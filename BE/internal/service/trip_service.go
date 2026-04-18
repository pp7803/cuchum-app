package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
)

const (
	// Driver may tap "start" from 15m before through 30m after scheduled_start_at (server time).
	scheduledStartEarlySlack = 15 * time.Minute
	scheduledStartLateSlack  = 30 * time.Minute
	// Reminders vs scheduled_start_at (DRIVER_ACCEPTED).
	departureNotifyBeforeScheduled = 10 * time.Minute
	departureNotifyLateAfterStart  = 10 * time.Minute
)

type TripService struct {
	tripRepo      *repository.TripRepository
	checklistRepo *repository.ChecklistRepository
	userRepo      *repository.UserRepository
	vehicleRepo   *repository.VehicleRepository
	notif         *NotificationService
}

func scheduleWindowEnd(start time.Time, end *time.Time) time.Time {
	if end != nil {
		return *end
	}
	return start.Add(24 * time.Hour)
}

// scheduleIntervalsOverlap uses half-open [start, end): adjacent windows do not overlap.
func scheduleIntervalsOverlap(aStart, aEnd, bStart, bEnd time.Time) bool {
	return aStart.Before(bEnd) && bStart.Before(aEnd)
}

func NewTripService(
	tripRepo *repository.TripRepository,
	checklistRepo *repository.ChecklistRepository,
	userRepo *repository.UserRepository,
	vehicleRepo *repository.VehicleRepository,
	notif *NotificationService,
) *TripService {
	return &TripService{
		tripRepo:      tripRepo,
		checklistRepo: checklistRepo,
		userRepo:      userRepo,
		vehicleRepo:   vehicleRepo,
		notif:         notif,
	}
}

func (s *TripService) StartTrip(ctx context.Context, driverID uuid.UUID, req models.StartTripRequest) (*models.Trip, error) {
	activeTrip, _ := s.tripRepo.GetActiveTrip(ctx, driverID)
	if activeTrip != nil {
		return nil, errors.New("you already have an active trip, please end it first")
	}

	trip := &models.Trip{
		DriverID:  driverID,
		VehicleID: req.VehicleID,
		StartOdo:  req.StartOdo,
		StartLat:  req.StartLat,
		StartLng:  req.StartLng,
	}

	if err := s.tripRepo.Create(ctx, trip); err != nil {
		return nil, err
	}

	return s.tripRepo.GetByID(ctx, trip.ID)
}

func (s *TripService) ScheduleTrip(ctx context.Context, req models.ScheduleTripRequest) (*models.Trip, error) {
	driver, err := s.userRepo.FindByID(ctx, req.DriverID)
	if err != nil || driver == nil {
		return nil, errors.New("driver not found")
	}
	if driver.Role != models.RoleDriver {
		return nil, errors.New("target user is not a driver")
	}

	if _, err := s.vehicleRepo.GetByID(ctx, req.VehicleID); err != nil {
		return nil, errors.New("vehicle not found")
	}

	startAt, err := ParseClientScheduleInstant(req.ScheduledStartAt)
	if err != nil {
		return nil, fmt.Errorf("invalid scheduled_start_at (use RFC3339): %w", err)
	}

	var endAt *time.Time
	if req.ScheduledEndAt != nil && *req.ScheduledEndAt != "" {
		t, err := ParseClientScheduleInstant(*req.ScheduledEndAt)
		if err != nil {
			return nil, fmt.Errorf("invalid scheduled_end_at (use RFC3339): %w", err)
		}
		endAt = &t
	}

	now := time.Now()
	if !startAt.After(now) {
		return nil, errors.New("scheduled_start_at must be in the future")
	}
	if endAt != nil && !endAt.After(startAt) {
		return nil, errors.New("scheduled_end_at must be after scheduled_start_at")
	}

	occ, err := s.tripRepo.ListTripsOccupyingVehicleForSchedule(ctx, req.VehicleID)
	if err != nil {
		return nil, fmt.Errorf("failed to check vehicle availability: %w", err)
	}
	newWinEnd := scheduleWindowEnd(startAt, endAt)
	for _, t := range occ {
		if t.Status == models.TripInProgress {
			return nil, errors.New("vehicle is already on an active trip")
		}
		if t.ScheduledStartAt == nil {
			continue
		}
		exEnd := scheduleWindowEnd(*t.ScheduledStartAt, t.ScheduledEndAt)
		if scheduleIntervalsOverlap(startAt, newWinEnd, *t.ScheduledStartAt, exEnd) {
			return nil, errors.New("vehicle already has another trip overlapping this time window")
		}
	}

	trip := &models.Trip{
		DriverID:         req.DriverID,
		VehicleID:        req.VehicleID,
		ScheduledStartAt: &startAt,
		ScheduledEndAt:   endAt,
		DriverNote:       req.DriverNote,
	}

	if err := s.tripRepo.CreateScheduled(ctx, trip); err != nil {
		return nil, err
	}

	trip, err = s.tripRepo.GetByID(ctx, trip.ID)
	if err != nil {
		return trip, err
	}

	// Notify driver (non-blocking best-effort)
	did := req.DriverID
	body := fmt.Sprintf("Bạn có chuyến mới dự kiến lúc %s.", formatDriverLocalDateTime(startAt))
	if req.DriverNote != nil && *req.DriverNote != "" {
		body += " Ghi chú: " + *req.DriverNote
	}
	go func() {
		_, _ = s.notif.Create(context.Background(), models.CreateNotificationRequest{
			Title:    "🚛 Chuyến xe được lên lịch",
			Body:     body,
			DriverID: &did,
		})
	}()

	return trip, nil
}

