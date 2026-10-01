extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	var box14 := level.get_node("CSGBox3D14") as CSGBox3D
	var box28 := level.get_node("CSGBox3D28") as CSGBox3D
	print("box14 pos=%s bottom=%.4f" % [box14.global_position, box14.position.y - box14.size.y * 0.5])
	print("box28 pos=%s bottom=%.4f" % [box28.global_position, box28.position.y - box28.size.y * 0.5])
	print("box28.x - box14.center.x should be ~0 offset by push (%.4f expected): %.4f" % [
		box14.size.x * 0.5 + box28.size.z * 0.5, box28.global_position.x - box14.global_position.x
	])
	print("box28.z should equal box14.z exactly: box28.z=%.4f box14.z=%.4f" % [box28.global_position.z, box14.global_position.z])
	print("bottom match: box28.bottom - box14.bottom = %.4f" % [
		(box28.position.y - box28.size.y * 0.5) - (box14.position.y - box14.size.y * 0.5)
	])
	quit(0)
