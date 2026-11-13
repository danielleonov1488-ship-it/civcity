extends SceneTree
## Проба библиотеки движений Quaternius UAL2: имена, длины, кости (сверка с UAL1 — тот же скелет после BoneMap).
##   bash .work/py/gpu_run.sh --headless --script res://scripts/test_ual2_probe.gd


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path: String in ["res://assets/people/UAL1_Standard.glb", "res://assets/people/UAL2_Standard.glb"]:
		var src := (load(path) as PackedScene).instantiate()
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
		print("UAL %s: skeleton %s bones %d, anims %d, player root %s" % [path.get_file(), sk.name, sk.get_bone_count(), ap.get_animation_list().size(), ap.root_node])
		var bones := []
		for i in sk.get_bone_count():
			bones.append(sk.get_bone_name(i))
		print("UAL bones ", ", ".join(bones))
		for n in ap.get_animation_list():
			var a := ap.get_animation(n)
			var paths := {}
			for t in a.get_track_count():
				paths[String(a.track_get_path(t)).get_slice(":", 0)] = true
			if path.contains("UAL2"):
				print("UAL anim %-40s %.2f s  tracks %d  nodes %s" % [n, a.length, a.get_track_count(), paths.keys()])
		src.free()
	quit()
