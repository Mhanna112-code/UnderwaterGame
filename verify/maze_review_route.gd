extends SceneTree

# Browser URLs cannot be exercised headlessly here, but this verifies their
# native equivalent: --maze-playtest is recognized after World finishes ready,
# then activates the embedded maze with the same three live party actors.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var findings: Array[String] = []
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	# World._ready() itself observes --maze-playtest and defers the transition.
	# Do not call a private helper here: the actual review flag is the trigger.
	for _frame in range(4):
		await process_frame
	if current_scene != world or world.embedded_maze == null or not world.embedded_maze.maze_active:
		findings.append("maze review route did not activate the embedded maze under World")
	elif world.embedded_maze.divers != world.divers or world.cam.current:
		findings.append("maze review route replaced the shared party or retained the World camera")
	for finding in findings:
		push_error(finding)
	print("MAZE REVIEW ROUTE: clean" if findings.is_empty() else "MAZE REVIEW ROUTE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
