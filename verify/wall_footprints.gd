# Usage: godot --headless --path . --script verify/wall_footprints.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _print_footprint(level: MazeLevel, node_name: String) -> void:
	var wall: CSGBox3D = level.get_node(node_name)
	var geo: Dictionary = level._wall_geometry(wall)
	var long_axis := geo["long_axis"] as Vector3
	var side_axis := geo["side_axis"] as Vector3
	var half_len := wall.size.x * 0.5
	var half_thick := wall.size.z * 0.5
	var c: Vector3 = wall.global_position
	var corners := [
		c + long_axis * half_len + side_axis * half_thick,
		c + long_axis * half_len - side_axis * half_thick,
		c - long_axis * half_len - side_axis * half_thick,
		c - long_axis * half_len + side_axis * half_thick,
	]
	print("%s  center=(%.2f, %.2f)  yaw=%.3f  size=(%.2f x %.2f)" % [node_name, c.x, c.z, wall.rotation.y, wall.size.x, wall.size.z])
	print("    negative_end=(%.2f, %.2f)  positive_end=(%.2f, %.2f)" % [(geo["negative_end"] as Vector3).x, (geo["negative_end"] as Vector3).z, (geo["positive_end"] as Vector3).x, (geo["positive_end"] as Vector3).z])
	print("    corners (x,z): %s" % [corners.map(func(v): return "(%.2f, %.2f)" % [v.x, v.z])])

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	print("--- Wall6/7 group ---")
	for n in ["CSGBox3D", "CurrentWall1", "CSGBox3D6", "CSGBox3D7"]:
		_print_footprint(level, n)

	print("--- Wall12/13 group ---")
	for n in ["CurrentWall3", "CurrentWall2", "CSGBox3D12", "CSGBox3D13"]:
		_print_footprint(level, n)

	quit(0)
