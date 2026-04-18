package service

import (
	"context"
	"fmt"
	"log"
	"sync"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type FCMService struct {
	client *messaging.Client
	mu     sync.RWMutex
}

var (
	fcmInstance *FCMService
	fcmOnce     sync.Once
)

// InitFCM initializes the Firebase Cloud Messaging service
func InitFCM(serviceAccountPath string) (*FCMService, error) {
	var initErr error
	fcmOnce.Do(func() {
		ctx := context.Background()
		opt := option.WithCredentialsFile(serviceAccountPath)

		app, err := firebase.NewApp(ctx, nil, opt)
		if err != nil {
			initErr = fmt.Errorf("failed to initialize Firebase app: %w", err)
			return
		}

		client, err := app.Messaging(ctx)
		if err != nil {
			initErr = fmt.Errorf("failed to get messaging client: %w", err)
			return
		}

		fcmInstance = &FCMService{client: client}
		log.Println("Firebase Cloud Messaging initialized successfully")
	})

	if initErr != nil {
		return nil, initErr
	}
	return fcmInstance, nil
}

// GetFCMService returns the singleton FCM instance
func GetFCMService() *FCMService {
	return fcmInstance
}

// SendToDevice sends a notification to a specific device token
func (s *FCMService) SendToDevice(ctx context.Context, token string, title, body string, data map[string]string) error {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if s.client == nil {
		return fmt.Errorf("FCM client not initialized")
	}

	message := &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				ClickAction: "FLUTTER_NOTIFICATION_CLICK",
				ChannelID:   "cuchum_notifications",
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Alert: &messaging.ApsAlert{
						Title: title,
						Body:  body,
					},
					Sound: "default",
					Badge: func() *int { i := 1; return &i }(),
				},
			},
		},
	}

	response, err := s.client.Send(ctx, message)
	if err != nil {
		return fmt.Errorf("failed to send FCM message: %w", err)
	}

	log.Printf("FCM message sent successfully: %s", response)
	return nil
}

// SendToMultipleDevices sends a notification to multiple device tokens
func (s *FCMService) SendToMultipleDevices(ctx context.Context, tokens []string, title, body string, data map[string]string) (*messaging.BatchResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if s.client == nil {
		return nil, fmt.Errorf("FCM client not initialized")
	}

	if len(tokens) == 0 {
		return nil, nil
	}

	message := &messaging.MulticastMessage{
		Tokens: tokens,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				ClickAction: "FLUTTER_NOTIFICATION_CLICK",
				ChannelID:   "cuchum_notifications",
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Alert: &messaging.ApsAlert{
						Title: title,
						Body:  body,
					},
					Sound: "default",
				},
			},
		},
	}

	response, err := s.client.SendEachForMulticast(ctx, message)
	if err != nil {
		return nil, fmt.Errorf("failed to send FCM multicast message: %w", err)
	}

	log.Printf("FCM multicast sent: %d success, %d failure", response.SuccessCount, response.FailureCount)
	return response, nil
}

// SendToTopic sends a notification to all devices subscribed to a topic
func (s *FCMService) SendToTopic(ctx context.Context, topic string, title, body string, data map[string]string) error {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if s.client == nil {
		return fmt.Errorf("FCM client not initialized")
	}

	message := &messaging.Message{
		Topic: topic,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				ClickAction: "FLUTTER_NOTIFICATION_CLICK",
				ChannelID:   "cuchum_notifications",
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Alert: &messaging.ApsAlert{
						Title: title,
						Body:  body,
					},
					Sound: "default",
				},
			},
		},
	}

	response, err := s.client.Send(ctx, message)
	if err != nil {
		return fmt.Errorf("failed to send FCM topic message: %w", err)
	}

	log.Printf("FCM topic message sent successfully: %s", response)
	return nil
}

// SubscribeToTopic subscribes device tokens to a topic
func (s *FCMService) SubscribeToTopic(ctx context.Context, tokens []string, topic string) error {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if s.client == nil {
		return fmt.Errorf("FCM client not initialized")
	}

	response, err := s.client.SubscribeToTopic(ctx, tokens, topic)
	if err != nil {
		return fmt.Errorf("failed to subscribe to topic: %w", err)
	}

	log.Printf("Subscribed to topic '%s': %d success, %d failure", topic, response.SuccessCount, response.FailureCount)
	return nil
}

// UnsubscribeFromTopic unsubscribes device tokens from a topic
func (s *FCMService) UnsubscribeFromTopic(ctx context.Context, tokens []string, topic string) error {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if s.client == nil {
		return fmt.Errorf("FCM client not initialized")
	}

	response, err := s.client.UnsubscribeFromTopic(ctx, tokens, topic)
	if err != nil {
		return fmt.Errorf("failed to unsubscribe from topic: %w", err)
	}

	log.Printf("Unsubscribed from topic '%s': %d success, %d failure", topic, response.SuccessCount, response.FailureCount)
	return nil
}
