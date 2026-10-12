class_name Entrance
extends RefCounted
## Въезд в город: большая дорога приходит с севера из-за горизонта, а на границе своей земли (Land.GATE)
## над ней стоит небольшая римская арка — каменный проём с карнизом и аттиком, по бокам две колонны
## с огненными чашами, фонари на опорах (ночью горят), цветы в вазонах, плющ и кипарисы.
## Чертёж строится в родных размерах Synty и уменьшается до «кукольного» масштаба (Catalog.ARCH).

const SX := 3.0                      # проём: деталь стены с аркой шириной 2,5 м растянута втрое
const SY := 1.85
const HALF := 1.25 * SX              # полуширина арки (родные метры)
const COL_X := HALF + 0.95           # колонны по бокам


## Чертёж арки: середина — на оси дороги, лицом (+Z) к городу
static func gate_bp() -> Bp:
	var b := Bp.new(64)
	var top := 3.01 * SY
	# проём: лицевая и обратная стороны, между ними — толща опор и свода
	for face: float in [1.0, -1.0]:
		var yaw := 0.0 if face > 0 else PI
		b.add_xf("SM_Bld_Wall_Door_Double_01", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(SX, SY, 1.0)), Vector3(-HALF * face, 0, 0.42 * face)))
	for sd: float in [-1.0, 1.0]:
		CatMonuments._box(b, "#marble", Vector3(sd * (HALF - 0.45), top / 2.0, 0), Vector3(0.86, top, 0.9))
	CatMonuments._box(b, "#marble", Vector3(0, top - 0.75, 0), Vector3(2 * HALF - 0.3, 1.5, 0.9))
	# карниз, аттик с медальонами, верхний карниз
	b.add_xf("SM_Bld_Wall_Large_Cap_01", Transform3D(Basis.from_scale(Vector3((2 * HALF + 0.5) / 5.02, 1.0, 1.5)), Vector3(-HALF - 0.25, top + 0.05, 0)))
	var ah := 0.85
	var ay := top + 0.36
	CatMonuments._box(b, "#marble", Vector3(0, ay + ah / 2.0, 0), Vector3(2 * HALF - 1.2, ah, 1.0))
	b.add_xf("SM_Bld_Wall_Large_Cap_01", Transform3D(Basis.from_scale(Vector3((2 * HALF - 0.9) / 5.02, 0.8, 1.25)), Vector3(-HALF + 0.45, ay + ah + 0.04, 0)))
	for face: float in [1.0, -1.0]:
		var yaw := 0.0 if face > 0 else PI
		b.add("SM_Bld_Ornament_02", Vector3(0, ay + ah / 2.0, 0.52 * face), yaw, 0.95)
		for sd: float in [-1.0, 1.0]:
			b.add("SM_Bld_Ornament_09", Vector3(sd * 1.6, ay + ah / 2.0 - 0.1, 0.52 * face), yaw, 0.8)
	# на аттике — бронзовая квадрига не по карману: две вазы и лавровый венок-медальон уже есть
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Prop_Vase_03", Vector3(sd * (HALF - 0.95), ay + ah + 0.32, 0), 0.0, 0.9)
	# фонари на опорах с обеих сторон (ночью горят)
	for face: float in [1.0, -1.0]:
		var yaw := 0.0 if face > 0 else PI
		for sd: float in [-1.0, 1.0]:
			var p := Vector3(sd * (HALF - 0.45), 2.75, 0.62 * face)
			b.add("#wall_lamp", p, yaw, 1.15)
			b.light(p + Basis(Vector3.UP, yaw) * Vector3(0, -0.25, 0.48))
	# колонны на пьедесталах с огненными чашами, плющ, вазоны и кипарисы
	for sd: float in [-1.0, 1.0]:
		var x := sd * COL_X
		b.add("SM_Prop_Pillar_Base_01", Vector3(x, 0, 0), 0.0, 1.0)
		b.add_xf("SM_Bld_Pillar_02", Transform3D(Basis.from_scale(Vector3(0.95, 1.12, 0.95)), Vector3(x, 1.0, 0)))
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 if sd < 0 else 2), Vector3(x, 1.0, 0), sd, 0.95)
		var ch := 1.0 + 3.0 * 1.12
		b.add("SM_Prop_Pillar_Top_01", Vector3(x, ch, 0), 0.0, 1.0)
		var bh := ch + 0.25
		b.add("SM_Prop_Brazier_04", Vector3(x, bh, 0), 0.0, 0.75)
		b.add("SM_Prop_Brazier_04_Insert_01", Vector3(x, bh, 0), 0.0, 0.75)
		CatDecor._fire(b, Vector3(x, bh + 0.25, 0), 0.16, 6, 0.13, 0.08)
		CatDecor._flame(b, Vector3(x + 0.05, bh + 0.32, 0.03), 0.16)
		CatDecor._flame(b, Vector3(x - 0.09, bh + 0.3, -0.06), 0.11)
		b.light(Vector3(x, bh + 0.7, 0))
		for face: float in [1.0, -1.0]:
			CatMonuments._pot(b, Vector3(x + sd * 0.15, 0, 0.95 * face), 0.62)
		CatMonuments._cypress(b, Vector3(sd * (COL_X + 1.5), 0, -0.6), 0.75)
		b.add("SM_Env_Bush_Cluster_0%d" % (2 + (1 if sd > 0 else 0)), Vector3(sd * (COL_X + 1.7), 0, 0.7), sd * 2.0, 0.42)
	# свисающий плющ с карниза
	for sd: float in [-1.0, 1.0]:
		b.add("SM_Env_Ivy_Draped_Flowers_0%d" % (2 if sd < 0 else 1), Vector3(sd * (HALF - 0.9), top + 0.05, 0.62), 0.0, 1.0)
	Catalog._scale(b, Catalog.ARCH)
	return b


## Где арка занимает землю (опоры, колонны, вазоны с обеих сторон, кусты и кипарисы), в осях арки, в метрах мира
static func solid_rects() -> Array:
	var s := Catalog.ARCH
	var out := []
	for sd: float in [-1.0, 1.0]:
		var x0 := (HALF - 0.9) * s
		var x1 := (COL_X + 0.5) * s
		out.append(Rect2(minf(sd * x0, sd * x1), -0.55 * s, absf(x1 - x0), 1.1 * s))
		# вазоны (z ±0.95), кипарис и куст за колонной — тоже не место для дома
		var x2 := (COL_X - 0.45) * s
		var x3 := (COL_X + 2.25) * s
		out.append(Rect2(minf(sd * x2, sd * x3), -1.3 * s, absf(x3 - x2), 2.6 * s))
	return out
