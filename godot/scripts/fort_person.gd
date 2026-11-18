extends RefCounted
## Единая точка создания жителя для разреза, переноса и портрета.

const Kit = preload("res://scripts/ui_kit_a.gd")
const ART := "res://assets/legion_b1/chars/"
const WORKERS := {"kitchen": "cook", "forge": "smith", "treasury": "treasurer",
	"mars": "priest", "smelter": "smith", "sawmill": "smith", "stable": "cavalry"}
const CLASSES := ["legionary", "archer", "priest", "cavalry"]


static func art(person: Dictionary, room := "", newcomer := false) -> String:
	if not newcomer:
		if bool(person.get("hero", false)):
			return "hero"
		if WORKERS.has(room):
			return String(WORKERS[room])
		if room in ["barracks", "drill", "tower", "arsenal"]:
			var cls := String(person.get("cls", "legionary"))
			return cls if cls in CLASSES else "legionary"
	var female := bool(person.get("female", int(person.get("res", {}).get("m", {}).get("sx", 0)) == 1))
	return "newcomer_female" if female else "newcomer_male"


static func make(person: Dictionary, room := "", newcomer := false, height := 171.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Kit.texture(ART + art(person, room, newcomer) + ".png")
	sprite.hframes = 8
	sprite.offset.y = 128.0 - 242.0
	sprite.scale = Vector2.ONE * (height / 242.0)
	return sprite


static func portrait_path(person: Dictionary, room := "", newcomer := false) -> String:
	return ART + art(person, room, newcomer) + "_portrait.png"


static func portrait(person: Dictionary, room: String, newcomer: bool, pixels: float) -> PanelContainer:
	return Kit.slot(portrait_path(person, room, newcomer), true, pixels)
