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

type TripRepository struct {
	pool *pgxpool.Pool
}

func NewTripRepository(pool *pgxpool.Pool) *TripRepository {
	return &TripRepository{pool: pool}
}

func nullTimePtr(nt sql.NullTime) *time.Time {
	if !nt.Valid {
		return nil
	}
	t := nt.Time
	return &t
}

func nullStringPtr(ns sql.NullString) *string {
	if !ns.Valid {
		return nil
	}
	s := ns.String
	return &s
}

func scanTrip(row interface {
	Scan(dest ...any) error
},
) (*models.Trip, error) {
	var (
		t                                         models.Trip
		schedStart, schedEnd, cancelledAt, st, et sql.NullTime
		dn, dd, acr                               sql.NullString
		n10, nStart, nLate                        sql.NullTime
	)
	err := row.Scan(
		&t.ID, &t.DriverID, &t.VehicleID, &t.Status,
		&schedStart, &schedEnd, &dn, &dd, &acr, &cancelledAt,
		&st, &et, &t.StartOdo, &t.EndOdo,
		&t.StartLat, &t.StartLng, &t.EndLat, &t.EndLng,
		&t.DistanceKm, &t.CreatedAt,
		&n10, &nStart, &nLate,
	)
	if err != nil {
		return nil, err
	}
	t.ScheduledStartAt = nullTimePtr(schedStart)
	t.ScheduledEndAt = nullTimePtr(schedEnd)
	t.DriverNote = nullStringPtr(dn)
	t.DriverDeclineNote = nullStringPtr(dd)
	t.AdminCancelReason = nullStringPtr(acr)
	t.CancelledAt = nullTimePtr(cancelledAt)
	t.StartTime = nullTimePtr(st)
	t.EndTime = nullTimePtr(et)
	t.NotifyDeparture10mSentAt = nullTimePtr(n10)
	t.NotifyDepartureStartSentAt = nullTimePtr(nStart)
	t.NotifyDepartureLateSentAt = nullTimePtr(nLate)
	return &t, nil
}

const tripSelectCols = `
		id, driver_id, vehicle_id, status,
		scheduled_start_at, scheduled_end_at, driver_note, driver_decline_note, admin_cancel_reason, cancelled_at,
		start_time, end_time, start_odo, end_odo,
		start_lat, start_lng, end_lat, end_lng, distance_km, created_at,
		notify_departure_10m_sent_at, notify_departure_start_sent_at, notify_departure_late_sent_at`

