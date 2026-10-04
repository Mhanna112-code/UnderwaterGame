# Usage: godot --headless --path . --script verify/wall6_placement.gd
extends SceneTree

var findings: Array[String] = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	var wall_a: CSGBox3D = level.get_node("CurrentWall1")
	var wall_orig: CSGBox3D = level.get_node("CSGBox3D")
	var wall_6: CSGBox3D = level.get_node("CSGBox3D6")
	var wall_7: CSGBox3D = level.get_node("CSGBox3D7")

	var wall1_target: Dictionary = level._nearest_wall_continuation(wall_a, wall_orig)
	var wall1_future: Dictionary = level._wall_geometry_at(wall1_target.position as Vector3, float(wall1_target.yaw), wall_a.size)
	var wall_orig_geometry: Dictionary = level._wall_geometry(wall_orig)
	var wall1_attach_point: Vector3 = level._wall_end(wall_orig_geometry,
		MazeLevel.WallEnd.POSITIVE if String(wall1_target.target_end) == "positive" else MazeLevel.WallEnd.NEGATIVE)
	var wall1_negative_end := wall1_future["negative_end"] as Vector3
	var wall1_positive_end := wall1_future["positive_end"] as Vector3
	var wall1_outer_end := wall1_negative_end if wall1_negative_end.distance_squared_to(wall1_attach_point) > wall1_positive_end.distance_squared_to(wall1_attach_point) else wall1_positive_end

	var wall_6_geometry: Dictionary = level._wall_geometry(wall_6)
	var wall6_negative_end := wall_6_geometry["negative_end"] as Vector3
	var wall6_positive_end := wall_6_geometry["positive_end"] as Vector3
	var touching_end := wall6_negative_end if wall6_negative_end.distance_to(wall1_outer_end) < wall6_positive_end.distance_to(wall1_outer_end) else wall6_positive_end
	var gap := touching_end.distance_to(wall1_outer_end)
	print("distance from Box6's nearer end to Wall1's future outer end (should be small): %.4f" % gap)
	_check(gap < 2.0, "CSGBox3D6 is not flush against CurrentWall1's hypothetical post-swing end (residual gap %.4f)" % gap)

	var expected_center_distance := wall_6.size.x * 0.5
	var actual_center_distance := wall_6.global_position.distance_to(wall1_outer_end)
	print("distance from Box6's center to touch point (expect ~= half its own length %.3f): %.4f" % [expected_center_distance, actual_center_distance])
	_check(absf(actual_center_distance - expected_center_distance) < 2.0,
		"CSGBox3D6's center is not the expected half-length away from the touch point (expected ~%.3f, got %.4f)" % [expected_center_distance, actual_center_distance])

	var lane_width := wall_7.global_position.distance_to(wall_6.global_position)
	print("Box6<->Box7 separation: %.3f" % lane_width)
	_check(lane_width > 0.5, "CSGBox3D7 ended up on top of CSGBox3D6 instead of offset by a real lane width (%.3f)" % lane_width)

	for finding in findings:
		print("FINDING  " + finding)
	print("WALL6 PLACEMENT: clean" if findings.is_empty() else "WALL6 PLACEMENT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
