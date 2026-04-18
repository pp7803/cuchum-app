-- Migration 008: Fix overly-restrictive unique constraint on profile_update_requests
-- The old UNIQUE(user_id, status) prevented a user from having more than one APPROVED/REJECTED
-- record over time. Replace it with a partial index that only enforces one PENDING per user.

-- Drop the existing constraint (created in migration 006)
ALTER TABLE profile_update_requests
    DROP CONSTRAINT IF EXISTS profile_update_requests_user_pending_unique;

-- Create a partial unique index: at most one PENDING request per user at any time.
-- APPROVED and REJECTED rows are historical and can be many per user.
CREATE UNIQUE INDEX IF NOT EXISTS idx_profile_update_requests_one_pending_per_user
    ON profile_update_requests(user_id)
    WHERE status = 'PENDING';
