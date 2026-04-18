package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DeviceTokenRepository struct {
	db *pgxpool.Pool
}

func NewDeviceTokenRepository(db *pgxpool.Pool) *DeviceTokenRepository {
	return &DeviceTokenRepository{db: db}
}

// SaveToken saves or updates a device FCM token for a user
func (r *DeviceTokenRepository) SaveToken(ctx context.Context, userID uuid.UUID, token string, platform string) error {
	query := `
		INSERT INTO device_tokens (user_id, token, platform, updated_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (user_id, token) 
		DO UPDATE SET platform = $3, updated_at = $4
	`
	_, err := r.db.Exec(ctx, query, userID, token, platform, time.Now())
	if err != nil {
		return fmt.Errorf("failed to save device token: %w", err)
	}
	return nil
}

// DeleteToken removes a device token
func (r *DeviceTokenRepository) DeleteToken(ctx context.Context, userID uuid.UUID, token string) error {
	query := `DELETE FROM device_tokens WHERE user_id = $1 AND token = $2`
	_, err := r.db.Exec(ctx, query, userID, token)
	if err != nil {
		return fmt.Errorf("failed to delete device token: %w", err)
	}
	return nil
}

// DeleteAllTokensForUser removes all tokens for a user (on logout from all devices)
func (r *DeviceTokenRepository) DeleteAllTokensForUser(ctx context.Context, userID uuid.UUID) error {
	query := `DELETE FROM device_tokens WHERE user_id = $1`
	_, err := r.db.Exec(ctx, query, userID)
	if err != nil {
		return fmt.Errorf("failed to delete all device tokens: %w", err)
	}
	return nil
}

// GetTokensForUser returns all FCM tokens for a user
func (r *DeviceTokenRepository) GetTokensForUser(ctx context.Context, userID uuid.UUID) ([]string, error) {
	query := `SELECT token FROM device_tokens WHERE user_id = $1`
	rows, err := r.db.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get device tokens: %w", err)
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, fmt.Errorf("failed to scan token: %w", err)
		}
		tokens = append(tokens, token)
	}
	return tokens, nil
}

// GetTokensForUsers returns all FCM tokens for multiple users
func (r *DeviceTokenRepository) GetTokensForUsers(ctx context.Context, userIDs []uuid.UUID) ([]string, error) {
	if len(userIDs) == 0 {
		return []string{}, nil
	}

	query := `SELECT token FROM device_tokens WHERE user_id = ANY($1)`
	rows, err := r.db.Query(ctx, query, userIDs)
	if err != nil {
		return nil, fmt.Errorf("failed to get device tokens: %w", err)
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, fmt.Errorf("failed to scan token: %w", err)
		}
		tokens = append(tokens, token)
	}
	return tokens, nil
}

// GetAllAdminTokens returns FCM tokens for all active admins
func (r *DeviceTokenRepository) GetAllAdminTokens(ctx context.Context) ([]string, error) {
	query := `
		SELECT dt.token 
		FROM device_tokens dt
		JOIN users u ON dt.user_id = u.id
		WHERE u.role = 'ADMIN' AND u.status = 'ACTIVE'
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to get admin tokens: %w", err)
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, fmt.Errorf("failed to scan token: %w", err)
		}
		tokens = append(tokens, token)
	}
	return tokens, nil
}

// GetAllDriverTokens returns FCM tokens for all active drivers
func (r *DeviceTokenRepository) GetAllDriverTokens(ctx context.Context) ([]string, error) {
	query := `
		SELECT dt.token 
		FROM device_tokens dt
		JOIN users u ON dt.user_id = u.id
		WHERE u.role = 'DRIVER' AND u.status = 'ACTIVE'
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to get driver tokens: %w", err)
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, fmt.Errorf("failed to scan token: %w", err)
		}
		tokens = append(tokens, token)
	}
	return tokens, nil
}
