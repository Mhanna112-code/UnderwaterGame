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

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	await process_frame
	var wall_a := maze.get_node("CurrentWall1") as CSGBox3D
	var wall_b := maze.get_node("CurrentWall2") as CSGBox3D
	var target_a := maze.get_node("CSGBox3D") as CSGBox3D
	var target_b := maze.get_node("CurrentWall3") as CSGBox3D
	var start_yaw_a := wall_a.rotation.y
	var start_yaw_b := wall_b.rotation.y
	maze._rotate_hallway_1_2()
	await create_timer(1.4).timeout
	var findings: Array[String] = []
	var turn_a := rad_to_deg(wrapf(wall_a.rotation.y - start_yaw_a, -PI, PI))
	var turn_b := rad_to_deg(wrapf(wall_b.rotation.y - start_yaw_b, -PI, PI))
	var gap_a := _horizontal_endpoint_gap(maze, wall_a, target_a)
	var gap_b := _horizontal_endpoint_gap(maze, wall_b, target_b)
	var parallel_a := absf(wall_a.global_transform.basis.x.normalized().dot(target_a.global_transform.basis.x.normalized()))
	var parallel_b := absf(wall_b.global_transform.basis.x.normalized().dot(target_b.global_transform.basis.x.normalized()))
	print("turns %.2f / %.2f, endpoint gaps %.4f / %.4f, parallel %.5f / %.5f" % [turn_a, turn_b, gap_a, gap_b, parallel_a, parallel_b])
	if absf(turn_a - 90.0) > 0.02 or absf(turn_b - 90.0) > 0.02:
		findings.append("hallway walls did not rotate exactly 90 degrees")
	if gap_a > 0.02 or parallel_a < 0.9999:
		findings.append("CurrentWall1 is not flush and parallel with CSGBox3D")
	if gap_b > 0.02 or parallel_b < 0.9999:
		findings.append("CurrentWall2 is not flush and parallel with CurrentWall3")
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE ROTATION: clean" if findings.is_empty() else "MAZE ROTATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
