package service

import (
	"context"
	"log"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
	"github.com/tsnn/ch-app/internal/repository"
)

type NotificationService struct {
	notificationRepo *repository.NotificationRepository
	deviceTokenRepo  *repository.DeviceTokenRepository
	fcmService       *FCMService
}

func NewNotificationService(
	notificationRepo *repository.NotificationRepository,
	deviceTokenRepo *repository.DeviceTokenRepository,
	fcmService *FCMService,
) *NotificationService {
	return &NotificationService{
		notificationRepo: notificationRepo,
		deviceTokenRepo:  deviceTokenRepo,
		fcmService:       fcmService,
	}
}

// Create saves a driver notification to DB and sends FCM push
func (s *NotificationService) Create(ctx context.Context, req models.CreateNotificationRequest) (*models.Notification, error) {
	notification := &models.Notification{
		Title:               req.Title,
		Body:                req.Body,
		DriverID:            req.DriverID,
		IsAdminNotification: false,
	}

	if err := s.notificationRepo.Create(ctx, notification); err != nil {
		return nil, err
	}

	// Push to connected SSE clients immediately
	GetSSEHub().Push(notification)
	go s.sendPushNotification(ctx, notification)
	return notification, nil
}

// NotifyAdmins saves an admin notification to DB + sends FCM push to all admins (non-blocking).
// Always uses context.Background() so the operation is not tied to a request lifecycle.
func (s *NotificationService) NotifyAdmins(ctx context.Context, title, body string) {
	bgCtx := context.Background()

	// Save to DB first (broadcast to all admins: driver_id = NULL, is_admin_notification = TRUE)
	notification := &models.Notification{
		Title:               title,
		Body:                body,
		DriverID:            nil,
		IsAdminNotification: true,
	}
	if err := s.notificationRepo.Create(bgCtx, notification); err != nil {
		log.Printf("Failed to save admin notification to DB: %v", err)
	}

	// Push to connected SSE clients immediately
	GetSSEHub().Push(notification)

	// Push FCM in background
	if s.fcmService == nil {
		return
	}
	go func() {
		tokens, err := s.deviceTokenRepo.GetAllAdminTokens(bgCtx)
		if err != nil || len(tokens) == 0 {
			return
		}
		data := map[string]string{
			"type":            "admin_alert",
			"notification_id": notification.ID.String(),
		}
		_, _ = s.fcmService.SendToMultipleDevices(bgCtx, tokens, title, body, data)
	}()
}

// NotifyDriver saves a notification for a specific driver and sends FCM push (non-blocking).
// Uses context.Background() for DB/FCM so work is not cancelled when the HTTP request ends.
func (s *NotificationService) NotifyDriver(_ context.Context, driverID uuid.UUID, title, body string) {
	bgCtx := context.Background()

	notification := &models.Notification{
		Title:               title,
		Body:                body,
		DriverID:            &driverID,
		IsAdminNotification: false,
	}
	if err := s.notificationRepo.Create(bgCtx, notification); err != nil {
		log.Printf("Failed to save driver notification to DB: %v", err)
		return
	}

	GetSSEHub().Push(notification)

	if s.fcmService == nil {
		return
	}
	go func() {
		tokens, err := s.deviceTokenRepo.GetTokensForUser(bgCtx, driverID)
		if err != nil || len(tokens) == 0 {
			return
		}
		data := map[string]string{
			"type":            "notification",
			"notification_id": notification.ID.String(),
		}
		_, _ = s.fcmService.SendToMultipleDevices(bgCtx, tokens, title, body, data)
	}()
}

// List returns notifications for the given user (DRIVER context)
func (s *NotificationService) List(ctx context.Context, driverID *uuid.UUID) ([]*models.Notification, error) {
	return s.notificationRepo.ListAll(ctx, driverID)
}

// ListAdminNotifications returns all admin system notifications
func (s *NotificationService) ListAdminNotifications(ctx context.Context) ([]*models.Notification, error) {
	return s.notificationRepo.ListForAdmin(ctx)
}

// MarkAsRead marks a notification as read for a user
func (s *NotificationService) MarkAsRead(ctx context.Context, notificationID uuid.UUID, userID uuid.UUID) error {
	return s.notificationRepo.MarkAsRead(ctx, notificationID, userID)
}

// UnreadCount returns unread notification count for a user
func (s *NotificationService) UnreadCount(ctx context.Context, userID uuid.UUID, isAdmin bool) (int, error) {
	return s.notificationRepo.UnreadCount(ctx, userID, isAdmin)
}

// sendPushNotification sends FCM push notification in background
func (s *NotificationService) sendPushNotification(ctx context.Context, notification *models.Notification) {
	if s.fcmService == nil {
		log.Println("FCM service not initialized, skipping push notification")
		return
	}

	data := map[string]string{
		"notification_id": notification.ID.String(),
		"type":            "notification",
	}

	var tokens []string
	var err error

	if notification.DriverID != nil {
		tokens, err = s.deviceTokenRepo.GetTokensForUser(ctx, *notification.DriverID)
	} else {
		tokens, err = s.deviceTokenRepo.GetAllDriverTokens(ctx)
	}

	if err != nil {
		log.Printf("Failed to get device tokens: %v", err)
		return
	}
	if len(tokens) == 0 {
		return
	}

	_, err = s.fcmService.SendToMultipleDevices(ctx, tokens, notification.Title, notification.Body, data)
	if err != nil {
		log.Printf("Failed to send FCM notification: %v", err)
	}
}

// RegisterDevice registers a device token for push notifications
func (s *NotificationService) RegisterDevice(ctx context.Context, userID uuid.UUID, token string, platform string) error {
	return s.deviceTokenRepo.SaveToken(ctx, userID, token, platform)
}

// UnregisterDevice removes a device token
func (s *NotificationService) UnregisterDevice(ctx context.Context, userID uuid.UUID, token string) error {
	return s.deviceTokenRepo.DeleteToken(ctx, userID, token)
}
