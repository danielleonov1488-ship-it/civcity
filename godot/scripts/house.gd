class_name House
extends RefCounted
## Римский дом в духе Synty: каменный цоколь, оштукатуренные стены, карнизы между этажами,
## окна со ставнями и ящиками цветов, дверь в каменной раме, лавка с навесом, балкон, черепица рядами,
## труба с дымом. Начало координат — середина основания, фасад смотрит на +Z.
## build() возвращает {"mesh": ArrayMesh, "smoke": [точки труб]}.

const WALLS := ["e3b56b", "dc977c", "efdcb6", "ecd283", "f0e9dc", "c9654a", "e7c39a"]
const SHUTTERS := ["5f7f52", "4e7d85", "7a5235", "5c6e88", "8a3f32"]
const TILES := ["c8693c", "b95c34", "d27a46", "bf6a3f"]
const FLOWERS := ["d8443d", "f07aa0", "f4f0e8", "f2c443", "b45cc8", "ff8a3d"]
const STONE := "c4b8a3"
const STONE_DARK := "a89c88"
const TRIM := "f1e6cc"
const WOOD := "7a4b2c"
const GLASS := "3a3a40"
const FLOOR_H := 2.5
const PLINTH := 0.4

var k := Kit.new()
var rng := RandomNumberGenerator.new()
var smoke: Array[Vector3] = []


## p: w, d, floors, wall, shutter, roof ("gable" | "hip" | "terrace"), shop, balcony, seed, sides (рисовать ли боковые стены)
func build(p: Dictionary) -> Dictionary:
	rng.seed = p.get("seed", 1)
	var w: float = p.get("w", 4.4)
	var d: float = p.get("d", 4.6)
	var fl: int = p.get("floors", 2)
	var wall := Color(p.get("wall", WALLS[rng.randi() % WALLS.size()]))
	var shut := Color(p.get("shutter", SHUTTERS[rng.randi() % SHUTTERS.size()]))
	var roof: String = p.get("roof", "gable")
	var top := PLINTH + fl * FLOOR_H
	# цоколь из камня, чуть шире стен
	k.box(Vector3(-w / 2 - 0.06, 0, -d / 2 - 0.06), Vector3(w / 2 + 0.06, PLINTH, d / 2 + 0.06), Color(STONE))
	# этажи: стены, над каждым — карниз
	for f in fl:
		var y0 := PLINTH + f * FLOOR_H
		var y1 := y0 + FLOOR_H
		var wc := wall.darkened(0.05) if f == 0 else wall
		k.box(Vector3(-w / 2, y0, -d / 2), Vector3(w / 2, y1, d / 2), wc)
		# угловые камни (рустовка) на первом этаже
		if f == 0:
			for sx: float in [-1.0, 1.0]:
				var yy := y0
				var alt := false
				while yy < y1 - 0.2:
					var hh := 0.32
					var ww := 0.36 if alt else 0.26
					k.box(Vector3(sx * w / 2 - (ww if sx > 0 else 0.0) - 0.02 * sx, yy, d / 2 - 0.0), Vector3(sx * w / 2 + (0.0 if sx > 0 else ww) + 0.02 * sx, yy + hh - 0.03, d / 2 + 0.04), Color(STONE).lightened(0.05))
					yy += hh
					alt = not alt
		k.box(Vector3(-w / 2 - 0.08, y1 - 0.06, -d / 2 - 0.08), Vector3(w / 2 + 0.08, y1 + 0.08, d / 2 + 0.08), Color(TRIM))
	# фасад: окна, дверь, лавка
	_front(w, d, fl, shut, p)
	# задняя стена — тоже окна (их видно, когда крутишь камеру)
	k.xf = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	for f in range(0, fl):
		_windows(w, d, PLINTH + f * FLOOR_H, shut, f > 0 and rng.randf() < 0.5)
	# боковые стены: по окну на этаж (у домов в ряду их закроет сосед)
	for side: float in [-1.0, 1.0]:
		k.xf = Transform3D(Basis(Vector3.UP, side * PI / 2), Vector3.ZERO)
		for f in range(1, fl):
			_window(0.0, PLINTH + f * FLOOR_H + 0.75, w / 2, shut, rng.randf() < 0.4)
	k.xf = Transform3D.IDENTITY
	# крыша
	match roof:
		"terrace":
			_terrace(w, d, top, wall)
		"hip":
			_roof(w, d, top, true)
		_:
			_roof(w, d, top, false)
	# труба
	if roof != "terrace" or rng.randf() < 0.5:
		var cx := w * (0.25 if rng.randf() < 0.5 else -0.25)
		var cz := -d * 0.18
		var base_y := top + (0.6 if roof != "terrace" else 0.0)
		k.box(Vector3(cx - 0.24, top - 0.2, cz - 0.24), Vector3(cx + 0.24, base_y + 1.0, cz + 0.24), Color(TRIM).darkened(0.08))
		k.box(Vector3(cx - 0.3, base_y + 1.0, cz - 0.3), Vector3(cx + 0.3, base_y + 1.12, cz + 0.3), Color(STONE_DARK))
		k.box(Vector3(cx - 0.16, base_y + 1.12, cz - 0.16), Vector3(cx + 0.16, base_y + 1.3, cz + 0.16), Color(TILES[0]))
		smoke.append(Vector3(cx, base_y + 1.35, cz))
	return {"mesh": k.mesh(), "smoke": smoke}


