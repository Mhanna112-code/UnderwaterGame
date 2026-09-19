# `tutorial exit: lesson completion returns to world — guards against
# post-QTE combat soft-lock`.
#
# This drives the real Battle.finished -> World handoff.  It starts the
# tutorial encounter, marks the authored stages and its one required enemy
# QTE as complete, and observes only player-visible completion state.
extends SceneTree

# The "Defeat the enemy!" prompt now hands off to the real _win() flow
# (celebration + per-level-gained log line each carry their own
# LOG_READ_DELAY timer, ~1.6s apiece) instead of an immediate force-win, so
# this needs real wall-clock room rather than the old flow's single timer.
const TIMEOUT_MS := 8000

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

	var battle: Battle = world.battle
	if battle == null:
		findings.append("TUTORIAL START: no battle was created")
	else:
		# The combat lesson has already taught every scripted move and shown
		# its required QTE.  This is the contract boundary under test, not a
		# second combat bot. The "Defeat the enemy!" prompt now hands the
		# fight back for a real turn-by-turn finish instead of auto-winning
		# (see battle.gd's _advance_turn()), so this also has to actually
		# down the enemy - otherwise the fight would just keep going and
		# world.battle would never clear within TIMEOUT_MS.
		for enemy_entry in battle.enemies:
			(enemy_entry.stats as CombatantStats).hp = 0
		battle._tutorial_step = battle._TUTORIAL_SCRIPT.size()
		battle._tutorial_enemy_turns = 1
		battle._tutorial_finale_shown = false
		battle._qte_active = false
		battle._advance_turn()

		var deadline := Time.get_ticks_msec() + TIMEOUT_MS
		while world.battle != null and Time.get_ticks_msec() < deadline:
			# Any caption already presented belongs to the completed lesson;
			# acknowledge it exactly as Enter would without inventing combat input.
			if world.battle._tutorial_awaiting_enter:
				world.battle._tutorial_awaiting_enter = false
			await process_frame

		if world.battle != null:
			findings.append("TUTORIAL EXIT: completed lesson left the battle screen mounted")
		if world.battling:
			findings.append("WORLD HANDOFF: battling stayed true after tutorial completion")
		if not world._first_encounter_done:
			findings.append("WORLD HANDOFF: tutorial completion did not restore world progression")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial exit         completed lesson returned to the world clean")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)
