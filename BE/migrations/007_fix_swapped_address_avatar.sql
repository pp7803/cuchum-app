-- Migration 007: Fix swapped address/avatar_url in driver_profiles and profile_update_requests
-- Caused by a bug where INSERT parameters $4 (address) and $5 (avatar_url) were swapped.
-- Run this after 006_add_profile_update_requests.sql

-- Fix driver_profiles: clear any address that looks like a Media path
UPDATE driver_profiles
SET address = NULL
WHERE address LIKE '/Media/%';

-- Fix profile_update_requests: swap back address and avatar_url where they were wrongly stored
UPDATE profile_update_requests
SET
    address   = avatar_url,
    avatar_url = address
WHERE address LIKE '/Media/%'
   OR avatar_url NOT LIKE '/Media/%' AND avatar_url IS NOT NULL AND address IS NULL;

-- Alternatively, just clear bad entries in pending requests
UPDATE profile_update_requests
SET address = NULL
WHERE address LIKE '/Media/%';