// Create starts an ad-hoc trip (driver) — IN_PROGRESS ngay lập tức
func (r *TripRepository) Create(ctx context.Context, trip *models.Trip) error {
	query := `
		INSERT INTO trips (id, driver_id, vehicle_id, status, start_time, start_odo, start_lat, start_lng, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	trip.ID = uuid.New()
	trip.Status = models.TripInProgress
	now := time.Now()
	trip.StartTime = &now
	trip.CreatedAt = now

	_, err := r.pool.Exec(ctx, query,
		trip.ID,
		trip.DriverID,
		trip.VehicleID,
		trip.Status,
		now,
		trip.StartOdo,
		trip.StartLat,
		trip.StartLng,
		trip.CreatedAt,
	)
	return err
}

// CreateScheduled — ADMIN: chuyến chờ tài xế xác nhận
func (r *TripRepository) CreateScheduled(ctx context.Context, trip *models.Trip) error {
	// start_time must stay NULL until the driver calls StartScheduledTrip; the column had
	// DEFAULT CURRENT_TIMESTAMP in legacy schema, so we insert NULL explicitly.
	query := `
		INSERT INTO trips (id, driver_id, vehicle_id, status,
			scheduled_start_at, scheduled_end_at, driver_note, created_at, start_time)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NULL)
	`
	trip.ID = uuid.New()
	trip.Status = models.TripScheduledPending
	trip.CreatedAt = time.Now()

	_, err := r.pool.Exec(ctx, query,
		trip.ID,
		trip.DriverID,
		trip.VehicleID,
		trip.Status,
		trip.ScheduledStartAt,
		trip.ScheduledEndAt,
		trip.DriverNote,
		trip.CreatedAt,
	)
	return err
}

// RespondToScheduledTrip — DRIVER chấp nhận / từ chối
func (r *TripRepository) RespondToScheduledTrip(ctx context.Context, tripID, driverID uuid.UUID, status models.TripStatus, declineNote *string) error {
	var q string
	var args []interface{}
	switch status {
	case models.TripDriverAccepted:
		q = `UPDATE trips SET status = $1, driver_decline_note = NULL WHERE id = $2 AND driver_id = $3 AND status = $4`
		args = []interface{}{models.TripDriverAccepted, tripID, driverID, models.TripScheduledPending}
	case models.TripDriverDeclined:
		q = `UPDATE trips SET status = $1, driver_decline_note = $2 WHERE id = $3 AND driver_id = $4 AND status = $5`
		args = []interface{}{models.TripDriverDeclined, declineNote, tripID, driverID, models.TripScheduledPending}
	default:
		return fmt.Errorf("invalid respond status")
	}
	res, err := r.pool.Exec(ctx, q, args...)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("trip not found or not awaiting response")
	}
	return nil
}

// StartScheduledTrip — DRIVER bắt đầu chạy (sau DRIVER_ACCEPTED)
func (r *TripRepository) StartScheduledTrip(ctx context.Context, tripID, driverID uuid.UUID, startOdo *int, startLat, startLng *float64) error {
	now := time.Now()
	q := `
		UPDATE trips
		SET status = $1, start_time = $2, start_odo = $3, start_lat = $4, start_lng = $5
		WHERE id = $6 AND driver_id = $7 AND status = $8
	`
	res, err := r.pool.Exec(ctx, q,
		models.TripInProgress, now, startOdo, startLat, startLng,
		tripID, driverID, models.TripDriverAccepted,
	)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("trip not found, not assigned to you, or not accepted yet")
	}
	return nil
}

func (r *TripRepository) EndTrip(ctx context.Context, tripID uuid.UUID, endOdo *int, endLat, endLng *float64) error {
	endTime := time.Now()

	// Cast nullable params ($3–$5) so PostgreSQL infers types when values are NULL (42P08).
	query := `
		UPDATE trips 
		SET status = $1, end_time = $2, end_odo = $3::integer, end_lat = $4::double precision, end_lng = $5::double precision,
		    distance_km = CASE 
		        WHEN start_odo IS NOT NULL AND $3::integer IS NOT NULL 
		        THEN ROUND(($3::integer - start_odo)::numeric, 2)
		        ELSE NULL 
		    END
		WHERE id = $6 AND status = 'IN_PROGRESS'
	`

	result, err := r.pool.Exec(ctx, query,
		models.TripCompleted,
		endTime,
		endOdo,
		endLat,
		endLng,
		tripID,
	)
	if err != nil {
		return err
	}

	if result.RowsAffected() == 0 {
		return fmt.Errorf("trip not found or already completed")
	}

	return nil
}

// AdminCancelTrip sets status CANCELLED and stores reason; only SCHEDULED_PENDING / DRIVER_ACCEPTED (see service rules).
func (r *TripRepository) AdminCancelTrip(ctx context.Context, tripID uuid.UUID, reason string) error {
	q := `
		UPDATE trips
		SET status = $1,
		    admin_cancel_reason = $2,
		    cancelled_at = NOW()
		WHERE id = $3
		  AND status IN ('SCHEDULED_PENDING', 'DRIVER_ACCEPTED')
	`
	res, err := r.pool.Exec(ctx, q, models.TripCancelled, reason, tripID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("trip not found or cannot be cancelled")
	}
	return nil
}

func (r *TripRepository) GetByID(ctx context.Context, tripID uuid.UUID) (*models.Trip, error) {
	query := `SELECT ` + tripSelectCols + ` FROM trips WHERE id = $1`
	row := r.pool.QueryRow(ctx, query, tripID)
	return scanTrip(row)
}

func (r *TripRepository) List(ctx context.Context, driverID *uuid.UUID, vehicleID *uuid.UUID, status *models.TripStatus, startDate, endDate string) ([]*models.Trip, error) {
	query := `SELECT ` + tripSelectCols + ` FROM trips WHERE 1=1`
	args := []interface{}{}
	argIndex := 1

	if driverID != nil {
		query += fmt.Sprintf(" AND driver_id = $%d", argIndex)
		args = append(args, *driverID)
		argIndex++
	}

	if vehicleID != nil {
		query += fmt.Sprintf(" AND vehicle_id = $%d", argIndex)
		args = append(args, *vehicleID)
		argIndex++
	}

	if status != nil {
		query += fmt.Sprintf(" AND status = $%d", argIndex)
		args = append(args, *status)
		argIndex++
	}

	if startDate != "" {
		query += fmt.Sprintf(" AND DATE(COALESCE(start_time, scheduled_start_at)) >= $%d", argIndex)
		args = append(args, startDate)
		argIndex++
	}

	if endDate != "" {
		query += fmt.Sprintf(" AND DATE(COALESCE(start_time, scheduled_start_at)) <= $%d", argIndex)
		args = append(args, endDate)
		argIndex++
	}

	query += " ORDER BY COALESCE(start_time, scheduled_start_at, created_at) DESC NULLS LAST"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var trips []*models.Trip
	for rows.Next() {
		t, err := scanTrip(rows)
		if err != nil {
			return nil, err
		}
		trips = append(trips, t)
	}

	return trips, nil
}

func (r *TripRepository) GetActiveTrip(ctx context.Context, driverID uuid.UUID) (*models.Trip, error) {
	query := `SELECT ` + tripSelectCols + ` FROM trips 
		WHERE driver_id = $1 AND status = 'IN_PROGRESS'
		ORDER BY start_time DESC NULLS LAST LIMIT 1`
	row := r.pool.QueryRow(ctx, query, driverID)
	return scanTrip(row)
}

// HasBlockingTripsForVehicleDeletion returns true if the vehicle must not be deleted:
//   - any IN_PROGRESS trip, or
//   - any SCHEDULED_PENDING / DRIVER_ACCEPTED trip whose scheduled window is not entirely before `now`
//     (i.e. no scheduled_end_at, or scheduled_end_at >= now). Trips with scheduled_end_at < now are ignored.
//
// COMPLETED, CANCELLED, DRIVER_DECLINED never block.
func (r *TripRepository) HasBlockingTripsForVehicleDeletion(ctx context.Context, vehicleID uuid.UUID, now time.Time) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM trips
			WHERE vehicle_id = $1
			AND (
				status = 'IN_PROGRESS'
				OR (
					status IN ('SCHEDULED_PENDING', 'DRIVER_ACCEPTED')
					AND NOT (
						scheduled_end_at IS NOT NULL
						AND scheduled_end_at < $2
					)
				)
			)
		)
	`, vehicleID, now).Scan(&exists)
	if err != nil {
		return false, err
	}
	return exists, nil
}

