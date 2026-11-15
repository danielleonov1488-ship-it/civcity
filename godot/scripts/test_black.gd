extends Node3D
## Сыщик черноты (владелец 14.11: «чернота почти в каждом здании»): каждая постройка (кроме украшений) — на чистом месте,
## 11:00, людей нет, земли нет (фон — пурпурный, чтобы силуэт здания был точным), четыре стороны под 35°.
## Тёмные области внутри силуэта (яркость < 0,03, связные, больше N пикселей) считаются: «BLACK <тип> <сторона> <пикселей>».
## Снимки — в out/, итог — таблицей по убыванию. Приёмка заднников проёмов (scripts/interiors.gd).
##   bash .work/py/gpu_run.sh res://test_black.tscn -- out=D:/CivCity/.work/night/black/run1/ [only=tavern,mansio] [hour=11] [minpx=25]
##   → «BLACK DONE total=… types=…»
var game
var out := "D:/CivCity/.work/night/black/run1/"
var only: PackedStringArray = []
var hour := 11.0
var minpx := 12
var zoom := 1.0
var sidesel := ""
var lim := 0.03          # яркость «чёрного»: стены в тени — 0,04–0,06, настоящие провалы — до 0,04 и обычно 0,01–0,02
var variant := 0
var tier := 1
var W := 640
var H := 360
const SIDES := ["front", "right", "back", "left"]
var pitch := 35.0          # наклон камеры (pitch=8 — почти в лоб: видно, что за проёмами)
var results := []          # [тип, пикселей всего, [по сторонам]]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1] if kv[1].ends_with("/") else kv[1] + "/"
			"only": only = kv[1].split(",")
			"hour": hour = float(kv[1])
			"minpx": minpx = int(kv[1])
			"lim": lim = float(kv[1])
			"zoom": zoom = float(kv[1])
			"side": sidesel = kv[1]
			"variant": variant = int(kv[1])
			"tier": tier = int(kv[1])
			"pitch": pitch = float(kv[1])
	Game.boot = {"new": "1", "hour": str(int(hour))}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _stage() -> void:
	game.hud.visible = false
	for ch in game.get_children():
		if ch is Node3D and ch != game.parts and ch != game.rig and not ch is Light3D:
			(ch as Node3D).visible = false
	var env: Environment = game.env
	env.background_mode = Environment.BG_COLOR          # небо остаётся для рассеянного света, фон — пурпур
	env.background_color = Color(1, 0, 1)
	env.fog_enabled = false
	env.volumetric_fog_enabled = false


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	var c: City = game.city
	for r in Defs.RESEARCH:
		c.research[r["id"]] = true
	c.level = 7
	c.money = 9000000
	var X0 := 140.0
	var Z0 := 120.0
	game.clear_nature(Vector2(X0, Z0), 40.0)
	await frames(4)
	_stage()
	game._set_hour(hour)
	DirAccess.make_dir_recursive_absolute(out)
	var types := []
	for t in Defs.B.keys():
		var d: Dictionary = Defs.B[t]
		if d.get("kind", "") == "decor":
			continue
		if not only.is_empty() and not (t in only):
			continue
		types.append(t)
	types.sort()
	for t: String in types:
		var b := c.place(t, Vector2(X0, Z0), 0.0, variant, 0, true)
		if b.is_empty() or not b.has("id"):
			print("BLACK SKIP ", t)
			continue
		if tier > 1 and String(Defs.B[t]["kind"]) == "house":
			b["tier"] = tier
		game._show(b)
		game._set_hour(hour)
		await frames(6)
		var bp: Bp = c.blueprint(b)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for r: Rect2 in bp.footprint(true):
			lo = lo.min(r.position)
			hi = hi.max(r.end)
		if lo.x == INF:
			lo = Vector2(-3, -3)
			hi = Vector2(3, 3)
		var ext := (hi - lo).length() * 0.5
		var top := bp.top_y()
		var ctr_l := (lo + hi) * 0.5
		var xf: Transform3D = c.xf(b)
		var ctr: Vector3 = xf * Vector3(ctr_l.x, top * 0.35, ctr_l.y)
		var dist := (maxf(ext * 1.55, top * 1.25) + 3.5) * zoom
		var per := []
		var total := 0
		for k in 4:
			if sidesel != "" and SIDES[k] != sidesel:
				per.append(0)
				continue
			game.rig.set_view(ctr, rad_to_deg(float(b["yaw"])) + 90.0 * k, pitch, dist)
			await frames(5)
			var img := get_viewport().get_texture().get_image()
			var px := _analyze(img, "%s%s_%s" % [out, t, SIDES[k]])
			per.append(px)
			total += px
			print("BLACK %s %s %d" % [t, SIDES[k], px])
		results.append([t, total, per])
		game._hide(b)
		c.remove(b, false, true)
		await frames(2)
	results.sort_custom(func(a, b2): return a[1] > b2[1])
	var sum := 0
	var f := FileAccess.open(out + "ranked.txt", FileAccess.WRITE)
	for r in results:
		var line := "RANK %-16s %6d  %s" % [r[0], r[1], str(r[2])]
		print(line)
		if f:
			f.store_line(line)
		sum += int(r[1])
	if f:
		f.close()
	print("BLACK DONE total=%d types=%d" % [sum, results.size()])
	get_tree().quit(0)


