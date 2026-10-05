extends "res://verify/maze_current_route.gd"
## EARN-1: the map is earned through normal no-map swimming, not a bootstrap trap.
var capture_dir := ""
var embedded_world: World

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	root.size = Vector2i(1280, 720)
	var review_entry := "--maze-playtest" in OS.get_cmdline_user_args()
	if "--world-acquisition" in OS.get_cmdline_user_args() or review_entry:
		embedded_world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
		embedded_world.skip_intro_for_test = true
		embedded_world.skip_tutorial_for_test = true
		root.add_child(embedded_world)
		current_scene = embedded_world
		await process_frame
		embedded_world.title_screen.close()
		paused = false
		embedded_world.random_encounters_enabled = false
		maze = embedded_world.embedded_maze
		if not review_entry:
			for i in 3:
				embedded_world.divers[i].global_position = Vector3(maze.embedded_bounds.position.x - 1.5 - i * 2, 1.8, 16)
			embedded_world.yaw = PI * 0.5
			var swim := InputEventKey.new()
			swim.keycode = KEY_W
			swim.pressed = true
			Input.parse_input_event(swim)
			for frame in 45:
				await physics_frame
				if maze.maze_active:
					break
			swim = InputEventKey.new()
			swim.keycode = KEY_W
			Input.parse_input_event(swim)
		else:
			for frame in 4:
				await process_frame
		_expect(maze.maze_active and current_scene == embedded_world, "EARN-1 real ramp approach did not enter shared maze")
		_expect(maze.divers == embedded_world.divers, "EARN-1 map route replaced the World party")
	else:
		maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
		root.add_child(maze)
		current_scene = maze
	for frame in range(15):
		await physics_frame
	var entry := maze._diver.global_position
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	await _key(KEY_L)
	_expect(not map.main_map.visible, "EARN-1 unearned L opens the navigation map")
	_expect(not String((maze.get_node("HUD/GoalLabel") as Label).text).contains("L:"),
		"EARN-1 footer teaches unavailable L before map acquisition")
	if not findings.is_empty():
		await _finish_earned()
		return
	var chest := maze.get_node_or_null("MapChest") as Node3D
	_expect(chest != null, "EARN-1 Control Room has no map chest")
	if chest == null:
		await _finish_earned()
		return
	# R is a genuine preference input, not disabling currents or wall collision.
	if maze.random_encounters_enabled:
		await _key(KEY_R)
	var goal := chest.global_position + Vector3(0, 1.0, 1.8)
	print("EARNED MAP ENTRY|position=", entry, "|goal=", goal, "|yaw=", maze._yaw)
	var route := _no_current_path(goal)
	_expect(not route.is_empty(), "EARN-1 no capsule-clear no-current route to chest before earning map")
	if not findings.is_empty():
		await _finish_earned()
		return
	# Rise using the real control before following the capsule-clear plane.
	var rise := InputEventKey.new()
	rise.keycode = KEY_SPACE
	rise.pressed = true
	Input.parse_input_event(rise)
	# Native shader warm-up can consume five wall-clock seconds before
	# enough physics frames occur; still bound it, and record held input/FPS.
	var deadline := Time.get_ticks_msec() + 10000
	var rise_frames := 0
	while maze._diver.global_position.y < goal.y - 0.12 and Time.get_ticks_msec() < deadline:
		await physics_frame
		rise_frames += 1
	print("EARNED MAP RISE|frames=", rise_frames, "|held=", Input.is_key_pressed(KEY_SPACE), "|y=", maze._diver.global_position.y, "|goal=", goal.y, "|fps=", Engine.get_frames_per_second())
	rise = InputEventKey.new()
	rise.keycode = KEY_SPACE
	Input.parse_input_event(rise)
	for frame in 10:
		await physics_frame
	_expect(maze._diver.global_position.y >= goal.y - 0.2, "EARN-1 normal SPACE could not rise for dome doorway")
	# The input observer steers horizontally. Plan at the actual settled
	# capsule height, not a desired Y it never commands (native low FPS can
	# overshoot SPACE). A clear plane at Y=2 is not proof for a diver at 2.6.
	goal.y = maze._diver.global_position.y
	route = _no_current_path(goal)
	_expect(not route.is_empty(), "EARN-1 no clear chest route at actual swim height")
	for waypoint in route:
		await _swim(waypoint)
		if not findings.is_empty():
			break
	if findings.is_empty():
		for frame in range(3):
			await physics_frame
		_expect(maze._diver.global_position.distance_to(goal) < 0.8, "EARN-1 real swimming did not reach chest approach")
		_expect(maze._hallway_1_2_swung == false and maze._path_opened == false,
			"EARN-1 route secretly needed wall/map progression before chest")
		var keys := maze.keys_held
		await _capture("chest-approach")
		await _key(KEY_E)
		await create_timer(2.2).timeout
		_expect(maze.key_items.count("maze_nav_map") == 1, "EARN-1 real chest E/Tween did not grant exactly one navigation map")
		_expect(maze.keys_held == keys, "EARN-1 map acquisition grants a spendable maze-door key")
		var popup := root.get_node("CharacterAbilityPopup")
		_expect((popup.get_node("%AbilityExplanationPanel") as Control).visible,
			"EARN-1 acquired-map explanation did not open")
		await _capture("map-acquired")
		if (popup.get_node("%AbilityExplanationPanel") as Control).visible:
			await _key(KEY_ESCAPE)
		await _key(KEY_L)
		_expect(map.main_map.visible, "EARN-1 acquired map cannot be opened with real L")
		_expect((popup.get_node("%AbilityExplanationPanel") as Control).visible and paused, "EARN-1 earned first L does not teach navigation")
		await _key(KEY_ESCAPE)
		await _capture("earned-map")
		await _key(KEY_L)
		var back := _no_current_path(Vector3(entry.x, maze._diver.global_position.y, entry.z))
		_expect(not back.is_empty(), "EARN-1 chest route has no return to the entry corridor")
		for waypoint in back:
			await _swim(waypoint)
			if not findings.is_empty():
				break
		_expect(Vector2(maze._diver.global_position.x-entry.x, maze._diver.global_position.z-entry.z).length() < 0.8,
			"EARN-1 real swimming could not return from the chest to maze entry")
		print("EARNED MAP ROUTE|distance=", trace.size(), " samples|position=", maze._diver.global_position,
			"|map_count=", maze.key_items.count("maze_nav_map"), "|keys=", maze.keys_held)
	await _finish_earned()

func _finish_earned() -> void:
	await _release_movement()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC EARNED MAP: clean" if findings.is_empty() else "MARC EARNED MAP: %d findings" % findings.size())
	if embedded_world != null:
		embedded_world.queue_free()
	else:
		maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	quit(0 if findings.is_empty() else 1)

func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK,
		"EARN-1 native capture failed")
