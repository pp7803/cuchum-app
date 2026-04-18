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

// ProfileUpdateRequestRepository handles profile update request persistence
type ProfileUpdateRequestRepository struct {
	db *pgxpool.Pool
}

// NewProfileUpdateRequestRepository creates a new repository
func NewProfileUpdateRequestRepository(db *pgxpool.Pool) *ProfileUpdateRequestRepository {
	return &ProfileUpdateRequestRepository{db: db}
}

// Upsert creates a new PENDING request or replaces the existing PENDING one for a user.
// Since only one PENDING request is allowed per user, we delete the old one first.
func (r *ProfileUpdateRequestRepository) Upsert(
	ctx context.Context,
	userID uuid.UUID,
	req *models.UpdateProfileRequest,
) (*models.ProfileUpdateRequest, error) {
	// Delete existing PENDING request for this user (if any)
	_, err := r.db.Exec(ctx,
		`DELETE FROM profile_update_requests WHERE user_id = $1 AND status = 'PENDING'`,
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to clear existing pending request: %w", err)
	}

	// Insert new PENDING request
	pur := &models.ProfileUpdateRequest{}
	insertQuery := `
		INSERT INTO profile_update_requests (user_id, citizen_id, license_class, license_number, address, avatar_url, proof_image_url, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, 'PENDING')
		RETURNING id, user_id, citizen_id, license_class, license_number, address, avatar_url, proof_image_url,
		          status, admin_note, reviewed_by, reviewed_at, created_at, updated_at`

	err = r.db.QueryRow(ctx, insertQuery,
		userID,
		req.CitizenID,
		req.LicenseClass,
		req.LicenseNumber,
		req.Address,
		req.AvatarURL,
		req.ProofImageURL,
	).Scan(
		&pur.ID, &pur.UserID, &pur.CitizenID, &pur.LicenseClass, &pur.LicenseNumber,
		&pur.Address, &pur.AvatarURL, &pur.ProofImageURL, &pur.Status,
		&pur.AdminNote, &pur.ReviewedBy, &pur.ReviewedAt,
		&pur.CreatedAt, &pur.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create profile update request: %w", err)
	}

	return pur, nil
}

// FindPendingByUserID returns the current PENDING request for a user (nil if none)
func (r *ProfileUpdateRequestRepository) FindPendingByUserID(ctx context.Context, userID uuid.UUID) (*models.ProfileUpdateRequest, error) {
	pur := &models.ProfileUpdateRequest{}
	query := `
		SELECT id, user_id, citizen_id, license_class, license_number, address, avatar_url, proof_image_url,
		       status, admin_note, reviewed_by, reviewed_at, created_at, updated_at
		FROM profile_update_requests
		WHERE user_id = $1 AND status = 'PENDING'
		ORDER BY created_at DESC
		LIMIT 1`

	err := r.db.QueryRow(ctx, query, userID).Scan(
		&pur.ID, &pur.UserID, &pur.CitizenID, &pur.LicenseClass, &pur.LicenseNumber,
		&pur.Address, &pur.AvatarURL, &pur.ProofImageURL, &pur.Status,
		&pur.AdminNote, &pur.ReviewedBy, &pur.ReviewedAt,
		&pur.CreatedAt, &pur.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get pending request: %w", err)
	}
	return pur, nil
}

// FindByID returns a request by ID
func (r *ProfileUpdateRequestRepository) FindByID(ctx context.Context, id uuid.UUID) (*models.ProfileUpdateRequest, error) {
	pur := &models.ProfileUpdateRequest{}
	query := `
		SELECT pur.id, pur.user_id, u.full_name,
		       pur.citizen_id, pur.license_class, pur.license_number, pur.address, pur.avatar_url, pur.proof_image_url,
		       pur.status, pur.admin_note, pur.reviewed_by, pur.reviewed_at,
		       pur.created_at, pur.updated_at
		FROM profile_update_requests pur
		JOIN users u ON u.id = pur.user_id
		WHERE pur.id = $1`

	err := r.db.QueryRow(ctx, query, id).Scan(
		&pur.ID, &pur.UserID, &pur.DriverName,
		&pur.CitizenID, &pur.LicenseClass, &pur.LicenseNumber, &pur.Address, &pur.AvatarURL, &pur.ProofImageURL,
		&pur.Status, &pur.AdminNote, &pur.ReviewedBy, &pur.ReviewedAt,
		&pur.CreatedAt, &pur.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get request: %w", err)
	}
	return pur, nil
}

