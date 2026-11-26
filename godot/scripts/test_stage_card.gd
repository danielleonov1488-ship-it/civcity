extends Node
## Карточка боя «Медведи и шайка» (Лес разбойников, бой 6) на разных размерах окна:
##   bash .work/py/gpu_run.sh res://test_stage_card.tscn --resolution 1366x768 -- out=D:/CivCity/.work/stage_card/a tag=1366
## Снимает окно похода и проверяет, что портреты в карточке квадратные (не вытянуты строкой) и карточка целиком в окне.
var game
var out := "D:/CivCity/.work/stage_card"
var tag := "shot"
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		if kv.size() == 2 and kv[0] == "tag":
			tag = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "hour": "10.5"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(name: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print(("STAGECARD ok   " if ok else "STAGECARD FAIL ") + name)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(20)
	var c: City = game.city
	var lg: Legion = c.legion
	var ui := LegionUi.of(game.hud)
	for cn: Dictionary in lg.battle_requested.get_connections():
		lg.battle_requested.disconnect(cn["callable"])
	c.legion_v = 0
	c.level = 4
	c.research["legion"] = true
	c.money = 4000.0
	c.place("barracks", Vector2(150, 205), 0.0, 0, -1, true)
	lg.progress = 5
	lg.levels = {"legionary": 3, "spearman": 1, "archer": 1}
	lg.squad = ["legionary", "legionary", "legionary"]
	lg.flags["tut"] = "done"
	c.changed.emit()
	await frames(10)
	ui.open("campaign")
	await frames(6)
	ui.sel = {"c": 0, "r": 0, "s": 5}
	ui._rebuild()
	await frames(30)
	var vp := get_viewport().get_visible_rect().size
	print("STAGECARD %s viewport %s window scale %s" % [tag, vp, ui.win.scale if ui.win else Vector2.ZERO])
	# портреты: рамки отряда, героя и врагов — квадратные
	var bad := _stretched(ui.content)
	check("портреты квадратные: %s" % ", ".join(bad), bad.is_empty())
	# карточка вмещает всё своё содержимое (последняя строка не залезает на рамку)
	var fb: Control = ui._fight_btn
	if fb != null:
		var v := fb.get_parent() as VBoxContainer
		var card := v.get_parent() as Control
		var last := v.get_child(v.get_child_count() - 1) as Control
		print("STAGECARD card %s vbox %s min %s last %s %s min %s" % [card.size, v.size, v.get_combined_minimum_size(), last.get_class(), Rect2(last.position, last.size), last.get_combined_minimum_size()])
		for ch: Node in v.get_children():
			var cc := ch as Control
			print("STAGECARD   %s y=%.0f h=%.0f min=%s" % [cc.get_class(), cc.position.y, cc.size.y, cc.get_combined_minimum_size()])
		check("карточка вмещает текст: низ %.0f из %.0f" % [last.position.y + last.size.y, v.size.y], last.position.y + last.size.y <= v.size.y + 0.5)
	if ui.win:
		var r := Rect2(ui.win.position, ui.win.size * ui.win.scale)
		check("окно целиком на экране %s в %s" % [r, vp], Rect2(Vector2.ZERO, vp).encloses(r))
	var map_w: float = ui.win.size.x
	check("походы: окно помещается без уменьшения (масштаб %.3f)" % ui.win.scale.x, ui.win.scale.x >= 0.999)
	await _shot(tag)
	# другие вкладки окна: портреты тоже квадратные
	for t: String in ["troops", "pvp"]:
		ui._select_tab(t)
		await frames(30)
		check("%s: портреты квадратные: %s" % [t, ", ".join(_stretched(ui.content))], _stretched(ui.content).is_empty())
		print("STAGECARD %s window %s scale %.3f" % [t, ui.win.size, ui.win.scale.x])
		check("%s: окно той же ширины, что у походов (%.0f / %.0f)" % [t, ui.win.size.x, map_w], absf(ui.win.size.x - map_w) < 0.5)
		check("%s: окно помещается без уменьшения (масштаб %.3f)" % [t, ui.win.scale.x], ui.win.scale.x >= 0.999)
		var body := ui.content.get_child(ui.content.get_child_count() - 1) as Control
		for ch: Node in body.get_children():
			if ch is Control:
				print("STAGECARD   %s %s h=%.0f min=%s" % [t, ch.get_class(), (ch as Control).size.y, (ch as Control).get_combined_minimum_size()])
		await _shot("%s_%s" % [tag, t])
	# большой отряд (прежний Легион: до 7 мест): карточка той же ширины, портреты квадратные
	for nq: int in [5, 7]:
		lg.flags["slots0"] = nq
		lg.squad = []
		for i in nq:
			lg.squad.append("legionary")
		ui._select_tab("campaign")
		ui.sel = {"c": 0, "r": 0, "s": 5}
		ui._rebuild()
		await frames(30)
		var card2 := (ui._fight_btn.get_parent() as Control).get_parent() as Control
		check("отряд %d: карточка шириной %.0f (как была 330)" % [nq, card2.size.x], absf(card2.size.x - 330.0) < 0.5)
		check("отряд %d: портреты квадратные: %s" % [nq, ", ".join(_stretched(ui.content))], _stretched(ui.content).is_empty())
		check("отряд %d: окно помещается без уменьшения (%.3f, %s)" % [nq, ui.win.scale.x, ui.win.size], ui.win.scale.x >= 0.999 and absf(ui.win.size.x - map_w) < 0.5)
		await _shot("%s_squad%d" % [tag, nq])
	print("STAGECARD DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Рамки портретов (бойцы, герой), вытянутые строкой: ширина не равна высоте
func _stretched(root: Control) -> Array:
	var bad := []
	for n: Node in root.find_children("*", "Control", true, false):
		var cc := n as Control
		if not cc.is_visible_in_tree():
			continue
		var round_one := (cc is PanelContainer and cc.get_child_count() > 0 and cc.get_child(0).name == "FortPortraitArt") or cc.name == "hero_slot"
		if round_one and absf(cc.size.x - cc.size.y) > 1.5:
			bad.append("%s %s" % [cc.name, cc.size])
	return bad


func _shot(name: String) -> void:
	await frames(8)
	var p := "%s/%s.png" % [out, name]
	get_viewport().get_texture().get_image().save_png(p)
	print("STAGECARD shot ", p)
