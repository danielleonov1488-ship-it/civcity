extends RefCounted

enum { LOAD, PARTS, BUFFER, NAV, SAVE_SNAPSHOT, SAVE_JSON, SAVE_WRITE, UI, UPLOAD, SPECTACLE, LAND_MESH,
	GAME, CITY_VISUALS, SKY, TOOL, ACTORS, MATERIAL, MESH_READ, MESH_COPY, MULTIMESH,
	PLACEMENT, COVER, PORTRAIT, SETTINGS, QUALITY, FORT_ART, FORT_OPEN, BATTLE_OPEN,
	BATTLE_RESULT, BATTLE_CLOSE, CAMP_BUILD, CITY_GROW, PEOPLE, HUD, GRASS, HOUR_TAIL, SPECTACLE_FRAME, CROWD_CAPTURE, CROWD_BAKE, CROWD_UPLOAD }
const LABELS := ["resource", "parts_mesh", "parts_growth", "navigation", "save_snapshot", "save_json",
	"save_write", "ui", "texture", "spectacle", "terrain_mesh", "game", "city_visuals", "sky_lights",
	"tool", "actors", "material", "mesh_read", "mesh_copy", "multimesh", "placement", "cover",
	"portrait", "settings", "quality", "fort_art", "fort_open", "battle_open", "battle_result",
	"battle_close", "camp_build", "city_grow", "people", "hud_frame", "grass", "hour_tail", "spectacle_frame", "crowd_capture", "crowd_bake", "crowd_upload"]
static var enabled := false
static var usec := PackedInt64Array()
static var load_paths := {}
static var person_sections := {}


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


static func sections() -> Dictionary:
	var values := person_sections.duplicate()
	for id in LABELS.size():
		if usec[id] > 0:
			values[LABELS[id]] = usec[id] / 1000.0
	return values


static func reset_frame() -> void:
	usec.resize(LABELS.size())
	usec.fill(0)
	load_paths.clear()
	person_sections.clear()
