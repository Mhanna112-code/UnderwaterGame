extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _horizontal_endpoint_gap(maze: MazeLevel, a: CSGBox3D, b: CSGBox3D) -> float:
	var gap := INF
	for a_positive in [false, true]:
		for b_positive in [false, true]:
			var a_end := maze._wall_endpoint(a, a_positive)
			var b_end := maze._wall_endpoint(b, b_positive)
			gap = minf(gap, Vector2(a_end.x, a_end.z).distance_to(Vector2(b_end.x, b_end.z)))
	return gap

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
	var start_yaw_a := wall_a.rotation.y
	var start_yaw_b := wall_b.rotation.y
	var home_a := wall_a.global_position
	var home_b := wall_b.global_position
	var target_wall_a := maze._wall_flush_target(wall_a, target_a)
	var target_wall_b := maze._wall_flush_target(wall_b, target_b)
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
	var findings: Array[String] = []
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
	print("turns %.2f / %.2f, endpoint gaps %.4f / %.4f, parallel %.5f / %.5f" % [turn_a, turn_b, gap_a, gap_b, parallel_a, parallel_b])
	print("CSGBox3D6 physical gaps outer %.4f / CSGBox3D-side %.4f" % [wall_6_outer_gap, wall_6_inner_gap])
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
	maze._rotate_hallway_1_2()
	await create_timer(1.4).timeout
	if wall_a.global_position.distance_to(home_a) > 0.02 or wall_b.global_position.distance_to(home_b) > 0.02 or absf(wrapf(wall_a.rotation.y - start_yaw_a, -PI, PI)) > 0.0001 or absf(wrapf(wall_b.rotation.y - start_yaw_b, -PI, PI)) > 0.0001:
		findings.append("H open-close does not restore the hallway wall transforms")
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE ROTATION: clean" if findings.is_empty() else "MAZE ROTATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
