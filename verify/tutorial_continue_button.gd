# `tutorial continue button: clicking the visible action advances the caption
# — guards against keyboard-only tutorial stalls`.
extends SceneTree

const TIMEOUT_MS := 9000
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := await _open_live_wait()
	if world.battle == null:
		findings.append("CONTINUE BUTTON START: tutorial Battle was never created")
	elif not world.battle._tutorial_awaiting_enter:
		findings.append("CONTINUE BUTTON START: tutorial never displayed a narration wait state")
	else:
		var button := world.battle.find_child("TutorialContinue", true, false) as Button
		if button == null:
			findings.append("KEYBOARD-ONLY TUTORIAL STALL: caption has no clickable Continue action")
		elif not button.visible or button.disabled:
			findings.append("CONTINUE BUTTON: action exists but is not usable while caption waits")
		else:
			# Verify the keyboard alias against this first *real* tutorial pause.
			var space := InputEventKey.new()
			space.keycode = KEY_SPACE
			space.pressed = true
			world.battle._unhandled_input(space)
			if world.battle._tutorial_awaiting_enter:
				findings.append("SPACE CONTINUE: Space did not advance the live tutorial caption")
	world.queue_free()
	await process_frame

	# A fresh live run leaves the click proof independent from the Space proof:
	# neither interaction gets credit for advancing a later scripted phase.
	world = await _open_live_wait()
	if world.battle == null:
		findings.append("CONTINUE BUTTON CLICK: tutorial Battle was never created")
	elif not world.battle._tutorial_awaiting_enter:
		findings.append("CONTINUE BUTTON CLICK: tutorial never displayed a narration wait state")
	else:
		var click_button := world.battle.find_child("TutorialContinue", true, false) as Button
		if click_button == null or not click_button.visible or click_button.disabled:
			findings.append("CONTINUE BUTTON CLICK: visible action is unavailable while caption waits")
		else:
			click_button.emit_signal("pressed")
			if world.battle._tutorial_awaiting_enter:
				findings.append("CONTINUE BUTTON: click did not advance the live tutorial caption")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial continue button   mouse click advanced the live caption wait state")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _open_live_wait() -> World:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world._start_battle("", false, "angler", world.divers, false, true)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while (world.battle == null or not world.battle._tutorial_awaiting_enter) and Time.get_ticks_msec() < deadline:
		await process_frame
	return world
