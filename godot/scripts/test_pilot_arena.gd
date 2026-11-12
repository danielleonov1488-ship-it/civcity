extends Node
## Пилот «новые амфитеатр и цирк» (NewArena, владелец 13.11): снимки для владельца — «было/стало» с четырёх сторон
## и вблизи у входа, кадр «для масштаба» рядом с домами плебеев и жителями, зрелища (зрители, гладиаторы, колесницы)
## и кадры для коротких роликов. Город новый, интерфейс спрятан, ничего не сохраняется.
##   bash .work/py/gpu_run.sh res://test_pilot_arena.tscn -- out=D:/CivCity/.work/pilot/arena/x/ new=1 mode=scale
##   mode=scale  — оба здания, шесть домов плебеев и жители на одном кадре (cam=x,z,поворот,наклон,даль — свой кадр)
##   mode=sheet  — каждое здание с четырёх сторон и вблизи у входа (hours=11,18.5)
##   mode=show   — представление в обоих: зрители сидят, на арене бьются, в цирке скачут (снимки)
##   mode=video  — кадры ролика (bash .work/py/gpu_run.sh --fixed-fps 30 …): video=colosseum|circus_fl dur=7
##   new=0 — прежние здания (NewArena.ON = false)
var game
var c: City
var out := "D:/CivCity/.work/pilot/arena/shots/"
var tag := "a"
var mode := "scale"
var hours := [11.0]
var only := []
var cam := []
var video := "colosseum"
var vdur := 7.0
var placed := {}                        # тип → постройка
var houses := []
const X0 := 136.0
const Z0 := 124.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
			"tag": tag = kv[1]
			"mode": mode = kv[1]
			"new": NewArena.ON = kv[1] != "0"
			"only": only = Array(kv[1].split(","))
			"video": video = kv[1]
			"dur": vdur = float(kv[1])
			"cam":
				for v in kv[1].split(","):
					cam.append(float(v))
			"hours":
				hours = []
				for h in kv[1].split(","):
					hours.append(float(h))
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name)
	print("PILOT shot ", name)


func put(type: String, at: Vector2) -> Dictionary:
	var err := ""
	for k in 80:
		var p := at + Vector2(cos(k * 2.4), sin(k * 2.4)) * (k * 0.3)
		var pl: Dictionary = game.placement(type, p)
		if pl["err"] == "":
			var b := c.place(type, pl["pos"], pl["yaw"], pl["variant"], pl["color"], true)
			game._show(b)
			return b
		err = pl["err"]
	print("PILOT NOTE не встало ", type, " у ", at, " — ", err)
	return {}


## Границы следа в мировых осях: [minx, maxx, minz, maxz]
func bounds(b: Dictionary) -> Array:
	var bp := c.blueprint(b)
	var xf := c.xf(b)
	var r := [INF, -INF, INF, -INF]
	for rc: Rect2 in bp.footprint():
		for q: Vector2 in [rc.position, rc.end, Vector2(rc.position.x, rc.end.y), Vector2(rc.end.x, rc.position.y)]:
			var w := xf * Vector3(q.x, 0, q.y)
			r[0] = minf(r[0], w.x)
			r[1] = maxf(r[1], w.x)
			r[2] = minf(r[2], w.z)
			r[3] = maxf(r[3], w.z)
	return r


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(10)
	c = game.city
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 900000
	c.legion.glory = 99999.0
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	if game.rig.attrs:
		game.rig.attrs.dof_blur_far_enabled = false
		game.rig.attrs.dof_blur_near_enabled = false
	game.clear_nature(Vector2(X0 + 30.0, Z0), 60.0)
	game.land.paint_line(Vector2(X0 - 10.0, Z0), Vector2(X0 + 80.0, Z0), 2.2, Land.Kind.ROAD, true)
	await frames(4)
	DirAccess.make_dir_recursive_absolute(out)
	# север улицы: амфитеатр, цирк; юг: шесть домов плебеев
	var x := X0
	for t: String in ["colosseum", "circus_fl"]:
		if not only.is_empty() and not only.has(t):
			continue
		# вплотную к дороге (как ставит игрок: фасад прилипает к краю мостовой)
		var bp0 := Catalog.make(t, 0, 0, 0)
		var x0 := 0.0
		for r: Rect2 in bp0.footprint():
			x0 = minf(x0, r.position.x)
		var b := put(t, Vector2(x - x0 + 0.5, Z0 - 2.2 - bp0.row_front() - 0.3))
		if b.is_empty():
			continue
		placed[t] = b
		var wb := bounds(b)
		x = maxf(x, wb[1]) + 4.0
		var bp := c.blueprint(b)
		print("PILOT %s: след %.1f × %.1f м (%.0f м²), деталей %d, верх %.2f м" % [t, wb[1] - wb[0], wb[3] - wb[2], (wb[1] - wb[0]) * (wb[3] - wb[2]), bp.parts.size(), bp.top_y()])
	if mode == "scale" or mode == "show" or mode == "video":
		for i in 6:
			var h := put("house_pleb", Vector2(X0 + 2.0 + i * 3.6, Z0 + 4.0))
			if not h.is_empty():
				houses.append(h)
		_citizens()
	await frames(30)
	match mode:
		"scale": await _scale()
		"sheet": await _sheet()
		"show": await _show()
		"video": await _video()
	print("PILOT DONE")
	get_tree().quit()


