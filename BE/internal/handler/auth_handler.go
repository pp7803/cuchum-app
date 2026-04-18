package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/service"
	"github.com/tsnn/ch-app/internal/utils"
)

// AuthHandler handles authentication endpoints
type AuthHandler struct {
	authService         *service.AuthService
	notificationService *service.NotificationService
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler(authService *service.AuthService, notificationService *service.NotificationService) *AuthHandler {
	return &AuthHandler{
		authService:         authService,
		notificationService: notificationService,
	}
}

// Login handles user login
// @route POST /api/v1/auth/login
func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	resp, err := h.authService.Login(c.Request.Context(), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Login successful", resp)
}

// RefreshToken handles token refresh
// @route POST /api/v1/auth/refresh
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req models.RefreshTokenRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	resp, err := h.authService.RefreshToken(c.Request.Context(), req.RefreshToken)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Token refreshed", resp)
}

// Logout handles user logout
// @route POST /api/v1/auth/logout
func (h *AuthHandler) Logout(c *gin.Context) {
	var req models.RefreshTokenRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	_ = h.authService.Logout(c.Request.Context(), req.RefreshToken)
	utils.SuccessResponse(c, http.StatusOK, "Logged out successfully", nil)
}

// GetMe handles getting current user info
// @route GET /api/v1/users/me
func (h *AuthHandler) GetMe(c *gin.Context) {
	userID, _ := c.Get("user_id")

	user, err := h.authService.GetCurrentUser(c.Request.Context(), userID.(uuid.UUID))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "User retrieved successfully", user)
}

// RegisterDevice registers a device token for push notifications
// @route POST /api/v1/devices/register
func (h *AuthHandler) RegisterDevice(c *gin.Context) {
	var req models.RegisterDeviceRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	if err := h.notificationService.RegisterDevice(c.Request.Context(), userID.(uuid.UUID), req.Token, req.Platform); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Device registered successfully", nil)
}

// UnregisterDevice removes a device token
// @route DELETE /api/v1/devices/unregister
func (h *AuthHandler) UnregisterDevice(c *gin.Context) {
	var req models.UnregisterDeviceRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	if err := h.notificationService.UnregisterDevice(c.Request.Context(), userID.(uuid.UUID), req.Token); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Device unregistered successfully", nil)
}

// BiometricLogin handles login using a stored biometric token
// @route POST /api/v1/auth/biometric-login  (PUBLIC)
func (h *AuthHandler) BiometricLogin(c *gin.Context) {
	var req models.BiometricLoginRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	resp, err := h.authService.BiometricLogin(c.Request.Context(), req.BiometricToken)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Login successful", resp)
}

// EnableBiometric generates and returns a biometric token for the authenticated user
// @route POST /api/v1/auth/biometric/enable  (AUTH REQUIRED)
func (h *AuthHandler) EnableBiometric(c *gin.Context) {
	userID, _ := c.Get("user_id")

	bt, err := h.authService.EnableBiometric(c.Request.Context(), userID.(uuid.UUID))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Biometric authentication enabled", models.EnableBiometricResponse{
		BiometricToken: bt.Token,
		ExpiresAt:      bt.ExpiresAt.Format("2006-01-02T15:04:05Z07:00"),
	})
}

// DisableBiometric revokes the biometric token for the authenticated user
// @route DELETE /api/v1/auth/biometric/disable  (AUTH REQUIRED)
func (h *AuthHandler) DisableBiometric(c *gin.Context) {
	userID, _ := c.Get("user_id")

	if err := h.authService.DisableBiometric(c.Request.Context(), userID.(uuid.UUID)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Biometric authentication disabled", nil)
}

// ChangePassword handles password change for authenticated user
// @route POST /api/v1/auth/change-password
func (h *AuthHandler) ChangePassword(c *gin.Context) {
	var req models.ChangePasswordRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	if req.NewPassword != req.ConfirmPassword {
		utils.ErrorResponse(c, http.StatusBadRequest, "New password and confirm password do not match")
		return
	}

	userID, _ := c.Get("user_id")
	if err := h.authService.ChangePassword(c.Request.Context(), userID.(uuid.UUID), req.CurrentPassword, req.NewPassword); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Password changed successfully", nil)
}
