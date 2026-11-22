extends RefCounted

enum { LOAD, PARTS, BUFFER, NAV, SAVE_SNAPSHOT, SAVE_JSON, SAVE_WRITE, UI, UPLOAD, SPECTACLE, LAND_MESH }
const LABELS := ["resource", "parts_mesh", "parts_growth", "navigation", "save_snapshot", "save_json",
	"save_write", "ui", "texture", "spectacle", "terrain_mesh"]
static var enabled := false
static var usec := PackedInt64Array()
static var load_paths := {}


static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func end(slot: int, started: int) -> void:
	if started != 0:
		usec[slot] += Time.get_ticks_usec() - started


static func loaded(path: String, started: int) -> void:
	if started != 0:
		var elapsed := Time.get_ticks_usec() - started
		usec[LOAD] += elapsed
		if elapsed >= 1000:
			load_paths[path] = elapsed
