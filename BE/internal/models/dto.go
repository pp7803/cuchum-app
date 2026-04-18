package models

import (
	"github.com/google/uuid"
)

// ===== Auth DTOs =====

// LoginRequest represents login request payload
type LoginRequest struct {
	Identifier string `json:"identifier" form:"identifier" binding:"required"` // phone_number or email
	Password   string `json:"password" form:"password" binding:"required"`
}

// LoginResponse represents login response
type LoginResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
	User         *User  `json:"user"`
}

// RefreshTokenRequest represents refresh token request
type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" form:"refresh_token" binding:"required"`
}

// RefreshTokenResponse represents refresh token response
type RefreshTokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
}

// ForgotPasswordRequest represents forgot password request
type ForgotPasswordRequest struct {
	Email string `json:"email" form:"email" binding:"required,email"`
}

// ForgotPasswordResponse represents forgot password response
type ForgotPasswordResponse struct {
	Message   string `json:"message"`
	ExpiresIn int    `json:"expires_in"` // OTP expiry in minutes
}

// ResetPasswordRequest represents reset password request
type ResetPasswordRequest struct {
	Email           string `json:"email" form:"email" binding:"required,email"`
	OTP             string `json:"otp" form:"otp" binding:"required,len=6"`
	NewPassword     string `json:"new_password" form:"new_password" binding:"required,min=6"`
	ConfirmPassword string `json:"confirm_password" form:"confirm_password" binding:"required,eqfield=NewPassword"`
}

// ChangePasswordRequest represents change password request for authenticated user
type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" form:"current_password" binding:"required"`
	NewPassword     string `json:"new_password" form:"new_password" binding:"required,min=6"`
	ConfirmPassword string `json:"confirm_password" form:"confirm_password" binding:"required"`
}

// ===== User DTOs =====

// CreateUserRequest represents request to create a new user
type CreateUserRequest struct {
	PhoneNumber string   `json:"phone_number"  form:"phone_number"  binding:"required"`
	Email       *string  `json:"email"         form:"email"`
	Password    string   `json:"password"      form:"password"      binding:"required,min=6"`
	FullName    string   `json:"full_name"     form:"full_name"     binding:"required"`
	Role        UserRole `json:"role"          form:"role"`
	// Optional driver profile fields (admin can pre-fill when creating a driver)
	CitizenID     *string `json:"citizen_id"     form:"citizen_id"`
	LicenseClass  *string `json:"license_class"  form:"license_class"`
	LicenseNumber *string `json:"license_number" form:"license_number"` // số GPLX
	Address       *string `json:"address"        form:"address"`
}

// UpdateUserStatusRequest represents request to update user status
type UpdateUserStatusRequest struct {
	Status UserStatus `json:"status" form:"status" binding:"required,oneof=ACTIVE INACTIVE"`
}

// AdminChangePasswordRequest represents admin change user password request
type AdminChangePasswordRequest struct {
	NewPassword string `json:"new_password" form:"new_password" binding:"required,min=6"`
}

// ===== Profile DTOs =====

// ProfileResponse represents full profile response with user info
type ProfileResponse struct {
	UserID         string                       `json:"user_id"`
	PhoneNumber    string                       `json:"phone_number"`
	Email          *string                      `json:"email,omitempty"`
	FullName       string                       `json:"full_name"`
	Role           string                       `json:"role"`
	Status         string                       `json:"status"`
	CitizenID      *string                      `json:"citizen_id,omitempty"`
	LicenseClass   *string                      `json:"license_class,omitempty"`
	LicenseNumber  *string                      `json:"license_number,omitempty"`
	Address        *string                      `json:"address,omitempty"`
	AvatarURL      *string                      `json:"avatar_url,omitempty"`
	CreatedAt      string                       `json:"created_at"`
	UpdatedAt      string                       `json:"updated_at"`
	PendingRequest *ProfileUpdateRequestSummary `json:"pending_request,omitempty"`
}

