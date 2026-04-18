package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

type PayslipRepository struct {
	db *pgxpool.Pool
}

func NewPayslipRepository(db *pgxpool.Pool) *PayslipRepository {
	return &PayslipRepository{db: db}
}

// List retrieves payslips (filtered by driver and month)
func (r *PayslipRepository) List(ctx context.Context, driverID *uuid.UUID, month *time.Time) ([]models.Payslip, error) {
	query := `
		SELECT p.id, p.driver_id, p.salary_month, p.file_url, p.is_viewed,
		       COALESCE(NULLIF(TRIM(p.status), ''), 'PENDING')::text,
		       p.note, p.confirmed_at, p.created_at,
		       COALESCE(NULLIF(TRIM(u.full_name), ''), '')
		FROM payslips p
		LEFT JOIN users u ON u.id = p.driver_id
		WHERE 1=1
	`
	args := []interface{}{}
	argIndex := 1

	if driverID != nil {
		query += fmt.Sprintf(" AND p.driver_id = $%d", argIndex)
		args = append(args, *driverID)
		argIndex++
	}

	if month != nil {
		query += fmt.Sprintf(" AND DATE_TRUNC('month', p.salary_month) = DATE_TRUNC('month', $%d::date)", argIndex)
		args = append(args, *month)
		argIndex++
	}

	query += " ORDER BY p.salary_month DESC, p.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list payslips: %w", err)
	}
	defer rows.Close()

	payslips := make([]models.Payslip, 0)
	for rows.Next() {
		var p models.Payslip
		var statusStr string
		err := rows.Scan(
			&p.ID, &p.DriverID, &p.SalaryMonth, &p.FileURL, &p.IsViewed,
			&statusStr, &p.Note, &p.ConfirmedAt, &p.CreatedAt,
			&p.DriverFullName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan payslip: %w", err)
		}
		p.Status = models.PayslipStatus(statusStr)
		payslips = append(payslips, p)
	}

	return payslips, nil
}

// Create creates a new payslip
func (r *PayslipRepository) Create(ctx context.Context, payslip *models.Payslip) error {
	query := `
		INSERT INTO payslips (driver_id, salary_month, file_url)
		VALUES ($1, $2, $3)
		RETURNING id, is_viewed, created_at
	`

	err := r.db.QueryRow(ctx, query,
		payslip.DriverID,
		payslip.SalaryMonth,
		payslip.FileURL,
	).Scan(&payslip.ID, &payslip.IsViewed, &payslip.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to create payslip: %w", err)
	}

	return nil
}

// MarkAsViewed marks payslip as viewed
func (r *PayslipRepository) MarkAsViewed(ctx context.Context, id uuid.UUID, driverID uuid.UUID) error {
	query := `
		UPDATE payslips
		SET is_viewed = TRUE, status = COALESCE(NULLIF(status, 'PENDING'), 'VIEWED')
		WHERE id = $1 AND driver_id = $2
	`

	result, err := r.db.Exec(ctx, query, id, driverID)
	if err != nil {
		return fmt.Errorf("failed to mark payslip as viewed: %w", err)
	}

	if result.RowsAffected() == 0 {
		return errors.New("payslip not found or access denied")
	}

	return nil
}

// ConfirmPayslip confirms or complains about a payslip
func (r *PayslipRepository) ConfirmPayslip(ctx context.Context, id uuid.UUID, driverID uuid.UUID, status models.PayslipStatus, note *string) error {
	query := `
		UPDATE payslips
		SET status = $1, note = $2, confirmed_at = $3, is_viewed = TRUE
		WHERE id = $4 AND driver_id = $5
	`

	result, err := r.db.Exec(ctx, query, status, note, time.Now(), id, driverID)
	if err != nil {
		return fmt.Errorf("failed to confirm payslip: %w", err)
	}

	if result.RowsAffected() == 0 {
		return errors.New("payslip not found or access denied")
	}

	return nil
}

// GetByID retrieves a payslip by ID
func (r *PayslipRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Payslip, error) {
	query := `
		SELECT p.id, p.driver_id, p.salary_month, p.file_url, p.is_viewed,
		       COALESCE(NULLIF(TRIM(p.status), ''), 'PENDING')::text,
		       p.note, p.confirmed_at, p.created_at,
		       COALESCE(NULLIF(TRIM(u.full_name), ''), '')
		FROM payslips p
		LEFT JOIN users u ON u.id = p.driver_id
		WHERE p.id = $1
	`
	var p models.Payslip
	var statusStr string
	err := r.db.QueryRow(ctx, query, id).Scan(
		&p.ID, &p.DriverID, &p.SalaryMonth, &p.FileURL, &p.IsViewed,
		&statusStr, &p.Note, &p.ConfirmedAt, &p.CreatedAt,
		&p.DriverFullName,
	)
	if err != nil {
		return nil, err
	}
	p.Status = models.PayslipStatus(statusStr)
	return &p, nil
}
