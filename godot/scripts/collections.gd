class_name Collections
## Коллекции города («Уютный Рим», бесконечная игра, docs/PLAN_COZY.md раздел 8.4): вкладка журнала — что собрано:
## окрасы кошек, статуи, виды украшений, трофеи и вещи наборов Легиона, римские праздники, почётные титулы.
## Ничего не хранит сам: всё считается из города (cats, buildings, legion, chron, renown).

const FUR_NAMES := ["рыжая", "серая полосатая", "чёрная", "белая", "бурая полосатая", "«во фраке»", "Мася", "сиамская"]


## Разделы: [{title, icon, have: [названия], all: число, hint}]
static func sections(c: City) -> Array:
	var out := []
	# кошки: окрасы
	var furs := {}
	for k: Dictionary in c.cats:
		furs[int(k.get("fur", 0))] = true
	var fl := []
	for f in furs.keys():
		if int(f) < FUR_NAMES.size():
			fl.append(String(FUR_NAMES[int(f)]))
	out.append({"title": "Окрасы кошек", "icon": "cat", "have": fl, "all": FUR_NAMES.size(),
		"hint": "Кошки приходят к семьям, что их любят. Редкие — сиамская и чёрная Мася из истории горожан."})
	# статуи и виды украшений
	var statues := {}
	var decor := {}
	var decor_all := 0
	for t in Defs.B:
		var d: Dictionary = Defs.B[t]
		if String(d.get("kind", "")) == "decor" and c.unlocked(String(t)):
			decor_all += 1
	var st_all := 0
	for t in Defs.B:
		if String(Defs.base_of(String(t))) == "statue":
			st_all += 1
	for id in c.buildings:
		var t := String(c.buildings[id]["type"])
		var d: Dictionary = Defs.B.get(t, {})
		if String(d.get("kind", "")) == "decor":
			decor[t] = String(d.get("name", t))
			if Defs.base_of(t) == "statue":
				statues[t] = String(d.get("name", t))
	out.append({"title": "Статуи", "icon": "laurels", "have": statues.values(), "all": st_all, "hint": "Статуи — в разделе «Украшения» → «Камень»."})
	out.append({"title": "Виды украшений в городе", "icon": "flower", "have": [], "count": decor.size(), "all": maxi(decor_all, decor.size()),
		"hint": "Сколько разных украшений стоит в городе из открытых."})
	# Легион: трофеи, реликвии и вещи наборов
	var lg := c.legion
	var tro := []
	for R: Dictionary in Legion.regions():
		if lg.has_trophy(String(R["id"])):
			tro.append(String(R["name"]))
	out.append({"title": "Трофеи Легиона", "icon": "legion", "have": tro, "all": maxi(1, Legion.regions().filter(func(R): return String(R.get("trophy", "")) != "").size()),
		"hint": "Трофей — за все звёзды провинции."})
	if lg.army_on():
		var sets := {}
		for it: Dictionary in lg.items:
			var k := String(it.get("set", ""))
			if k != "":
				sets["%s|%s" % [k, it.get("slot", "")]] = true
		var names := []
		for k: String in Gear.SET_IDS:
			var n := 0
			for key in sets:
				if String(key).begins_with(k + "|"):
					n += 1
			if n > 0:
				names.append("%s %d/5" % [Gear.SETS[k]["name"], n])
		out.append({"title": "Вещи наборов", "icon": "swords", "have": names, "count": sets.size(), "all": Gear.SET_IDS.size() * Gear.SLOTS.size(),
			"hint": "Вещи наборов куются в Кузнице из реликвий боссов похода."})
	# праздники и титулы (новая игра)
	if Renown.on(c):
		var fests := []
		for f: Dictionary in Renown.CAL_FESTS:
			if int((c.chron.get("c", {}) as Dictionary).get("cal_" + String(f["id"]), 0)) > 0:
				fests.append(String(f["name"]))
		out.append({"title": "Римские праздники", "icon": "laurels", "have": fests, "all": Renown.CAL_FESTS.size(),
			"hint": "Праздники приходят сами по календарю: Луперкалии, Флоралии, Виналии, Сатурналии."})
		var titles := []
		for i in Renown.title_idx(c.renown) + 1:
			titles.append(String(Renown.TITLES[i][1]))
		out.append({"title": "Почётные титулы", "icon": "laurels", "have": titles, "all": Renown.TITLES.size(),
			"hint": "Титулы — за известность города (плашка под плашкой города)."})
	return out


static func fill(hud, list: VBoxContainer) -> void:
	var c: City = hud.game.city
	var secs := sections(c)
	var got := 0
	var all := 0
	for s: Dictionary in secs:
		got += int(s.get("count", (s["have"] as Array).size()))
		all += int(s["all"])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(hud._icon("keys", 30, hud.C_GOLD))
	head.add_child(hud._label("Коллекции города: собрано %d из %d" % [got, all], 20, false, hud.C_INK, hud.font_title))
	list.add_child(head)
	for s: Dictionary in secs:
		var n := int(s.get("count", (s["have"] as Array).size()))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(hud._icon(String(s["icon"]), 22, hud.C_SOFT))
		var l: Label = hud._label(String(s["title"]), 16, true, hud.C_INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(hud._label("%d / %d" % [n, int(s["all"])], 16, true, hud.C_GOOD if n >= int(s["all"]) else hud.C_INK))
		list.add_child(h)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(540, 6)
		bar.show_percentage = false
		bar.max_value = maxf(1.0, float(s["all"]))
		bar.value = n
		list.add_child(bar)
		var have: Array = s["have"]
		var txt := (", ".join(have) + ". ") if not have.is_empty() else ""
		list.add_child(hud._wrap(hud._label(txt + String(s["hint"]), 13, false, hud.C_SOFT), 540))
		list.add_child(hud._divider(8))