func _front(w: float, d: float, fl: int, shut: Color, p: Dictionary) -> void:
	var z := d / 2
	var shop: bool = p.get("shop", false)
	# первый этаж: дверь в каменной раме и окно — или лавка с навесом
	var door_x := -w * 0.22 if w > 3.6 else 0.0
	_door(door_x, z)
	if shop and w > 3.6:
		_shop(w * 0.22, z, minf(1.9, w * 0.42))
	elif w > 3.6:
		_window(w * 0.24, PLINTH + 0.9, z, shut, rng.randf() < 0.7)
	# верхние этажи — окна; на втором иногда балкон
	for f in range(1, fl):
		var y := PLINTH + f * FLOOR_H
		if f == 1 and p.get("balcony", false):
			_balcony(w, y, z)
		_windows(w, d, y, shut, true)


func _windows(w: float, d: float, y: float, shut: Color, flowers: bool) -> void:
	var n := maxi(1, int((w - 0.6) / 1.45))
	for i in n:
		var x := -w / 2 + w * (i + 0.5) / n
		_window(x, y + 0.75, d / 2, shut, flowers and rng.randf() < 0.75)


## Окно: стекло в глубине, каменный подоконник и перемычка, открытые ставни по бокам, ящик с цветами
func _window(x: float, y: float, z: float, shut: Color, box_flowers: bool) -> void:
	var ww := 0.62
	var wh := 0.95
	k.box(Vector3(x - ww / 2, y, z - 0.02), Vector3(x + ww / 2, y + wh, z + 0.012), Color(GLASS))
	# переплёт
	k.box(Vector3(x - 0.025, y, z), Vector3(x + 0.025, y + wh, z + 0.03), Color(TRIM).darkened(0.1))
	k.box(Vector3(x - ww / 2, y + wh * 0.55, z), Vector3(x + ww / 2, y + wh * 0.55 + 0.04, z + 0.03), Color(TRIM).darkened(0.1))
	# подоконник и перемычка
	k.box(Vector3(x - ww / 2 - 0.08, y - 0.07, z - 0.02), Vector3(x + ww / 2 + 0.08, y, z + 0.1), Color(TRIM))
	k.box(Vector3(x - ww / 2 - 0.06, y + wh, z - 0.02), Vector3(x + ww / 2 + 0.06, y + wh + 0.1, z + 0.05), Color(TRIM))
	# ставни, распахнутые к стене, с планками
	for s: float in [-1.0, 1.0]:
		var x0 := x + s * (ww / 2 + 0.02)
		var x1 := x + s * (ww / 2 + 0.02 + ww * 0.5)
		k.box(Vector3(minf(x0, x1), y - 0.02, z), Vector3(maxf(x0, x1), y + wh + 0.02, z + 0.05), shut)
		for q in 4:
			var yy := y + 0.08 + q * 0.22
			k.box(Vector3(minf(x0, x1) + 0.03, yy, z + 0.05), Vector3(maxf(x0, x1) - 0.03, yy + 0.05, z + 0.07), shut.darkened(0.25))
	if box_flowers:
		_flower_box(x, y - 0.07, z + 0.1, ww + 0.1)


