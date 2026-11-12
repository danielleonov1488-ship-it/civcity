class_name CatDress
extends RefCounted
## Наполнение домов и лавок деталями Synty, как на картинках Synty (владелец 12.11: «всё на Synty, пересобрать…
## более детальными и живыми»): ящики цветов под окнами, цветущий плющ на глухих стенах, горшки с цветами у дверей,
## горшки на цепях над входом. Ставится после сборки облика по стенам Synty из чертежа (снаружи — от середины дома);
## землю не занимает (Bp.free_parts) — след и правила постановки прежние.

const WALL_W := 2.5            # стена Synty: 2,5 вдоль (x от 0), 3 в высоту, толщина по z
const BOXES := ["SM_Prop_FlowerBed_01", "SM_Prop_FlowerBed_02"]
const IVY := ["SM_Env_Ivy_Flowers_01", "SM_Env_Ivy_Flowers_02", "SM_Env_Ivy_Flowers_03", "SM_Env_Ivy_Flowers_04", "SM_Env_Ivy_Flowers_05"]
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
		var at := func(u: float, v: float, d: float) -> Vector3: return o + along * u * sx + Vector3.UP * v * sy + out * d
		if nm.contains("Window"):
			if rng.randf() < (0.5 if shop else 0.78):
				_put(b, BOXES[rng.randi() % BOXES.size()], at.call(WALL_W * 0.5, 1.05, 0.2), yaw, Vector3(0.42 * sx, 0.42, 0.36))
		elif nm.contains("Door"):
			if shop:
				continue
			if rng.randf() < 0.75:
				for side: float in [0.18, WALL_W - 0.18]:
					if rng.randf() < 0.8:
						var p0: Vector3 = at.call(side, 0.0, 0.32)
						_put(b, "SM_Prop_Vase_03", p0, rng.randf() * TAU, Vector3.ONE * 0.62)
						_put(b, CatDecor.BLOOMS[rng.randi() % CatDecor.BLOOMS.size()], p0 + Vector3(0, 0.36, 0), rng.randf() * TAU, Vector3.ONE * 0.22,
							{"tint": CatDecor.TRUE_COLOR})
			if rng.randf() < 0.55:
				_put(b, HANG[rng.randi() % HANG.size()], at.call(WALL_W - 0.3 if rng.randf() < 0.5 else 0.3, 2.45, 0.3), yaw, Vector3.ONE * 0.42)
		elif ivy_left > 0 and rng.randf() < 0.6:
			ivy_left -= 1
			_put(b, IVY[rng.randi() % IVY.size()], at.call(WALL_W * (0.3 if rng.randf() < 0.5 else 0.7), 0.95, 0.04), yaw, Vector3(0.9, 1.15, 1.0))


static func _put(b: Bp, nm: String, p: Vector3, yaw: float, s: Vector3, remap := {}) -> void:
	b.free_parts[b.parts.size()] = true
	b.parts.append([nm, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(s), p), remap])
