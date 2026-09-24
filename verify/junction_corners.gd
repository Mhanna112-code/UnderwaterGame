extends SceneTree

func _corners(level: MazeLevel, wall: CSGBox3D) -> Array:
	var g: Dictionary = level._wall_geometry(wall)
	var center: Vector3 = g["center"]
	var long_axis: Vector3 = g["long_axis"]
	var side_axis: Vector3 = g["side_axis"]
	var half_len: float = wall.size.x * 0.5
	var half_thick: float = wall.size.z * 0.5
	return [
		center + long_axis * half_len + side_axis * half_thick,
		center + long_axis * half_len - side_axis * half_thick,
		center - long_axis * half_len - side_axis * half_thick,
		center - long_axis * half_len + side_axis * half_thick,
	]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	var connector := level.get_node("CSGBox3DConnector") as CSGBox3D
	var stub := level.get_node("CSGBox3DConnectorStub") as CSGBox3D

	print("connector corners:")
	for c in _corners(level, connector):
		print("  %s" % c)
	print("stub corners:")
	for c in _corners(level, stub):
		print("  %s" % c)
	quit(0)
