extends "res://scripts/charpilot_actor.gd"
## Внешность противника и набор боевых поз.

const ASSETS := "res://assets/legion_enemies/"
const BULL := "res://assets/animals/Bull.glb"
const SPRITES := ["minotaur", "cyclops", "elephant", "chariot", "charioteer", "horseArcher", "cataphract"]
const TROUSERS := ["celt", "dacian", "eastern"]
const ROBES := ["druid", "priest", "shade"]
# Туника, оружие, щит или колчан, головные уборы для двух вариантов.
const HUMANS := {
	"bandit": ["bandit", "cudgel", "", ["hood", ""]],
	"chief": ["bandit", "club", "", ["hood", "headband"]],
	"slinger": ["bandit", "sling", "", ["", "hood"]],
	"gaul": ["celt", "sword", "oval", ["", "celt_helm"]],
	"gaulArcher": ["celt", "bow", "quiver", ["", "headband"]],
	"briton": ["celt", "sword", "hex", ["headband", ""]],
	"celtiberian": ["celt", "sword", "oval", ["cap", ""]],
	"gaulKing": ["celt", "sword", "oval", ["crest", "crest"]],
	"berserker": ["german", "axe", "round", ["", "headband"]],
	"germArcher": ["german", "bow", "quiver", ["", "headband"]],
	"giant": ["german", "club", "", ["", "headband"]],
	"arminius": ["german", "spear", "round", ["headband", "celt_helm"]],
	"druid": ["druid", "staff", "", ["druid_hood", "druid_hood"]],
	"druidBoss": ["druid", "staff", "", ["druid_hood", "druid_hood"]],
	"priest": ["priest", "staff", "", ["veil", "nemes"]],
	"setPriest": ["priest", "staff", "", ["nemes_gold", "nemes_gold"]],
	"zalPriest": ["druid", "staff", "", ["cap", "druid_hood"]],
	"khopesh": ["egypt", "khopesh", "", ["nemes", "nemes"]],
	"nileArcher": ["egypt", "bow", "quiver", ["nemes", "nemes"]],
	"pharaoh": ["egypt", "khopesh", "", ["nemes_gold", "nemes_gold"]],
	"mercenary": ["carthage", "sword", "round", ["celt_helm", ""]],
	"hannibal": ["carthage", "sword", "round", ["crest", "crest"]],
	"numidian": ["numidian", "bow", "quiver", ["headband", ""]],
	"cataphractFoe": ["eastern", "spear", "round", ["cone", "cone"]],
	"surena": ["eastern", "bow", "quiver", ["cone", "cone"]],
	"dacian": ["dacian", "falx", "", ["cap", ""]],
	"decebalus": ["dacian", "falx", "", ["cap", "celt_helm"]],
	"pirate": ["pirate", "knife", "", ["headband", "headband"]],
	"shade": ["shade", "sword", "", ["dark_hood", "dark_hood"]],
	"spartacus": ["bandit", "sword", "round", ["headband", ""]],
	"salassi": ["celt", "axe", "hex", ["celt_helm", "headband"]],
	"vercingetorix": ["celt", "sword", "oval", ["crest", "crest"]],
	"boudicca": ["celt", "sword", "hex", ["", "headband"]],
	"viriathus": ["celt", "sword", "oval", ["headband", "cap"]],
}
const BEASTS := {
	"forestBear": ["bear", Color(1.22, 1.18, 1.12), 0.88, false, false],
	"bear": ["bear", Color.WHITE, 1.0, false, false],
	"venomBear": ["bear", Color("9eb663"), 0.96, false, false],
	"hadesBear": ["bear", Color("675874"), 0.96, true, false],
	"greatbear": ["bear", Color("dba78c"), 1.02, false, true],
	"hadesGuardian": ["bear", Color("5c4f67"), 1.06, true, true],
	"boar": ["boar", Color.WHITE, 1.0, false, false],
	"bull": ["bull", Color.WHITE, 1.0, false, false],
	"bullLeader": ["bull", Color("c19c82"), 1.04, false, false],
}

static var _animals: Dictionary = {}
static var _animal_materials: Dictionary = {}
static var _shade_material: StandardMaterial3D

var idle := "Sword_Idle"
var walk := "Walk"
var strike := "Sword_Attack"
var reaction := "Hit_Chest"
var fall := "Death01"
var stature := 1.79
var size_factor := 1.0
var yaw := 57.0
var wide := false


static func prewarm(waves: Array) -> void:
	var warmed := {}
	for wave: Array in waves:
		for entry: Dictionary in wave:
			var key := String(entry.get("key", ""))
			if warmed.has(key):
				continue
			warmed[key] = true
			if BEASTS.has(key):
				animal_scene(String(BEASTS[key][0]))
			elif HUMANS.has(key):
				var kit: Array = HUMANS[key]
				var sex := "_f" if key == "boudicca" else "_m"
				_kit_file(_body_file(kit[0], sex), ASSETS)
				for i in 2:
					_kit_file("%s_%d%s" % [kit[0], i, sex], ASSETS)
				for part: String in [kit[1], kit[2], kit[3][0], kit[3][1]]:
					if not part.is_empty():
						_kit_file(part, ASSETS)
				if kit[0] == "celt" and sex == "_m":
					_kit_file("moustache", ASSETS)


func build_enemy(key: String, number: int, variant := -1) -> bool:
	var wanted := false
	if HUMANS.has(key):
		wanted = _build_human(key, posmod(number if variant < 0 else variant, 2))
	elif BEASTS.has(key):
		wanted = _build_beast(key)
	if not wanted:
		return false
	for action: String in [idle, walk, strike, reaction, fall]:
		if clip_length(action) <= 0.0:
			return _fail("missing enemy clip %s: %s" % [key, action])
	return pose_at(idle, float(number % 6) * 0.13)


