extends RefCounted
## Город строится в той же расстановке, что и витрина. Меняем только видимость.

const FIRST_STREET := Vector2(192, 108)
const MASK_STEP := Land.CELL * Land.SM

var buildings: Array[Dictionary] = []
var roads: Array[Array] = []
var growing: Array[Dictionary] = []
var surface: Image
var texture: ImageTexture
var building_index := 0
var road_index := 0
var restored := false


func prepare(game: Game) -> void:
	var land := game.land
	# Садовые улицы огибают пруд и соединяют площадь с берегом.
	_curve(land, Vector2(193.5, 150), Vector2(201, 156), Vector2(209, 159.3), 0.92)
	_curve(land, Vector2(213, 160.4), Vector2(206, 169), Vector2(201, 173), 0.85)
	_curve(land, Vector2(159, 171), Vector2(147, 177), Vector2(145.5, 186), 0.90)
	game._rebuild_land()
	surface = game.surf_img.duplicate()
	surface.clear_mipmaps()
	for y in range(215, 512):
		for x in range(245, 514):
			var color := surface.get_pixel(x, y)
			if color.r + color.g + color.b < 0.01 and color.a > 0.99:
				continue
			var p := Vector2(x + 0.5, y + 0.5) * MASK_STEP
			var t := _arrival(p) - 0.90
			if t > 0.0:
				roads.append([t, Vector2i(x, y), color])
				surface.set_pixel(x, y, Color(0, 0, 0, 1))
	roads.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	surface.generate_mipmaps()
	texture = ImageTexture.create_from_image(surface)
	game.land_mat.set_shader_parameter("surf", texture)
	for b: Dictionary in game.city.buildings.values():
		var id := int(b["id"])
		var display: Dictionary = game.visuals.get(id, {})
		if b["type"] == "center" or display.is_empty():
			continue
		var p: Vector2 = b["pos"]
		var t := _arrival(p) + 0.55 + float(id % 13) * 0.07
		var saved := game.parts.hide_handles(display["h"])
		var nodes: Array[Node3D] = []
		for n: Node3D in display["lights"] + display["smoke"] + display["actors"] + display.get("pets", []):
			if is_instance_valid(n) and n.visible:
				n.hide()
				nodes.append(n)
		buildings.append({
			"t": t, "origin": Vector3(p.x, float(b["y"]), p.y), "saved": saved, "nodes": nodes,
			"length": 0.64 + 0.17 * float(b["tier"]) + (0.35 if b["type"] in ["temple", "forum", "pantheon", "colosseum"] else 0.0),
		})
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	game.people.hide()


func _arrival(p: Vector2) -> float:
	var dx := absf(p.x - FIRST_STREET.x)
	var south := maxf(0.0, p.y - FIRST_STREET.y)
	return clampf(0.62 + 0.080 * south + 0.064 * dx + 0.28 * sin(p.y * 0.145 + p.x * 0.09), 0.30, 15.5)


func _curve(land: Land, a: Vector2, b: Vector2, c: Vector2, width: float) -> void:
	for i in 33:
		var u := float(i) / 32.0
		land.paint_circle(a.lerp(b, u).lerp(b.lerp(c, u), u), width, Land.Kind.DIRT, false, false, false, false)


func advance(t: float, game: Game) -> void:
	# По мере роста кварталов открываем пиксели исходной мостовой.
	if not restored and t >= 16.0:
		game.land_mat.set_shader_parameter("surf", game.surf_tex)
		restored = true
	elif road_index < roads.size() and t >= float(roads[road_index][0]):
		surface.clear_mipmaps()
		while road_index < roads.size() and t >= float(roads[road_index][0]):
			var p: Vector2i = roads[road_index][1]
			surface.set_pixelv(p, roads[road_index][2])
			road_index += 1
		surface.generate_mipmaps()
		texture.update(surface)

	while building_index < buildings.size() and t >= float(buildings[building_index]["t"]):
		var entry := buildings[building_index]
		game.parts.restore(entry["saved"])
		growing.append(entry)
		building_index += 1
	for i in range(growing.size() - 1, -1, -1):
		var entry := growing[i]
		var phase := clampf((t - float(entry["t"])) / float(entry["length"]), 0.0, 1.0)
		var amount := smoothstep(0.0, 1.0, phase)
		var origin: Vector3 = entry["origin"]
		var shape := Vector3(lerpf(0.72, 1.0, amount), maxf(amount, 0.002), lerpf(0.72, 1.0, amount))
		for saved: Array in entry["saved"]:
			for pose: Array in saved[2]:
				var mm: MultiMesh = pose[0]
				var xf: Transform3D = pose[1]
				xf.basis = xf.basis.scaled(shape)
				xf.origin = origin + (xf.origin - origin) * shape
				mm.set_instance_transform(int(saved[1]), xf)
		if phase >= 1.0:
			for node: Node3D in entry["nodes"]:
				if is_instance_valid(node):
					node.show()
			growing.remove_at(i)

	game.people.visible = t >= 5.0
	if t < 14.0:
		for resident: Dictionary in game.people._shown:
			var node: Node3D = resident.get("node")
			if is_instance_valid(node):
				node.visible = t >= _arrival(Vector2(node.position.x, node.position.z)) + 1.5
	elif t < 14.1:
		for resident: Dictionary in game.people._shown:
			var node: Node3D = resident.get("node")
			if is_instance_valid(node):
				node.show()


func finished() -> bool:
	return restored and building_index == buildings.size() and growing.is_empty()