// ListTripsOccupyingVehicleForSchedule returns trips that reserve the vehicle for scheduling checks:
// IN_PROGRESS, SCHEDULED_PENDING, DRIVER_ACCEPTED (with scheduled_start_at set for the latter two).
func (r *TripRepository) ListTripsOccupyingVehicleForSchedule(ctx context.Context, vehicleID uuid.UUID) ([]*models.Trip, error) {
	query := `SELECT ` + tripSelectCols + ` FROM trips
		WHERE vehicle_id = $1
		  AND (
		    status = 'IN_PROGRESS'
		    OR (status IN ('SCHEDULED_PENDING', 'DRIVER_ACCEPTED') AND scheduled_start_at IS NOT NULL)
		  )`
	rows, err := r.pool.Query(ctx, query, vehicleID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var trips []*models.Trip
	for rows.Next() {
		t, err := scanTrip(rows)
		if err != nil {
			return nil, err
		}
		trips = append(trips, t)
	}
	return trips, nil
}

// ListDriverAcceptedScheduledTrips returns accepted trips with a scheduled start (for departure cron).
func (r *TripRepository) ListDriverAcceptedScheduledTrips(ctx context.Context) ([]*models.Trip, error) {
	q := `SELECT ` + tripSelectCols + ` FROM trips
		WHERE status = 'DRIVER_ACCEPTED' AND scheduled_start_at IS NOT NULL`
	rows, err := r.pool.Query(ctx, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var trips []*models.Trip
	for rows.Next() {
		t, err := scanTrip(rows)
		if err != nil {
			return nil, err
		}
		trips = append(trips, t)
	}
	return trips, nil
}

func (r *TripRepository) TryMarkDepartureNotify10m(ctx context.Context, tripID uuid.UUID) (bool, error) {
	res, err := r.pool.Exec(ctx, `
		UPDATE trips SET notify_departure_10m_sent_at = $2
		WHERE id = $1 AND status = 'DRIVER_ACCEPTED' AND notify_departure_10m_sent_at IS NULL`,
		tripID, time.Now())
	if err != nil {
		return false, err
	}
	return res.RowsAffected() > 0, nil
}

func (r *TripRepository) TryMarkDepartureNotifyStart(ctx context.Context, tripID uuid.UUID) (bool, error) {
	res, err := r.pool.Exec(ctx, `
		UPDATE trips SET notify_departure_start_sent_at = $2
		WHERE id = $1 AND status = 'DRIVER_ACCEPTED' AND notify_departure_start_sent_at IS NULL`,
		tripID, time.Now())
	if err != nil {
		return false, err
	}
	return res.RowsAffected() > 0, nil
}

func (r *TripRepository) TryMarkDepartureNotifyLate(ctx context.Context, tripID uuid.UUID) (bool, error) {
	res, err := r.pool.Exec(ctx, `
		UPDATE trips SET notify_departure_late_sent_at = $2
		WHERE id = $1 AND status = 'DRIVER_ACCEPTED' AND notify_departure_late_sent_at IS NULL`,
		tripID, time.Now())
	if err != nil {
		return false, err
	}
	return res.RowsAffected() > 0, nil
}

// AutoCancelStaleDriverAccepted cancels DRIVER_ACCEPTED trips whose scheduled start was over `grace` ago.
func (r *TripRepository) AutoCancelStaleDriverAccepted(ctx context.Context, now time.Time, grace time.Duration, reason string) ([]uuid.UUID, error) {
	rows, err := r.pool.Query(ctx, `
		WITH sel AS (
			SELECT id, driver_id FROM trips
			WHERE status = 'DRIVER_ACCEPTED'
			  AND scheduled_start_at IS NOT NULL
			  AND scheduled_start_at + ($3::bigint * INTERVAL '1 second') < $1::timestamptz
		)
		UPDATE trips AS t
		SET status = 'CANCELLED', admin_cancel_reason = $2, cancelled_at = NOW()
		FROM sel
		WHERE t.id = sel.id
		RETURNING sel.driver_id`,
		now, reason, int64(grace.Seconds()))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var drivers []uuid.UUID
	for rows.Next() {
		var did uuid.UUID
		if err := rows.Scan(&did); err != nil {
			return nil, err
		}
		drivers = append(drivers, did)
	}
	return drivers, nil
}
