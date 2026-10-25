class_name Looks
extends RefCounted
## Облик жителя меняется (этап 6.5 плана от 24.10): в цирюльне — причёска и борода, в лавках одежды — цвета.
## Сам житель иногда меняет облик, когда сходит в лавку (visit) — даже если его сейчас не видно (меняется запись).
## Игрок выбирает в карточке жителя из того, что открыли лавки города (options). Дети не носят бород и венков.
## Те же списки и правила — для «Гардероба» своего героя (Д11).

const BEARDS := 4
const CROWNS := 2
const TONES := ["A", "B", "C"]                # цвет волос — тона палитры Synty (S — седые, у стариков)
## Яркие краски красильни: шафран, марена, вайда, мирт, аметист, оранжевый, морская волна, кермес
const DYES := ["d9a93e", "b4432f", "4d7397", "6f8a4e", "8c5fa0", "c9733a", "5e9488", "a82c3c"]
const WHITE := ["f4f1ea", "f8f6f0"]           # тога из фуллоники — белее белого
const LUX := ["6e2a5a", "d4a548", "a3283a"]   # кайма из мастерской тог: пурпур, золото, кермес
## Как часто поход в лавку меняет облик
const CHANCE := {"barber": 0.3, "weaver": 0.15, "cobbler": 0.08, "dyer": 0.35, "fullonica": 0.3, "tailor": 0.25, "jeweler": 0.2}
## Что меняет лавка (для подсказок в карточке)
const SHOP_WHAT := {"barber": "причёски, бороды и цвет волос", "weaver": "цвета одежды", "dyer": "яркие краски",
	"fullonica": "тогу белее", "tailor": "пурпурную и золотую кайму", "jeweler": "лавровый венок"}


static func hair_max(female: bool) -> int:
	return 6 if female else 7


## Цвета туники по сословию (палитра Citizen.PAL), первые n
static func class_cols(cls: String, female: bool, mdl: String, n := 8) -> Array:
	var pal: Array = Citizen.PAL.get(cls, Citizen.PAL["plebs"])
	if mdl == "SK_Chr_Politician_Male_01":
		pal = Citizen.PAL["senator"]
	elif cls == "patricians":
		pal = Citizen.PAL["patricians_f" if female else "patricians_m"]
	var out := []
	for e: Array in pal:
		out.append(String(e[0]))
		if out.size() >= n:
			break
	return out


## Есть ли у модели такая ткань: "main", "second" (тога, нижняя туника), "trim" (кайма)
static func has_part(mdl: String, part: String) -> bool:
	return (Citizen.CLOTH.get(mdl, {}) as Dictionary).has(part) or (part == "trim" and mdl == "SK_Chr_Worker_Male_01")


## Новый основной цвет; у рабочего кайма — светлее той же ткани (как у Synty)
static func set_main(lk: Dictionary, hex: String) -> void:
	lk["main"] = hex
	if String(lk.get("mdl", "")) == "SK_Chr_Worker_Male_01":
		lk["trim"] = Color(hex).lerp(Color("e8dfcc"), 0.55).to_html(false)


## Другое значение из 1…n (не то же самое); у ребёнка-мальчика без лысеющей «седьмой»
static func _other(cur: int, n: int, rg: RandomNumberGenerator, skip := -1) -> int:
	for k in 8:
		var v := 1 + rg.randi() % n
		if v != cur and v != skip:
			return v
	return cur


static func _pick_other(cur: String, opts: Array, rg: RandomNumberGenerator) -> String:
	var o := opts.filter(func(x): return String(x) != cur)
	return String(o[rg.randi() % o.size()]) if not o.is_empty() else cur


## Житель сходил в лавку типа t: облик lk иногда меняется (true — поменялся)
static func visit(lk: Dictionary, t: String, female: bool, child: bool, cls: String, rg: RandomNumberGenerator) -> bool:
	var p := float(CHANCE.get(t, 0.0))
	if p <= 0.0 or rg.randf() >= p:
		return false
	var mdl := String(lk.get("mdl", ""))
	match t:
		"barber":
			if not female and not child and rg.randf() < 0.4:
				var b := int(lk.get("beard", 0))
				lk["beard"] = 0 if b > 0 and rg.randf() < 0.4 else _other(b, BEARDS, rg)    # сбрил, подстриг или отпустил
			else:
				lk["hair"] = _other(int(lk.get("hair", 1)), hair_max(female), rg, 7 if child and not female else -1)
		"weaver", "cobbler":
			if not lk.has("main"):
				return false
			set_main(lk, _pick_other(String(lk["main"]), class_cols(cls, female, mdl), rg))
		"dyer":
			if not lk.has("main"):
				return false
			set_main(lk, _pick_other(String(lk["main"]), DYES, rg))
		"fullonica":
			if not lk.has("second") or not has_part(mdl, "second"):
				return false
			lk["second"] = _pick_other(String(lk["second"]), WHITE, rg)
		"tailor":
			if has_part(mdl, "trim") and mdl != "SK_Chr_Worker_Male_01" and lk.has("trim"):
				lk["trim"] = _pick_other(String(lk["trim"]), LUX, rg)
			elif has_part(mdl, "second") and lk.has("second"):
				lk["second"] = _pick_other(String(lk["second"]), WHITE, rg)
			else:
				return false
		"jeweler":
			if child or cls == "plebs" or int(lk.get("crown", 0)) > 0:
				return false
			lk["crown"] = 1 + rg.randi() % CROWNS
		_:
			return false
	return true


## Что игрок может выбрать в «Внешности» (карточка жителя): открывают лавки, что стоят в городе.
## {hair, beard, tone, crown: bool; cols, second, trim: [«rrggbb»]; need: {что: лавка, что откроет}}
static func options(city: City, lk: Dictionary, female: bool, child: bool, cls: String) -> Dictionary:
	var has := {}
	for id in city.buildings:
		has[String(city.buildings[id]["type"])] = true
	var mdl := String(lk.get("mdl", ""))
	var o := {"hair": has.has("barber"), "beard": has.has("barber") and not female and not child, "tone": has.has("barber"),
		"crown": has.has("jeweler") and not child and cls != "plebs", "cols": [], "second": [], "trim": [], "need": {}}
	if lk.has("main") and (has.has("weaver") or has.has("cobbler") or has.has("dyer") or has.has("tailor") or has.has("fullonica")):
		o["cols"] = class_cols(cls, female, mdl, 6)
	if lk.has("main") and has.has("dyer"):
		for c: String in DYES:
			if not (c in o["cols"]):
				o["cols"].append(c)
	if has.has("fullonica") and has_part(mdl, "second") and lk.has("second"):
		o["second"] = WHITE + Citizen.PAL["toga"].map(func(e): return String(e[0]))
	if has.has("tailor") and has_part(mdl, "trim") and mdl != "SK_Chr_Worker_Male_01" and lk.has("trim"):
		o["trim"] = LUX + Citizen.PAL["belt"].map(func(e): return String(e[0]))
	# чего не хватает — подсказать, какая лавка откроет
	if not has.has("barber"):
		o["need"]["hair"] = "Цирюльня"
	if (o["cols"] as Array).is_empty() and lk.has("main"):
		o["need"]["cols"] = "Ткацкая лавка"
	elif not has.has("dyer") and lk.has("main"):
		o["need"]["dyes"] = "Красильня"
	return o
