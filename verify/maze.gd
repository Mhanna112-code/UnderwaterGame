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

# CSGBox3D6 is the fixed wall that closes the alternate corridor.  It must
# meet CurrentWall1's far edge after that wall performs its H-key turn, not
# be offset from the original CSGBox3D in a world-space direction.
func _expected_perpendicular_flush(maze: MazeLevel, wall_a: CSGBox3D, wall_6: CSGBox3D, target: CSGBox3D) -> Vector3:
	var wall_a_target := maze._wall_flush_target(wall_a, target)
	var future_yaw := float(wall_a_target.yaw)
	var future_center := wall_a_target.position as Vector3
	var forward := Basis(Vector3.UP, future_yaw).x.normalized()
	var far_end := future_center + forward * wall_a.size.x * 0.5
	var b_forward := Basis(Vector3.UP, future_yaw + PI * 0.5).x.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x)
	return far_end + forward * wall_6.size.z * 0.5 - b_forward * wall_6.size.x * 0.5 - side * wall_a.size.z * 0.5

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
	var expected_wall_6 := _expected_perpendicular_flush(maze, wall_a, wall_6, target_a)
	var wall_6_axis := wall_6.global_transform.basis.x.normalized()
	var future_wall_1_axis := Basis(Vector3.UP, float(maze._wall_flush_target(wall_a, target_a).yaw)).x.normalized()
	maze._rotate_hallway_1_2()
	await create_timer(1.4).timeout
	var findings: Array[String] = []
	var turn_a := rad_to_deg(wrapf(wall_a.rotation.y - start_yaw_a, -PI, PI))
	var turn_b := rad_to_deg(wrapf(wall_b.rotation.y - start_yaw_b, -PI, PI))
	var gap_a := _horizontal_endpoint_gap(maze, wall_a, target_a)
	var gap_b := _horizontal_endpoint_gap(maze, wall_b, target_b)
	var parallel_a := absf(wall_a.global_transform.basis.x.normalized().dot(target_a.global_transform.basis.x.normalized()))
	var parallel_b := absf(wall_b.global_transform.basis.x.normalized().dot(target_b.global_transform.basis.x.normalized()))
	var wall_6_position_error := wall_6.global_position.distance_to(expected_wall_6)
	var wall_6_perpendicular := absf(wall_6_axis.dot(future_wall_1_axis))
	print("turns %.2f / %.2f, endpoint gaps %.4f / %.4f, parallel %.5f / %.5f" % [turn_a, turn_b, gap_a, gap_b, parallel_a, parallel_b])
	if absf(turn_a - 90.0) > 0.02 or absf(turn_b - 90.0) > 0.02:
		findings.append("hallway walls did not rotate exactly 90 degrees")
	if gap_a > 0.02 or parallel_a < 0.9999:
		findings.append("CurrentWall1 is not flush and parallel with CSGBox3D")
	if gap_b > 0.02 or parallel_b < 0.9999:
		findings.append("CurrentWall2 is not flush and parallel with CurrentWall3")
	if wall_6_position_error > 0.02 or wall_6_perpendicular > 0.0001:
		findings.append("CSGBox3D6 is not flush and perpendicular to CurrentWall1's rotated far end (error %.3f, dot %.5f)" % [wall_6_position_error, wall_6_perpendicular])
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE ROTATION: clean" if findings.is_empty() else "MAZE ROTATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
