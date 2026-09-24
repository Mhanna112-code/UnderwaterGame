extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(level)
	await process_frame
	await process_frame

	var min_base := INF
	var max_base := -INF
	var count := 0
	for box in level.wall_boxes:
		var base: float = box.position.y - box.size.y * 0.5
		min_base = minf(min_base, base)
		max_base = maxf(max_base, base)
		count += 1
	print("checked %d walls, base range: [%.6f, %.6f]" % [count, min_base, max_base])

	var wall_7 := level.get_node("CSGBox3D7") as CSGBox3D
	var wall_13 := level.get_node("CSGBox3D13") as CSGBox3D
	var reward_wall := level.get_node("RewardChamberWestWall") as CSGBox3D
	print("wall_7 pos.y=%.4f size.y=%.4f base=%.4f" % [wall_7.position.y, wall_7.size.y, wall_7.position.y - wall_7.size.y * 0.5])
	print("wall_13 pos.y=%.4f size.y=%.4f base=%.4f" % [wall_13.position.y, wall_13.size.y, wall_13.position.y - wall_13.size.y * 0.5])
	print("RewardChamberWestWall pos.y=%.4f size.y=%.4f base=%.4f" % [reward_wall.position.y, reward_wall.size.y, reward_wall.position.y - reward_wall.size.y * 0.5])
	quit(0)
