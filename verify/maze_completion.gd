extends SceneTree

# Captured full-run contract for the standalone maze. This drives the
# production CharacterBody3D through physics; it never writes the diver's
# position after scene spawn, disables collision, or neutralizes currents.

# The player must actually arrive at each collision-planned cell. A large
# arrival radius can skip a one-metre CSG wall by accepting positions on either
# side as "close enough", which is exactly the false completion claim this
# regression exists to prevent.
const DT := 1.0 / 30.0
const MAX_FRAMES_PER_LEG := 500
const WAYPOINT_RADIUS := 0.15
const GRID_STEP := 0.8
const SEARCH_MIN := Vector2(-18.0, -38.0)
const SEARCH_MAX := Vector2(108.0, 108.0)

func _initialize() -> void:
	call_deferred("_run")

func _press(maze: MazeLevel, key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	maze._unhandled_input(event)

func _swim_to(diver: Diver, target: Vector3, trace: Array[Vector3]) -> bool:
	for _frame in range(MAX_FRAMES_PER_LEG):
		var delta := target - diver.global_position
		delta.y = 0.0
		trace.append(diver.global_position)
		if delta.length() <= WAYPOINT_RADIUS:
			return true
		diver.swim(delta.normalized(), 0.0, DT)
		await physics_frame
	return false

func _visited(trace: Array[Vector3], center: Vector3, radius: float) -> bool:
	for point in trace:
		var planar := Vector2(point.x - center.x, point.z - center.z)
		if planar.length() <= radius:
			return true
	return false

func _cell_for(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / GRID_STEP), roundi(point.z / GRID_STEP))

func _point_for(cell: Vector2i, y: float) -> Vector3:
	return Vector3(cell.x * GRID_STEP, y, cell.y * GRID_STEP)

func _in_search_bounds(point: Vector3) -> bool:
	return point.x >= SEARCH_MIN.x and point.x <= SEARCH_MAX.x and point.z >= SEARCH_MIN.y and point.z <= SEARCH_MAX.y

func _diver_shape(diver: Diver) -> Shape3D:
	for child in diver.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).shape
	return null

func _is_clear(space: PhysicsDirectSpaceState3D, shape: Shape3D, position: Vector3, diver: Diver) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = [diver.get_rid()]
	return space.intersect_shape(query, 1).is_empty()

# Returns a collision-valid grid route, not a scripted teleport path. The
# production Diver still swims every resulting leg below; this only plans
# around the CSG geometry so the test can discover the real maze route rather
# than assuming a straight line through every future wall arrangement.
func _find_route(diver: Diver, goal: Vector3, minimum_z: float) -> Array[Vector3]:
	var shape := _diver_shape(diver)
	if shape == null:
		return []
	var space := root.get_world_3d().direct_space_state
	var start := _cell_for(diver.global_position)
	var queue: Array[Vector2i] = [start]
	var parent: Dictionary = {start: start}
	var found := Vector2i(999_999, 999_999)
	var head := 0
	var neighbors: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var world_point := _point_for(cell, diver.global_position.y)
		if world_point.distance_to(goal) <= Diver.SHOCKWAVE_RADIUS - 0.25:
			found = cell
			break
		for offset in neighbors:
			var next := cell + offset
			if parent.has(next):
				continue
			var next_point := _point_for(next, diver.global_position.y)
			if next_point.z < minimum_z or not _in_search_bounds(next_point) or not _is_clear(space, shape, next_point, diver):
				continue
			parent[next] = cell
			queue.append(next)
	if found.x == 999_999:
		return []
	var reverse_path: Array[Vector3] = []
	var cursor := found
	while cursor != start:
		reverse_path.append(_point_for(cursor, diver.global_position.y))
		cursor = parent[cursor] as Vector2i
	reverse_path.reverse()
	return reverse_path

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	for _frame in range(10):
		await physics_frame

	# This is the player-visible H interaction. The existing traversal test
	# already proves the local passage; this contract continues to the reward.
	_press(maze, KEY_H)
	await create_timer(1.4).timeout
	for _frame in range(3):
		await physics_frame
	maze.set_physics_process(false)

	var diver := maze._diver
	var rock_marker := maze.get_node("ItemRock") as Marker3D
	var wall_6 := maze.get_node("CSGBox3D6") as CSGBox3D
	var wall_7 := maze.get_node("CSGBox3D7") as CSGBox3D
	var mouth_x := (wall_6.global_position.x + wall_7.global_position.x) * 0.5
	var trace: Array[Vector3] = []
	var findings: Array[String] = []

	# The first two points are the previously reported wall route. The rest of
	# the maze is planned from live collision, then driven through with the real
	# player, so this contract works if a future layout changes without becoming
	# a magic, through-wall movement script.
	var legs: Array[Vector3] = [
		Vector3(mouth_x, 0.0, -4.0),
		Vector3(mouth_x, 0.0, 18.0),
		# Carry the player clear of WindCorridor3 before planning. H deliberately
		# makes this zone a one-way northbound lane; attempting to immediately
		# route back south would be a false "movement failed" result.
		Vector3(mouth_x, 0.0, 24.0),
	]
	for target in legs:
		if not await _swim_to(diver, target, trace):
			findings.append("player stopped at %s before route waypoint %s" % [diver.global_position, target])
			break
	if findings.is_empty():
		# Do not route back into the H-open one-way channel after deliberately
		# clearing it. A physical path that requires swimming upstream through
		# that zone is not a playable player route.
		var route := _find_route(diver, rock_marker.global_position, 18.0)
		if route.is_empty():
			findings.append("no collision-safe route connects the opened hallway to ItemRock's shockwave range")
		else:
			for target in route:
				if not await _swim_to(diver, target, trace):
					findings.append("player stopped at %s while following the collision-safe route to ItemRock" % diver.global_position)
					break

	# The route must genuinely use the post-H corridor and approach from south;
	# otherwise opening the whole perimeter could create a false green result.
	if not _visited(trace, Vector3(mouth_x, 0.0, 8.0), 3.0):
		findings.append("route did not traverse the opened CSGBox3D6/7 channel")
	if not _visited(trace, Vector3(rock_marker.global_position.x, 0.0, 35.5), 2.0):
		findings.append("route did not reach the authored southern reward entrance")

	if findings.is_empty():
		# Completion must use the actual player-facing interaction, not a
		# direct ability call that a browser reviewer cannot reproduce.
		_press(maze, KEY_E)
		for _frame in range(3):
			await physics_frame
		if not maze.has_method("is_completed") or not bool(maze.call("is_completed")):
			findings.append("breaking ItemRock does not mark the maze complete")
		var completion_label := maze.get_node_or_null("HUD/MazeComplete") as Label
		if completion_label == null or not completion_label.visible:
			findings.append("completion is not visibly communicated to the player")

	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE COMPLETION: clean" if findings.is_empty() else "MAZE COMPLETION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
