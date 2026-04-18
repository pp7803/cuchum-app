-- Thời điểm mua/đổ xăng (theo tài xế), hiển thị YYYY-MM-DD HH:MM trên app.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'fuel_reports' AND column_name = 'fuel_purchased_at'
    ) THEN
        ALTER TABLE fuel_reports ADD COLUMN fuel_purchased_at TIMESTAMPTZ;
    END IF;
END$$;

COMMENT ON COLUMN fuel_reports.fuel_purchased_at IS 'Thời điểm mua nhiên liệu (UTC); NULL = không khai báo / dữ liệu cũ';
