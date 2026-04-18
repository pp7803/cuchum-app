-- Migration 012: GPLX (license_number), scheduled trips, trip links on fuel/checklist

-- Driver profile: số giấy phép lái xe
ALTER TABLE driver_profiles
    ADD COLUMN IF NOT EXISTS license_number VARCHAR(64);

ALTER TABLE profile_update_requests
    ADD COLUMN IF NOT EXISTS license_number VARCHAR(64);

-- Trips: admin schedules → driver accepts → driver starts
ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS scheduled_start_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS scheduled_end_at   TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS driver_note        TEXT,
    ADD COLUMN IF NOT EXISTS driver_decline_note TEXT;

COMMENT ON COLUMN trips.scheduled_start_at IS 'Thời điểm dự kiến bắt đầu chuyến (admin lên lịch)';
COMMENT ON COLUMN trips.driver_note IS 'Ghi chú của admin cho tài xế (vd: chở công nhân đối tác A)';

-- Liên kết checklist / fuel với chuyến (tùy chọn)
ALTER TABLE vehicle_checklists
    ADD COLUMN IF NOT EXISTS trip_id UUID REFERENCES trips(id) ON DELETE SET NULL;

ALTER TABLE fuel_reports
    ADD COLUMN IF NOT EXISTS trip_id UUID REFERENCES trips(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_vehicle_checklists_trip ON vehicle_checklists(trip_id);
CREATE INDEX IF NOT EXISTS idx_fuel_reports_trip ON fuel_reports(trip_id);
