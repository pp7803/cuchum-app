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

type IncidentService struct {
	incidentRepo *repository.IncidentRepository
	tripRepo     *repository.TripRepository
	notif        *NotificationService
	userRepo     *repository.UserRepository
	vehicleRepo  *repository.VehicleRepository
}

func NewIncidentService(
	incidentRepo *repository.IncidentRepository,
	tripRepo *repository.TripRepository,
	notif *NotificationService,
	userRepo *repository.UserRepository,
	vehicleRepo *repository.VehicleRepository,
) *IncidentService {
	return &IncidentService{
		incidentRepo: incidentRepo,
		tripRepo:     tripRepo,
		notif:        notif,
		userRepo:     userRepo,
		vehicleRepo:  vehicleRepo,
	}
}

func (s *IncidentService) Create(ctx context.Context, driverID uuid.UUID, req models.CreateIncidentRequest) (*models.Incident, error) {
	incidentDate := time.Now()
	if req.ViolationAt != nil && *req.ViolationAt != "" {
		var err error
		incidentDate, err = time.Parse(time.RFC3339, *req.ViolationAt)
		if err != nil {
			incidentDate, err = time.ParseInLocation("2006-01-02 15:04", *req.ViolationAt, time.Local)
			if err != nil {
				incidentDate, err = time.Parse("2006-01-02", *req.ViolationAt)
				if err != nil {
					return nil, fmt.Errorf("invalid violation_at (RFC3339, YYYY-MM-DD, or YYYY-MM-DD HH:MM): %w", err)
				}
			}
		}
	}

	if req.TripID != nil {
		trip, err := s.tripRepo.GetByID(ctx, *req.TripID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, errors.New("trip not found")
			}
			return nil, err
		}
		if trip.DriverID != driverID {
			return nil, errors.New("trip does not belong to you")
		}
		if trip.VehicleID != req.VehicleID {
			return nil, errors.New("vehicle_id must match trip vehicle")
		}
		if trip.Status != models.TripInProgress {
			return nil, errors.New("trip must be in progress to report incident")
		}
	}

	incident := &models.Incident{
		DriverID:     driverID,
		VehicleID:    req.VehicleID,
		TripID:       req.TripID,
		IncidentType: req.Type,
		Description:  req.Description,
		ImageURL:     req.ImageURL,
		GpsLat:       req.GpsLat,
		GpsLng:       req.GpsLng,
		IncidentDate: incidentDate,
	}

	if err := s.incidentRepo.Create(ctx, incident); err != nil {
		return nil, err
	}

	if req.Type == models.IncidentTrafficTicket || req.TripID != nil {
		driverName := "Tài xế"
		if u, err := s.userRepo.FindByID(ctx, driverID); err == nil && u != nil && u.FullName != "" {
			driverName = u.FullName
		}
		plate := "—"
		if v, err := s.vehicleRepo.GetByID(ctx, req.VehicleID); err == nil && v != nil {
			plate = v.LicensePlate
		}
		title := "🚨 Báo cáo sự cố"
		typeLabel := "sự cố"
		if req.Type == models.IncidentTrafficTicket {
			title = "⚠️ Báo cáo vi phạm"
			typeLabel = "vi phạm"
		}
		body := fmt.Sprintf("%s đã báo %s (xe %s).", driverName, typeLabel, plate)
		s.notif.NotifyAdmins(context.Background(), title, body)
	}

	return incident, nil
}

func (s *IncidentService) List(ctx context.Context, driverID *uuid.UUID, incidentType *models.IncidentType, tripID *uuid.UUID) ([]*models.Incident, error) {
	return s.incidentRepo.List(ctx, driverID, incidentType, tripID)
}

func (s *IncidentService) GetByID(ctx context.Context, incidentID uuid.UUID) (*models.Incident, error) {
	return s.incidentRepo.GetByID(ctx, incidentID)
}
