extends SceneTree
## Подарки друзей в городе без окна (docs/ONLINE_V2.md): SocialNet.apply_gift → City.gifts; подарок открывает постройку,
## ставится даром и помнит дарителя; сохранение и загрузка; карточка города; прибавка туристов без входа — 0.
## Запуск: Godot --headless --path godot --script res://scripts/test_social_city.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	print("SOCIALCITY %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


class FakeGame:
	var city
	var people = null
	var mode := "play"


func _init() -> void:
	var land := Land.new()
	var c := City.new(land)
	c.cozy_v = 1
	c.econ = 1
	c.decor_v = 1
	land.own_start()
	c.place("center", Land.CENTER, PI / 2, 0, 0, true)
	c.money = 50.0
	var g := FakeGame.new()
	g.city = c
	check(not c.unlocked("fountain"), "фонтан ещё не открыт")
	SocialNet.apply_gift(g, "fountain", "Брундизий", "фонтанчик")
	SocialNet.apply_gift(g, "flowers", "Капуя", "цветочные вазоны")
	check(c.gift_ready("fountain") and c.unlocked("fountain"), "подарок открывает фонтан")
	check((c.gifts.get("flowers", []) as Array).size() == 3, "цветы — три штуки даром")
	# поставить фонтан даром (денег 50 — фонтан стоит 400)
	var spot := Vector2.ZERO
	var found := false
	for dz in range(-30, 31, 3):
		for dx in range(-30, 31, 3):
			var p := Land.CENTER + Vector2(dx, dz)
			if c.check_place("fountain", p, 0.0)["err"] == "":
				spot = p
				found = true
				break
		if found:
			break
	check(found, "нашлось место для фонтана (денег меньше цены — подарок не мешает)")
	var m0 := c.money
	var b := c.place("fountain", spot, 0.0) if found else {}
	check(not b.is_empty() and String(b.get("gift", "")) == "Брундизий" and absf(c.money - m0) < 0.01, "фонтан встал даром и помнит дарителя")
	check(not c.gift_ready("fountain"), "подарок фонтана израсходован")
	check(not c.unlocked("fountain") or c.research.has("fountain"), "без подарка фонтан снова закрыт")
	# сохранение и загрузка
	var d := c.save_data()
	var land2 := Land.new()
	var c2 := City.new(land2)
	land2.load_changes(d.get("land", {}))
	c2.load_data(JSON.parse_string(JSON.stringify(d)))
	var b2: Dictionary = c2.buildings.get(int(b.get("id", -1)), {})
	check(String(b2.get("gift", "")) == "Брундизий", "после загрузки фонтан помнит дарителя")
	check((c2.gifts.get("flowers", []) as Array).size() == 3 and (c2.gifts["flowers"] as Array)[0] == "Капуя", "после загрузки цветы-подарки на месте")
	# список подарков для окна
	var gl := FriendsUi.gifts_here(c2)
	check(gl.size() == 2 and String(gl[0]).contains("Брундизий") and String(gl[1]).contains("×3"), "окно «Друзья»: подарки в городе (%s)" % str(gl))
	# без входа туристы из других городов ничего не прибавляют
	check(SocialNet.tour_bonus(c) == 0.0, "без сервера прибавки к туристам нет")
	print("SOCIALCITY DONE fails=%d" % fails)
	quit(1 if fails else 0)
