package service

import (
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"
)

// Driver-facing date/time strings (notifications, SMS-style copy) use Vietnam civil time
// so they match what admins and drivers expect, regardless of server TZ or UTC in JSON/DB.
var (
	vietnamTZOnce sync.Once
	vietnamTZ     *time.Location
)

func vietnamLocation() *time.Location {
	vietnamTZOnce.Do(func() {
		var err error
		vietnamTZ, err = time.LoadLocation("Asia/Ho_Chi_Minh")
		if err != nil {
			vietnamTZ = time.FixedZone("ICT", 7*3600)
		}
	})
	return vietnamTZ
}

func formatDriverLocalDateTime(t time.Time) string {
	return t.In(vietnamLocation()).Format("02/01/2006 15:04")
}

// ParseClientScheduleInstant parses admin-supplied scheduled times.
// RFC3339 / RFC3339Nano with zone first; otherwise treats a zone-less ISO-like
// string as wall clock in Asia/Ho_Chi_Minh (e.g. Dart local DateTime.toIso8601String()).
func ParseClientScheduleInstant(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Time{}, errors.New("empty time")
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t, nil
	}
	if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
		return t, nil
	}
	loc := vietnamLocation()
	for _, layout := range []string{
		"2006-01-02T15:04:05.000000000",
		"2006-01-02T15:04:05.000000",
		"2006-01-02T15:04:05.000",
		"2006-01-02T15:04:05",
	} {
		if t, err := time.ParseInLocation(layout, s, loc); err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("invalid time (use RFC3339): %q", s)
}
