# Explicit Skip is the only early exit from the required tutorial encounter.
# It must restore the world rather than behaving like Run's ordinary flee.
extends SceneTree

const TIMEOUT_MS := 3000
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world._start_battle("", false, "angler", world.divers, false, true)
	await process_frame
	if world.battle == null:
		findings.append("TUTORIAL START: no battle was created")
	else:
		world.battle._on_skip_tutorial_pressed()
		var deadline := Time.get_ticks_msec() + TIMEOUT_MS
		while world.battle != null and Time.get_ticks_msec() < deadline:
			await process_frame
		if world.battle != null:
			findings.append("SKIP LEFT THE BATTLE MOUNTED")
		if world.battling:
			findings.append("SKIP LEFT WORLD IN BATTLE STATE")
		if not world._first_encounter_done:
			findings.append("SKIP DID NOT UNLOCK WORLD PROGRESSION")
		for d in world.divers:
			var stats: CombatantStats = (d as Diver).stats
			if stats.hp != stats.hp_max or stats.oxygen != stats.oxygen_max:
				findings.append("SKIP DID NOT FULLY RESTORE PARTY")
				break
		# Skip takes the same post-lesson handoff as a tutorial victory. The
		# former multi-page world-controls overlay was deliberately removed from
		# this moment: it hid the first objective before a player could see the
		# beacon. The concise card must instead make the exact first route goal
		# visible and relinquish control when Continue is pressed.
		if world.route == null or world.route.objective_id != "shallow_angler":
			findings.append("SKIP DID NOT OPEN THE SHALLOWS ROUTE OBJECTIVE")
		if not world.route_transition_card.visible or not paused:
			findings.append("SKIP DID NOT OPEN THE ROUTE CONTINUE HANDOFF")
		else:
			world.route_transition_card.dismiss()
			await process_frame
			if paused:
				findings.append("SKIP HANDOFF LEFT THE TREE PAUSED AFTER CONTINUE")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial skip          returned to the world clean")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)
