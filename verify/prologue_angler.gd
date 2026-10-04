# ANGLE-001/002: the opener changes health only, never combat rules or kits.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ordinary := Battle.new()
	ordinary.guardian_encounter = true
	ordinary.guardian_enemy_id = "angler"
	root.add_child(ordinary)
	await process_frame
	var opening := Battle.new()
	opening.prologue_angler_encounter = true
	root.add_child(opening)
	await process_frame
	var normal := ordinary.enemies[0].stats as CombatantStats
	var weak := opening.enemies[0].stats as CombatantStats
	_expect(weak.hp_max > 1 and weak.hp_max < normal.hp_max, "ANGLE-001 opening must be weaker through modest HP reduction, not 1 HP")
	for field in ["strength", "defense", "agility", "accuracy", "evasion"]:
		# Angler's normal factory independently rolls a 5–25% species boost.
		# Two encounters need not roll identical ACC; both must obey that range.
		var base := float(Goblin.BASE_STATS[field])
		var low := int(round(base * Goblin.BOOST_MIN))
		var high := int(round(base * Goblin.BOOST_MAX))
		_expect(int(weak.get(field)) >= low and int(weak.get(field)) <= high,
			"ANGLE-001 opening overrides ordinary species range for " + field)
		_expect(int(normal.get(field)) >= low and int(normal.get(field)) <= high,
			"ANGLE-001 ordinary comparison is not an Angler for " + field)
	for model in Diver.BASE_STATS:
		var stats := CombatantStats.new()
		stats.accuracy = int(Diver.BASE_STATS[model].accuracy)
		var entry := {"model_name": model, "stats": stats}
		_expect(opening._moves_for(entry) == ordinary._moves_for(entry), "ANGLE-002 opening hides/rewrites ordinary kit " + model)
	ordinary.queue_free()
	opening.queue_free()
	await process_frame
	if not OS.get_cmdline_user_args().has("--contract-only"):
		await _button_witnesses()
		await _nonlethal_handoff("Staff_Diver", "Electric Touch", "Axe Kick", 2)
		await _nonlethal_handoff("Staff_Diver", "Flash Blast", "Axe Kick", 3)
		await _nonlethal_handoff("Prototype_V(1922)", "Crushing Haymaker", "Guard Bash", 3)
	_finish()

func _button_witnesses() -> void:
	# First-turn fixture changes initiative only, to exercise each real diver's
	# buttons before AI acts. STR/DEF/ACC/EVA and move data remain their baseline.
	var rows := [
		["Staff_Diver", "Electric Touch", 1, 0],
		["Staff_Diver", "Scuba Stabbing", 1, 2],
		["Staff_Diver", "Flash Blast", 0, 0],
		["Staff_Diver", "Multiple Knee Combo", 1, 0],
		["Staff_Diver", "Axe Kick", 3, 0],
		["Prototype_1(1910)", "Precise Tap", 3, 0],
		["Prototype_1(1910)", "Weaken", 0, 0],
		["Prototype_1(1910)", "Slow", 0, 0],
		["Prototype_V(1922)", "Guard Bash", 3, 0],
		["Prototype_V(1922)", "Heavy Kick", 0, 0],
		["Prototype_V(1922)", "Crushing Haymaker", 0, 0],
	]
	# Generated boundary fixtures catch hidden guarantees: below/equal/above
	# evasion with defense both below and well above attack strength.
	for acc in [0, 1, 2, 5]:
		for defense in [0, 3, 9]:
			var expected := 0 if acc <= 1 or defense > 6 else 1
			rows.append(["Staff_Diver", "Electric Touch", expected, 0, acc, defense])
	for row in rows:
		var diver := Diver.new()
		diver.model_name = row[0]
		root.add_child(diver)
		diver.stats.agility = 10
		var fight := Battle.new()
		fight.prologue_angler_encounter = true
		fight.party_source = [diver]
		root.add_child(fight)
		await process_frame
		await process_frame
		var target := fight.enemies[0].stats as CombatantStats
		if row.size() > 4:
			diver.stats.accuracy = row[4]
			target.defense = row[5]
		var interruptions: Array[String] = []
		var results: Array[String] = []
		fight.prologue_angler_defeated.connect(func() -> void: interruptions.append("cordys"))
		fight.finished.connect(func(result: String) -> void: results.append(result))
		var before: String = fight.log_label.get_parsed_text()
		await _choose(fight, row[1])
		var elapsed := 0.0
		while fight.log_label.get_parsed_text() == before and elapsed < 8.0:
			await create_timer(0.02).timeout
			elapsed += 0.02
		_expect(fight.log_label.get_parsed_text() != before, "ANGLE-003 button action never resolved: " + row[1])
		_expect(target.hp == 3 - row[2], "ANGLE-003 wrong baseline damage: %s expected %d, HP=%d" % [row[1], row[2], target.hp])
		_expect(target.status_level("bleed") == row[3], "ANGLE-003 Stabbing changed ordinary Bleed")
		if row[1] == "Axe Kick":
			_expect("for 4" in fight.log_label.get_parsed_text(), "ANGLE-003 Axe Kick damage was inflated; HP clamp hid it")
		if row[1] == "Flash Blast":
			_expect(target.status_level("blindness") == 2, "ANGLE-003 utility lost Blindness")
		if row[1] in ["Heavy Kick", "Crushing Haymaker"]:
			_expect("evades" in fight.log_label.get_parsed_text(), "ANGLE-003 low-ACC Bucky move was guaranteed a hit")
		if row[2] < 3:
			_expect(interruptions.is_empty(), "ANGLE-003 nonlethal action interrupted for Cordys")
		else:
			await create_timer(2.0).timeout
			_expect(interruptions == ["cordys"], "ANGLE-004 real kill failed single interruption")
		_expect(results.is_empty() and diver.stats.xp == 0 and diver.stats.spell_points == 0,
			"ANGLE-004 action leaked victory/progression")
		print("ANGLER BUTTON|", row, "|HP=", target.hp, "|log=", fight.log_label.get_parsed_text())
		fight.queue_free()
		diver.queue_free()
		await process_frame

