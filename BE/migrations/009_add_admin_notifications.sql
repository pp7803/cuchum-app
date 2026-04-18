-- Migration 009: Add is_admin_notification flag + mark_as_read for admin
-- Separates "admin system alerts" (profile updates, etc.) from "driver notifications"

ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS is_admin_notification BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_notifications_is_admin ON notifications(is_admin_notification);

COMMENT ON COLUMN notifications.is_admin_notification IS
    'TRUE = notification targeted at admin users (system alerts). FALSE = driver notification.';
