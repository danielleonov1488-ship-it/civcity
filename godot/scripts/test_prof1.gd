extends Node3D
## PROF1: профессии, старые сохранения, найм, единая выработка и две карточки.

var out := "D:/CivCity/.work/stage5/prof/shots/"
var game
var fails := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, why: String) -> bool:
	if not ok:
		fails += 1
		print("PROF1 FAIL " + why)
	return ok


func shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.advisor_panel.hide()
	await frames(8)
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out + file)
	if check(error == OK, "save " + file):
		print("PROF1 SHOT " + out + file)


func model() -> City:
	var c := City.new(Land.new())
	c.cozy_v = 1
	c.auto_hire = false
	c.level = 7
	c.money = 1000000.0
	return c


func place(c: City, type: String, pos: Vector2) -> Dictionary:
	var b := c.place(type, pos, 0.0, 0, 0, true)
	if not check(not b.is_empty(), "place " + type):
		return b
	var door := c.door_point(b)
	c.land.paint_line(door - Vector2(3, 0), door + Vector2(3, 0), 2.0, Land.Kind.ROAD, true)
	c.compute()
	return b


func home(c: City, nm: String, pos: Vector2, profs: Array, cls := "plebs") -> Dictionary:
	var h := place(c, "house_pleb" if cls == "plebs" else ("house_artisan" if cls == "artisans" else "house_patrician"), pos)
	var ms: Array = []
	for i in profs.size():
		ms.append({"pn": "Гай" if i == 0 else "Юлия", "sx": i % 2, "age": 1, "sd": i + 11, "prof": profs[i]})
	h["families"] = [{"name": nm, "n": ms.size(), "cls": cls, "m": ms}]
	h["pop"] = ms.size()
	c.compute()
	return h


func family_profs(f: Dictionary) -> Array:
	var result: Array = []
	for m: Dictionary in f.get("m", []):
		result.append(String(m.get("prof", "")))
	return result


func fingerprint(data: Dictionary) -> Dictionary:
	var result := {}
	for b: Dictionary in data["buildings"]:
		for f: Dictionary in b["families"]:
			result[String(f["name"])] = family_profs(f)
	for f: Dictionary in data["arrivals"]:
		result[String(f["name"])] = family_profs(f)
	return result


func chances() -> void:
	check(Defs.PROFESSIONS.size() == 6 and is_equal_approx(Defs.PROF_BONUS, 0.2), "six professions, bonus 20%")
	for cls: String in Defs.CLASS_ORDER:
		var total := 0
		var counts := {}
		for roll in 100:
			var prof := Residents.profession_roll(cls, roll)
			counts[prof] = int(counts.get(prof, 0)) + 1
		for id: String in Defs.PROFESSIONS:
			var chance := int(Defs.PROFESSIONS[id]["chance"][cls])
			total += chance
			check(int(counts.get(id, 0)) == chance, cls + " weighted rolls " + id)
		check(total == 100, cls + " chances sum to 100")
	for type: String in Defs.B:
		if Defs.B[type].has("jobs"):
			check(Defs.PROFESSIONS.has(Defs.building_profession(Defs.B[type])), "job category " + type)
	for type: String in ["scriptorium", "school", "library", "academy"]:
		check(Defs.building_profession(Defs.B[type]) == "scholar", "science overrides farming " + type)
	for type: String in ["temple", "venus", "pantheon"]:
		check(Defs.building_profession(Defs.B[type]) == "priest", "temple overrides special " + type)
	check(Defs.building_profession(Defs.B["vigiles"]) == "attendant", "other specials use attendant")


