extends SceneTree
## INT-11: explicit secret identity must not silently construct a random pack.
var findings: Array[String] = []
var identities: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture := "--capture-puppets" in OS.get_cmdline_user_args()
	var baseline := capture or "--baseline-only" in OS.get_cmdline_user_args()
	Engine.time_scale = 1.0 if capture else 10.0
	for oxygen in ([100.0] if baseline else [100.0, 84.0, 67.0]):
		for potions in ([2] if baseline else [0, 2]):
			await _case(capture, float(oxygen), int(potions))
	Engine.time_scale = 1.0
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE PUPPET WAVES: clean" if findings.is_empty() else "MAZE PUPPET WAVES: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _case(capture: bool, oxygen: float, potions: int) -> void:
	root.size = Vector2i(1280, 720)
	identities.clear()
	seed(64221)
	var sources: Array[Diver] = []
	for model in Cast.ALL:
		var diver := Diver.new()
		diver.model_name = model
		root.add_child(diver)
		# Actual XP/learning establishes a legal consumer kit, not a full-route
		# grind proof. Baseline max HP remains 10; no outcome or damage injected.
		while diver.stats.level < 5:
			diver.stats.gain_xp(10)
		SpellTree.learn_all_available(diver, [])
		diver.stats.oxygen = oxygen
		sources.append(diver)
	var battle := Battle.new()
	battle.encounter_source = "maze_puppets"
	battle.party_source = sources
	battle.inventory_source = {"potion": potions}
	var outcomes: Array[String] = []
	battle.finished.connect(func(result: String) -> void: outcomes.append(result))
	var handoff := {"before": {}, "observed": false, "layout_observed": false}
	var rewards := {"total": 0}
	var expected_progress: Array[CombatantStats] = []
	for diver in sources:
		expected_progress.append(diver.stats.duplicate() as CombatantStats)
	battle.encounter_wave_cleared.connect(func(wave: int, _total: int) -> void:
		if wave == 1:
			handoff.before = _state(battle))
	battle.encounter_wave_started.connect(func(wave: int, _total: int) -> void:
		for enemy in battle.enemies:
			rewards.total += int(enemy.get("xp_reward", 0))
		if wave == 2:
			handoff.observed = true
			_expect(_state(battle) == handoff.before, "INT-12 handoff changed party actors/resources/effects/items")
			_expect(outcomes.is_empty(), "INT-11 intermediate outcome during handoff")
			await process_frame
			await process_frame
			var stage := battle._stage_container.get_global_rect()
			var turns := battle._queue_bar.get_global_rect()
			_expect(is_equal_approx(stage.position.y, turns.end.y), "INT-08 wave handoff leaves a strip between turn bar and stage")
			handoff.layout_observed = true
			if capture:
				await _capture("puppets-wave2"))
	root.add_child(battle)
	await process_frame
	if capture:
		await _capture("puppets-wave1")
	var roster := _roster(battle)
	_expect(roster == ["angler", "swordfish_duelist", "frilled_shark"],
		"INT-11 secret source built wrong first roster: " + str(roster))
	print("PUPPET DISPATCH|", roster)
	var xp_before: Array[int] = []
	for diver in sources:
		xp_before.append(diver.stats.xp)
	var deadline := Time.get_ticks_msec() + (120000 if capture else 45000)
	var actions := 0
	while outcomes.is_empty() and _roster(battle) == roster and Time.get_ticks_msec() < deadline:
		if battle._tutorial_awaiting_enter:
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.pressed = true
			Input.parse_input_event(enter)
		if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
			var model := String(battle._acting.model_name)
			var move := "Swift Strike" if model == "Staff_Diver" else "Precise Jab" if model == "Prototype_1(1910)" else "Guard Bash"
			_expect(await _choose(battle, move, _preferred_target(battle)), "INT-11 real move unavailable: " + move)
			actions += 1
		await process_frame
	_expect(outcomes.is_empty(), "INT-11 first wave emitted final outcome: " + str(outcomes))
	_expect(_roster(battle) == ["bomb_bot", "sword_slayer"], "INT-11 clearing first wave did not build the second: " + str(_roster(battle)))
	for index in range(sources.size()):
		_expect(sources[index].stats.xp == xp_before[index], "INT-11 first wave awarded XP")
	_expect(handoff.observed, "INT-12 no actual second-wave conservation boundary observed")
	print("PUPPET HANDOFF|actions=", actions, "|outcomes=", outcomes, "|next=", _roster(battle))
	print("PUPPET CONSERVATION|", handoff.before)
	while not handoff.layout_observed and Time.get_ticks_msec() < deadline:
		await process_frame
	# Six bounded resource shapes exercise the transfer invariant. The full
	# real win is run for the baseline; variants stop at the observed handoff.
	if oxygen != 100.0 or potions != 2:
		battle.queue_free()
		for diver in sources:
			diver.queue_free()
		await process_frame
		return
	deadline = Time.get_ticks_msec() + (180000 if capture else 60000)
	while outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 100:
		if battle._tutorial_awaiting_enter:
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.pressed = true
			Input.parse_input_event(enter)
		if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
			var model := String(battle._acting.model_name)
			var hurt := ""
			for entry in battle.party:
				var stats := entry.stats as CombatantStats
				if stats.hp > 0 and stats.hp <= 5:
					hurt = String(entry.display_name)
					break
			var move := "Swift Strike" if model == "Staff_Diver" else "Precise Jab" if model == "Prototype_1(1910)" else "Guard Bash"
			if not hurt.is_empty() and model == "Staff_Diver" and (battle._acting.stats as CombatantStats).oxygen >= 16.0:
				_expect(await _choose(battle, "Healing Current", hurt), "INT-12 normal recovery move unavailable")
			else:
				_expect(await _choose(battle, move, _preferred_target(battle)), "INT-12 second-wave move unavailable: " + move)
			actions += 1
		await process_frame
	_expect(outcomes == ["won"], "INT-11 full two-wave real fight did not produce one win: " + str(outcomes))
	for index in range(sources.size()):
		expected_progress[index].gain_xp(int(rewards.total))
		_expect(sources[index].stats.xp == expected_progress[index].xp and sources[index].stats.level == expected_progress[index].level,
			"INT-11 final victory did not grant both waves' XP once to every source diver")
	await process_frame
	for label in battle.queue_row.find_children("*", "Label", true, false):
		_expect(not ((label as Label).is_visible_in_tree() and (label as Label).text == "NOW"),
			"INT-08 final victory still claims an active turn")
	_expect(not battle._turn_cursor.visible, "INT-08 final victory leaves the active-turn cursor visible")
	print("PUPPET FINAL|actions=", actions, "|outcomes=", outcomes, "|resources=", _state(battle))
	if capture:
		await _capture("puppets-final")
	battle.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/evidence/maze-campaign-integration/" + name + ".png"
	_expect(root.get_texture().get_image().save_png(path) == OK, "Native puppet capture failed: " + name)

