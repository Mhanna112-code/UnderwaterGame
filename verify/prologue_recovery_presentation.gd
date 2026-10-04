extends SceneTree
## REC-002/003: real responsive copy/action and input through decoration.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var recovery := PrologueRecovery.new()
	root.add_child(recovery)
	var presses: Array[bool] = []
	recovery.continued.connect(func() -> void: presses.append(true))
	for state in ["saving", "retry", "ready"]:
		match state:
			"saving": recovery.show_saving()
			"retry": recovery.show_save_failure()
			"ready": recovery.clear_save_failure()
		for _frame in range(8):
			await process_frame
		var viewport := root.get_visible_rect()
		var texts: Array[String] = []
		for node in recovery.find_children("*", "Control", true, false):
			var control := node as Control
			if not control.is_visible_in_tree():
				continue
			if control is Label or control is Button:
				if not viewport.encloses(control.get_global_rect()):
					findings.append("REC-002 clipped " + control.name + " at " + str(viewport.size))
			if control is Label:
				texts.append((control as Label).text)
		if not texts.has("Grow stronger.") or not texts.has("Find a way to defeat Cordys."):
			findings.append("REC-002 motivation lost or rewritten")
		var button := recovery._continue_button
		if not button.has_focus():
			findings.append("REC-003 action lost keyboard focus in " + state)
		var before := presses.size()
		await _click(button.get_global_rect().get_center())
		if presses.size() != before + (0 if state == "saving" else 1):
			findings.append("REC-003 decoration blocks click or disabled Saving accepts click: " + state)
		print("RECOVERY UI|%s|viewport=%s|button=%s|clicks=%d" % [state, viewport.size, button.get_global_rect(), presses.size() - before])
		var before_key := presses.size()
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER
			key.pressed = pressed
			Input.parse_input_event(key)
			await process_frame
		if presses.size() != before_key + (0 if state == "saving" else 1):
			findings.append("REC-003 keyboard focus/disabled action is broken: " + state)
	recovery.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	quit(0 if findings.is_empty() else 1)

func _click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
