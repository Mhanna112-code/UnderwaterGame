extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _horizontal_endpoint_gap(maze: MazeLevel, a: CSGBox3D, b: CSGBox3D) -> float:
	var a_geometry: Dictionary = maze._wall_geometry(a)
	var b_geometry: Dictionary = maze._wall_geometry(b)
	var a_negative := a_geometry["negative_end"] as Vector3
	var a_positive := a_geometry["positive_end"] as Vector3
	var b_negative := b_geometry["negative_end"] as Vector3
	var b_positive := b_geometry["positive_end"] as Vector3
	var gap := INF
	for a_end in [a_negative, a_positive]:
		for b_end in [b_negative, b_positive]:
			gap = minf(gap, Vector2(a_end.x, a_end.z).distance_to(Vector2(b_end.x, b_end.z)))
	return gap

# This calculation deliberately lives in the verifier, not MazeLevel: it is
# the independent physical oracle for the public continuation query below.
# A caller of MazeLevel must *not* need to repeat this local-axis work or
# decide which sign means "the end I want".
func _physical_continuation_candidates(moving: CSGBox3D, target: CSGBox3D) -> Array[Dictionary]:
	var target_long_axis := target.global_transform.basis.x.normalized()
	var target_half_length := target.size.x * 0.5
	var moving_half_length := moving.size.x * 0.5
	var negative_end := target.global_position - target_long_axis * target_half_length
	var positive_end := target.global_position + target_long_axis * target_half_length
	return [
		{
			"target_end": "negative",
			"position": negative_end - target_long_axis * moving_half_length,
		},
		{
			"target_end": "positive",
			"position": positive_end + target_long_axis * moving_half_length,
		},
	]

func _verify_named_nearest_continuation(maze: MazeLevel, moving: CSGBox3D, target: CSGBox3D, label: String, findings: Array[String]) -> void:
	var result: Dictionary = maze._nearest_wall_continuation(moving, target)
	var candidates := _physical_continuation_candidates(moving, target)
	var nearest := candidates[0]
	for candidate in candidates:
		var candidate_position := candidate.position as Vector3
		var nearest_position := nearest.position as Vector3
		if moving.global_position.distance_squared_to(candidate_position) <= moving.global_position.distance_squared_to(nearest_position):
			nearest = candidate
	var result_position := result.position as Vector3
	var nearest_position := nearest.position as Vector3
	if result.get("target_end", "") != nearest.get("target_end", "") or result_position.distance_to(nearest_position) > 0.001:
		findings.append("%s nearest continuation query does not name and select the physical nearest target end" % label)

func _xz_rotate(vector: Vector3, yaw: float) -> Vector3:
	var rotated := Vector2(vector.x, vector.z).rotated(-yaw)
	return Vector3(rotated.x, vector.y, rotated.y)

# Solve target = pivot + R(start - pivot) in the X/Z plane.  This is an
# independent geometric construction used to judge the runtime animation,
# not the wall-placement implementation under test.
func _pivot_between(start: Vector3, target: Vector3, yaw: float) -> Vector3:
	var c := cos(yaw)
	var s := sin(yaw)
	var rotated_start := _xz_rotate(start, yaw)
	var rhs := Vector2(target.x - rotated_start.x, target.z - rotated_start.z)
	var determinant := (1.0 - c) * (1.0 - c) + s * s
	if determinant < 0.00001:
		return start
	return Vector3(
		((1.0 - c) * rhs.x + s * rhs.y) / determinant,
		start.y,
		(-s * rhs.x + (1.0 - c) * rhs.y) / determinant
	)

func _xz_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _wall_end_corners(wall: CSGBox3D, positive_end: bool) -> Array[Vector3]:
	var forward := wall.global_transform.basis.x.normalized()
	var side := wall.global_transform.basis.z.normalized()
	var end_center := wall.global_position + forward * wall.size.x * 0.5 * (1.0 if positive_end else -1.0)
	var half_thickness := wall.size.z * 0.5
	return [end_center - side * half_thickness, end_center + side * half_thickness]

