extends "res://scripts/test_ux.gd"
## Регрессия «Этажа»: прежние проверки UX и снимки стрелок после UI4/UI4b.

const Badge = preload("res://scripts/map_badge.gd")
var out := "D:/CivCity/.work/stage4/ui4c/shots/"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "out":
			out = pair[1] if pair[1].ends_with("/") else pair[1] + "/"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	game.can_save = false
	add_child(game)
	_run()


func check(ok: bool, what: String, extra = null) -> bool:
	print(("UI4C PASS " if ok else "UI4C FAIL ") + what + ("" if ok or extra == null else "  " + str(extra)))
	if not ok:
		fails += 1
	return ok


func shot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "папка снимков"):
		return
	var error := get_viewport().get_texture().get_image().save_png(out + name)
	if check(error == OK, "сохранён " + name):
		print("UI4C SHOT " + out + name)


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			print("UI4C DONE fails=%d" % fails)
			get_tree().quit(1)
			return
	c = game.city
	c.auto_hire = true
	cover = game.cover
	hud = game.hud
	hud.house_more = true
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	game.tutorial.step = Tutorial.STEPS.size()
	game.tutorial.card.visible = false
	c.tips["tut"] = -1
	c.tips["ui"] = 3
	c.tips["cover_tip"] = true
	c.legion.flags["camp_told"] = true
	hud.apply_reveal(3)
	await frames(5)
	await _town()
	await _floor_locked()
	await _floor_tool()
	await _floor_stroke()
	await _floor_broke()
	await _floor_why()
	await _floor_mixed()
	await _badge_top()
	await _floor_exit()
	print("UI4C DONE fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _arrow_look(id: int, warning: bool) -> void:
	var key := "fl%d" % id
	if not check(hud.badges.has(key), "есть стрелка дома %d" % id):
		return
	var badge: Badge = hud.badges[key]["n"]
	check(badge.is_visible_in_tree(), "стрелка дома %d видна" % id)
	check(badge.arrow and badge.size.y == 66.0 and badge.label != null and badge.pill != null, "стрелка 40 px и цена под ней")
	if badge.label == null or badge.pill == null:
		return
	check(badge.label.text == hud.fmt(c.floor_price(c.buildings[id])), "цена в плашке под стрелкой")
	check(badge.warn == warning and badge.label.get_theme_color("font_color") == (Badge.BAD if warning else Badge.INK), "красный текст цены" if warning else "обычный текст цены")
	check(badge.label.position.y >= 44 and badge.pill.border_color == Badge.RIM and badge.pill.border_width_top == 1 and badge.pill.corner_radius_top_left == 10, "тонкая кремовая плашка цены")
	check(not cover.want.has(id) if warning else cover.want.get(id) == Cover.GREEN, "красная цена без зелёной подсветки" if warning else "доступный дом подсвечен")


func _floor_tool() -> void:
	await super._floor_tool()
	var ready: Array = c.floor_ready(false)
	check(floor_path(ready).size() == ready.size(), "весь ряд стрелок в кадре")
	for id in ready:
		_arrow_look(int(id), false)
	if ready.is_empty():
		return
	# Исчезновение скрытого обычного значка не должно сдвинуть стрелку инструмента.
	var id: int = ready[0]
	var key := "fl%d" % id
	var before: Dictionary = hud.badges[key]
	var pos: Vector3 = before["pos"]
	var rect: Rect2 = (before["n"] as Control).get_global_rect()
	var home: Dictionary = c.buildings[id]
	var expected_y: float = float(home["y"]) + c.blueprint(home).top_y() + 1.2
	check(is_equal_approx(pos.y, expected_y), "скрытая обычная стрелка не поднимает стрелку инструмента")
	check((not hud.world_icons.has(id) or not (hud.badges["b%d" % id]["n"] as Control).visible), "обычный значок не заслоняет инструмент")
	var money: float = c.money
	c.money = c.floor_price(home) - 1.0
	c.changed.emit()
	await frames(4)
	hud._place_badges()
	_arrow_look(id, true)
	check(hud.badges[key]["pos"] == pos and (hud.badges[key]["n"] as Control).get_global_rect() == rect, "красная цена сохраняет место и размер стрелки")
	move(badge_scr(key))
	await frames(3)
	check(cover.cap[2] == "Не хватает денариев: этаж стоит %s ден." % hud.fmt(c.floor_price(home)), "у красной стрелки точная цена нехватки")
	await shot("ui4c_price_red.png")
	c.money = money
	c.changed.emit()
	await frames(4)
	_arrow_look(id, false)
	check(hud.badges[key]["pos"] == pos and (hud.badges[key]["n"] as Control).get_global_rect() == rect, "возврат обычной стрелки не сдвигает инструмент")


func _floor_broke() -> void:
	await super._floor_broke()
	var red := 0
	for id in row1:
		var key := "fl%d" % int(id)
		if hud.badges.has(key) and bool(hud.badges[key]["warn"]):
			_arrow_look(int(id), true)
			red += 1
	check(red > 0, "после исчерпания денег осталась видимая красная цена")
