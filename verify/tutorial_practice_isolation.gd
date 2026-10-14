extends SceneTree

# QT6: optional practice must not heal or overwrite an earned party.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world.route_state.prologue_complete = true
	world.route_state.opening_video_seen = true
	world.route_state.tutorial_complete = true
	world.route_state.normalize_prologue_phase()
	world._first_encounter_started = true
	world._intro_active = false
	world.set_physics_process(false)
	world.set_process(false)
	world.inventory = {"potion": 2}
	var originals: Array[CombatantStats] = []
	var expected := []
	for index in world.divers.size():
		var stats: CombatantStats = world.divers[index].stats
		stats.hp = 7 - index
		stats.oxygen = 55 + index
		originals.append(stats)
		expected.append([stats.hp, stats.oxygen, stats.xp, stats.level])
	world._replay_tutorial_battle(Battle.TUTORIAL_PROFILE_QUICK)
	await process_frame
	for index in originals.size():
		var stats := originals[index]
		if [stats.hp, stats.oxygen, stats.xp, stats.level] != expected[index]:
			failures.append("QT6: starting optional training mutated the earned diver's resources")
	if failures.is_empty():
		var deadline := Time.get_ticks_msec() + 12000
		while world.battle != null and Time.get_ticks_msec() < deadline:
			if world.battle.skip_tutorial_btn.is_visible_in_tree() and not world.battle.skip_tutorial_btn.disabled:
				world.battle.skip_tutorial_btn.emit_signal("pressed")
			await process_frame
		if world.battle != null or world.battling:
			failures.append("QT10: optional practice Skip did not release the real World")
		for index in originals.size():
			var stats: CombatantStats = world.divers[index].stats
			if stats != originals[index] or [stats.hp, stats.oxygen, stats.xp, stats.level] != expected[index]:
				failures.append("QT6: leaving optional training did not restore the earned party")
		if world.inventory != {"potion": 2} or world.ability_popups_seen or paused:
			failures.append("QT3/QT6: practice changed inventory or forced onboarding instead of returning to play")
	for failure in failures:
		push_error(failure)
	print("TUTORIAL PRACTICE ISOLATION: %d failure(s)" % failures.size())
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	quit(0 if failures.is_empty() else 1)
