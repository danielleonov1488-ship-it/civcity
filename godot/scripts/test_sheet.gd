extends Control
## Лист обликов (для работы над украшениями и постройками): каждый тип — крупно в своём окошке, под ним название.
##   bash .work/py/gpu_run.sh res://test_sheet.tscn -- types=a,b,c cols=4 out=D:/CivCity/.work/gd/b/sheet.png [yaw=35] [fp=1]
## types — список типов Defs.B (или «set:<исследование>» — все облики, что оно открывает; «tier»/«variant» — тип:этаж:фасад)

var CELL := Vector2i(384, 300)


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var list: Array = []
	for t: String in String(args.get("types", "bench")).split(","):
		if t.begins_with("set:"):
			for k in Defs.B:
				if String(Defs.B[k].get("unlock", "")) == t.substr(4) or String(Defs.DECOR_LATER.get(k, "")) == t.substr(4):
					list.append(k)
		else:
			list.append(t)
	if args.has("cell"):
		CELL = Vector2i(int(String(args["cell"]).get_slice("x", 0)), int(String(args["cell"]).get_slice("x", 1)))   # окошко побольше (большие памятники)
	var cols := int(args.get("cols", "4"))
	var yaw := deg_to_rad(float(args.get("yaw", "32")))
	var out := String(args.get("out", "D:/CivCity/.work/gd/b/sheet.png"))
	var vp := SubViewport.new()
	vp.size = CELL
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("d9e4d0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("e6dccb")
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("9cb35c")
	ground.material_override = gm
	vp.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var imgs := []
	for item: String in list:
		var p := item.split(":")
		var type := p[0]
		var d: Dictionary = {}
		var bp: Bp
		if type == "m":
			# голая модель Synty: m:Имя
			bp = Bp.new(1)
			bp.parts.append([p[1], Transform3D.IDENTITY, {}])
			type = p[1]
		elif not Defs.B.has(type):
			print("SHEET unknown ", type)
			continue
		else:
			d = Defs.B[type]
			bp = Catalog.make(type, int(p[1]) if p.size() > 1 else (2 if d["kind"] == "house" else 0), int(p[2]) if p.size() > 2 else 0, 3)
		var g := Parts.ghost(bp, "outline", Color(0, 0, 0, 0))
		for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
			gi.material_override = null
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if bool(d.get("wall", false)) or (d.is_empty() and (type.contains("Mural") or type.contains("Symbol") or type.contains("Numeral"))):
			# настенное — на кусок стены
			var wall := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(3.2, 3.2, 0.2)
			wall.mesh = bm
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color("e9c98f")
			wall.material_override = wm
			wall.position = Vector3(0, 0.0, -0.1)
			g.add_child(wall)
			g.position.y = 1.6
		if not d.is_empty():
			Hud.add_pets(g, type)
		vp.add_child(g)
		if args.has("fp"):
			for r: Rect2 in bp.footprint():
				var m := MeshInstance3D.new()
				var b2 := BoxMesh.new()
				b2.size = Vector3(r.size.x, 0.02, r.size.y)
				m.mesh = b2
				var mm := StandardMaterial3D.new()
				mm.albedo_color = Color(1, 0, 0, 0.35)
				mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.material_override = mm
				m.position = Vector3(r.get_center().x, 0.02, r.get_center().y)
				vp.add_child(m)
		var box := Artisau.aabb(g)
		box.position += g.position
		var c := box.get_center()
		var rad := maxf(0.6, box.size.length() * 0.5)
		var dir := Vector3(sin(yaw) * 0.8, 0.62, cos(yaw) * 0.8).normalized()
		cam.look_at_from_position(c + dir * rad / sin(deg_to_rad(15.0)) * 1.0, c, Vector3.UP)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		imgs.append([type, img, box.size])
		g.queue_free()
		for ch in vp.get_children():
			if ch is MeshInstance3D and ch != ground:
				ch.queue_free()
		await get_tree().process_frame
	# лист: окошки рядами, под каждым — название и размер
	var rows := int(ceil(imgs.size() / float(cols)))
	var sheet := Image.create(cols * CELL.x, rows * (CELL.y + 26), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("f3ead8"))
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)
	for k in imgs.size():
		var e2: Array = imgs[k]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(e2[1])
		tr.custom_minimum_size = Vector2(CELL) * 0.98
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(tr)
		var l := Label.new()
		var sz: Vector3 = e2[2]
		l.text = "%s · %s · %.1f×%.1f×%.1f" % [e2[0], Defs.B[e2[0]]["name"] if Defs.B.has(e2[0]) else "", sz.x, sz.y, sz.z]
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color("3a2412"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(CELL.x, 24)
		v.add_child(l)
		grid.add_child(v)
	vp.queue_free()
	await get_tree().process_frame
	var need := Vector2i(cols * CELL.x, rows * (CELL.y + 24))
	get_window().size = need
	get_window().content_scale_size = need
	for i in 6:
		await get_tree().process_frame
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(out)
	print("SHEET ", out, " items=", imgs.size())
	get_tree().quit()
