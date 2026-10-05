extends SceneTree
## M99-P1/2/3: public Escape and four real tabs stay usable across viewports.

var findings: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await _settle()
	# Real save-free consumer kit; do not fake known-spell arrays or touch slots.
	world._on_title_spell_playtest()
	world._first_encounter_done = true
	await _settle()
	var menu := world.inventory_menu
	var viewport_shapes: Array[Vector2i] = [Vector2i(360, 640), Vector2i(720, 480),
		Vector2i(720, 900), Vector2i(1280, 720)]
	# Generated widths/heights, not just author-picked screenshots.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99004
	for _index in range(8):
		viewport_shapes.append(Vector2i(rng.randi_range(360, 1440), rng.randi_range(480, 1000)))
	for shape in viewport_shapes:
		root.size = shape
		await _settle()
		await _escape()
		_expect(menu.visible, "M99-P3 Escape did not open the real menu")
		for sibling in menu.get_parent().get_children():
			if sibling is Control and sibling != menu and sibling.is_visible_in_tree():
				_expect(menu.get_index() > sibling.get_index(),
					"M99-P4 exploration HUD paints above pause-menu controls")
		var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_expect(_covers(menu.get_global_rect(), bounds), "M99-P3 overlay does not cover " + str(shape))
		var before: Vector3 = world.divers[world.active].global_position
		var move := InputEventKey.new()
		move.keycode = KEY_W
		move.physical_keycode = KEY_W
		move.pressed = true
		Input.parse_input_event(move)
		for _frame in range(5):
			await physics_frame
		move = InputEventKey.new()
		move.keycode = KEY_W
		move.physical_keycode = KEY_W
		Input.parse_input_event(move)
		_expect(world.divers[world.active].global_position.distance_to(before) < 0.01,
			"M99-P3 exploration moved behind the menu at " + str(shape))
		for tab_name in ["Items", "Party Spells", "Combat Help", "Audio"]:
			var tab := _button(menu, tab_name)
			_expect(tab != null and tab.is_visible_in_tree(), "M99-P2 missing tab " + tab_name)
			if tab == null:
				continue
			tab.pressed.emit()
			await _settle()
			for other_name in ["Items", "Party Spells", "Combat Help", "Audio"]:
				var other := _button(menu, other_name)
				_expect(other != null and _inside(other.get_global_rect(), bounds),
					"M99-P1 inaccessible %s tab at %s" % [other_name, shape])
			var scroll := menu.find_child("ContentScroll", true, false) as ScrollContainer
			_expect(scroll != null and _inside(scroll.get_global_rect(), bounds)
				and scroll.size.y >= 100, "M99-P1 reading window clipped/collapsed at " + str(shape))
			if tab_name == "Party Spells":
				_expect(_button_containing(menu, "Mending Current") != null,
					"M99-P2 learned spells lost during pause-menu port")
			if tab_name == "Combat Help":
				for action in ["Replay Tutorial Fight", "Replay Special Encounter Tutorial"]:
					_expect(_button(menu, action) != null, "M99-P2 lost existing Help action " + action)
				_expect(_button(menu, "Reopen Tutorial Guide") == null,
					"M99-P5 superseded guide button still appears after Marc's removal")
			if tab_name == "Audio":
				for slider_name in ["MusicVolumeSlider", "SFXVolumeSlider"]:
					var slider := menu.find_child(slider_name, true, false) as HSlider
					_expect(slider != null and slider.is_visible_in_tree()
						and _inside(slider.get_global_rect(), bounds),
						"M99-P1/2 inaccessible audio level at " + str(shape))
			# Content must not overflow horizontally even when scrolling vertically.
			for child in menu.find_children("*", "Button", true, false):
				if child.is_visible_in_tree():
					var rect: Rect2 = child.get_global_rect()
					_expect(rect.position.x >= -1 and rect.end.x <= bounds.end.x + 1,
						"M99-P1 content wider than viewport: %s at %s" % [child.text, shape])
			if not capture_dir.is_empty() and shape in [Vector2i(360, 640), Vector2i(720, 480), Vector2i(720, 900), Vector2i(1280, 720)]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(capture_dir.path_join("pause-%dx%d-%s.png" % [shape.x, shape.y, tab_name.replace(" ", "-")]))
		await _escape()
		_expect(not menu.visible, "M99-P3 Escape did not return to exploration")
	var guide_key := InputEventKey.new()
	guide_key.keycode = KEY_F1
	guide_key.pressed = true
	Input.parse_input_event(guide_key)
	await _settle()
	_expect(world.tutorial_book.visible, "M99-P5 removing the guide button also disabled F1")
	world.tutorial_book._close_btn.pressed.emit()
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC PAUSE PRESENTATION: clean" if findings.is_empty() else "MARC PAUSE PRESENTATION: failed")
	quit(0 if findings.is_empty() else 1)

func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await _settle()
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	Input.parse_input_event(event)
	await _settle()

func _settle() -> void:
	for _frame in range(6):
		await process_frame

func _inside(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x - 1 and rect.position.y >= bounds.position.y - 1 \
		and rect.end.x <= bounds.end.x + 1 and rect.end.y <= bounds.end.y + 1

func _covers(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.distance_to(bounds.position) < 1 and rect.end.distance_to(bounds.end) < 1

func _button(node: Node, label: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child.text == label:
			return child
	return null

func _button_containing(node: Node, text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if text in child.text:
			return child
	return null

func _expect(ok: bool, message: String) -> void:
	if not ok and not findings.has(message):
		findings.append(message)
