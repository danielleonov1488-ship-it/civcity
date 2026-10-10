class_name Props
extends RefCounted
## Деревья, кусты, цветы, фонари, фонтан, прилавок, амфоры и ворота в скале — всё низкополигональное, в духе Synty.
## Каждая функция дописывает геометрию в общий Kit (k.xf — куда ставить).


## Пиния (зонтичная сосна) — главное дерево Рима: изогнутый ствол и плоская крона-зонтик
static func pine(k: Kit, seed_v: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var bark := Color("7b5a43")
	var h := r.randf_range(5.0, 7.0)
	var lean := Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))
	var p0 := Vector3.ZERO
	var p1 := Vector3(0, h * 0.45, 0) + lean * 0.4
	var p2 := Vector3(0, h, 0) + lean
	k.rod(p0, p1, 0.2, 6, bark)
	k.rod(p1, p2, 0.15, 6, bark)
	# ветви к долям кроны; крона — «зонтик» из многих плоских пучков хвои, сверху светлее
	var top := Color("3f6b30")
	for i in 5:
		var a := TAU * i / 5.0 + r.randf() * 0.5
		var rr := r.randf_range(0.9, 1.6)
		var off := Vector3(cos(a) * rr, r.randf_range(-0.15, 0.35), sin(a) * rr)
		k.rod(p2 - Vector3(0, 0.5, 0), p2 + off, 0.07, 5, bark)
		k.blob(p2 + off + Vector3(0, 0.2, 0), Vector3(1.05, 0.42, 1.05), top.lightened(r.randf() * 0.1), r.randi(), 0.3)
	k.blob(p2 + Vector3(0, 0.5, 0), Vector3(1.3, 0.5, 1.3), top.lightened(0.06), r.randi(), 0.28)
	k.blob(p2 + Vector3(r.randf_range(-0.5, 0.5), 0.85, r.randf_range(-0.5, 0.5)), Vector3(0.8, 0.35, 0.8), top.lightened(0.12), r.randi(), 0.3)