func _flower_box(x: float, y: float, z: float, len: float) -> void:
	k.box(Vector3(x - len / 2, y - 0.2, z), Vector3(x + len / 2, y, z + 0.2), Color("b5603a"))
	var n := int(len / 0.13)
	for i in n:
		var fx := x - len / 2 + (i + 0.5) * len / n
		var leaf := Color("5c8a3a").lightened(rng.randf() * 0.15)
		k.blob(Vector3(fx, y + 0.06, z + 0.1), Vector3(0.09, 0.08, 0.09), leaf, rng.randi(), 0.25)
		if rng.randf() < 0.75:
			var fc := Color(FLOWERS[rng.randi() % FLOWERS.size()])
			k.blob(Vector3(fx + rng.randf_range(-0.03, 0.03), y + 0.14, z + 0.1 + rng.randf_range(-0.04, 0.04)), Vector3(0.05, 0.045, 0.05), fc, rng.randi(), 0.2)
	# свисающая зелень
	for i in 2:
		var fx := x + rng.randf_range(-len / 3, len / 3)
		k.blob(Vector3(fx, y - 0.24, z + 0.21), Vector3(0.07, 0.16, 0.05), Color("4f7f34"), rng.randi(), 0.3)


func _door(x: float, z: float) -> void:
	var dw := 0.95
	var dh := 1.95
	var y := PLINTH
	# ступенька и каменная рама с аркой
	k.box(Vector3(x - dw / 2 - 0.2, 0, z), Vector3(x + dw / 2 + 0.2, PLINTH, z + 0.35), Color(STONE).lightened(0.05))
	k.box(Vector3(x - dw / 2 - 0.14, y, z - 0.02), Vector3(x - dw / 2, y + dh, z + 0.08), Color(TRIM))
	k.box(Vector3(x + dw / 2, y, z - 0.02), Vector3(x + dw / 2 + 0.14, y + dh, z + 0.08), Color(TRIM))
	# полотно из досок
	for i in 4:
		var x0 := x - dw / 2 + i * dw / 4
		k.box(Vector3(x0 + 0.01, y, z - 0.04), Vector3(x0 + dw / 4 - 0.01, y + dh, z + 0.0), Color(WOOD).lightened(0.04 * (i % 2)))
	# полукруглая арка над дверью: камни-клинья
	var r0 := dw / 2
	var r1 := dw / 2 + 0.16
	var cy := y + dh
	for i in 7:
		var a0 := PI * i / 7.0
		var a1 := PI * (i + 1) / 7.0
		var p0 := Vector3(x + cos(a0) * r0, cy + sin(a0) * r0, z + 0.08)
		var p1 := Vector3(x + cos(a1) * r0, cy + sin(a1) * r0, z + 0.08)
		var q0 := Vector3(x + cos(a0) * r1, cy + sin(a0) * r1, z + 0.08)
		var q1 := Vector3(x + cos(a1) * r1, cy + sin(a1) * r1, z + 0.08)
		var col := Color(TRIM) if i % 2 == 0 else Color(TRIM).darkened(0.07)
		k.quad(p0, q0, q1, p1, col)
		# тёмная полукруглая фрамуга
		k.tri(Vector3(x, cy, z - 0.03), Vector3(x + cos(a0) * r0, cy + sin(a0) * r0, z - 0.03), Vector3(x + cos(a1) * r0, cy + sin(a1) * r0, z - 0.03), Color(GLASS))
	# фонарь у двери
	var lx := x + dw / 2 + 0.35
	k.box(Vector3(lx - 0.03, y + 1.75, z), Vector3(lx + 0.03, y + 1.8, z + 0.25), Color("2e2a26"))
	k.box(Vector3(lx - 0.08, y + 1.5, z + 0.17), Vector3(lx + 0.08, y + 1.75, z + 0.33), Color("f6c76a"))


