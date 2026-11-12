class_name CatDress
extends RefCounted
## Наполнение домов и лавок деталями Synty, как на картинках Synty (владелец 12.11: «всё на Synty, пересобрать…
## более детальными и живыми»): ящики цветов под окнами, цветущий плющ на глухих стенах, горшки с цветами у дверей,
## горшки на цепях над входом. Ставится после сборки облика по стенам Synty из чертежа (снаружи — от середины дома);
## землю не занимает (Bp.free_parts) — след и правила постановки прежние.

const WALL_W := 2.5            # стена Synty: 2,5 вдоль (x от 0), 3 в высоту, толщина по z
const BOXES := ["SM_Prop_FlowerBed_01", "SM_Prop_FlowerBed_02"]
## Окна стен Synty (сняты с картинки стен спереди): подоконник по высоте и окна [середина вдоль стены, ширина]
const WIN := {"SM_Bld_Wall_Window_01": [0.65, [[1.25, 1.2]]], "SM_Bld_Wall_Window_02": [1.4, [[0.55, 0.42], [1.25, 0.42], [1.95, 0.42]]],
	"SM_Bld_Wall_Window_03": [1.4, [[1.25, 0.42]]], "SM_Bld_Wall_Window_04": [1.4, [[1.25, 1.75]]], "SM_Bld_Wall_Window_05": [0.65, [[1.25, 1.2]]]}
## Двери: [начало и конец проёма вдоль стены, верх проёма]
const DOOR := {"SM_Bld_Wall_Door_01": [0.75, 1.75, 1.97], "SM_Bld_Wall_Door_04": [0.75, 1.75, 1.97], "SM_Bld_Wall_Door_Double_01": [0.25, 2.25, 1.97],
	"SM_Bld_Wall_Door_Double_03": [0.25, 2.25, 1.97], "SM_Bld_Wall_Door_Large_01": [0.7, 1.8, 2.47], "SM_Bld_Wall_Door_Double_Large_01": [0.3, 2.2, 2.47]}
const IVY := ["SM_Env_Ivy_Flowers_01", "SM_Env_Ivy_Flowers_02", "SM_Env_Ivy_Flowers_03", "SM_Env_Ivy_Flowers_04", "SM_Env_Ivy_Flowers_05"]
## Клетки signs.png (как SIGNS в deploy/kit/kit_houses.py): 6 столбцов × 7 рядов
const SIGNS := ["meat", "bread", "shoes", "dye", "togas", "pots", "oil", "lamps", "wine", "perfume", "jewel", "cloth", "barber", "medic",
	"thermo", "taberna", "fullonica", "mansio", "fruit", "veg", "fish", "fresco", "copper", "grain", "scriptorium", "school", "library",
	"academy", "warehouse", "vigiles", "herbalist", "sculptor", "catshop", "shelter", "balnea", "baths", "prefect", "arch_ins", "relief",
	"puppets", "mimes", "dice"]
## Вывеска над дверью лавки и общественного здания (рисунки Codex)
const TRADE_SIGN := {"butcher": "meat", "bakery": "bread", "cobbler": "shoes", "dyer": "dye", "tailor": "togas", "potter": "pots",
	"oilshop": "oil", "lamps": "lamps", "wineshop": "wine", "perfumer": "perfume", "jeweler": "jewel", "weaver": "cloth", "barber": "barber",
	"medic": "medic", "thermopolium": "thermo", "taberna": "taberna", "fullonica": "fullonica", "mansio": "mansio", "scriptorium": "scriptorium",
	"herbalist": "herbalist", "sculptor": "sculptor", "catshop": "catshop", "shelter": "shelter", "balnea": "balnea", "baths": "baths",
	"prefect": "prefect", "school": "school", "library": "library", "academy": "academy", "warehouse": "warehouse", "vigiles": "vigiles"}
## Товар у входа лавки — вещицы, что жители носят в руках (HandProps): окорока у мясника, сандалии у сапожника, бусы у ювелира
const TRADE_GOODS := {"butcher": "ham", "cobbler": "sandals", "jeweler": "necklace", "wineshop": "grapes"}
const HANG := ["SM_Prop_FlowerPot_Hanging_01", "SM_Prop_FlowerPot_Hanging_02", "SM_Prop_FlowerPot_Hanging_03", "SM_Prop_FlowerPot_Hanging_04"]


