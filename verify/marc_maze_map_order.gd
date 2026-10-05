extends SceneTree
## MAP-3: actual arrow cycles must follow spatial order, not node names.
var findings: Array[String] = []
var maze: MazeLevel
var map: MazeMiniMap
var centre: Vector2
var cases := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	# Presentation fixture, not claimed as physical traversal. No save IO.
	maze.set_physics_process(false)
	maze._diver.global_position = Vector3(2000, 0, 2000)
	map = maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	# Independent spatial origin: the continuous physical floor is centered
	# on the complete maze footprint. Do not call the map's angle/sort helper.
	var floor_y := INF
	for body in maze.get_children():
		if body is StaticBody3D:
			for shape in body.get_children():
				if shape is CollisionShape3D and shape.shape is BoxShape3D:
					if shape.shape.size.x > 100 and shape.shape.size.z > 100 and shape.global_position.y < floor_y:
						floor_y = shape.global_position.y
						centre = Vector2(shape.global_position.x, shape.global_position.z)
	_expect(not is_inf(floor_y), "MAP-3 fixture could not identify the complete maze floor")
	var sets := maze.rotatable_wall_sets()
	var currents := maze._currents_by_corridor.keys()
	for mask in range(1 << sets.size()):
		var data := _empty_discovery()
		var expected: Array[String] = []
		for i in sets.size():
			if mask & (1 << i):
				expected.append(sets[i].name)
				for wall in sets[i].walls:
					data.walls.append(String(wall.name))
		await _prepare(data)
		await _cycle(expected, false)
	for mask in range(1 << currents.size()):
		var data := _empty_discovery()
		var expected: Array[String] = []
		for i in currents.size():
			if mask & (1 << i):
				data.corridors.append(String(currents[i].name))
				expected.append(String(currents[i].name))
		await _prepare(data)
		await _cycle(expected, true)
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC MAP CLOCKWISE: clean|generated_subsets=%d" % cases if findings.is_empty() else "MARC MAP CLOCKWISE: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _empty_discovery() -> Dictionary:
	return {"walls": [], "rooms": [], "corridors": [], "halls": [], "count": 0, "pois": []}

func _prepare(data: Dictionary) -> void:
	if map.main_map.visible:
		await _key(KEY_L)
	map.restore_campaign_discovery(data)
	await process_frame
	await _key(KEY_L)

func _cycle(expected: Array[String], current: bool) -> void:
	cases += 1
	var forward: Array[String] = []
	var points: Array[Vector2] = []
	for step in maxi(expected.size(), 1):
		await _key(KEY_RIGHT, current)
		var selected := _selection(current)
		if not expected.is_empty():
			forward.append(selected)
			points.append(_position(current))
		else:
			_expect(selected.is_empty(), "MAP-3 empty discovery selects hidden content")
	for id in expected:
		_expect(forward.count(id) == 1, "MAP-3 arrow cycle skips/repeats discovered " + id)
	for id in forward:
		_expect(expected.has(id), "MAP-3 arrow selects undiscovered " + id)
	var wraps := 0
	for i in points.size():
		if _after(points[i] - centre, points[(i+1) % points.size()] - centre):
			wraps += 1
	_expect(points.size() < 2 or wraps == 1, "MAP-3 Right cycle is not clockwise (including its wrap): " + str(forward))
	if not expected.is_empty():
		await _key(KEY_RIGHT, current)
		_expect(_selection(current) == forward[0], "MAP-3 full cycle does not wrap exactly once")
		for i in range(forward.size()-1, -1, -1):
			await _key(KEY_LEFT, current)
			_expect(_selection(current) == forward[i], "MAP-3 Left does not reverse the same spatial cycle")

# Quadrants and oriented area, not product atan2/angle helpers.
func _after(a: Vector2, b: Vector2) -> bool:
	var a_half := 0 if a.y > 0 or (is_zero_approx(a.y) and a.x >= 0) else 1
	var b_half := 0 if b.y > 0 or (is_zero_approx(b.y) and b.x >= 0) else 1
	return a_half > b_half if a_half != b_half else a.cross(b) < -0.001

func _selection(current: bool) -> String:
	if current:
		return String(map.selectedCurrentCorridor.name) if map.selectedCurrentCorridor != null else ""
	return String(map.selected_rotatable_set.get("name", ""))

func _position(current: bool) -> Vector2:
	if current:
		for shape in map.selectedCurrentCorridor.get_children():
			if shape is CollisionShape3D:
				return Vector2(shape.global_position.x, shape.global_position.z)
	var sum := Vector2.ZERO
	for wall in map.selected_rotatable_set.walls:
		sum += Vector2(wall.global_position.x, wall.global_position.z)
	return sum / map.selected_rotatable_set.walls.size()

func _key(code: Key, ctrl := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.ctrl_pressed = ctrl
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = InputEventKey.new()
	e.keycode = code
	Input.parse_input_event(e)
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
