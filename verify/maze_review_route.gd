extends SceneTree

# Browser URLs cannot be exercised headlessly here, but this verifies their
# native equivalent: --maze-playtest is recognized by World and transitions
# after _ready() has completed, without leaving the half-built World running.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var findings: Array[String] = []
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	# World._ready() itself observes --maze-playtest and defers the transition.
	# Do not call the helper on `world` here: a correct route frees that old
	# scene before this coroutine resumes.
	for _frame in range(4):
		await process_frame
	if not current_scene is MazeLevel:
		findings.append("maze review route did not replace World with MazeLevel")
	for finding in findings:
		push_error(finding)
	print("MAZE REVIEW ROUTE: clean" if findings.is_empty() else "MAZE REVIEW ROUTE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
