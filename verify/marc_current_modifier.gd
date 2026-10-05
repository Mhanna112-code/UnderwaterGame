extends SceneTree
## MAP-6: Ctrl is a map modifier, not an undisclosed sink control.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	await _motion(world.divers[world.active], "World")
	world.queue_free()
	await process_frame
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in 8:
		await physics_frame
	await _motion(maze._diver, "Maze")
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC CURRENT MODIFIER: clean" if findings.is_empty() else "MARC CURRENT MODIFIER: failed")
	quit(0 if findings.is_empty() else 1)

func _motion(diver: Diver, owner: String) -> void:
	# Fixture altitude clear of floor/ceiling; actual swim handles every frame.
	diver.position.y = 2.0
	diver.velocity = Vector3.ZERO
	await physics_frame
	var start := diver.position.y
	await _hold(KEY_CTRL, 30)
	_expect(absf(diver.position.y - start) < 0.08, "MAP-6 Ctrl sinks the diver in " + owner)
	diver.velocity = Vector3.ZERO
	start = diver.position.y
	await _hold(KEY_SHIFT, 30)
	_expect(diver.position.y < start - 0.25, "MAP-6 Shift no longer dives in " + owner)
	print("MODIFIER MOTION|", owner, "|Ctrl/Shift checked")

func _hold(code: Key, frames: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	for frame in frames:
		await physics_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await physics_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
