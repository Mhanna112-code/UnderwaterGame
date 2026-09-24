# Usage: godot --headless --path . --script verify/wall12_placement.gd
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

	var wall_2: CSGBox3D = level.get_node("CurrentWall2")
	var wall_3: CSGBox3D = level.get_node("CurrentWall3")
	var wall_12: CSGBox3D = level.get_node("CSGBox3D12")
	var wall_13: CSGBox3D = level.get_node("CSGBox3D13")

	print("CurrentWall2 pos=%s yaw=%.3f" % [wall_2.global_position, wall_2.rotation.y])
	print("CurrentWall3 pos=%s yaw=%.3f" % [wall_3.global_position, wall_3.rotation.y])
	print("CSGBox3D12   pos=%s yaw=%.3f" % [wall_12.global_position, wall_12.rotation.y])
	print("CSGBox3D13   pos=%s yaw=%.3f" % [wall_13.global_position, wall_13.rotation.y])

	# Box12's own rotation is its authored orientation from the scene, no
	# longer computed/forced by the script - so there's no fixed relationship
	# to assert against CurrentWall2's post-swing yaw here.
	var wall2_target: Dictionary = level._nearest_wall_continuation(wall_2, wall_3)

	# Box12 attaches to CurrentWall2's future outer end by ONE OF ITS OWN
	# ends (moving_anchor_end=NEGATIVE in the real code), not by its center -
	# it's perpendicular to Wall2/Wall3's corridor, so its center is expected
	# to sit a full half-length away from the touch point along its own long
	# axis. Checking "distance from Box12's CENTER to the touch point ~= 0"
	# was the wrong invariant (that's only true for a wall continuing
	# colinearly, like Box6/Wall1). The real invariant: whichever of Box12's
	# own two ends _position_beyond_wall_end() is documented to anchor should
	# land on the touch point, modulo the small clearance/thickness terms the
	# formula itself adds (source thickness + Box12's own thickness).
	var wall2_future: Dictionary = level._wall_geometry_at(wall2_target.position as Vector3, float(wall2_target.yaw), wall_2.size)
	var wall_3_geometry: Dictionary = level._wall_geometry(wall_3)
	var wall2_attach_point: Vector3 = level._wall_end(wall_3_geometry,
		MazeLevel.WallEnd.POSITIVE if String(wall2_target.target_end) == "positive" else MazeLevel.WallEnd.NEGATIVE)
	var wall2_negative_end := wall2_future["negative_end"] as Vector3
	var wall2_positive_end := wall2_future["positive_end"] as Vector3
	var wall2_outer_end := wall2_negative_end if wall2_negative_end.distance_squared_to(wall2_attach_point) > wall2_positive_end.distance_squared_to(wall2_attach_point) else wall2_positive_end

	var wall_12_geometry: Dictionary = level._wall_geometry(wall_12)
	var wall12_negative_end := wall_12_geometry["negative_end"] as Vector3
	var wall12_positive_end := wall_12_geometry["positive_end"] as Vector3
	var touching_end := wall12_negative_end if wall12_negative_end.distance_to(wall2_outer_end) < wall12_positive_end.distance_to(wall2_outer_end) else wall12_positive_end
	var gap := touching_end.distance_to(wall2_outer_end)
	print("distance from Box12's nearer end to Wall2's future outer end (should be small, within clearance terms): %.4f" % gap)
	_check(gap < 2.0, "CSGBox3D12 is not flush against CurrentWall2's hypothetical post-swing end (residual gap %.4f)" % gap)

	# And its CENTER should be roughly a half-length away from that same
	# touch point along its own long axis - confirms it's oriented and
	# anchored the way an end-attached perpendicular wall should be, not
	# just coincidentally close by some other placement.
	var expected_center_distance := wall_12.size.x * 0.5
	var actual_center_distance := wall_12.global_position.distance_to(wall2_outer_end)
	print("distance from Box12's center to touch point (expect ~= half its own length %.3f): %.4f" % [expected_center_distance, actual_center_distance])
	_check(absf(actual_center_distance - expected_center_distance) < 2.0,
		"CSGBox3D12's center is not the expected half-length away from the touch point (expected ~%.3f, got %.4f)" % [expected_center_distance, actual_center_distance])

	# Box13 should be laterally offset from Box12 (a real lane width), not
	# co-located with it.
	var lane_width := wall_13.global_position.distance_to(wall_12.global_position)
	print("Box12<->Box13 separation: %.3f" % lane_width)
	_check(lane_width > 0.5, "CSGBox3D13 ended up on top of CSGBox3D12 instead of offset by a real lane width (%.3f)" % lane_width)

	# No overlap between Box12/13 and any other authored wall box - the same
	# class of bug this whole flush-join system was built to catch.
	for other_name in ["CSGBox3D", "CurrentWall1", "CSGBox3D6", "CSGBox3D7", String(wall_2.name), String(wall_3.name)]:
		var other: CSGBox3D = level.get_node_or_null(other_name)
		if other == null or other == wall_12 or other == wall_13:
			continue
		for mover_name in ["CSGBox3D12", "CSGBox3D13"]:
			var mover: CSGBox3D = level.get_node(mover_name)
			var d := mover.global_position.distance_to(other.global_position)
			var min_clear := (mover.size.x + other.size.x) * 0.25
			if d < min_clear:
				findings.append("%s and %s are suspiciously close (%.2f apart, expected at least ~%.2f) - possible overlap" % [mover_name, other.name, d, min_clear])

	for finding in findings:
		print("FINDING  " + finding)
	print("WALL12 PLACEMENT: clean" if findings.is_empty() else "WALL12 PLACEMENT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
