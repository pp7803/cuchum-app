package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
)

type ChecklistService struct {
	checklistRepo *repository.ChecklistRepository
	tripRepo      *repository.TripRepository
	userRepo      *repository.UserRepository
	vehicleRepo   *repository.VehicleRepository
	notif         *NotificationService
}

func NewChecklistService(
	checklistRepo *repository.ChecklistRepository,
	tripRepo *repository.TripRepository,
	userRepo *repository.UserRepository,
	vehicleRepo *repository.VehicleRepository,
	notif *NotificationService,
) *ChecklistService {
	return &ChecklistService{
		checklistRepo: checklistRepo,
		tripRepo:      tripRepo,
		userRepo:      userRepo,
		vehicleRepo:   vehicleRepo,
		notif:         notif,
	}
}

func (s *ChecklistService) Create(ctx context.Context, driverID uuid.UUID, req models.CreateChecklistRequest) (*models.VehicleChecklist, error) {
	if req.TripID == uuid.Nil {
		return nil, errors.New("trip_id is required")
	}

	trip, err := s.tripRepo.GetByID(ctx, req.TripID)
	if err != nil {
		return nil, errors.New("trip not found")
	}
	if trip.DriverID != driverID {
		return nil, errors.New("trip does not belong to you")
	}
	if trip.VehicleID != req.VehicleID {
		return nil, errors.New("vehicle_id must match the trip vehicle")
	}
	switch trip.Status {
	case models.TripDriverAccepted, models.TripInProgress:
	default:
		return nil, errors.New("checklist is only allowed after the driver has accepted the trip (accepted or in-progress)")
	}

	exists, err := s.checklistRepo.ExistsForTrip(ctx, req.TripID)
	if err != nil {
		return nil, fmt.Errorf("failed to verify checklist: %w", err)
	}
	if exists {
		return nil, errors.New("vehicle checklist already submitted for this trip")
	}

	tid := req.TripID
	checklist := &models.VehicleChecklist{
		DriverID:   driverID,
		VehicleID:  req.VehicleID,
		TripID:     &tid,
		CheckDate:  time.Now(),
		TireCheck:  req.TireCheck,
		LightCheck: req.LightCheck,
		CleanCheck: req.CleanCheck,
		BrakeCheck: req.BrakeCheck,
		OilCheck:   req.OilCheck,
		Note:       req.Note,
	}

	if err := s.checklistRepo.Create(ctx, checklist); err != nil {
		return nil, err
	}

	dn, plate := "Tài xế", "—"
	if u, e := s.userRepo.FindByID(ctx, driverID); e == nil && u != nil && u.FullName != "" {
		dn = u.FullName
	}
	if v, e := s.vehicleRepo.GetByID(ctx, trip.VehicleID); e == nil && v != nil {
		plate = v.LicensePlate
	}
	go func() {
		s.notif.NotifyAdmins(context.Background(), "📋 Kiểm tra xe",
			fmt.Sprintf("%s đã hoàn thành kiểm tra xe trước chuyến (xe %s).", dn, plate))
	}()

	return checklist, nil
}

func (s *ChecklistService) List(ctx context.Context, vehicleID *uuid.UUID, date string, tripID *uuid.UUID) ([]*models.VehicleChecklist, error) {
	return s.checklistRepo.List(ctx, vehicleID, date, tripID)
}
