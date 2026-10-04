extends SceneTree
## LAB-BAL-001/002/003: real earned kits, real buttons, real terminal outcomes.
## Engine time is accelerated for batch runs; stats, O2, RNG and turns are not.
const SEEDS := 8
var findings: Array[String] = []
var output := ""

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		output = OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	Engine.time_scale = 12.0 if output.is_empty() else 2.0
	for level in [2, 3]:
		for policy in ["accessible", "skilled"]:
			var wins := 0
			var count := SEEDS if output.is_empty() else 1
			for index in range(count):
				var result := await _fight(level, policy, 62000 + index)
				wins += 1 if result == "won" else 0
			print("LAB REAL BALANCE|level=%d|policy=%s|wins=%d/%d" % [level, policy, wins, count])
			_expect(wins >= int(ceil(count * (0.75 if policy == "skilled" else 0.50))),
				"LAB-BAL-002 level %d %s real wins %d/%d below attainable-victory band" % [level, policy, wins, count])
	Engine.time_scale = 1.0
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("LAB REAL BALANCE: clean" if findings.is_empty() else "LAB REAL BALANCE: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _fight(level: int, policy: String, rng_seed: int) -> String:
	var sources: Array[Diver] = []
	for model in Battle.DISPLAY_NAMES:
		var diver := Diver.new()
		diver.model_name = model
		root.add_child(diver)
		# Earn through ordinary XP and automatic learning, with no keys/shards.
		while diver.stats.level < level:
			diver.stats.gain_xp(10 if diver.stats.level == 1 else 11)
			SpellTree.learn_all_available(diver, [])
		sources.append(diver)
	var battle := Battle.new()
	battle.boss_encounter = true
	battle.boss_intro_enabled = true # Use the real intro-to-first-turn handoff.
	battle.encounter_source = "lab_boss"
	battle.party_source = sources
	var outcomes: Array[String] = []
	battle.finished.connect(func(result: String) -> void: outcomes.append(result))
	seed(rng_seed)
	root.add_child(battle)
	await process_frame
	var actions := 0
	var lowest_party_hp := 30
	var minimum_living := 3
	var lowest_oxygen := 100.0
	var deadline := Time.get_ticks_msec() + (45000 if output.is_empty() else 150000)
	var captured_loss := false
	while outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 80:
		var total_hp := 0
		var living := 0
		for entry in battle.party:
			total_hp += int(entry.stats.hp)
			living += 1 if entry.stats.hp > 0 else 0
			lowest_oxygen = minf(lowest_oxygen, entry.stats.oxygen)
		lowest_party_hp = mini(lowest_party_hp, total_hp)
		minimum_living = mini(minimum_living, living)
		if actions <= 6:
			_expect(living >= 2, "LAB-BAL-001 first two rounds eliminate the viable party")
		if battle._tutorial_awaiting_enter:
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.pressed = true
			Input.parse_input_event(enter)
		# Never press a timing-dodge input: a lucky QTE cannot carry this gate.
		if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
			var name := _choice(battle, policy)
			var selected := await _choose(battle, name)
			_expect(selected, "LAB-BAL-002 earned move not reachable through menu: " + name)
			actions += 1
			if not selected:
				break
		if not output.is_empty() and not captured_loss and battle.party.any(func(entry: Dictionary) -> bool: return entry.stats.hp < 10):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("level-%d-%s-live-combat.png" % [level, policy]))
			captured_loss = true
		await process_frame
	var result := outcomes[0] if not outcomes.is_empty() else "timeout"
	print("LAB REAL FIGHT|level=%d|policy=%s|seed=%d|result=%s|actions=%d|boss_hp=%d|min_party_hp=%d|min_living=%d|min_oxygen=%.1f" % [level, policy, rng_seed, result, actions, (battle.enemies[0].stats as CombatantStats).hp, lowest_party_hp, minimum_living, lowest_oxygen])
	_expect(result != "timeout", "LAB-BAL-002 real fight timed out or lost input")
	_expect(lowest_party_hp < 30, "LAB-BAL-001 tuned boss never damages the party")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("level-%d-%s-%s.png" % [level, policy, result]))
	for diver in sources:
		_expect(diver.stats.hp_max == 10, "LAB-BAL-003 victory fixture inflated party HP")
	battle.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame
	await process_frame
	return result

func _choice(battle: Battle, policy: String) -> String:
	var entry := battle._acting
	var model := String(entry.model_name)
	var enemy := battle.enemies[0].stats as CombatantStats
	if model == "Staff_Diver":
		if policy == "skilled" and enemy.status_turns("blindness") <= 1:
			return "Flash Blast"
		return "Swift Strike" if entry.stats.oxygen >= 8.0 else "Axe Kick"
	if model == "Prototype_1(1910)":
		if policy == "skilled" and enemy.effective_defense() > 0 and entry.stats.oxygen >= 10.0:
			return "Weaken"
		return "Precise Jab" if entry.stats.oxygen >= 8.0 else "Precise Tap"
	if policy == "skilled" and entry.equipped_spells.has("mending_current") and entry.stats.oxygen >= 8.0 and battle.party.any(func(ally: Dictionary) -> bool: return ally.stats.hp > 0 and ally.stats.hp <= 5):
		return "Mending Current"
	return "Guard Bash"

func _choose(battle: Battle, move_name: String) -> bool:
	battle.attack_btn.pressed.emit()
	await process_frame
	var selected: Button
	for value in battle.move_buttons:
		var button := value as Button
		if button.text.get_slice("\n", 0) == move_name and not button.disabled:
			selected = button
			break
	if selected == null:
		return false
	# Do not emit a hidden spell's signal: use the player's actual paging button.
	var pages := 0
	while not selected.is_visible_in_tree() and pages < 6 and not battle._move_down_btn.disabled:
		battle._move_down_btn.pressed.emit()
		await process_frame
		pages += 1
	if not selected.is_visible_in_tree():
		return false
	selected.pressed.emit()
	await process_frame
	if battle.target_buttons.is_empty():
		return false
	var target := battle.target_buttons[0] as Button
	if move_name == "Mending Current":
		var lowest := INF
		for value in battle.target_buttons:
			var candidate := value as Button
			for entry in battle.party:
				if candidate.text.begins_with(String(entry.display_name)) and entry.stats.hp > 0 and entry.stats.hp < lowest:
					lowest = entry.stats.hp
					target = candidate
	target.pressed.emit()
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
