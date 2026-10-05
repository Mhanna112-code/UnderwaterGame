extends SceneTree

# Browser URLs cannot be exercised headlessly here, but this verifies their
# native equivalent: --maze-playtest is recognized after World finishes ready,
# then activates the embedded maze with the same three live party actors.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var findings: Array[String] = []
	var unfinished := RouteState.new()
	var before := unfinished.to_save_data()
	if not unfinished.exploration_goal("shallows").is_empty() or not unfinished.exploration_goal("deep").is_empty():
		findings.append("GOAL-6 maze destination exposes World guidance during the unfinished opening")
	if not unfinished.exploration_goal("maze").to_lower().contains("control room") \
		or unfinished.to_save_data() != before:
		findings.append("GOAL-6 displaying a diagnostic destination mutates narrative/progression state")
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
	if world.embedded_maze != null and world.embedded_maze.maze_active:
		var goal := world.embedded_maze.get_node("HUD/GoalLabel") as Label
		if not goal.is_visible_in_tree() or not goal.text.to_lower().contains("control room"):
			findings.append("GOAL-6 real diagnostic maze flag leaves the active entrance without its destination")
		if world.route_state.prologue_complete or world.route_state.lab_state != "locked" \
			or world.embedded_maze.key_items.has("maze_nav_map"):
			findings.append("GOAL-6 diagnostic destination falsely grants opening, laboratory or map progression")
	for finding in findings:
		push_error(finding)
	print("MAZE REVIEW ROUTE: clean" if findings.is_empty() else "MAZE REVIEW ROUTE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
