class_name AnimClock
## Часы для мелких анимаций (крылья птиц, хвосты кошек, покачивание уток на воде).
## В игре — настоящее время. При съёмке ролика (scripts/promo_cam.gd, --fixed-fps) кадр считается дольше,
## чем идёт в видео: тогда часы ведёт съёмка (movie — секунды видео), и в ролике всё машет с нормальной скоростью.

static var movie := -1.0


static func now() -> float:
	return movie if movie >= 0.0 else Time.get_ticks_msec() / 1000.0
