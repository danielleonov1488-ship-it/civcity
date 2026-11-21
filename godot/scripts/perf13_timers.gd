extends RefCounted

enum { BATTLE, SIM, SCORE, TEAM_DRAW, BARS, DRAW_BARS, PLAN, SEPARATE, GOAL, OUTLINE, RANGED_POSE, FORT, PLACE, SHADOWS, SOUND, FIELD, CITY, CITY_HOUR, CITY_STAFF, CITY_HOMES, CITY_ADVICE }
const LABELS := ["BATTLE", "SIM", "SCORE", "TEAM_DRAW", "BARS", "DRAW_BARS", "PLAN", "SEPARATE", "GOAL", "OUTLINE", "RANGED_POSE", "FORT", "PLACE", "SHADOWS", "SOUND", "FIELD", "CITY", "CITY_HOUR", "CITY_STAFF", "CITY_HOMES", "CITY_ADVICE"]
static var enabled := false
static var usec := PackedInt64Array()

static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func end(slot: int, started: int) -> void:
	if started != 0:
		usec[slot] += Time.get_ticks_usec() - started