func (s *TripService) RespondTrip(ctx context.Context, tripID, driverID uuid.UUID, req models.RespondTripRequest) (*models.Trip, error) {
	trip, err := s.tripRepo.GetByID(ctx, tripID)
	if err != nil {
		return nil, errors.New("trip not found")
	}
	if trip.DriverID != driverID {
		return nil, errors.New("you are not assigned to this trip")
	}
	if trip.Status != models.TripScheduledPending {
		return nil, errors.New("this trip is not awaiting your response")
	}

	if err := s.tripRepo.RespondToScheduledTrip(ctx, tripID, driverID, req.Status, req.DeclineNote); err != nil {
		return nil, err
	}
	trip, err = s.tripRepo.GetByID(ctx, tripID)
	if err != nil {
		return trip, err
	}
	dn, plate := s.driverAndPlate(ctx, trip)
	go func() {
		bg := context.Background()
		switch req.Status {
		case models.TripDriverAccepted:
			s.notif.NotifyAdmins(bg, "✅ Tài xế nhận chuyến",
				fmt.Sprintf("%s đã đồng ý chuyến (xe %s).", dn, plate))
		case models.TripDriverDeclined:
			msg := fmt.Sprintf("%s đã từ chối chuyến (xe %s).", dn, plate)
			if req.DeclineNote != nil && *req.DeclineNote != "" {
				msg += " Lý do: " + *req.DeclineNote
			}
			s.notif.NotifyAdmins(bg, "⛔ Tài xế từ chối chuyến", msg)
		}
	}()
	return trip, nil
}

func (s *TripService) StartScheduledTrip(ctx context.Context, tripID, driverID uuid.UUID, req models.StartScheduledTripRequest) (*models.Trip, error) {
	activeTrip, _ := s.tripRepo.GetActiveTrip(ctx, driverID)
	if activeTrip != nil {
		return nil, errors.New("you already have an active trip, please end it first")
	}

	trip, err := s.tripRepo.GetByID(ctx, tripID)
	if err != nil {
		return nil, errors.New("trip not found")
	}
	if trip.DriverID != driverID {
		return nil, errors.New("you are not assigned to this trip")
	}
	if trip.Status != models.TripDriverAccepted {
		return nil, errors.New("accept the scheduled trip before starting")
	}

	if trip.ScheduledStartAt == nil {
		return nil, errors.New("trip has no scheduled start time")
	}
	hasChecklist, err := s.checklistRepo.ExistsForTrip(ctx, tripID)
	if err != nil {
		return nil, fmt.Errorf("failed to verify checklist: %w", err)
	}
	if !hasChecklist {
		return nil, errors.New("complete the vehicle checklist for this trip before starting")
	}
	now := time.Now()
	winStart := trip.ScheduledStartAt.Add(-scheduledStartEarlySlack)
	winEnd := trip.ScheduledStartAt.Add(scheduledStartLateSlack)
	if now.Before(winStart) || now.After(winEnd) {
		return nil, errors.New("you may start only between 15 minutes before and 30 minutes after scheduled start")
	}

	if err := s.tripRepo.StartScheduledTrip(ctx, tripID, driverID, req.StartOdo, req.StartLat, req.StartLng); err != nil {
		return nil, err
	}
	trip, err = s.tripRepo.GetByID(ctx, tripID)
	if err != nil {
		return trip, err
	}
	dn, plate := s.driverAndPlate(ctx, trip)
	go func() {
		s.notif.NotifyAdmins(context.Background(), "▶️ Bắt đầu chuyến",
			fmt.Sprintf("%s đã bắt đầu chạy (xe %s).", dn, plate))
	}()
	return trip, nil
}

