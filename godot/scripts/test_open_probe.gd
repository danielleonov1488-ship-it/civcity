extends SceneTree
## Отладка чертежа: «-- aabb имена» — габариты моделей; «-- parts тип подстрока» — детали чертежа типа, чьё имя содержит подстроку, с их габаритами
func _init() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 1 and ua[0] == "parts":
		var bp: Bp = Catalog.make(ua[1], 1, 0, 0)
		for p in bp.parts:
			var nm: String = p[0]
			if ua.size() > 2 and not nm.contains(ua[2]):
				continue
			var xf: Transform3D = p[1]
			var bb: AABB = xf * Bp.model_aabb(nm)
			print("PART ", nm, " x ", snapped(bb.position.x, 0.01), "..", snapped(bb.end.x, 0.01), " y ", snapped(bb.position.y, 0.01), "..", snapped(bb.end.y, 0.01), " z ", snapped(bb.position.z, 0.01), "..", snapped(bb.end.z, 0.01))
		quit()
		return
	var names: PackedStringArray = ua[0].split(",") if ua.size() > 0 else PackedStringArray()
	for n in names:
		var b := Bp.model_aabb(n)
		print("AABB ", n, " pos ", snapped(b.position, Vector3(0.01, 0.01, 0.01)), " size ", snapped(b.size, Vector3(0.01, 0.01, 0.01)))
	quit()
