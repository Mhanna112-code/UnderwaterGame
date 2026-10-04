extends SceneTree
## Real first-channel traversal catches unreachable current/map integration.
const STEP := 0.75
const ARRIVAL := 0.45
var findings: Array[String] = []
var trace: Array[Vector3] = []
var maze: MazeLevel

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in range(12):
		await physics_frame
	print("ROUTE START|", maze._diver.global_position)
	for name in ["CSGBox3D", "CurrentWall1", "CurrentWall2", "CurrentWall3", "CSGBox3D6", "CSGBox3D7"]:
		var wall := maze.get_node(name) as CSGBox3D
		print("ROUTE WALL|", name, "|position=", wall.global_position, "|size=", wall.size, "|yaw=", wall.rotation.y)
	for name in ["WindCorridor1", "WindCorridor3"]:
		for child in maze.get_node(name).get_children():
			if child is CollisionShape3D:
				print("ROUTE CURRENT|", name, "|position=", child.global_position, "|size=", (child.shape as BoxShape3D).size)
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	# Normal spawn is not within discovery range yet. Swim to the south
	# end of the first wall before asking the map to rotate undiscovered walls.
	var entry_wall := maze.get_node("CurrentWall1") as CSGBox3D
	var entry_end := entry_wall.global_position + entry_wall.global_basis.x * (entry_wall.size.x * 0.5)
	var other_end := entry_wall.global_position - entry_wall.global_basis.x * (entry_wall.size.x * 0.5)
	if other_end.distance_to(maze._diver.global_position) < entry_end.distance_to(maze._diver.global_position):
		entry_end = other_end
	var outward := (entry_end-entry_wall.global_position).normalized()
	outward.y = 0
	entry_end.y = maze._diver.global_position.y
	await _walk_route(entry_end + outward * 3.0)
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	await _key(KEY_L)
	_expect(map.main_map.visible, "ROUTE map did not open")
	_expect(String(map.selected_rotatable_set.get("name", "")) == "CurrentWall1/2", "ROUTE entrance did not reveal hallway walls")
	if findings.is_empty():
		await _key(KEY_E)
		await create_timer(1.7).timeout
		_expect(maze._hallway_1_2_swung, "ROUTE real E did not open hallway")
		_expect(map.selectedCurrentCorridor == maze.get_node("WindCorridor1"), "ROUTE entrance did not select obstructing current1")
		if findings.is_empty():
			await _key(KEY_R)
			_expect(not maze._currents_by_corridor.has(maze.get_node("WindCorridor1")), "ROUTE R left the entry current in place")
	await _key(KEY_L)
	var w6 := maze.get_node("CSGBox3D6") as CSGBox3D
	var w7 := maze.get_node("CSGBox3D7") as CSGBox3D
	var centre := (w6.global_position + w7.global_position) * 0.5
	var axis := w6.global_basis.x.normalized()
	var start := centre - axis * (w6.size.x * 0.5 + 2.0)
	var finish := centre + axis * (w6.size.x * 0.5 + 2.0)
	var channel_interior := centre
	# Choose the channel end closest to the actual normal entrance.
	if finish.distance_to(maze._diver.global_position) < start.distance_to(maze._diver.global_position):
		var swap := start
		start = finish
		finish = swap
	# The first-channel contract ends beyond its current Area, not beyond
	# the whole 80m static boundary which contains later puzzle junctions.
	for child in maze.get_node("WindCorridor3").get_children():
		if child is CollisionShape3D:
			channel_interior = child.global_position
			var size := (child.shape as BoxShape3D).size
			var box_axis: Basis = child.global_basis
			var along := (finish-start).normalized()
			var extent := absf(box_axis.x.dot(along)) * size.x * 0.5 + absf(box_axis.z.dot(along)) * size.z * 0.5
			finish = child.global_position + along * (extent + 2.0)
	start.y = maze._diver.global_position.y
	finish.y = start.y
	print("ROUTE CHANNEL|start=", start, "|end=", finish)
	if findings.is_empty():
		# Discover the obstructing channel from its outer approach, without
		# trying to swim sideways into a still-active current first.
		var side := w6.global_position-centre
		side.y = 0
		await _walk_route(start + side.normalized() * 7.0)
	if findings.is_empty():
		await _key(KEY_L)
		var selected := false
		for cycle in range(12):
			if map.selectedCurrentCorridor == maze.get_node("WindCorridor3"):
				selected = true
				break
			await _key(KEY_RIGHT, true)
		_expect(selected, "ROUTE physical channel approach did not reveal selectable current3")
		if selected:
			if "--leave-current3" not in OS.get_cmdline_user_args():
				await _key(KEY_R)
				_expect(not maze._currents_by_corridor.has(maze.get_node("WindCorridor3")), "ROUTE current3 did not vacate first channel")
		await _key(KEY_L)
	if findings.is_empty():
		await _walk_route(start)
	if findings.is_empty():
		await _swim(finish)
		var closest := INF
		for point in trace:
			closest = minf(closest, Vector2(point.x-channel_interior.x, point.z-channel_interior.z).length())
		_expect(closest <= 1.0, "ROUTE reached exit by bypassing channel interior")
	await _release_movement()
	if findings.is_empty() and "--capture-route" in OS.get_cmdline_user_args():
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png("res://docs/evidence/maze-campaign-integration/current-route-channel.png") == OK, "ROUTE native capture failed")
		await _key(KEY_L)
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png("res://docs/evidence/maze-campaign-integration/current-route-map.png") == OK, "ROUTE map capture failed")
		await _key(KEY_L)
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE CURRENT ROUTE: clean" if findings.is_empty() else "MAZE CURRENT ROUTE: %d findings" % findings.size())
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	quit(0 if findings.is_empty() else 1)