func assignment() -> void:
	var a := model()
	var b := model()
	a.rng.seed = 192367
	b.rng.seed = 192367
	for cls: String in Defs.CLASS_ORDER:
		for i in 12:
			var fa := a.new_family(cls)
			var fb := b.new_family(cls)
			check(fa == fb and a.rng.state == b.rng.state, "seeded family " + cls)
			for m: Dictionary in fa["m"]:
				check(Defs.PROFESSIONS.has(String(m.get("prof", ""))) if int(m["age"]) > 0 else not m.has("prof"), "only adults have professions")
	var f := {"name": "Юлии", "n": 3, "m": [
		{"pn": "Гай", "sx": 0, "age": 1, "sd": 1},
		{"pn": "Юлия", "sx": 1, "age": 2, "sd": 2},
		{"pn": "Марк", "sx": 0, "age": 0, "sd": 3, "prof": "priest"}]}
	var expected := RandomNumberGenerator.new()
	expected.seed = 31337
	a.rng.seed = 31337
	Residents.new_professions(f, "plebs", a.rng, 7)
	check(f["m"][0]["prof"] == Residents.profession_roll("plebs", expected.randi_range(0, 99)), "first adult uses city RNG")
	check(f["m"][1]["prof"] == Residents.profession_roll("plebs", expected.randi_range(0, 99)), "elder uses city RNG")
	check(a.rng.state == expected.state and not f["m"][2].has("prof"), "one RNG roll per adult, none per child")
	var before := family_profs(f)
	Residents.fit(f, 999, "patricians")
	check(family_profs(f) == before, "rehome and class change keep professions")


func persistence() -> void:
	var c := model()
	var h := home(c, "Фабии", Land.START, ["farmer", "priest"])
	var f: Dictionary = h["families"][0]
	f["m"].append({"pn": "Марк", "sx": 0, "age": 0, "sd": 20})
	f["n"] = 3
	h["pop"] = 3
	c.arrivals.append(c.new_family("artisans"))
	var walking := c.new_family("patricians")
	walking["home"] = int(h["id"])
	c.pending[String(walking["name"])] = walking
	var field := place(c, "farm", Land.START + Vector2(9, 0))
	check(c.hire(field) == 1, "save fixture hires farmer")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	var expected := fingerprint(saved)
	for i in 2:
		var restored := model()
		restored.load_data(saved.duplicate(true))
		saved = JSON.parse_string(JSON.stringify(restored.save_data()))
		check(fingerprint(saved) == expected, "JSON save/load: housed, waiting, walking families round %d" % i)
		check(restored.hired_of(restored.buildings[int(field["id"])]) == 1, "profession does not lose saved job")
	# Прежние записи без prof, в том числе старые города с автоматическим штатом.
	for row: Dictionary in saved["buildings"]:
		for family: Dictionary in row["families"]:
			for m: Dictionary in family["m"]:
				m.erase("prof")
	for family: Dictionary in saved["arrivals"]:
		for m: Dictionary in family["m"]:
			m.erase("prof")
	saved["cozy_v"] = 0
	var a := model()
	var b := model()
	a.rng.seed = 111
	b.rng.seed = 222
	var a_state := a.rng.state
	var b_state := b.rng.state
	a.load_data(saved.duplicate(true))
	b.load_data(saved.duplicate(true))
	check(a.rng.state == a_state and b.rng.state == b_state, "old save migration leaves both RNG streams unchanged")
	check(fingerprint(a.save_data()) == fingerprint(b.save_data()), "migration ignores city RNG seed")
	for family: Dictionary in a.buildings[int(h["id"])]["families"]:
		for i in (family["m"] as Array).size():
			var m: Dictionary = family["m"][i]
			check(String(m.get("prof", "")) == (Residents.profession_roll("plebs", posmod(hash([family["name"], i]), 100)) if int(m["age"]) > 0 else ""), "migration is family-name plus member-index hash")
	# Самые старые семьи ещё без массива m: создаются прямо при load_data.
	for row: Dictionary in saved["buildings"]:
		for family: Dictionary in row["families"]:
			family.erase("m")
	for family: Dictionary in saved["arrivals"]:
		family.erase("m")
	a.load_data(saved.duplicate(true))
	b.load_data(saved.duplicate(true))
	check(a.rng.state == a_state and b.rng.state == b_state, "missing members also migrate without RNG")
	check(fingerprint(a.save_data()) == fingerprint(b.save_data()), "missing-member migration deterministic")
	for family: Dictionary in a.arrivals:
		check((family["m"] as Array).size() == int(family["n"]) and family_profs(family)[0] != "", "waiting family migrated on load")
	var local := {"name": "Корнелии", "n": 2}
	var moved := local.duplicate(true)
	Residents.fit(local, 5, "plebs")
	Residents.fit(moved, 500, "plebs")
	check(family_profs(local) == family_profs(moved), "migration profession does not depend on home id")


