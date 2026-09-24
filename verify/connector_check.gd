extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	var connector := level.get_node_or_null("CSGBox3DConnector") as CSGBox3D
	if connector == null:
		print("CSGBox3DConnector not found")
		quit(1)
		return

	print("connector pos=%s yaw=%.4f size=%s" % [connector.global_position, connector.rotation.y, connector.size])

	var wall_13 := level.get_node("CSGBox3D13") as CSGBox3D
	var wall_7 := level.get_node("CSGBox3D7") as CSGBox3D
	var wall_13_geometry: Dictionary = level._wall_geometry(wall_13)
	var wall_7_geometry: Dictionary = level._wall_geometry(wall_7)
	var wall13_target_end := wall_13_geometry["negative_end"] as Vector3
	var wall7_target_end := wall_7_geometry["negative_end"] as Vector3
	var connector_geometry: Dictionary = level._wall_geometry(connector)
	var neg := connector_geometry["negative_end"] as Vector3
	var pos := connector_geometry["positive_end"] as Vector3
	print("connector negative_end=%s positive_end=%s" % [neg, pos])
	print("wall13_target_end=%s wall7_target_end=%s" % [wall13_target_end, wall7_target_end])
	print("distance neg->wall13_target_end = %.4f" % neg.distance_to(wall13_target_end))
	print("distance pos->wall13_target_end = %.4f" % pos.distance_to(wall13_target_end))
	print("distance neg->wall7_target_end = %.4f" % neg.distance_to(wall7_target_end))
	print("distance pos->wall7_target_end = %.4f" % pos.distance_to(wall7_target_end))
	quit(0)
