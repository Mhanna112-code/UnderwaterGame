# Usage: godot --headless --path . --script verify/wall12_trace.gd
extends SceneTree

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

	print("wall_12 after _ready(): pos=%s yaw=%.4f" % [wall_12.global_position, wall_12.rotation.y])

	var wall2_target: Dictionary = level._nearest_wall_continuation(wall_2, wall_3)
	print("wall2_target = %s" % wall2_target)
	var wall2_future: Dictionary = level._wall_geometry_at(wall2_target.position as Vector3, float(wall2_target.yaw), wall_2.size)
	print("wall2_future = %s" % wall2_future)
	var wall_3_geometry: Dictionary = level._wall_geometry(wall_3)
	print("wall_3_geometry = %s" % wall_3_geometry)
	var wall2_attach_point: Vector3 = level._wall_end(wall_3_geometry,
		MazeLevel.WallEnd.POSITIVE if String(wall2_target.target_end) == "positive" else MazeLevel.WallEnd.NEGATIVE)
	print("wall2_attach_point = %s" % wall2_attach_point)

	var wall2_negative_end := wall2_future["negative_end"] as Vector3
	var wall2_positive_end := wall2_future["positive_end"] as Vector3
	var wall2_outer_end: Vector3
	var wall2_outward_axis: Vector3
	if wall2_negative_end.distance_squared_to(wall2_attach_point) > wall2_positive_end.distance_squared_to(wall2_attach_point):
		wall2_outer_end = wall2_negative_end
		wall2_outward_axis = -(wall2_future["long_axis"] as Vector3)
	else:
		wall2_outer_end = wall2_positive_end
		wall2_outward_axis = wall2_future["long_axis"] as Vector3
	print("wall2_outer_end=%s wall2_outward_axis=%s" % [wall2_outer_end, wall2_outward_axis])

	print("about to call _position_beyond_wall_end with yaw=%.4f size_x=%.4f size_z=%.4f" % [wall_12.rotation.y, wall_12.size.x, wall_12.size.z])
	var result: Vector3 = level._position_beyond_wall_end(
		wall2_outer_end, wall2_outward_axis, wall_2.size.z,
		wall_12.rotation.y, wall_12.size.x, wall_12.size.z
	)
	print("_position_beyond_wall_end returned: %s" % result)

	quit(0)
