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

	var connector := level.get_node("CSGBox3DConnector") as CSGBox3D
	var connector_geometry: Dictionary = level._wall_geometry(connector)
	print("connector positive_end=%s" % (connector_geometry["positive_end"] as Vector3))

	var stub := level.get_node("CSGBox3DConnectorStub") as CSGBox3D
	print("stub pos=%s rotation.y=%.4f size=%s" % [stub.global_position, stub.rotation.y, stub.size])
	var stub_geometry: Dictionary = level._wall_geometry(stub)
	var stub_side_axis := stub_geometry["side_axis"] as Vector3
	var stub_thickness_face_a := stub.global_position + stub_side_axis * stub.size.z * 0.5
	var stub_thickness_face_b := stub.global_position - stub_side_axis * stub.size.z * 0.5
	print("stub thickness face A=%s" % stub_thickness_face_a)
	print("stub thickness face B=%s" % stub_thickness_face_b)
	print("face A Z vs connector positive_end Z: %.4f vs %.4f" % [stub_thickness_face_a.z, (connector_geometry["positive_end"] as Vector3).z])
	print("face B Z vs wall7_target_end Z: %.4f vs %.4f" % [stub_thickness_face_b.z, wall7_target_end.z])
	quit(0)
