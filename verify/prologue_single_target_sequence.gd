# SOLO-001/002: real player choice -> individual normal-stat deaths, not AoE.
extends SceneTree
var findings: Array[String] = []
var output := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = String(args[0])
		DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 720)
	var sources: Array[Diver] = []
	for model in ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]:
		var diver := Diver.new()
		diver.model_name = model
		root.add_child(diver)
		sources.append(diver)
	var fight := Battle.new()
	fight.prologue_angler_encounter = true
	fight.party_source = sources
	root.add_child(fight)
	await process_frame
	await process_frame
	await fight.reveal_prologue_octopus()
	var outcomes: Array[String] = []
	fight.finished.connect(func(outcome: String) -> void: outcomes.append(outcome))
	var before := _hp(fight)
	var observations: Array[Dictionary] = []
	var audio := root.get_node("GameAudio")
	audio.clear_sfx_event_trace()
	fight.attack_btn.pressed.emit()
	await process_frame
	(fight.move_buttons[0] as Button).pressed.emit()
	await process_frame
	(fight.target_buttons[0] as Button).pressed.emit()
	var started := Time.get_ticks_msec()
	var next_capture := started
	var frame_number := 0
	var choices := 1
	var ready_since := 0
	while outcomes.is_empty() and Time.get_ticks_msec() - started < 35000:
		await process_frame
		if not output.is_empty() and Time.get_ticks_msec() >= next_capture:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("frame-%04d.png" % frame_number))
			frame_number += 1
			next_capture = Time.get_ticks_msec() + 125
		var current := _hp(fight)
		if current != before:
			var changed: Array[int] = []
			for index in range(3):
				if before[index] != current[index]:
					changed.append(index)
			var living := current.filter(func(hp: int) -> bool: return hp > 0).size()
			observations.append({"changed": changed, "hp": current.duplicate(), "living": living, "time": Time.get_ticks_msec(), "clip": (fight.enemies[0].actor.anim as AnimationPlayer).current_animation})
			_expect(changed.size() == 1, "SOLO-001 boss changes multiple divers' HP in one frame: %s" % [changed])
			_expect(outcomes.is_empty(), "SOLO-002 final outcome emitted before individual impacts can be read")
			_expect(fight.attack_btn.disabled and not fight.main_menu.visible and not fight.move_menu.visible, "SOLO-005 player controls remain active during Cordys's response")
			_expect(String(fight._acting.display_name) == "Cordys", "SOLO-005 NOW names a diver during Cordys's strikes")
			before = current
		if observations.size() == choices and choices < 3 and fight.main_menu.visible and not fight.attack_btn.disabled:
			if ready_since == 0:
				ready_since = Time.get_ticks_msec()
				_expect(String(fight._acting.display_name) == ["Maxilani", "Musashi", "Bucky"][choices], "SOLO-007 next living diver does not receive a real turn")
			if Time.get_ticks_msec() - ready_since >= 1000:
				_expect(_hp(fight) == before and outcomes.is_empty(), "SOLO-007 Cordys attacked while the player was deciding")
				fight.attack_btn.pressed.emit()
				await process_frame
				(fight.move_buttons[0] as Button).pressed.emit()
				await process_frame
				(fight.target_buttons[0] as Button).pressed.emit()
				choices += 1
				ready_since = 0
	_expect(observations.size() == 3, "SOLO-001 expected three separate targeted impacts, got %s" % [observations])
	if observations.size() == 3:
		for index in range(3):
			var row := observations[index]
			var fragments := ["OctoStab", "Head_Bash", "Eletric_Shooting"]
			_expect(String(row.clip).contains(fragments[index]), "SOLO-003 missing distinct attack at impact: %s" % row)
			_expect(row.changed == [index] and row.living == 2 - index and row.hp[index] == 0, "SOLO-001 starting diver is not one-shot individually: %s" % row)
			if index > 0:
				_expect(row.time - observations[index - 1].time >= 1000, "SOLO-001 deaths are too close to read individually")
	_expect(outcomes == ["prologue_defeat"] and _hp(fight) == [0, 0, 0], "SOLO-002 sequence does not emit exactly one final defeat after all real deaths")
	_expect(choices == 3, "SOLO-007 automatic wipe removed intervening player attacks: %d choices" % choices)
	_expect(audio.get_sfx_event_trace().count("combat_heavy_hit") == 3 and audio.get_sfx_event_trace().count("combat_heavy_swing") == 3, "SOLO-005 missing/stacked swing or impact cues: %s" % [audio.get_sfx_event_trace()])
	print("CORDYS TARGETED SEQUENCE|", observations)
	fight.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("CORDYS TARGETED SEQUENCE: clean" if findings.is_empty() else "CORDYS TARGETED SEQUENCE: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _hp(fight: Battle) -> Array[int]:
	var values: Array[int] = []
	for entry in fight.party:
		values.append((entry.stats as CombatantStats).hp)
	return values

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