## Жители для масштаба: стоят на улице у домов
func _citizens() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 10:
		var p := Citizen.create(rng, i % 2 == 1, i % 5 == 4, i % 4 == 2)
		p.scale = Vector3.ONE * Citizen.SIZE
		game.add_child(p)
		var px := X0 + 1.0 + i * 2.1 + rng.randf_range(-0.4, 0.4)
		var pz := Z0 + rng.randf_range(-0.8, 0.8)
		p.global_position = Vector3(px, game.land.height_at(px, pz), pz)
		p.rotation.y = rng.randf() * TAU
		p.play("Idle_Loop", 0.0, rng.randf())


func _view(t: Vector2, yaw: float, pitch: float, d: float) -> void:
	game.rig.set_view(Vector3(t.x, game.land.height_at(t.x, t.y) + 0.6, t.y), yaw, pitch, d)


func _scale() -> void:
	for h: float in hours:
		game._set_hour(h)
		await frames(20)
		if cam.size() >= 5:
			_view(Vector2(cam[0], cam[1]), cam[2], cam[3], cam[4])
		else:
			var all := [INF, -INF, INF, -INF]
			for b: Dictionary in placed.values() + houses:
				var wb := bounds(b)
				all = [minf(all[0], wb[0]), maxf(all[1], wb[1]), minf(all[2], wb[2]), maxf(all[3], wb[3])]
			var ctr := Vector2((all[0] + all[1]) * 0.5, (all[2] + all[3]) * 0.5)
			var rad := maxf(all[1] - all[0], all[3] - all[2]) * 0.5
			print("PILOT cam=%.1f,%.1f,%.0f,%.0f,%.1f" % [ctr.x, ctr.y, 20.0, 42.0, rad * 2.6])
			_view(ctr, 20.0, 42.0, rad * 2.6)
		await frames(45)
		await snap("%s_scale_h%d.png" % [tag, int(h * 10)])
		# вблизи: от домов к зданиям
		for t: String in placed:
			var wb := bounds(placed[t])
			var ctr := Vector2((wb[0] + wb[1]) * 0.5, (wb[2] + wb[3]) * 0.5)
			_view(ctr + Vector2(0, 4.0), 0.0, 30.0, 22.0)
			await frames(40)
			await snap("%s_scale_%s_h%d.png" % [tag, t, int(h * 10)])