## Пикселей в тёмных (яркость < 0,03) связных областях ≥ minpx внутри силуэта; снимок — jpg, разметка — красным в *_mark.jpg
func _analyze(img: Image, base: String) -> int:
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(base + ".jpg", 0.85)
	var im := img.duplicate() as Image
	im.resize(W, H, Image.INTERPOLATE_BILINEAR)
	var d := im.get_data()
	var n := W * H
	var dark := PackedByteArray()
	dark.resize(n)
	for i in n:
		var r := d[i * 3]
		var g := d[i * 3 + 1]
		var b := d[i * 3 + 2]
		var is_bg := r > 150 and b > 150 and g < 90 and (r - g) > 90 and (b - g) > 90
		if is_bg:
			continue
		var lum := (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
		if lum < lim:
			dark[i] = 1
	# тонкие тёмные линии (решётки окон, швы, контуры) — не провалы: оставляем пиксели, у которых тёмные и четыре соседа
	var core := PackedByteArray()
	core.resize(n)
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var q := y * W + x
			if dark[q] == 1 and dark[q - 1] == 1 and dark[q + 1] == 1 and dark[q - W] == 1 and dark[q + W] == 1:
				core[q] = 1
	dark = core
	# связные области
	var seen := PackedByteArray()
	seen.resize(n)
	var total := 0
	var mark := PackedInt32Array()
	var stack := PackedInt32Array()
	for s in n:
		if dark[s] == 0 or seen[s] == 1:
			continue
		stack.resize(0)
		stack.append(s)
		seen[s] = 1
		var comp := PackedInt32Array()
		while stack.size() > 0:
			var p: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			comp.append(p)
			var x := p % W
			var y := p / W
			if x > 0 and dark[p - 1] == 1 and seen[p - 1] == 0:
				seen[p - 1] = 1
				stack.append(p - 1)
			if x < W - 1 and dark[p + 1] == 1 and seen[p + 1] == 0:
				seen[p + 1] = 1
				stack.append(p + 1)
			if y > 0 and dark[p - W] == 1 and seen[p - W] == 0:
				seen[p - W] = 1
				stack.append(p - W)
			if y < H - 1 and dark[p + W] == 1 and seen[p + W] == 0:
				seen[p + W] = 1
				stack.append(p + W)
		if comp.size() >= minpx:
			total += comp.size()
			mark.append_array(comp)
	if total > 0:
		for p in mark:
			im.set_pixel(p % W, p / W, Color(1, 0.1, 0.1))
		im.save_jpg(base + "_mark.jpg", 0.8)
	return total
