# Usage: godot --headless --path . --script verify/wall6_trace.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	var wall_a: CSGBox3D = level.get_node("CurrentWall1")
	var wall_orig: CSGBox3D = level.get_node("CSGBox3D")
	var wall_6: CSGBox3D = level.get_node("CSGBox3D6")

	var wall1_target: Dictionary = level._nearest_wall_continuation(wall_a, wall_orig)
	print("wall1_target = %s" % wall1_target)
	var wall1_future: Dictionary = level._wall_geometry_at(wall1_target.position as Vector3, float(wall1_target.yaw), wall_a.size)
	print("wall1_future = %s" % wall1_future)
	var wall_orig_geometry: Dictionary = level._wall_geometry(wall_orig)
	var wall1_attach_point: Vector3 = level._wall_end(wall_orig_geometry,
		MazeLevel.WallEnd.POSITIVE if String(wall1_target.target_end) == "positive" else MazeLevel.WallEnd.NEGATIVE)
	print("wall1_attach_point = %s" % wall1_attach_point)

	var wall1_negative_end := wall1_future["negative_end"] as Vector3
	var wall1_positive_end := wall1_future["positive_end"] as Vector3
	print("negative_end=%s dist_to_attach=%.4f" % [wall1_negative_end, wall1_negative_end.distance_to(wall1_attach_point)])
	print("positive_end=%s dist_to_attach=%.4f" % [wall1_positive_end, wall1_positive_end.distance_to(wall1_attach_point)])

	print("wall_6 rotation.y = %.4f  size=%s" % [wall_6.rotation.y, wall_6.size])
	print("wall_a (CurrentWall1) size.z = %.4f" % wall_a.size.z)

	quit(0)