// ProfileUpdateRequestSummary is a compact view of a pending profile update request
type ProfileUpdateRequestSummary struct {
	ID            string  `json:"id"`
	CitizenID     *string `json:"citizen_id,omitempty"`
	LicenseClass  *string `json:"license_class,omitempty"`
	LicenseNumber *string `json:"license_number,omitempty"`
	Address       *string `json:"address,omitempty"`
	AvatarURL     *string `json:"avatar_url,omitempty"`
	ProofImageURL *string `json:"proof_image_url,omitempty"`
	Status        string  `json:"status"`
	AdminNote     *string `json:"admin_note,omitempty"`
	CreatedAt     string  `json:"created_at"`
}

// UpdateProfileRequest represents request to update driver profile
type UpdateProfileRequest struct {
	Address       *string `json:"address" form:"address"`
	LicenseClass  *string `json:"license_class" form:"license_class"`
	LicenseNumber *string `json:"license_number" form:"license_number"`
	AvatarURL     *string `json:"avatar_url" form:"avatar_url"`
	CitizenID     *string `json:"citizen_id" form:"citizen_id"`
	ProofImageURL *string `json:"proof_image_url" form:"proof_image_url"` // ảnh minh chứng (DRIVER: lưu vào yêu cầu PENDING; upload folder profile-proofs)
}

// ===== Contract DTOs =====

// CreateContractRequest represents request to create a contract
type CreateContractRequest struct {
	DriverID       uuid.UUID `json:"driver_id" form:"driver_id" binding:"required"`
	ContractNumber string    `json:"contract_number" form:"contract_number" binding:"required"`
	FileURL        string    `json:"file_url" form:"file_url" binding:"required"`
	StartDate      string    `json:"start_date" form:"start_date" binding:"required"` // Format: YYYY-MM-DD
	EndDate        *string   `json:"end_date,omitempty" form:"end_date"`              // Format: YYYY-MM-DD
}

// RespondContractRequest is DRIVER: xác nhận đã đọc & đồng ý, hoặc không xác nhận kèm lý do
type RespondContractRequest struct {
	Status ContractAcknowledgmentStatus `json:"status" form:"status" binding:"required,oneof=ACKNOWLEDGED DECLINED"`
	Note   *string                      `json:"note" form:"note"`
}

// ===== Payslip DTOs =====

// CreatePayslipRequest represents request to create a payslip
type CreatePayslipRequest struct {
	DriverID    uuid.UUID `json:"driver_id" form:"driver_id" binding:"required"`
	SalaryMonth string    `json:"salary_month" form:"salary_month" binding:"required"` // Format: YYYY-MM
	FileURL     string    `json:"file_url" form:"file_url" binding:"required"`
}

// ===== Fuel Report DTOs =====

// CreateFuelReportRequest represents request to create a fuel report
type CreateFuelReportRequest struct {
	VehicleID       uuid.UUID  `json:"vehicle_id" form:"vehicle_id" binding:"required"`
	TripID          *uuid.UUID `json:"trip_id" form:"trip_id"` // tùy chọn: gắn với chuyến đang thực hiện
	ReportDate      string     `json:"report_date" form:"report_date"`
	OdoCurrent      *int       `json:"odo_current" form:"odo_current"`
	Liters          *float64   `json:"liters" form:"liters"`
	TotalCost       float64    `json:"total_cost" form:"total_cost" binding:"required,gt=0"`
	ReceiptImageURL string     `json:"receipt_image_url" form:"receipt_image_url" binding:"required"`
	OdoImageURL     *string    `json:"odo_image_url" form:"odo_image_url"`
	GpsLatitude     *float64   `json:"gps_latitude" form:"gps_latitude"`
	GpsLongitude    *float64   `json:"gps_longitude" form:"gps_longitude"`
	// RFC3339, e.g. 2026-04-08T14:30:00+07:00 — thời điểm mua/đổ xăng.
	FuelPurchasedAt *string `json:"fuel_purchased_at,omitempty" form:"fuel_purchased_at"`
}

// UpdateFuelReportRequest represents request to update fuel report
type UpdateFuelReportRequest struct {
	AdminNote string `json:"admin_note" form:"admin_note" binding:"required"`
}

// ===== Trip Report DTOs =====

// CreateTripReportRequest represents request to create/update trip report
type CreateTripReportRequest struct {
	ReportDate string `json:"report_date" form:"report_date"` // Format: YYYY-MM-DD, defaults to today
	TotalTrips int    `json:"total_trips" form:"total_trips" binding:"required,gte=0"`
}