func _roster(battle: Battle) -> Array[String]:
	var roster: Array[String] = []
	for entry in battle.enemies:
		# A legitimately defeated Goblin frees its visual actor before the
		# resolved turn advances. Remember the observed identity by stats owner.
		var actor_value: Variant = (entry as Dictionary).get("actor")
		var owner := (entry.stats as CombatantStats).get_instance_id()
		if is_instance_valid(actor_value) and actor_value is Goblin:
			identities[owner] = (actor_value as Goblin).enemy_id()
		roster.append(String(identities.get(owner, "not-puppet")))
	return roster

func _state(battle: Battle) -> Dictionary:
	var state := {"party": [], "items": battle.inventory_source.duplicate(true)}
	for entry in battle.party:
		var stats := entry.stats as CombatantStats
		state.party.append({"resource": stats.get_instance_id(), "actor": (entry.actor as Node).get_instance_id(),
			"hp": stats.hp, "oxygen": stats.oxygen, "xp": stats.xp,
			"level": stats.level, "evasion_current": stats.evasion_current,
			"strength": stats.strength, "defense": stats.defense, "agility": stats.agility,
			"accuracy": stats.accuracy, "evasion": stats.evasion,
			"statuses": stats.statuses.duplicate(true), "temporary": stats.temporary_modifiers.duplicate(true)})
	return state

func _preferred_target(battle: Battle) -> String:
	# Threat-first target selection uses the same visible cards as a player:
	# do not spend two rounds hitting armoured Bomb Bot while Slayer bleeds us.
	for id in ["sword_slayer", "swordfish_duelist", "angler", "frilled_shark", "bomb_bot"]:
		for entry in battle.enemies:
			if (entry.stats as CombatantStats).hp > 0 and String(identities.get((entry.stats as CombatantStats).get_instance_id(), "")) == id:
				return String(entry.display_name)
	return ""

func _choose(battle: Battle, name: String, target_name: String = "") -> bool:
	battle.attack_btn.pressed.emit()
	await process_frame
	var chosen: Button
	for button in battle.move_buttons:
		if (button as Button).text.get_slice("\n", 0) == name and not (button as Button).disabled:
			chosen = button as Button
	if chosen == null:
		return false
	var pages := 0
	while not chosen.is_visible_in_tree() and pages < 8 and not battle._move_down_btn.disabled:
		battle._move_down_btn.pressed.emit()
		await process_frame
		pages += 1
	if not chosen.is_visible_in_tree():
		return false
	chosen.pressed.emit()
	await process_frame
	if battle.target_buttons.is_empty():
		return false
	var target := battle.target_buttons[0] as Button
	if not target_name.is_empty():
		target = null
		for candidate in battle.target_buttons:
			if ((candidate as Button).text.begins_with(target_name) or (candidate as Button).text.begins_with("Whole party")) and not (candidate as Button).disabled:
				target = candidate as Button
		if target == null:
			return false
	target.pressed.emit()
	return true

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
