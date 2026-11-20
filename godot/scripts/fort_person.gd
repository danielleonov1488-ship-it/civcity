extends RefCounted
## Единая точка создания жителя для разреза, переноса и портрета.

const Kit = preload("res://scripts/ui_kit_a.gd")
const Actor = preload("res://scripts/charpilot_actor.gd")
const PersonLook = preload("res://scripts/legion_person_look.gd")
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


static func loadout(person: Dictionary, gear: Array, battle_class := "") -> Dictionary:
	var hero := bool(person.get("hero", false)) or battle_class == "hero"
	var weapon := ""
	var work := ""
	var armor := false
	var helmet := false
	var shield := false
	for item: Dictionary in gear:
		match String(item["slot"]):
			"weapon":
				weapon = Gear.weapon_class(item)
			"armor":
				armor = true
			"helmet":
				helmet = true
			"offhand":
				shield = true
			Gear.OUTFIT_SLOT:
				work = String(Gear.WORK_LOOK.get(Gear.work_kind(item), ""))
	var archer := weapon == "archer" or battle_class in ["archer", "ballista", "catapult"]
	var outfit := "peasant"
	if hero:
		outfit = "centurion"
	elif work != "" and battle_class.is_empty():
		outfit = work
	elif archer:
		outfit = "archer"
	elif battle_class == "priest":
		outfit = "priest"
	elif armor:
		outfit = "legionary"
	elif work != "":
		outfit = work
	return {"outfit": outfit, "helmet": helmet or hero, "bow": hero and archer,
		"sword": (hero and not archer) or weapon == "legionary" or battle_class in ["legionary", "spearman", "cavalry"],
		"shield": (shield or hero) and not (hero and archer)}


static func make(person: Dictionary, parent: Node, gear: Array, battle_class := "") -> Actor:
	var look := PersonLook.ensure(person)
	var clothes := loadout(person, gear, battle_class)
	var actor := Actor.new()
	actor.set_meta("look", look.duplicate())
	actor.set_meta("loadout", clothes)
	parent.add_child(actor)
	if not actor.build(1, bool(look["female"]), String(look["skin"]), look, String(clothes["outfit"])) or not actor.set_loadout(clothes):
		push_warning("Synty: " + actor.problem)
		actor.hide()
	return actor


static func portrait_path(person: Dictionary, room := "", newcomer := false) -> String:
	return ART + art(person, room, newcomer) + "_portrait.png"


static func portrait(person: Dictionary, room: String, newcomer: bool, pixels: float) -> PanelContainer:
	return Kit.slot(portrait_path(person, room, newcomer), true, pixels)