static func dress(b: Bp, type: String) -> void:
	var walls := []
	var sum := Vector3.ZERO
	for p in b.parts:
		var nm := String(p[0])
		if not nm.begins_with("SM_Bld_Wall_") or nm.contains("Tiny") or nm.contains("Balcony") or nm.contains("Trim") or nm.contains("Pillar"):
			continue
		var xf: Transform3D = p[1]
		var c := xf * Bp.model_aabb(nm).get_center()
		walls.append([nm, xf, c])
		sum += c
	if walls.size() < 2:
		return
	var mid := sum / walls.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([type, b.parts.size(), walls.size(), int(mid.x * 100.0), int(mid.z * 100.0)])
	var shop := not type.begins_with("house_")
	var ivy_left := 2 if rng.randf() < 0.5 else 1
	var signed := false
	for w: Array in walls:
		var nm: String = w[0]
		var xf: Transform3D = w[1]
		var c: Vector3 = w[2]
		var along := xf.basis.x.normalized()
		var n := xf.basis.z.normalized()
		var sx := xf.basis.x.length()
		var sy := xf.basis.y.length()
		var out := n if (c - mid).dot(n) > 0.0 else -n
		out.y = 0.0
		if out.length() < 0.5:
			continue
		out = out.normalized()
		var yaw := atan2(out.x, out.z)
		var o := xf.origin
		var ground := o.y < 1.0
		var face := 0.115 * xf.basis.z.length()          # от середины толщины стены — до её лица
		var at := func(u: float, v: float, d: float) -> Vector3: return o + along * u * sx + Vector3.UP * v * sy + out * (d + face)
		if nm.contains("Window"):
			# ящики цветов ровно под окнами (у круглых отдушин — нет)
			if WIN.has(nm) and rng.randf() < (0.5 if shop else 0.8):
				var wd: Array = WIN[nm]
				var bx: String = BOXES[rng.randi() % BOXES.size()]
				for e: Array in wd[1]:
					_put(b, bx, at.call(float(e[0]), float(wd[0]) - 0.14, 0.12), yaw, Vector3(float(e[1]) * sx / 1.57 * 1.05, 0.4, 0.34))
		elif nm.contains("Door"):
			if shop:
				if out.z > 0.6 and not signed and TRADE_SIGN.has(type):
					signed = true
					# вывеска над дверью, по бокам — товар на крюках
					var dt: Array = DOOR.get(nm, [0.75, 1.75, 1.97])
					var sy0 := minf(float(dt[2]) + 0.45, 2.6)
					_put(b, "#sign:" + String(TRADE_SIGN[type]), at.call((float(dt[0]) + float(dt[1])) * 0.5, sy0, 0.03), yaw, Vector3(1.05, 1.05, 1.0))
					if TRADE_GOODS.has(type):
						for k in 3:
							_put(b, "#hp_" + String(TRADE_GOODS[type]), at.call(WALL_W * 0.5 - 0.75 + k * 0.75, 2.05, 0.2), yaw + rng.randf_range(-0.3, 0.3), Vector3.ONE * 0.75)
				continue
			var dd: Array = DOOR.get(nm, [0.75, 1.75, 1.97])
			if rng.randf() < 0.8 and float(dd[0]) > 0.5:
				for side: float in [float(dd[0]) - 0.3, float(dd[1]) + 0.3]:
					if rng.randf() < 0.8:
						var p0: Vector3 = at.call(side, 0.0, 0.32)
						_put(b, "SM_Prop_Vase_03", p0, rng.randf() * TAU, Vector3.ONE * 0.62)
						_put(b, CatDecor.BLOOMS[rng.randi() % CatDecor.BLOOMS.size()], p0 + Vector3(0, 0.36, 0), rng.randf() * TAU, Vector3.ONE * 0.22,
							{"tint": CatDecor.TRUE_COLOR})
			if rng.randf() < 0.55:
				_put(b, HANG[rng.randi() % HANG.size()], at.call(WALL_W - 0.3 if rng.randf() < 0.5 else 0.3, 2.45, 0.3), yaw, Vector3.ONE * 0.42)
		elif ivy_left > 0 and rng.randf() < 0.6:
			ivy_left -= 1
			_put(b, IVY[rng.randi() % IVY.size()], at.call(WALL_W * (0.3 if rng.randf() < 0.5 else 0.7), 0.95, 0.02), yaw, Vector3(0.9, 1.15, 1.0))


static func _put(b: Bp, nm: String, p: Vector3, yaw: float, s: Vector3, remap := {}) -> void:
	b.free_parts[b.parts.size()] = true
	b.parts.append([nm, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), remap])


## Вывеска: доска из тёмного дерева, на лицевой стороне — клетка signs.png; 1 × 0,67 (единицы чертежа)
static var _sign_tex: Texture2D
static func sign_mesh(key: String) -> Mesh:
	var i := maxi(0, SIGNS.find(key))
	var cx := i % 6
	var cy := i / 6
	var am := ArrayMesh.new()
	var k := Kit.new()
	k.boxc(Vector3(0, 0, 0.0), Vector3(1.08, 0.74, 0.05), Color("5a3a22"), [])
	var wood := k.mesh()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wood.surface_get_arrays(0))
	am.surface_set_material(0, Kit.material(0.85))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := cx / 6.0 + 0.002
	var u1 := (cx + 1) / 6.0 - 0.002
	var v0 := cy / 7.0 + 0.002
	var v1 := (cy + 1) / 7.0 - 0.002
	var w := 0.5
	var h := 0.335
	var z := 0.027
	st.set_normal(Vector3(0, 0, 1))
	for q: Array in [[Vector3(-w, -h, z), Vector2(u0, v1)], [Vector3(w, -h, z), Vector2(u1, v1)], [Vector3(w, h, z), Vector2(u1, v0)],
			[Vector3(-w, -h, z), Vector2(u0, v1)], [Vector3(w, h, z), Vector2(u1, v0)], [Vector3(-w, h, z), Vector2(u0, v0)]]:
		st.set_uv(q[1])
		st.add_vertex(q[0])
	st.commit(am)
	var m := StandardMaterial3D.new()
	if _sign_tex == null:
		_sign_tex = load("res://assets/kit/tex/signs.png")
	m.albedo_texture = _sign_tex
	m.roughness = 0.8
	am.surface_set_material(1, m)
	return am
