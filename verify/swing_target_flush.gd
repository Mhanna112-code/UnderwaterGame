# Usage: godot --headless --path . --script verify/swing_target_flush.gd
extends SceneTree

var findings: Array[String] = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _corners(center: Vector3, long_axis: Vector3, side_axis: Vector3, size: Vector3) -> Array:
	var half_len := size.x * 0.5
	var half_thick := size.z * 0.5
	return [
		center + long_axis * half_len + side_axis * half_thick,
		center + long_axis * half_len - side_axis * half_thick,
		center - long_axis * half_len - side_axis * half_thick,
		center - long_axis * half_len + side_axis * half_thick,
	]

func _check_pair(level: MazeLevel, moving_wall: CSGBox3D, target_wall: CSGBox3D, label: String) -> void:
	var t: Dictionary = level._nearest_wall_continuation(moving_wall, target_wall)
	var moving_future: Dictionary = level._wall_geometry_at(t.position as Vector3, float(t.yaw), moving_wall.size)
	var target_geometry: Dictionary = level._wall_geometry(target_wall)

	var moving_corners := _corners(moving_future["center"] as Vector3, moving_future["long_axis"] as Vector3, moving_future["side_axis"] as Vector3, moving_future["size"] as Vector3)
	var target_corners := _corners(target_geometry["center"] as Vector3, target_geometry["long_axis"] as Vector3, target_geometry["side_axis"] as Vector3, target_geometry["size"] as Vector3)

	# For each of moving_wall's 4 corners, find the closest target corner.
	# A true flush join means two of moving_wall's corners land almost
	# exactly on two of target_wall's corners (the shared edge) - not
	# necessarily touching at a single point.
	var best_pair_dists: Array[float] = []
	for mc in moving_corners:
		var mc_v: Vector3 = mc
		var best := INF
		for tc in target_corners:
			var tc_v: Vector3 = tc
			best = minf(best, mc_v.distance_to(tc_v))
		best_pair_dists.append(best)
	best_pair_dists.sort()
	var closest_two := best_pair_dists[0] + best_pair_dists[1]
	print("%s: sum of the two smallest moving-corner-to-nearest-target-corner distances (should be ~0 for a flush shared edge): %.4f" % [label, closest_two])
	_check(closest_two < 0.2, "%s: no pair of matching corners between moving and target walls - not flush (sum %.4f)" % [label, closest_two])

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	_check_pair(level, level.get_node("CurrentWall1"), level.get_node("CSGBox3D"), "CurrentWall1 -> CSGBox3D")
	_check_pair(level, level.get_node("CurrentWall2"), level.get_node("CurrentWall3"), "CurrentWall2 -> CurrentWall3")

	for finding in findings:
		print("FINDING  " + finding)
	print("SWING TARGET FLUSH: clean" if findings.is_empty() else "SWING TARGET FLUSH: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
