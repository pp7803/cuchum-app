package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

type OTPRepository struct {
	db *pgxpool.Pool
}

func NewOTPRepository(db *pgxpool.Pool) *OTPRepository {
	return &OTPRepository{db: db}
}

// Create creates a new OTP record
func (r *OTPRepository) Create(ctx context.Context, otp *models.PasswordResetOTP) error {
	query := `
		INSERT INTO password_reset_otps (id, user_id, email, otp_code, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.db.Exec(ctx, query,
		otp.ID,
		otp.UserID,
		otp.Email,
		otp.OTPCode,
		otp.ExpiresAt,
		otp.CreatedAt,
	)
	return err
}

// FindValidOTP finds a valid (not expired, not used) OTP for an email
func (r *OTPRepository) FindValidOTP(ctx context.Context, email, otpCode string) (*models.PasswordResetOTP, error) {
	query := `
		SELECT id, user_id, email, otp_code, expires_at, used_at, created_at
		FROM password_reset_otps
		WHERE email = $1 AND otp_code = $2 AND expires_at > $3 AND used_at IS NULL
		ORDER BY created_at DESC
		LIMIT 1
	`

	var otp models.PasswordResetOTP
	err := r.db.QueryRow(ctx, query, email, otpCode, time.Now()).Scan(
		&otp.ID,
		&otp.UserID,
		&otp.Email,
		&otp.OTPCode,
		&otp.ExpiresAt,
		&otp.UsedAt,
		&otp.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &otp, nil
}

// MarkAsUsed marks an OTP as used
func (r *OTPRepository) MarkAsUsed(ctx context.Context, otpID uuid.UUID) error {
	query := `UPDATE password_reset_otps SET used_at = $1 WHERE id = $2`
	_, err := r.db.Exec(ctx, query, time.Now(), otpID)
	return err
}

// InvalidatePreviousOTPs invalidates all previous OTPs for an email
func (r *OTPRepository) InvalidatePreviousOTPs(ctx context.Context, email string) error {
	query := `UPDATE password_reset_otps SET used_at = $1 WHERE email = $2 AND used_at IS NULL`
	_, err := r.db.Exec(ctx, query, time.Now(), email)
	return err
}