func hiring() -> void:
	var c := model()
	var near := home(c, "Ближние", Land.START, ["farmer"])
	var far := home(c, "Дальние", Land.START + Vector2(24, 0), ["trader"])
	var shop := place(c, "weaver", Land.START + Vector2(8, 0))
	check(c.hire(shop) == 1 and int(far["families"][0]["m"][0].get("job", -1)) == int(shop["id"]), "fitting free worker preferred over nearer mismatched worker")
	check(c.hire(shop) == 1 and int(near["families"][0]["m"][0].get("job", -1)) == int(shop["id"]), "fallback hires mismatched worker")
	check(c.hire(shop) == 0, "profession does not create extra slots")
	check(c.fire(shop, 9) == 2 and c.hired_of(shop) == 0, "fire releases both kinds")
	var master := home(c, "Мастера", Land.START + Vector2(12, 10), ["scholar"], "artisans")
	near["families"][0]["m"][0]["prof"] = "scholar"
	var school := place(c, "school", Land.START + Vector2(20, 10))
	check(c.hire(school) == 1 and int(master["families"][0]["m"][0].get("job", -1)) == int(school["id"]), "fitting pleb cannot take artisan slot")
	c.fire(shop, 9)
	master["families"][0]["m"][0].erase("job")
	master["families"][0]["m"][0].erase("job_class")
	master["families"][0]["m"][0]["prof"] = "trader"
	far["families"][0]["m"][0]["prof"] = "farmer"
	c.compute()
	check(c.hire(shop) == 1 and int(near["families"][0]["m"][0].get("job", -1)) == int(shop["id"]), "existing class priority stays ahead of profession")


func outputs() -> void:
	for type: String in ["farm", "stall_fruit", "musicians", "scriptorium", "temple", "vigiles", "warehouse", "smelter"]:
		var c := model()
		var d: Dictionary = Defs.B[type]
		var profession := Defs.building_profession(d)
		var cls := String((d["jobs"] as Dictionary).keys()[0])
		var mx := int(d["jobs"][cls])
		var profs: Array = []
		profs.resize(mx)
		profs.fill(profession)
		var h := home(c, "Работники", Land.START, profs, cls)
		var work := place(c, type, Land.START + Vector2(8, 0))
		var ms: Array = h["families"][0]["m"]
		for n in range(mx + 1):
			for k in range(n + 1):
				for i in mx:
					ms[i]["prof"] = profession if i < k else ("trader" if profession != "trader" else "farmer")
					ms[i].erase("job")
					ms[i].erase("job_class")
					if i < n:
						ms[i]["job"] = int(work["id"])
						ms[i]["job_class"] = cls
				work["hire"] = n
				c.compute()
				var expected := (float(n) + 0.2 * k) / float(mx)
				check(int(work.get("prof_fit", -1)) == k and is_equal_approx(float(work["staff"]), expected), "%s N=%d K=%d M=%d" % [type, n, k, mx])
				if d["kind"] == "shop":
					check(int(work["cap"]) == ceili(float(Defs.CAPACITY[int(d["cap"])]) * expected), "shop service uses weighted staff once")
				elif d["kind"] == "farm":
					check(is_equal_approx(float(c.goods.get(d["makes"], 0.0)), expected), "field goods use weighted staff once")
				elif d["kind"] == "rp":
					check(is_equal_approx(float(c.rp_sources().get(type, 0.0)), c.rp_per_hour(type) * expected), "research uses weighted staff once")
				elif d["kind"] == "military":
					check(is_equal_approx(c.legion.workshop_k(type), expected), "workshop keeps weighted staff up to 120%")
				elif d["kind"] == "monument":
					check(is_equal_approx(float(h["monuments"]), roundi(float(d["bonus"]) * expected)), "temple and special use weighted staff once")
		check(is_equal_approx(float(work["staff"]), 1.2), "full fitting staff reaches 120% " + type)
		var state := c.rng.state
		c.compute(true)
		check(c.rng.state == state and is_equal_approx(float(work["staff"]), 1.2), "compute does not reroll or compound bonus " + type)


