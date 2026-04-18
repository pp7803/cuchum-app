-- One-shot flags for driver departure reminders (cron / background worker).
ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS notify_departure_10m_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notify_departure_start_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notify_departure_late_sent_at TIMESTAMPTZ;
