-- Driver acknowledgment: xác nhận / không xác nhận (có lý do)
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS is_viewed BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS acknowledgment_status VARCHAR(32) NOT NULL DEFAULT 'PENDING';
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS driver_note TEXT;
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ;

ALTER TABLE contracts DROP CONSTRAINT IF EXISTS contracts_acknowledgment_status_check;
ALTER TABLE contracts ADD CONSTRAINT contracts_acknowledgment_status_check
    CHECK (acknowledgment_status IN ('PENDING', 'ACKNOWLEDGED', 'DECLINED'));

UPDATE contracts SET acknowledgment_status = 'PENDING' WHERE acknowledgment_status IS NULL OR acknowledgment_status = '';
