-- Migration 001: Add default admin user
-- Safe migration: Uses ON CONFLICT to skip if exists
-- Login: 0987654321 / admin@gmail.com / password: admin

INSERT INTO users (phone_number, email, password_hash, full_name, role, status)
VALUES (
    '0987654321',
    'admin@gmail.com',
    '$2a$10$Te/b.tZ4fUw1x8nWLds8mOKPNqq48Y9xvAsOU4jc3uXPMSyWrEDfi',
    'System Administrator',
    'ADMIN',
    'ACTIVE'
) ON CONFLICT (phone_number) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name;
