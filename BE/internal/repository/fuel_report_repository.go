package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

type FuelReportRepository struct {
	db *pgxpool.Pool
}

func NewFuelReportRepository(db *pgxpool.Pool) *FuelReportRepository {
	return &FuelReportRepository{db: db}
}

// List retrieves fuel reports with filters
func (r *FuelReportRepository) List(ctx context.Context, driverID *uuid.UUID, date *time.Time, vehicleID *uuid.UUID, tripID *uuid.UUID) ([]models.FuelReport, error) {
	query := `
		SELECT id, driver_id, vehicle_id, trip_id, report_date, odo_current, liters, total_cost, 
		       receipt_image_url, odo_image_url, gps_latitude, gps_longitude, admin_note, fuel_purchased_at, created_at
		FROM fuel_reports
		WHERE 1=1
	`
	args := []interface{}{}
	argIndex := 1

	if driverID != nil {
		query += fmt.Sprintf(" AND driver_id = $%d", argIndex)
		args = append(args, *driverID)
		argIndex++
	}

	if date != nil {
		query += fmt.Sprintf(" AND report_date = $%d", argIndex)
		args = append(args, *date)
		argIndex++
	}

	if vehicleID != nil {
		query += fmt.Sprintf(" AND vehicle_id = $%d", argIndex)
		args = append(args, *vehicleID)
		argIndex++
	}

	if tripID != nil {
		query += fmt.Sprintf(" AND trip_id = $%d", argIndex)
		args = append(args, *tripID)
		argIndex++
	}

	query += " ORDER BY COALESCE(fuel_purchased_at, created_at) DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list fuel reports: %w", err)
	}
	defer rows.Close()

	reports := make([]models.FuelReport, 0)
	for rows.Next() {
		var fr models.FuelReport
		var fuelAt sql.NullTime
		err := rows.Scan(
			&fr.ID, &fr.DriverID, &fr.VehicleID, &fr.TripID, &fr.ReportDate,
			&fr.OdoCurrent, &fr.Liters, &fr.TotalCost,
			&fr.ReceiptImageURL, &fr.OdoImageURL,
			&fr.GpsLatitude, &fr.GpsLongitude,
			&fr.AdminNote, &fuelAt, &fr.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan fuel report: %w", err)
		}
		if fuelAt.Valid {
			t := fuelAt.Time
			fr.FuelPurchasedAt = &t
		}
		reports = append(reports, fr)
	}

	return reports, nil
}

// ListByDateRange retrieves fuel reports within a date range (for export)
func (r *FuelReportRepository) ListByDateRange(ctx context.Context, startDate, endDate time.Time, driverID *uuid.UUID) ([]models.FuelReport, error) {
	query := `
		SELECT fr.id, fr.driver_id, fr.vehicle_id, fr.trip_id, fr.report_date, fr.odo_current, fr.liters, fr.total_cost, 
		       fr.receipt_image_url, fr.odo_image_url, fr.gps_latitude, fr.gps_longitude, fr.admin_note, fr.fuel_purchased_at, fr.created_at
		FROM fuel_reports fr
		WHERE fr.report_date >= $1 AND fr.report_date <= $2
	`
	args := []interface{}{startDate, endDate}
	argIndex := 3

	if driverID != nil {
		query += fmt.Sprintf(" AND fr.driver_id = $%d", argIndex)
		args = append(args, *driverID)
	}

	query += " ORDER BY COALESCE(fr.fuel_purchased_at, fr.created_at) DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list fuel reports by date range: %w", err)
	}
	defer rows.Close()

	reports := make([]models.FuelReport, 0)
	for rows.Next() {
		var fr models.FuelReport
		var fuelAt sql.NullTime
		err := rows.Scan(
			&fr.ID, &fr.DriverID, &fr.VehicleID, &fr.TripID, &fr.ReportDate,
			&fr.OdoCurrent, &fr.Liters, &fr.TotalCost,
			&fr.ReceiptImageURL, &fr.OdoImageURL,
			&fr.GpsLatitude, &fr.GpsLongitude,
			&fr.AdminNote, &fuelAt, &fr.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan fuel report: %w", err)
		}
		if fuelAt.Valid {
			t := fuelAt.Time
			fr.FuelPurchasedAt = &t
		}
		reports = append(reports, fr)
	}

	return reports, nil
}

// Create creates a new fuel report
func (r *FuelReportRepository) Create(ctx context.Context, report *models.FuelReport) error {
	query := `
		INSERT INTO fuel_reports (driver_id, vehicle_id, trip_id, report_date, odo_current, liters, total_cost, receipt_image_url, odo_image_url, gps_latitude, gps_longitude, fuel_purchased_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, created_at
	`

	err := r.db.QueryRow(ctx, query,
		report.DriverID,
		report.VehicleID,
		report.TripID,
		report.ReportDate,
		report.OdoCurrent,
		report.Liters,
		report.TotalCost,
		report.ReceiptImageURL,
		report.OdoImageURL,
		report.GpsLatitude,
		report.GpsLongitude,
		report.FuelPurchasedAt,
	).Scan(&report.ID, &report.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to create fuel report: %w", err)
	}

	return nil
}

// UpdateAdminNote updates admin note for a fuel report
func (r *FuelReportRepository) UpdateAdminNote(ctx context.Context, id uuid.UUID, note string) error {
	query := `
		UPDATE fuel_reports
		SET admin_note = $1
		WHERE id = $2
	`

	result, err := r.db.Exec(ctx, query, note, id)
	if err != nil {
		return fmt.Errorf("failed to update admin note: %w", err)
	}

	if result.RowsAffected() == 0 {
		return errors.New("fuel report not found")
	}

	return nil
}
