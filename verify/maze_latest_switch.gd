extends SceneTree
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	if "--poster" in OS.get_cmdline_user_args():
		await _poster()
	else:
		await _lanes()
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("LATEST MAZE SWITCH: clean" if findings.is_empty() else "LATEST MAZE SWITCH: failed")
	quit(0 if findings.is_empty() else 1)

func _lanes() -> void:
	var modal := SwitchMinigameModal.new()
	root.add_child(modal)
	await process_frame
	var origin := modal.panel.global_position
	modal.begin_lines_drawing(origin + Vector2(modal.line_xs[0], 190))
	modal.continue_lines_drawing(origin + Vector2(modal.line_xs[2], 190))
	modal.finish_lines_drawing()
	await _capture("/tmp/maze-latest-two-lane.png")
	_expect(modal.rungs.size() == 1 and modal.rungs[0].from == 0 and modal.rungs[0].to == 2,
		"Nonadjacent portrait drag silently snaps to an adjacent lane")
	if findings.is_empty():
		var deadline := Time.get_ticks_msec() + 16000
		while (modal.lane[0] != 2 or modal._crossing[0]) and Time.get_ticks_msec() < deadline:
			await process_frame
		print("LANE CONSUMER|lanes=", modal.lane, "|used=", modal._used_rungs, "|traveling=", modal.traveling, "|crossing=", modal._crossing, "|foot=", modal._foot_y(0))
		_expect(modal.lane[0] == 2 and modal._used_rungs[0].size() == 1,
			"Actual traveling portrait does not consume the directed two-lane rung")
		modal.begin_lines_drawing(origin + Vector2(modal.line_xs[2], 440))
		modal.continue_lines_drawing(origin + Vector2(modal.line_xs[0], 440))
		modal.finish_lines_drawing()
		_expect(modal.rungs.size() == 2 and modal.rungs[1].from == 2 and modal.rungs[1].to == 0,
			"Reverse two-lane drag loses its direction")
		modal.begin_lines_drawing(origin + Vector2(modal.line_xs[0], 540))
		modal.continue_lines_drawing(origin + Vector2(modal.line_xs[0] + 8, 540))
		modal.finish_lines_drawing()
		_expect(modal.rungs.size() == 2, "Short same-lane drag invents a rung")
	modal.queue_free()
	await process_frame

func _poster() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	maze.random_encounters_enabled = false
	maze.room_encounters_enabled = false
	maze._switch_explained = true
	var poster: MazePoster = maze._posters[2]
	var found := false
	for amount in [0.6, 0.7, 0.8]:
		maze.divers[maze.active].global_position = maze._switch_node.global_position.lerp(poster.global_position, amount) + poster.facing() * 0.35
		maze.divers[maze.active].global_position.y = 0
		await physics_frame
		var to_switch := maze._switch_node.global_position - maze._diver.global_position
		to_switch.y = 0
		var to_poster := poster.global_position - maze._diver.global_position
		to_poster.y = 0
		print("POSTER CONSUMER|poster=", to_poster.length(), "|switch=", to_switch.length(), "|reachable=", maze._poster_in_reach() == poster, "/", maze._diver_near_switch())
		if maze._poster_in_reach() == poster and maze._diver_near_switch() and to_poster.length() < to_switch.length():
			found = true
			break
	_expect(found, "Poster/switch overlap fixture is not valid at current geometry")
	if found:
		# Let the real room-entry explainer claim its input before dismissing it;
		# a one-physics-frame fixture can deliver E while that deferred UI opens.
		for frame in range(5):
			await physics_frame
			await process_frame
		var popup := root.get_node_or_null("CharacterAbilityPopup")
		if popup != null and paused:
			(popup.get_node("%PopupClose") as Button).pressed.emit()
			await process_frame
		print("POSTER BEFORE E|paused=", paused, "|modal=", maze.any_modal_open(), "|cooldown=", maze._interact_cooldown)
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		await process_frame
		event = InputEventKey.new()
		event.keycode = KEY_E
		Input.parse_input_event(event)
		await process_frame
		print("POSTER AFTER E|poster=", maze.poster_modal_open(), "|switch=", maze.switch_modal_open(), "|paused=", paused)
		_expect(maze.poster_modal_open() and not maze.switch_modal_open(),
			"Nearby switch steals real E from the closer poster")
		await _capture("/tmp/maze-latest-poster.png")
	maze.queue_free()
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _capture(output: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	for frame in range(4):
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output)