func (s *TripService) EndTrip(ctx context.Context, tripID uuid.UUID, driverID uuid.UUID, req models.EndTripRequest) (*models.Trip, error) {
	trip, err := s.tripRepo.GetByID(ctx, tripID)
	if err != nil {
		return nil, errors.New("trip not found")
	}

	if trip.DriverID != driverID {
		return nil, errors.New("you are not authorized to end this trip")
	}

	if trip.Status != models.TripInProgress {
		return nil, errors.New("trip is not in progress")
	}

	if err := s.tripRepo.EndTrip(ctx, tripID, req.EndOdo, req.EndLat, req.EndLng); err != nil {
		return nil, err
	}

	trip, err = s.tripRepo.GetByID(ctx, tripID)
	if err != nil {
		return trip, err
	}
	dn, plate := s.driverAndPlate(ctx, trip)
	go func() {
		s.notif.NotifyAdmins(context.Background(), "🏁 Kết thúc chuyến",
			fmt.Sprintf("%s đã kết thúc chuyến (xe %s).", dn, plate))
	}()
	return trip, nil
}

func (s *TripService) driverAndPlate(ctx context.Context, trip *models.Trip) (driverName, plate string) {
	driverName = "Tài xế"
	plate = "—"
	if u, err := s.userRepo.FindByID(ctx, trip.DriverID); err == nil && u != nil && u.FullName != "" {
		driverName = u.FullName
	}
	if v, err := s.vehicleRepo.GetByID(ctx, trip.VehicleID); err == nil && v != nil {
		plate = v.LicensePlate
	}
	return
}

// AdminCancelTrip cancels pending/accepted scheduled trips and notifies the driver.
// Not allowed while IN_PROGRESS or during the driver departure window
// [scheduled_start_at − 15m, scheduled_start_at + 30m].
func (s *TripService) AdminCancelTrip(ctx context.Context, tripID uuid.UUID, reason string) (*models.Trip, error) {
	trip, err := s.tripRepo.GetByID(ctx, tripID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("trip not found")
		}
		return nil, err
	}
	if trip.Status == models.TripInProgress {
		return nil, errors.New("cannot cancel trip while it is in progress")
	}
	if trip.Status != models.TripScheduledPending && trip.Status != models.TripDriverAccepted {
		return nil, errors.New("trip cannot be cancelled")
	}
	if trip.ScheduledStartAt != nil {
		now := time.Now()
		wStart := trip.ScheduledStartAt.Add(-scheduledStartEarlySlack)
		wEnd := trip.ScheduledStartAt.Add(scheduledStartLateSlack)
		if !now.Before(wStart) && !now.After(wEnd) {
			return nil, errors.New("cannot cancel during scheduled departure window (15 minutes before through 30 minutes after planned start)")
		}
	}
	driverID := trip.DriverID
	if err := s.tripRepo.AdminCancelTrip(ctx, tripID, reason); err != nil {
		return nil, err
	}
	trip, err = s.tripRepo.GetByID(ctx, tripID)
	if err != nil {
		return nil, err
	}
	go func() {
		s.notif.NotifyDriver(context.Background(), driverID, "❌ Chuyến bị hủy",
			fmt.Sprintf("Quản trị đã hủy chuyến. Lý do: %s", reason))
	}()
	return trip, nil
}

func (s *TripService) List(ctx context.Context, driverID *uuid.UUID, vehicleID *uuid.UUID, status *models.TripStatus, startDate, endDate string) ([]*models.Trip, error) {
	return s.tripRepo.List(ctx, driverID, vehicleID, status, startDate, endDate)
}

func (s *TripService) GetActiveTrip(ctx context.Context, driverID uuid.UUID) (*models.Trip, error) {
	t, err := s.tripRepo.GetActiveTrip(ctx, driverID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return t, nil
}

// GetTripForViewer returns one trip; DRIVER only if assigned. Enriches license_plate and driver_name.
func (s *TripService) GetTripForViewer(ctx context.Context, tripID uuid.UUID, viewerID uuid.UUID, role string) (*models.Trip, error) {
	if role != string(models.RoleAdmin) && role != string(models.RoleDriver) {
		return nil, errors.New("trip not found")
	}

	trip, err := s.tripRepo.GetByID(ctx, tripID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("trip not found")
		}
		return nil, err
	}

	if role == string(models.RoleDriver) && trip.DriverID != viewerID {
		return nil, errors.New("trip not found")
	}

	v, err := s.vehicleRepo.GetByID(ctx, trip.VehicleID)
	if err != nil {
		return nil, errors.New("trip not found")
	}
	lp := v.LicensePlate
	trip.LicensePlate = &lp

	if u, err := s.userRepo.FindByID(ctx, trip.DriverID); err == nil && u != nil {
		fn := u.FullName
		trip.DriverName = &fn
	}

	return trip, nil
}