// ===== Query Params =====

// PaginationParams represents pagination query params
type PaginationParams struct {
	Page  int `form:"page,default=1" binding:"omitempty,gte=1"`
	Limit int `form:"limit,default=20" binding:"omitempty,gte=1,lte=100"`
}

// UserQueryParams represents user list query params
type UserQueryParams struct {
	PaginationParams
	Status UserStatus `form:"status" binding:"omitempty,oneof=ACTIVE INACTIVE"`
}

// FuelReportQueryParams represents fuel report query params
type FuelReportQueryParams struct {
	Date      string     `form:"date"`       // Format: YYYY-MM-DD
	VehicleID *uuid.UUID `form:"vehicle_id"` // Filter by vehicle
}

// TripReportQueryParams represents trip report query params
type TripReportQueryParams struct {
	StartDate string `form:"start_date"` // Format: YYYY-MM-DD
	EndDate   string `form:"end_date"`   // Format: YYYY-MM-DD
}

// PayslipQueryParams represents payslip query params
type PayslipQueryParams struct {
	Month string `form:"month"` // Format: YYYY-MM
}

// ContractQueryParams represents contract query params
type ContractQueryParams struct {
	DriverID             *uuid.UUID `form:"driver_id"`             // Admin only - filter by driver
	AcknowledgmentStatus string     `form:"acknowledgment_status"` // Admin optional: PENDING | ACKNOWLEDGED | DECLINED
}

// ===== Upload DTO =====

// UploadResponse represents file upload response
type UploadResponse struct {
	FileURL  string `json:"file_url"`
	FileName string `json:"file_name"`
	FileSize int64  `json:"file_size"`
}

// ===== Payslip Confirm DTO =====

// ConfirmPayslipRequest represents request to confirm/complain payslip
type ConfirmPayslipRequest struct {
	Status PayslipStatus `json:"status" form:"status" binding:"required,oneof=CONFIRMED COMPLAINED"`
	Note   *string       `json:"note" form:"note"`
}

// ===== Checklist DTOs =====

// CreateChecklistRequest represents request to create a vehicle checklist
type CreateChecklistRequest struct {
	VehicleID uuid.UUID `json:"vehicle_id" form:"vehicle_id" binding:"required"`
	// TripID bắt buộc: checklist gắn với chuyến đã nhận lịch hoặc đang chạy.
	TripID     uuid.UUID `json:"trip_id" form:"trip_id" binding:"required"`
	TireCheck  bool      `json:"tire_check" form:"tire_check"`
	LightCheck bool      `json:"light_check" form:"light_check"`
	CleanCheck bool      `json:"clean_check" form:"clean_check"`
	BrakeCheck bool      `json:"brake_check" form:"brake_check"`
	OilCheck   bool      `json:"oil_check" form:"oil_check"`
	Note       *string   `json:"note" form:"note"`
}

// ChecklistQueryParams represents checklist query params
type ChecklistQueryParams struct {
	VehicleID *uuid.UUID `form:"vehicle_id"`
	Date      string     `form:"date"` // Format: YYYY-MM-DD
}

// ===== Trip DTOs =====

// StartTripRequest represents request to start a trip
type StartTripRequest struct {
	VehicleID uuid.UUID `json:"vehicle_id" form:"vehicle_id" binding:"required"`
	StartOdo  *int      `json:"start_odo" form:"start_odo"`
	StartLat  *float64  `json:"start_lat" form:"start_lat"`
	StartLng  *float64  `json:"start_lng" form:"start_lng"`
}

// EndTripRequest represents request to end a trip
type EndTripRequest struct {
	EndOdo *int     `json:"end_odo" form:"end_odo"`
	EndLat *float64 `json:"end_lat" form:"end_lat"`
	EndLng *float64 `json:"end_lng" form:"end_lng"`
}

// AdminCancelTripRequest — ADMIN hủy chuyến (có lý do, thông báo tài xế)
type AdminCancelTripRequest struct {
	Reason string `json:"reason" form:"reason" binding:"required,min=2,max=2000"`
}

// TripQueryParams represents trip query params
type TripQueryParams struct {
	Status    *TripStatus `form:"status"`
	VehicleID *uuid.UUID  `form:"vehicle_id"`
	StartDate string      `form:"start_date"` // Format: YYYY-MM-DD
	EndDate   string      `form:"end_date"`   // Format: YYYY-MM-DD
}

