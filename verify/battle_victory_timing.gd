extends "res://verify/maze_puppet_waves.gd"
## END-1: actual attacks must replace combat music during Victory, not afterward.

func _run() -> void:
	Engine.time_scale = 6.0
	seed(90501)
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	# Fixed real ordinary roster; baseline stats, normal damage, no injected win.
	world._start_battle("", false, "angler", [], false, false, "", false, ["angler"])
	var battle := world.battle
	var audio := root.get_node("GameAudio") as UnderwaterAudioManager
	var outcomes: Array[String] = []
	battle.finished.connect(func(result: String) -> void: outcomes.append(result))
	var observed_victory := false
	var actions := 0
	var deadline := Time.get_ticks_msec() + 30000
	while outcomes.is_empty() and Time.get_ticks_msec() < deadline:
		if battle._tutorial_awaiting_enter:
			var enter := InputEventKey.new()
			enter.keycode = KEY_ENTER
			enter.pressed = true
			Input.parse_input_event(enter)
		for node in battle.queue_row.get_children():
			if node is Label and node.text == "Victory" and node.is_visible_in_tree():
				if not observed_victory:
					observed_victory = true
					_expect(audio.get_music_state().cue_id == "victory",
						"END-1 Victory is on screen but main battle music is still playing")
					_expect(world.battle == battle and world.battling, "END-1 cue was observed only after leaving Battle")
		if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
			var model := String(battle._acting.model_name)
			var move := "Electric Touch" if model == "Staff_Diver" else "Precise Tap" if model == "Prototype_1(1910)" else "Guard Bash"
			_expect(await _choose(battle, move), "END fixture move unavailable: " + move)
			actions += 1
		await process_frame
	_expect(observed_victory and outcomes == ["won"], "END fixture never reached actual Victory: " + str(outcomes))
	await process_frame
	_expect(audio.get_music_state().cue_id == "exploration", "END-1 victory music starts/persists after returning to World")
	print("VICTORY TIMING|actions=", actions, "|outcomes=", outcomes, "|visible_victory=", observed_victory)
	world.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	paused = false
	audio.release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("BATTLE VICTORY TIMING: clean" if findings.is_empty() else "BATTLE VICTORY TIMING: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
