# `Glassgoat review: Swap accepts A/D and Space and tells the player so —
# guards against an undiscoverable teammate-selection control scheme`.
extends SceneTree

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
	# The title path intentionally holds exploration abilities until the
	# tutorial/route handoff; this input contract is a free-world contract.
	world._intro_active = false
	world.active = 0
	world._update_hud()

	# Start the real Swap ability through the live input boundary. The selected
	# teammate is a public selector result; no selector state is faked here.
	world._unhandled_input(_key(KEY_E))
	_expect(world.target_selector.selecting, "SWAP START: E did not open teammate selection")
	if world.target_selector.selecting:
		var first := world.target_selector.current_target()
		world._unhandled_input(_key(KEY_D))
		_expect(world.target_selector.current_target() != first,
			"SWAP CONTROL: D did not choose the next teammate")
		world._unhandled_input(_key(KEY_A))
		_expect(world.target_selector.current_target() == first,
			"SWAP CONTROL: A did not choose the previous teammate")
		_expect(world.hud.text.contains("A/D") and world.hud.text.contains("Space"),
			"SWAP COPY: visible selection instructions do not advertise A/D and Space")
		world._unhandled_input(_key(KEY_SPACE))
		_expect(not world.target_selector.selecting,
			"SWAP CONTROL: Space did not confirm the highlighted teammate")

	# Steering identity must not masquerade as the route's forward beacon. A low
	# ring has no directional point and leaves the amber route post as the only
	# "go this way" landmark.
	world._update_active_cursor()
	var active_diver := world.divers[world.active] as Diver
	_expect(world._active_cursor.mesh is TorusMesh,
		"ACTIVE MARKER: active diver is still marked by a directional cone instead of a neutral halo")
	_expect(world._active_cursor.global_position.y - active_diver.global_position.y <= 0.25,
		"ACTIVE MARKER: selection halo floats high enough to read as route guidance")

	# The delivered Frilled rig must continue its actual idle after any action;
	# a one-shot rest pose makes the fish appear frozen in a real battle.
	var shark := FrilledShark.new()
	root.add_child(shark)
	await process_frame
	var idle := shark.anim.get_animation(shark._idle_anim) if shark.anim != null and shark._idle_anim != "" else null
	_expect(idle != null and idle.loop_mode != Animation.LOOP_NONE,
		"FRILLED IDLE: imported idle clip is not configured to loop")
	shark.play("idle")
	await create_timer(1.5).timeout
	_expect(shark.anim != null and shark.anim.is_playing(),
		"FRILLED IDLE: actor stopped playing during an idle observation")
	if not shark.available_moves().is_empty():
		shark.play_move(shark.available_moves()[0] as Dictionary)
		await create_timer(0.2).timeout
		shark.play("idle")
		await process_frame
		_expect(shark.anim != null and shark.anim.is_playing(),
			"FRILLED IDLE: actor did not resume idle after an action")
	shark.queue_free()

	# Ordinary route species are authored content, not party-relative random
	# scalers. Use an intentionally stronger reference so a floor/max algorithm
	# cannot accidentally pass by returning the same small numbers.
	var strong_reference := _stats(30, 8, 7, 6, 6, 6)
	_expect(_matches_stats(Goblin.new().make_stats(strong_reference), [5, 2, 0, 2, 1, 3]),
		"ANGLER STATS: ordinary Angler does not use its agreed 5/2/0/2/1/3 table")
	_expect(_matches_stats(FrilledShark.new().make_stats(strong_reference), [5, 2, 2, 1, 2, 2]),
		"FRILLED STATS: ordinary Frilled Shark does not use its agreed 5/2/2/1/2/2 table")
	_expect(_matches_stats(Goblin.new().make_stats(strong_reference, 2), [5, 2, 0, 2, 1, 3]) and _matches_stats(FrilledShark.new().make_stats(strong_reference, 2), [5, 2, 2, 1, 2, 2]),
		"ORDINARY STATS: player level changes an ordinary Angler or Frilled Shark away from its authored table")
	# Any extra capstone pressure must announce itself in the route data and in
	# battle, never masquerade as a stealth boost to a delivered normal enemy.
	for beat_value in RouteProgression.BEATS:
		var beat := beat_value as Dictionary
		if not bool(beat.get("capstone", false)):
			continue
		for modifier_value in beat.get("enemy_modifiers", []) as Array:
			var modifier := modifier_value as Dictionary
			_expect(not String(modifier.get("variant_name", "")).is_empty(),
				"CAPSTONE VARIANT: encounter-only enemy modifier has no visible name")

	# Enemy risk belongs on the persistent combat card, while move cards need
	# to name their direct result rather than show an unexplained yellow total.
	var battle := Battle.new()
	root.add_child(battle)
	await process_frame
	await process_frame
	if battle.enemies.is_empty():
		findings.append("COMBAT CARD: no live enemy was built for review")
	else:
		battle._refresh_all_bars()
		var enemy_status := String((battle.enemies[0] as Dictionary).status_label.text)
		_expect(enemy_status.contains("EVA"),
			"COMBAT CARD: enemy EVA is hidden before target hover")
	if not battle.party.is_empty():
		battle._populate_move_menu(battle.party[0] as Dictionary)
		var first_move := battle.move_buttons[0] as Button if not battle.move_buttons.is_empty() else null
		_expect(first_move != null and first_move.text.contains("Damage"),
			"MOVE CARD: direct damage is not labelled on the player-facing move card")
		_expect(first_move != null and first_move.get_child_count() == 0,
			"MOVE CARD: an unlabeled raw-power badge still overlays the move name")
	battle.queue_free()

	# Glassgoat's old screenshot reported Electric Touch as zero damage and zero
	# EVA reduction. The shipped V2 Scuba table is nonzero with the real base
	# stats; lock that player-visible result so a zero-initialized preview
	# cannot quietly return.
	var scuba_base := _stats(10, 1, 0, 3, 3, 3)
	var electric := CombatMoves.SCUBA[0] as Dictionary
	var electric_summary := CombatMoves.resolved_hint(scuba_base, electric)
	_expect(electric_summary.contains("1 Damage") and electric_summary.contains("EVA -3"),
		"ELECTRIC TOUCH: base Scuba preview regressed to zero damage or zero EVA reduction")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("Glassgoat review: Swap A/D + Space control contract clean")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _stats(hp: int, strength: int, defense: int, agility: int, evasion: int, accuracy: int) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = hp
	stats.strength = strength
	stats.defense = defense
	stats.agility = agility
	stats.evasion = evasion
	stats.accuracy = accuracy
	stats.fill()
	return stats

func _matches_stats(stats: CombatantStats, expected: Array) -> bool:
	return [stats.hp_max, stats.strength, stats.defense, stats.agility, stats.evasion, stats.accuracy] == expected
