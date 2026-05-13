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
func (s *NotificationService) NotifyAdmins(ctx context.Context, title, body, resourceType string, resourceID *uuid.UUID) {
	bgCtx := context.Background()

	var rid *uuid.UUID
	if resourceID != nil {
		copy := *resourceID
		rid = &copy
	}
	var rt *string
	if resourceType != "" {
		copy := resourceType
		rt = &copy
	}

	// Save to DB first (broadcast to all admins: driver_id = NULL, is_admin_notification = TRUE)
	notification := &models.Notification{
		Title:               title,
		Body:                body,
		DriverID:            nil,
		IsAdminNotification: true,
		ResourceType:        rt,
		ResourceID:          rid,
	}
	if err := s.notificationRepo.Create(bgCtx, notification); err != nil {
		log.Printf("[NOTIF-ADMIN] ❌ DB insert failed: %v (title=%q)", err, title)
		return
	}
	log.Printf("[NOTIF-ADMIN] ✅ DB saved id=%s title=%q resource=%s/%v",
		notification.ID, title, strPtr(rt), rid)

	// Push to connected SSE clients immediately
	GetSSEHub().Push(notification)

	// Push FCM in background
	if s.fcmService == nil {
		log.Printf("[NOTIF-ADMIN] ⚠️ FCM disabled — skipping push for id=%s", notification.ID)
		return
	}
	go func() {
		tokens, err := s.deviceTokenRepo.GetAllAdminTokens(bgCtx)
		if err != nil {
			log.Printf("[NOTIF-ADMIN] ❌ FCM get admin tokens failed: %v (id=%s)", err, notification.ID)
			return
		}
		if len(tokens) == 0 {
			log.Printf("[NOTIF-ADMIN] ⚠️ No admin FCM tokens — skipping push (id=%s)", notification.ID)
			return
		}
		data := map[string]string{
			"type":            "admin_alert",
			"notification_id": notification.ID.String(),
		}
		if rt != nil {
			data["resource_type"] = *rt
		}
		if rid != nil {
			data["resource_id"] = rid.String()
		}
		log.Printf("[NOTIF-ADMIN] 📤 Sending FCM to %d admin device(s) id=%s", len(tokens), notification.ID)
		resp, err := s.fcmService.SendToMultipleDevices(bgCtx, tokens, title, body, data)
		if err != nil {
			log.Printf("[NOTIF-ADMIN] ❌ FCM send failed: %v (id=%s)", err, notification.ID)
		} else {
			log.Printf("[NOTIF-ADMIN] ✅ FCM sent id=%s success=%d failure=%d",
				notification.ID, resp.SuccessCount, resp.FailureCount)
		}
	}()
}

func strPtr(s *string) string {
	if s == nil {
		return "<nil>"
	}
	return *s
}

// NotifyDriver saves a notification for a specific driver and sends FCM push (non-blocking).
// Uses context.Background() for DB/FCM so work is not cancelled when the HTTP request ends.
func (s *NotificationService) NotifyDriver(_ context.Context, driverID uuid.UUID, title, body, resourceType string, resourceID *uuid.UUID) {
	bgCtx := context.Background()

	var rid *uuid.UUID
	if resourceID != nil {
		copy := *resourceID
		rid = &copy
	}
	var rt *string
	if resourceType != "" {
		copy := resourceType
		rt = &copy
	}

	notification := &models.Notification{
		Title:               title,
		Body:                body,
		DriverID:            &driverID,
		IsAdminNotification: false,
		ResourceType:        rt,
		ResourceID:          rid,
	}
	if err := s.notificationRepo.Create(bgCtx, notification); err != nil {
		log.Printf("[NOTIF-DRIVER] ❌ DB insert failed: %v (title=%q driver=%s)", err, title, driverID)
		return
	}
	log.Printf("[NOTIF-DRIVER] ✅ DB saved id=%s title=%q driver=%s resource=%s/%v",
		notification.ID, title, driverID, strPtr(rt), rid)

	GetSSEHub().Push(notification)

	if s.fcmService == nil {
		log.Printf("[NOTIF-DRIVER] ⚠️ FCM disabled — skipping push for id=%s", notification.ID)
		return
	}
	go func() {
		tokens, err := s.deviceTokenRepo.GetTokensForUser(bgCtx, driverID)
		if err != nil {
			log.Printf("[NOTIF-DRIVER] ❌ FCM get tokens failed: %v (id=%s driver=%s)", err, notification.ID, driverID)
			return
		}
		if len(tokens) == 0 {
			log.Printf("[NOTIF-DRIVER] ⚠️ No FCM tokens for driver=%s — skipping push (id=%s)", driverID, notification.ID)
			return
		}
		data := map[string]string{
			"type":            "notification",
			"notification_id": notification.ID.String(),
		}
		if rt != nil {
			data["resource_type"] = *rt
		}
		if rid != nil {
			data["resource_id"] = rid.String()
		}
		log.Printf("[NOTIF-DRIVER] 📤 Sending FCM to %d device(s) driver=%s id=%s", len(tokens), driverID, notification.ID)
		resp, err := s.fcmService.SendToMultipleDevices(bgCtx, tokens, title, body, data)
		if err != nil {
			log.Printf("[NOTIF-DRIVER] ❌ FCM send failed: %v (id=%s)", err, notification.ID)
		} else {
			log.Printf("[NOTIF-DRIVER] ✅ FCM sent id=%s success=%d failure=%d",
				notification.ID, resp.SuccessCount, resp.FailureCount)
		}
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
		log.Printf("[NOTIF-PUSH] ⚠️ FCM disabled — skipping id=%s", notification.ID)
		return
	}

	data := map[string]string{
		"notification_id": notification.ID.String(),
		"type":            "notification",
	}
	if notification.ResourceType != nil {
		data["resource_type"] = *notification.ResourceType
	}
	if notification.ResourceID != nil {
		data["resource_id"] = notification.ResourceID.String()
	}

	var tokens []string
	var err error
	var target string

	if notification.DriverID != nil {
		target = notification.DriverID.String()
		tokens, err = s.deviceTokenRepo.GetTokensForUser(ctx, *notification.DriverID)
	} else {
		target = "broadcast"
		tokens, err = s.deviceTokenRepo.GetAllDriverTokens(ctx)
	}

	if err != nil {
		log.Printf("[NOTIF-PUSH] ❌ Get tokens failed: %v (id=%s target=%s)", err, notification.ID, target)
		return
	}
	if len(tokens) == 0 {
		log.Printf("[NOTIF-PUSH] ⚠️ No tokens for target=%s — skipping (id=%s)", target, notification.ID)
		return
	}

	log.Printf("[NOTIF-PUSH] 📤 Sending FCM to %d device(s) target=%s id=%s", len(tokens), target, notification.ID)
	resp, err := s.fcmService.SendToMultipleDevices(ctx, tokens, notification.Title, notification.Body, data)
	if err != nil {
		log.Printf("[NOTIF-PUSH] ❌ FCM send failed: %v (id=%s)", err, notification.ID)
	} else {
		log.Printf("[NOTIF-PUSH] ✅ FCM sent id=%s success=%d failure=%d",
			notification.ID, resp.SuccessCount, resp.FailureCount)
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