func _walk_route(goal: Vector3) -> void:
	var shape: Shape3D
	for child in maze._diver.get_children():
		if child is CollisionShape3D:
			shape = child.shape
	if shape == null:
		findings.append("ROUTE no real diver collision shape")
		return
	var start := Vector2i(roundi(maze._diver.global_position.x / STEP), roundi(maze._diver.global_position.z / STEP))
	var queue: Array[Vector2i] = [start]
	var parent := {start: start}
	var found := Vector2i(999999, 999999)
	var head := 0
	var space := maze.get_world_3d().direct_space_state
	while head < queue.size() and head < 15000:
		var cell := queue[head]
		head += 1
		var point := Vector3(cell.x * STEP, goal.y, cell.y * STEP)
		if point.distance_to(goal) < 0.75:
			found = cell
			break
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if parent.has(next):
				continue
			var pos := Vector3(next.x * STEP, goal.y, next.y * STEP)
			if absf(pos.x-goal.x) > 55 or absf(pos.z-goal.z) > 55:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.IDENTITY, pos)
			query.collision_mask = 1
			query.collide_with_areas = false
			query.exclude = [maze._diver.get_rid()]
			if not space.intersect_shape(query, 1).is_empty():
				continue
			parent[next] = cell
			queue.append(next)
	if found.x == 999999:
		findings.append("ROUTE no collision-valid approach from normal entry to channel")
		return
	var route: Array[Vector3] = [goal]
	var cursor := found
	while cursor != start:
		route.append(Vector3(cursor.x * STEP, goal.y, cursor.y * STEP))
		cursor = parent[cursor]
	route.reverse()
	for waypoint in route:
		await _swim(waypoint)
		if not findings.is_empty():
			break

func _swim(goal: Vector3) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	var release_click := InputEventMouseButton.new()
	release_click.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release_click)
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	var arrived := false
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		var delta := goal - maze._diver.global_position
		delta.y = 0
		trace.append(maze._diver.global_position)
		if delta.length() < ARRIVAL:
			arrived = true
			break
		var desired := atan2(delta.x, delta.z)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-angle_difference(maze._yaw, desired) / 0.004, 0)
		Input.parse_input_event(motion)
		await physics_frame
	await _release_movement()
	if not arrived:
		findings.append("ROUTE normal keys stopped at %s before %s (push=%s, axis=%s)" % [maze._diver.global_position, goal, maze._diver.external_push, maze._diver.current_axis])
	else:
		print("ROUTE LEG|", maze._diver.global_position)

func _release_movement() -> void:
	var release := InputEventKey.new()
	release.keycode = KEY_W
	Input.parse_input_event(release)
	await physics_frame

func _key(code: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shift
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
