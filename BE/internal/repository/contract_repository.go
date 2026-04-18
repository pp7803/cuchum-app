package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/tsnn/ch-app/internal/models"
)

type ContractRepository struct {
	db *pgxpool.Pool
}

func NewContractRepository(db *pgxpool.Pool) *ContractRepository {
	return &ContractRepository{db: db}
}

// List retrieves contracts (filtered by driver for non-admin). Optional ackFilter limits by acknowledgment_status (admin).
func (r *ContractRepository) List(ctx context.Context, driverID *uuid.UUID, ackFilter *models.ContractAcknowledgmentStatus) ([]models.Contract, error) {
	query := `
		SELECT c.id, c.driver_id, c.contract_number, c.file_url, c.start_date, c.end_date,
		       c.is_viewed,
		       COALESCE(NULLIF(TRIM(c.acknowledgment_status), ''), 'PENDING')::text,
		       c.driver_note, c.responded_at, c.created_at,
		       COALESCE(NULLIF(TRIM(u.full_name), ''), '')
		FROM contracts c
		LEFT JOIN users u ON u.id = c.driver_id
		WHERE 1=1
	`
	args := []interface{}{}
	argIndex := 1

	if driverID != nil {
		query += fmt.Sprintf(" AND c.driver_id = $%d", argIndex)
		args = append(args, *driverID)
		argIndex++
	}

	if ackFilter != nil {
		query += fmt.Sprintf(" AND c.acknowledgment_status = $%d", argIndex)
		args = append(args, string(*ackFilter))
		argIndex++
	}

	query += " ORDER BY c.created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list contracts: %w", err)
	}
	defer rows.Close()

	contracts := make([]models.Contract, 0)
	for rows.Next() {
		var c models.Contract
		var ackStr string
		err := rows.Scan(
			&c.ID, &c.DriverID, &c.ContractNumber, &c.FileURL, &c.StartDate, &c.EndDate,
			&c.IsViewed,
			&ackStr,
			&c.DriverNote, &c.RespondedAt, &c.CreatedAt,
			&c.DriverFullName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan contract: %w", err)
		}
		c.AcknowledgmentStatus = models.ContractAcknowledgmentStatus(ackStr)
		contracts = append(contracts, c)
	}

	return contracts, nil
}

// Create creates a new contract
func (r *ContractRepository) Create(ctx context.Context, contract *models.Contract) error {
	query := `
		INSERT INTO contracts (driver_id, contract_number, file_url, start_date, end_date)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at
	`

	err := r.db.QueryRow(ctx, query,
		contract.DriverID,
		contract.ContractNumber,
		contract.FileURL,
		contract.StartDate,
		contract.EndDate,
	).Scan(&contract.ID, &contract.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to create contract: %w", err)
	}

	contract.IsViewed = false
	contract.AcknowledgmentStatus = models.ContractAckPending
	return nil
}

// GetByID returns a contract by id
func (r *ContractRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Contract, error) {
	query := `
		SELECT c.id, c.driver_id, c.contract_number, c.file_url, c.start_date, c.end_date,
		       c.is_viewed,
		       COALESCE(NULLIF(TRIM(c.acknowledgment_status), ''), 'PENDING')::text,
		       c.driver_note, c.responded_at, c.created_at,
		       COALESCE(NULLIF(TRIM(u.full_name), ''), '')
		FROM contracts c
		LEFT JOIN users u ON u.id = c.driver_id
		WHERE c.id = $1
	`
	var c models.Contract
	var ackStr string
	err := r.db.QueryRow(ctx, query, id).Scan(
		&c.ID, &c.DriverID, &c.ContractNumber, &c.FileURL, &c.StartDate, &c.EndDate,
		&c.IsViewed,
		&ackStr,
		&c.DriverNote, &c.RespondedAt, &c.CreatedAt,
		&c.DriverFullName,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, err
		}
		return nil, fmt.Errorf("failed to get contract: %w", err)
	}
	c.AcknowledgmentStatus = models.ContractAcknowledgmentStatus(ackStr)
	return &c, nil
}

// MarkAsViewed sets is_viewed when the driver opens the PDF
func (r *ContractRepository) MarkAsViewed(ctx context.Context, id uuid.UUID, driverID uuid.UUID) error {
	query := `
		UPDATE contracts SET is_viewed = TRUE
		WHERE id = $1 AND driver_id = $2
	`
	res, err := r.db.Exec(ctx, query, id, driverID)
	if err != nil {
		return fmt.Errorf("failed to mark contract viewed: %w", err)
	}
	if res.RowsAffected() == 0 {
		return errors.New("contract not found or access denied")
	}
	return nil
}

// RespondContract sets driver acknowledgment (only while PENDING)
func (r *ContractRepository) RespondContract(ctx context.Context, id uuid.UUID, driverID uuid.UUID, status models.ContractAcknowledgmentStatus, note *string) error {
	query := `
		UPDATE contracts
		SET acknowledgment_status = $1, driver_note = $2, responded_at = $3
		WHERE id = $4 AND driver_id = $5 AND acknowledgment_status = 'PENDING'
	`
	res, err := r.db.Exec(ctx, query, string(status), note, time.Now(), id, driverID)
	if err != nil {
		return fmt.Errorf("failed to respond to contract: %w", err)
	}
	if res.RowsAffected() == 0 {
		return errors.New("contract not found, access denied, or already responded")
	}
	return nil
}
