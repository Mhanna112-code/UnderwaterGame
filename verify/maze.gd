extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	await process_frame
	var wall_a := maze.get_node("CurrentWall1") as CSGBox3D
	var wall_b := maze.get_node("CurrentWall2") as CSGBox3D
	var pivot := maze._wall_endpoint(wall_a)
	var start_yaw_a := wall_a.rotation.y
	var start_yaw_b := wall_b.rotation.y
	var center_gap := wall_a.global_position.distance_to(wall_b.global_position)
	maze._rotate_hallway_1_2()
	await create_timer(1.4).timeout
	var findings: Array[String] = []
	var turn_a := rad_to_deg(wrapf(wall_a.rotation.y - start_yaw_a, -PI, PI))
	var turn_b := rad_to_deg(wrapf(wall_b.rotation.y - start_yaw_b, -PI, PI))
	var pivot_drift := maze._wall_endpoint(wall_a).distance_to(pivot)
	var gap_drift := absf(wall_a.global_position.distance_to(wall_b.global_position) - center_gap)
	print("turns %.2f / %.2f degrees, pivot drift %.4f, pair gap drift %.4f" % [turn_a, turn_b, pivot_drift, gap_drift])
	if absf(turn_a - 90.0) > 0.02 or absf(turn_b - 90.0) > 0.02:
		findings.append("hallway walls did not rotate exactly 90 degrees")
	if pivot_drift > 0.02:
		findings.append("computed wall endpoint did not remain fixed")
	if gap_drift > 0.02:
		findings.append("two-wall hallway distorted while rotating")
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE ROTATION: clean" if findings.is_empty() else "MAZE ROTATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