// ScheduleTripRequest — ADMIN tạo chuyến lịch trước cho tài xế
type ScheduleTripRequest struct {
	DriverID         uuid.UUID `json:"driver_id" form:"driver_id" binding:"required"`
	VehicleID        uuid.UUID `json:"vehicle_id" form:"vehicle_id" binding:"required"`
	ScheduledStartAt string    `json:"scheduled_start_at" form:"scheduled_start_at" binding:"required"` // RFC3339
	ScheduledEndAt   *string   `json:"scheduled_end_at,omitempty" form:"scheduled_end_at"`
	DriverNote       *string   `json:"driver_note,omitempty" form:"driver_note"`
}

// RespondTripRequest — DRIVER chấp nhận / từ chối chuyến được lên lịch
type RespondTripRequest struct {
	Status      TripStatus `json:"status" form:"status" binding:"required,oneof=DRIVER_ACCEPTED DRIVER_DECLINED"`
	DeclineNote *string    `json:"decline_note,omitempty" form:"decline_note"`
}

// StartScheduledTripRequest — DRIVER bắt đầu chạy sau khi đã DRIVER_ACCEPTED
type StartScheduledTripRequest struct {
	StartOdo *int     `json:"start_odo" form:"start_odo"`
	StartLat *float64 `json:"start_lat" form:"start_lat"`
	StartLng *float64 `json:"start_lng" form:"start_lng"`
}

// CreateVehicleRequest — ADMIN tạo xe
type CreateVehicleRequest struct {
	LicensePlate        string  `json:"license_plate" form:"license_plate" binding:"required"`
	VehicleType         *string `json:"vehicle_type,omitempty" form:"vehicle_type"`
	Status              string  `json:"status,omitempty" form:"status"`
	InsuranceExpiry     *string `json:"insurance_expiry,omitempty" form:"insurance_expiry"` // YYYY-MM-DD
	RegistrationExpiry  *string `json:"registration_expiry,omitempty" form:"registration_expiry"`
	LastMaintenanceDate *string `json:"last_maintenance_date,omitempty" form:"last_maintenance_date"`
	NextMaintenanceDate *string `json:"next_maintenance_date,omitempty" form:"next_maintenance_date"`
	ImageURL            *string `json:"image_url,omitempty" form:"image_url"` // URL sau upload ?folder=vehicles
}

// UpdateVehicleRequest — ADMIN cập nhật xe (chỉ gửi trường cần đổi)
type UpdateVehicleRequest struct {
	LicensePlate        *string `json:"license_plate,omitempty" form:"license_plate"`
	VehicleType         *string `json:"vehicle_type,omitempty" form:"vehicle_type"`
	Status              *string `json:"status,omitempty" form:"status"`
	ImageURL            *string `json:"image_url,omitempty" form:"image_url"`
	InsuranceExpiry     *string `json:"insurance_expiry,omitempty" form:"insurance_expiry"`
	RegistrationExpiry  *string `json:"registration_expiry,omitempty" form:"registration_expiry"`
	LastMaintenanceDate *string `json:"last_maintenance_date,omitempty" form:"last_maintenance_date"`
	NextMaintenanceDate *string `json:"next_maintenance_date,omitempty" form:"next_maintenance_date"`
}

// ===== Incident DTOs =====

// CreateIncidentRequest represents request to report an incident
type CreateIncidentRequest struct {
	VehicleID   uuid.UUID    `json:"vehicle_id" form:"vehicle_id" binding:"required"`
	TripID      *uuid.UUID   `json:"trip_id,omitempty" form:"trip_id"`
	Type        IncidentType `json:"type" form:"type" binding:"required,oneof=ACCIDENT BREAKDOWN TRAFFIC_TICKET"`
	Description *string      `json:"description" form:"description"`
	ImageURL    *string      `json:"image_url" form:"image_url"`
	GpsLat      *float64     `json:"gps_lat" form:"gps_lat"`
	GpsLng      *float64     `json:"gps_lng" form:"gps_lng"`
	// ViolationAt: thời điểm vi phạm (RFC3339), khuyến nghị với TRAFFIC_TICKET; mặc định = thời điểm gửi báo cáo
	ViolationAt *string `json:"violation_at" form:"violation_at"`
}

