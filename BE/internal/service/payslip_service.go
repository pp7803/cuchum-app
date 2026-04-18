package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
)

type PayslipService struct {
	payslipRepo *repository.PayslipRepository
	userRepo    *repository.UserRepository
	notif       *NotificationService
}

func NewPayslipService(
	payslipRepo *repository.PayslipRepository,
	userRepo *repository.UserRepository,
	notif *NotificationService,
) *PayslipService {
	return &PayslipService{
		payslipRepo: payslipRepo,
		userRepo:    userRepo,
		notif:       notif,
	}
}

func (s *PayslipService) List(ctx context.Context, driverID *uuid.UUID, monthStr string) ([]models.Payslip, error) {
	var month *time.Time
	if monthStr != "" {
		parsed, err := time.Parse("2006-01", monthStr)
		if err != nil {
			return nil, fmt.Errorf("invalid month format (use YYYY-MM): %w", err)
		}
		month = &parsed
	}

	payslips, err := s.payslipRepo.List(ctx, driverID, month)
	if err != nil {
		return nil, fmt.Errorf("failed to list payslips: %w", err)
	}
	return payslips, nil
}

func (s *PayslipService) Create(ctx context.Context, req models.CreatePayslipRequest) (*models.Payslip, error) {
	salaryMonth, err := time.Parse("2006-01", req.SalaryMonth)
	if err != nil {
		return nil, fmt.Errorf("invalid salary_month format (use YYYY-MM): %w", err)
	}

	payslip := &models.Payslip{
		DriverID:    req.DriverID,
		SalaryMonth: salaryMonth,
		FileURL:     req.FileURL,
	}

	if err := s.payslipRepo.Create(ctx, payslip); err != nil {
		return nil, fmt.Errorf("failed to create payslip: %w", err)
	}

	payslip.Status = models.PayslipPending
	if u, e := s.userRepo.FindByID(ctx, req.DriverID); e == nil && u != nil {
		payslip.DriverFullName = u.FullName
	}

	if s.notif != nil {
		monthStr := req.SalaryMonth
		did := req.DriverID
		go func() {
			s.notif.NotifyDriver(context.Background(), did, "Bảng lương mới",
				fmt.Sprintf("Kỳ lương %s đã được đăng tải. Mở ứng dụng để xem chi tiết.", monthStr))
		}()
	}

	return payslip, nil
}

func (s *PayslipService) MarkAsViewed(ctx context.Context, payslipID, driverID uuid.UUID) error {
	if err := s.payslipRepo.MarkAsViewed(ctx, payslipID, driverID); err != nil {
		return fmt.Errorf("failed to mark payslip as viewed: %w", err)
	}
	return nil
}

func (s *PayslipService) ConfirmPayslip(ctx context.Context, payslipID, driverID uuid.UUID, req models.ConfirmPayslipRequest) error {
	ps, err := s.payslipRepo.GetByID(ctx, payslipID)
	if err != nil {
		return fmt.Errorf("payslip not found: %w", err)
	}
	if ps.DriverID != driverID {
		return errors.New("payslip not found or access denied")
	}

	if err := s.payslipRepo.ConfirmPayslip(ctx, payslipID, driverID, req.Status, req.Note); err != nil {
		return fmt.Errorf("failed to confirm payslip: %w", err)
	}

	if s.notif == nil {
		return nil
	}

	monthStr := ps.SalaryMonth.Format("2006-01")
	driverName := "Tài xế"
	if u, e := s.userRepo.FindByID(context.Background(), driverID); e == nil && u != nil {
		driverName = u.FullName
	}

	notePreview := ""
	if req.Note != nil {
		notePreview = trimRunes(strings.TrimSpace(*req.Note), 280)
	}

	bg := context.Background()
	switch req.Status {
	case models.PayslipConfirmed:
		go s.notif.NotifyAdmins(bg, "Xác nhận bảng lương",
			fmt.Sprintf("%s đã xác nhận đúng bảng lương kỳ %s.", driverName, monthStr))
	case models.PayslipComplained:
		body := fmt.Sprintf("%s khiếu nại bảng lương kỳ %s.", driverName, monthStr)
		if notePreview != "" {
			body += " Nội dung: " + notePreview
		}
		go s.notif.NotifyAdmins(bg, "Khiếu nại bảng lương", body)
	}

	return nil
}

// ImportFromData imports multiple payslips from parsed data (from Excel)
func (s *PayslipService) ImportFromData(ctx context.Context, items []models.PayslipImportItem) (*models.ImportResult, error) {
	result := &models.ImportResult{
		TotalRows:   len(items),
		SuccessRows: 0,
		ErrorRows:   0,
		Errors:      []string{},
	}

	for i, item := range items {
		// Validate driver exists
		if _, err := s.userRepo.FindByID(ctx, item.DriverID); err != nil {
			result.ErrorRows++
			result.Errors = append(result.Errors, fmt.Sprintf("Row %d: driver not found (%s)", i+1, item.DriverID))
			continue
		}

		salaryMonth, err := time.Parse("2006-01", item.SalaryMonth)
		if err != nil {
			result.ErrorRows++
			result.Errors = append(result.Errors, fmt.Sprintf("Row %d: invalid salary_month format", i+1))
			continue
		}

		payslip := &models.Payslip{
			DriverID:    item.DriverID,
			SalaryMonth: salaryMonth,
			FileURL:     item.FileURL,
		}

		if err := s.payslipRepo.Create(ctx, payslip); err != nil {
			result.ErrorRows++
			result.Errors = append(result.Errors, fmt.Sprintf("Row %d: %v", i+1, err))
			continue
		}

		result.SuccessRows++

		if s.notif != nil {
			did := item.DriverID
			sm := item.SalaryMonth
			go func() {
				s.notif.NotifyDriver(context.Background(), did, "Bảng lương mới",
					fmt.Sprintf("Kỳ lương %s đã được đăng tải.", sm))
			}()
		}
	}

	return result, nil
}

func trimRunes(s string, max int) string {
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max]) + "…"
}
