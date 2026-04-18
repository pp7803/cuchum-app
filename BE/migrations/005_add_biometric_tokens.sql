-- Migration 005: Add biometric_tokens table for biometric authentication
-- Run this after 004_add_device_tokens.sql

-- Biometric tokens table (one active token per user)
CREATE TABLE IF NOT EXISTS biometric_tokens (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT        NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT biometric_tokens_user_id_unique UNIQUE (user_id),
    CONSTRAINT biometric_tokens_token_unique   UNIQUE (token)
);

CREATE INDEX IF NOT EXISTS idx_biometric_tokens_token   ON biometric_tokens(token);
CREATE INDEX IF NOT EXISTS idx_biometric_tokens_user_id ON biometric_tokens(user_id);

COMMENT ON TABLE  biometric_tokens            IS 'Stores long-lived biometric login tokens (one per user)';
COMMENT ON COLUMN biometric_tokens.token      IS '64-char hex random token, stored in plaintext (treated like a credential)';
COMMENT ON COLUMN biometric_tokens.expires_at IS 'Token expiry, default 1 year from issuance';
