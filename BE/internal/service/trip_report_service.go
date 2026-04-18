package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
)

type TripReportService struct {
	tripReportRepo *repository.TripReportRepository
}

func NewTripReportService(tripReportRepo *repository.TripReportRepository) *TripReportService {
	return &TripReportService{tripReportRepo: tripReportRepo}
}

func (s *TripReportService) List(ctx context.Context, driverID *uuid.UUID, startDateStr, endDateStr string) ([]models.DailyTripReport, error) {
	var startDate, endDate *time.Time

	if startDateStr != "" {
		parsed, err := time.Parse("2006-01-02", startDateStr)
		if err != nil {
			return nil, fmt.Errorf("invalid start_date format (use YYYY-MM-DD): %w", err)
		}
		startDate = &parsed
	}

	if endDateStr != "" {
		parsed, err := time.Parse("2006-01-02", endDateStr)
		if err != nil {
			return nil, fmt.Errorf("invalid end_date format (use YYYY-MM-DD): %w", err)
		}
		endDate = &parsed
	}

	reports, err := s.tripReportRepo.List(ctx, driverID, startDate, endDate)
	if err != nil {
		return nil, fmt.Errorf("failed to list trip reports: %w", err)
	}
	return reports, nil
}

func (s *TripReportService) CreateOrUpdate(ctx context.Context, driverID uuid.UUID, req models.CreateTripReportRequest) (*models.DailyTripReport, error) {
	reportDate := time.Now()
	if req.ReportDate != "" {
		parsed, err := time.Parse("2006-01-02", req.ReportDate)
		if err != nil {
			return nil, fmt.Errorf("invalid report_date format (use YYYY-MM-DD): %w", err)
		}
		reportDate = parsed
	}

	report := &models.DailyTripReport{
		DriverID:   driverID,
		ReportDate: reportDate,
		TotalTrips: req.TotalTrips,
	}

	if err := s.tripReportRepo.Upsert(ctx, report); err != nil {
		return nil, fmt.Errorf("failed to create/update trip report: %w", err)
	}

	return report, nil
}
