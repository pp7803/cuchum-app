package models

import (
	"time"

	"github.com/google/uuid"
)

// UserRole represents user role enum
type UserRole string

const (
	RoleAdmin  UserRole = "ADMIN"
	RoleDriver UserRole = "DRIVER"
)

// UserStatus represents user status enum
type UserStatus string

const (
	StatusActive   UserStatus = "ACTIVE"
	StatusInactive UserStatus = "INACTIVE"
)

// User represents a user account
type User struct {
	ID           uuid.UUID  `json:"id"`
	PhoneNumber  string     `json:"phone_number"`
	Email        *string    `json:"email,omitempty"`
	PasswordHash string     `json:"-"`
	FullName     string     `json:"full_name"`
	Role         UserRole   `json:"role"`
	Status       UserStatus `json:"status"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

// DriverProfile represents a driver's profile
type DriverProfile struct {
	UserID        uuid.UUID `json:"user_id"`
	CitizenID     *string   `json:"citizen_id,omitempty"`
	LicenseClass  *string   `json:"license_class,omitempty"`
	LicenseNumber *string   `json:"license_number,omitempty"` // số GPLX
	Address       *string   `json:"address,omitempty"`
	AvatarURL     *string   `json:"avatar_url,omitempty"`
}

// ContractAcknowledgmentStatus is the driver's legal acknowledgment of the contract PDF
type ContractAcknowledgmentStatus string

const (
	ContractAckPending      ContractAcknowledgmentStatus = "PENDING"
	ContractAckAcknowledged ContractAcknowledgmentStatus = "ACKNOWLEDGED"
	ContractAckDeclined     ContractAcknowledgmentStatus = "DECLINED"
)

// Contract represents an employment contract
type Contract struct {
	ID                   uuid.UUID                    `json:"id"`
	DriverID             uuid.UUID                    `json:"driver_id"`
	DriverFullName       string                       `json:"driver_full_name,omitempty"`
	ContractNumber       string                       `json:"contract_number"`
	FileURL              string                       `json:"file_url"`
	StartDate            time.Time                    `json:"start_date"`
	EndDate              *time.Time                   `json:"end_date,omitempty"`
	IsViewed             bool                         `json:"is_viewed"`
	AcknowledgmentStatus ContractAcknowledgmentStatus `json:"acknowledgment_status"`
	DriverNote           *string                      `json:"driver_note,omitempty"`
	RespondedAt          *time.Time                   `json:"responded_at,omitempty"`
	CreatedAt            time.Time                    `json:"created_at"`
}

// Payslip represents a monthly salary slip
type Payslip struct {
	ID             uuid.UUID     `json:"id"`
	DriverID       uuid.UUID     `json:"driver_id"`
	DriverFullName string        `json:"driver_full_name,omitempty"`
	SalaryMonth    time.Time     `json:"salary_month"`
	FileURL        string        `json:"file_url"`
	IsViewed       bool          `json:"is_viewed"`
	Status         PayslipStatus `json:"status"`
	Note           *string       `json:"note,omitempty"`
	ConfirmedAt    *time.Time    `json:"confirmed_at,omitempty"`
	CreatedAt      time.Time     `json:"created_at"`
}

// Vehicle represents a vehicle
type Vehicle struct {
	ID                  uuid.UUID  `json:"id"`
	LicensePlate        string     `json:"license_plate"` // biển số xe
	VehicleType         *string    `json:"vehicle_type,omitempty"`
	Status              string     `json:"status"`
	ImageURL            *string    `json:"image_url,omitempty"` // ảnh xe (upload folder vehicles)
	InsuranceExpiry     *time.Time `json:"insurance_expiry,omitempty"`
	RegistrationExpiry  *time.Time `json:"registration_expiry,omitempty"`
	LastMaintenanceDate *time.Time `json:"last_maintenance_date,omitempty"`
	NextMaintenanceDate *time.Time `json:"next_maintenance_date,omitempty"`
}

// FuelReport represents a fuel expense report
type FuelReport struct {
	ID              uuid.UUID  `json:"id"`
	DriverID        uuid.UUID  `json:"driver_id"`
	VehicleID       *uuid.UUID `json:"vehicle_id,omitempty"`
	TripID          *uuid.UUID `json:"trip_id,omitempty"`
	ReportDate      time.Time  `json:"report_date"`
	OdoCurrent      *int       `json:"odo_current,omitempty"`
	Liters          *float64   `json:"liters,omitempty"`
	TotalCost       float64    `json:"total_cost"`
	ReceiptImageURL string     `json:"receipt_image_url"`
	OdoImageURL     *string    `json:"odo_image_url,omitempty"`
	GpsLatitude     *float64   `json:"gps_latitude,omitempty"`
	GpsLongitude    *float64   `json:"gps_longitude,omitempty"`
	AdminNote       *string    `json:"admin_note,omitempty"`
	FuelPurchasedAt *time.Time `json:"fuel_purchased_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

// DailyTripReport represents a daily trip count report
type DailyTripReport struct {
	ID         uuid.UUID `json:"id"`
	DriverID   uuid.UUID `json:"driver_id"`
	ReportDate time.Time `json:"report_date"`
	TotalTrips int       `json:"total_trips"`
	CreatedAt  time.Time `json:"created_at"`
}

// RefreshToken represents a refresh token for JWT renewal
type RefreshToken struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	Token     string     `json:"-"`
	ExpiresAt time.Time  `json:"expires_at"`
	CreatedAt time.Time  `json:"created_at"`
	RevokedAt *time.Time `json:"revoked_at,omitempty"`
}

