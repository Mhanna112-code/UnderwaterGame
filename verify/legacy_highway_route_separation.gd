# `legacy highway puzzle: solving its real plates must not add an inert goal
# beside a live RouteState objective — guards against contradictory guidance`.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world.set_physics_process(false)
	world.route_state.set_objective("defeat_bomb_bot")

	if world._lock_plates.size() != 3 or world.divers.size() < 3:
		findings.append("PUZZLE FIXTURE: production world does not expose three plates and three divers")
	else:
		for i in range(3):
			var diver := world.divers[i] as Diver
			diver.global_position = (world._lock_plates[i] as LockPlate).global_position
			diver.velocity = Vector3.ZERO
			# Use the production Area3D's own entry path. Plate collision itself is
			# covered elsewhere; this gate isolates what World does once all three
			# real plates report occupied.
			(world._lock_plates[i] as LockPlate)._on_body_entered(diver)
		world.call("_check_gap_puzzle")
		if not world._puzzle_solved:
			findings.append("PUZZLE FIXTURE: occupying the real three plates did not solve the production puzzle")
		elif world._puzzle_goal.visible:
			findings.append("COMPETING LEGACY GOAL: inert cyan waypoint is visible beside active objective defeat_bomb_bot")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("LEGACY GUIDANCE: puzzle opened without competing with the active route objective")
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	quit(0 if findings.is_empty() else 1)