## Лавка: широкий проём с прилавком и полосатый навес на шестах
func _shop(x: float, z: float, ww: float) -> void:
	var y := PLINTH
	k.box(Vector3(x - ww / 2, y, z - 0.25), Vector3(x + ww / 2, y + 1.9, z + 0.01), Color("2c2622"))
	k.box(Vector3(x - ww / 2 - 0.12, y, z - 0.02), Vector3(x - ww / 2, y + 2.0, z + 0.08), Color(TRIM))
	k.box(Vector3(x + ww / 2, y, z - 0.02), Vector3(x + ww / 2 + 0.12, y + 2.0, z + 0.08), Color(TRIM))
	k.box(Vector3(x - ww / 2 - 0.12, y + 1.9, z - 0.02), Vector3(x + ww / 2 + 0.12, y + 2.08, z + 0.1), Color(TRIM))
	# прилавок с товаром
	k.box(Vector3(x - ww / 2, y, z), Vector3(x + ww / 2, y + 0.85, z + 0.45), Color(WOOD))
	for i in int(ww / 0.3):
		var fx := x - ww / 2 + 0.18 + i * 0.3
		var fruit := Color(["e6a23c", "c43b2f", "7da63a", "e8d36a"][rng.randi() % 4])
		k.box(Vector3(fx - 0.12, y + 0.85, z + 0.05), Vector3(fx + 0.12, y + 0.95, z + 0.4), Color("a0784e"))
		for q in 3:
			k.blob(Vector3(fx + rng.randf_range(-0.07, 0.07), y + 1.0, z + 0.12 + q * 0.1), Vector3(0.05, 0.05, 0.05), fruit, rng.randi(), 0.15)
	# навес полосами
	var a := Color(["c9483b", "3f7f8a", "d9a33a"][rng.randi() % 3])
	var b := Color("f3ead8")
	var n := 7
	var x0 := x - ww / 2 - 0.25
	var x1 := x + ww / 2 + 0.25
	var yt := y + 2.35
	var yb := y + 1.9
	for i in n:
		var u0 := lerpf(x0, x1, float(i) / n)
		var u1 := lerpf(x0, x1, float(i + 1) / n)
		var col := a if i % 2 == 0 else b
		k.quad(Vector3(u0, yt, z + 0.02), Vector3(u0, yb, z + 1.0), Vector3(u1, yb, z + 1.0), Vector3(u1, yt, z + 0.02), col)
		k.quad(Vector3(u0, yb, z + 1.0), Vector3(u0, yb - 0.18, z + 1.02), Vector3(u1, yb - 0.18, z + 1.02), Vector3(u1, yb, z + 1.0), col.darkened(0.08))
	for s: float in [x0 + 0.05, x1 - 0.05]:
		k.rod(Vector3(s, 0, z + 1.0), Vector3(s, yb, z + 1.0), 0.035, 5, Color("5a3d26"))


func _balcony(w: float, y: float, z: float) -> void:
	var bw := minf(w * 0.7, 2.6)
	k.box(Vector3(-bw / 2, y - 0.12, z), Vector3(bw / 2, y + 0.04, z + 0.75), Color(STONE))
	# консоли под плитой
	for s: float in [-bw / 2 + 0.2, bw / 2 - 0.2]:
		k.box(Vector3(s - 0.07, y - 0.42, z), Vector3(s + 0.07, y - 0.12, z + 0.5), Color(STONE_DARK))
	# перила: стойки и поручень
	var ry := y + 0.9
	k.box(Vector3(-bw / 2, ry, z + 0.68), Vector3(bw / 2, ry + 0.06, z + 0.76), Color("3b302a"))
	for side: float in [-1.0, 1.0]:
		k.box(Vector3(side * bw / 2 - 0.04, ry, z), Vector3(side * bw / 2 + 0.04, ry + 0.06, z + 0.76), Color("3b302a"))
	var n := int(bw / 0.14)
	for i in n + 1:
		var bx := -bw / 2 + i * bw / n
		k.box(Vector3(bx - 0.015, y + 0.04, z + 0.7), Vector3(bx + 0.015, ry, z + 0.74), Color("3b302a"))
	# горшки с цветами
	for i in 2:
		var px := -bw / 2 + 0.3 + i * (bw - 0.6)
		k.cyl(Vector3(px, y + 0.04, z + 0.4), 0.13, 0.25, 7, Color("b5603a"), 0.16)
		k.blob(Vector3(px, y + 0.42, z + 0.4), Vector3(0.2, 0.2, 0.2), Color("5c8a3a"), rng.randi(), 0.25)
		for q in 3:
			k.blob(Vector3(px + rng.randf_range(-0.12, 0.12), y + 0.55, z + 0.4 + rng.randf_range(-0.1, 0.1)), Vector3(0.06, 0.05, 0.06), Color(FLOWERS[rng.randi() % FLOWERS.size()]), rng.randi(), 0.2)


