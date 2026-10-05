extends "res://verify/maze_puppet_waves.gd"
## INT-13: a real two-wave maze win earns one maze key, never lab completion.

func _run() -> void:
	Engine.time_scale = 10.0
	seed(64221)
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	world.route_state.set_zone("deep")
	world.route_state.set_maze_door_state("available")
	for diver in world.divers:
		while diver.stats.level < 5:
			diver.stats.gain_xp(10)
		SpellTree.learn_all_available(diver, [])
	# Disclosed location fixtures: actual entrance/contact/Yes own transitions.
	# XP establishes a legal consumer kit, not earned progression/navigation.
	world.divers[0].global_position = world.deep_zone_layout.route_points().maze_transition
	for frame in range(20):
		await physics_frame
		if current_scene is MazeLevel:
			break
	if not current_scene is MazeLevel:
		findings.append("INT-13 actual campaign entrance did not reach maze")
		await _finish_reward()
		return
	var maze := current_scene as MazeLevel
	var lab_before := [maze.route_state.bomb_bot_state, maze.route_state.sword_slayer_state, maze.route_state.lab_state, maze.route_state.tethys_state]
	var keys_before := maze.keys_held
	var sonar_before := maze.divers[0].sonar_active
	var guard := maze._boss_triggers.secret_boss as Node3D
	maze.divers[maze.active].global_position = guard.global_position + Vector3.UP
	for frame in range(20):
		await physics_frame
		if maze.any_modal_open():
			break
	var yes := InputEventKey.new()
	# Freeze combat randomness at the interaction boundary, independently of
	# procedural scenery/poster RNG consumed during World/Maze construction.
	# This is one attainable reward-consumer victory, not all-roll balance proof.
	var battle_seed := 64222
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--battle-seed="):
			battle_seed = int(arg.trim_prefix("--battle-seed="))
	seed(battle_seed)
	print("PUPPET REWARD SEED|", battle_seed)
	yes.keycode = KEY_Y
	yes.pressed = true
	Input.parse_input_event(yes)
	await process_frame
	await process_frame
	var battles := maze.find_children("*", "Battle", false, false)
	if battles.size() != 1:
		print("PUPPET APPROACH DIAGNOSTIC|paused=", paused, "|modal=", maze.any_modal_open(), "|active=", maze.active, "|guard=", guard.global_position, "|diver=", maze.divers[maze.active].global_position)
		for button in root.find_children("*", "Button", true, false):
			if (button as Button).is_visible_in_tree():
				print("VISIBLE BUTTON|", (button as Button).text)
		findings.append("INT-13 actual puppet approach did not start one fight")
		maze.queue_free()
		await _finish_reward()
		return
	var battle := battles[0] as Battle
	var audio := root.get_node("GameAudio") as UnderwaterAudioManager
	var music_trace := audio.get_music_transition_trace()
	battle.encounter_wave_started.connect(func(wave: int, _total: int) -> void:
		if wave == 2:
			_expect(audio.get_music_transition_trace() == music_trace and String(audio.get_music_state().cue_id) == "battle",
				"INT-16 puppet handoff restarted or replaced Battle music"))
	var outcomes: Array[String] = []
	battle.finished.connect(func(result: String) -> void: outcomes.append(result))
	var actions := 0
	var deadline := Time.get_ticks_msec() + 90000
	while outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 100:
		_roster(battle)
		if battle._tutorial_awaiting_enter:
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.pressed = true
			Input.parse_input_event(enter)
		if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
			var model := String(battle._acting.model_name)
			var move := "Swift Strike" if model == "Staff_Diver" else "Precise Jab" if model == "Prototype_1(1910)" else "Guard Bash"
			var target := _preferred_target(battle)
			# Clear the first wave's threats before spending turns healing;
			# delaying Angler lets its persistent Bleed stack. Same observed
			# threat-first policy as the continuous-Battle consumer baseline.
			if _roster(battle) == ["bomb_bot", "sword_slayer"] and model == "Staff_Diver" and (battle._acting.stats as CombatantStats).oxygen >= 16:
				for entry in battle.party:
					var stats := entry.stats as CombatantStats
					if stats.hp > 0 and stats.hp <= 5:
						move = "Healing Current"
						target = String(entry.display_name)
						break
			var chosen := await _choose(battle, move, target)
			_expect(chosen, "INT-13 actual move unavailable: " + move)
			if not chosen:
				print("PUPPET MOVE DIAGNOSTIC|model=", model, "|state=", _state(battle))
				for button in battle.move_buttons:
					print("MOVE BUTTON|", (button as Button).text, "|disabled=", (button as Button).disabled)
				break
			actions += 1
			print("PUPPET REWARD ACTION|", actions, "|move=", move, "|target=", target, "|state=", _state(battle))
		await process_frame
	_expect(outcomes == ["won"], "INT-13 actual maze waves did not win: " + str(outcomes))
	await process_frame
	_expect(maze.keys_held == keys_before + 1 and maze.key_items.count("abyss_key") == 1,
		"INT-13 actual puppet victory did not earn exactly one maze key")
	_expect([maze.route_state.bomb_bot_state, maze.route_state.sword_slayer_state, maze.route_state.lab_state, maze.route_state.tethys_state] == lab_before,
		"INT-13 puppet victory changed independent laboratory progress")
	_expect(not maze.campaign_key_items.has("abyss_key"), "INT-13 maze key polluted campaign spell relics")
	_expect(String(audio.get_music_state().cue_id) == "exploration", "INT-16 actual puppet victory did not return exploration music")
	_expect(maze.divers[0].sonar_active == sonar_before and not maze.divers[0].exploration_paused,
		"INT-12 resolved battle changed Sonar preference or left exploration suspended")
	var oxygen_after := maze.divers[0].stats.oxygen
	await create_timer(3.4).timeout
	if sonar_before and maze.divers[0].stats.hp > 0:
		_expect(maze.divers[0].stats.oxygen < oxygen_after,
			"INT-12 returning to exploration did not resume normal Sonar billing")
	var snapshot := maze.campaign_snapshot()
	_expect(not snapshot.boss_triggers.has("secret_boss") and snapshot.boss_triggers.has("main_boss"),
		"INT-13 puppet win did not complete only its own guardian")
	var restored := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(restored)
	await process_frame
	_expect(restored.snapshot_matches_runtime(snapshot), "INT-13 actual puppet-win snapshot invalid")
	if restored.snapshot_matches_runtime(snapshot):
		restored.restore_campaign_snapshot(snapshot)
		await process_frame
		_expect(restored.keys_held == keys_before + 1 and not restored.campaign_snapshot().boss_triggers.has("secret_boss"),
			"INT-13 restored maze repeated guardian or lost its key")
	print("PUPPET MAZE WIN|actions=", actions, "|outcomes=", outcomes, "|keys=", maze.keys_held, "|remaining=", snapshot.boss_triggers, "|lab=", lab_before)
	restored.queue_free()
	maze.queue_free()
	await _finish_reward()

func _finish_reward() -> void:
	await process_frame
	Engine.time_scale = 1.0
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE PUPPET REWARD: clean" if findings.is_empty() else "MAZE PUPPET REWARD: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
