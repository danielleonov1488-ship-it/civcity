extends SceneTree
## Нутро чертежа: какие «#dark/#lit/#room/#plate» стоят у типа (аргументы после «--»: типы через запятую)
func _init() -> void:
	var ua := OS.get_cmdline_user_args()
	var types: PackedStringArray = ua[0].split(",") if ua.size() > 0 else PackedStringArray(["taberna"])
	for t in types:
		var bp: Bp = Catalog.make(t, 1, 0, 0)
		for p in bp.parts:
			var nm: String = p[0]
			if nm.begins_with("#dark") or nm.begins_with("#lit") or nm.begins_with("#room") or nm.begins_with("#plate"):
				var xf: Transform3D = p[1]
				print("PART ", t, " ", nm, " size ", snapped(Vector3(xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length()), Vector3(0.01, 0.01, 0.01)), " at ", snapped(xf.origin, Vector3(0.01, 0.01, 0.01)))
	quit()
