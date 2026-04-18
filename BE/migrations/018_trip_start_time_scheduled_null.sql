-- Scheduled trips must not get start_time from DEFAULT CURRENT_TIMESTAMP (looked like "actual start"
-- before the driver tapped "bắt đầu chạy"). Only IN_PROGRESS/COMPLETED should have start_time set by app logic.
ALTER TABLE trips ALTER COLUMN start_time DROP DEFAULT;

UPDATE trips
SET start_time = NULL
WHERE scheduled_start_at IS NOT NULL
  AND status IN (
    'SCHEDULED_PENDING',
    'DRIVER_ACCEPTED',
    'DRIVER_DECLINED',
    'CANCELLED'
  );
