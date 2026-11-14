extends SceneTree
## Здания Легиона (NewMilitary): след в осях постройки (м) на каждом уровне облика, вход, высота, сколько деталей,
## огней и людей при деле; проверка правила test_legion — облик уровня только прибавляет (детали 1-го уровня на месте,
## новые низкие — внутри следа 1-го уровня). Без окна.
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_mil_probe.gd -- [types=barracks,forge] [new=0] [tiers=0,5]
## Печатает «MIL LOT …», «MIL GROW …» и в конце «MIL PROBE DONE fails=N».

func _init() -> void:
	var types: Array = Legion.BUILDING_IDS.duplicate()
	var tiers := [0, 2, 5]
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"types": types = Array(kv[1].split(","))
			"new":
				if kv[1] == "0":
					for t: String in NewMilitary.ON:
						NewMilitary.ON[t] = false
			"tiers":
				tiers = []
				for s in kv[1].split(","):
					tiers.append(int(s))
	var fails := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("aabb="):
			# габариты деталей (родные метры): начало и размер — для подбора мест
			for nm: String in a.trim_prefix("aabb=").split(","):
				var bx := Bp.model_aabb(nm)
				print("MIL AABB %-36s pos (%.2f, %.2f, %.2f) size (%.2f, %.2f, %.2f)" % [nm, bx.position.x, bx.position.y, bx.position.z, bx.size.x, bx.size.y, bx.size.z])
			types = []
	for t: String in types:
		for tier: int in tiers:
			var b := Catalog.make(t, tier, 0, 0)
			var lot := Rect2()
			var first := true
			for r: Rect2 in b.footprint():
				lot = r if first else lot.merge(r)
				first = false
			print("MIL LOT %-10s t%d x %.2f .. %.2f  z %.2f .. %.2f  (%.2f x %.2f = %.1f m2)  top %.2f  door (%.2f, %.2f)  front %.2f  parts %d  lights %d  actors %d  smoke %d" % [t, tier,
				lot.position.x, lot.end.x, lot.position.y, lot.end.y, lot.size.x, lot.size.y, lot.get_area(), b.top_y(), b.door.x, b.door.z, b.row_front(),
				b.parts.size(), b.lights.size(), b.actors.size(), b.smoke.size()])
		# правило роста (как test_legion mode=api): детали 1-го уровня остаются, новые низкие — внутри следа 1-го уровня
		var b0 := Catalog.make(t, 0, 0, 0)
		var rects := []
		for r: Rect2 in b0.footprint():
			rects.append(r.grow(0.3))
		var had := {}
		for pp: Array in b0.parts:
			had[[pp[0], (pp[1] as Transform3D).origin.snapped(Vector3.ONE * 0.05)]] = true
		var out := []
		for tier in range(1, Legion.VIS_MAX + 1):
			var bt := Catalog.make(t, tier, 0, 0)
			if bt.parts.size() <= b0.parts.size():
				out.append("t%d ничего не прибавилось" % tier)
			var now := {}
			for pp: Array in bt.parts:
				now[[pp[0], (pp[1] as Transform3D).origin.snapped(Vector3.ONE * 0.05)]] = true
			var lost := 0
			for k in had:
				if not now.has(k):
					lost += 1
			if lost > 0:
				out.append("t%d пропало деталей 1-го уровня: %d" % [tier, lost])
			for i in range(bt.parts.size()):
				if had.has([bt.parts[i][0], (bt.parts[i][1] as Transform3D).origin.snapped(Vector3.ONE * 0.05)]):
					continue
				var o: Vector3 = (bt.parts[i][1] as Transform3D).origin
				if o.y < 1.6 and not rects.any(func(r: Rect2) -> bool: return r.has_point(Vector2(o.x, o.z))):
					out.append("t%d %s вне следа (%.1f, %.1f)" % [tier, bt.parts[i][0], o.x, o.z])
			print("MIL GROW %-10s t%d +%d деталей" % [t, tier, bt.parts.size() - b0.parts.size()])
		if not out.is_empty():
			fails += 1
			print("MIL FAIL %s: %s" % [t, str(out.slice(0, 8))])
	print("MIL PROBE DONE fails=%d" % fails)
	quit()
