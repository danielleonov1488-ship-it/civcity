extends Node
## Этап 4 плана от 24.10 (docs/PLAN_2026-10-24_tech.md 4.1, 4.3–4.6, 4.8) и просьбы владельца: утки, лебедь, овцы.
##   bash .work/py/gpu_run.sh res://test_stage4.tscn                — новый город; в конце «S4 DONE fails=0»; снимки — .work/gd/b/s4t_*.png
##   … -- mode=owner                                                — копия города владельца (кладётся в папку сохранений
##        запуска): окантовка у старого города при загрузке, пересчёт < 300 мс, дороги и поля не тронуты, бордюры у домусов
## 4.4 окантовка: глина у домов и лавок (только на траве), у домуса и храма — каменный бордюр; снос и постройка заново
##     возвращают кольца соседей точно; маска покрытий: A — 1 на дороге; глина соседа не заходит на домус и в его сад
##     (домус первым, дом первым, пересчёт при загрузке — одно и то же)
## 4.1 кошки: одна сетка с глазами, свой материал, спит — глаза закрыты; в «Пересмотреть» — того же роста, что на улице;
##     утки (селезень и уточка), лебедь, овцы «пасутся»
## 4.3/4.5 вещи в руках: лира у музыканта (играет на ней, только когда она в руках; иначе лира на скамье), бритва
##     у цирюльника, копьё и щит снимаются оба; на «Низкой» — нет; при обычном приближении — есть; покупку несут домой
## 4.6 леса на стройке; отменили стройку сразу — лесов и рабочих на пустом месте нет

