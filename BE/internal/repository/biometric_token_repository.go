package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

// BiometricTokenRepository handles biometric token persistence
type BiometricTokenRepository struct {
	pool *pgxpool.Pool
}

// NewBiometricTokenRepository creates a new biometric token repository
func NewBiometricTokenRepository(pool *pgxpool.Pool) *BiometricTokenRepository {
	return &BiometricTokenRepository{pool: pool}
}

// Upsert creates or replaces the biometric token for a user (one active token per user)
func (r *BiometricTokenRepository) Upsert(ctx context.Context, userID uuid.UUID, token string, expiresAt time.Time) (*models.BiometricToken, error) {
	bt := &models.BiometricToken{}
	query := `
		INSERT INTO biometric_tokens (user_id, token, expires_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id) DO UPDATE
			SET token      = EXCLUDED.token,
			    expires_at = EXCLUDED.expires_at,
			    updated_at = NOW()
		RETURNING id, user_id, token, expires_at, created_at, updated_at`

	err := r.pool.QueryRow(ctx, query, userID, token, expiresAt).Scan(
		&bt.ID, &bt.UserID, &bt.Token, &bt.ExpiresAt, &bt.CreatedAt, &bt.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return bt, nil
}

// FindByToken finds a valid (non-expired) biometric token
func (r *BiometricTokenRepository) FindByToken(ctx context.Context, token string) (*models.BiometricToken, error) {
	bt := &models.BiometricToken{}
	query := `
		SELECT id, user_id, token, expires_at, created_at, updated_at
		FROM biometric_tokens
		WHERE token = $1 AND expires_at > NOW()`

	err := r.pool.QueryRow(ctx, query, token).Scan(
		&bt.ID, &bt.UserID, &bt.Token, &bt.ExpiresAt, &bt.CreatedAt, &bt.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return bt, nil
}

// DeleteByUserID removes the biometric token for a user (disable biometric)
func (r *BiometricTokenRepository) DeleteByUserID(ctx context.Context, userID uuid.UUID) error {
	query := `DELETE FROM biometric_tokens WHERE user_id = $1`
	_, err := r.pool.Exec(ctx, query, userID)
	return err
}

// ExistsForUser checks whether the user has an active (non-expired) biometric token
func (r *BiometricTokenRepository) ExistsForUser(ctx context.Context, userID uuid.UUID) (bool, error) {
	var count int
	query := `SELECT COUNT(*) FROM biometric_tokens WHERE user_id = $1 AND expires_at > NOW()`
	err := r.pool.QueryRow(ctx, query, userID).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, nil
}