## Черепичная крыша: скаты, ряды полукруглой черепицы от карниза к коньку, конёк, фронтоны или вальмы
func _roof(w: float, d: float, y: float, hip: bool) -> void:
	var ov := 0.35
	var rise := minf(w, d) * 0.3
	var x0 := -w / 2 - ov
	var x1 := w / 2 + ov
	var z0 := -d / 2 - ov
	var z1 := d / 2 + ov
	var ridge_y := y + rise + ov * rise / (d / 2)
	var base := Color(TILES[1]).darkened(0.12)
	var hx := (d / 2 + ov) if hip else 0.0      # насколько вальма срезает конёк с торцов
	var r0 := Vector3(x0 + hx, ridge_y, 0)
	var r1 := Vector3(x1 - hx, ridge_y, 0)
	# подложка скатов
	k.quad(Vector3(x0, y, z1), Vector3(x1, y, z1), r1, r0, base)
	k.quad(Vector3(x1, y, z0), Vector3(x0, y, z0), r0, r1, base)
	if hip:
		k.tri(Vector3(x0, y, z0), Vector3(x0, y, z1), r0, base)
		k.tri(Vector3(x1, y, z1), Vector3(x1, y, z0), r1, base)
	else:
		# фронтоны — стена дома
		var wc := Color(TRIM).darkened(0.03)
		k.tri(Vector3(-w / 2, y, -d / 2), Vector3(-w / 2, y, d / 2), Vector3(-w / 2, ridge_y - ov * 0.4, 0), wc)
		k.tri(Vector3(w / 2, y, d / 2), Vector3(w / 2, y, -d / 2), Vector3(w / 2, ridge_y - ov * 0.4, 0), wc)
	# нижняя сторона свеса (видна снизу)
	k.quad(Vector3(x0, y - 0.01, z0), Vector3(x1, y - 0.01, z0), Vector3(x1, y - 0.01, z1), Vector3(x0, y - 0.01, z1), Color(WOOD).darkened(0.2))
	# ряды черепицы на двух длинных скатах
	var step := 0.26
	var x := x0 + step * 0.5
	var row := 0
	while x < x1 - step * 0.3:
		var col := Color(TILES[(row * 7 + int(rng.randi() % 3)) % TILES.size()])
		var lim := 0.0
		if hip:
			lim = maxf(0.0, maxf(x0 + hx - x, x - (x1 - hx)))   # у вальмы ряд короче
		for s: float in [1.0, -1.0]:
			var e := Vector3(x, y + 0.02, s * z1)
			var t := Vector3(x, ridge_y + 0.02, 0.0)
			if lim > 0.0:
				var f := lim / (d / 2 + ov)
				t = e.lerp(t, 1.0 - f)
			var up := (t - e).cross(Vector3.RIGHT * s).normalized() * -1.0
			k.half_tube(e + up * 0.04, t + up * 0.04, 0.1, 4, col, up)
		x += step
		row += 1
	# вальмы — ряды поперёк
	if hip:
		for s: float in [-1.0, 1.0]:
			var ex := x0 if s < 0 else x1
			var zz := z0 + step * 0.5
			while zz < z1 - step * 0.3:
				var lim := absf(zz) / (d / 2 + ov)
				var e := Vector3(ex, y + 0.02, zz)
				var t := Vector3(ex - s * (d / 2 + ov), ridge_y + 0.02, zz).lerp(e, lim)
				var up := Vector3(-s * 0.6, 0.8, 0).normalized()
				k.half_tube(e + up * 0.04, t + up * 0.04, 0.1, 4, Color(TILES[int(absf(zz * 7)) % TILES.size()]), up)
				zz += step
	# конёк
	k.half_tube(r0 + Vector3(-0.1, 0.08, 0), r1 + Vector3(0.1, 0.08, 0), 0.15, 5, Color(TILES[2]).darkened(0.05))
	if hip:
		for s: float in [-1.0, 1.0]:
			var rr := r0 if s < 0 else r1
			for zc: float in [z0, z1]:
				k.half_tube(Vector3(x0 if s < 0 else x1, y + 0.06, zc), rr + Vector3(0, 0.08, 0), 0.12, 4, Color(TILES[2]).darkened(0.05))


