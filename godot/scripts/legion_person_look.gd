extends RefCounted
## Только постоянные части облика. Свой генератор не трогает броски Легиона.

const HAIR_TONES := ["A", "B", "C", "S"]
const SKIN_TONES := ["A", "B", "C"]


static func ensure(person: Dictionary, fallback_id := 1) -> Dictionary:
	var saved: Dictionary = person.get("look", {}) if person.get("look") is Dictionary else {}
	var meta: Dictionary = person.get("res", {}).get("m", {})
	var seed_value := int(person.get("look_seed", meta.get("sd", int(person.get("id", fallback_id)) * 409)))
	var female := bool(saved.get("female", person.get("female", int(meta.get("sx", 0)) == 1)))
	person["look_seed"] = seed_value
	person["female"] = female
	if saved.get("female") is bool and saved.get("skin") in SKIN_TONES and saved.get("hair") is int and saved.get("hair_color") in HAIR_TONES and saved.get("head") is int:
		saved["hair"] = clampi(int(saved["hair"]), 1 if female else 0, 6 if female else 7)
		saved["head"] = clampi(int(saved["head"]), 0, 2)
		return saved
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var skin: String = SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)]
	var hair := rng.randi_range(1 if female else 0, 6 if female else 7)
	var tone: String = HAIR_TONES[rng.randi_range(0, HAIR_TONES.size() - 1)]
	var head := rng.randi_range(0, 2)
	skin = String(saved.get("skin", skin))
	if skin not in SKIN_TONES:
		skin = "A"
	tone = String(saved.get("hair_color", saved.get("hc", tone)))
	var look := {
		"female": female, "skin": skin,
		"hair": clampi(int(saved.get("hair", hair)), 1 if female else 0, 6 if female else 7),
		"hair_color": tone if tone in HAIR_TONES else skin,
		"head": clampi(int(saved.get("head", head)), 0, 2),
	}
	person["look"] = look
	return look
