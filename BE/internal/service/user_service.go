package service

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
	"github.com/tsnn/ch-app/internal/utils"
)

// UserService handles user management business logic
type UserService struct {
	userRepo    *repository.UserRepository
	profileRepo *repository.ProfileRepository
}

// NewUserService creates a new user service
func NewUserService(userRepo *repository.UserRepository, profileRepo *repository.ProfileRepository) *UserService {
	return &UserService{
		userRepo:    userRepo,
		profileRepo: profileRepo,
	}
}

// CreateUser creates a new driver account
func (s *UserService) CreateUser(ctx context.Context, req models.CreateUserRequest) (*models.User, error) {
	// Validate citizen_id if provided
	if req.CitizenID != nil && *req.CitizenID != "" {
		if err := validateCitizenID(*req.CitizenID); err != nil {
			return nil, err
		}
	}

	// Validate email if provided
	if req.Email != nil && *req.Email != "" {
		// Basic email validation
		email := *req.Email
		if len(email) < 3 || !contains(email, "@") || !contains(email, ".") {
			return nil, errors.New("invalid email format")
		}
	}

	// Check if phone number already exists
	existing, err := s.userRepo.FindByPhoneNumber(ctx, req.PhoneNumber)
	if err != nil {
		return nil, fmt.Errorf("failed to check existing user: %w", err)
	}

	if existing != nil {
		return nil, errors.New("phone number already exists")
	}

	// Hash password
	hashedPassword, err := utils.HashPassword(req.Password)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Set default role if not provided (trim whitespace from form input)
	role := models.UserRole(strings.TrimSpace(string(req.Role)))
	if role == "" {
		role = models.RoleDriver
	}

	// Normalize email (convert empty string to nil)
	var email *string
	if req.Email != nil && *req.Email != "" {
		email = req.Email
	}

	// Create user
	user := &models.User{
		PhoneNumber:  req.PhoneNumber,
		Email:        email,
		PasswordHash: hashedPassword,
		FullName:     req.FullName,
		Role:         role,
		Status:       models.StatusActive,
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	// Create driver profile row and populate optional fields
	if role == models.RoleDriver {
		if err := s.userRepo.CreateDriverProfile(ctx, user.ID); err != nil {
			return nil, fmt.Errorf("failed to create driver profile: %w", err)
		}
		// Save optional profile fields if provided
		if req.CitizenID != nil || req.LicenseClass != nil || req.LicenseNumber != nil || req.Address != nil {
			profileReq := models.UpdateProfileRequest{
				CitizenID:     req.CitizenID,
				LicenseClass:  req.LicenseClass,
				LicenseNumber: req.LicenseNumber,
				Address:       req.Address,
			}
			if err := s.profileRepo.Update(ctx, user.ID, &profileReq); err != nil {
				return nil, fmt.Errorf("failed to save driver profile fields: %w", err)
			}
		}
	}

	// Clear password hash
	user.PasswordHash = ""

	return user, nil
}

func contains(s, substr string) bool {
	return len(s) > 0 && len(substr) > 0 && s != substr &&
		(len(s) >= len(substr) && s[0:len(substr)] == substr ||
			len(s) > len(substr) && findSubstr(s, substr))
}

func findSubstr(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// ListUsers retrieves list of users with pagination
func (s *UserService) ListUsers(ctx context.Context, params models.UserQueryParams) ([]models.User, int, error) {
	users, total, err := s.userRepo.List(ctx, params)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to list users: %w", err)
	}

	// Clear password hashes
	for i := range users {
		users[i].PasswordHash = ""
	}

	return users, total, nil
}

// UpdateUserStatus updates user account status
func (s *UserService) UpdateUserStatus(ctx context.Context, userID uuid.UUID, status models.UserStatus) error {
	if err := s.userRepo.UpdateStatus(ctx, userID, status); err != nil {
		return fmt.Errorf("failed to update user status: %w", err)
	}

	return nil
}

// UpdateUserPassword updates user password (admin only)
func (s *UserService) UpdateUserPassword(ctx context.Context, userID uuid.UUID, newPassword string) error {
	// Check if user exists
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return errors.New("user not found")
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
