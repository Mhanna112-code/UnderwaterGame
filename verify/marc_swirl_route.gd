extends SceneTree
## SWIRL-2/3: physical swimming and moving, genuinely damaging rock hazards.
var findings: Array[String] = []
var capture_dir := ""
var maze: MazeLevel
var hit_counts: Dictionary = {}

func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	seed(970435)
	maze = (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in 12:
		await physics_frame
	maze.random_encounters_enabled = false
	maze.room_encounters_enabled = false
	# Vision is part of Q now; no separate item/equipment grant in this route.
	var room := maze.get_node("SphereRoom") as SwirlRoom
	room.diver_hit.connect(func(diver: Diver) -> void:
		hit_counts[diver.model_name] = int(hit_counts.get(diver.model_name, 0)) + 1)
	var before := room.positions()
	for frame in 30:
		await physics_frame
	var after := room.positions()
	_expect(before.size() == after.size() and not before.is_empty(), "SWIRL-3 hazards vanished over time")
	if not before.is_empty():
		_expect(before[0].distance_to(after[0]) > 0.25, "SWIRL-3 hazards do not actually orbit")
	print("SWIRL ACTUAL ROOM|rocks=", after.size(), "|bounds=", room.room_min, "..", room.room_max)
	for index in maze.divers.size():
		for other in maze.divers:
			other.global_position = Vector3(2000, 0, 2000)
		maze.active = index
		maze._diver = maze.divers[index]
		var diver := maze._diver
		diver.sonar_active = diver.passive_id == "sonar"
		var wall := maze.get_node("CSGBox3D16") as Node3D
		var toward := room.center - wall.global_position
		toward.y = 0
		toward = toward.normalized()
		var start := room.center - toward * (minf(room.room_max.x-room.room_min.x, room.room_max.z-room.room_min.z) * 0.5 - 1.6)
		start.y = (maze.get_node("DiverEntry") as Node3D).global_position.y
		diver.global_position = start
		diver.velocity = Vector3.ZERO
		# The accessible eye includes the chest approach, not its physical centre.
		var goal := Vector3(room.center.x, start.y, room.center.z) - toward * 1.8
		var hp_before := diver.stats.hp
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = Vector2(900, 400)
		click.pressed = true
		Input.parse_input_event(click)
		await process_frame
		click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		Input.parse_input_event(click)
		var press := InputEventKey.new()
		press.keycode = KEY_W
		press.pressed = true
		Input.parse_input_event(press)
		var arrived := false
		var captured := false
		var deadline := Time.get_ticks_msec() + 20000
		var ticks := 0
		while Time.get_ticks_msec() < deadline:
			var delta := goal - diver.global_position
			delta.y = 0
			if delta.length() < 0.75:
				arrived = true
				break
			var desired := atan2(delta.x, delta.z)
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(-angle_difference(maze._yaw, desired) / 0.004, 0)
			Input.parse_input_event(motion)
			await physics_frame
			ticks += 1
			if ticks % 60 == 0:
				print("SWIRL INPUT TRACE|", diver.model_name, "|ticks=", ticks,
					"|W=", Input.is_key_pressed(KEY_W), "|yaw=", maze._yaw,
					"|look=", maze._mouse_look, "|modal=", maze.any_modal_open(),
					"|position=", diver.global_position)
			_expect(room.contains(diver.global_position), "SWIRL-2 knockback/movement leaves room walls")
			if not captured and delta.length() < 7.0 and index == 0:
				captured = true
				await _capture("approach")
		var release := InputEventKey.new()
		release.keycode = KEY_W
		Input.parse_input_event(release)
		await physics_frame
		_expect(arrived, "SWIRL-2 real W/mouse cannot reach eye for " + diver.model_name + " at " + str(diver.global_position))
		_expect(diver.stats.hp >= 1 and diver.stats.hp <= hp_before, "SWIRL-3 hazard violates nonlethal HP contract")
		print("SWIRL PHYSICAL SWIM|", diver.model_name, "|arrived=", arrived, "|HP=", hp_before, "->", diver.stats.hp, "|hits=", hit_counts.get(diver.model_name, 0), "|position=", diver.global_position)
		if index == 0:
			await _capture("eye")
	# Independent real-contact case: HP and the public hit signal must agree.
	# Physical chest collision is tested separately from moving hazard contacts.
	maze.set_physics_process(false)
	var chest := maze.get_node("VortexChest") as Node3D
	var actor := maze._diver
	actor.global_position = Vector3(chest.global_position.x, 0, chest.global_position.z - 3)
	actor.velocity = Vector3.ZERO
	await physics_frame
	var nearest := INF
	for step in 20:
		actor.move_and_collide(Vector3(0, 0, 0.2))
		nearest = minf(nearest, Vector2(actor.global_position.x-chest.global_position.x, actor.global_position.z-chest.global_position.z).length())
	_expect(nearest >= 0.85, "SWIRL-5 actual capsule passes inside vortex chest: " + str(nearest))
	actor.global_position = Vector3(chest.global_position.x, 0, chest.global_position.z - 1.8)
	actor.velocity = Vector3.ZERO
	maze.set_physics_process(true)
	await physics_frame
	var prompt := maze._switch_prompt
	_expect(prompt != null and prompt.visible and prompt.text == "Press E to open", "SWIRL-5 chest caption does not explain opening")
	var open := InputEventKey.new()
	open.keycode = KEY_E
	open.pressed = true
	Input.parse_input_event(open)
	open = InputEventKey.new()
	open.keycode = KEY_E
	Input.parse_input_event(open)
	await create_timer(2.4).timeout
	_expect(maze.key_items.count("vortex_key") == 1, "SWIRL-5 real E/Tween did not award one Vortex Key")
	# End any information modal before the final contact fixture; do not pause
	# the hazard while pretending that the lack of damage is a pass.
	var popup := root.get_node_or_null("CharacterAbilityPopup")
	if popup != null and (popup.get_node("%AbilityExplanationPanel") as Control).visible:
		var dismiss := InputEventKey.new()
		dismiss.keycode = KEY_ESCAPE
		dismiss.pressed = true
		Input.parse_input_event(dismiss)
		await process_frame
		dismiss = InputEventKey.new()
		dismiss.keycode = KEY_ESCAPE
		Input.parse_input_event(dismiss)
	var contact := maze._diver
	var hp := contact.stats.hp
	var hits := int(hit_counts.get(contact.model_name, 0))
	contact.global_position = room.positions()[0]
	contact.velocity = Vector3.ZERO
	for frame in 3:
		await physics_frame
	_expect(int(hit_counts.get(contact.model_name, 0)) > hits and contact.stats.hp == maxi(1, hp - 2),
		"SWIRL-3 real capsule contact has no authored damage/hit signal")
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC SWIRL ROUTE: clean" if findings.is_empty() else "MARC SWIRL ROUTE: failed")
	quit(0 if findings.is_empty() else 1)

func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	# physics_frame resumes before that frame's HUD/camera update. Capture the
	# settled approach, not stale interaction copy from the previous position.
	await physics_frame
	await physics_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_dir.path_join("swirl-"+label+".png")) == OK,
		"SWIRL-3 native capture failed")

func _expect(ok: bool, message: String) -> void:
	if not ok and not findings.has(message):
		findings.append(message)