func _corner_gap(first: Array[Vector3], second: Array[Vector3]) -> float:
	var gap := INF
	for a in first:
		for b in second:
			gap = minf(gap, _xz_distance(a, b))
	return gap

func _wall_corners(wall: CSGBox3D) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for positive_end in [false, true]:
		corners.append_array(_wall_end_corners(wall, positive_end))
	return corners

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	await process_frame
	var wall_a := maze.get_node("CurrentWall1") as CSGBox3D
	var wall_b := maze.get_node("CurrentWall2") as CSGBox3D
	var target_a := maze.get_node("CSGBox3D") as CSGBox3D
	var target_b := maze.get_node("CurrentWall3") as CSGBox3D
	var wall_6 := maze.get_node("CSGBox3D6") as CSGBox3D
	var wall_7 := maze.get_node("CSGBox3D7") as CSGBox3D
	var findings: Array[String] = []
	var start_yaw_a := wall_a.rotation.y
	var start_yaw_b := wall_b.rotation.y
	var home_a := wall_a.global_position
	var home_b := wall_b.global_position
	# Bug #6: the test talks in named target ends and a physical nearest
	# continuation. It does not pass any boolean local-axis sign to MazeLevel.
	_verify_named_nearest_continuation(maze, wall_a, target_a, "CurrentWall1 → CSGBox3D", findings)
	_verify_named_nearest_continuation(maze, wall_b, target_b, "CurrentWall2 → CurrentWall3", findings)
	var target_wall_a: Dictionary = maze._nearest_wall_continuation(wall_a, target_a)
	var target_wall_b: Dictionary = maze._nearest_wall_continuation(wall_b, target_b)
	var target_position_a := target_wall_a.position as Vector3
	var target_position_b := target_wall_b.position as Vector3
	var target_yaw_a := float(target_wall_a.yaw)
	var target_yaw_b := float(target_wall_b.yaw)
	var pivot_a := _pivot_between(home_a, target_position_a, wrapf(target_yaw_a - start_yaw_a, -PI, PI))
	var pivot_b := _pivot_between(home_b, target_position_b, wrapf(target_yaw_b - start_yaw_b, -PI, PI))
	var radius_a := _xz_distance(home_a, pivot_a)
	var radius_b := _xz_distance(home_b, pivot_b)
	var wall_6_axis := wall_6.global_transform.basis.x.normalized()
	maze._rotate_hallway_1_2()
	await create_timer(0.6).timeout
	var mid_radius_error_a := absf(_xz_distance(wall_a.global_position, pivot_a) - radius_a)
	var mid_radius_error_b := absf(_xz_distance(wall_b.global_position, pivot_b) - radius_b)
	var mid_turn_a := absf(wrapf(wall_a.rotation.y - start_yaw_a, -PI, PI))
	var mid_turn_b := absf(wrapf(wall_b.rotation.y - start_yaw_b, -PI, PI))
	print("mid-swing pivot radius errors %.4f / %.4f, turns %.2f / %.2f" % [mid_radius_error_a, mid_radius_error_b, rad_to_deg(mid_turn_a), rad_to_deg(mid_turn_b)])
	await create_timer(1.4).timeout
	var turn_a := rad_to_deg(wrapf(wall_a.rotation.y - start_yaw_a, -PI, PI))
	var turn_b := rad_to_deg(wrapf(wall_b.rotation.y - start_yaw_b, -PI, PI))
	var gap_a := _horizontal_endpoint_gap(maze, wall_a, target_a)
	var gap_b := _horizontal_endpoint_gap(maze, wall_b, target_b)
	var parallel_a := absf(wall_a.global_transform.basis.x.normalized().dot(target_a.global_transform.basis.x.normalized()))
	var parallel_b := absf(wall_b.global_transform.basis.x.normalized().dot(target_b.global_transform.basis.x.normalized()))
	var wall_6_perpendicular := absf(wall_6_axis.dot(wall_a.global_transform.basis.x.normalized()))
	var wall_a_positive_corners := _wall_end_corners(wall_a, true)
	var wall_a_negative_corners := _wall_end_corners(wall_a, false)
	var positive_end_is_outer := _xz_distance(wall_a_positive_corners[0], target_a.global_position) > _xz_distance(wall_a_negative_corners[0], target_a.global_position)
	var outer_end_corners := wall_a_positive_corners if positive_end_is_outer else wall_a_negative_corners
	var inner_end_corners := wall_a_negative_corners if positive_end_is_outer else wall_a_positive_corners
	var wall_6_outer_gap := _corner_gap(outer_end_corners, _wall_corners(wall_6))
	var wall_6_inner_gap := _corner_gap(inner_end_corners, _wall_corners(wall_6))
	# Marc's follow-up contract: these two static passage boundaries must
	# begin on one cross-line. They may be separated laterally (that is the
	# passage), but must not be staggered along their shared length axis.
	# Measure the final collision geometry rather than either placement helper.
	var wall_7_axis := wall_7.global_transform.basis.x.normalized()
	var csg67_axis_alignment := absf(wall_6_axis.dot(wall_7_axis))
	var csg67_center_delta := wall_7.global_position - wall_6.global_position
	var csg67_longitudinal_stagger := absf(csg67_center_delta.dot(wall_6_axis))
	var csg67_clear_lane_width := absf(csg67_center_delta.dot(wall_6.global_transform.basis.z.normalized())) - (wall_6.size.z + wall_7.size.z) * 0.5
	print("turns %.2f / %.2f, endpoint gaps %.4f / %.4f, parallel %.5f / %.5f" % [turn_a, turn_b, gap_a, gap_b, parallel_a, parallel_b])
	print("CSGBox3D6 physical gaps outer %.4f / CSGBox3D-side %.4f" % [wall_6_outer_gap, wall_6_inner_gap])
	print("CSGBox3D6/7 axis %.5f, longitudinal stagger %.4f, clear lane %.4f" % [csg67_axis_alignment, csg67_longitudinal_stagger, csg67_clear_lane_width])
	if absf(turn_a - 90.0) > 0.02 or absf(turn_b - 90.0) > 0.02:
		findings.append("hallway walls did not rotate exactly 90 degrees")
	if mid_turn_a < 5.0 * PI / 180.0 or mid_turn_a > 85.0 * PI / 180.0 or mid_turn_b < 5.0 * PI / 180.0 or mid_turn_b > 85.0 * PI / 180.0:
		findings.append("mid-swing sample did not occur during the hallway rotation")
	if mid_radius_error_a > 0.05 or mid_radius_error_b > 0.05:
		findings.append("moving walls do not preserve their attachment pivots during the hallway swing")
	if wall_a.global_position.distance_to(target_position_a) > 0.02 or wall_b.global_position.distance_to(target_position_b) > 0.02:
		findings.append("arc motion does not finish at the precomputed flush transforms")
	if gap_a > 0.02 or parallel_a < 0.9999:
		findings.append("CurrentWall1 is not flush and parallel with CSGBox3D")
	if gap_b > 0.02 or parallel_b < 0.9999:
		findings.append("CurrentWall2 is not flush and parallel with CurrentWall3")
	if wall_6_outer_gap > 0.02 or wall_6_inner_gap < wall_a.size.x * 0.5 or wall_6_perpendicular > 0.0001:
		findings.append("CSGBox3D6 does not meet CurrentWall1's rotated outer join")
	if csg67_axis_alignment < 0.9999 or csg67_longitudinal_stagger > 0.02 or csg67_clear_lane_width < maze._diver.radius * 2.0:
		findings.append("CSGBox3D6/7 do not share an aligned, swimmable passage cross-line")
	maze._rotate_hallway_1_2()
	await create_timer(1.4).timeout
	if wall_a.global_position.distance_to(home_a) > 0.02 or wall_b.global_position.distance_to(home_b) > 0.02 or absf(wrapf(wall_a.rotation.y - start_yaw_a, -PI, PI)) > 0.0001 or absf(wrapf(wall_b.rotation.y - start_yaw_b, -PI, PI)) > 0.0001:
		findings.append("H open-close does not restore the hallway wall transforms")
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE ROTATION: clean" if findings.is_empty() else "MAZE ROTATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
