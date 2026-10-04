# OPEN-036: real button choice, stat-based Cordys retaliation, no forced HP reset.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sources: Array[Diver] = []
	for model_name in ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]:
		var diver := Diver.new()
		diver.model_name = model_name
		root.add_child(diver)
		sources.append(diver)
	await process_frame
	var fight := Battle.new()
	fight.prologue_angler_encounter = true
	fight.party_source = sources
	root.add_child(fight)
	await process_frame
	await process_frame
	await fight.reveal_prologue_octopus()
	var outcomes: Array[String] = []
	fight.finished.connect(func(value: String) -> void: outcomes.append(value))
	# A high-HP fixture catches an unconditional death disguised as a huge hit.
	for entry in fight.party:
		var stats := entry.stats as CombatantStats
		stats.hp_max = 200
		stats.hp = 200
	var enemy := fight.enemies[0].stats as CombatantStats
	var game_audio := root.get_node("GameAudio")
	game_audio.clear_sfx_event_trace()
	var strength := enemy.strength
	var defenses: Array[int] = []
	for entry in fight.party:
		defenses.append((entry.stats as CombatantStats).effective_defense())
	fight.attack_btn.emit_signal("pressed")
	await process_frame
	(fight.move_buttons[0] as Button).emit_signal("pressed")
	await process_frame
	(fight.target_buttons[0] as Button).emit_signal("pressed")
	await create_timer(8.0).timeout
	_expect(outcomes.is_empty(), "OPEN-036 Cordys declared defeat although a stat-based hit should leave survivors")
	for i in range(fight.party.size()):
		var stats := fight.party[i].stats as CombatantStats
		var expected := 200 - maxi(1, strength - defenses[i])
		_expect(stats.hp == expected, "OPEN-036 retaliation bypassed STR/DEF: expected %d, got %d" % [expected, stats.hp])
	_expect(game_audio.get_sfx_event_trace().count("combat_heavy_hit") == 1,
		"OPEN-038 one Poison Breath stacks duplicate heavy-impact sounds")
	fight.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame
	if not OS.get_cmdline_user_args().has("--survivor-only"):
		await _choice_matrix()
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	for finding in findings:
		print("FINDING  ", finding)
	print("PROLOGUE COMBAT: clean" if findings.is_empty() else "PROLOGUE COMBAT: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _choice_matrix() -> void:
	# Hand-computed witnesses, not a copy of the production resolver. These
	# cover different mechanics through real buttons; formulas are deterministic.
	var cases := [
		["Electric Touch", 1, 3, 0, 0, 1, 0, 0, 0, 0],
		["Axe Kick", 1, 3, 0, 0, 4, 0, 0, 0, -3],
		["Scuba Stabbing", 1, 3, 0, 0, 1, 2, 0, 0, 0],
		["Flash Blast", 1, 3, 0, 0, 0, 0, 2, -1, -1],
		["Multiple Knee Combo", 1, 3, 0, 0, 1, 0, 0, -1, -1],
		["Axe Kick", 7, 4, 2, 0, 9, 0, 0, 0, -3],
		["Electric Touch", 7, 4, 2, 0, 5, 0, 0, 0, 0],
		["Electric Touch", 7, 0, 0, 0, 0, 0, 0, 0, 0],
		["Scuba Stabbing", 7, 3, 0, 3, 0, 0, 0, 0, 0],
	]
	# Seeded generated inputs catch ACC/EVA ties, defense floors and status
	# composition beyond the independent baseline witnesses above. The oracle
	# is the public ordinary-combat resolver, never a fake Battle implementation.
	var rng := RandomNumberGenerator.new()
	rng.seed = 361037
	for _i in range(6):
		var move := CombatMoves.SCUBA[rng.randi_range(0, 4)] as Dictionary
		var actor := CombatantStats.new()
		actor.strength = rng.randi_range(0, 12)
		actor.accuracy = rng.randi_range(0, 6)
		var boss := CombatantStats.new()
		boss.hp_max = 1000
		boss.defense = rng.randi_range(0, 10)
		boss.evasion = rng.randi_range(0, 6)
		boss.fill()
		var original_evasion := boss.evasion
		var result := CombatRules.resolve(actor, boss, move)
		cases.append([String(move.name), actor.strength, actor.accuracy, boss.defense,
			original_evasion, int(result.damage), boss.status_level("bleed"),
			boss.status_level("blindness"), actor.temporary_modifiers.accuracy, actor.temporary_modifiers.evasion])
	for row in cases:
		var fight := Battle.new()
		fight.prologue_angler_encounter = true
		root.add_child(fight)
		await process_frame
		await process_frame
		await fight.reveal_prologue_octopus()
		var actor := fight.party[0].stats as CombatantStats
		var boss := fight.enemies[0].stats as CombatantStats
		actor.strength = row[1]
		actor.accuracy = row[2]
		boss.defense = row[3]
		boss.evasion = row[4]
		boss.evasion_current = row[4]
		var observed: Array[Dictionary] = []
		var outcomes: Array[String] = []
		fight.finished.connect(func(value: String) -> void: outcomes.append(value))
		fight.prologue_phase_changed.connect(func(phase: String) -> void:
			if phase == "scripted_defeat":
				observed.append({"damage": 1000 - boss.hp, "bleed": boss.status_level("bleed"), "blindness": boss.status_level("blindness"), "acc_cost": actor.temporary_modifiers.accuracy, "eva_cost": actor.temporary_modifiers.evasion, "oxygen": actor.oxygen}))
		fight.attack_btn.emit_signal("pressed")
		await process_frame
		var selected: Button
		for button in fight.move_buttons:
			if (button as Button).text.get_slice("\n", 0) == row[0]:
				selected = button as Button
		_expect(selected != null, "OPEN-036 Cordys hides a normal move: %s" % row[0])
		if selected != null:
			selected.emit_signal("pressed")
			await process_frame
			(fight.target_buttons[0] as Button).emit_signal("pressed")
			var elapsed := 0.0
			while outcomes.is_empty() and elapsed < 12.0:
				await create_timer(0.1).timeout
				elapsed += 0.1
			_expect(observed.size() == 1, "OPEN-037 no single real impact for %s" % row[0])
			if not observed.is_empty():
				var got := observed[0]
				_expect(got.damage == row[5] and got.bleed == row[6] and got.blindness == row[7] and got.acc_cost == row[8] and got.eva_cost == row[9] and got.oxygen == 100.0, "OPEN-037 move/stat/effect mismatch: %s -> %s" % [row, got])
			_expect(outcomes == ["prologue_defeat"], "OPEN-036 normal starting party did not lose to real boss stats")
			if row[6] > 0:
				_expect(boss.hp == 1000 - row[5] - row[6], "OPEN-037 Bleed did not tick on Cordys's turn")
			print("CHOICE|", row[0], "|STR=", row[1], "|ACC=", row[2], "|DEF=", row[3], "|EVA=", row[4], "|", observed)
		fight.queue_free()
		await process_frame
