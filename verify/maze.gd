extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _min_distance(maze: MazeLevel, a: CSGBox3D, b: CSGBox3D) -> float:
	var result := INF
	for a_positive in [false, true]:
		for b_positive in [false, true]:
			var a_end := maze._wall_endpoint(a, a_positive)
			var b_end := maze._wall_endpoint(b, b_positive)
			result = minf(result, Vector2(a_end.x, a_end.z).distance_to(Vector2(b_end.x, b_end.z)))
	return result

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	await process_frame
	maze._rotate_hallway_1_2()
	await create_timer(1.4).timeout
	var connector := maze.get_node("CurrentWall2") as CSGBox3D
	var rotated := maze.get_node("CurrentWall1") as CSGBox3D
	var destination := maze.get_node("CurrentWall3") as CSGBox3D
	var findings: Array[String] = []
	print("connector->rotated %.4f, connector->destination %.4f" % [
		_min_distance(maze, connector, rotated), _min_distance(maze, connector, destination)])
	if _min_distance(maze, connector, rotated) > 0.02:
		findings.append("connector does not meet the rotated hallway")
	if _min_distance(maze, connector, destination) > 0.02:
		findings.append("connector does not meet the destination wall")
	if not is_equal_approx(connector.size.y, destination.size.y):
		findings.append("connector height does not match the destination")
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE ALIGNMENT: clean" if findings.is_empty() else "MAZE ALIGNMENT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
