extends Node3D
## Дома из своего набора деталей (KitHouses, владелец 11.11): в городке все дома — свои; старый дом (без "kw") —
## на прежнем следе; ставни днём открыты, ночью закрыты (KitShutters); ночью в комнатах тёплый свет. Снимки день/ночь.
##   bash .work/py/gpu_run.sh res://test_kit_houses.tscn -- [out=D:/CivCity/.work/kit/kit_test]
var game
var out := "D:/CivCity/.work/kit/kit_test"
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv[0] == "out":
			out = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	KitHouses.ON = true                       # проверка своего набора — даже когда игра на Synty (владелец 12.11)
	Game.boot = {"demo": "1", "noui": "1", "hour": "12"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func check(ok: bool, what: String) -> bool:
	print("KH ", "PASS " if ok else "FAIL ", what)
	if not ok:
		fails += 1
	return ok


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(30)
	if game.rig.attrs:
		game.rig.attrs.dof_blur_far_enabled = false
		game.rig.attrs.dof_blur_near_enabled = false
	var c = game.city
	var houses := []
	var kit := 0
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		if c.is_house(b):
			houses.append(b)
			if c.blueprint(b).kit_id != "":
				kit += 1
	check(houses.size() > 5 and kit == houses.size(), "все дома городка — свои (%d из %d)" % [kit, houses.size()])
	# старое сохранение: дом без "kw" — свой облик, но на прежнем следе
	for t in ["house_pleb", "house_artisan", "house_patrician"]:
		var lb := Catalog.make(t, 1, 1, 0, true)
		var r: Rect2 = lb.footprint()[0]
		var o := KitHouses.old_fp(t, 1)
		var lr: Array = lb.occ_footprint()
		# след (бордюр, щелчок) — общий прямоугольник прежнего; клетки — ровно прежние прямоугольники, не их общий
		check(lb.kit_id != "" and absf(r.size.x - o.size.x) < 0.02 and absf(r.size.y - o.size.y) < 0.02 and lr.size() > 1 and lr == KitHouses.old_rects(t, 1, 0),
			"%s из старого сохранения — на прежнем следе %s, клетки — прежние (%d прямоугольников)" % [t, o, lr.size()])
	# дом с жильцами и ставнями
	var hb: Dictionary = {}
	for b: Dictionary in houses:
		if int(b["pop"]) > 0 and not c.blueprint(b).kit_mov.is_empty():
			hb = b
			break
	if not check(not hb.is_empty(), "есть жилой дом со ставнями"):
		_end()
		return
	var bp: Bp = c.blueprint(hb)
	var m: Array = bp.kit_mov[0]
	var hs: Array = game.visuals[int(hb["id"])]["h"]
	var hnd: Array = hs[int(m[0])]
	var mm: MultiMesh = (hnd[0]["subs"][0]["mm"])
	var day := mm.get_instance_transform(int(hnd[1]))
	var hp: Vector2 = hb["pos"]
	game.rig.set_view(Vector3(hp.x, game.land.height_at(hp.x, hp.y) + 1.5, hp.y), 180.0 - rad_to_deg(float(hb["yaw"])) + 25.0, 24.0, 11.0)
	await frames(30)
	await shot("day")
	game.hour = 23.5
	await get_tree().create_timer(3.5).timeout
	var night := mm.get_instance_transform(int(hnd[1]))
	var closed: Transform3D = game.city.xf(hb) * bp.kit_sq * Transform3D(Basis(m[2], Vector3.UP, m[3]), m[1])
	check(night.basis.x.distance_to(day.basis.x) > 0.1 and night.basis.x.distance_to(closed.basis.x) < 0.01, "ночью ставни закрылись (днём были открыты)")
	await shot("night")
	game.hour = 9.5
	await get_tree().create_timer(3.5).timeout
	var morning := mm.get_instance_transform(int(hnd[1]))
	check(morning.basis.x.distance_to(day.basis.x) < 0.01, "утром снова открыты (%.4f)" % morning.basis.x.distance_to(day.basis.x))
	_end()


func _end() -> void:
	print("KH DONE fails=", fails)
	get_tree().quit()
