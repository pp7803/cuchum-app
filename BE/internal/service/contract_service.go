package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
)

type ContractService struct {
	contractRepo *repository.ContractRepository
	userRepo     *repository.UserRepository
	notif        *NotificationService
}

func NewContractService(
	contractRepo *repository.ContractRepository,
	notif *NotificationService,
	userRepo *repository.UserRepository,
) *ContractService {
	return &ContractService{
		contractRepo: contractRepo,
		notif:        notif,
		userRepo:     userRepo,
	}
}

func (s *ContractService) List(ctx context.Context, driverID *uuid.UUID, ackFilter *models.ContractAcknowledgmentStatus) ([]models.Contract, error) {
	contracts, err := s.contractRepo.List(ctx, driverID, ackFilter)
	if err != nil {
		return nil, fmt.Errorf("failed to list contracts: %w", err)
	}
	return contracts, nil
}

func (s *ContractService) Create(ctx context.Context, req models.CreateContractRequest) (*models.Contract, error) {
	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		return nil, fmt.Errorf("invalid start_date format: %w", err)
	}

	contract := &models.Contract{
		DriverID:       req.DriverID,
		ContractNumber: req.ContractNumber,
		FileURL:        req.FileURL,
		StartDate:      startDate,
	}

	if req.EndDate != nil {
		endDate, err := time.Parse("2006-01-02", *req.EndDate)
		if err != nil {
			return nil, fmt.Errorf("invalid end_date format: %w", err)
		}
		contract.EndDate = &endDate
	}

	if err := s.contractRepo.Create(ctx, contract); err != nil {
		return nil, fmt.Errorf("failed to create contract: %w", err)
	}

	if u, e := s.userRepo.FindByID(ctx, req.DriverID); e == nil && u != nil {
		contract.DriverFullName = u.FullName
	}

	if s.notif != nil {
		did := req.DriverID
		num := req.ContractNumber
		go func() {
			s.notif.NotifyDriver(context.Background(), did, "Hợp đồng lao động",
				fmt.Sprintf("Hợp đồng %s đã được thêm. Vui lòng xem PDF và xác nhận hoặc từ chối kèm lý do trên ứng dụng.", num))
		}()
	}

	return contract, nil
}

func (s *ContractService) MarkAsViewed(ctx context.Context, contractID, driverID uuid.UUID) error {
	if err := s.contractRepo.MarkAsViewed(ctx, contractID, driverID); err != nil {
		return fmt.Errorf("failed to mark contract as viewed: %w", err)
	}
	return nil
}

func (s *ContractService) RespondContract(ctx context.Context, contractID, driverID uuid.UUID, req models.RespondContractRequest) error {
	if req.Status == models.ContractAckDeclined {
		n := ""
		if req.Note != nil {
			n = strings.TrimSpace(*req.Note)
		}
		if n == "" {
			return errors.New("note is required when declining")
		}
	}

	c, err := s.contractRepo.GetByID(ctx, contractID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("contract not found")
		}
		return fmt.Errorf("contract not found: %w", err)
	}
	if c.DriverID != driverID {
		return errors.New("contract not found or access denied")
	}
	if c.AcknowledgmentStatus != models.ContractAckPending {
		return errors.New("contract already responded")
	}

	var notePtr *string
	if req.Note != nil {
		t := strings.TrimSpace(*req.Note)
		if t != "" {
			notePtr = &t
		}
	}

	if err := s.contractRepo.RespondContract(ctx, contractID, driverID, req.Status, notePtr); err != nil {
		return err
	}

	if s.notif == nil {
		return nil
	}

	driverName := "Tài xế"
	if u, e := s.userRepo.FindByID(context.Background(), driverID); e == nil && u != nil {
		driverName = u.FullName
	}
	num := c.ContractNumber
	bg := context.Background()

	switch req.Status {
	case models.ContractAckAcknowledged:
		go s.notif.NotifyAdmins(bg, "Tài xế xác nhận hợp đồng",
			fmt.Sprintf("%s đã xác nhận đã đọc và đồng ý hợp đồng %s.", driverName, num))
	case models.ContractAckDeclined:
		reason := ""
		if notePtr != nil {
			reason = *notePtr
		}
		go s.notif.NotifyAdmins(bg, "Tài xế không xác nhận hợp đồng",
			fmt.Sprintf("%s không xác nhận hợp đồng %s. Lý do: %s", driverName, num, reason))
	}

	return nil
}
