extends SceneTree
## События недели без окна (docs/ONLINE_V2.md §3): неделя как на сервере, чередование нашествия и подземелий, враги
## под силу отряда, бой события досчитывается (LegionSim), награды и счётчики набегов и этажей, настройка испытания.
## Запуск: Godot --headless --path godot --script res://scripts/test_events_city.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print("EVENTSCITY %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _init() -> void:
	# неделя: 2.11.2026 00:00 UTC — неделя 0, через 7 дней — 1
	check(LegionEvents.week(1793577600.0) == 0 and LegionEvents.week(1793577600.0 + 604800.0 + 5.0) == 1, "неделя — как на сервере")
	check(LegionEvents.kind(0) == "invasion" and LegionEvents.kind(1) == "dungeon", "нашествие и подземелья чередуются")
	# враги под силу
	var foes := LegionEvents.foes_for(["gaul", "gaul", "gaulArcher", "berserker", "wolf"], 3000.0)
	var p := 0
	for f: Dictionary in foes:
		p += Legion.power(f)
	check(foes.size() == 5 and absf(p - 3000.0) < 3000.0 * 0.06, "враги подобраны под силу 3000 (вышло %d)" % p)
	var boss := LegionEvents.foes_for(LegionEvents.FLOOR_FOES[4], 5000.0)
	check(bool(Legion.ENEMIES["gaulKing"].get("boss", false)) and boss.size() == 5, "в последнем подземелье — вождь галлов")
	# бой события досчитывается: отряд 5 бойцов против врагов той же силы
	var own := {"squad": [{"type": "legionary", "level": 12}, {"type": "legionary", "level": 12}, {"type": "spearman", "level": 12},
		{"type": "archer", "level": 12}, {"type": "archer", "level": 12}], "perks": {"oil": 2}}
	var mine := Legion.snapshot_stats(own)
	var mp := 0
	for s: Dictionary in mine:
		mp += Legion.power(s)
	var setup := {"kind": "pvp", "squad": mine, "waves": [LegionEvents.foes_for(LegionEvents.FLOOR_FOES[0], mp * 0.8)], "perks": {"oil": 2},
		"enemy_perks": {}, "enemy_auto": true, "enemy_formation": true, "seed": 4242, "event": {"id": "floor", "title": "t", "k": 0.8, "power": mp}}
	var r := LegionSim.new(setup).run(true)
	check(r.has("win") and float(r.get("time", 0.0)) > 1.0, "бой события досчитан (победа: %s, %.1f с)" % [str(r.get("win")), float(r.get("time", 0.0))])
	# награды и счётчики
	var land := Land.new()
	var c := City.new(land)
	c.cozy_v = 1
	land.own_start()
	c.place("center", Land.CENTER, PI / 2, 0, 0, true)
	var lg: Legion = c.legion
	var m0 := c.money
	var out := LegionEvents.apply(lg, {"event": {"id": "floor", "k": 0.8, "power": 2000}}, {"win": true})
	check(LegionEvents.floor_now(lg) == 1 and float(out["reward"].get("money", 0)) > 0.0 and c.money > m0, "этаж пройден: следующий, награда в казне")
	var out2 := LegionEvents.apply(lg, {"event": {"id": "raid", "k": 1.0, "power": 2000}}, {"win": false})
	check(LegionEvents.raids_left(lg) == LegionEvents.RAIDS_DAY - 1 and (out2["reward"] as Dictionary).is_empty(), "проигранный набег тоже считается, без награды")
	var e: Dictionary = lg.flags["ev"]
	e["w"] = int(e["w"]) - 1
	check(LegionEvents.floor_now(lg) == 0, "новая неделя — подземелья заново")
	# испытание: настройка боя по ответу сервера
	var a := {"battle": "tok", "seed": 77, "tier": 2, "name": "Серьёзное испытание: «Без умений»", "attack": own, "enemy": {"squad": [{"type": "archer", "level": 6}], "perks": {}}}
	var ts := LegionEvents.make_trial(lg, a)
	check(String(ts["event"]["id"]) == "trial" and String(ts["event"]["battle"]) == "tok" and (ts["squad"] as Array).size() == 5 and int(ts["seed"]) == 77
		and not (ts["opponent"] as Dictionary).has("battle"), "испытание: бой по ответу сервера (бои с городами его не доложат)")
	print("EVENTSCITY DONE fails=%d" % fails)
	quit(1 if fails else 0)
