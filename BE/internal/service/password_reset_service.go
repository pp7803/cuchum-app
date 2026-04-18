package service

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/config"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
	"github.com/tsnn/ch-app/internal/utils"
)

type PasswordResetService struct {
	otpRepo      *repository.OTPRepository
	userRepo     *repository.UserRepository
	emailService *EmailService
	cfg          *config.EmailConfig
}

func NewPasswordResetService(
	otpRepo *repository.OTPRepository,
	userRepo *repository.UserRepository,
	emailService *EmailService,
	cfg *config.EmailConfig,
) *PasswordResetService {
	return &PasswordResetService{
		otpRepo:      otpRepo,
		userRepo:     userRepo,
		emailService: emailService,
		cfg:          cfg,
	}
}

// SendOTP generates and sends OTP to the user's email
func (s *PasswordResetService) SendOTP(ctx context.Context, email string) (*models.ForgotPasswordResponse, error) {
	// Find user by email
	user, err := s.userRepo.FindByEmail(ctx, email)
	if err != nil {
		return nil, fmt.Errorf("failed to find user: %w", err)
	}
	if user == nil {
		return nil, errors.New("email không tồn tại trong hệ thống")
	}

	// Invalidate previous OTPs
	if err := s.otpRepo.InvalidatePreviousOTPs(ctx, email); err != nil {
		return nil, fmt.Errorf("failed to invalidate previous OTPs: %w", err)
	}

	// Generate 6-digit OTP
	otpCode, err := generateOTP(6)
	if err != nil {
		return nil, fmt.Errorf("failed to generate OTP: %w", err)
	}

	// Calculate expiry
	expireMinutes := s.cfg.OTPExpireMinutes
	if expireMinutes == 0 {
		expireMinutes = 5 // Default 5 minutes
	}

	// Create OTP record
	otp := &models.PasswordResetOTP{
		ID:        uuid.New(),
		UserID:    user.ID,
		Email:     email,
		OTPCode:   otpCode,
		ExpiresAt: time.Now().Add(time.Duration(expireMinutes) * time.Minute),
		CreatedAt: time.Now(),
	}

	if err := s.otpRepo.Create(ctx, otp); err != nil {
		return nil, fmt.Errorf("failed to save OTP: %w", err)
	}

	// Send email
	if err := s.emailService.SendOTP(email, otpCode, expireMinutes); err != nil {
		return nil, fmt.Errorf("failed to send email: %w", err)
	}

	return &models.ForgotPasswordResponse{
		Message:   "Mã OTP đã được gửi đến email của bạn",
		ExpiresIn: expireMinutes,
	}, nil
}

// ResetPassword verifies OTP and resets the password
func (s *PasswordResetService) ResetPassword(ctx context.Context, req models.ResetPasswordRequest) error {
	// Find valid OTP
	otp, err := s.otpRepo.FindValidOTP(ctx, req.Email, req.OTP)
	if err != nil {
		return fmt.Errorf("failed to find OTP: %w", err)
	}
	if otp == nil {
		return errors.New("mã OTP không hợp lệ hoặc đã hết hạn")
	}

	// Hash new password
	hashedPassword, err := utils.HashPassword(req.NewPassword)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Update user password
	if err := s.userRepo.UpdatePassword(ctx, otp.UserID, hashedPassword); err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

	// Mark OTP as used
	if err := s.otpRepo.MarkAsUsed(ctx, otp.ID); err != nil {
		return fmt.Errorf("failed to mark OTP as used: %w", err)
	}

	return nil
}

// generateOTP generates a secure random numeric OTP
func generateOTP(length int) (string, error) {
	const digits = "0123456789"
	otp := make([]byte, length)
	for i := range otp {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(digits))))
		if err != nil {
			return "", err
		}
		otp[i] = digits[n.Int64()]
	}
	return string(otp), nil
}
