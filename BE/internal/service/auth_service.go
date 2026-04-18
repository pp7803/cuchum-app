package service

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
	"github.com/tsnn/ch-app/internal/utils"
)

// AuthService handles authentication business logic
type AuthService struct {
	userRepo            *repository.UserRepository
	refreshTokenRepo    *repository.RefreshTokenRepository
	biometricTokenRepo  *repository.BiometricTokenRepository
	jwtUtil             *utils.JWTUtil
}

// NewAuthService creates a new auth service
func NewAuthService(
	userRepo *repository.UserRepository,
	refreshTokenRepo *repository.RefreshTokenRepository,
	biometricTokenRepo *repository.BiometricTokenRepository,
	jwtUtil *utils.JWTUtil,
) *AuthService {
	return &AuthService{
		userRepo:           userRepo,
		refreshTokenRepo:   refreshTokenRepo,
		biometricTokenRepo: biometricTokenRepo,
		jwtUtil:            jwtUtil,
	}
}

// Login authenticates user and returns JWT tokens
func (s *AuthService) Login(ctx context.Context, req models.LoginRequest) (*models.LoginResponse, error) {
	// Find user by phone or email
	user, err := s.userRepo.FindByPhoneOrEmail(ctx, req.Identifier)
	if err != nil {
		return nil, fmt.Errorf("failed to find user: %w", err)
	}

	if user == nil {
		return nil, errors.New("invalid credentials")
	}

	if user.Status != models.StatusActive {
		return nil, errors.New("account is inactive")
	}

	if err := utils.VerifyPassword(user.PasswordHash, req.Password); err != nil {
		return nil, errors.New("invalid credentials")
	}

	// Generate access token
	accessToken, err := s.jwtUtil.GenerateAccessToken(user.ID, string(user.Role))
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	// Check if user has valid refresh token
	existingToken, err := s.refreshTokenRepo.FindValidByUserID(ctx, user.ID)
	var refreshToken string

	if err == nil && existingToken != nil {
		// Reuse existing valid refresh token
		refreshToken = existingToken.Token
	} else {
		// Generate new refresh token if none exists or expired
		newToken, expiresAt, err := s.jwtUtil.GenerateRefreshToken()
		if err != nil {
			return nil, fmt.Errorf("failed to generate refresh token: %w", err)
		}

		// Revoke old tokens and store new one
		_ = s.refreshTokenRepo.RevokeAllForUser(ctx, user.ID)
		_, err = s.refreshTokenRepo.Create(ctx, user.ID, newToken, expiresAt)
		if err != nil {
			return nil, fmt.Errorf("failed to store refresh token: %w", err)
		}
		refreshToken = newToken
	}

	user.PasswordHash = ""

	return &models.LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    6 * 3600, // 6 hours in seconds
		User:         user,
	}, nil
}

// RefreshToken refreshes the access token using refresh token
func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*models.RefreshTokenResponse, error) {
	// Find refresh token
	rt, err := s.refreshTokenRepo.FindByToken(ctx, refreshToken)
	if err != nil {
		return nil, errors.New("invalid or expired refresh token")
	}

	// Get user
	user, err := s.userRepo.FindByID(ctx, rt.UserID)
	if err != nil || user == nil {
		return nil, errors.New("user not found")
	}

	if user.Status != models.StatusActive {
		return nil, errors.New("account is inactive")
	}

	// Generate new access token only (keep refresh token unchanged)
	accessToken, err := s.jwtUtil.GenerateAccessToken(user.ID, string(user.Role))
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	return &models.RefreshTokenResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken, // Return same refresh token
		ExpiresIn:    6 * 3600,
	}, nil
}

// Logout revokes refresh token
func (s *AuthService) Logout(ctx context.Context, refreshToken string) error {
	return s.refreshTokenRepo.Revoke(ctx, refreshToken)
}

// GetCurrentUser retrieves current user info
func (s *AuthService) GetCurrentUser(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	if user == nil {
		return nil, errors.New("user not found")
	}

	user.PasswordHash = ""
	return user, nil
}

// EnableBiometric generates and stores (upserts) a biometric token for a user
func (s *AuthService) EnableBiometric(ctx context.Context, userID uuid.UUID) (*models.BiometricToken, error) {
	token, expiresAt, err := s.jwtUtil.GenerateBiometricToken()
	if err != nil {
		return nil, fmt.Errorf("failed to generate biometric token: %w", err)
	}

	bt, err := s.biometricTokenRepo.Upsert(ctx, userID, token, expiresAt)
	if err != nil {
		return nil, fmt.Errorf("failed to store biometric token: %w", err)
	}

	return bt, nil
}

// BiometricLogin authenticates using a biometric token and returns fresh access/refresh tokens
func (s *AuthService) BiometricLogin(ctx context.Context, biometricToken string) (*models.LoginResponse, error) {
	bt, err := s.biometricTokenRepo.FindByToken(ctx, biometricToken)
	if err != nil {
		return nil, errors.New("invalid or expired biometric token")
	}

	user, err := s.userRepo.FindByID(ctx, bt.UserID)
	if err != nil || user == nil {
		return nil, errors.New("user not found")
	}

	if user.Status != models.StatusActive {
		return nil, errors.New("account is inactive")
	}

	accessToken, err := s.jwtUtil.GenerateAccessToken(user.ID, string(user.Role))
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	existingToken, err := s.refreshTokenRepo.FindValidByUserID(ctx, user.ID)
	var refreshToken string

	if err == nil && existingToken != nil {
		refreshToken = existingToken.Token
	} else {
		newToken, expiresAt, err := s.jwtUtil.GenerateRefreshToken()
		if err != nil {
			return nil, fmt.Errorf("failed to generate refresh token: %w", err)
		}
		_ = s.refreshTokenRepo.RevokeAllForUser(ctx, user.ID)
		if _, err = s.refreshTokenRepo.Create(ctx, user.ID, newToken, expiresAt); err != nil {
			return nil, fmt.Errorf("failed to store refresh token: %w", err)
		}
		refreshToken = newToken
	}

	user.PasswordHash = ""
	return &models.LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    6 * 3600,
		User:         user,
	}, nil
}

// DisableBiometric removes the biometric token for a user
func (s *AuthService) DisableBiometric(ctx context.Context, userID uuid.UUID) error {
	return s.biometricTokenRepo.DeleteByUserID(ctx, userID)
}

// ChangePassword changes the password for authenticated user
func (s *AuthService) ChangePassword(ctx context.Context, userID uuid.UUID, currentPassword, newPassword string) error {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return errors.New("user not found")
	}

	// Verify current password
	if err := utils.VerifyPassword(user.PasswordHash, currentPassword); err != nil {
		return errors.New("current password is incorrect")
	}

	// Hash new password
	hashedPassword, err := utils.HashPassword(newPassword)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Update password
	if err := s.userRepo.UpdatePassword(ctx, userID, hashedPassword); err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

	return nil
}
