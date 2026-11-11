extends Node
## Карточки «было / стало» (владелец 11.11: «по каждому — как было раньше с моделями Синти, как сейчас»):
## для каждого типа — общий вид и крупный план витрины, прежняя модель (KitHouses.ON = false) и своя, с одной камеры.
##   bash .work/py/gpu_run.sh res://test_cards.tscn -- types=butcher,bakery out=D:/CivCity/.work/kit/cards/raw
## Пишет <out>/<тип>_{old,new}_{full,close}.png (склейку с подписями делает .work/kit/cards.py)

const SIZE := Vector2i(1100, 820)


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var out := String(args.get("out", "D:/CivCity/.work/kit/cards/raw"))
	DirAccess.make_dir_recursive_absolute(out)
	var yaw := deg_to_rad(float(args.get("yaw", "28")))
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("cfdde6")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("e6dccb")
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("b9ab8c")
	ground.material_override = gm
	vp.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	for spec: String in String(args.get("types", "butcher")).split(","):
		var type := spec.get_slice(":", 0)       # «center:4» — тип и уровень (станция растёт)
		if not Defs.B.has(type):
			print("CARDS unknown ", type)
			continue
		var d: Dictionary = Defs.B[type]
		var tier := int(spec.get_slice(":", 1)) if spec.contains(":") else (2 if d["kind"] == "house" else 0)
		var gs := {}
		var boxes := {}
		for k in ["old", "new"]:
			KitHouses.ON = k == "new"
			Catalog._cache.clear()
			var bp := Catalog.make(type, tier, 0, 3)
			var g := Parts.ghost(bp, "outline", Color(0, 0, 0, 0))
			for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
				gi.material_override = null
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			Hud.add_pets(g, type)              # кошки, ослик, вещицы витрины — как в игре
			g.visible = false
			vp.add_child(g)
			gs[k] = g
			boxes[k] = Artisau.aabb(g)
		KitHouses.ON = true
		var rad := maxf(boxes["old"].size.length(), boxes["new"].size.length()) * 0.5
		var dir := Vector3(sin(yaw) * 0.8, 0.62, cos(yaw) * 0.8).normalized()
		for k in ["old", "new"]:
			var g: Node3D = gs[k]
			g.visible = true
			var box: AABB = boxes[k]
			var c := Vector3(0, box.size.y * 0.42, (box.position.z + box.end.z) * 0.5)
			cam.look_at_from_position(c + dir * rad / sin(deg_to_rad(15.0)) * 0.92, c, Vector3.UP)
			await _shot(vp, "%s/%s_%s_full.png" % [out, spec.replace(":", "_"), k])
			# крупно: витрина у земли (перед — +z)
			var front := minf(box.end.z, (boxes["new"] as AABB).end.z) - 0.55
			var tc := Vector3(0.0, 0.95, front)
			var cd := Vector3(0.4, 0.34, 1.0).normalized()
			cam.look_at_from_position(tc + cd * (3.6 if type.begins_with("stall_") else 5.2), tc, Vector3.UP)
			await _shot(vp, "%s/%s_%s_close.png" % [out, spec.replace(":", "_"), k])
			g.visible = false
		for k in gs:
			gs[k].queue_free()
		await get_tree().process_frame
		print("CARDS ", type)
	get_tree().quit()


func _shot(vp: SubViewport, path: String) -> void:
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