## Каждое здание: 3/4 спереди слева и справа, сзади, с боков, вблизи у входа
func _sheet() -> void:
	for h: float in hours:
		game._set_hour(h)
		await frames(20)
		var w := 0.0
		while w < 2.0:
			await get_tree().process_frame
			w += get_process_delta_time()
		for t: String in placed:
			var b: Dictionary = placed[t]
			var wb := bounds(b)
			var ctr := Vector2((wb[0] + wb[1]) * 0.5, (wb[2] + wb[3]) * 0.5)
			var rad := maxf(wb[1] - wb[0], wb[3] - wb[2]) * 0.5
			var f := City.facing(float(b["yaw"]))
			var fy := rad_to_deg(atan2(f.x, f.y))
			var dd := maxf(11.5, rad * 2.5)
			# [поворот от фасада, наклон, даль, сдвиг цели к фасаду (м)]
			var views := [[-40.0, 34.0, dd, 0.0], [40.0, 34.0, dd, 0.0], [180.0, 36.0, dd, 0.0], [-90.0, 30.0, dd, 0.0], [90.0, 30.0, dd, 0.0],
				[-14.0, 14.0, maxf(7.0, rad * 1.1), (wb[3] - wb[2]) * 0.5 - 0.5], [0.0, 62.0, dd * 1.1, 0.0]]
			for i in views.size():
				var v: Array = views[i]
				var tp := ctr + f * float(v[3])
				_view(tp, fy + float(v[0]), float(v[1]), float(v[2]))
				await frames(35)
				await snap("%s_%s_v%d_h%d.png" % [tag, t, i, int(h * 10)])


func _show() -> void:
	var sp: Spectacle = game.spectacle
	game.speed = 1.0
	game._set_hour(hours[0])
	for t: String in placed:
		var b: Dictionary = placed[t]
		var V: Dictionary = sp.venues.get(int(b["id"]), {})
		print("PILOT %s: мест %d" % [t, 0 if V.is_empty() else (V["lay"]["seats"] as Array).size()])
		sp.force(int(b["id"]), "show", 0.95, true)
	var w := 0.0
	while w < 9.0:
		await get_tree().process_frame
		w += get_process_delta_time()
	for t: String in placed:
		var b: Dictionary = placed[t]
		var wb := bounds(b)
		var ctr := Vector2((wb[0] + wb[1]) * 0.5, (wb[2] + wb[3]) * 0.5)
		var rad := maxf(wb[1] - wb[0], wb[3] - wb[2]) * 0.5
		var f := City.facing(float(b["yaw"]))
		var fy := rad_to_deg(atan2(f.x, f.y))
		var views := [[-30.0, 48.0, maxf(12.0, rad * 2.6)], [150.0, 40.0, maxf(10.0, rad * 2.0)], [20.0, 30.0, maxf(7.0, rad * 1.4)], [0.0, 70.0, maxf(12.0, rad * 2.4)]]
		for i in views.size():
			var v: Array = views[i]
			_view(ctr, fy + float(v[0]), float(v[1]), float(v[2]))
			for k in 3:
				await frames(20)
			await snap("%s_show_%s_v%d.png" % [tag, t, i])


## Кадры ролика: представление идёт, камера медленно облетает здание; кадр — каждый кадр игры (--fixed-fps 30)
func _video() -> void:
	var sp: Spectacle = game.spectacle
	game.speed = 1.0
	game._set_hour(hours[0])
	var b: Dictionary = placed.get(video, {})
	if b.is_empty():
		return
	sp.force(int(b["id"]), "show", 0.95, true)
	for t: String in placed:
		if t != video:
			sp.force(int(placed[t]["id"]), "idle")
	var wb := bounds(b)
	var ctr := Vector2((wb[0] + wb[1]) * 0.5, (wb[2] + wb[3]) * 0.5)
	var rad := maxf(wb[1] - wb[0], wb[3] - wb[2]) * 0.5
	var f := City.facing(float(b["yaw"]))
	var fy := rad_to_deg(atan2(f.x, f.y))
	# разгон: бойцы вышли, колесницы набрали ход
	var warm := 0
	while warm < 240:
		await get_tree().process_frame
		warm += 1
	var dir := out + "frames_%s/" % video
	DirAccess.make_dir_recursive_absolute(dir)
	var n := int(vdur * 30.0)
	for i in n:
		var k := float(i) / maxf(1.0, n - 1.0)
		var yaw := fy - 35.0 + 50.0 * k
		var d := lerpf(rad * 3.0, rad * 2.6, k) if video == "colosseum" else lerpf(rad * 1.5, rad * 1.25, k)
		var pitch := lerpf(58.0, 50.0, k) if video == "colosseum" else lerpf(40.0, 32.0, k)
		_view(ctr, yaw, pitch, maxf(6.5, d))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "f%04d.png" % i)
		await get_tree().process_frame
	print("PILOT frames ", n, " → ", dir)
