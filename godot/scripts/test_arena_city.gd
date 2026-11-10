extends SceneTree
## Награда сезона арены в городе без окна (docs/ONLINE_V2.md §2): LegionNet.apply_prize — денарии, Слава, лучшая лига
## в Legion.flags (сохраняется), плащи арены в гардеробе героя открываются лигой.
## Запуск: Godot --headless --path godot --script res://scripts/test_arena_city.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print("ARENACITY %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


class FakeGame:
	var city
	var hud = null
	var mode := "play"


func _init() -> void:
	var land := Land.new()
	var c := City.new(land)
	c.cozy_v = 1
	land.own_start()
	c.place("center", Land.CENTER, PI / 2, 0, 0, true)
	var g := FakeGame.new()
	g.city = c
	var cent := {"arena": 4}
	var leg := {"arena": 5}
	check(not Hero.open(c, cent) and not Hero.open(c, leg), "плащи арены закрыты")
	check(Hero.need_text(cent).contains("Центурионы"), "подсказка: «%s»" % Hero.need_text(cent))
	var m0 := c.money
	var g0 := c.legion.glory
	LegionNet.apply_prize(g, {"season": 3, "league": 4, "name": "Центурионы", "money": 7500, "glory": 30, "place": 0})
	check(absf(c.money - m0 - 7500.0) < 0.01 and absf(c.legion.glory - g0 - 30.0) < 0.01, "награда: +7500 ден. и +30 Славы")
	check(Hero.open(c, cent) and not Hero.open(c, leg), "лига «Центурионы» открыла багряный плащ")
	LegionNet.apply_prize(g, {"season": 4, "league": 2, "name": "Принципы", "money": 2500, "glory": 10, "place": 2})
	check(int(c.legion.flags["arena"]) == 4, "лучшая лига не падает от слабого сезона")
	check(int((c.chron["c"] as Dictionary).get("arena_wreath", 0)) == 1, "место в тройке — венок в летопись")
	var d := c.legion.to_dict()
	var lg2 := Legion.new()
	lg2.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(int(lg2.flags.get("arena", -1)) == 4, "лучшая лига сохраняется")
	print("ARENACITY DONE fails=%d" % fails)
	quit(1 if fails else 0)
