package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

type IncidentRepository struct {
	pool *pgxpool.Pool
}

func NewIncidentRepository(pool *pgxpool.Pool) *IncidentRepository {
	return &IncidentRepository{pool: pool}
}

func (r *IncidentRepository) Create(ctx context.Context, incident *models.Incident) error {
	query := `
		INSERT INTO incidents (id, driver_id, vehicle_id, trip_id, incident_type, description, image_url, gps_lat, gps_lng, incident_date, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`
	incident.ID = uuid.New()
	if incident.IncidentDate.IsZero() {
		incident.IncidentDate = time.Now()
	}
	incident.CreatedAt = time.Now()

	_, err := r.pool.Exec(ctx, query,
		incident.ID,
		incident.DriverID,
		incident.VehicleID,
		incident.TripID,
		incident.IncidentType,
		incident.Description,
		incident.ImageURL,
		incident.GpsLat,
		incident.GpsLng,
		incident.IncidentDate,
		incident.CreatedAt,
	)
	return err
}

func (r *IncidentRepository) GetByID(ctx context.Context, incidentID uuid.UUID) (*models.Incident, error) {
	query := `
		SELECT id, driver_id, vehicle_id, trip_id, incident_type, description, image_url, gps_lat, gps_lng, 
		       incident_date, resolved_at, admin_note, created_at
		FROM incidents WHERE id = $1
	`
	incident := &models.Incident{}
	err := r.pool.QueryRow(ctx, query, incidentID).Scan(
		&incident.ID, &incident.DriverID, &incident.VehicleID, &incident.TripID, &incident.IncidentType,
		&incident.Description, &incident.ImageURL, &incident.GpsLat, &incident.GpsLng,
		&incident.IncidentDate, &incident.ResolvedAt, &incident.AdminNote, &incident.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return incident, nil
}

func (r *IncidentRepository) List(ctx context.Context, driverID *uuid.UUID, incidentType *models.IncidentType, tripID *uuid.UUID) ([]*models.Incident, error) {
	query := `
		SELECT id, driver_id, vehicle_id, trip_id, incident_type, description, image_url, gps_lat, gps_lng, 
		       incident_date, resolved_at, admin_note, created_at
		FROM incidents
		WHERE 1=1
	`
	args := []interface{}{}
	argIndex := 1

	if driverID != nil {
		query += fmt.Sprintf(" AND driver_id = $%d", argIndex)
		args = append(args, *driverID)
		argIndex++
	}

	if incidentType != nil {
		query += fmt.Sprintf(" AND incident_type = $%d", argIndex)
		args = append(args, *incidentType)
		argIndex++
	}

	if tripID != nil {
		query += fmt.Sprintf(" AND trip_id = $%d", argIndex)
		args = append(args, *tripID)
		argIndex++
	}

	query += " ORDER BY incident_date DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var incidents []*models.Incident
	for rows.Next() {
		i := &models.Incident{}
		if err := rows.Scan(
			&i.ID, &i.DriverID, &i.VehicleID, &i.TripID, &i.IncidentType,
			&i.Description, &i.ImageURL, &i.GpsLat, &i.GpsLng,
			&i.IncidentDate, &i.ResolvedAt, &i.AdminNote, &i.CreatedAt,
		); err != nil {
			return nil, err
		}
		incidents = append(incidents, i)
	}

	return incidents, nil
}

func (r *IncidentRepository) UpdateAdminNote(ctx context.Context, incidentID uuid.UUID, note string, resolved bool) error {
	var query string
	if resolved {
		query = `UPDATE incidents SET admin_note = $1, resolved_at = $2 WHERE id = $3`
		_, err := r.pool.Exec(ctx, query, note, time.Now(), incidentID)
		return err
	}
	query = `UPDATE incidents SET admin_note = $1 WHERE id = $2`
	_, err := r.pool.Exec(ctx, query, note, incidentID)
	return err
}