// ProfileUpdateStatus represents the review status of a profile update request
type ProfileUpdateStatus string

const (
	ProfileUpdatePending  ProfileUpdateStatus = "PENDING"
	ProfileUpdateApproved ProfileUpdateStatus = "APPROVED"
	ProfileUpdateRejected ProfileUpdateStatus = "REJECTED"
)

// ProfileUpdateRequest represents a driver's request to update their profile fields
type ProfileUpdateRequest struct {
	ID            uuid.UUID           `json:"id"`
	UserID        uuid.UUID           `json:"user_id"`
	DriverName    string              `json:"driver_name,omitempty"`
	CitizenID     *string             `json:"citizen_id,omitempty"`
	LicenseClass  *string             `json:"license_class,omitempty"`
	LicenseNumber *string             `json:"license_number,omitempty"`
	Address       *string             `json:"address,omitempty"`
	AvatarURL     *string             `json:"avatar_url,omitempty"`
	ProofImageURL *string             `json:"proof_image_url,omitempty"`
	Status        ProfileUpdateStatus `json:"status"`
	AdminNote     *string             `json:"admin_note,omitempty"`
	ReviewedBy    *uuid.UUID          `json:"reviewed_by,omitempty"`
	ReviewedAt    *time.Time          `json:"reviewed_at,omitempty"`
	CreatedAt     time.Time           `json:"created_at"`
	UpdatedAt     time.Time           `json:"updated_at"`
}

// BiometricToken represents a long-lived token for biometric authentication
type BiometricToken struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	Token     string    `json:"-"` // Never expose in JSON
	ExpiresAt time.Time `json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// PasswordResetOTP represents a password reset OTP
type PasswordResetOTP struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	Email     string     `json:"email"`
	OTPCode   string     `json:"-"`
	ExpiresAt time.Time  `json:"expires_at"`
	UsedAt    *time.Time `json:"used_at,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}

// PayslipStatus represents payslip status enum
type PayslipStatus string

const (
	PayslipPending    PayslipStatus = "PENDING"
	PayslipViewed     PayslipStatus = "VIEWED"
	PayslipConfirmed  PayslipStatus = "CONFIRMED"
	PayslipComplained PayslipStatus = "COMPLAINED"
)

// TripStatus represents trip status enum
type TripStatus string

const (
	TripScheduledPending TripStatus = "SCHEDULED_PENDING" // Admin tạo, chờ tài xế phản hồi
	TripDriverAccepted   TripStatus = "DRIVER_ACCEPTED"   // Tài xế đồng ý, chưa bắt đầu chạy
	TripDriverDeclined   TripStatus = "DRIVER_DECLINED"   // Tài xế từ chối
	TripInProgress       TripStatus = "IN_PROGRESS"
	TripCompleted        TripStatus = "COMPLETED"
	TripCancelled        TripStatus = "CANCELLED"
)

// IncidentType represents incident type enum
type IncidentType string

const (
	IncidentAccident      IncidentType = "ACCIDENT"
	IncidentBreakdown     IncidentType = "BREAKDOWN"
	IncidentTrafficTicket IncidentType = "TRAFFIC_TICKET"
)