const OWNER := "D:/CivCity/.work/owner_save/city.json"
const SHOTS := "D:/CivCity/.work/gd/b/"
var game
var c: City
var land: Land
var fails := 0
var mode := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
	if mode == "owner" and FileAccess.file_exists(OWNER):
		DirAccess.copy_absolute(OWNER, GamePaths.save_dir().path_join("city.json"))
		Game.boot = {"play": "1", "hour": "11"}
	else:
		Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String, extra = null) -> bool:
	print(("S4 PASS " if ok else "S4 FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	await frames(8)
	DirAccess.make_dir_recursive_absolute(SHOTS)
	get_viewport().get_texture().get_image().save_png(SHOTS + name)
	print("SHOT ", name)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	c = game.city
	land = game.land
	game.can_save = false
	if mode == "owner":
		await _owner()
	else:
		await _new()
	print("S4 DONE fails=%d" % fails)
	get_tree().quit()


## Поставить постройку у точки (на траве у дороги), без денег и проверок уровня
func place(type: String, at: Vector2, dz := -0.5) -> Dictionary:
	for k in 16:
		var pl: Dictionary = game.placement(type, at + Vector2(0, dz * k))
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			return b
	return {}


func wear_sum(i0: int, j0: int, i1: int, j1: int) -> int:
	var s := 0
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			s += land.wear[j * Land.N + i]
	return s


func _new() -> void:
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	game.speed = 0.0
	var X0 := 176.0
	var Z0 := 150.0
	game.clear_nature(Vector2(X0, Z0), 30.0)
	land.paint_line(Vector2(X0 - 26.0, Z0), Vector2(X0 + 22.0, Z0), 1.6, Land.Kind.ROAD, true)
	await frames(10)
	var kinds0 := land.kind.duplicate()
	# --- 4.4: окантовка ---
	var a := place("house_pleb", Vector2(X0 - 12.0, Z0 - 2.0))
	check(not a.is_empty() and c.apron_of(a) == 1, "дом плебеев — с глиняной окантовкой")
	var snap_a := land.wear.duplicate()
	var cells: PackedInt32Array = a.get("cells", PackedInt32Array())
	var ring := 0
	var far := 0
	var road_w := 0
	for k in cells:
		for d: int in [1, -1, Land.N, -Land.N]:
			var k2 := k + d * 2
			if land.occ[k2] == 0 and land.kind[k2] == Land.Kind.GRASS and land.wear[k2] > 0:
				ring += 1
	var ac := land.cell(a["pos"])
	far = wear_sum(ac.x + 60, ac.y - 10, ac.x + 70, ac.y + 10)
	check(ring > 20 and far == 0, "у стен — глина (клеток вокруг: %d), в 15 м — нет (%d)" % [ring, far])
	# маска: на чистой дороге A = 1, на окантовке < 1
	game._rebuild_land(6)
	var rc := land.cell(Vector2(X0 + 15.0, Z0))
	var img: Image = game.surf_img
	var px_road := img.get_pixel(rc.x / Land.SM, rc.y / Land.SM)
	var wk := -1
	for k in cells:
		var k2 := k - Land.N * 2
		if land.occ[k2] == 0 and land.kind[k2] == Land.Kind.GRASS and land.wear[k2] >= 200:
			wk = k2
			break
	var px_ap := img.get_pixel((wk % Land.N) / Land.SM, (wk / Land.N) / Land.SM) if wk >= 0 else Color(0, 0, 0, 1)
	check(is_equal_approx(px_road.a, 1.0) and px_road.r > 0.9 and px_ap.a < 0.6, "маска: дорога без окантовки (A %.2f), у стены — окантовка (A %.2f)" % [px_road.a, px_ap.a])
	# соседи: поставить второй дом рядом, снести его — кольца первого точно как были; снести первый и поставить заново
	var b := place("house_pleb", Vector2(X0 - 4.0, Z0 - 2.0))
	var snap_ab := land.wear.duplicate()
	c.remove(b, false)
	check(land.wear == snap_a, "снесли соседа — окантовка первого дома ровно как была")
	b = c.place("house_pleb", b["pos"], b["yaw"], b["variant"], b["color"], true)
	check(land.wear == snap_ab, "сосед снова на месте — та же окантовка")
	c.remove(a, false)
	a = c.place("house_pleb", a["pos"], a["yaw"], a["variant"], a["color"], true)
	check(land.wear == snap_ab, "первый дом снесли и поставили заново — кольца обоих те же")
	check(land.kind == kinds0, "окантовка не меняет покрытие: дороги, площади, поля как были")
	# домус — бордюр, а не глина
	var dm := place("house_patrician", Vector2(X0 + 8.0, Z0 - 2.0))
	await frames(4)
	var vis: Dictionary = game.visuals.get(dm.get("id", -1), {})
	var bp_n: int = c.blueprint(dm).parts.size() if not dm.is_empty() else 0
	var kerb: Bp = Kerb.blueprint(c.blueprint(dm)) if not dm.is_empty() else Bp.new()
	check(not dm.is_empty() and c.apron_of(dm) == 2 and kerb.parts.size() > 20 and (vis.get("h", []) as Array).size() == bp_n + kerb.parts.size(),
		"домус: каменный бордюр (%d камней) вместе с домом" % kerb.parts.size())
	var dw := 0
	for k in (dm.get("cells", PackedInt32Array()) as PackedInt32Array):
		dw += land.wear[k]
	check(dw == 0, "под домусом и вокруг — без глины")
	game.rig.cine = true
	game.hud.visible = false
	game.rig.cine_look(Vector3(X0 - 8.0, 9.0, Z0 + 12.0), Vector3(X0 - 6.0, land.height_at(X0, Z0), Z0 - 3.0))
	game._set_hour(10.5)
	await frames(30)
	await shot("s4t_apron.png")
	# --- 4.1: кошки ---
	game.people.rng.seed = 3
	var cat: Dictionary = game.people._make_cat(a, {"fur": 1, "p": Vector2(X0 - 10.0, Z0 + 0.5)})
	var mi: MeshInstance3D = (cat["n"] as Node3D).find_children("*", "MeshInstance3D", true, false)[0]
	var eyes := 0
	for col: Color in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		if col.r > 0.7:
			eyes += 1
	check(mi.mesh.get_surface_count() == 1 and eyes > 40 and cat.has("mat"), "кошка: одна сетка (было три), глаза (%d вершин), свой материал" % eyes)
	cat["state"] = "sleep"
	cat["clip"] = ""
	game.people._cat_anim(cat)
	check(float((cat["mat"] as ShaderMaterial).get_shader_parameter("sleep")) == 1.0, "спит — глаза закрыты")
	cat["state"] = "sit"
	game.people._cat_anim(cat)
	check(float((cat["mat"] as ShaderMaterial).get_shader_parameter("sleep")) == 0.0, "проснулась — глаза открыты")
	var fur0 := (game.people._make_cat(a, {"fur": 0, "p": Vector2(X0 - 9.0, Z0 + 0.5)})["mat"] as ShaderMaterial)
	check(int(fur0.get_shader_parameter("pattern")) == 1 and (fur0.get_shader_parameter("fur") as Color).is_equal_approx(People.CAT_FURS[0][0])
		and fur0.get_shader_parameter("sheen") == null, "окрас 0 (кошка в корзинке) — рыжая тигровая, без отлива")
	# Мася из «Где Мася?» (Д15): чёрная, жёлтые глаза, отлив по краю; случайным кошкам города её окрас не выпадает
	var masya := (game.people._make_cat(a, {"fur": People.CAT_MASYA, "p": Vector2(X0 - 8.0, Z0 + 0.5)})["mat"] as ShaderMaterial)
	var mc := masya.get_shader_parameter("fur") as Color
	var me := masya.get_shader_parameter("eye_col") as Color
	check(mc.get_luminance() < 0.15 and int(masya.get_shader_parameter("pattern")) == 0 and me.r > 0.8 and me.g > 0.6 and float(masya.get_shader_parameter("sheen")) > 0.3
		and People.CAT_MASYA >= People.CAT_FURS.size(), "Мася — чёрная, глаза жёлтые, отлив по краю; окрас не из случайных (%s)" % mc)
	var bed := People.cat_node(0, "Sleep", 5)
	check(float((bed.get_child(0).get_meta("fur_mat") as ShaderMaterial).get_shader_parameter("sleep")) == 1.0, "кошка в корзинке спит с закрытыми глазами")
	var big := People.cat_node(0, "Sit", 3, People.CAT_LEN)
	var kk: float = (big.get_child(0) as Node3D).scale.x / (bed.get_child(0) as Node3D).scale.x
	check(is_equal_approx(kk, People.CAT_LEN / People.CAT_LEN_BED), "кошка в «Пересмотреть» — уличного роста (в %.2f раза больше, чем в корзинке)" % kk)
	bed.free()
	big.free()
	# --- утки, лебедь, овцы ---
	var duck := Parts._special_mesh("#duck")
	var hen := Parts._special_mesh("#duck_f")
	var swan := Parts._special_mesh("#swan")
	check(duck.get_aabb().size.z > 0.35 and hen != duck and swan.get_aabb().size.z > 0.6 and swan.get_aabb().size.y > 0.4,
		"утка %.2f м, уточка, лебедь %.2f м (новые модели)" % [duck.get_aabb().size.z, swan.get_aabb().size.z])
	check(duck.get_aabb().position.y > -0.01, "низ утки — по воду (лапы срезаны)")
	var sp := place("sheep", Vector2(X0 + 16.0, Z0 - 8.0))
	await frames(3)
	var pets: Array = game.visuals.get(sp.get("id", -1), {}).get("pets", [])
	var grazing := 0
	for sh in pets:
		var aps := (sh as Node).find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty() and String((aps[0] as AnimationPlayer).current_animation).contains("Graze"):
			grazing += 1
	check(pets.size() == 2 and grazing == 2, "две овцы пасутся (новая модель, %d)" % grazing)
	# --- 4.3: вещи в руках ---
	check(HandProps.work_clip("musicians", 0, "Sitting_Talking") == "Play_Lyre" and Citizen.library().has_animation("Play_Lyre"), "музыкант играет на лире")
	var rr := RandomNumberGenerator.new()
	rr.seed = 9
	var mu := Citizen.create(rr, false)
	add_child(mu)
	HandProps.hold(mu, HandProps.work("musicians", 0), "Play_Lyre")
	var att := mu.find_children("HandProp", "BoneAttachment3D", true, false)
	check(HandProps.held(mu) == "lyre" and att.size() == 1 and (att[0] as BoneAttachment3D).bone_name == "LeftHand", "лира — в левой руке (на кости кисти, не на скамье)")
	var bench_lyre := Catalog.make("musicians", 0, 0, 0).parts.filter(func(p): return String(p[0]) == "SM_Prop_Lyre_01")
	check(bench_lyre.size() == 1, "лира на скамье музыкантов есть (видна, пока её нет в руках)")
	HandProps.drop(mu)
	check(HandProps.held(mu) == "" and mu.find_children("HandProp", "BoneAttachment3D", true, false).is_empty(), "с работы — без лиры")
	var tagged := func() -> int:
		return mu.find_children("*", "BoneAttachment3D", true, false).filter(func(n): return n.has_meta("hand_prop")).size()
	HandProps.hold(mu, ["spear", "shield"], "Sword_Idle")
	var two: int = tagged.call()
	HandProps.drop(mu)
	check(two == 2 and tagged.call() == 0 and HandProps.held(mu) == "", "копьё и щит: в руках оба (%d), сняли — оба (щит не остаётся)" % two)
	check(HandProps.work("barber", 0) == ["razor"] and HandProps.work("musicians", 1).is_empty(), "бритва — у единственного работника цирюльни; пустых мест для вещей нет")
	mu.queue_free()
	# музыканты в городе: житель на месте работы, рядом с камерой — с лирой; «Низкая» — без вещей
	var ms := place("musicians", Vector2(X0 - 18.0, Z0 + 2.5), 0.5)
	var worker := {}
	for r in game.people.residents:
		if int(r["home"]) > 0:
			worker = r
			break
	if worker.is_empty():
		var hh := place("house_pleb", Vector2(X0 - 20.0, Z0 - 2.0))
		c.settled(int(hh["id"]), 2, "Проба")
		var fam: Array = game.people._make_family("Проба", 2, int(hh["id"]), c.door_point(hh))
		worker = fam[0]
	worker["job"] = ms["id"]
	game.people._enter_work(worker)
	game.people._node(worker)
	var wn: Citizen = worker["node"]
	if wn:
		var wp := wn.global_position
		game.rig.cine_look(wp + Vector3(1.6, 1.2, 2.2), wp + Vector3(0, 0.5, 0))
	var lyre_h: Array = game.people._lyre_handle(int(ms.get("id", -1)))
	var lyre_state := func() -> String:
		return "%s/%s/%s/%s" % [HandProps.held(wn) if wn else "-", worker.get("slot_anim", ""), wn.anim.current_animation if wn else "-",
			"скамья пуста" if not lyre_h.is_empty() and game.parts.is_hidden(lyre_h) else "на скамье"]
	check(wn != null and worker.get("slot_anim", "") == "Sitting_Talking" and not lyre_h.is_empty() and not game.parts.is_hidden(lyre_h),
		"пришёл на работу: сидит, лира на скамье (%s)" % lyre_state.call())
	game.people._props_tick()
	check(lyre_state.call() == "lyre/Play_Lyre/Play_Lyre/скамья пуста", "музыкант у камеры — играет на лире в руках, скамья пуста (%s)" % lyre_state.call())
	await frames(10)
	await shot("s4t_music.png")
	game.settings["quality"] = "low"
	Gfx.apply(game)
	game.people._props_tick()
	check(wn == null or lyre_state.call() == "/Sitting_Talking/Sitting_Talking/на скамье", "«Низкая» — вещей в руках нет, на пустой руке не играет, лира на скамье (%s)" % lyre_state.call())
	await frames(10)
	await shot("s4t_music_low.png")
	game.settings["quality"] = "high"
	Gfx.apply(game)
	game.people._props_tick()
	check(wn == null or lyre_state.call() == "lyre/Play_Lyre/Play_Lyre/скамья пуста", "снова «Высокая» — лира снова в руках (%s)" % lyre_state.call())
	if wn:
		# камера далеко (в ролике) — без лиры в руках, она на скамье
		var wp2 := wn.global_position
		game.rig.cine_look(wp2 + Vector3(60.0, 40.0, 60.0), wp2)
		game.people._props_tick()
		check(lyre_state.call() == "/Sitting_Talking/Sitting_Talking/на скамье", "камера далеко — лира на скамье, музыкант сидит (%s)" % lyre_state.call())
		# обычная камера игры при обычном приближении (60): меряем от точки взгляда — лира в руках
		game.rig.cine = false
		game.rig.set_view(wp2 + Vector3(4.0, 0, 3.0), 200.0, 38.0, 60.0)
		game.people._props_tick()
		check(lyre_state.call() == "lyre/Play_Lyre/Play_Lyre/скамья пуста" and game.rig.cam.global_position.distance_to(wp2) > 60.0,
			"обычное приближение (камера в %.0f м) — лира в руках (%s)" % [game.rig.cam.global_position.distance_to(wp2), lyre_state.call()])
		await frames(10)
		await shot("s4t_music_default.png")
		game.rig.cine = true
	# цирюльня: единственный работник — цирюльник с бритвой (а не клиент в кресле)
	var bb := place("barber", Vector2(X0 + 11.0, Z0 + 2.5), 0.5)
	var barber := {}
	for r in game.people.residents:
		if r != worker and int(r["home"]) > 0 and r["state"] != "work":
			barber = r
			break
	if barber.is_empty():
		var hb := place("house_pleb", Vector2(X0 - 9.0, Z0 + 2.5), 0.5)
		c.settled(int(hb["id"]), 2, "Бритва")
		barber = (game.people._make_family("Бритва", 2, int(hb["id"]), c.door_point(hb)) as Array)[0]
	if check(not bb.is_empty(), "цирюльня поставлена"):
		barber["job"] = bb["id"]
		game.people._enter_work(barber)
		game.people._node(barber)
		var bn: Citizen = barber["node"]
		if bn:
			var bp3 := bn.global_position
			var bf := bn.global_transform.basis.z.normalized()        # спереди, чуть сбоку — видно бритву в руке
			game.rig.cine_look(bp3 + bf * 2.0 + bf.cross(Vector3.UP) * 0.8 + Vector3(0, 1.1, 0), bp3 + Vector3(0, 0.7, 0))
		game.people._props_tick()
		check(int(barber["slot"]) == 0 and barber.get("slot_anim", "") == "Interact" and bn != null and HandProps.held(bn) == "razor",
			"цирюльник стоит у кресла с бритвой (место %d, %s, %s)" % [int(barber["slot"]), barber.get("slot_anim", ""), HandProps.held(bn) if bn else "-"])
		await frames(10)
		await shot("s4t_barber.png")
	# покупку несут домой
	var bk := place("bakery", Vector2(X0 + 2.0, Z0 + 2.5), 0.5)
	var cust := {}
	for r in game.people.residents:
		if r != worker:
			cust = r
			break
	if not cust.is_empty() and not bk.is_empty():
		cust["act"] = "shop"
		cust["dest"] = {"act": "shop", "bid": bk["id"]}
		game.people._on_step(cust, "PickUp_Table")
		check(String(cust.get("carry", "")) == "basket", "купил в пекарне — несёт корзину домой")
		cust["state"] = "walk"
		check(game.people.props_want(cust) == ["basket"], "по дороге — корзина в руке")
		game.people._door_done(cust, "home", {})
		check(not cust.has("carry"), "донёс — без корзины")
	# --- 4.6: леса на стройке ---
	game.build_anim = true
	game.speed = 1.0
	var nb := place("house_artisan", Vector2(X0 - 2.0, Z0 + 3.0), 0.5)
	game.build_anim = false
	check(int(game._grows) == 1 and not game.visuals.has(nb.get("id", -1)), "стройка: леса и рабочие, дом растёт")
	var gp: Vector2 = nb.get("pos", Vector2(X0, Z0))
	game.rig.cine_look(Vector3(gp.x + 6.0, land.height_at(gp.x, gp.y) + 5.0, gp.y + 8.0), Vector3(gp.x, land.height_at(gp.x, gp.y) + 1.5, gp.y))
	await get_tree().create_timer(1.6).timeout
	await shot("s4t_build.png")
	await get_tree().create_timer(2.5).timeout
	check(int(game._grows) == 0 and game.visuals.has(nb.get("id", -1)), "через 3–4 с — готовый дом, лесов нет")
	# поставили по ошибке и сразу отменили (снесли): леса, призрак и рабочие уходят сразу, дом потом не появляется
	game.build_anim = true
	var ub := place("house_pleb", Vector2(X0 - 10.0, Z0 + 3.0), 0.5)
	game.build_anim = false
	var uid := int(ub.get("id", -1))
	var live: Array = game._grow_live.get(uid, [])
	if check(not ub.is_empty() and live.size() == 3 and int(game._grows) == 1, "вторая стройка с лесами"):
		c.remove(ub, false)
		await frames(3)
		check(int(game._grows) == 0 and not game._grow_live.has(uid) and not is_instance_valid(live[1]) and not is_instance_valid(live[2]),
			"отменили сразу — лесов, призрака и рабочих нет (строек с лесами: %d)" % int(game._grows))
		await get_tree().create_timer(3.6).timeout
		check(not game.visuals.has(uid), "и дом на пустом месте потом не появился")
	await _apron_kerb()


## 4.4: глина дома вплотную к домусу не заходит на домус и в его сад — домус первым, дом первым и пересчёт при
## загрузке дают одно и то же; снесли домус — глина как у одного дома
func _apron_kerb() -> void:
	var X1 := 172.0
	var Z1 := 186.0
	game.clear_nature(Vector2(X1, Z1), 28.0)
	land.paint_line(Vector2(X1 - 24.0, Z1), Vector2(X1 + 24.0, Z1), 1.6, Land.Kind.ROAD, true)
	await frames(5)
	var dm := place("house_patrician", Vector2(X1, Z1 - 2.0))
	if not check(not dm.is_empty(), "домус для проверки сада"):
		return
	var did := int(dm["id"])
	var dcells: PackedInt32Array = dm["cells"]
	var dset := {}
	var lo := Vector2i(Land.N, Land.N)
	var hi := Vector2i(-1, -1)
	for k in dcells:
		dset[k] = true
		lo = lo.min(Vector2i(k % Land.N, k / Land.N))
		hi = hi.max(Vector2i(k % Land.N, k / Land.N))
	# дома плебеев — вплотную к обеим боковым стенам домуса (с одной стороны — дом, с другой — сад за оградой):
	# от середины домуса вбок, первое место, где можно
	var hs := []
	for side: float in [1.0, -1.0]:
		for s in 120:
			var pl: Dictionary = game.placement("house_pleb", Vector2((dm["pos"] as Vector2).x + side * 0.25 * s, Z1 - 2.0))
			if pl["err"] == "":
				hs.append(c.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"], true))
				break
	if not check(hs.size() == 2, "места для домов у обеих стен домуса (%d)" % hs.size()):
		return
	# клетки домуса, до которых без бордюра дошло бы кольцо глины (до 4 клеток от стены дома)
	var reach := {}
	for h: Dictionary in hs:
		for k in (h["cells"] as PackedInt32Array):
			for dy in range(-4, 5):
				for dx in range(-4 + absi(dy), 5 - absi(dy)):
					if dset.has(k + dy * Land.N + dx):
						reach[k + dy * Land.N + dx] = true
	# клетки домуса и сад за его оградой (туда глине можно дойти только сквозь стены)
	var inner := _walled(dset, lo, hi)
	var wsum := func() -> int:
		var sm := 0
		for k in dcells:
			sm += land.wear[k]
		for k in inner:
			sm += land.wear[k]
		return sm
	var w_dm_first := land.wear.duplicate()
	check(reach.size() > 20 and wsum.call() == 0, "дома вплотную к домусу (кольцо дошло бы до %d его клеток): на домусе и в саду (%d клеток) глины нет (%d)" % [reach.size(), inner.size(), wsum.call()])
	var near := 0
	for h: Dictionary in hs:
		for k in (h["cells"] as PackedInt32Array):
			for d: int in [Land.N * 2, -Land.N * 2, 2, -2]:
				if land.occ[k + d] == 0 and land.wear[k + d] > 0:
					near += 1
	check(near > 20, "у самих домов глина есть (%d)" % near)
	game.rig.cine = true
	var hc: Vector2 = dm["pos"]
	var hy: float = land.height_at(hc.x, hc.y)
	game.rig.cine_look(Vector3(hc.x + 4.0, hy + 18.0, hc.y - 18.0), Vector3(hc.x, hy, hc.y - 3.0))
	await frames(30)
	await shot("s4t_apron_domus.png")
	# дом первым, домус потом — то же самое
	c.remove(dm, false)
	var w_house := land.wear.duplicate()
	var dm2 := c.place("house_patrician", dm["pos"], dm["yaw"], dm["variant"], dm["color"], true)
	check(land.wear == w_dm_first, "дом первым, домус потом — глина та же (на домусе и в саду нет)")
	c.apron_all()
	check(land.wear == w_dm_first, "пересчёт при загрузке — та же глина")
	c.remove(dm2, false)
	check(land.wear == w_house, "снесли домус — глина как у одного дома")


## Сад за оградой домуса: клетки внутри рамки lo…hi, куда снаружи не дойти, не подходя к домусу ближе CLOSE клеток
## (калитку — щель уже 1,5 м — считаем закрытой, как бордюр); у самой стены снаружи — не сад
func _walled(dset: Dictionary, lo: Vector2i, hi: Vector2i) -> Array:
	var CL := Kerb.CLOSE
	var near := {}
	for k: int in dset:
		var ci := k % Land.N
		var cj := k / Land.N
		for dj in range(-CL, CL + 1):
			for di in range(-CL, CL + 1):
				near[(cj + dj) * Land.N + ci + di] = true
	var lo2 := lo - Vector2i(CL + 1, CL + 1)
	var hi2 := hi + Vector2i(CL + 1, CL + 1)
	var seen := {}
	var stack: Array[int] = []
	for j in range(lo2.y, hi2.y + 1):
		for i in range(lo2.x, hi2.x + 1):
			if i == lo2.x or i == hi2.x or j == lo2.y or j == hi2.y:
				stack.append(j * Land.N + i)
	while not stack.is_empty():
		var k: int = stack.pop_back()
		if seen.has(k):
			continue
		var ci := k % Land.N
		var cj := k / Land.N
		if ci < lo2.x or ci > hi2.x or cj < lo2.y or cj > hi2.y or near.has(k):
			continue
		seen[k] = true
		for d: int in [1, -1, Land.N, -Land.N]:
			stack.append(k + d)
	# не дошли снаружи и не у самой стены: внутри ограды дальше CLOSE от рамки
	var out := []
	for j in range(lo.y + CL + 1, hi.y - CL):
		for i in range(lo.x + CL + 1, hi.x - CL):
			var k := j * Land.N + i
			if not seen.has(k) and not dset.has(k) and land.occ[k] == 0 and land.kind[k] == Land.Kind.GRASS:
				out.append(k)
	return out


## Город владельца: окантовка при загрузке, быстро; дороги и поля не тронуты; бордюры у домусов
func _owner() -> void:
	check(c.buildings.size() > 300, "город владельца загружен (%d построек)" % c.buildings.size())
	var t0 := Time.get_ticks_usec()
	c.apron_all()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("S4 apron_all %.1f мс на %d построек" % [ms, c.buildings.size()])
	check(ms < 300.0, "окантовка всего города заново — %.0f мс (< 300)" % ms)
	var worn := 0
	for k in land.wear.size():
		if land.wear[k] > 0:
			worn += 1
	check(worn > 20000, "старый город получил окантовку (%d клеток)" % worn)
	var kerbs := 0
	for id in c.buildings:
		if c.apron_of(c.buildings[id]) == 2:
			var vis: Dictionary = game.visuals.get(id, {})
			if (vis.get("h", []) as Array).size() > c.blueprint(c.buildings[id]).parts.size():
				kerbs += 1
	check(kerbs >= 10, "домусы и храм — с бордюром (%d)" % kerbs)
	var kw := 0
	for id in c.buildings:
		if c.apron_of(c.buildings[id]) == 2:
			for k in (c.buildings[id]["cells"] as PackedInt32Array):
				kw += land.wear[k]
	check(kw == 0, "глина соседей не заходит на домусы и храм (%d)" % kw)
	Kerb._cache.clear()
	var t1 := Time.get_ticks_usec()
	for id in c.buildings:
		if c.apron_of(c.buildings[id]) == 2:
			Kerb.blueprint(c.blueprint(c.buildings[id]))
	var kms := (Time.get_ticks_usec() - t1) / 1000.0
	check(kms < 200.0, "бордюры всех домусов и храма — %.0f мс при загрузке (< 200)" % kms)
	game.rig.cine = true
	game.hud.visible = false
	game._set_hour(10.0)
	for v: Array in [["center", Vector3(210, 0, 145), 15.0, 42.0, 60.0], ["close", Vector3(205, 0, 140), 30.0, 35.0, 22.0]]:
		var tgt: Vector3 = v[1]
		tgt.y = land.height_at(tgt.x, tgt.z)
		var yaw := deg_to_rad(float(v[2]))
		var pit := deg_to_rad(float(v[3]))
		var d := float(v[4])
		game.rig.cine_look(tgt + Vector3(sin(yaw) * cos(pit), sin(pit), cos(yaw) * cos(pit)) * d * 0.6, tgt)
		await frames(90)
		await shot("s4t_owner_%s.png" % v[0])