## Кипарис — узкая тёмная свеча
static func cypress(k: Kit, seed_v: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var h := r.randf_range(3.6, 5.4)
	k.rod(Vector3.ZERO, Vector3(0, 0.7, 0), 0.12, 5, Color("6b4c37"))
	var c := Color("3d6834")
	k.blob(Vector3(0, h * 0.42 + 0.4, 0), Vector3(0.55, h * 0.42, 0.55), c, r.randi(), 0.12)
	k.blob(Vector3(0, h * 0.75 + 0.3, 0), Vector3(0.38, h * 0.25, 0.38), c.lightened(0.05), r.randi(), 0.12)


## Олива — низкий корявый ствол и серебристая крона
static func olive(k: Kit, seed_v: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var bark := Color("6f5a48")
	var p1 := Vector3(r.randf_range(-0.3, 0.3), 1.1, r.randf_range(-0.3, 0.3))
	k.rod(Vector3.ZERO, p1, 0.18, 6, bark)
	var leaf := Color("8b9b5e")
	for i in 3:
		var a := TAU * i / 3.0 + r.randf()
		var tip := p1 + Vector3(cos(a) * 0.8, r.randf_range(0.5, 0.9), sin(a) * 0.8)
		k.rod(p1, tip, 0.09, 5, bark)
		k.blob(tip + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9), leaf.lightened(r.randf() * 0.1), r.randi(), 0.25)


static func bush(k: Kit, seed_v: int, s := 1.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var c := Color(["5e8a3e", "6c9444", "537f38"][r.randi() % 3])
	k.blob(Vector3(0, 0.35 * s, 0), Vector3(0.6, 0.42, 0.6) * s, c, r.randi(), 0.25)
	if r.randf() < 0.5:
		for i in 4:
			k.blob(Vector3(r.randf_range(-0.4, 0.4), 0.62 * s, r.randf_range(-0.4, 0.4)), Vector3(0.08, 0.07, 0.08), Color(House.FLOWERS[r.randi() % House.FLOWERS.size()]), r.randi(), 0.2)


## Пятно полевых цветов
static func flowers(k: Kit, seed_v: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var c := Color(["f4f0e8", "f2c443", "d8443d", "b45cc8", "7aa6e0"][r.randi() % 5])
	for i in 9:
		var p := Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.6, 0.6))
		k.rod(p, p + Vector3(0, 0.22, 0), 0.012, 3, Color("4f7f34"))
		k.blob(p + Vector3(0, 0.25, 0), Vector3(0.05, 0.04, 0.05), c, r.randi(), 0.2)


static func rock(k: Kit, seed_v: int, s := 1.0) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	k.blob(Vector3(0, 0.15 * s, 0), Vector3(0.55, 0.35, 0.45) * s, Color("bdb2a2"), r.randi(), 0.3)


## Фонарь на столбе (точка огня возвращается, чтобы зажечь свет ночью)
static func lamp(k: Kit) -> Vector3:
	var iron := Color("2f2a26")
	k.cyl(Vector3.ZERO, 0.14, 0.35, 6, Color("a99c88"))
	k.rod(Vector3(0, 0.3, 0), Vector3(0, 2.6, 0), 0.05, 6, iron)
	k.box(Vector3(-0.17, 2.6, -0.17), Vector3(0.17, 2.66, 0.17), iron)
	k.box(Vector3(-0.13, 2.66, -0.13), Vector3(0.13, 3.0, 0.13), Color("f6c76a"))
	k.cone(Vector3(0, 3.0, 0), 0.22, 0.25, 4, iron)
	return Vector3(0, 2.83, 0)


## Фонтан: восьмиугольная мраморная чаша с профилированным бортом, вода, в центре постамент (статуя ставится отдельно)
static func fountain(k: Kit) -> Array:
	var st := Color("e2d7c3")
	var st2 := Color("cfc3ad")
	var n := 8
	# ступень вокруг
	k.cyl(Vector3.ZERO, 2.75, 0.12, n, st2)
	# стенка чаши: снаружи с выступами-карнизами
	k.cyl(Vector3(0, 0.12, 0), 2.45, 0.12, n, st, -1.0, false)
	k.cyl(Vector3(0, 0.24, 0), 2.35, 0.38, n, st2, 2.35, false)
	k.cyl(Vector3(0, 0.62, 0), 2.5, 0.1, n, st, -1.0, false)
	# широкий борт сверху (кольцо) и внутренняя стенка
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		k.quad_out(o0 * 2.5 + Vector3(0, 0.72, 0), o1 * 2.5 + Vector3(0, 0.72, 0), o1 * 2.15 + Vector3(0, 0.72, 0), o0 * 2.15 + Vector3(0, 0.72, 0), st.lightened(0.05), Vector3(0, 0, 0))
		k.quad_in(o0 * 2.15 + Vector3(0, 0.3, 0), o1 * 2.15 + Vector3(0, 0.3, 0), o1 * 2.15 + Vector3(0, 0.72, 0), o0 * 2.15 + Vector3(0, 0.72, 0), st2.darkened(0.1), Vector3(0, 0.5, 0))
	# вода внутри
	k.cyl(Vector3(0, 0.3, 0), 2.16, 0.26, n, Color("62b8b8"), -1.0, true)
	# постамент с чашей поменьше и львиными мордами
	k.cyl(Vector3(0, 0.5, 0), 0.55, 0.75, n, st)
	k.cyl(Vector3(0, 1.2, 0), 0.62, 0.08, n, st2)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 8.0
		var p := Vector3(cos(a) * 0.56, 0.95, sin(a) * 0.56)
		k.blob(p, Vector3(0.12, 0.12, 0.12), Color("b89a5a"), i, 0.1)
		k.rod(p, p + Vector3(cos(a) * 0.5, -0.45, sin(a) * 0.5), 0.025, 4, Color("bfe8ec"))
	return [Vector3(0, 1.3, 0)]


## Прилавок рынка: стол, ящики с фруктами, полосатый тент на шестах
static func stall(k: Kit, seed_v: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var wood := Color("8a5a36")
	for p: Vector3 in [Vector3(-1.0, 0, -0.6), Vector3(1.0, 0, -0.6), Vector3(-1.0, 0, 0.6), Vector3(1.0, 0, 0.6)]:
		k.rod(p, p + Vector3(0, 2.1, 0), 0.05, 5, wood.darkened(0.2))
	k.box(Vector3(-1.0, 0.75, -0.55), Vector3(1.0, 0.85, 0.55), wood)
	k.box(Vector3(-0.95, 0, -0.5), Vector3(0.95, 0.75, -0.45), wood.darkened(0.15))
	for i in 4:
		var x := -0.72 + i * 0.48
		var fc := Color(["e6a23c", "c43b2f", "7da63a", "e8d36a", "7b3f8c"][r.randi() % 5])
		k.box(Vector3(x - 0.2, 0.85, -0.35), Vector3(x + 0.2, 1.0, 0.35), Color("a0784e"))
		for q in 5:
			k.blob(Vector3(x + r.randf_range(-0.13, 0.13), 1.05, r.randf_range(-0.25, 0.25)), Vector3(0.06, 0.06, 0.06), fc, r.randi(), 0.15)
	# навес из простого холста — без «современных» полос
	var a := Color(["e9dfc6", "d9b878", "c98a5a", "cdbf9f", "b9a27a"][r.randi() % 5])
	var b := a.darkened(0.06)
	for i in 8:
		var x0 := -1.15 + i * 0.2875
		var x1 := x0 + 0.2875
		var col := a if i % 2 == 0 else b
		k.quad(Vector3(x0, 2.25, -0.75), Vector3(x0, 2.45, 0.0), Vector3(x1, 2.45, 0.0), Vector3(x1, 2.25, -0.75), col)
		k.quad(Vector3(x0, 2.45, 0.0), Vector3(x0, 2.25, 0.75), Vector3(x1, 2.25, 0.75), Vector3(x1, 2.45, 0.0), col)
	# амфоры у прилавка
	for i in 2:
		amphora(k, Vector3(1.25, 0, -0.3 + i * 0.45), r.randi())


static func amphora(k: Kit, at: Vector3, seed_v: int) -> void:
	var c := Color(["b5603a", "c9774a", "a85536"][seed_v % 3])
	k.cyl(at, 0.08, 0.15, 7, c, 0.2, false)
	k.cyl(at + Vector3(0, 0.15, 0), 0.2, 0.35, 7, c, 0.17, false)
	k.cyl(at + Vector3(0, 0.5, 0), 0.17, 0.12, 7, c, 0.07, false)
	k.cyl(at + Vector3(0, 0.62, 0), 0.07, 0.12, 7, c, 0.09)


static func crate(k: Kit, at: Vector3, s := 0.45) -> void:
	var w := Color("9a6b40")
	k.box(at + Vector3(-s / 2, 0, -s / 2), at + Vector3(s / 2, s, s / 2), w)
	k.box(at + Vector3(-s / 2 - 0.01, s * 0.45, -s / 2 - 0.01), at + Vector3(s / 2 + 0.01, s * 0.55, s / 2 + 0.01), w.darkened(0.2))


## Деревянная скамья
static func bench(k: Kit) -> void:
	var w := Color("8a5a36")
	k.box(Vector3(-0.8, 0.42, -0.2), Vector3(0.8, 0.5, 0.2), w)
	k.box(Vector3(-0.8, 0.55, -0.24), Vector3(0.8, 0.85, -0.19), w)
	for x: float in [-0.7, 0.7]:
		k.box(Vector3(x - 0.05, 0, -0.18), Vector3(x + 0.05, 0.42, 0.18), w.darkened(0.25))


## Ворота в скале — начало города: каменная арка с клиньями, аттик с надписью, тёмный тоннель, факелы.
## Отсюда приезжают повозки с переселенцами. Возвращает точки факелов.
static func gate(k: Kit) -> Array:
	var st := Color("d6c9b1")
	var st2 := Color("c4b59b")
	var dark := Color("1c1916")
	# тоннель в глубину скалы: стенки смотрят внутрь
	var tc := Vector3(0, 2.0, -3.0)
	k.quad_in(Vector3(-2.0, 0, -6.0), Vector3(2.0, 0, -6.0), Vector3(2.0, 5.4, -6.0), Vector3(-2.0, 5.4, -6.0), dark, tc)
	k.quad_in(Vector3(-2.0, 0, -6.0), Vector3(-2.0, 0, 0.2), Vector3(-2.0, 5.4, 0.2), Vector3(-2.0, 5.4, -6.0), dark.lightened(0.04), tc)
	k.quad_in(Vector3(2.0, 0, -6.0), Vector3(2.0, 0, 0.2), Vector3(2.0, 5.4, 0.2), Vector3(2.0, 5.4, -6.0), dark.lightened(0.04), tc)
	k.quad_in(Vector3(-2.0, 5.4, -6.0), Vector3(2.0, 5.4, -6.0), Vector3(2.0, 5.4, 0.2), Vector3(-2.0, 5.4, 0.2), dark, tc)
	k.quad_in(Vector3(-2.0, 0.02, -6.0), Vector3(2.0, 0.02, -6.0), Vector3(2.0, 0.02, 0.2), Vector3(-2.0, 0.02, 0.2), Color("8f8574"), tc)
	# опоры
	for s: float in [-1.0, 1.0]:
		var x0 := s * 2.0
		var x1 := s * 3.3
		k.box(Vector3(minf(x0, x1), 0, -0.4), Vector3(maxf(x0, x1), 3.4, 0.8), st)
		k.box(Vector3(minf(x0, x1) - 0.12, 0, -0.5), Vector3(maxf(x0, x1) + 0.12, 0.5, 0.9), st2)
		k.box(Vector3(minf(x0, x1) - 0.08, 3.3, -0.45), Vector3(maxf(x0, x1) + 0.08, 3.5, 0.85), Color("e6dcc6"))
		# пилястры
		var px := s * 2.65
		k.box(Vector3(px - 0.25, 0.5, 0.8), Vector3(px + 0.25, 3.3, 0.95), Color("e6dcc6"))
	# арка из клиньев
	var cy := 3.4
	var r0 := 2.0
	var r1 := 3.0
	var n := 11
	for i in n:
		var a0 := PI * i / n
		var a1 := PI * (i + 1) / n
		var col := st if i % 2 == 0 else st2
		if i == n / 2:
			col = Color("efe6d2")
		var p := func(a: float, r: float, z: float) -> Vector3: return Vector3(cos(a) * r, cy + sin(a) * r, z)
		k.quad(p.call(a0, r0, 0.8), p.call(a0, r1, 0.8), p.call(a1, r1, 0.8), p.call(a1, r0, 0.8), col)
		k.quad_in(p.call(a0, r0, -0.4), p.call(a1, r0, -0.4), p.call(a1, r0, 0.8), p.call(a0, r0, 0.8), col.darkened(0.15), Vector3(0, cy, 0.2))
	# стена над аркой до аттика
	k.box(Vector3(-3.3, 3.4, -0.4), Vector3(-2.0, 6.4, 0.8), st)
	k.box(Vector3(2.0, 3.4, -0.4), Vector3(3.3, 6.4, 0.8), st)
	k.box(Vector3(-2.0, 5.4, -0.4), Vector3(2.0, 6.4, 0.75), st)
	# карниз и аттик с плитой надписи
	k.box(Vector3(-3.6, 6.4, -0.5), Vector3(3.6, 6.65, 1.0), Color("e6dcc6"))
	k.box(Vector3(-3.3, 6.65, -0.4), Vector3(3.3, 7.8, 0.85), st)
	k.box(Vector3(-2.2, 6.85, 0.85), Vector3(2.2, 7.6, 0.92), Color("efe6d2"))
	for i in 5:
		k.box(Vector3(-1.8 + i * 0.75, 7.15, 0.92), Vector3(-1.35 + i * 0.75, 7.3, 0.95), Color("8a7a62"))
	k.box(Vector3(-3.6, 7.8, -0.5), Vector3(3.6, 8.0, 1.0), Color("e6dcc6"))
	# факелы на опорах
	var fire: Array = []
	for s: float in [-1.0, 1.0]:
		var fx := s * 3.55
		k.box(Vector3(fx - 0.05, 2.1, 0.6), Vector3(fx + 0.05, 2.15, 1.0), Color("2f2a26"))
		k.cyl(Vector3(fx, 2.15, 1.0), 0.07, 0.4, 6, Color("5a3d26"), 0.1)
		k.blob(Vector3(fx, 2.65, 1.0), Vector3(0.12, 0.2, 0.12), Color("ffb347"), 5, 0.2)
		fire.append(Vector3(fx, 2.7, 1.0))
	return fire