static func _body_file(style: String, suffix: String) -> String:
	if style in ROBES:
		return "local_robed" + suffix
	return ("local_covered" if style in TROUSERS else "local_body") + suffix


func _build_human(key: String, variation: int) -> bool:
	var kit: Array = HUMANS[key]
	var style := String(kit[0])
	var equipment := String(kit[1])
	var hat: String = kit[3][variation]
	_family = 1
	_female = key == "boudicca"
	var hair := 0
	var beard := 0
	if hat in ["", "headband"]:
		hair = (3 if variation == 0 else 5) if style in ["celt", "german"] else (2 if variation == 0 else 4)
		if _female:
			hair = 1 if variation == 0 else 3
	if style in ["german", "druid", "dacian", "bandit"] and not _female:
		beard = (2 if variation == 0 else 4) if style in ["german", "druid", "dacian"] else (1 if variation == 0 else 0)
	var hair_color := "S" if style == "druid" else ("C" if variation == 0 and style in ["celt", "german"] else "B")
	var complexion := "C" if style == "numidian" else "A"
	if style in ["egypt", "priest", "carthage"]:
		complexion = "B" if variation == 0 else "C"
	if not _build_synty(complexion, {"hair": hair, "beard": beard, "hair_color": hair_color}):
		return false
	if key == "shade":
		_atlas = _shade(_atlas as StandardMaterial3D)
		for part: MeshInstance3D in identity:
			part.material_override = _atlas
	var outfit_root := Node3D.new()
	outfit_root.name = "EnemyOutfit"
	_rig.add_child(outfit_root)
	# У друидов и египтян выбираем светлое льняное полотно из двух выкрасок.
	var fabric := 1 if style == "priest" else (0 if style in ["egypt", "druid"] else variation)
	for part: String in [_body_file(style, _suffix()), "%s_%d%s" % [style, fabric, _suffix()], equipment, kit[2], hat]:
		if not part.is_empty() and not _add_kit_file(part, outfit_root, _atlas, ASSETS):
			return false
	if style == "celt" and not _female and not _add_kit_file("moustache", outfit_root, _atlas, ASSETS):
		return false
	if equipment in ["bow", "staff", "sling"]:
		idle = "Spell_Simple_Idle"
		strike = "Spell_Simple_Shoot" if equipment != "sling" else "Punch_Cross"
		yaw = 49.0
	if hat == "crest":
		stature = 2.02
	elif hat in ["cap", "cone"]:
		stature = 1.96
	set_meta("enemy_style", style)
	set_meta("enemy_variant", variation)
	return true


static func _shade(atlas: StandardMaterial3D) -> StandardMaterial3D:
	if _shade_material == null:
		_shade_material = atlas.duplicate() as StandardMaterial3D
		_shade_material.albedo_color = Color("758baf")
		_shade_material.emission_enabled = true
		_shade_material.emission = Color("334f79")
		_shade_material.emission_energy_multiplier = 0.14
	return _shade_material


static func animal_scene(kind: String) -> PackedScene:
	if not _animals.has(kind):
		var path := BULL if kind == "bull" else ASSETS + kind + ".glb"
		if ResourceLoader.exists(path, "PackedScene"):
			_animals[kind] = load(path)
	return _animals.get(kind) as PackedScene


func _build_beast(key: String) -> bool:
	var style: Array = BEASTS[key]
	var kind := String(style[0])
	var scene := animal_scene(kind)
	if scene == null:
		return _fail("missing enemy animal " + kind)
	var body := scene.instantiate() as Node3D
	add_child(body)
	var animation_players := body.find_children("*", "AnimationPlayer", true, false)
	if animation_players.is_empty():
		return _fail("enemy animal without animations " + kind)
	_register_player(animation_players[0] as AnimationPlayer)
	wide = true
	idle = "Idle"
	walk = "Run" if key in ["forestBear", "hadesBear", "venomBear", "boar"] else "Walk"
	strike = "Attack"
	reaction = "Hit"
	fall = "Death"
	stature = 1.30 if kind == "bear" else 1.08
	size_factor = float(style[2])
	yaw = 66.0
	if kind == "bull":
		strike = "Attack_Headbutt"
		reaction = "Idle_HitReact_Left"
		stature = 1.53
		body.scale = Vector3.ONE * 0.34
	for part: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.custom_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 5, 6))
		for i in part.mesh.get_surface_count():
			var material := part.get_active_material(i) as StandardMaterial3D
			if material != null:
				part.set_surface_override_material(i, _animal_skin(key, material, style, kind != "bull"))
	set_meta("enemy_style", kind)
	return true


static func _animal_skin(key: String, original: StandardMaterial3D, style: Array, vertex_palette: bool) -> Material:
	var swatch := "%s/%s" % [key, original.resource_name]
	if not _animal_materials.has(swatch):
		var material := original.duplicate() as StandardMaterial3D
		if vertex_palette:
			material.vertex_color_use_as_albedo = true
		match original.resource_name:
			"Coat", "Main", "Main_Light", "Muzzle":
				var tint: Color = style[1]
				material.albedo_color *= tint
			"Eyes":
				if style[3]:
					material.emission_enabled = true
					material.emission = Color("ff581c")
					material.emission_energy_multiplier = 0.8
			"Scars":
				if not style[4]:
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					material.albedo_color = Color.TRANSPARENT
		_animal_materials[swatch] = material
	return _animal_materials[swatch] as Material
