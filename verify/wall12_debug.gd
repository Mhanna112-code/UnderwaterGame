# Usage: godot --headless --path . --script verify/wall12_debug.gd
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

	var wall2_target: Dictionary = level._nearest_wall_continuation(wall_2, wall_3)
	print("wall2_target = %s" % wall2_target)

	var wall2_future: Dictionary = level._wall_geometry_at(wall2_target.position as Vector3, float(wall2_target.yaw), wall_2.size)
	print("wall2_future long_axis=%s neg_end=%s pos_end=%s" % [wall2_future.long_axis, wall2_future.negative_end, wall2_future.positive_end])

	var wall_3_geometry: Dictionary = level._wall_geometry(wall_3)
	var wall2_attach_point: Vector3 = level._wall_end(wall_3_geometry,
		MazeLevel.WallEnd.POSITIVE if String(wall2_target.target_end) == "positive" else MazeLevel.WallEnd.NEGATIVE)
	print("wall2_attach_point (on CurrentWall3) = %s" % wall2_attach_point)

	var wall2_negative_end := wall2_future["negative_end"] as Vector3
	var wall2_positive_end := wall2_future["positive_end"] as Vector3
	var pick_negative := wall2_negative_end.distance_squared_to(wall2_attach_point) > wall2_positive_end.distance_squared_to(wall2_attach_point)
	var wall2_outer_end: Vector3 = wall2_negative_end if pick_negative else wall2_positive_end
	var wall2_outward_axis: Vector3 = -(wall2_future["long_axis"] as Vector3) if pick_negative else (wall2_future["long_axis"] as Vector3)
	print("picked negative end as outer? %s -> outer_end=%s outward_axis=%s" % [pick_negative, wall2_outer_end, wall2_outward_axis])

	print("wall_12.rotation.y = %.4f" % wall_12.rotation.y)
	var moving_long_axis := Basis(Vector3.UP, wall_12.rotation.y).x.normalized()
	print("moving_long_axis (wall_12's own, at its actual rotation) = %s" % moving_long_axis)
	print("wall2_outward_axis dot moving_long_axis = %.4f (expect near 0 - they should be perpendicular)" % wall2_outward_axis.dot(moving_long_axis))

	var actual := level._position_beyond_wall_end(
		wall2_outer_end, wall2_outward_axis, wall_2.size.z,
		wall_12.rotation.y, wall_12.size.x, wall_12.size.z, MazeLevel.WallEnd.NEGATIVE
	)
	print("_position_beyond_wall_end() returns: %s" % actual)
	print("wall_12 actual global_position:        %s" % wall_12.global_position)

	quit(0)
