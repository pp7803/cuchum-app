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

type VehicleService struct {
	vehicleRepo *repository.VehicleRepository
	tripRepo    *repository.TripRepository
}

func NewVehicleService(vehicleRepo *repository.VehicleRepository, tripRepo *repository.TripRepository) *VehicleService {
	return &VehicleService{vehicleRepo: vehicleRepo, tripRepo: tripRepo}
}

func (s *VehicleService) List(ctx context.Context, status string) ([]models.Vehicle, error) {
	vehicles, err := s.vehicleRepo.List(ctx, status)
	if err != nil {
		return nil, fmt.Errorf("failed to list vehicles: %w", err)
	}
	return vehicles, nil
}

func (s *VehicleService) GetMaintenance(ctx context.Context, vehicleID uuid.UUID) (*models.VehicleMaintenance, error) {
	maintenance, err := s.vehicleRepo.GetMaintenance(ctx, vehicleID)
	if err != nil {
		return nil, fmt.Errorf("failed to get vehicle maintenance: %w", err)
	}
	return maintenance, nil
}

func parseOptionalDate(s *string) (*time.Time, error) {
	if s == nil || *s == "" {
		return nil, nil
	}
	t, err := time.Parse("2006-01-02", *s)
	if err != nil {
		return nil, fmt.Errorf("invalid date %q (use YYYY-MM-DD)", *s)
	}
	return &t, nil
}

func (s *VehicleService) Create(ctx context.Context, req models.CreateVehicleRequest) (*models.Vehicle, error) {
	ins, err := parseOptionalDate(req.InsuranceExpiry)
	if err != nil {
		return nil, err
	}
	reg, err := parseOptionalDate(req.RegistrationExpiry)
	if err != nil {
		return nil, err
	}
	last, err := parseOptionalDate(req.LastMaintenanceDate)
	if err != nil {
		return nil, err
	}
	next, err := parseOptionalDate(req.NextMaintenanceDate)
	if err != nil {
		return nil, err
	}

	v := &models.Vehicle{
		LicensePlate:        req.LicensePlate,
		VehicleType:         req.VehicleType,
		Status:              req.Status,
		ImageURL:            req.ImageURL,
		InsuranceExpiry:     ins,
		RegistrationExpiry:  reg,
		LastMaintenanceDate: last,
		NextMaintenanceDate: next,
	}
	if v.Status == "" {
		v.Status = "ACTIVE"
	}

	if err := s.vehicleRepo.Create(ctx, v); err != nil {
		return nil, err
	}
	return s.vehicleRepo.GetByID(ctx, v.ID)
}

func (s *VehicleService) Update(ctx context.Context, id uuid.UUID, req models.UpdateVehicleRequest) error {
	ins, err := parseOptionalDate(req.InsuranceExpiry)
	if err != nil {
		return err
	}
	reg, err := parseOptionalDate(req.RegistrationExpiry)
	if err != nil {
		return err
	}
	last, err := parseOptionalDate(req.LastMaintenanceDate)
	if err != nil {
		return err
	}
	next, err := parseOptionalDate(req.NextMaintenanceDate)
	if err != nil {
		return err
	}

	return s.vehicleRepo.Update(ctx, id,
		req.LicensePlate,
		req.VehicleType,
		req.Status,
		req.ImageURL,
		ins, reg, last, next,
	)
}

func (s *VehicleService) Delete(ctx context.Context, id uuid.UUID) error {
	block, err := s.tripRepo.HasBlockingTripsForVehicleDeletion(ctx, id, time.Now().UTC())
	if err != nil {
		return err
	}
	if block {
		return errors.New("cannot delete vehicle while it has trips in progress or scheduled for the present or future")
	}
	return s.vehicleRepo.Delete(ctx, id)
}
