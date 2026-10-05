extends SceneTree

var findings: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _expect(ok: bool, bug: String) -> void:
	if not ok:
		findings.append(bug)

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	world.divers[0].global_position = Vector3(263, 2, 16)
	for frame in range(18):
		await physics_frame
	var maze := world.embedded_maze
	_expect(maze.maze_active, "REST fixture shared ramp entry")
	_expect(maze._campaign_save_points.size() == 3, "REST-1 missing interior pads")
	maze.random_encounters_enabled = false
	for point in maze._campaign_save_points:
		world.divers[1].stats.hp = 0
		world.divers[2].stats.oxygen = 17.0
		world.divers[0].global_position = point.global_position + Vector3.UP * 0.7
		for frame in range(9):
			await physics_frame
		_expect(point.has_diver(world.divers[0]), "REST-1 pad has no actual Area overlap: " + String(point.name))
		_expect(world.divers[1].stats.hp == world.divers[1].stats.hp_max and world.divers[2].stats.oxygen > 99.0,
			"REST-1 pad did not restore shared/downed party: " + String(point.name))
		var key := InputEventKey.new()
		key.keycode = KEY_P
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		await process_frame
		print("REST INPUT|", point.name, "|active=", maze.maze_active, "|modal=", maze.any_modal_open(), "|contact=", maze._contacted_campaign_checkpoint(), "|menu=", maze._save_menu.visible)
		_expect(maze._save_menu.visible, "REST-1 actual P did not open menu: " + String(point.name))
		maze._save_menu.close()
		key = InputEventKey.new()
		key.keycode = KEY_P
		Input.parse_input_event(key)
	var hall := maze._hall_rect()
	var seen_lanes: Dictionary = {}
	for hazard in maze._hall_whirlpools:
		_expect(is_equal_approx(hazard.warning_radius, 2.6) and is_equal_approx(hazard.pull_radius, 1.6) and is_equal_approx(hazard.pull_speed, 2.4), "HALL-1 old aggressive parameters")
		var fraction: float = (hazard.global_position.z - hall.get_center().y) / hall.size.y
		seen_lanes[snappedf(fraction, 0.01)] = true
		_expect(hazard.deep_hole_radius > 0.0 and hazard.get_child_count() >= 5, "HALL-1 no deep shaft/current")
	var floor := maze.get_node("Floor_BossHall") as CSGBox3D
	var holes := 0
	for child in floor.get_children():
		if child is CSGCylinder3D and child.operation == CSGShape3D.OPERATION_SUBTRACTION:
			holes += 1
	_expect(holes == maze._hall_whirlpools.size(), "HALL-1 visible floor not carved")
	_expect(seen_lanes.size() >= 3, "HALL-1 whirlpools still aligned on one side")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		maze.set_physics_process(false)
		world.set_physics_process(false)
		var camera := maze.get_node("Camera3D") as Camera3D
		var target := Vector3(hall.get_center().x, maze._floor_top_y, hall.get_center().y)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(hall.size.x, hall.size.y) * 1.3
		camera.global_position = target + Vector3(0, 60, 0.01)
		camera.look_at(target, Vector3.UP)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pr100-marc-hall-native.png")
	for size in [Vector2i(1280,720), Vector2i(1280,360), Vector2i(360,640)]:
		root.size = size
		world.title_screen.open()
		world.title_screen._open_slots("load")
		for frame in range(6):
			await process_frame
		var viewport := Rect2(Vector2.ZERO, Vector2(size))
		_expect(viewport.encloses(world.title_screen._menu_panel.get_global_rect()), "AUTO-3 Load panel clipped at " + str(size))
		var rows := 0
		for child in world.title_screen._list.get_children():
			if child is Button and String(child.name).begins_with("AutosaveSlot"):
				rows += 1
		_expect(rows == 3, "AUTO-3 missing auto rows")
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/pr100-load-%dx%d.png" % [size.x, size.y])
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC RECOVERY/HALL/TITLE: clean" if findings.is_empty() else "MARC RECOVERY/HALL/TITLE: findings")
	quit(0 if findings.is_empty() else 1)
