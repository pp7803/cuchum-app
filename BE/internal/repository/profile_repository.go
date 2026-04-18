package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)


type ProfileRepository struct {
	db *pgxpool.Pool
}

func NewProfileRepository(db *pgxpool.Pool) *ProfileRepository {
	return &ProfileRepository{db: db}
}

func (r *ProfileRepository) GetByUserID(ctx context.Context, userID uuid.UUID) (*models.DriverProfile, error) {
	query := `
SELECT user_id, citizen_id, license_class, license_number, address, avatar_url
FROM driver_profiles
WHERE user_id = $1
`

	var profile models.DriverProfile
	err := r.db.QueryRow(ctx, query, userID).Scan(
		&profile.UserID,
		&profile.CitizenID,
		&profile.LicenseClass,
		&profile.LicenseNumber,
		&profile.Address,
		&profile.AvatarURL,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get profile: %w", err)
	}

	return &profile, nil
}

func (r *ProfileRepository) Update(ctx context.Context, userID uuid.UUID, profile *models.UpdateProfileRequest) error {
	// UPSERT: creates the row if it doesn't exist (e.g. admin users), otherwise merges
	query := `
INSERT INTO driver_profiles (user_id, address, license_class, license_number, avatar_url, citizen_id)
VALUES ($6, $1, $2, $3, $4, $5)
ON CONFLICT (user_id) DO UPDATE
SET address         = COALESCE(EXCLUDED.address,         driver_profiles.address),
    license_class   = COALESCE(EXCLUDED.license_class,   driver_profiles.license_class),
    license_number  = COALESCE(EXCLUDED.license_number, driver_profiles.license_number),
    avatar_url      = COALESCE(EXCLUDED.avatar_url,      driver_profiles.avatar_url),
    citizen_id      = COALESCE(EXCLUDED.citizen_id,      driver_profiles.citizen_id)
`
	_, err := r.db.Exec(ctx, query,
		profile.Address,
		profile.LicenseClass,
		profile.LicenseNumber,
		profile.AvatarURL,
		profile.CitizenID,
		userID,
	)
	if err != nil {
		return fmt.Errorf("failed to upsert profile: %w", err)
	}
	return nil
}
