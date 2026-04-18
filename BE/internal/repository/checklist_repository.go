package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

type ChecklistRepository struct {
	pool *pgxpool.Pool
}

func NewChecklistRepository(pool *pgxpool.Pool) *ChecklistRepository {
	return &ChecklistRepository{pool: pool}
}

func (r *ChecklistRepository) ExistsForTrip(ctx context.Context, tripID uuid.UUID) (bool, error) {
	var n int64
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM vehicle_checklists WHERE trip_id = $1`,
		tripID,
	).Scan(&n)
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

func (r *ChecklistRepository) Create(ctx context.Context, checklist *models.VehicleChecklist) error {
	query := `
		INSERT INTO vehicle_checklists (id, driver_id, vehicle_id, trip_id, check_date, tire_check, light_check, clean_check, brake_check, oil_check, note, created_at)
		VALUES ($1, $2, $3, $4, $5::date, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, created_at
	`
	checklist.ID = uuid.New()
	checklist.CreatedAt = time.Now()
	if checklist.CheckDate.IsZero() {
		checklist.CheckDate = time.Now()
	}

	return r.pool.QueryRow(ctx, query,
		checklist.ID,
		checklist.DriverID,
		checklist.VehicleID,
		checklist.TripID,
		checklist.CheckDate,
		checklist.TireCheck,
		checklist.LightCheck,
		checklist.CleanCheck,
		checklist.BrakeCheck,
		checklist.OilCheck,
		checklist.Note,
		checklist.CreatedAt,
	).Scan(&checklist.ID, &checklist.CreatedAt)
}

func (r *ChecklistRepository) List(ctx context.Context, vehicleID *uuid.UUID, date string, tripID *uuid.UUID) ([]*models.VehicleChecklist, error) {
	query := `
		SELECT id, driver_id, vehicle_id, trip_id, check_date, tire_check, light_check, clean_check, brake_check, oil_check, note, created_at
		FROM vehicle_checklists
		WHERE 1=1
	`
	args := []interface{}{}
	n := 1

	if vehicleID != nil {
		query += fmt.Sprintf(" AND vehicle_id = $%d", n)
		args = append(args, *vehicleID)
		n++
	}

	if date != "" {
		query += fmt.Sprintf(" AND check_date = $%d::date", n)
		args = append(args, date)
		n++
	}

	if tripID != nil {
		query += fmt.Sprintf(" AND trip_id = $%d", n)
		args = append(args, *tripID)
		n++
	}

	query += " ORDER BY created_at DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var checklists []*models.VehicleChecklist
	for rows.Next() {
		c := &models.VehicleChecklist{}
		if err := rows.Scan(
			&c.ID, &c.DriverID, &c.VehicleID, &c.TripID, &c.CheckDate,
			&c.TireCheck, &c.LightCheck, &c.CleanCheck, &c.BrakeCheck, &c.OilCheck,
			&c.Note, &c.CreatedAt,
		); err != nil {
			return nil, err
		}
		checklists = append(checklists, c)
	}

	return checklists, nil
}