// VehicleChecklist represents a daily vehicle safety checklist
type VehicleChecklist struct {
	ID         uuid.UUID  `json:"id"`
	DriverID   uuid.UUID  `json:"driver_id"`
	VehicleID  uuid.UUID  `json:"vehicle_id"`
	TripID     *uuid.UUID `json:"trip_id,omitempty"`
	CheckDate  time.Time  `json:"check_date"`
	TireCheck  bool       `json:"tire_check"`
	LightCheck bool       `json:"light_check"`
	CleanCheck bool       `json:"clean_check"`
	BrakeCheck bool       `json:"brake_check"`
	OilCheck   bool       `json:"oil_check"`
	Note       *string    `json:"note,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
}

// Trip represents a single trip with GPS tracking
type Trip struct {
	ID                uuid.UUID  `json:"id"`
	DriverID          uuid.UUID  `json:"driver_id"`
	VehicleID         uuid.UUID  `json:"vehicle_id"`
	Status            TripStatus `json:"status"`
	ScheduledStartAt  *time.Time `json:"scheduled_start_at,omitempty"`
	ScheduledEndAt    *time.Time `json:"scheduled_end_at,omitempty"`
	DriverNote        *string    `json:"driver_note,omitempty"`
	DriverDeclineNote *string    `json:"driver_decline_note,omitempty"`
	AdminCancelReason *string    `json:"admin_cancel_reason,omitempty"`
	CancelledAt       *time.Time `json:"cancelled_at,omitempty"`
	// Set by background scheduler; omitted from JSON API responses.
	NotifyDeparture10mSentAt   *time.Time `json:"-"`
	NotifyDepartureStartSentAt *time.Time `json:"-"`
	NotifyDepartureLateSentAt  *time.Time `json:"-"`
	StartTime                  *time.Time `json:"start_time,omitempty"`
	EndTime                    *time.Time `json:"end_time,omitempty"`
	StartOdo                   *int       `json:"start_odo,omitempty"`
	EndOdo                     *int       `json:"end_odo,omitempty"`
	StartLat                   *float64   `json:"start_lat,omitempty"`
	StartLng                   *float64   `json:"start_lng,omitempty"`
	EndLat                     *float64   `json:"end_lat,omitempty"`
	EndLng                     *float64   `json:"end_lng,omitempty"`
	DistanceKm                 *float64   `json:"distance_km,omitempty"`
	CreatedAt                  time.Time  `json:"created_at"`
	// Enriched on GET /trips/:id only (not stored on trips row).
	LicensePlate *string `json:"license_plate,omitempty"`
	DriverName   *string `json:"driver_name,omitempty"`
}

// Incident represents a reported incident
type Incident struct {
	ID           uuid.UUID    `json:"id"`
	DriverID     uuid.UUID    `json:"driver_id"`
	VehicleID    uuid.UUID    `json:"vehicle_id"`
	TripID       *uuid.UUID   `json:"trip_id,omitempty"`
	IncidentType IncidentType `json:"type"`
	Description  *string      `json:"description,omitempty"`
	ImageURL     *string      `json:"image_url,omitempty"`
	GpsLat       *float64     `json:"gps_lat,omitempty"`
	GpsLng       *float64     `json:"gps_lng,omitempty"`
	IncidentDate time.Time    `json:"incident_date"`
	ResolvedAt   *time.Time   `json:"resolved_at,omitempty"`
	AdminNote    *string      `json:"admin_note,omitempty"`
	CreatedAt    time.Time    `json:"created_at"`
}

// Notification represents a notification message
type Notification struct {
	ID                  uuid.UUID  `json:"id"`
	Title               string     `json:"title"`
	Body                string     `json:"body"`
	DriverID            *uuid.UUID `json:"driver_id,omitempty"` // NULL = broadcast
	IsRead              bool       `json:"is_read"`
	IsAdminNotification bool       `json:"is_admin_notification"` // TRUE = targeted at admins
	CreatedBy           *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt           time.Time  `json:"created_at"`
}

// VehicleMaintenance represents vehicle maintenance information
type VehicleMaintenance struct {
	VehicleID           uuid.UUID  `json:"vehicle_id"`
	LicensePlate        string     `json:"license_plate"`
	ImageURL            *string    `json:"image_url,omitempty"`
	InsuranceExpiry     *time.Time `json:"insurance_expiry,omitempty"`
	RegistrationExpiry  *time.Time `json:"registration_expiry,omitempty"`
	LastMaintenanceDate *time.Time `json:"last_maintenance_date,omitempty"`
	NextMaintenanceDate *time.Time `json:"next_maintenance_date,omitempty"`
}

// FuelReportExport represents fuel report data for Excel export
type FuelReportExport struct {
	ID              uuid.UUID  `json:"id"`
	DriverID        uuid.UUID  `json:"driver_id"`
	DriverName      string     `json:"driver_name"`
	VehicleID       *uuid.UUID `json:"vehicle_id,omitempty"`
	ReportDate      time.Time  `json:"report_date"`
	OdoCurrent      *int       `json:"odo_current,omitempty"`
	Liters          *float64   `json:"liters,omitempty"`
	TotalCost       float64    `json:"total_cost"`
	ReceiptImageURL string     `json:"receipt_image_url"`
	AdminNote       *string    `json:"admin_note,omitempty"`
	FuelPurchasedAt *time.Time `json:"fuel_purchased_at,omitempty"`
}
