-- Add resource_type and resource_id columns to notifications table
-- for navigation when tapping notifications
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS resource_type TEXT,
    ADD COLUMN IF NOT EXISTS resource_id UUID;
