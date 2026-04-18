package service

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
)

type ProfileService struct {
	profileRepo              *repository.ProfileRepository
	profileUpdateRequestRepo *repository.ProfileUpdateRequestRepository
	userRepo                 *repository.UserRepository
	notificationService      *NotificationService
}

func NewProfileService(
	profileRepo *repository.ProfileRepository,
	profileUpdateRequestRepo *repository.ProfileUpdateRequestRepository,
	userRepo *repository.UserRepository,
	notificationService *NotificationService,
) *ProfileService {
	return &ProfileService{
		profileRepo:              profileRepo,
		profileUpdateRequestRepo: profileUpdateRequestRepo,
		userRepo:                 userRepo,
		notificationService:      notificationService,
	}
}

// GetProfile returns full profile + pending request (if any) for the given user
func (s *ProfileService) GetProfile(ctx context.Context, userID uuid.UUID) (*models.ProfileResponse, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %w", err)
	}
	if user == nil {
		return nil, fmt.Errorf("user not found")
	}

	profile, err := s.profileRepo.GetByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get profile: %w", err)
	}

	response := &models.ProfileResponse{
		UserID:      user.ID.String(),
		PhoneNumber: user.PhoneNumber,
		Email:       user.Email,
		FullName:    user.FullName,
		Role:        string(user.Role),
		Status:      string(user.Status),
		CreatedAt:   user.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:   user.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}

	if profile != nil {
		response.CitizenID = profile.CitizenID
		response.LicenseClass = profile.LicenseClass
		response.LicenseNumber = profile.LicenseNumber
		response.Address = profile.Address
		response.AvatarURL = profile.AvatarURL
	}

	// Attach pending update request for DRIVER users
	if user.Role == models.RoleDriver {
		pending, err := s.profileUpdateRequestRepo.FindPendingByUserID(ctx, userID)
		if err != nil {
			return nil, fmt.Errorf("failed to get pending request: %w", err)
		}
		if pending != nil {
			response.PendingRequest = &models.ProfileUpdateRequestSummary{
				ID:            pending.ID.String(),
				CitizenID:     pending.CitizenID,
				LicenseClass:  pending.LicenseClass,
				LicenseNumber: pending.LicenseNumber,
				Address:       pending.Address,
				AvatarURL:     pending.AvatarURL,
				ProofImageURL: pending.ProofImageURL,
				Status:        string(pending.Status),
				AdminNote:     pending.AdminNote,
				CreatedAt:     pending.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
			}
		}
	}

	return response, nil
}

// RequestProfileUpdate creates a PENDING update request for a DRIVER.
// Admin users and avatar-only updates bypass the queue and apply directly.
func (s *ProfileService) RequestProfileUpdate(
	ctx context.Context,
	userID uuid.UUID,
	role models.UserRole,
	req models.UpdateProfileRequest,
) (any, error) {
	// Validate citizen_id if provided
	if req.CitizenID != nil && *req.CitizenID != "" {
		if err := validateCitizenID(*req.CitizenID); err != nil {
			return nil, err
		}
	}

	// Avatar URL always applied directly — no approval needed for any role
	if req.AvatarURL != nil && *req.AvatarURL != "" {
		avatarOnly := models.UpdateProfileRequest{AvatarURL: req.AvatarURL}
		if err := s.profileRepo.Update(ctx, userID, &avatarOnly); err != nil {
			return nil, fmt.Errorf("failed to update avatar: %w", err)
		}
		req.AvatarURL = nil // Remove from pending request
	}

	hasOtherFields := req.CitizenID != nil || req.LicenseClass != nil || req.LicenseNumber != nil || req.Address != nil
	hasProof := req.ProofImageURL != nil && strings.TrimSpace(*req.ProofImageURL) != ""
	if !hasOtherFields && !hasProof {
		return nil, nil // Avatar-only update done
	}

	if role == models.RoleAdmin {
		// Admin: apply remaining fields directly
		if err := s.profileRepo.Update(ctx, userID, &req); err != nil {
			return nil, fmt.Errorf("failed to update profile: %w", err)
		}
		return nil, nil
	}

	// DRIVER: create pending request for non-avatar fields
	pur, err := s.profileUpdateRequestRepo.Upsert(ctx, userID, &req)
	if err != nil {
		return nil, fmt.Errorf("failed to create update request: %w", err)
	}

	// Notify admins via FCM (non-blocking)
	user, _ := s.userRepo.FindByID(ctx, userID)
	driverName := "Tài xế"
	if user != nil {
		driverName = user.FullName
	}
	s.notificationService.NotifyAdmins(ctx,
		"📋 Yêu cầu cập nhật hồ sơ mới",
		fmt.Sprintf("%s vừa gửi yêu cầu cập nhật thông tin hồ sơ.", driverName),
	)

	return pur, nil
}

// ListProfileUpdateRequests returns profile update requests with total count (admin only)
func (s *ProfileService) ListProfileUpdateRequests(
	ctx context.Context,
	status string,
	page, limit int,
) ([]*models.ProfileUpdateRequest, int, error) {
	total, err := s.profileUpdateRequestRepo.CountByStatus(ctx, status)
	if err != nil {
		return nil, 0, err
	}
	list, err := s.profileUpdateRequestRepo.ListByStatus(ctx, status, page, limit)
	if err != nil {
		return nil, 0, err
	}
	return list, total, nil
}

// ReviewProfileUpdateRequest approves or rejects a pending request (admin only)
func (s *ProfileService) ReviewProfileUpdateRequest(
	ctx context.Context,
	requestID uuid.UUID,
	reviewerID uuid.UUID,
	status models.ProfileUpdateStatus,
	adminNote *string,
) (*models.ProfileUpdateRequest, error) {
	pur, err := s.profileUpdateRequestRepo.Review(ctx, requestID, reviewerID, status, adminNote)
	if err != nil {
		return nil, err
	}

	// On APPROVED: apply the requested changes to the actual profile
	if pur.Status == models.ProfileUpdateApproved {
		req := models.UpdateProfileRequest{
			CitizenID:     pur.CitizenID,
			LicenseClass:  pur.LicenseClass,
			LicenseNumber: pur.LicenseNumber,
			Address:       pur.Address,
			AvatarURL:     pur.AvatarURL,
		}
		if err := s.profileRepo.Update(ctx, pur.UserID, &req); err != nil {
			return nil, fmt.Errorf("request approved but failed to apply: %w", err)
		}
	}

	// Notify the driver of the review result.
	// Use context.Background() — the request ctx is cancelled once the handler returns,
	// which would abort the DB insert before it completes.
	var notifTitle, notifBody string
	if pur.Status == models.ProfileUpdateApproved {
		notifTitle = "✅ Yêu cầu cập nhật hồ sơ đã được duyệt"
		notifBody = "Thông tin hồ sơ của bạn đã được cập nhật thành công."
	} else {
		notifTitle = "❌ Yêu cầu cập nhật hồ sơ bị từ chối"
		notifBody = "Vui lòng kiểm tra lại thông tin và gửi yêu cầu mới."
		if adminNote != nil && *adminNote != "" {
			notifBody = "Lý do: " + *adminNote
		}
	}
	driverID := pur.UserID
	go func() {
		bgCtx := context.Background()
		_, _ = s.notificationService.Create(bgCtx, models.CreateNotificationRequest{
			Title:    notifTitle,
			Body:     notifBody,
			DriverID: &driverID,
		})
	}()

	return pur, nil
}
