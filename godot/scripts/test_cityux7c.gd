extends "res://scripts/test_cityux7a.gd"
## Снимки CITYUX7c. Проверяющий запускает сцену с отдельным профилем.


func _ready() -> void:
	prefix = "CITYUX7C"
	out = "D:/CivCity/.work/stage6/cityux7c/shots/"
	var profile := "D:/CivCity/.work/stage6/cityux7c/profiles/run_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if not check(DirAccess.make_dir_recursive_absolute(profile) == OK, "isolated profile directory"):
		print(prefix, " DONE fails=", fails)
		get_tree().quit(1)
		return
	OS.set_environment("CIVCITY_SAVEDIR", profile)
	OS.set_environment("CIVCITY_NOLOGIN", "1")
	OS.set_environment("CIVCITY_NOMINPAUSE", "1")
	OS.set_environment("CIVCITY_HEROSCREEN", "0")
	GamePaths._dir = ""
	I18n.set_lang("ru")
	super._ready()


func _top_tooltips() -> void:
	await super._top_tooltips()
	await move_to(hud.cats["housing"])
	check(not hud.hover_tip.visible, "top tooltip hides after leaving the bar")
	await wedding_checklist()


func wedding_checklist() -> void:
	var stories: Stories = game.stories
	stories.set_process(false)
	city.level = 3
	city.research["s_wedding"] = true
	city.research["deco_flowers"] = true
	city.research["thermopolium"] = true
	game.build_anim = false
	var home := city.place("house_pleb", Vector2(177, 136), 0.0, 0, 0, true)
	if not check(not home.is_empty(), "wedding fixture home"):
		return
	var active := {"id": "wedding", "step": 1, "home": int(home["id"]), "fam": "Юлии",
		"flags": {"choice": "garden"}, "t0": int(city.stories["h"]), "id0": city.next_id}
	city.stories["offer"] = {}
	city.stories["active"] = active
	game.settings["tasks_folded"] = false
	game.rig.set_view(Vector3(177, Land.BASE_Y, 136), 20, 48, 36)
	hud.refresh()
	await frames()
	var row := hud.tasks_box.find_child("story_row", true, false)
	var list := row.find_child("parts", true, false) if row != null else null
	if not check(list != null and list.get_child_count() == 2, "wedding shows two garden requirements"):
		return
	var flowers := list.get_child(0) as Button
	var arbor := list.get_child(1) as Button
	check(flowers.icon != null and flowers.text == "Цветы · осталось 8", "eight flowers with icon")
	check(arbor.icon != null and arbor.text == "Беседка или арка · осталось 1", "one arbor or arch with icon")
	if not check(wedding_button("Выбрать место") != null and wedding_button("Лучше: пир в таверне") != null,
		"garden can choose area or switch to tavern"):
		return
	await shot("08_wedding_garden.png")
	var choose := wedding_button("Выбрать место")
	if not check(choose != null, "garden area button still visible"):
		return
	choose.pressed.emit()
	var zone := Vector2(184, 164)
	check(game.tool == "story_zone" and stories.place_zone(zone) and stories._hp(active) == zone,
		"garden uses the chosen area")
	var tavern := wedding_button("Лучше: пир в таверне")
	if not check(tavern != null and wedding_button("Перенести") != null, "can move area or change feast"):
		return
	tavern.pressed.emit()
	var parts: Array = stories.row_info().get("parts", [])
	check(parts.size() == 1 and String(parts[0]["text"]) == "Таверна · осталось 1", "switching branch swaps checklist")
	await shot("09_wedding_tavern.png")


func wedding_button(caption: String) -> Button:
	var row := hud.tasks_box.find_child("story_row", true, false)
	if row == null:
		return null
	for b: Button in row.find_children("*", "Button", true, false):
		if b.text == caption and b.is_visible_in_tree() and not b.is_queued_for_deletion():
			return b
	return null