func visible_texts(node: Node) -> String:
	var result := String(node.text) + "\n" if node is Label or node is Button else ""
	for child: Node in node.get_children():
		result += visible_texts(child)
	return result


func icon_check(icon: PanelContainer) -> void:
	var prof := String(icon.get_meta("profession", ""))
	var picture := icon.get_node("ProfessionPicture") as TextureRect
	check(Defs.PROFESSIONS.has(prof) and picture.texture != null, "profession icon has texture")
	check(icon.tooltip_text.contains(String(Defs.PROFESSIONS[prof]["name"])) and icon.tooltip_text.contains("+20% к работе, если подходит"), "every icon has name and bonus tooltip")
	check(icon.find_children("*", "Label", true, false).is_empty(), "icon has no text-only label")
	if bool(icon.get_meta("fits", false)):
		var rim := icon.get_theme_stylebox("panel") as StyleBoxFlat
		check(rim.border_color == Hud.C_GOOD and rim.border_width_left == 2, "matching portrait has green rim")


func cards() -> void:
	var c: City = game.city
	var hud: Hud = game.hud
	c.cozy_v = 1
	c.auto_hire = false
	c.level = 3
	c.money = 1000000.0
	var at := Land.START + Vector2(18, 8)
	var h := home(c, "Юлии", at, ["trader", "farmer", "scholar"])
	var family: Dictionary = h["families"][0]
	family["m"][2]["age"] = 2
	family["m"].append({"pn": "Марк", "sx": 0, "age": 0, "sd": 91})
	family["n"] = 4
	h["pop"] = 4
	var shop := place(c, "weaver", at + Vector2(8, 0))
	check(c.hire(shop, 2) == 2, "card fixture hired two")
	game.rig.set_view(Vector3(at.x, 2.0, at.y), 24, 50, 46)
	game.select_building(shop)
	hud.open_info(shop)
	await frames(8)
	var icons: Array[Node] = hud.info_box.find_children("ProfessionIcon", "PanelContainer", true, false)
	check(icons.size() == 3, "building shows wanted icon and two worker icons")
	var matched := 0
	for icon: PanelContainer in icons:
		icon_check(icon)
		if bool(icon.get_meta("fits", false)):
			matched += 1
	check(matched == 1, "only fitting worker gets green rim")
	var count := hud.info_box.find_child("profession_count", true, false) as Label
	check(count != null and count.text == "1 / 2", "suited counter is numbers only")
	for id: String in Defs.PROFESSIONS:
		check(not visible_texts(hud.info_box).contains(String(Defs.PROFESSIONS[id]["name"])), "no profession text panel " + id)
	await shot("1_building_card.png")
	game.select_building(h)
	hud.house_more = false
	hud.open_info(h)
	await frames(8)
	icons = hud.info_box.find_children("ProfessionIcon", "PanelContainer", true, false)
	check(icons.size() == 3, "house shows adults and elder professions, none for child")
	for icon: PanelContainer in icons:
		icon_check(icon)
		check(String(icon.get_meta("profession_role", "")) == "family", "family icon follows member head")
	await shot("2_house_card.png")
	I18n.set_lang("en")
	check(I18n.t("+20% к работе, если подходит") == "+20% work output when suited", "English bonus tooltip")
	for id: String in Defs.PROFESSIONS:
		check(I18n.t(String(Defs.PROFESSIONS[id]["name"])) == String(Defs.PROFESSIONS[id]["en"]), "English profession " + id)
	I18n.set_lang("ru")


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if waited >= 18000:
			check(false, "ready_done timeout")
			_finish()
			return
	game.can_save = false
	game.settings["autosave"] = false
	game.settings["advisor_off"] = true
	game.speed = 0.0
	game.build_anim = false
	game.rig.cine = true
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.hide()
	game.tutorial.set_process(false)
	game.city.tips["tut"] = -1
	game.city.tips["ui"] = 3
	game.hud.apply_reveal(3)
	game.hud.close_panels()
	I18n.set_lang("ru")
	if check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory"):
		chances()
		assignment()
		persistence()
		hiring()
		outputs()
		await cards()
	_finish()


func _finish() -> void:
	print("PROF1 DONE fails=", fails)
	get_tree().quit(0 if fails == 0 else 1)
