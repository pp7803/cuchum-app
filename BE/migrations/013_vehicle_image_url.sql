-- Ảnh xe (URL sau upload POST /upload?folder=vehicles)
ALTER TABLE vehicles
    ADD COLUMN IF NOT EXISTS image_url TEXT;

COMMENT ON COLUMN vehicles.license_plate IS 'Biển số xe';
COMMENT ON COLUMN vehicles.image_url IS 'Đường dẫn ảnh xe trong /Media/vehicles/';
