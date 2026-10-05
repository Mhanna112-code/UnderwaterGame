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
	print("%s: gap=%.4f" % [label, gap])
	_check(gap < 1.0, "%s: residual gap %.4f is larger than expected clearance terms" % [label, gap])

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	var pairs := [
		["CSGBox3D11", "CSGBox3D9"],
		["CSGBox3D10", "CSGBox3D8"],
		["CSGBox3D15", "CSGBox3D10"],
		["CSGBox3D14", "CSGBox3D11"],
		["CSGBox3D16", "CSGBox3D15"],
		["CSGBox3D27", "CSGBox3D14"],
		["CSGBox3D18", "CSGBox3D16"],
		["CSGBox3D21", "CSGBox3D18"],
		["CSGBox3D22", "CSGBox3D21"],
		["CSGBox3D23", "CSGBox3D22"],
		["CSGBox3D25", "CSGBox3D23"],
		["CSGBox3D24", "CSGBox3D25"],
		["RewardChamberWestWall", "CSGBox3D24"],
	]
	for pair in pairs:
		var moving := level.get_node(pair[0]) as CSGBox3D
		var target := level.get_node(pair[1]) as CSGBox3D
		_check_pair(level, moving, target, "%s -> %s" % [pair[0], pair[1]])

	for finding in findings:
		print("FINDING  " + finding)
	print("PERIMETER CHAIN: clean" if findings.is_empty() else "PERIMETER CHAIN: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
