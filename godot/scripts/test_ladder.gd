extends Node
## Линейка размеров (SizeLadder): постройки рядами по ступеням, в каждом ряду первым — дом плебеев (мерка) и жители.
## Прежние сборки подогнаны под будущую площадь следа (ladder=1) — снимки владельцу на утверждение размеров.
##   bash .work/py/gpu_run.sh res://test_ladder.tscn -- out=D:/CivCity/.work/ladder/<папка>/ [ladder=0]
##        [rows=house_pleb,library,temple;house_pleb,theatre — свои ряды: типы через запятую, ряды через «;»]
## Снимки: <out>/row<N>.png, <out>/all.png; подписи — строки «LAD LABEL row x y тип площадь» (склейка — .work/ladder/mk_ladder.py)

var game
var c: City
var out := "D:/CivCity/.work/ladder/t/"
var ladder := true
var rows: Array = []

const ROWS := [
	["house_pleb", "house_artisan", "vigiles", "prefect", "mansio", "school", "balnea", "warehouse"],
	["house_pleb", "library", "center", "odeon", "forum", "baths", "theatre"],
	["house_pleb", "theatre", "venus", "temple", "academy", "pantheon"],
	["house_pleb", "thermae", "colosseum", "circus_fl"],
]
const X0 := 118.0
const Z0 := 96.0
const DZ := 26.0
const GAP := 2.2


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"ladder": ladder = kv[1] != "0"
			"rows":
				for r in kv[1].split(";"):
					rows.append(Array(r.split(",")))
	if rows.is_empty():
		rows = ROWS.duplicate()
	if ladder:
		SizeLadder.apply()
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func secs(t: float) -> void:
	var w := 0.0
	while w < t:
		await get_tree().process_frame
		w += get_process_delta_time()


## Прямоугольник следа чертежа (yaw 0: фасад смотрит на +Z, к улице)
func lot(type: String, col: int) -> Rect2:
	var r := Rect2()
	var first := true
	for rc: Rect2 in Catalog.make(type, 1, 0, col).footprint():
		r = rc if first else r.merge(rc)
		first = false
	return r


func _citizen(rng: RandomNumberGenerator, p: Vector2, yaw: float, child := false) -> void:
	var cn := Citizen.create(rng, rng.randf() < 0.5, child, false)
	game.add_child(cn)
	cn.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	cn.rotation.y = yaw
	cn.play("Idle_Loop", 0.0, rng.randf())


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(10)
	c = game.city
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 9000000
	game.hud.visible = false
	game.speed = 0.0
	if game.weather:
		game.weather.left_h = 0.0
		game.weather.force = 0.0
	if game.people:
		game.people.visible = false
	game.clear_nature(Vector2(X0 + 40.0, Z0 + 40.0), 75.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var placed := []          # [ряд, тип, Rect2 в мире, площадь]
	var widths := []
	for ri in rows.size():
		var zr: float = Z0 + DZ * ri
		game.land.paint_line(Vector2(X0 - 6.0, zr), Vector2(X0 + 96.0, zr), 2.0, Land.Kind.ROAD, true)
		var cur := X0
		var ci := 0
		for t: String in rows[ri]:
			var col := (ci * 3 + ri) % 6
			ci += 1
			var r := lot(t, col)
			var pos := Vector2(cur - r.position.x, zr - 2.4 - r.end.y)
			var b: Dictionary = c.place(t, pos, 0.0, 0, col, true)
			if b.is_empty() or not b.has("id"):
				print("LAD NOTE не встало ", t, " ряд ", ri)
				cur += r.size.x + GAP
				continue
			if b.has("pop"):
				b["pop"] = 3
			game._show(b)
			var wr := Rect2(pos + r.position, r.size)
			placed.append([ri, t, wr, r.size.x * r.size.y])
			print("LAD PLACED ряд %d %-12s %.1f × %.1f м = %.0f м² (%.1f дома)" % [ri, t, r.size.x, r.size.y, r.size.x * r.size.y, r.size.x * r.size.y / SizeLadder.HOUSE])
			cur += r.size.x + GAP
		widths.append(cur - X0)
		# жители у первого дома и у середины ряда — для масштаба
		for k in 5:
			_citizen(rng, Vector2(X0 + 1.0 + k * 0.9, zr - 1.2 + (k % 2) * 0.5), PI + rng.randf_range(-0.5, 0.5), k == 4)
		for k in 4:
			_citizen(rng, Vector2(X0 + (cur - X0) * 0.55 + k * 1.1, zr - 1.0), PI + rng.randf_range(-0.5, 0.5))
	await frames(40)
	DirAccess.make_dir_recursive_absolute(out)
	game._set_hour(11.0)
	await frames(20)
	var cam := get_viewport().get_camera_3d()
	for ri in rows.size():
		var zr: float = Z0 + DZ * ri
		var w: float = widths[ri]
		var ctr := Vector3(X0 + 31.0, game.land.height_at(X0 + w * 0.5, zr) + 1.5, zr - 5.0)
		game.rig.set_view(ctr, 0.0, 30.0, 70.0)            # одна даль для всех рядов — один масштаб
		await secs(0.6)
		await frames(30)
		get_viewport().get_texture().get_image().save_png(out + "row%d.png" % ri)
		for e: Array in placed:
			var wr: Rect2 = e[2]
			var base := Vector3(wr.get_center().x, game.land.height_at(wr.get_center().x, wr.end.y), wr.end.y + 0.6)
			if cam.is_position_behind(base):
				continue
			var sp := cam.unproject_position(base)
			if sp.x < 0 or sp.y < 0 or sp.x > 1920 or sp.y > 1080:
				continue
			print("LAD LABEL %d %.0f %.0f %s %.0f %d" % [ri, sp.x, sp.y, e[1], float(e[3]), int(e[0])])
	var wa := 0.0
	for w2: float in widths:
		wa = maxf(wa, w2)
	game.rig.set_view(Vector3(X0 + wa * 0.5, 2.0, Z0 + DZ * 1.5 - 4.0), 0.0, 58.0, wa * 1.75)
	await secs(0.6)
	await frames(30)
	get_viewport().get_texture().get_image().save_png(out + "all.png")
	print("LAD DONE")
	get_tree().quit()
