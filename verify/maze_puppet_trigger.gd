extends SceneTree
## INT-11: the real secret-room prompt must dispatch puppets, not lab Tethys.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	var audio := root.get_node("GameAudio") as UnderwaterAudioManager
	_expect(String(audio.get_music_state().cue_id) == "exploration",
		"INT-16 real maze entry has no exploration music owner")
	var sonar := InputEventKey.new()
	sonar.keycode = KEY_Q
	sonar.pressed = true
	Input.parse_input_event(sonar)
	await process_frame
	await process_frame
	_expect(maze.divers[0].sonar_active, "INT-12 real Q did not enable sonar before fight")
	var guard := maze._boss_triggers.get("secret_boss") as Node3D
	if guard == null:
		findings.append("INT-11 secret approach has no guard")
	else:
		# Disclosed location fixture: normal collision/proximity and real Yes
		# input own the start. This is not full maze navigation acceptance.
		if "--capture-puppets" in OS.get_cmdline_user_args():
			maze.divers[maze.active].global_position = guard.global_position + Vector3(0, 1, 4.5)
			# The default entrance looks +Z. This approach is from +Z, so aim
			# back at the guard through actual mouse events, not a camera helper.
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(640, 360)
			Input.parse_input_event(click)
			await process_frame
			var look := InputEventMouseMotion.new()
			look.relative = Vector2(-PI / 0.004, 0)
			Input.parse_input_event(look)
			await process_frame
			for frame in range(45):
				await physics_frame
			await _capture("puppets-approach")
		maze.divers[maze.active].global_position = guard.global_position + Vector3.UP
		for frame in range(20):
			await physics_frame
			if maze.any_modal_open():
				break
		_expect(maze.any_modal_open(), "INT-11 guard proximity did not open confirmation")
		if "--capture-puppets" in OS.get_cmdline_user_args():
			await _capture("puppets-confirmation")
		var yes := InputEventKey.new()
		yes.keycode = KEY_Y
		yes.pressed = true
		Input.parse_input_event(yes)
		await process_frame
		await process_frame
		var battles := maze.find_children("*", "Battle", false, false)
		_expect(battles.size() == 1, "INT-11 confirmation did not create exactly one battle")
		if battles.size() == 1:
			var battle := battles[0] as Battle
			var roster: Array[String] = []
			for entry in battle.enemies:
				var actor := entry.actor as Node3D
				roster.append((actor as Goblin).enemy_id() if actor is Goblin else "not-puppet")
			_expect(battle.encounter_source == "maze_puppets" and roster == ["angler", "swordfish_duelist", "frilled_shark"],
				"INT-11 actual secret confirmation dispatched wrong encounter: " + battle.encounter_source + str(roster))
			print("PUPPET APPROACH|source=", battle.encounter_source, "|roster=", roster)
			_expect(String(audio.get_music_state().cue_id) == "battle" and String(audio.get_music_state().phase) == "intro",
				"INT-16 real puppet start did not select Battle INTRO")
			var oxygen_before := maze.divers[0].stats.oxygen
			await create_timer(3.4).timeout
			_expect(maze.divers[0].stats.oxygen == oxygen_before,
				"INT-12 exploration sonar continues draining shared oxygen during combat")
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE PUPPET TRIGGER: clean" if findings.is_empty() else "MAZE PUPPET TRIGGER: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("res://docs/evidence/maze-campaign-integration/" + name + ".png") == OK,
		"Native approach capture failed: " + name)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
