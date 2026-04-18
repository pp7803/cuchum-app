package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/service"
	"github.com/tsnn/ch-app/internal/utils"
)

type PasswordResetHandler struct {
	passwordResetService *service.PasswordResetService
}

func NewPasswordResetHandler(passwordResetService *service.PasswordResetService) *PasswordResetHandler {
	return &PasswordResetHandler{passwordResetService: passwordResetService}
}

// ForgotPassword sends OTP to user's email
func (h *PasswordResetHandler) ForgotPassword(c *gin.Context) {
	var req models.ForgotPasswordRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	response, err := h.passwordResetService.SendOTP(c.Request.Context(), req.Email)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, response.Message, response)
}

// ResetPassword verifies OTP and resets password
func (h *PasswordResetHandler) ResetPassword(c *gin.Context) {
	var req models.ResetPasswordRequest
	if err := c.ShouldBind(&req); err != nil {
		utils.ValidationErrorResponse(c, err.Error())
		return
	}

	if err := h.passwordResetService.ResetPassword(c.Request.Context(), req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.SuccessResponse(c, http.StatusOK, "Đặt lại mật khẩu thành công", nil)
}
