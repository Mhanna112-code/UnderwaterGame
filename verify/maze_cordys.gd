extends SceneTree
## INT-15: campaign rematch must not become Tethys or the forced-loss opener.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture := "--capture-cordys" in OS.get_cmdline_user_args()
	Engine.time_scale = 1.0 if capture else 10.0
	seed(77124)
	var sources: Array[Diver] = []
	for model in Cast.ALL:
		var diver := Diver.new()
		diver.model_name = model
		root.add_child(diver)
		# Legal consumer kit, not proof of an earned maze route.
		while diver.stats.level < 5:
			diver.stats.gain_xp(10)
		SpellTree.learn_all_available(diver, [])
		sources.append(diver)
	var battle := Battle.new()
	battle.encounter_source = "maze_cordys"
	battle.party_source = sources
	battle.inventory_source = {"potion": 2}
	var outcomes: Array[String] = []
	battle.finished.connect(func(result: String) -> void: outcomes.append(result))
	root.add_child(battle)
	await process_frame
	_expect(battle.enemies.size() == 1, "INT-15 finale must have exactly one Cordys")
	if battle.enemies.size() == 1:
		var enemy := battle.enemies[0] as Dictionary
		var actor := enemy.actor as Node3D
		_expect(actor is PrologueOctopus and String(enemy.display_name) == "Cordys",
			"INT-15 finale dispatch constructed " + String(enemy.display_name))
		_expect((enemy.stats as CombatantStats).hp_max < 1000
			and (enemy.stats as CombatantStats).strength < 80,
			"INT-15 finale inherited overpowering opening stats")
	_expect(not battle.prologue_octopus_encounter and not battle.boss_encounter,
		"INT-15 finale inherited opening forced loss or lab ownership")
	print("CORDYS DISPATCH|source=", battle.encounter_source, "|enemies=", battle.enemies.size())
	if capture and findings.is_empty():
		await _capture("cordys-reveal")
	if findings.is_empty() and not "--dispatch-only" in OS.get_cmdline_user_args():
		var deadline := Time.get_ticks_msec() + (300000 if capture else 90000)
		var actions := 0
		while outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 90:
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
					if stats.hp > 0 and stats.hp <= 6:
						hurt = String(entry.display_name)
						break
				var move := "Swift Strike" if model == "Staff_Diver" else "Precise Jab" if model == "Prototype_1(1910)" else "Guard Bash"
				var target := "Cordys"
				if not hurt.is_empty() and model == "Staff_Diver" and (battle._acting.stats as CombatantStats).oxygen >= 16:
					move = "Healing Current"
					target = hurt
				_expect(await _choose(battle, move, target), "INT-15 real move inaccessible: " + move)
				actions += 1
				if capture and actions == 3:
					await _capture("cordys-player-action")
			await process_frame
		_expect(outcomes == ["won"], "INT-15 real rematch did not produce one victory: " + str(outcomes))
		var state: Array = []
		for diver in sources:
			_expect(diver.stats.hp_max == 10, "INT-15 consumer inflated party HP")
			state.append({"hp": diver.stats.hp, "oxygen": diver.stats.oxygen, "xp": diver.stats.xp, "level": diver.stats.level})
		print("CORDYS FINAL|actions=", actions, "|outcomes=", outcomes, "|party=", state, "|items=", battle.inventory_source)
		if capture:
			await _capture("cordys-victory")
	battle.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	Engine.time_scale = 1.0
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE CORDYS: clean" if findings.is_empty() else "MAZE CORDYS: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _choose(battle: Battle, move: String, target: String) -> bool:
	battle.attack_btn.pressed.emit()
	await process_frame
	var chosen: Button
	for button in battle.move_buttons:
		if (button as Button).text.get_slice("\n", 0) == move and not (button as Button).disabled:
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
	for button in battle.target_buttons:
		if (button as Button).text.begins_with(target) and not (button as Button).disabled:
			(button as Button).pressed.emit()
			return true
	return false

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("res://docs/evidence/maze-campaign-integration/" + name + ".png") == OK,
		"INT-15 native capture failed: " + name)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
