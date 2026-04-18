-- Migration 006: Profile update requests (Driver submits → Admin approves/rejects)
-- Run this after 005_add_biometric_tokens.sql

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'profile_update_status') THEN
        CREATE TYPE profile_update_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS profile_update_requests (
    id             UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID                  NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- Requested new values (NULL means "not changing this field")
    citizen_id     TEXT,
    license_class  VARCHAR(20),
    address        TEXT,
    avatar_url     TEXT,
    -- Review
    status         VARCHAR(20)           NOT NULL DEFAULT 'PENDING',
    admin_note     TEXT,
    reviewed_by    UUID                  REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at    TIMESTAMPTZ,
    created_at     TIMESTAMPTZ           DEFAULT NOW(),
    updated_at     TIMESTAMPTZ           DEFAULT NOW()
);
-- Note: uniqueness (one PENDING per user) enforced by partial index below

CREATE INDEX IF NOT EXISTS idx_profile_update_requests_user_id ON profile_update_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_update_requests_status  ON profile_update_requests(status);

-- Partial unique index: only one PENDING request per user allowed at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_profile_update_requests_one_pending_per_user
    ON profile_update_requests(user_id)
    WHERE status = 'PENDING';

COMMENT ON TABLE  profile_update_requests        IS 'Stores driver profile change requests pending admin approval';
COMMENT ON COLUMN profile_update_requests.status IS 'PENDING | APPROVED | REJECTED';
