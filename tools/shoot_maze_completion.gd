# Captures the actual standalone maze completion defended by
# verify/maze_completion.gd. It uses the same H input, collision-aware route,
# production Diver swimming, northbound current, and shockwave reward action;
# only movement input is replayed. Run with a display-capable Godot process:
#
# godot --path . --script tools/shoot_maze_completion.gd -- before.png complete.png
extends SceneTree

const DT := 1.0 / 30.0
const WAYPOINT_RADIUS := 0.15
const GRID_STEP := 0.8
const SEARCH_MIN := Vector2(-18.0, -38.0)
const SEARCH_MAX := Vector2(108.0, 108.0)

var before_path := "/tmp/pr70-maze-completion-before.png"
var complete_path := "/tmp/pr70-maze-completion-complete.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		before_path = String(args[0])
	if args.size() >= 2:
		complete_path = String(args[1])
	call_deferred("_run")

func _capture(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("captured %s" % path)

func _press(maze: MazeLevel, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	maze._unhandled_input(event)

func _swim_to(maze: MazeLevel, diver: Diver, target: Vector3) -> bool:
	for _frame in range(500):
		var delta := target - diver.global_position
		delta.y = 0.0
		if delta.length() <= WAYPOINT_RADIUS:
			return true
		diver.swim(delta.normalized(), 0.0, DT)
		maze._move_camera(DT)
		await physics_frame
	return false

func _cell_for(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / GRID_STEP), roundi(point.z / GRID_STEP))

func _point_for(cell: Vector2i, y: float) -> Vector3:
	return Vector3(cell.x * GRID_STEP, y, cell.y * GRID_STEP)

func _is_clear(space: PhysicsDirectSpaceState3D, shape: Shape3D, position: Vector3, diver: Diver) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = [diver.get_rid()]
	return space.intersect_shape(query, 1).is_empty()

func _route_to_reward(diver: Diver, goal: Vector3) -> Array[Vector3]:
	var shape: Shape3D = null
	for child in diver.get_children():
		if child is CollisionShape3D:
			shape = (child as CollisionShape3D).shape
	if shape == null:
		return []
	var start := _cell_for(diver.global_position)
	var queue: Array[Vector2i] = [start]
	var parent: Dictionary = {start: start}
	var found := Vector2i(999_999, 999_999)
	var head := 0
	var space := root.get_world_3d().direct_space_state
	var neighbors: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var point := _point_for(cell, diver.global_position.y)
		if point.distance_to(goal) <= Diver.SHOCKWAVE_RADIUS - 0.25:
			found = cell
			break
		for offset in neighbors:
			var next := cell + offset
			if parent.has(next):
				continue
			var next_point := _point_for(next, diver.global_position.y)
			if next_point.z < 18.0 or next_point.x < SEARCH_MIN.x or next_point.x > SEARCH_MAX.x or next_point.z > SEARCH_MAX.y:
				continue
			if not _is_clear(space, shape, next_point, diver):
				continue
			parent[next] = cell
			queue.append(next)
	if found.x == 999_999:
		return []
	var route: Array[Vector3] = []
	var cursor := found
	while cursor != start:
		route.append(_point_for(cursor, diver.global_position.y))
		cursor = parent[cursor] as Vector2i
	route.reverse()
	return route

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	for _frame in range(10):
		await physics_frame
	maze._yaw = 0.0
	maze._pitch = -0.12
	var diver := maze._diver
	for _frame in range(18):
		maze._move_camera(DT)
		await process_frame
	await _capture(before_path)

	_press(maze, KEY_H)
	await create_timer(1.4).timeout
	maze.set_physics_process(false)
	var wall_6 := maze.get_node("CSGBox3D6") as CSGBox3D
	var wall_7 := maze.get_node("CSGBox3D7") as CSGBox3D
	var mouth_x := (wall_6.global_position.x + wall_7.global_position.x) * 0.5
	var route_ok := await _swim_to(maze, diver, Vector3(mouth_x, 0.0, -4.0))
	route_ok = route_ok and await _swim_to(maze, diver, Vector3(mouth_x, 0.0, 18.0))
	route_ok = route_ok and await _swim_to(maze, diver, Vector3(mouth_x, 0.0, 24.0))
	var rock := maze.get_node("ItemRock") as Marker3D
	var route := _route_to_reward(diver, rock.global_position)
	for target in route:
		route_ok = route_ok and await _swim_to(maze, diver, target)
	if route_ok and not route.is_empty():
		# Capture the same E input a human reviewer uses at the relic.
		_press(maze, KEY_E)
		# Let the temporary shockwave sphere fade so the capture proves the
		# final reward/completion UI rather than hiding it behind impact VFX.
		await create_timer(0.6).timeout
		for _frame in range(4):
			maze._move_camera(DT)
			await process_frame
	await _capture(complete_path)
	print("maze completion capture %s at %s" % ["clean" if maze.is_completed() and route_ok else "failed", diver.global_position])
	quit(0 if maze.is_completed() and route_ok else 1)
