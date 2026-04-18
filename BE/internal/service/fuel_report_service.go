package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
)

type FuelReportService struct {
	fuelReportRepo *repository.FuelReportRepository
	userRepo       *repository.UserRepository
	tripRepo       *repository.TripRepository
	vehicleRepo    *repository.VehicleRepository
	notif          *NotificationService
}

func NewFuelReportService(
	fuelReportRepo *repository.FuelReportRepository,
	userRepo *repository.UserRepository,
	tripRepo *repository.TripRepository,
	vehicleRepo *repository.VehicleRepository,
	notif *NotificationService,
) *FuelReportService {
	return &FuelReportService{
		fuelReportRepo: fuelReportRepo,
		userRepo:       userRepo,
		tripRepo:       tripRepo,
		vehicleRepo:    vehicleRepo,
		notif:          notif,
	}
}

func (s *FuelReportService) List(ctx context.Context, driverID *uuid.UUID, dateStr string, vehicleID *uuid.UUID, tripID *uuid.UUID) ([]models.FuelReport, error) {
	var date *time.Time
	if dateStr != "" {
		parsed, err := time.Parse("2006-01-02", dateStr)
		if err != nil {
			return nil, fmt.Errorf("invalid date format (use YYYY-MM-DD): %w", err)
		}
		date = &parsed
	}

	reports, err := s.fuelReportRepo.List(ctx, driverID, date, vehicleID, tripID)
	if err != nil {
		return nil, fmt.Errorf("failed to list fuel reports: %w", err)
	}
	return reports, nil
}

func (s *FuelReportService) Create(ctx context.Context, driverID uuid.UUID, req models.CreateFuelReportRequest) (*models.FuelReport, error) {
	reportDate := time.Now()
	if req.ReportDate != "" {
		parsed, err := time.Parse("2006-01-02", req.ReportDate)
		if err != nil {
			return nil, fmt.Errorf("invalid report_date format (use YYYY-MM-DD): %w", err)
		}
		reportDate = parsed
	}

	var tripForWindow *models.Trip
	if req.TripID != nil {
		trip, err := s.tripRepo.GetByID(ctx, *req.TripID)
		if err != nil {
			return nil, errors.New("trip not found")
		}
		tripForWindow = trip
		if trip.DriverID != driverID {
			return nil, errors.New("trip does not belong to you")
		}
		if trip.VehicleID != req.VehicleID {
			return nil, errors.New("vehicle_id must match the scheduled trip vehicle")
		}
		// Báo cáo khi đổ xăng: gắn chuyến đã nhận (chuẩn bị chạy) hoặc đang chạy.
		if trip.Status != models.TripInProgress && trip.Status != models.TripDriverAccepted {
			return nil, errors.New("fuel report can only be linked to a trip that is accepted or in progress")
		}
		if trip.ScheduledStartAt == nil {
			return nil, errors.New("trip has no scheduled start time")
		}
		now := time.Now()
		winStart := trip.ScheduledStartAt.Add(-scheduledStartEarlySlack)
		winEnd := trip.ScheduledStartAt.Add(scheduledStartLateSlack)
		if now.Before(winStart) || now.After(winEnd) {
			return nil, errors.New("you may add a trip-linked fuel report only between 15 minutes before and 30 minutes after scheduled start")
		}
	}

	fuelPurchasedAtValue := time.Now()
	fuelPurchasedAt := &fuelPurchasedAtValue
	if req.FuelPurchasedAt != nil {
		s := strings.TrimSpace(*req.FuelPurchasedAt)
		if s != "" {
			t, err := time.Parse(time.RFC3339, s)
			if err != nil {
				return nil, fmt.Errorf("invalid fuel_purchased_at (use RFC3339): %w", err)
			}
			if t.After(time.Now()) {
				return nil, errors.New("fuel_purchased_at must not be in the future")
			}
			if tripForWindow != nil && tripForWindow.ScheduledStartAt != nil {
				ws := tripForWindow.ScheduledStartAt.Add(-scheduledStartEarlySlack)
				we := tripForWindow.ScheduledStartAt.Add(scheduledStartLateSlack)
				if t.Before(ws) || t.After(we) {
					return nil, errors.New("fuel_purchased_at must fall within 15 minutes before or 30 minutes after the trip scheduled start")
				}
			}
			fuelPurchasedAt = &t
		}
	}

	report := &models.FuelReport{
		DriverID:        driverID,
		VehicleID:       &req.VehicleID,
		TripID:          req.TripID,
		ReportDate:      reportDate,
		OdoCurrent:      req.OdoCurrent,
		Liters:          req.Liters,
		TotalCost:       req.TotalCost,
		ReceiptImageURL: req.ReceiptImageURL,
		OdoImageURL:     req.OdoImageURL,
		GpsLatitude:     req.GpsLatitude,
		GpsLongitude:    req.GpsLongitude,
		FuelPurchasedAt: fuelPurchasedAt,
	}

	if err := s.fuelReportRepo.Create(ctx, report); err != nil {
		return nil, fmt.Errorf("failed to create fuel report: %w", err)
	}

	if req.TripID != nil {
		trip, terr := s.tripRepo.GetByID(ctx, *req.TripID)
		if terr == nil && trip != nil {
			dn, plate := "Tài xế", "—"
			if u, e := s.userRepo.FindByID(ctx, trip.DriverID); e == nil && u != nil && u.FullName != "" {
				dn = u.FullName
			}
			if v, e := s.vehicleRepo.GetByID(ctx, trip.VehicleID); e == nil && v != nil {
				plate = v.LicensePlate
			}
			go func() {
				s.notif.NotifyAdmins(context.Background(), "⛽ Báo cáo xăng",
					fmt.Sprintf("%s báo chi phí nhiên liệu %.0fđ (xe %s).", dn, req.TotalCost, plate))
			}()
		}
	}

	return report, nil
}

func (s *FuelReportService) UpdateAdminNote(ctx context.Context, reportID uuid.UUID, note string) error {
	if err := s.fuelReportRepo.UpdateAdminNote(ctx, reportID, note); err != nil {
		return fmt.Errorf("failed to update admin note: %w", err)
	}
	return nil
}

// ExportByDateRange returns fuel reports for export
func (s *FuelReportService) ExportByDateRange(ctx context.Context, startDateStr, endDateStr string, driverID *uuid.UUID) ([]models.FuelReportExport, error) {
	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		return nil, fmt.Errorf("invalid start_date format (use YYYY-MM-DD): %w", err)
	}

	endDate, err := time.Parse("2006-01-02", endDateStr)
	if err != nil {
		return nil, fmt.Errorf("invalid end_date format (use YYYY-MM-DD): %w", err)
	}

	reports, err := s.fuelReportRepo.ListByDateRange(ctx, startDate, endDate, driverID)
	if err != nil {
		return nil, err
	}

	// Get user names for export
	exports := make([]models.FuelReportExport, 0, len(reports))
	for _, r := range reports {
		export := models.FuelReportExport{
			ID:              r.ID,
			DriverID:        r.DriverID,
			VehicleID:       r.VehicleID,
			ReportDate:      r.ReportDate,
			OdoCurrent:      r.OdoCurrent,
			Liters:          r.Liters,
			TotalCost:       r.TotalCost,
			ReceiptImageURL: r.ReceiptImageURL,
			AdminNote:       r.AdminNote,
			FuelPurchasedAt: r.FuelPurchasedAt,
		}

		// Get driver name
		if user, err := s.userRepo.FindByID(ctx, r.DriverID); err == nil {
			export.DriverName = user.FullName
		}

		exports = append(exports, export)
	}

	return exports, nil
}
