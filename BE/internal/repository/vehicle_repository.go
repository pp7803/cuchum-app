package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

type VehicleRepository struct {
	db *pgxpool.Pool
}

func NewVehicleRepository(db *pgxpool.Pool) *VehicleRepository {
	return &VehicleRepository{db: db}
}

func scanVehicle(row interface{ Scan(dest ...any) error }) (*models.Vehicle, error) {
	var v models.Vehicle
	var ins, reg, last, next sql.NullTime
	var img sql.NullString
	err := row.Scan(
		&v.ID, &v.LicensePlate, &v.VehicleType, &v.Status, &img,
		&ins, &reg, &last, &next,
	)
	if err != nil {
		return nil, err
	}
	v.ImageURL = nullStringPtr(img)
	v.InsuranceExpiry = nullTimePtr(ins)
	v.RegistrationExpiry = nullTimePtr(reg)
	v.LastMaintenanceDate = nullTimePtr(last)
	v.NextMaintenanceDate = nullTimePtr(next)
	return &v, nil
}

// List retrieves vehicles with optional status filter
func (r *VehicleRepository) List(ctx context.Context, status string) ([]models.Vehicle, error) {
	query := `
		SELECT id, license_plate, vehicle_type, status, image_url,
		       insurance_expiry, registration_expiry, last_maintenance_date, next_maintenance_date
		FROM vehicles
		WHERE 1=1
	`
	args := []interface{}{}

	if status != "" {
		query += " AND status = $1"
		args = append(args, status)
	}

	query += " ORDER BY license_plate"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list vehicles: %w", err)
	}
	defer rows.Close()

	vehicles := make([]models.Vehicle, 0)
	for rows.Next() {
		v, err := scanVehicle(rows)
		if err != nil {
			return nil, fmt.Errorf("failed to scan vehicle: %w", err)
		}
		vehicles = append(vehicles, *v)
	}

	return vehicles, nil
}

// GetMaintenance retrieves maintenance information for a vehicle
func (r *VehicleRepository) GetMaintenance(ctx context.Context, vehicleID uuid.UUID) (*models.VehicleMaintenance, error) {
	query := `
		SELECT id, license_plate, image_url, insurance_expiry, registration_expiry, last_maintenance_date, next_maintenance_date
		FROM vehicles WHERE id = $1
	`
	m := &models.VehicleMaintenance{}
	var ins, reg, last, next sql.NullTime
	var img sql.NullString
	err := r.db.QueryRow(ctx, query, vehicleID).Scan(
		&m.VehicleID, &m.LicensePlate, &img, &ins, &reg, &last, &next,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get vehicle maintenance: %w", err)
	}
	m.ImageURL = nullStringPtr(img)
	m.InsuranceExpiry = nullTimePtr(ins)
	m.RegistrationExpiry = nullTimePtr(reg)
	m.LastMaintenanceDate = nullTimePtr(last)
	m.NextMaintenanceDate = nullTimePtr(next)
	return m, nil
}

// GetByID retrieves a vehicle by ID
func (r *VehicleRepository) GetByID(ctx context.Context, vehicleID uuid.UUID) (*models.Vehicle, error) {
	query := `
		SELECT id, license_plate, vehicle_type, status, image_url,
		       insurance_expiry, registration_expiry, last_maintenance_date, next_maintenance_date
		FROM vehicles WHERE id = $1`
	row := r.db.QueryRow(ctx, query, vehicleID)
	return scanVehicle(row)
}

// Create inserts a new vehicle
func (r *VehicleRepository) Create(ctx context.Context, v *models.Vehicle) error {
	query := `
		INSERT INTO vehicles (id, license_plate, vehicle_type, status, image_url,
			insurance_expiry, registration_expiry, last_maintenance_date, next_maintenance_date)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	v.ID = uuid.New()
	if v.Status == "" {
		v.Status = "ACTIVE"
	}
	_, err := r.db.Exec(ctx, query,
		v.ID, v.LicensePlate, v.VehicleType, v.Status, v.ImageURL,
		v.InsuranceExpiry, v.RegistrationExpiry, v.LastMaintenanceDate, v.NextMaintenanceDate,
	)
	return err
}

// Update patches vehicle fields; nil pointer = giữ nguyên cột
func (r *VehicleRepository) Update(ctx context.Context, id uuid.UUID,
	licensePlate, vehicleType, status, imageURL *string,
	insuranceExpiry, registrationExpiry, lastMaintenanceDate, nextMaintenanceDate *time.Time,
) error {
	res, err := r.db.Exec(ctx, `
		UPDATE vehicles SET
			license_plate = COALESCE($2, license_plate),
			vehicle_type = COALESCE($3, vehicle_type),
			status = COALESCE($4, status),
			image_url = COALESCE($5, image_url),
			insurance_expiry = COALESCE($6, insurance_expiry),
			registration_expiry = COALESCE($7, registration_expiry),
			last_maintenance_date = COALESCE($8, last_maintenance_date),
			next_maintenance_date = COALESCE($9, next_maintenance_date)
		WHERE id = $1`,
		id, licensePlate, vehicleType, status, imageURL,
		insuranceExpiry, registrationExpiry, lastMaintenanceDate, nextMaintenanceDate,
	)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("vehicle not found")
	}
	return nil
}

// Delete removes a vehicle row
func (r *VehicleRepository) Delete(ctx context.Context, id uuid.UUID) error {
	res, err := r.db.Exec(ctx, `DELETE FROM vehicles WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("vehicle not found")
	}
	return nil
}
