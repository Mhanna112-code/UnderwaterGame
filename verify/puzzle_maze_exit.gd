extends SceneTree
## PX-01: real plate completion + movement opens Deep; the maze ramp is after lab.
const SLOT := 918349
var findings: Array[String] = []
var world: World
var owns_slot := false
var expected_stats: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	if SaveManager.slot_exists(SLOT):
		findings.append("PX harness slot exists; refusing overwrite")
		await _finish()
		return
	world = await _world_fixture()
	# PX-04: placement at the proposed exit is a deliberate negative fixture.
	world.divers[0].global_position = Vector3(47, 2, 10)
	for frame in range(12):
		await physics_frame
	_expect(current_scene == world, "PX-04 unsolved puzzle permits maze entry")
	# Put actors on real Areas; do not set solved, call the poll or emit an entry.
	for index in range(3):
		world.divers[index].global_position = world._lock_plates[index].global_position
		world.divers[index].velocity = Vector3.ZERO
	for frame in range(12):
		await physics_frame
	_expect(world._puzzle_solved, "PX fixture real plate Areas did not complete the puzzle")
	await create_timer(3.8).timeout
	for diver in world.divers:
		expected_stats.append(diver.stats)
	if "--cold-load" in OS.get_cmdline_user_args():
		world.save_point_menu.save_requested.emit(world.divers[0], SLOT)
		await process_frame
		var saved := SaveManager.read_slot(SLOT)
		if "--browser-fixture" in OS.get_cmdline_user_args():
			var fixture := FileAccess.open("/tmp/puzzle-maze-solved-fixture.json", FileAccess.WRITE)
			fixture.store_string(JSON.stringify(saved))
			fixture.close()
		world.queue_free()
		await process_frame
		world = await _world_fixture()
		for invalid in [{"ability_puzzle_solved": "yes"}, {"maze_entry_source": "lab"}]:
			var broken := saved.duplicate(true)
			broken.merge(invalid, true)
			var before_hp: int = world.divers[0].stats.hp
			_expect(not world.restore_checkpoint(broken) and world.divers[0].stats.hp == before_hp,
				"PX malformed new entrance fields accepted or partly mutated party")
		_expect(world.restore_checkpoint(saved), "PX-02 solved checkpoint refused restoration")
		for index in range(3):
			expected_stats[index] = world.divers[index].stats
		await physics_frame
		for door in world._doors:
			var shapes: Array = door.get_children().filter(func(child: Node) -> bool: return child is CollisionShape3D)
			_expect(shapes.size() == 1 and (shapes[0] as CollisionShape3D).disabled,
				"PX-02 solved checkpoint rebuilt a blocking puzzle door")
	if "--capture-exit" in OS.get_cmdline_user_args():
		await _swim(Vector3(40, 2, 10), false)
		# Look toward the doorway with real mouse input before judging its sign.
		var look := InputEventMouseButton.new()
		look.button_index = MOUSE_BUTTON_LEFT
		look.pressed = true
		Input.parse_input_event(look)
		await process_frame
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-angle_difference(world.yaw, PI / 2.0) / 0.004, 0)
		Input.parse_input_event(motion)
		look = InputEventMouseButton.new()
		look.button_index = MOUSE_BUTTON_LEFT
		Input.parse_input_event(look)
		await create_timer(1.2).timeout
		print("PUZZLE EXIT VIEW|diver=", world.divers[world.active].global_position, "|camera=", world.cam.global_position)
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png("res://docs/evidence/maze-campaign-integration/puzzle-maze-exit.png") == OK, "PX exit capture failed")
	await _swim(Vector3(48, 2, 10), false)
	for frame in range(16):
		await physics_frame
	_expect(current_scene == world and not world.embedded_maze.maze_active,
		"PX-01 blockade exit still teleports to the maze instead of leading toward lab-side ramp")
	_expect(world.divers[world.active].global_position.distance_to(Vector3(48, 2, 10)) < 1.0,
		"PX-01 solved blockade exit remains physically obstructed")
	for index in range(3):
		_expect(world.divers[index].stats == expected_stats[index], "PX exit replaced party resources")
	_expect(world._puzzle_solved and world.route_state.lab_state == "locked" and world.route_state.tethys_state == "locked",
		"PX exit lost puzzle progress or changed independent laboratory completion")
	print("PUZZLE EXIT|Deep passage opened|maze entrance relocated beyond laboratory|party preserved")
	await _finish()

func _world_fixture() -> World:
	var instance := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	instance.skip_intro_for_test = true
	instance.skip_tutorial_for_test = true
	root.add_child(instance)
	current_scene = instance
	await process_frame
	instance.title_screen.close()
	instance.get_node("HUD").show()
	paused = false
	instance._current_slot = SLOT
	owns_slot = true
	await _key(KEY_R)
	for frame in range(6):
		await physics_frame
	return instance

func _swim(goal: Vector3, expect_scene: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	var deadline := Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < deadline and current_scene == world:
		var delta: Vector3 = goal - world.divers[world.active].global_position
		delta.y = 0
		if not expect_scene and delta.length() < 0.35:
			break
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-angle_difference(world.yaw, atan2(delta.x, delta.z)) / 0.004, 0)
		Input.parse_input_event(motion)
		await physics_frame
	event = InputEventKey.new()
	event.keycode = KEY_W
	Input.parse_input_event(event)
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(click)
	await physics_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
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

func _finish() -> void:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	if owns_slot:
		DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING ", finding)
	print("PUZZLE MAZE EXIT: clean" if findings.is_empty() else "PUZZLE MAZE EXIT: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
