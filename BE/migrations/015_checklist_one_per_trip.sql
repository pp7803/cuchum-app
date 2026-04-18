-- Một chuyến tối đa một checklist (trip_id NOT NULL); bỏ ràng buộc trùng theo ngày để cùng xe có nhiều chuyến trong một ngày.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'vehicle_checklists_driver_id_vehicle_id_check_date_key'
    ) THEN
        ALTER TABLE vehicle_checklists
            DROP CONSTRAINT vehicle_checklists_driver_id_vehicle_id_check_date_key;
    END IF;
END$$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_vehicle_checklists_trip_id
    ON vehicle_checklists (trip_id)
    WHERE trip_id IS NOT NULL;
