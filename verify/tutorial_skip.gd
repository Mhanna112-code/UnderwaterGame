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
		# Skip is an exit from the combat lesson, not from learning the world
		# controls. The onboarding is allowed to pause the world while visible,
		# but it must be dismissible back to the same playable state.
		if not world.ability_onboarding.visible:
			findings.append("SKIP DID NOT OPEN WORLD-CONTROL HANDOFF")
		else:
			world.ability_onboarding.call("dismiss")
			await process_frame
			if paused:
				findings.append("SKIP HANDOFF LEFT THE TREE PAUSED AFTER DISMISS")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial skip          returned to the world clean")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)
