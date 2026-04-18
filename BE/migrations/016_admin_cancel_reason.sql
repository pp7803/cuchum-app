-- Lý do admin hủy chuyến (hiển thị cho tài xế / API).
ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS admin_cancel_reason TEXT;

COMMENT ON COLUMN trips.admin_cancel_reason IS 'Lý do hủy chuyến do quản trị viên (khi status = CANCELLED)';