// IncidentQueryParams represents incident query params
type IncidentQueryParams struct {
	DriverID *uuid.UUID    `form:"driver_id"`
	Type     *IncidentType `form:"type"`
}

// ===== Notification DTOs =====

// CreateNotificationRequest represents request to create a notification
type CreateNotificationRequest struct {
	Title    string     `json:"title" form:"title" binding:"required"`
	Body     string     `json:"body" form:"body" binding:"required"`
	DriverID *uuid.UUID `json:"driver_id" form:"driver_id"` // NULL means broadcast
}

// ===== Fuel Report Export DTO =====

// FuelReportExportParams represents fuel report export query params
type FuelReportExportParams struct {
	StartDate string     `form:"start_date" binding:"required"` // Format: YYYY-MM-DD
	EndDate   string     `form:"end_date" binding:"required"`   // Format: YYYY-MM-DD
	DriverID  *uuid.UUID `form:"driver_id"`
}

// ===== Updated Fuel Report DTO =====

// CreateFuelReportRequestV2 represents updated request to create a fuel report
type CreateFuelReportRequestV2 struct {
	VehicleID       uuid.UUID `json:"vehicle_id" form:"vehicle_id" binding:"required"`
	ReportDate      string    `json:"report_date" form:"report_date"`
	OdoCurrent      *int      `json:"odo_current" form:"odo_current"`
	Liters          *float64  `json:"liters" form:"liters"`
	TotalCost       float64   `json:"total_cost" form:"total_cost" binding:"required,gt=0"`
	ReceiptImageURL string    `json:"receipt_image_url" form:"receipt_image_url" binding:"required"`
	OdoImageURL     *string   `json:"odo_image_url" form:"odo_image_url"`
	GpsLatitude     *float64  `json:"gps_latitude" form:"gps_latitude"`
	GpsLongitude    *float64  `json:"gps_longitude" form:"gps_longitude"`
}

// ===== Profile Update Request DTOs =====

// ReviewProfileUpdateRequest represents admin's approval/rejection action
type ReviewProfileUpdateRequest struct {
	Status    string  `json:"status" form:"status" binding:"required,oneof=APPROVED REJECTED"`
	AdminNote *string `json:"admin_note" form:"admin_note"`
}

// ProfileUpdateRequestQueryParams represents query params for listing requests (admin)
type ProfileUpdateRequestQueryParams struct {
	PaginationParams
	Status string `form:"status" binding:"omitempty,oneof=PENDING APPROVED REJECTED"`
}

// ===== Biometric Auth DTOs =====

// BiometricLoginRequest represents biometric login request payload
type BiometricLoginRequest struct {
	BiometricToken string `json:"biometric_token" form:"biometric_token" binding:"required"`
}

// EnableBiometricResponse represents the response after enabling biometric auth
type EnableBiometricResponse struct {
	BiometricToken string `json:"biometric_token"`
	ExpiresAt      string `json:"expires_at"`
}

// ===== Device Token DTOs =====

// RegisterDeviceRequest represents request to register FCM device token
type RegisterDeviceRequest struct {
	Token    string `json:"token" form:"token" binding:"required"`
	Platform string `json:"platform" form:"platform"` // android, ios, web
}

// UnregisterDeviceRequest represents request to unregister FCM device token
type UnregisterDeviceRequest struct {
	Token string `json:"token" form:"token" binding:"required"`
}

// ===== Import/Export DTOs =====

// PayslipImportItem represents a single row in payslip import
type PayslipImportItem struct {
	DriverID    uuid.UUID `json:"driver_id"`
	SalaryMonth string    `json:"salary_month"` // Format: YYYY-MM
	FileURL     string    `json:"file_url"`
}

// PayslipsImportRequest represents payslips import request
type PayslipsImportRequest struct {
	Items []PayslipImportItem `json:"items" binding:"required,dive"`
}

// ImportResult represents the result of an import operation
type ImportResult struct {
	TotalRows   int      `json:"total_rows"`
	SuccessRows int      `json:"success_rows"`
	ErrorRows   int      `json:"error_rows"`
	Errors      []string `json:"errors,omitempty"`
}
