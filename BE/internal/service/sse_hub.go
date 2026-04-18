package service

import (
	"sync"

	"github.com/google/uuid"
	"github.com/tsnn/ch-app/internal/models"
)

// SSEClient represents a single connected SSE client
type SSEClient struct {
	UserID  uuid.UUID
	IsAdmin bool
	Ch      chan *models.Notification
}

// SSEHub manages all active SSE client connections
type SSEHub struct {
	mu      sync.RWMutex
	clients map[uuid.UUID][]*SSEClient
}

// singleton hub used across the whole process
var globalSSEHub = &SSEHub{clients: make(map[uuid.UUID][]*SSEClient)}

// GetSSEHub returns the global SSEHub singleton
func GetSSEHub() *SSEHub { return globalSSEHub }

// Register creates a channel for a new SSE client and registers it
func (h *SSEHub) Register(userID uuid.UUID, isAdmin bool) *SSEClient {
	client := &SSEClient{
		UserID:  userID,
		IsAdmin: isAdmin,
		Ch:      make(chan *models.Notification, 32),
	}
	h.mu.Lock()
	h.clients[userID] = append(h.clients[userID], client)
	h.mu.Unlock()
	return client
}

// Unregister removes the client and closes its channel
func (h *SSEHub) Unregister(client *SSEClient) {
	h.mu.Lock()
	defer h.mu.Unlock()

	list := h.clients[client.UserID]
	for i, c := range list {
		if c == client {
			h.clients[client.UserID] = append(list[:i], list[i+1:]...)
			close(c.Ch)
			break
		}
	}
	if len(h.clients[client.UserID]) == 0 {
		delete(h.clients, client.UserID)
	}
}

// Push delivers a notification to the appropriate connected clients:
//   - is_admin_notification = true  → all admin clients
//   - driver_id = specific uuid     → that driver's clients
//   - driver_id = nil               → all driver clients (broadcast)
func (h *SSEHub) Push(notification *models.Notification) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	send := func(ch chan *models.Notification) {
		select {
		case ch <- notification:
		default: // drop silently when buffer is full
		}
	}

	if notification.IsAdminNotification {
		for _, clients := range h.clients {
			for _, c := range clients {
				if c.IsAdmin {
					send(c.Ch)
				}
			}
		}
		return
	}

	if notification.DriverID != nil {
		for _, c := range h.clients[*notification.DriverID] {
			send(c.Ch)
		}
		return
	}

	// Broadcast to all driver clients
	for _, clients := range h.clients {
		for _, c := range clients {
			if !c.IsAdmin {
				send(c.Ch)
			}
		}
	}
}
