extends SceneTree
## WR-01/02: actual input travel catches unreachable independent maze entry.
const SLOT := 918347
const STEP := 1.0
const ARRIVAL := 0.45
var findings: Array[String] = []
var world: World
var owned_slot := false
var expected_stats: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	if SaveManager.slot_exists(SLOT):
		findings.append("WR harness slot exists; refusing overwrite")
		await _finish()
		return
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	# Isolate the recovered-world journey, not opener completion or puzzle solving.
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").show()
	paused = false
	world._current_slot = SLOT
	owned_slot = true
	for diver in world.divers:
		expected_stats.append(diver.stats)
	for frame in range(12):
		await physics_frame
	print("WORLD MAZE START|", world.divers[world.active].global_position)
	_expect(world.route_state.zone_id == "shallows" and world.route_state.maze_door_state == "locked",
		"WR fixture did not start in normal shallow/locked state")
	await _key(KEY_R)
	_expect(not world.random_encounters_enabled, "WR parsed R did not disable ordinary random encounters")
	# Travel beside the shallow puzzle rather than claiming to solve it. This
	# retains its collision and every lab gate while testing the independent path.
	for goal in [Vector3(55, 2, -5), DeepZoneLayout.DEEP_ENTRY,
		DeepZoneLayout.DEEP_HUB, Vector3(104, 2, -4), DeepZoneLayout.MAZE_TRANSITION]:
		if not findings.is_empty() or current_scene is MazeLevel:
			break
		await _walk_route(goal)
	await _release_movement()
	for frame in range(16):
		await physics_frame
		if current_scene is MazeLevel:
			break
	_expect(current_scene is MazeLevel, "WR-01 actual world travel did not load the maze")
	if current_scene is MazeLevel:
		var maze := current_scene as MazeLevel
		_expect(maze.route_state.bomb_bot_state == "available" and maze.route_state.sword_slayer_state == "available"
			and maze.route_state.tethys_state == "locked" and maze.route_state.lab_state == "locked",
			"WR-02 independent entry required or changed laboratory victories")
		for index in range(3):
			_expect(maze.divers[index].stats == expected_stats[index], "WR-02 actual movement arrival reconstructed party stats")
		_expect(not maze.random_encounters_enabled, "WR-02 actual arrival lost encounter preference")
		print("WORLD MAZE ARRIVED|", maze._diver.global_position, "|lab=", maze.route_state.lab_state)
		if "--capture-route" in OS.get_cmdline_user_args():
			await create_timer(1.2).timeout
			await RenderingServer.frame_post_draw
			_expect(root.get_texture().get_image().save_png("res://docs/evidence/maze-campaign-integration/world-maze-arrival.png") == OK,
				"WR rendered arrival capture failed")
	await _finish()

func _walk_route(goal: Vector3) -> void:
	var diver := world.divers[world.active] as Diver
	var shape_node: CollisionShape3D
	for child in diver.get_children():
		if child is CollisionShape3D:
			shape_node = child
	_expect(shape_node != null, "WR real diver collision shape is missing")
	if shape_node == null:
		return
	var start := Vector2i(roundi(diver.global_position.x / STEP), roundi(diver.global_position.z / STEP))
	var queue: Array[Vector2i] = [start]
	var parent := {start: start}
	var found := Vector2i(999999, 999999)
	var head := 0
	var space := world.get_world_3d().direct_space_state
	while head < queue.size() and head < 30000:
		var cell := queue[head]
		head += 1
		var point := Vector3(cell.x * STEP, goal.y, cell.y * STEP)
		if point.distance_to(goal) < 0.8:
			found = cell
			break
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if parent.has(next):
				continue
			var pos := Vector3(next.x * STEP, goal.y, next.y * STEP)
			if absf(pos.x-goal.x) > 70 or absf(pos.z-goal.z) > 70:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape_node.shape
			query.transform = Transform3D(Basis.IDENTITY, pos) * shape_node.transform
			query.collision_mask = diver.collision_mask
			query.collide_with_areas = false
			query.exclude = [diver.get_rid()]
			if not space.intersect_shape(query, 1).is_empty():
				continue
			parent[next] = cell
			queue.append(next)
	if found.x == 999999:
		findings.append("WR-01 no collision-valid approach from %s to %s" % [diver.global_position, goal])
		return
	var route: Array[Vector3] = [goal]
	var cursor := found
	while cursor != start:
		route.append(Vector3(cursor.x * STEP, goal.y, cursor.y * STEP))
		cursor = parent[cursor]
	route.reverse()
	for waypoint in route:
		await _swim(waypoint)
		if not findings.is_empty() or current_scene is MazeLevel:
			break

func _swim(goal: Vector3) -> void:
	if current_scene is MazeLevel:
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	var arrived := false
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and is_instance_valid(world):
		if current_scene is MazeLevel:
			arrived = true
			break
		var diver := world.divers[world.active] as Diver
		var delta := goal-diver.global_position
		delta.y = 0
		if delta.length() < ARRIVAL:
			arrived = true
			break
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-angle_difference(world.yaw, atan2(delta.x, delta.z)) / 0.004, 0)
		Input.parse_input_event(motion)
		await physics_frame
	await _release_movement()
	if not arrived and is_instance_valid(world):
		findings.append("WR-01 normal inputs stopped at %s before %s" % [world.divers[world.active].global_position, goal])

func _release_movement() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	Input.parse_input_event(event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(mouse)
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
	if owned_slot:
		DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING ", finding)
	print("WORLD MAZE ROUTE: clean" if findings.is_empty() else "WORLD MAZE ROUTE: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
