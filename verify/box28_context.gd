extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	for n in ["CSGBox3D11", "CSGBox3D14", "CSGBox3D27", "CSGBox3D28"]:
		var box := level.get_node(n) as CSGBox3D
		var g: Dictionary = level._wall_geometry(box)
		print("%s pos=%s yaw=%.4f size=%s negative_end=%s positive_end=%s bottom=%.4f" % [
			n, box.global_position, box.rotation.y, box.size, g["negative_end"], g["positive_end"],
			box.position.y - box.size.y * 0.5
		])
	quit(0)
