extends SceneTree

# Slice-4 map truth contract.  This is intentionally a production-widget
# test: it reads MazeMiniMap's Line2D points after a real `H` change rather
# than comparing a separate planning model or a screenshot.

const EPSILON := 0.02

func _initialize() -> void:
	call_deferred("_run")

func _key(keycode: Key, shift := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.shift_pressed = shift
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

# The current overlay is a wavy polyline, so only its two ends have to match
# the live flow path.
func _endpoints_match(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return a.size() >= 2 and b.size() >= 2 and a[0].distance_to(b[0]) <= EPSILON and a[a.size() - 1].distance_to(b[b.size() - 1]) <= EPSILON

func _reveal_all(minimap: MazeMiniMap, maze: MazeLevel) -> void:
	var diver := maze._diver
	var home := diver.global_position
	for corridor in maze.corridors:
		diver.global_position = minimap._corridor_center(corridor)
		minimap._update_revealed()
		await process_frame
	diver.global_position = home
	minimap._refresh_main_map()

func _expected_flow_points(minimap: MazeMiniMap, corridor: Area3D, current: WaterCurrent) -> PackedVector2Array:
	var path: PackedVector3Array = minimap.call("_flow_path_for_corridor", corridor, current) as PackedVector3Array
	var points := PackedVector2Array()
	for point in path:
		points.append(minimap._project_to_main_map(point))
	return points

func _assert_current_truth(minimap: MazeMiniMap, maze: MazeLevel, findings: Array[String], phase: String) -> void:
	if not minimap.has_method("_flow_path_for_corridor"):
		findings.append("%s: minimap has no flow path sourced from live WaterCurrent state" % phase)
		return
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
		var path: PackedVector3Array = minimap.call("_flow_path_for_corridor", corridor as Area3D, current) as PackedVector3Array
		if path.size() < 2:
			findings.append("%s: active %s produced no directional path" % [phase, (corridor as Area3D).name])
			continue
		var rendered := (lines[corridor] as Line2D).points
		var expected := _expected_flow_points(minimap, corridor as Area3D, current)
		if not _endpoints_match(rendered, expected):
			findings.append("%s: rendered flow for %s does not match its live collision area" % [phase, (corridor as Area3D).name])
		var shown_direction: Vector3 = (path[path.size() - 1] - path[0]).normalized()
		if shown_direction.dot(current.orientation.normalized()) < 0.999:
			findings.append("%s: rendered flow for %s points away from WaterCurrent.orientation" % [phase, (corridor as Area3D).name])

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
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
		if minimap.main_map.get_node_or_null("MazeMapTitle") == null or minimap.main_map.get_node_or_null("MazeMapLegend") == null or minimap.main_map.get_node_or_null("MazeMapObjective") == null:
			findings.append("large map lacks its reviewable title, flow legend, or H/relic objective")

		var wall := maze.get_node("CurrentWall1") as CSGBox3D
		var wall_line := _line_for_wall(minimap, wall)
		if wall_line == null:
			findings.append("CurrentWall1 has no overview line after discovery")
		else:
			var before_points := wall_line.points
			maze._unhandled_input(_key(KEY_H))
			await create_timer(1.4).timeout
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
			maze._unhandled_input(_key(KEY_V))
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

			# MAP-CURRENT: Shift+arrows move the current selection, and R
			# rotates the selected current to its paired corridor.
			var before_current: Variant = minimap.selectedCurrentCorridor
			minimap._unhandled_input(_key(KEY_RIGHT, true))
			if minimap.selectedCurrentCorridor == null or minimap.selectedCurrentCorridor == before_current:
				findings.append("Shift+Right does not select a different current")
			minimap.selectedCurrentCorridor = corridor_4
			minimap._unhandled_input(_key(KEY_R))
			if not maze._currents_by_corridor.has(corridor_3) or maze._currents_by_corridor.has(corridor_4):
				findings.append("R does not rotate the selected Corridor4 current back to Corridor3")
			elif minimap.selectedCurrentCorridor != corridor_3:
				findings.append("the rotated current is not still selected in its new corridor")

	for finding in findings:
		push_error(finding)
	print("MAZE MINIMAP: clean" if findings.is_empty() else "MAZE MINIMAP: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
