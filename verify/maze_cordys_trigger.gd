extends SceneTree
## INT-15: confirmed final approach starts Cordys, not laboratory Tethys.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 10.0
	seed(77124)
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	maze.route_state = RouteState.new()
	for diver in maze.divers:
		while diver.stats.level < 5:
			diver.stats.gain_xp(10)
		SpellTree.learn_all_available(diver, [])
	var station := maze._boss_triggers.get("main_boss") as Node3D
	if station == null:
		findings.append("INT-15 no authored finale station")
	else:
		# Location fixture, not navigation/key proof. Real proximity and Y own start.
		maze.divers[maze.active].global_position = station.global_position + Vector3(-4, 1.2, 0)
		for frame in range(20):
			await physics_frame
			if maze.any_modal_open():
				break
		if not maze.any_modal_open() or maze._battling:
			findings.append("INT-15 approach did not wait for confirmation")
		var yes := InputEventKey.new()
		yes.keycode = KEY_Y
		yes.pressed = true
		Input.parse_input_event(yes)
		await process_frame
		yes = InputEventKey.new()
		yes.keycode = KEY_Y
		Input.parse_input_event(yes)
		await process_frame
		var battles := maze.find_children("*", "Battle", false, false)
		if battles.size() != 1:
			findings.append("INT-15 confirmation did not start exactly one fight")
		else:
			var battle := battles[0] as Battle
			var enemy := battle.enemies[0] as Dictionary
			if battle.encounter_source != "maze_cordys" or not enemy.actor is PrologueOctopus or String(enemy.display_name) != "Cordys":
				findings.append("INT-15 confirmed approach dispatched " + String(enemy.display_name) + " source=" + battle.encounter_source)
			print("CORDYS CONFIRMED|source=", battle.encounter_source, "|actor=", enemy.display_name)
			var audio := root.get_node("GameAudio") as UnderwaterAudioManager
			if String(audio.get_music_state().cue_id) != "cordys":
				findings.append("INT-16 real Cordys start did not select Final Boss music")
			if findings.is_empty() and "--real-win" in OS.get_cmdline_user_args():
				var outcomes: Array[String] = []
				battle.finished.connect(func(result: String) -> void: outcomes.append(result))
				var deadline := Time.get_ticks_msec() + 90000
				var actions := 0
				while outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 90:
					if battle._tutorial_awaiting_enter:
						var enter := InputEventKey.new()
						enter.keycode = KEY_ENTER
						enter.pressed = true
						Input.parse_input_event(enter)
					if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
						var model := String(battle._acting.model_name)
						var move := "Swift Strike" if model == "Staff_Diver" else "Precise Jab" if model == "Prototype_1(1910)" else "Guard Bash"
						var target := "Cordys"
						for entry in battle.party:
							var stats := entry.stats as CombatantStats
							if model == "Staff_Diver" and stats.hp > 0 and stats.hp <= 6 and (battle._acting.stats as CombatantStats).oxygen >= 16:
								move = "Healing Current"
								target = String(entry.display_name)
								break
						if not await _choose(battle, move, target):
							findings.append("INT-15 actual maze action unavailable: " + move)
							break
						actions += 1
					await process_frame
				if outcomes != ["won"]:
					findings.append("INT-15 actual confirmed fight did not win: " + str(outcomes))
				await process_frame
				var snapshot := maze.campaign_snapshot()
				if String(audio.get_music_state().cue_id) != "exploration":
					findings.append("INT-16 actual finale victory left boss music in exploration")
				if maze.route_state.octopus_state != "defeated" or maze.route_state.tethys_state != "locked" or maze.route_state.bomb_bot_state != "available" or maze.route_state.sword_slayer_state != "available":
					findings.append("INT-15 real Cordys win did not update independent campaign boss state")
				if snapshot.boss_triggers.has("main_boss") or not snapshot.boss_triggers.has("secret_boss"):
					findings.append("INT-15 actual win did not complete Cordys independently of puppets")
				var restored := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
				root.add_child(restored)
				await process_frame
				if not restored.snapshot_matches_runtime(snapshot):
					findings.append("INT-15 actual completed-maze snapshot is invalid")
				else:
					restored.restore_campaign_snapshot(snapshot)
					await process_frame
					if restored.campaign_snapshot().boss_triggers.has("main_boss"):
						findings.append("INT-15 restored maze resurrected defeated Cordys")
					if not restored.find_children("*", "PrologueOctopus", true, false).is_empty():
						findings.append("INT-15 restored completed room resurrected Cordys model")
				print("CORDYS MAZE WIN|actions=", actions, "|outcomes=", outcomes, "|remaining=", snapshot.boss_triggers)
				restored.queue_free()
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	Engine.time_scale = 1.0
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE CORDYS TRIGGER: clean" if findings.is_empty() else "MAZE CORDYS TRIGGER: %d findings" % findings.size())
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
