extends SceneTree
## SWIRL-4: sonar should reveal hazards, not cover the controlled diver.
var findings: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(720, 480)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	seed(970435)
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in 12:
		await physics_frame
	maze.set_physics_process(false)
	var room := maze.get_node("SphereRoom") as SwirlRoom
	room.set_revealed(true)
	# Hidden MultiMesh instances have not received their world transforms yet.
	# Let the public reveal render real orbit positions before freezing the pose.
	for frame in 3:
		await physics_frame
	room.set_physics_process(false)
	for diver in maze.divers:
		diver.global_position = Vector3(2000, 0, 2000)
	maze._diver.global_position = Vector3(room.center.x, 0, room.center.z)
	var actor := maze._diver
	var camera := maze.get_node("Camera3D") as Camera3D
	var focus := actor.global_position + Vector3(0, actor.height * 0.35, 0)
	var meshes := actor.model.find_children("*", "MeshInstance3D", true, false)
	var originals: Array = []
	for mesh in meshes:
		originals.append(mesh.material_override)
	var mask := StandardMaterial3D.new()
	mask.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mask.albedo_color = Color.RED
	mask.disable_fog = true
	var time_scale := Engine.time_scale
	Engine.time_scale = 0
	var angles: Array[float] = []
	for point in room.positions():
		var planar := Vector2(point.x - room.center.x, point.z - room.center.z)
		if planar.length() < 4.1 and angles.size() < 6:
			angles.append(atan2(planar.x, planar.y) + PI)
	angles.append_array([0.3, 2.4])
	for index in 8:
		var angle := angles[index]
		# Exercise the low chase-camera eye height observed in the physical run,
		# not an elevated observer that can look over the offending foreground.
		camera.global_position = focus - Vector3(sin(angle), 0, cos(angle)) * 6.5
		camera.global_position.y = 0.6
		camera.look_at(focus)
		room.set_revealed(true)
		for mesh in meshes:
			mesh.material_override = mask
		await process_frame
		await RenderingServer.frame_post_draw
		var visible := _red_pixels(root.get_texture().get_image())
		room.set_revealed(false)
		await process_frame
		await RenderingServer.frame_post_draw
		var alone := _red_pixels(root.get_texture().get_image())
		var covered := 1.0 - float(visible) / maxf(1, alone)
		if alone < 100 or covered > 0.25:
			findings.append("SWIRL-4 sonar rocks hide controlled diver at angle %d: %.3f" % [index, covered])
		print("SWIRL PIXEL VISIBILITY|angle=", index, "|with=", visible, "|alone=", alone, "|covered=", covered)
		room.set_revealed(true)
		for i in meshes.size():
			meshes[i].material_override = originals[i]
		await process_frame
		await RenderingServer.frame_post_draw
		if not capture_dir.is_empty():
			root.get_texture().get_image().save_png(capture_dir.path_join("eye-angle-%d.png" % index))
	Engine.time_scale = time_scale
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC SWIRL VISIBILITY: clean" if findings.is_empty() else "MARC SWIRL VISIBILITY: failed")
	quit(0 if findings.is_empty() else 1)

func _red_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.r > 0.8 and color.g < 0.2 and color.b < 0.2:
				count += 1
	return count
