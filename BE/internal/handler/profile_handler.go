package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/service"
	"github.com/tsnn/ch-app/internal/utils"
)

type ProfileHandler struct {
	profileService *service.ProfileService
}

func NewProfileHandler(profileService *service.ProfileService) *ProfileHandler {
	return &ProfileHandler{profileService: profileService}
}

// GetMyProfile returns the authenticated user's full profile + any pending update request
// @route GET /api/v1/profile
func (h *ProfileHandler) GetMyProfile(c *gin.Context) {
	userID, _ := c.Get("user_id")

	profile, err := h.profileService.GetProfile(c.Request.Context(), userID.(uuid.UUID))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Profile retrieved successfully", profile)
}

// UpdateProfile submits a profile update.
// - DRIVER  → creates a PENDING request for admin approval.
// - ADMIN   → applies changes immediately.
// @route PUT /api/v1/profile
func (h *ProfileHandler) UpdateProfile(c *gin.Context) {
	userID, _ := c.Get("user_id")
	role, _ := c.Get("user_role") // set by AuthMiddleware as "user_role"

	var req models.UpdateProfileRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	result, err := h.profileService.RequestProfileUpdate(
		c.Request.Context(),
		userID.(uuid.UUID),
		models.UserRole(role.(string)),
		req,
	)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	if result == nil {
		// Admin: direct update
		utils.SuccessResponse(c, http.StatusOK, "Profile updated successfully", nil)
	} else {
		// Driver: pending request created
		utils.SuccessResponse(c, http.StatusAccepted,
			"Yêu cầu cập nhật hồ sơ đã được gửi và đang chờ Admin duyệt", result)
	}
}

// GetDriverProfile returns a driver's profile (admin only)
// @route GET /api/v1/users/:id/profile
func (h *ProfileHandler) GetDriverProfile(c *gin.Context) {
	driverID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid driver ID")
		return
	}

	profile, err := h.profileService.GetProfile(c.Request.Context(), driverID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Profile retrieved successfully", profile)
}

// ListProfileUpdateRequests lists profile update requests (admin only)
// @route GET /api/v1/profile-requests
func (h *ProfileHandler) ListProfileUpdateRequests(c *gin.Context) {
	var params models.ProfileUpdateRequestQueryParams
	if err := c.ShouldBind(&params); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}
	if params.Page == 0 {
		params.Page = 1
	}
	if params.Limit == 0 {
		params.Limit = 20
	}

	list, total, err := h.profileService.ListProfileUpdateRequests(
		c.Request.Context(),
		params.Status,
		params.Page,
		params.Limit,
	)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	if list == nil {
		list = []*models.ProfileUpdateRequest{}
	}

	utils.SuccessResponse(c, http.StatusOK, "Requests retrieved successfully", gin.H{
		"requests": list,
		"total":    total,
		"page":     params.Page,
		"limit":    params.Limit,
	})
}

// ReviewProfileUpdateRequest approves or rejects a pending request (admin only)
// @route PATCH /api/v1/profile-requests/:id/review
func (h *ProfileHandler) ReviewProfileUpdateRequest(c *gin.Context) {
	requestID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request ID")
		return
	}

	var req models.ReviewProfileUpdateRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	reviewerID, _ := c.Get("user_id")

	pur, err := h.profileService.ReviewProfileUpdateRequest(
		c.Request.Context(),
		requestID,
		reviewerID.(uuid.UUID),
		models.ProfileUpdateStatus(req.Status),
		req.AdminNote,
	)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	msg := "Yêu cầu đã được duyệt"
	if pur.Status == models.ProfileUpdateRejected {
		msg = "Yêu cầu đã bị từ chối"
	}

	utils.SuccessResponse(c, http.StatusOK, msg, pur)
}
