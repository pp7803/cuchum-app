package service

import (
	"context"
	"fmt"
	"log"
	"time"
)

const systemAutoCancelReason = "[Hệ thống] Không bắt đầu chuyến trong 30 phút kể từ giờ chạy dự kiến."

// RunDepartureJobs processes DRIVER_ACCEPTED scheduled trips: FCM + in-app reminders and auto-cancel.
// Intended to run about every minute from the API process (same binary as HTTP).
func (s *TripService) RunDepartureJobs(ctx context.Context) {
	if s == nil || s.tripRepo == nil {
		return
	}
	now := time.Now()

	trips, err := s.tripRepo.ListDriverAcceptedScheduledTrips(ctx)
	if err != nil {
		log.Printf("RunDepartureJobs: list trips: %v", err)
	} else {
		for _, t := range trips {
			if t == nil || t.ScheduledStartAt == nil {
				continue
			}
			sched := *t.ScheduledStartAt
			when := formatDriverLocalDateTime(sched)

			// T−10m … T: first time we are within 10 minutes before start (and before scheduled time).
			if t.NotifyDeparture10mSentAt == nil && !now.Before(sched.Add(-departureNotifyBeforeScheduled)) && now.Before(sched) {
				ok, mErr := s.tripRepo.TryMarkDepartureNotify10m(ctx, t.ID)
				if mErr != nil {
					log.Printf("RunDepartureJobs: mark 10m %s: %v", t.ID, mErr)
				} else if ok {
					s.notif.NotifyDriver(ctx, t.DriverID, "🚛 Sắp tới giờ chạy",
						fmt.Sprintf("Chuyến dự kiến bắt đầu lúc %s (còn khoảng 10 phút).", when))
				}
			}

			// At or after scheduled start (one shot).
			if t.NotifyDepartureStartSentAt == nil && !now.Before(sched) {
				ok, mErr := s.tripRepo.TryMarkDepartureNotifyStart(ctx, t.ID)
				if mErr != nil {
					log.Printf("RunDepartureJobs: mark start %s: %v", t.ID, mErr)
				} else if ok {
					s.notif.NotifyDriver(ctx, t.DriverID, "▶️ Đến giờ chạy dự kiến",
						fmt.Sprintf("Giờ bắt đầu dự kiến %s. Hoàn tất kiểm tra xe (nếu chưa) và bắt đầu chạy.", when))
				}
			}

			// T+10m: late reminder while still accepted and not started.
			if t.NotifyDepartureLateSentAt == nil && !now.Before(sched.Add(departureNotifyLateAfterStart)) {
				ok, mErr := s.tripRepo.TryMarkDepartureNotifyLate(ctx, t.ID)
				if mErr != nil {
					log.Printf("RunDepartureJobs: mark late %s: %v", t.ID, mErr)
				} else if ok {
					s.notif.NotifyDriver(ctx, t.DriverID, "⏰ Chuyến đang trễ",
						fmt.Sprintf("Đã quá giờ dự kiến %s. Hãy bắt đầu chạy sớm — tối đa 30 phút sau giờ dự kiến, sau đó chuyến sẽ bị hủy tự động.", when))
				}
			}
		}
	}

	driverIDs, err := s.tripRepo.AutoCancelStaleDriverAccepted(ctx, now, scheduledStartLateSlack, systemAutoCancelReason)
	if err != nil {
		log.Printf("RunDepartureJobs: auto-cancel: %v", err)
		return
	}
	for _, did := range driverIDs {
		s.notif.NotifyDriver(ctx, did, "❌ Chuyến bị hủy tự động",
			"Chuyến đã bị hủy vì không bắt đầu trong 30 phút kể từ giờ chạy dự kiến.")
	}
}
