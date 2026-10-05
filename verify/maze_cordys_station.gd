extends SceneTree
## CS-1/2/3/5: visible stationed Cordys requires deliberate confirmation.
var findings: Array[String] = []
var maze: MazeLevel
var actor: PrologueOctopus

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 720)
	maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	var actors := maze.find_children("*", "PrologueOctopus", true, false)
	_expect(actors.size() == 1, "CS-1 main room has no single visible stationed Cordys")
	if actors.size() != 1:
		await _finish()
		return
	actor = actors[0] as PrologueOctopus
	var station := actor.global_position
	var room := maze._main_boss_room_rect()
	print("CORDYS STATION|position=", station, "|room=", room, "|door_z=", maze._main_boss_door_z)
	_expect(actor.is_visible_in_tree() and room.has_point(Vector2(station.x, station.z)), "CS-1 Cordys is hidden or outside opposite boss room")
	var bounds := actor.current_pose_bounds()
	_expect(bounds.position.y >= maze._maze_floor_top() - 0.05, "CS-5 Cordys mesh is inside floor")
	_expect(absf(bounds.position.y - maze._maze_floor_top() - 0.3) < 0.1, "CS-5 Cordys floats above intended floor placement")
	for corner in 8:
		var point := bounds.get_endpoint(corner)
		_expect(room.has_point(Vector2(point.x, point.z)), "CS-5 idle skin intersects boss-room wall")
	for frame in 60:
		await physics_frame
		_expect(actor.global_position.distance_to(station) < 0.001, "CS-1 Cordys patrols instead of remaining stationed at frame %d" % frame)
	# An inactive companion in range must not trigger the active diver's fight.
	maze.divers[1].global_position = station + Vector3.UP
	for frame in 6:
		await physics_frame
	_expect(not maze.any_modal_open() and not maze._battling, "CS-3 companion proximity initiates finale")
	maze.divers[1].global_position = maze.entrance_point() + Vector3(0, 2, 2)
	# Isolated key fixture: unlock the actual entrance with E so the normal
	# approach camera is not trapped against a door we bypassed for setup.
	var door := maze.get_node("MazeDoorMainBoss") as KeyDoor
	maze.keys_held = 1
	maze._diver.global_position = door.global_position + Vector3(-1.5, 1.2, 0)
	await _key(KEY_E)
	await create_timer(1.5).timeout
	_expect(door.is_open() and maze.keys_held == 0, "CS-5 actual E did not open main-room entrance")
	var snapshot := maze.campaign_snapshot()
	_expect(snapshot.boss_triggers.has("main_boss"), "CS-4 living Cordys lost completion identity")
	for index in 3:
		while maze.active != index:
			await _key(KEY_TAB)
		var diver := maze.divers[index] as Diver
		diver.global_position = station + Vector3(-10, 1.2, 0)
		diver.velocity = Vector3.ZERO
		await _look(PI / 2.0)
		await create_timer(0.4).timeout
		if index == 0:
			# Other UI owns input at an otherwise eligible physical approach.
			maze.inventory_menu.open()
			diver.global_position = station + Vector3(-4, 1.2, 0)
			for frame in 6:
				await physics_frame
			_expect(maze.find_children("*", "ConfirmPromptModal", false, false).is_empty() and not maze._battling, "CS-3 station interrupts inventory owner")
			diver.global_position = station + Vector3(-10, 1.2, 0)
			maze.inventory_menu.close()
			await create_timer(0.5).timeout
			await _capture("station")
		await _press(KEY_W, true)
		var deadline := Time.get_ticks_msec() + 8000
		while not maze.any_modal_open() and not maze._battling and Time.get_ticks_msec() < deadline:
			await physics_frame
		await _press(KEY_W, false)
		var prompts := maze.find_children("*", "ConfirmPromptModal", false, false)
		print("CORDYS APPROACH|diver=", index, "|position=", diver.global_position, "|yaw=", maze._yaw, "|prompt=", prompts.size(), "|battle=", maze._battling, "|armed=", maze._cordys_prompt_armed)
		_expect(prompts.size() == 1 and not maze._battling, "CS-1 real approach did not reach confirmation for diver %d at %s (battle=%s)" % [index, diver.global_position, maze._battling])
		if prompts.size() != 1:
			break
		var prompt := prompts[0] as ConfirmPromptModal
		_expect(prompt.message == "A great danger is detected here. Are you sure you would like to proceed?", "CS-1 danger question differs from requested contract")
		var focus := root.gui_get_focus_owner() as Button
		_expect(focus != null and focus.text.begins_with("No"), "CS-2 danger popup defaults to unsafe Yes choice")
		_expect(not maze.can_capture_campaign_snapshot(), "CS-3 prompt allows unsafe checkpoint capture")
		var before := diver.global_position
		await _press(KEY_W, true)
		await _key(KEY_TAB)
		await _key(KEY_P)
		for frame in 12:
			await physics_frame
		await _press(KEY_W, false)
		_expect(maze.active == index and diver.global_position.distance_to(before) < 0.01, "CS-2 prompt leaks movement/diver switching")
		if index == 0:
			await _capture("confirmation")
			for node in prompt.find_children("*", "Control", true, false):
				if node is Button or node is Label:
					_expect(root.get_visible_rect().encloses((node as Control).get_global_rect()), "CS-5 danger popup clips controls")
		await _key(KEY_ESCAPE if index == 1 else KEY_N)
		await create_timer(2.2).timeout
		_expect(not maze._battling and not maze.any_modal_open(), "CS-2 decline starts fight or immediately reopens prompt")
		_expect(diver.global_position.distance_to(before) < 0.05, "CS-2 decline unexpectedly teleports player")
	# A saved undefeated boss still stations one actor and asks before combat.
	maze.queue_free()
	await process_frame
	maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	_expect(maze.snapshot_matches_runtime(snapshot), "CS-4 old compatible snapshot refused")
	maze.restore_campaign_snapshot(snapshot)
	await process_frame
	_expect(maze.find_children("*", "PrologueOctopus", true, false).size() == 1 and not maze._battling, "CS-4 undefeated restore lost station or starts fight")
	var restored_station := maze._boss_triggers.get("main_boss") as Node3D
	maze.set_maze_active(false)
	maze._diver.global_position = restored_station.global_position + Vector3(-4, 1.2, 0)
	for frame in 8:
		await physics_frame
	_expect(not maze.any_modal_open() and not maze._battling, "CS-3 inactive maze initiates boss prompt")
	maze.set_maze_active(true)
	for frame in 8:
		await physics_frame
	_expect(maze.any_modal_open() and not maze._battling, "CS-3 resumed maze fails to ask at eligible approach")
	await _finish()

func _look(yaw: float) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-angle_difference(maze._yaw, yaw) / 0.004, 0)
	Input.parse_input_event(motion)
	await process_frame
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(click)
	await process_frame

func _press(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func _key(key: Key) -> void:
	await _press(key, true)
	await _press(key, false)

func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/cordys-%s-%dx%d.png" % [label, root.size.x, root.size.y]
	_expect(root.get_texture().get_image().save_png(path) == OK, "CS-5 capture failed")
	print("CAPTURE ", path)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	if is_instance_valid(maze):
		maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE CORDYS STATION: clean" if findings.is_empty() else "MAZE CORDYS STATION: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
