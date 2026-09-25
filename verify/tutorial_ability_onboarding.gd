# `progression route: a completed tutorial exposes the one shallow objective,
# dismisses its short handoff card, rejects an ordinary roll, and starts the
# authored Angler — guards against a post-tutorial soft lock or random route`.
#
# The former automatic multi-page ability modal is intentionally not the
# first-free-play handoff anymore: it blocked movement before the player saw
# the beacon. F1 still exposes that reference material; this gate protects
# the new playable route instead.
extends SceneTree

const TIMEOUT_MS := 9000
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
		findings.append("ROUTE HANDOFF START: no tutorial battle was created")
	else:
		for enemy_entry in battle.enemies:
			(enemy_entry.stats as CombatantStats).hp = 0
		battle._tutorial_step = battle._TUTORIAL_SCRIPT.size()
		battle._tutorial_enemy_turns = 1
		battle._tutorial_finale_shown = false
		battle._qte_active = false
		battle._advance_turn()
		var deadline := Time.get_ticks_msec() + TIMEOUT_MS
		while world.battle != null and Time.get_ticks_msec() < deadline:
			if world.battle._tutorial_awaiting_enter:
				world.battle._tutorial_awaiting_enter = false
			await process_frame
		if world.battle != null:
			findings.append("ROUTE HANDOFF: completed tutorial left Battle mounted")
		else:
			await _verify_handoff(world)

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial route handoff  completed lesson opened one safe authored objective")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _verify_handoff(world: World) -> void:
	_expect(world.route != null and world.route.objective_id == "shallow_angler",
		"TUTORIAL HANDOFF: no active Shallows Angler objective after the lesson")
	_expect(world.route != null and world.route.objective_text == "Shallows — follow the beacon.",
		"TUTORIAL HANDOFF: first player-facing objective drifted")
	_expect(world.route_objective_label.visible,
		"TUTORIAL HANDOFF: sole route objective is not visibly displayed in the world")
	_expect(world.route_transition_card.visible and paused,
		"TUTORIAL HANDOFF: the short Continue card did not guard the initial handoff")
	if not findings.is_empty():
		return
	world.route_transition_card.dismiss()
	await process_frame
	_expect(not paused and not world.battling,
		"TRANSITION DISMISS: Continue did not return control to the world")

	var d := world.divers[world.active] as Diver
	d.encounter_triggered.emit()
	await process_frame
	_expect(world.battle == null,
		"ROUTE SAFETY: an ordinary distance roll interrupted the authored shallow path")

	world._on_route_triggered(d)
	await process_frame
	await process_frame
	_expect(world.battle != null,
		"AUTHORED DISPATCH: arriving at the active beacon did not begin combat")
	if world.battle != null:
		_expect(world.battle.enemies.size() == 1,
			"AUTHORED DISPATCH: shallow Angler did not stay a single-enemy fight")
		if not world.battle.enemies.is_empty():
			var actor := (world.battle.enemies[0] as Dictionary).actor as Goblin
			_expect(actor != null and actor.enemy_id() == "angler",
				"AUTHORED DISPATCH: shallow route built the wrong enemy")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
