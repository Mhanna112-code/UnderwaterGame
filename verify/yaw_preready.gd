extends SceneTree

func _initialize() -> void:
	var level := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	var wall_12 := level.get_node("CSGBox3D12") as CSGBox3D
	print("BEFORE add_child (pre-_ready): wall_12.rotation.y = %.4f" % wall_12.rotation.y)
	root.add_child(level)
	call_deferred("_after", level)

func _after(level: MazeLevel) -> void:
	var wall_12 := level.get_node("CSGBox3D12") as CSGBox3D
	print("AFTER add_child (_ready has run): wall_12.rotation.y = %.4f" % wall_12.rotation.y)
	quit(0)
