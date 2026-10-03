# Normal-play handoff from the separate deep-zone landmark to the current
# standalone maze. This is explicitly independent of the laboratory blockers
# and Tethys: the plan defines two branches after the blockade, not a maze
# reward for clearing the lab.
# Usage: godot --headless --path . --script verify/deep_zone_maze_transition.gd
extends SceneTree

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
	world._first_encounter_done = true
	world.route_state.set_zone("deep")
	world.route_state.set_blocker_state("bomb_bot", "available")
	world.route_state.set_blocker_state("sword_slayer", "available")
	world.route_state.set_lab_state("locked")
	world.route_state.set_tethys_state("locked")
	world.route_state.set_maze_door_state("available")
	world.route_state.set_objective("defeat_bomb_bot")
	(world.divers[world.active] as Diver).global_position = world.deep_zone_layout.route_points().maze_transition
	world._update_maze_transition()
	for _frame in range(5):
		await process_frame
	_expect(current_scene is MazeLevel,
		"DZ-MAZE-001: separate maze branch incorrectly requires lab/Tethys completion")
	if current_scene is MazeLevel:
		var maze := current_scene as MazeLevel
		_expect(maze.get_node_or_null("HUD") != null,
			"DZ-MAZE-001: maze handoff loaded a non-playable scene without its HUD")
		maze.queue_free()
	await process_frame
	var audio_owner := root.get_node_or_null("GameAudio")
	if audio_owner != null:
		audio_owner.call("release_streams_for_shutdown")
	await process_frame
	for finding in findings:
		print("FINDING  " + finding)
	print("DEEP ZONE MAZE TRANSITION: clean" if findings.is_empty() else "DEEP ZONE MAZE TRANSITION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
