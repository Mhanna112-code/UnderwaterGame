# TITLE-001/003/004/005: real decoder handoff, not finish_for_test.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# The headless dummy display does not inherit the desktop window dimensions.
	# Rendered acceptance still runs separately at both real resolutions.
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 720)
	var script := load("res://game/opening_video.gd") as Script
	var owner := script.new() as CanvasLayer
	if not _has_property(owner, "show_opening_title"):
		findings.append("TITLE-001 first-run owner has no authored title handoff")
		owner.free()
		_finish()
		return
	_expect(not owner.get("show_opening_title"), "TITLE-004 inherited cinematic unexpectedly opts into opening title")
	owner.set("show_opening_title", true)
	var events: Array[String] = []
	owner.connect("handoff_started", func() -> void: events.append("handoff"))
	owner.completed.connect(func(ok: bool) -> void: events.append("complete" if ok else "failure"))
	root.add_child(owner)
	await process_frame
	var deadline := Time.get_ticks_msec() + 45000
	while events.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(events == ["handoff"], "TITLE-001 actual movie EOF did not enter title before completion: %s" % [events])
	if events == ["handoff"]:
		_expect(paused, "TITLE-002 title unpaused gameplay")
		owner.call("_on_video_finished")
		owner.call("_on_video_finished")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		Input.parse_input_event(escape)
		await create_timer(1.2).timeout
		_expect(events == ["handoff"], "TITLE-002/003 input or repeated EOF bypassed title hold")
		var card := owner.get_node_or_null("InputBlocker/OpeningTitle") as Control
		_expect(card != null and card.is_visible_in_tree(), "TITLE-001 title is not rendered")
		if card != null:
			var visible_copy := ""
			for child in card.find_children("*", "Label", true, false):
				var label := child as Label
				if label.is_visible_in_tree():
					visible_copy += label.text + "\n"
				var rect := label.get_global_rect()
				_expect(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(rect), "TITLE-005 label outside viewport: " + label.text)
				if label.text == "UNDERWATER":
					_expect(label.get_line_count() == 1, "TITLE-005 title splits mid-word on narrow screens")
			for contributor in ["ImmortalDemonGod", "Mhanna", "Glass_Goat", "Phoenix Down Music"]:
				_expect(visible_copy.contains(contributor), "TITLE-008 opening credit missing: " + contributor)
		if OS.get_cmdline_user_args().has("--capture") and card != null:
			# macOS suspends drawing for occluded verification windows. Force a
			# real draw rather than accept a stale gray texture or wait forever.
			DisplayServer.window_move_to_foreground()
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/opening-title-%dx%d.png" % [int(root.size.x), int(root.size.y)])
		var started := Time.get_ticks_msec()
		while is_instance_valid(owner) and Time.get_ticks_msec() - started < 6000:
			await process_frame
		_expect(events == ["handoff", "complete"], "TITLE-003 title did not complete exactly once: %s" % [events])
		_expect(not is_instance_valid(owner), "TITLE-003 title owner survives completion")
	paused = false
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	await process_frame
	_finish()

func _has_property(owner: Object, name: String) -> bool:
	for property in owner.get_property_list():
		if property.name == name:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING TITLE HANDOFF: clean" if findings.is_empty() else "OPENING TITLE HANDOFF: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
