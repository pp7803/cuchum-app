package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

type NotificationRepository struct {
	pool *pgxpool.Pool
}

func NewNotificationRepository(pool *pgxpool.Pool) *NotificationRepository {
	return &NotificationRepository{pool: pool}
}

// Create inserts a new notification (works for both driver and admin notifications)
func (r *NotificationRepository) Create(ctx context.Context, notification *models.Notification) error {
	query := `
		INSERT INTO notifications (id, title, body, driver_id, is_admin_notification, created_by, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	notification.ID = uuid.New()
	notification.CreatedAt = time.Now()
	notification.IsRead = false

	_, err := r.pool.Exec(ctx, query,
		notification.ID,
		notification.Title,
		notification.Body,
		notification.DriverID,
		notification.IsAdminNotification,
		notification.CreatedBy,
		notification.CreatedAt,
	)
	return err
}

// ListForDriver returns notifications for a specific driver + broadcast (NULL driver_id) notifications
func (r *NotificationRepository) ListForDriver(ctx context.Context, driverID uuid.UUID) ([]*models.Notification, error) {
	query := `
		SELECT id, title, body, driver_id, is_read, is_admin_notification, created_by, created_at
		FROM notifications
		WHERE is_admin_notification = FALSE
		  AND (driver_id = $1 OR driver_id IS NULL)
		ORDER BY created_at DESC
		LIMIT 100
	`
	return r.scan(r.pool.Query(ctx, query, driverID))
}

// ListForAdmin returns admin notifications (system alerts broadcast to all admins)
func (r *NotificationRepository) ListForAdmin(ctx context.Context) ([]*models.Notification, error) {
	query := `
		SELECT id, title, body, driver_id, is_read, is_admin_notification, created_by, created_at
		FROM notifications
		WHERE is_admin_notification = TRUE
		ORDER BY created_at DESC
		LIMIT 200
	`
	return r.scan(r.pool.Query(ctx, query))
}

// ListAll is kept for backward compat (admin GET /notifications)
func (r *NotificationRepository) ListAll(ctx context.Context, driverID *uuid.UUID) ([]*models.Notification, error) {
	if driverID != nil {
		return r.ListForDriver(ctx, *driverID)
	}
	// Admin calling without driver filter → return driver broadcasts
	query := `
		SELECT id, title, body, driver_id, is_read, is_admin_notification, created_by, created_at
		FROM notifications
		WHERE is_admin_notification = FALSE
		ORDER BY created_at DESC
		LIMIT 100
	`
	return r.scan(r.pool.Query(ctx, query))
}

// MarkAsRead marks a notification as read for the given user
func (r *NotificationRepository) MarkAsRead(ctx context.Context, notificationID uuid.UUID, userID uuid.UUID) error {
	// Works for both driver notifications (driver_id match or broadcast) and admin notifications
	query := `
		UPDATE notifications
		SET is_read = TRUE
		WHERE id = $1
		  AND (driver_id = $2 OR driver_id IS NULL OR is_admin_notification = TRUE)
	`
	_, err := r.pool.Exec(ctx, query, notificationID, userID)
	return err
}

// UnreadCount returns the count of unread notifications for a user
func (r *NotificationRepository) UnreadCount(ctx context.Context, userID uuid.UUID, isAdmin bool) (int, error) {
	var query string
	if isAdmin {
		query = `SELECT COUNT(*) FROM notifications WHERE is_admin_notification = TRUE AND is_read = FALSE`
		var count int
		err := r.pool.QueryRow(ctx, query).Scan(&count)
		return count, err
	}
	query = `SELECT COUNT(*) FROM notifications WHERE is_admin_notification = FALSE AND is_read = FALSE AND (driver_id = $1 OR driver_id IS NULL)`
	var count int
	err := r.pool.QueryRow(ctx, query, userID).Scan(&count)
	return count, err
}

// ─── helper ──────────────────────────────────────────────────────────────────

type queryFn func() (interface{ Next() bool; Scan(...any) error; Close(); Err() error }, error)

func (r *NotificationRepository) scan(rows interface {
	Next() bool
	Scan(dest ...any) error
	Close()
	Err() error
}, err error) ([]*models.Notification, error) {
	if err != nil {
		return nil, fmt.Errorf("failed to query notifications: %w", err)
	}
	defer rows.Close()

	var list []*models.Notification
	for rows.Next() {
		n := &models.Notification{}
		if err := rows.Scan(
			&n.ID, &n.Title, &n.Body, &n.DriverID,
			&n.IsRead, &n.IsAdminNotification, &n.CreatedBy, &n.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan notification: %w", err)
		}
		list = append(list, n)
	}
	return list, rows.Err()
}
