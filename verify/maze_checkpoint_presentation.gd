# INT-08: real checkpoint/menu rendering and mouse input, without writing
# any user save. Run non-headless with the Compatibility renderer.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		findings.append("INT-08 checkpoint presentation requires a real display")
		await _finish()
		return
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
	world.divers[0].global_position = world.deep_zone_layout.route_points().maze_transition
	for frame in range(16):
		await physics_frame
		if current_scene is MazeLevel:
			break
	if not current_scene is MazeLevel:
		findings.append("INT-08 checkpoint setup: real entrance did not reach maze")
		await _finish()
		return
	var maze := current_scene as MazeLevel
	await create_timer(1.2).timeout
	await _capture("entry")
	var point := maze.get_node("MazeCheckpoint") as SavePoint
	maze.divers[0].global_position = point.global_position + Vector3.UP
	for frame in range(8):
		await physics_frame
	await _capture("contact")
	var announcements := 0
	for label in _visible_labels(maze):
		if label.text.contains("Party restored"):
			announcements += 1
			if not Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(label.get_global_rect()):
				findings.append("INT-08 checkpoint contact announcement is clipped")
		if label.text.begins_with("Hallway:") or label.text.begins_with("Open the hallway."):
			findings.append("INT-08 checkpoint announcement overlaps normal gameplay captions")
	if announcements != 1:
		findings.append("INT-08 checkpoint contact has no single visible recovery announcement")
	var key := InputEventKey.new()
	key.keycode = KEY_P
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key = InputEventKey.new()
	key.keycode = KEY_P
	Input.parse_input_event(key)
	await process_frame
	await RenderingServer.frame_post_draw
	var save := _button(maze, "Save")
	if save == null:
		findings.append("INT-08 checkpoint P does not reveal a visible Save button")
		await _finish()
		return
	await _click(save.get_global_rect().get_center())
	await RenderingServer.frame_post_draw
	var slot := _button(maze, "Slot 1 -", true)
	if slot == null:
		findings.append("INT-08 actual Save mouse click does not reveal the slot picker")
	for label in _visible_labels(maze):
		if label.text.contains("Party restored"):
			findings.append("INT-08 gameplay announcement leaks over the active Save menu")
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for button in _visible_buttons(maze):
		if not viewport.encloses(button.get_global_rect()):
			findings.append("INT-08 checkpoint button clipped: " + button.text)
	await _capture("slots")
	await _finish()

func _capture(phase: String) -> void:
	await RenderingServer.frame_post_draw
	var size := root.get_visible_rect().size
	var path := "/tmp/underwater-maze-checkpoint-%dx%d-%s.png" % [int(size.x), int(size.y), phase]
	root.get_texture().get_image().save_png(path)
	print("CHECKPOINT CAPTURE|", path)

func _button(node: Node, text: String, prefix := false) -> Button:
	if node is Button and (node as Button).is_visible_in_tree():
		var button := node as Button
		if button.text.begins_with(text) if prefix else button.text == text:
			return button
	for child in node.get_children():
		var button := _button(child, text, prefix)
		if button != null:
			return button
	return null

func _visible_buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if node is Button and (node as Button).is_visible_in_tree():
		out.append(node as Button)
	for child in node.get_children():
		out.append_array(_visible_buttons(child))
	return out

func _visible_labels(node: Node) -> Array[Label]:
	var out: Array[Label] = []
	if node is Label and (node as Label).is_visible_in_tree():
		out.append(node as Label)
	for child in node.get_children():
		out.append_array(_visible_labels(child))
	return out

func _click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _finish() -> void:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE CHECKPOINT PRESENTATION: clean controls" if findings.is_empty() else "MAZE CHECKPOINT PRESENTATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
