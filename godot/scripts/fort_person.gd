extends RefCounted
## Единая точка создания жителя для разреза, переноса и портрета.

const Kit = preload("res://scripts/ui_kit_a.gd")
const Portraits = preload("res://scripts/fort_portraits.gd")
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
		if room in ["hq", "barracks", "tower", "arsenal"]:
			var cls := String(person.get("cls", "legionary"))
			return cls if cls in CLASSES else "legionary"
	var female := bool(person.get("female", int(person.get("res", {}).get("m", {}).get("sx", 0)) == 1))
	return "newcomer_female" if female else "newcomer_male"


static func loadout(person: Dictionary, gear: Array, battle_class := "") -> Dictionary:
	if bool(person.get("centurion", false)) or battle_class == "hero":
		return {"outfit": "centurion", "helmet": true, "bow": false, "sword": true, "shield": true}
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
	if work != "" and battle_class.is_empty():
		outfit = work
	elif archer:
		outfit = "archer"
	elif battle_class == "priest":
		outfit = "priest"
	elif armor:
		outfit = "legionary"
	elif work != "":
		outfit = work
	return {"outfit": outfit, "helmet": helmet and not hero, "bow": hero and archer,
		"sword": weapon == "legionary" or battle_class in ["legionary", "hero", "spearman", "cavalry"],
		"shield": shield and not archer}


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
	elif bool(person.get("hero", false)) and battle_class != "hero":
		actor.add_dweller_hero_trim(String(person.get("cape", "a3283a")), int(person.get("crown", 1)))
	return actor


static func portrait_path(person: Dictionary, room := "", newcomer := false) -> String:
	return ART + art(person, room, newcomer) + "_portrait.png"


static func portrait(person: Dictionary, pixels: float, gear: Array = [], battle_class := "") -> PanelContainer:
	return _portrait_frame(_portrait_spec(person, gear, battle_class), pixels)


static func bind_portrait(rect: TextureRect, person: Dictionary, gear: Array = []) -> void:
	Portraits.bind(rect, _portrait_spec(person, gear))


static func rival_portrait(look: Dictionary, pixels: float) -> PanelContainer:
	var spec := {"key": JSON.stringify(["rival", look], "", true), "look": look, "clothes": {"outfit": "centurion"},
		"cape": String(look.get("cape", "a3283a")), "crown": int(look.get("crown", 1)), "rival": true}
	return _portrait_frame(spec, pixels)


static func _portrait_frame(spec: Dictionary, pixels: float) -> PanelContainer:
	var frame := Kit.slot(null, true, pixels)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var image := Kit.image(null, Vector2.ONE * maxf(1.0, pixels - 18.0))
	image.name = "FortPortraitArt"
	frame.add_child(image)
	Portraits.bind(image, spec)
	return frame


static func _portrait_spec(person: Dictionary, gear: Array, battle_class := "") -> Dictionary:
	var look := PersonLook.ensure(person.duplicate(true))
	var clothes := loadout(person, gear, battle_class)
	var cape := String(person.get("cape", "a3283a"))
	var crown := int(person.get("crown", 1)) if bool(person.get("hero", false)) else 0
	var pieces := {}
	for item: Dictionary in gear:
		pieces[String(item["slot"])] = [int(item.get("id", 0)), int(item.get("rarity", 0)), int(item.get("tier", 0))]
	var key := JSON.stringify([look, clothes, crown, cape, pieces], "", true)
	return {"key": key, "look": look, "clothes": clothes, "cape": cape, "crown": crown, "rival": false}


static func hero_person(lg: Legion) -> Dictionary:
	var c := lg.city() as City
	var person := lg.hero_dweller().duplicate()
	if Hero.exists(c):
		var chosen := Hero.look(c).duplicate()
		person["look"] = chosen
		person["female"] = Hero.female(c)
		person["cape"] = String(chosen.get("cape", "a3283a"))
		person["crown"] = int(chosen.get("crown", 1))
	person["hero"] = true
	return person


static func squad_person(lg: Legion, stats: Dictionary) -> Dictionary:
	if bool(stats.get("hero", false)) or stats.get("key") == "hero":
		return hero_person(lg)
	var sid := int(stats.get("sid", 0))
	var place := int(stats.get("place", -1))
	if sid == 0 and lg.v3() and place >= 0 and place < lg.squad3.size():
		sid = int(lg.squad3[place])
	var person := lg.soldier(sid)
	if not person.is_empty():
		return person
	return {"look_seed": hash([stats.get("key", ""), place, stats.get("name", "")])}