// CountByStatus returns total count of requests matching the given status
func (r *ProfileUpdateRequestRepository) CountByStatus(ctx context.Context, status string) (int, error) {
	var count int
	query := `SELECT COUNT(*) FROM profile_update_requests WHERE ($1 = '' OR status = $1)`
	err := r.db.QueryRow(ctx, query, status).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed to count requests: %w", err)
	}
	return count, nil
}

// ListByStatus returns requests filtered by status with pagination (admin)
func (r *ProfileUpdateRequestRepository) ListByStatus(ctx context.Context, status string, page, limit int) ([]*models.ProfileUpdateRequest, error) {
	offset := (page - 1) * limit
	query := `
		SELECT pur.id, pur.user_id, u.full_name,
		       pur.citizen_id, pur.license_class, pur.license_number, pur.address, pur.avatar_url, pur.proof_image_url,
		       pur.status, pur.admin_note, pur.reviewed_by, pur.reviewed_at,
		       pur.created_at, pur.updated_at
		FROM profile_update_requests pur
		JOIN users u ON u.id = pur.user_id
		WHERE ($1 = '' OR pur.status = $1)
		ORDER BY pur.created_at DESC
		LIMIT $2 OFFSET $3`

	rows, err := r.db.Query(ctx, query, status, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to list requests: %w", err)
	}
	defer rows.Close()

	var list []*models.ProfileUpdateRequest
	for rows.Next() {
		pur := &models.ProfileUpdateRequest{}
		if err := rows.Scan(
			&pur.ID, &pur.UserID, &pur.DriverName,
			&pur.CitizenID, &pur.LicenseClass, &pur.LicenseNumber, &pur.Address, &pur.AvatarURL, &pur.ProofImageURL,
			&pur.Status, &pur.AdminNote, &pur.ReviewedBy, &pur.ReviewedAt,
			&pur.CreatedAt, &pur.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan request: %w", err)
		}
		list = append(list, pur)
	}
	return list, nil
}

// Review approves or rejects a request; on APPROVED it returns the data to apply to profile
func (r *ProfileUpdateRequestRepository) Review(
	ctx context.Context,
	id uuid.UUID,
	reviewerID uuid.UUID,
	status models.ProfileUpdateStatus,
	adminNote *string,
) (*models.ProfileUpdateRequest, error) {
	pur := &models.ProfileUpdateRequest{}
	query := `
		UPDATE profile_update_requests
		SET status      = $1,
		    admin_note  = $2,
		    reviewed_by = $3,
		    reviewed_at = NOW(),
		    updated_at  = NOW()
		WHERE id = $4 AND status = 'PENDING'
		RETURNING id, user_id, citizen_id, license_class, license_number, address, avatar_url, proof_image_url,
		          status, admin_note, reviewed_by, reviewed_at, created_at, updated_at`

	err := r.db.QueryRow(ctx, query, status, adminNote, reviewerID, id).Scan(
		&pur.ID, &pur.UserID, &pur.CitizenID, &pur.LicenseClass, &pur.LicenseNumber,
		&pur.Address, &pur.AvatarURL, &pur.ProofImageURL, &pur.Status,
		&pur.AdminNote, &pur.ReviewedBy, &pur.ReviewedAt,
		&pur.CreatedAt, &pur.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("request not found or already reviewed")
		}
		return nil, fmt.Errorf("failed to review request: %w", err)
	}
	return pur, nil
}
