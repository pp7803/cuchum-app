package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

type TripReportRepository struct {
	db *pgxpool.Pool
}

func NewTripReportRepository(db *pgxpool.Pool) *TripReportRepository {
	return &TripReportRepository{db: db}
}

// List retrieves trip reports with filters
func (r *TripReportRepository) List(ctx context.Context, driverID *uuid.UUID, startDate, endDate *time.Time) ([]models.DailyTripReport, error) {
	query := `
		SELECT id, driver_id, report_date, total_trips, created_at
		FROM daily_trip_reports
		WHERE 1=1
	`
	args := []interface{}{}
	argIndex := 1

	if driverID != nil {
		query += fmt.Sprintf(" AND driver_id = $%d", argIndex)
		args = append(args, *driverID)
		argIndex++
	}

	if startDate != nil {
		query += fmt.Sprintf(" AND report_date >= $%d", argIndex)
		args = append(args, *startDate)
		argIndex++
	}

	if endDate != nil {
		query += fmt.Sprintf(" AND report_date <= $%d", argIndex)
		args = append(args, *endDate)
		argIndex++
	}

	query += " ORDER BY report_date DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list trip reports: %w", err)
	}
	defer rows.Close()

	reports := make([]models.DailyTripReport, 0)
	for rows.Next() {
		var r models.DailyTripReport
		err := rows.Scan(&r.ID, &r.DriverID, &r.ReportDate, &r.TotalTrips, &r.CreatedAt)
		if err != nil {
			return nil, fmt.Errorf("failed to scan trip report: %w", err)
		}
		reports = append(reports, r)
	}

	return reports, nil
}

// Upsert creates or updates a trip report for the date
func (r *TripReportRepository) Upsert(ctx context.Context, report *models.DailyTripReport) error {
	query := `
		INSERT INTO daily_trip_reports (driver_id, report_date, total_trips)
		VALUES ($1, $2, $3)
		ON CONFLICT (driver_id, report_date)
		DO UPDATE SET total_trips = EXCLUDED.total_trips
		RETURNING id, created_at
	`

	err := r.db.QueryRow(ctx, query,
		report.DriverID,
		report.ReportDate,
		report.TotalTrips,
	).Scan(&report.ID, &report.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to upsert trip report: %w", err)
	}

	return nil
}
