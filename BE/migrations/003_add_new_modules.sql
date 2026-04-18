-- Migration 003: Add new modules (Checklists, Trips, Incidents, Notifications)
-- Safe migration: Uses IF NOT EXISTS to avoid errors

-- Create ENUM types if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payslip_status') THEN
        CREATE TYPE payslip_status AS ENUM ('PENDING', 'VIEWED', 'CONFIRMED', 'COMPLAINED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trip_status') THEN
        CREATE TYPE trip_status AS ENUM ('IN_PROGRESS', 'COMPLETED', 'CANCELLED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'incident_type') THEN
        CREATE TYPE incident_type AS ENUM ('ACCIDENT', 'BREAKDOWN', 'TRAFFIC_TICKET');
    END IF;
END$$;

-- 1. Add new columns to payslips table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payslips' AND column_name = 'status') THEN
        ALTER TABLE payslips ADD COLUMN status VARCHAR(20) DEFAULT 'PENDING';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payslips' AND column_name = 'note') THEN
        ALTER TABLE payslips ADD COLUMN note TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payslips' AND column_name = 'confirmed_at') THEN
        ALTER TABLE payslips ADD COLUMN confirmed_at TIMESTAMP WITH TIME ZONE;
    END IF;
END$$;

-- 2. Add new columns to vehicles table (maintenance info)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vehicles' AND column_name = 'insurance_expiry') THEN
        ALTER TABLE vehicles ADD COLUMN insurance_expiry DATE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vehicles' AND column_name = 'registration_expiry') THEN
        ALTER TABLE vehicles ADD COLUMN registration_expiry DATE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vehicles' AND column_name = 'last_maintenance_date') THEN
        ALTER TABLE vehicles ADD COLUMN last_maintenance_date DATE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vehicles' AND column_name = 'next_maintenance_date') THEN
        ALTER TABLE vehicles ADD COLUMN next_maintenance_date DATE;
    END IF;
END$$;

-- 3. Add new columns to fuel_reports table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fuel_reports' AND column_name = 'odo_current') THEN
        ALTER TABLE fuel_reports ADD COLUMN odo_current INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fuel_reports' AND column_name = 'liters') THEN
        ALTER TABLE fuel_reports ADD COLUMN liters DECIMAL(8, 2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fuel_reports' AND column_name = 'odo_image_url') THEN
        ALTER TABLE fuel_reports ADD COLUMN odo_image_url TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fuel_reports' AND column_name = 'gps_latitude') THEN
        ALTER TABLE fuel_reports ADD COLUMN gps_latitude DECIMAL(10, 8);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fuel_reports' AND column_name = 'gps_longitude') THEN
        ALTER TABLE fuel_reports ADD COLUMN gps_longitude DECIMAL(11, 8);
    END IF;
END$$;

-- 4. Vehicle Checklists table
CREATE TABLE IF NOT EXISTS vehicle_checklists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    check_date DATE NOT NULL DEFAULT CURRENT_DATE,
    tire_check BOOLEAN NOT NULL DEFAULT FALSE,
    light_check BOOLEAN NOT NULL DEFAULT FALSE,
    clean_check BOOLEAN NOT NULL DEFAULT FALSE,
    brake_check BOOLEAN DEFAULT FALSE,
    oil_check BOOLEAN DEFAULT FALSE,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(driver_id, vehicle_id, check_date)
);

-- 5. Trips table (replaces daily_trip_reports for real-time tracking)
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'IN_PROGRESS',
    start_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP WITH TIME ZONE,
    start_odo INTEGER,
    end_odo INTEGER,
    start_lat DECIMAL(10, 8),
    start_lng DECIMAL(11, 8),
    end_lat DECIMAL(10, 8),
    end_lng DECIMAL(11, 8),
    distance_km DECIMAL(8, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. Incidents table
CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    incident_type VARCHAR(20) NOT NULL,
    description TEXT,
    image_url TEXT,
    gps_lat DECIMAL(10, 8),
    gps_lng DECIMAL(11, 8),
    incident_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE,
    admin_note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    driver_id UUID REFERENCES users(id) ON DELETE CASCADE, -- NULL means broadcast to all
    is_read BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_checklists_driver ON vehicle_checklists(driver_id);
CREATE INDEX IF NOT EXISTS idx_checklists_vehicle ON vehicle_checklists(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_checklists_date ON vehicle_checklists(check_date);

CREATE INDEX IF NOT EXISTS idx_trips_driver ON trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_vehicle ON trips(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_start_time ON trips(start_time);

CREATE INDEX IF NOT EXISTS idx_incidents_driver ON incidents(driver_id);
CREATE INDEX IF NOT EXISTS idx_incidents_vehicle ON incidents(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_incidents_type ON incidents(incident_type);
CREATE INDEX IF NOT EXISTS idx_incidents_date ON incidents(incident_date);

CREATE INDEX IF NOT EXISTS idx_notifications_driver ON notifications(driver_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);
