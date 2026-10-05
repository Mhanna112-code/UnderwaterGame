extends SceneTree

# Slice-4 map truth contract.  This is intentionally a production-widget
# test: it reads MazeMiniMap's Line2D points after a real `H` change rather
# than comparing a separate planning model or a screenshot.

const EPSILON := 0.02

func _initialize() -> void:
	call_deferred("_run")

func _key(keycode: Key, ctrl := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	return event

func _line_for_wall(minimap: MazeMiniMap, wall: CSGBox3D) -> Line2D:
	var hall_name: String = minimap._wall_to_hall.get(wall, "")
	if hall_name == "":
		return minimap._main_map_lone_lines.get(wall, null) as Line2D
	if not minimap._main_map_hall_lines.has(hall_name) or not minimap._hall_walls.has(hall_name):
		return null
	var walls: Array[CSGBox3D] = minimap._hall_walls[hall_name]
	var index := walls.find(wall)
	if index < 0:
		return null
	var lines: Array[Line2D] = minimap._main_map_hall_lines[hall_name]
	return lines[index] if index < lines.size() else null

func _points_match(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return a.size() == b.size() and a.size() >= 2 and a[0].distance_to(b[0]) <= EPSILON and a[a.size() - 1].distance_to(b[b.size() - 1]) <= EPSILON

func _reveal_all(minimap: MazeMiniMap, maze: MazeLevel) -> void:
	var diver := maze._diver
	var home := diver.global_position
	for corridor in maze.corridors:
		diver.global_position = minimap._corridor_center(corridor)
		minimap._update_revealed()
		await process_frame
	diver.global_position = home
	minimap._refresh_main_map()

func _assert_current_truth(minimap: MazeMiniMap, maze: MazeLevel, findings: Array[String], phase: String) -> void:
	if minimap.get("_main_map_current_lines") == null:
		findings.append("%s: minimap has no persistent rendered current overlays" % phase)
		return
	var lines: Dictionary = minimap.get("_main_map_current_lines") as Dictionary
	if lines.size() != maze._currents_by_corridor.size():
		findings.append("%s: map shows %d current overlays but runtime owns %d" % [phase, lines.size(), maze._currents_by_corridor.size()])
	for corridor in maze._currents_by_corridor:
		if not lines.has(corridor):
			findings.append("%s: active %s has no map overlay" % [phase, (corridor as Area3D).name])
			continue
		var current := maze._currents_by_corridor[corridor] as WaterCurrent
		var shape: CollisionShape3D
		for child in corridor.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				shape = child
		if shape == null:
			findings.append("%s: physical current has no Box push volume" % phase)
			continue
		var rendered := (lines[corridor] as Line2D).points
		if rendered.size() < 2:
			findings.append("MAP-4 live current has no rendered directional line")
			continue
		var shown := rendered[-1] - rendered[0]
		var centre := Vector2(shape.global_position.x, shape.global_position.z)
		var expected_centre := Vector2(MazeMiniMap.MAIN_MAP_MARGIN, MazeMiniMap.MAIN_MAP_HEADER) + (centre - minimap._main_map_origin) * minimap._main_map_px_per_unit
		if ((rendered[0] + rendered[-1]) * 0.5).distance_to(expected_centre) > EPSILON:
			findings.append("MAP-4 %s symbolic flow is not centered on its physical push volume" % corridor.name)
		var physical_direction := Vector2(current.orientation.x, current.orientation.z).normalized()
		if shown.normalized().dot(physical_direction) < 0.999:
			findings.append("MAP-4 %s arrow reverses its physical flow" % corridor.name)
		# Independent corner projection, not the product's flow-path helper.
		var lo := INF
		var hi := -INF
		for x in [-0.5, 0.5]:
			for y in [-0.5, 0.5]:
				for z in [-0.5, 0.5]:
					var corner: Vector3 = shape.global_transform * (shape.shape.size * Vector3(x, y, z))
					var distance := Vector2(corner.x, corner.z).dot(physical_direction)
					lo = minf(lo, distance)
					hi = maxf(hi, distance)
		var largest_valid_length := maxf(44.0, (hi - lo) * minimap._main_map_px_per_unit)
		if shown.length() < 44.0 - EPSILON or shown.length() > largest_valid_length + EPSILON:
			findings.append("MAP-4 %s line length %.2f is unreadable or overstates its physical extent (44..%.2f)" % [corridor.name, shown.length(), largest_valid_length])

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	# Always the normal entrance start, whichever developer spawn is switched on.
	maze.dev_spawn_at_sphere_room = false
	maze.dev_spawn_at_boss_rooms = false
	maze.dev_spawn_at_switch = false
	root.add_child(maze)
	for _frame in range(4):
		await process_frame
	var minimap := maze.get_node_or_null("HUD/MazeMiniMap") as MazeMiniMap
	var findings: Array[String] = []
	if minimap == null:
		findings.append("MazeLevel does not expose a named MazeMiniMap to review")
	else:
		# MAP-FOG-06: before exploration, no current information should leak.
		var initial_current_lines: Variant = minimap.get("_main_map_current_lines")
		if initial_current_lines != null and not (initial_current_lines as Dictionary).is_empty():
			findings.append("undiscovered maze exposes current overlays before a corridor is seen")
		minimap._unhandled_input(_key(KEY_L))
		if minimap.main_map == null or not minimap.main_map.visible:
			findings.append("M does not open the large maze map")
		await _reveal_all(minimap, maze)
		_assert_current_truth(minimap, maze, findings, "closed")
		if minimap.main_map.get_node_or_null("MazeMapTitle") == null or minimap.main_map.get_node_or_null("MazeMapLegend") == null:
			findings.append("large map lacks its reviewable title or flow legend")

		var wall := maze.get_node("CurrentWall1") as CSGBox3D
		var wall_line := _line_for_wall(minimap, wall)
		if wall_line == null:
			findings.append("CurrentWall1 has no overview line after discovery")
		else:
			var before_points := wall_line.points
			# Walls only rotate from the map now; H itself must do nothing.
			maze._unhandled_input(_key(KEY_H))
			if maze._hallway_1_2_swung:
				findings.append("H still rotates CurrentWall1/2 outside the map")
			maze._rotate_hallway_1_2()
			# Wait for the swing itself to finish (it locks further rotation
			# while moving) rather than a fixed time that a slow frame can beat.
			var swing_deadline := Time.get_ticks_msec() + 3000
			while not maze._moving_wall_sets.is_empty() and Time.get_ticks_msec() < swing_deadline:
				await process_frame
			await process_frame
			minimap._refresh_main_map()
			var actual_segment: Array = minimap._box_segment(wall)
			var expected_wall := PackedVector2Array([minimap._project_to_main_map(actual_segment[0]), minimap._project_to_main_map(actual_segment[1])])
			if _points_match(before_points, wall_line.points):
				findings.append("CurrentWall1 overview line stays at its closed position after H")
			if not _points_match(wall_line.points, expected_wall):
				findings.append("CurrentWall1 overview line does not match its post-H collision transform")
			_assert_current_truth(minimap, maze, findings, "open")
			var corridor_1 := maze.get_node("WindCorridor1") as Area3D
			var corridor_3 := maze.get_node("WindCorridor3") as Area3D
			var corridor_4 := maze.get_node("WindCorridor4") as Area3D
			if not maze._currents_by_corridor.has(corridor_1) or not maze._currents_by_corridor.has(corridor_3):
				findings.append("H moved a current - it should only swing CurrentWall1/2")
			elif (maze._currents_by_corridor[corridor_3] as WaterCurrent).orientation.dot(Vector3(0, 0, -1)) < 0.999:
				findings.append("Corridor3 does not start with a southbound (-Z) current")
			maze._toggle_current_3_to_4()
			minimap._refresh_main_map()
			if maze._currents_by_corridor.has(corridor_3) or not maze._currents_by_corridor.has(corridor_4):
				findings.append("V does not move Corridor3's current into Corridor4")
			else:
				var southbound := maze._currents_by_corridor[corridor_4] as WaterCurrent
				if southbound.orientation.dot(Vector3(0, 0, -1)) < 0.999:
					findings.append("Corridor4 current is not southbound (-Z) after V")
			_assert_current_truth(minimap, maze, findings, "after V")

			# MAP-ROTATE: the nearest rotatable set is selected, its walls blink,
			# and E on the open map rotates it (here: closes the hallway again).
			maze._diver.global_position = (maze.get_node("CurrentWall1") as CSGBox3D).global_position + Vector3(3, 0, 0)
			minimap._update_selected_rotatable_set()
			if String(minimap.selected_rotatable_set.get("name", "")) != "CurrentWall1/2":
				findings.append("CurrentWall1/2 is not the selected rotatable set when the diver is beside it")
			var was_swung := maze._hallway_1_2_swung
			minimap._unhandled_input(_key(KEY_E))
			if maze._hallway_1_2_swung == was_swung:
				findings.append("E on the open map does not rotate the selected wall set")
			maze._diver.global_position = Vector3(500, 0, 500)
			minimap._update_selected_rotatable_set()
			if not minimap.selected_rotatable_set.is_empty():
				findings.append("a rotatable set stays selected with the diver far away")

			# MAP-CURRENT: Ctrl+arrows move the current selection, and Ctrl+E
			# rotates the selected current to its paired corridor.
			var before_current: Variant = minimap.selectedCurrentCorridor
			minimap._unhandled_input(_key(KEY_RIGHT, true))
			if minimap.selectedCurrentCorridor == null or minimap.selectedCurrentCorridor == before_current:
				findings.append("Ctrl+Right does not select a different current")
			minimap.selectedCurrentCorridor = corridor_4
			minimap._unhandled_input(_key(KEY_E, true))
			if not maze._currents_by_corridor.has(corridor_3) or maze._currents_by_corridor.has(corridor_4):
				findings.append("Ctrl+E does not rotate the selected Corridor4 current back to Corridor3")
			elif minimap.selectedCurrentCorridor != corridor_3:
				findings.append("the rotated current is not still selected in its new corridor")

	for finding in findings:
		push_error(finding)
	print("MAZE MINIMAP: clean" if findings.is_empty() else "MAZE MINIMAP: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
