-- Track explicit cancel time for trips and link incidents to a specific trip.

ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

COMMENT ON COLUMN trips.cancelled_at IS 'Thời điểm chuyến bị hủy (admin/system).';

-- Backfill old cancelled trips with best-effort timestamp.
UPDATE trips
SET cancelled_at = COALESCE(cancelled_at, end_time, start_time, created_at)
WHERE status = 'CANCELLED'
  AND cancelled_at IS NULL;

ALTER TABLE incidents
    ADD COLUMN IF NOT EXISTS trip_id UUID REFERENCES trips(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_incidents_trip_id ON incidents(trip_id);
