extends SceneTree
## EARN-3: real chest animation excludes actions, but Escape safely pauses it.
var findings: Array[String] = []
var cases := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for kind in ["MapChest", "VortexChest"]:
		for active in 3:
			await _case(kind, active)
			if not findings.is_empty():
				break
		if not findings.is_empty():
			break
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC CHEST OWNERSHIP: clean|cases=%d" % cases if findings.is_empty() else "MARC CHEST OWNERSHIP: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _case(kind: String, active: int) -> void:
	cases += 1
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in 12:
		await physics_frame
	maze.room_encounters_enabled = false
	for i in active:
		await _key(KEY_TAB)
	for diver in maze.divers:
		diver.global_position = Vector3(2000, 0, 2000)
	var chest := maze.get_node(kind) as Node3D
	# Real capsule motion against the authored chest, not only existence of
	# a StaticBody. This local fixture is independent of route/swim proof.
	maze.set_physics_process(false)
	# Skins have different measured capsule heights. Keep each capsule just
	# above the floor instead of letting a short one swim over the chest.
	maze._diver.global_position = chest.global_position + Vector3(0, maze._diver.height * 0.5 + 0.05, 3)
	maze._diver.velocity = Vector3.ZERO
	await physics_frame
	var nearest := INF
	for step in 20:
		maze._diver.move_and_collide(Vector3(0, 0, -0.2))
		nearest = minf(nearest, Vector2(maze._diver.global_position.x-chest.global_position.x,
			maze._diver.global_position.z-chest.global_position.z).length())
	var box := chest.get_node("ChestBody").get_child(0) as CollisionShape3D
	var clearance := (box.shape as BoxShape3D).size.z * 0.5 + maze._diver.radius - 0.02
	_expect(nearest >= clearance, "EARN-3 real capsule penetrates solid " + kind + "|nearest=" + str(nearest)
		+ "|height=" + str(maze._diver.height) + "|radius=" + str(maze._diver.radius) + "|position=" + str(maze._diver.global_position))
	maze._diver.global_position = chest.global_position + Vector3(0, 1.5, 1.8)
	maze.set_physics_process(true)
	# Vortex case must have a genuinely usable map to catch the sibling input
	# bypass. This is an ownership fixture, not route/acquisition evidence.
	if kind == "VortexChest":
		maze.key_items.append("maze_nav_map")
	for frame in 3:
		await physics_frame
	var starts: Array[Vector3] = []
	for diver in maze.divers:
		starts.append(diver.global_position)
	var initial_yaw := maze._yaw
	var initial_pitch := maze._pitch
	var sonar := maze._diver.sonar_active
	var preference := maze.random_encounters_enabled
	var initial_keys := maze.keys_held
	var item := "maze_nav_map" if kind == "MapChest" else "vortex_key"
	await _key(KEY_E)
	_expect(not maze.can_capture_campaign_snapshot(), "EARN-3 in-flight chest can become a saved empty reward")
	var actions := [KEY_W, KEY_SPACE, KEY_TAB, KEY_Q, KEY_R, KEY_L, KEY_E, KEY_RIGHT, KEY_P]
	for code in actions:
		await _key(code, true, code in [KEY_W, KEY_SPACE])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(click)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(60, 40)
	Input.parse_input_event(motion)
	for frame in 8:
		await physics_frame
	await _key(KEY_W, false)
	await _key(KEY_SPACE, false)
	for i in maze.divers.size():
		_expect(maze.divers[i].global_position.distance_to(starts[i]) <= 0.01,
			"EARN-3 held movement/current moved diver during chest animation")
	_expect(maze.active == active and not maze.target_selector.selecting,
		"EARN-3 chest allowed Tab or ability/Swap input")
	_expect(is_equal_approx(maze._yaw, initial_yaw) and is_equal_approx(maze._pitch, initial_pitch),
		"EARN-3 chest allowed mouse/arrow look")
	_expect(maze._diver.sonar_active == sonar and maze.random_encounters_enabled == preference,
		"EARN-3 chest allowed Q/R preferences to change")
	_expect(not maze.get_node("HUD/MazeMiniMap").main_map.visible and not maze._save_menu.visible,
		"EARN-3 sibling map/save input bypassed chest ownership")
	if findings.is_empty():
		await _key(KEY_ESCAPE)
		_expect(maze.inventory_menu.visible, "EARN-3 Escape could not expose the pause menu during chest")
		await create_timer(0.4, true).timeout
		_expect(not maze.key_items.has(item), "EARN-3 paused chest granted reward before its animation resumed")
		await _key(KEY_ESCAPE)
		_expect(not paused and not maze.inventory_menu.visible, "EARN-3 Escape failed to resume chest")
		await create_timer(2.2).timeout
		var popup := root.get_node("CharacterAbilityPopup")
		if (popup.get_node("%AbilityExplanationPanel") as Control).visible:
			await _key(KEY_ESCAPE)
		_expect(maze.key_items.count(item) == 1 and maze.keys_held == initial_keys + (1 if kind == "VortexChest" else 0),
			"EARN-3 interrupted/repeated E lost or duplicated a chest reward")
		_expect(maze.can_capture_campaign_snapshot(), "EARN-3 completed chest stranded its transient snapshot lock")
	print("CHEST INPUT CASE|", kind, "|active=", active, "|findings=", findings.size())
	maze.queue_free()
	await process_frame

func _key(code: Key, pressed := true, hold := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	if pressed and not hold:
		event = InputEventKey.new()
		event.keycode = code
		Input.parse_input_event(event)
		await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
