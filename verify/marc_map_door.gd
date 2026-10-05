extends SceneTree
## DOOR-1..4: real map/door keys, physical reach, priorities and key ownership.
var findings: Array[String] = []
var cases := 0
var capture_dir := ""

func _initialize() -> void:
	# Native verification must not capture unrelated typing in another app.
	# The same parsed game keys still run; browser keyboard remains a separate gate.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var prior_speed := Engine.time_scale
	Engine.time_scale = 8
	for active in 3:
		for mode in ["keyed", "free", "top", "top_closed", "missing", "far", "ctrl", "open", "overlap"]:
			await _case(active, mode)
	Engine.time_scale = prior_speed
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC MAP DOOR: clean|generated=%d" % cases if findings.is_empty() else "MARC MAP DOOR: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _case(active: int, mode: String) -> void:
	cases += 1
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	maze.set_physics_process(false)
	maze.random_encounters_enabled = false
	for actor in maze.divers:
		actor.global_position = Vector3(2000, 0, 2000)
	for i in active:
		await _key(KEY_TAB)
	_expect(maze.active == active, "DOOR fixture Tab did not select intended diver")
	var door := maze.get_node("MazeDoor16") as KeyDoor
	var shape: CollisionShape3D
	for child in door.get_children():
		if child is CollisionShape3D:
			shape = child
	if shape == null:
		_expect(false, "DOOR fixture has no real collision shape")
		maze.queue_free()
		await process_frame
		return
	var half: Vector3 = shape.shape.size * 0.5
	# Fixture near the actual exterior surface; the oracle is successful input,
	# not a call to the product's reach or ready predicate.
	var local := Vector3(0, -half.y + 0.8, half.z + 0.7)
	if mode in ["top", "top_closed"]:
		local.y = half.y - 0.1
	if mode == "far":
		local.z += 8
	maze.divers[active].global_position = shape.global_transform * local
	maze.keys_held = 0 if mode == "missing" else 1
	maze.campaign_key_items.assign(["current_pearl"])
	if mode == "free":
		door.required_key_id = ""
	if mode == "open":
		door.restore_open_state()
	var eligible: KeyDoor = door
	if mode == "overlap":
		# Earlier empty-key-count door must not swallow an eligible free door.
		maze.keys_held = 0
		eligible = maze._spawn_key_door("ReadyDoorFixture", door.global_position, door.global_basis.z, "")
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	var discovery := {"walls": [], "rooms": [], "corridors": [], "halls": [], "count": 0, "pois": []}
	for wall in maze.wall_boxes:
		discovery.walls.append(String(wall.name))
	for corridor in maze.corridors:
		discovery.corridors.append(String(corridor.name))
	map.restore_campaign_discovery(discovery)
	await _key(KEY_L)
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT, true)
	_expect(map.main_map.visible and not map.selected_rotatable_set.is_empty() and map.selectedCurrentCorridor != null,
		"DOOR fixture real map keys did not select geometry")
	var walls: Array[Transform3D] = []
	var wall_nodes: Array[Node3D] = []
	for wall in map.selected_rotatable_set.get("walls", []):
		wall_nodes.append(wall)
		walls.append(wall.global_transform)
	var before_current := map.selectedCurrentCorridor
	var before_keys := maze.keys_held
	var hallway_before := maze._hallway_1_2_swung
	_expect(maze._moving_wall_sets.is_empty(), "DOOR fixture started snapshot during an existing wall rotation")
	if mode == "top_closed":
		await _key(KEY_L)
	await _key(KEY_E, mode == "ctrl")
	await create_timer(1.7).timeout
	var should_open := mode in ["keyed", "free", "top", "top_closed", "overlap"]
	var id := "active=%d mode=%s" % [active, mode]
	_expect(eligible.is_open() == (should_open or mode == "open"), "DOOR-1 ready-door priority/open state wrong: " + id)
	if should_open:
		_expect(not eligible.is_collision_blocking(), "DOOR-1 open door still blocks collision after real animation: " + id)
		for i in walls.size():
			_expect(wall_nodes[i].global_transform.is_equal_approx(walls[i]), "DOOR-1 E opens door but also rotates walls: " + id
				+ "|wall=" + String(wall_nodes[i].name) + "|before=" + str(walls[i]) + "|after=" + str(wall_nodes[i].global_transform)
				+ "|hallway_swung_before=" + str(hallway_before) + "|after=" + str(maze._hallway_1_2_swung))
	else:
		if mode == "ctrl":
			_expect(map.selectedCurrentCorridor != before_current, "DOOR-3 Ctrl+E no longer moves current: " + id)
			for i in walls.size():
				_expect(wall_nodes[i].global_transform.is_equal_approx(walls[i]), "DOOR-3 Ctrl+E rotates walls: " + id)
		else:
			var changed := false
			for i in walls.size():
				changed = changed or not wall_nodes[i].global_transform.is_equal_approx(walls[i])
			_expect(changed, "DOOR-3 unavailable door incorrectly steals ordinary map wall E: " + id)
	var expected_keys := before_keys - 1 if mode in ["keyed", "top", "top_closed"] else before_keys
	_expect(maze.keys_held == expected_keys and maze.campaign_key_items == ["current_pearl"], "DOOR-3 lost wrong key/relic or failed to spend one: " + id)
	if mode == "overlap":
		_expect(not door.is_open(), "DOOR-4 missing-key door opens instead of ready free door")
	if should_open and eligible.is_open():
		# Repeated E after opening must not charge another key.
		if mode != "top_closed":
			await _key(KEY_E)
			_expect(maze.keys_held == expected_keys, "DOOR-3 repeat E spends a second key: " + id)
			await create_timer(1.7).timeout
	if not capture_dir.is_empty() and active == 0 and mode in ["keyed", "top"]:
		await _key(KEY_L)
		var camera := maze.get_node("Camera3D") as Camera3D
		# The corridor is narrow; an 8m fixture camera lands inside its far
		# wall, bypassing the production camera's collision pull-in.
		camera.global_position = door.global_position + door.global_basis.z * 2.2 + Vector3.UP * 2
		camera.look_at(door.global_position + Vector3.UP * door.visual_height * 0.5)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("door-%s.png" % mode))
	print("MAP DOOR CASE|", id, "|keys=", maze.keys_held, "|open=", eligible.is_open())
	maze.queue_free()
	await process_frame

func _key(code: Key, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.ctrl_pressed = ctrl
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