func _nonlethal_handoff(model: String, first_move: String, followup: String, expected_hp: int) -> void:
	var diver := Diver.new()
	diver.model_name = model
	root.add_child(diver)
	diver.stats.agility = 10 # Initiative-only fixture, as in the button matrix.
	var fight := Battle.new()
	fight.prologue_angler_encounter = true
	fight.party_source = [diver]
	root.add_child(fight)
	await process_frame
	await process_frame
	var interruptions: Array[String] = []
	fight.prologue_angler_defeated.connect(func() -> void: interruptions.append("cordys"))
	await _choose(fight, first_move)
	var elapsed := 0.0
	while not fight.main_menu.is_visible_in_tree() and elapsed < 20.0:
		await create_timer(0.1).timeout
		elapsed += 0.1
	_expect(interruptions.is_empty() and (fight.enemies[0].stats as CombatantStats).hp == expected_hp,
		"ANGLE-003 nonlethal/utility/miss falsely defeated Angler: " + first_move)
	_expect(fight.main_menu.is_visible_in_tree() and not fight.attack_btn.disabled,
		"ANGLE-003 nonlethal action never returned usable combat controls")
	if fight.main_menu.is_visible_in_tree():
		await _choose(fight, followup)
		elapsed = 0.0
		while interruptions.is_empty() and elapsed < 10.0:
			await create_timer(0.1).timeout
			elapsed += 0.1
		_expect(interruptions == ["cordys"], "ANGLE-004 second genuine action did not finish opening")
	fight.queue_free()
	diver.queue_free()
	await process_frame

func _choose(fight: Battle, name: String) -> void:
	fight.attack_btn.emit_signal("pressed")
	await process_frame
	var selected: Button
	for value in fight.move_buttons:
		var button := value as Button
		if button.text.get_slice("\n", 0) == name:
			selected = button
	_expect(selected != null and not selected.disabled, "ANGLE-002 absent/disabled ordinary move " + name)
	if selected == null:
		return
	selected.emit_signal("pressed")
	await process_frame
	_expect(not fight.target_buttons.is_empty(), "ANGLE-003 move lost target confirmation")
	if not fight.target_buttons.is_empty():
		(fight.target_buttons[0] as Button).emit_signal("pressed")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	for finding in findings:
		print("FINDING  " + finding)
	print("PROLOGUE ANGLER: clean" if findings.is_empty() else "PROLOGUE ANGLER: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
