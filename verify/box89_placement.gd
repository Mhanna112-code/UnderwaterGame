extends SceneTree

var findings: Array[String] = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _initialize() -> void:
	call_deferred("_run")

func _check_pair(level: MazeLevel, moving: CSGBox3D, target: CSGBox3D, label: String) -> void:
	var target_geometry: Dictionary = level._wall_geometry(target)
	var target_neg := target_geometry["negative_end"] as Vector3
	var target_pos := target_geometry["positive_end"] as Vector3

	var moving_geometry: Dictionary = level._wall_geometry(moving)
	var moving_neg := moving_geometry["negative_end"] as Vector3
	var moving_pos := moving_geometry["positive_end"] as Vector3

	var touching_target := target_neg if target_neg.distance_to(moving.global_position) < target_pos.distance_to(moving.global_position) else target_pos
	var touching_moving := moving_neg if moving_neg.distance_to(touching_target) < moving_pos.distance_to(touching_target) else moving_pos
	var gap := touching_moving.distance_to(touching_target)
	print("%s: %s touching end vs %s target end gap = %.4f" % [label, moving.name, target.name, gap])
	_check(gap < 1.0, "%s: residual gap %.4f is larger than expected clearance terms" % [label, gap])

	print("%s: %s pos=%s yaw=%.4f" % [label, moving.name, moving.global_position, moving.rotation.y])

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	_check_pair(level, level.get_node("CSGBox3D8"), level.get_node("CSGBox3D12"), "Box8->Box12")
	_check_pair(level, level.get_node("CSGBox3D9"), level.get_node("CSGBox3D13"), "Box9->Box13")

	for finding in findings:
		print("FINDING  " + finding)
	print("BOX8/9 PLACEMENT: clean" if findings.is_empty() else "BOX8/9 PLACEMENT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
