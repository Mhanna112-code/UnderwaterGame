# Playable prologue Angler encounter contract.
#
# Bugs caught:
# - OPEN-009: a visible choice deals no damage/misses/fails to kill, or the
#   Angler acts first.
# - OPEN-010: the one-action tuning mutates ordinary Anglers, grants campaign
#   rewards, or falls through normal victory before Cordys can interrupt.
#
# Usage: godot --headless --path . --script verify/prologue_angler.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe := Battle.new()
	if not _has_property(probe, "prologue_angler_encounter"):
		findings.append("OPEN-009 Battle has no prologue Angler configuration")
		probe.free()
		_finish()
		return
	probe.free()

	var battle := Battle.new()
	battle.set("prologue_angler_encounter", true)
	root.add_child(battle)
	await process_frame
	await process_frame
	_expect(battle.enemies.size() == 1, "OPEN-009 prologue must contain exactly one enemy")
	if battle.enemies.is_empty():
		_finish()
		return
	var enemy := battle.enemies[0] as Dictionary
	var enemy_stats := enemy.stats as CombatantStats
	var actor := battle.party[0] as Dictionary
	var actor_stats := actor.stats as CombatantStats
	_expect(String(enemy.display_name) == "Angler", "OPEN-009 prologue opponent is not the authored Angler")
	_expect(enemy_stats.hp_max == 1 and enemy_stats.defense == 0 and enemy_stats.evasion == 0,
		"OPEN-009 prologue Angler is not isolated one-action tuning")
	_expect(actor_stats.effective_agility() > enemy_stats.effective_agility(),
		"OPEN-009 Angler can act before the player's first real choice")

	var moves: Array = battle._moves_for(actor)
	_expect(moves.size() >= 2, "OPEN-009 prologue exposes too few real offensive choices")
	for move_value in moves:
		var move := move_value as Dictionary
		_expect(_deals_damage(move), "OPEN-009 non-damaging choice is visible: %s" % String(move.get("name", "?")))
		var target := _fresh_target()
		var result: Dictionary
		if move.has("formula"):
			result = CombatRules.resolve(actor_stats, target, move, false)
		else:
			result = Battle.apply_damage_roll(actor_stats, target, move, 0.85)
		_expect(bool(result.get("hit", false)), "OPEN-009 visible choice can miss: %s" % String(move.get("name", "?")))
		_expect(target.hp == 0, "OPEN-009 visible choice is not lethal: %s" % String(move.get("name", "?")))

	var xp_before := actor_stats.xp
	var interruptions: Array[String] = []
	var normal_results: Array[String] = []
	battle.prologue_angler_defeated.connect(func() -> void: interruptions.append("cordys"))
	battle.finished.connect(func(result: String) -> void: normal_results.append(result))
	enemy_stats.hp = 0
	battle._advance_turn()
	await process_frame
	_expect(interruptions == ["cordys"], "OPEN-010 Angler defeat did not emit exactly one Cordys interruption")
	_expect(normal_results.is_empty(), "OPEN-010 Angler defeat fell through normal Battle.finished")
	_expect(actor_stats.xp == xp_before, "OPEN-010 prologue Angler granted XP")
	_expect(is_instance_valid(battle), "OPEN-010 battle vanished before same-sequence Cordys reveal")

	battle.queue_free()
	await process_frame
	var ordinary := Battle.new()
	root.add_child(ordinary)
	await process_frame
	await process_frame
	if not ordinary.enemies.is_empty():
		var ordinary_stats := (ordinary.enemies[0] as Dictionary).stats as CombatantStats
		_expect(ordinary_stats.hp_max > 1,
			"OPEN-010 prologue tuning leaked into an ordinary encounter")
	ordinary.queue_free()
	await process_frame
	await _test_visible_button_choices()
	_finish()

func _test_visible_button_choices() -> void:
	# Resolve every exposed first-turn choice through the same Attack, move,
	# and target buttons used in production, including the all-target choice.
	var names := ["Electric Touch", "Scuba Stabbing", "Multiple Knee Combo", "Axe Kick"]
	for move_name in names:
		var fight := Battle.new()
		fight.prologue_angler_encounter = true
		root.add_child(fight)
		await process_frame
		await process_frame
		var interruptions: Array[String] = []
		var swings: Array[String] = []
		fight.prologue_angler_defeated.connect(func() -> void: interruptions.append("defeated"))
		fight.player_swing_staged.connect(func(_attacker: Node3D, _target: Node3D) -> void: swings.append("swing"))
		fight.attack_btn.emit_signal("pressed")
		await process_frame
		var selected: Button
		for button in fight.move_buttons:
			if (button as Button).text.get_slice("\n", 0) == move_name:
				selected = button as Button
				break
		_expect(selected != null and not selected.disabled, "OPEN-009 attack is absent/disabled: %s" % move_name)
		if selected != null:
			selected.emit_signal("pressed")
			await process_frame
			_expect(not fight.target_buttons.is_empty(), "OPEN-009 attack has no real target confirmation: %s" % move_name)
			if not fight.target_buttons.is_empty():
				(fight.target_buttons[0] as Button).emit_signal("pressed")
				var elapsed := 0.0
				while interruptions.is_empty() and elapsed < 12.0:
					await create_timer(0.1).timeout
					elapsed += 0.1
			_expect(interruptions == ["defeated"], "OPEN-009 button choice did not defeat Angler once: %s" % move_name)
			_expect(swings == ["swing"], "OPEN-009 button choice did not animate against its selected target: %s" % move_name)
			_expect((fight.party[0].stats as CombatantStats).xp == 0, "OPEN-010 button choice granted XP: %s" % move_name)
		fight.queue_free()
		await process_frame

func _fresh_target() -> CombatantStats:
	var target := CombatantStats.new()
	target.hp_max = 1
	target.hp = 1
	target.defense = 0
	target.evasion = 0
	target.evasion_current = 0
	return target

func _deals_damage(move: Dictionary) -> bool:
	if move.has("formula"):
		return not (move.get("formula", {}) as Dictionary).is_empty()
	return int(move.get("power", 0)) > 0 and String(move.get("effect", "")) not in ["heal", "revive"]

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String((property as Dictionary).name) == property_name:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING  " + finding)
	print("PROLOGUE ANGLER: clean" if findings.is_empty() else "PROLOGUE ANGLER: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
