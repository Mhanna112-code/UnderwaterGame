extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	var wall_7 := level.get_node("CSGBox3D7") as CSGBox3D
	var wall_7_geometry: Dictionary = level._wall_geometry(wall_7)
	var wall7_target_end := wall_7_geometry["negative_end"] as Vector3
	print("wall7_target_end=%s" % wall7_target_end)

	var stub := level.get_node_or_null("CSGBox3DConnectorStub") as CSGBox3D
	if stub:
		print("CSGBox3DConnectorStub pos=%s rotation.y=%.4f size=%s" % [stub.global_position, stub.rotation.y, stub.size])
		var stub_geometry: Dictionary = level._wall_geometry(stub)
		var neg := stub_geometry["negative_end"] as Vector3
		var pos := stub_geometry["positive_end"] as Vector3
		print("stub negative_end=%s positive_end=%s" % [neg, pos])
		print("distance neg->wall7_target_end = %.4f" % neg.distance_to(wall7_target_end))
		print("distance pos->wall7_target_end = %.4f" % pos.distance_to(wall7_target_end))
	else:
		print("CSGBox3DConnectorStub not found")
	quit(0)