## Плоская крыша-терраса: парапет, плитка, кадки с растениями, навес из жердей с лозой
func _terrace(w: float, d: float, y: float, wall: Color) -> void:
	# пол террасы — терракотовая плитка в шахматку
	var tile := 0.6
	var nx := int(ceil(w / tile))
	var nz := int(ceil(d / tile))
	for iz in nz:
		for ix in nx:
			var x0 := -w / 2 + ix * w / nx
			var z0 := -d / 2 + iz * d / nz
			var tc := Color("c98a62") if (ix + iz) % 2 == 0 else Color("b97a55")
			k.box(Vector3(x0, y + 0.08, z0), Vector3(x0 + w / nx - 0.02, y + 0.14, z0 + d / nz - 0.02), tc.lightened(rng.randf() * 0.06))
	k.box(Vector3(-w / 2, y + 0.08, -d / 2), Vector3(w / 2, y + 0.125, d / 2), Color("8a5a3e"))
	var ph := 0.55
	k.box(Vector3(-w / 2, y, d / 2 - 0.15), Vector3(w / 2, y + ph, d / 2), wall)
	k.box(Vector3(-w / 2, y, -d / 2), Vector3(w / 2, y + ph, -d / 2 + 0.15), wall)
	k.box(Vector3(-w / 2, y, -d / 2), Vector3(-w / 2 + 0.15, y + ph, d / 2), wall)
	k.box(Vector3(w / 2 - 0.15, y, -d / 2), Vector3(w / 2, y + ph, d / 2), wall)
	# кромка парапета — по периметру
	var cap := Color(TRIM)
	k.box(Vector3(-w / 2 - 0.04, y + ph, d / 2 - 0.19), Vector3(w / 2 + 0.04, y + ph + 0.07, d / 2 + 0.04), cap)
	k.box(Vector3(-w / 2 - 0.04, y + ph, -d / 2 - 0.04), Vector3(w / 2 + 0.04, y + ph + 0.07, -d / 2 + 0.19), cap)
	k.box(Vector3(-w / 2 - 0.04, y + ph, -d / 2 + 0.19), Vector3(-w / 2 + 0.19, y + ph + 0.07, d / 2 - 0.19), cap)
	k.box(Vector3(w / 2 - 0.19, y + ph, -d / 2 + 0.19), Vector3(w / 2 + 0.04, y + ph + 0.07, d / 2 - 0.19), cap)
	# кадки
	for i in 3:
		var px := rng.randf_range(-w / 2 + 0.5, w / 2 - 0.5)
		var pz := rng.randf_range(-d / 2 + 0.5, d / 2 - 0.5)
		k.cyl(Vector3(px, y + 0.06, pz), 0.2, 0.35, 8, Color("b5603a"), 0.24)
		if rng.randf() < 0.5:
			k.blob(Vector3(px, y + 1.0, pz), Vector3(0.18, 0.75, 0.18), Color("3f6b38"), rng.randi())   # кипарис в кадке
		else:
			k.blob(Vector3(px, y + 0.6, pz), Vector3(0.32, 0.28, 0.32), Color("5c8a3a"), rng.randi())
	# перголa
	if rng.randf() < 0.6:
		var gx0 := -w / 2 + 0.4
		var gx1 := gx0 + minf(2.2, w - 0.8)
		var gz0 := -d / 2 + 0.4
		var gz1 := gz0 + 1.6
		for px: float in [gx0, gx1]:
			for pz: float in [gz0, gz1]:
				k.rod(Vector3(px, y, pz), Vector3(px, y + 2.0, pz), 0.05, 5, Color("6e4b2f"))
		var bz := gz0
		while bz <= gz1 + 0.01:
			k.box(Vector3(gx0 - 0.15, y + 2.0, bz - 0.04), Vector3(gx1 + 0.15, y + 2.08, bz + 0.04), Color("6e4b2f"))
			bz += 0.32
		for q in 5:
			k.blob(Vector3(rng.randf_range(gx0, gx1), y + 2.12, rng.randf_range(gz0, gz1)), Vector3(0.45, 0.12, 0.35), Color("4f8a3a"), rng.randi(), 0.3)
