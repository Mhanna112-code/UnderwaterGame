# Captures Marc's reported camera regression: after the post-tutorial modal
# closes, a normal mouse press and mouse motion must immediately reach the
# free-world camera. Usage:
#   godot --headless --path . --script verify/tutorial_camera_handoff.gd
extends SceneTree

var findings: Array[String] = []
var battle_result := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	battle_result = ""
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	# Enter by the public title-screen signal, rather than clearing paused by
	# hand. This makes the test exercise the same world state a player reaches.
	world.title_screen.new_game_chosen.emit(1)
	await process_frame
	await process_frame
	# Reach the popup through the production tutorial-end path. The visible Skip
	# Tutorial control is used only to keep this regression fast; its completion
	# uses World._on_battle_finished() and the exact same post-battle modal as a
	# won tutorial.
	world._start_battle("", false, "angler", world.divers, false, true)
	await process_frame
	await process_frame
	var battle: Battle = world.battle
	if battle == null:
		findings.append("MODAL CAMERA HANDOFF: tutorial battle did not start")
		_finish(world)
		return
	battle.finished.connect(func(result): battle_result = String(result))
	var deadline := Time.get_ticks_msec() + 15000
	while battle_result == "" and Time.get_ticks_msec() < deadline:
		if world.battle != null and world.battle._tutorial_awaiting_enter:
			world.battle._tutorial_awaiting_enter = false
		if world.battle != null and not world.battle._busy \
				and world.battle.skip_tutorial_btn != null and not world.battle.skip_tutorial_btn.disabled:
			world.battle.skip_tutorial_btn.emit_signal("pressed")
		await process_frame
	if battle_result != "skipped":
		findings.append("MODAL CAMERA HANDOFF: tutorial did not reach the normal post-battle modal path")
		_finish(world)
		return
	await process_frame
	await process_frame

	var popup := root.get_node_or_null("CharacterAbilityPopup") as Control
	if popup == null:
		findings.append("MODAL CAMERA HANDOFF: CharacterAbilityPopup autoload is missing")
		_finish(world)
		return
	var panel := popup.get_node_or_null("UI/AbilityExplanationPanel") as Control
	if panel == null:
		findings.append("MODAL CAMERA HANDOFF: ability panel is missing")
		_finish(world)
		return
	_expect(paused and panel.visible,
		"MODAL CAMERA HANDOFF: the real modal did not visibly pause the world")

	# Regression guard for a modal that lets the world rotate while it is open.
	var yaw_while_open := world.yaw
	_dispatch_mouse_motion(Vector2(150.0, 0.0))
	await process_frame
	_expect(is_equal_approx(world.yaw, yaw_while_open),
		"MODAL CAMERA HANDOFF: mouse motion leaked through the open tutorial modal")

	# Emit the rendered next/terminal-Close button until the real multi-page
	# walkthrough is done. This catches a regression where an intermediate page
	# advances but the final page never performs the close handoff.
	var close_button := popup.get_node_or_null("UI/AbilityExplanationPanel/Margin/VBoxContainer/PopupClose") as Button
	if close_button == null:
		findings.append("MODAL CAMERA HANDOFF: the visible terminal Close button is missing")
		_finish(world)
		return
	var close_deadline := Time.get_ticks_msec() + 5000
	while panel.visible and Time.get_ticks_msec() < close_deadline:
		close_button.emit_signal("pressed")
		await process_frame
	await process_frame
	_expect(not paused and not panel.visible,
		"MODAL CAMERA HANDOFF: closing the tutorial modal did not return to an active world")

	# A player should not need arrow keys or an additional UI transition. This
	# is the actual World input route, not a direct write to `world.yaw` or
	# `world.mouse_look`.
	world.mouse_look = false
	var yaw_before := world.yaw
	var diver := world.divers[world.active] as Diver
	var camera_before := (world.cam as Camera3D).global_position - diver.global_position
	_dispatch_mouse_press()
	_dispatch_mouse_motion(Vector2(-150.0, 0.0))
	# World moves its chase camera in _physics_process() with intentional
	# smoothing. Wait for physical time, not a handful of idle frames.
	for _frame in range(24):
		await physics_frame
	_expect(world.mouse_look,
		"MODAL CAMERA HANDOFF: first post-modal mouse press did not enable look")
	_expect(absf(world.yaw - yaw_before) > 0.4,
		"MODAL CAMERA HANDOFF: post-modal mouse motion did not rotate the world camera")
	var camera_after := (world.cam as Camera3D).global_position - diver.global_position
	var orbit_change := Vector2(camera_after.x - camera_before.x, camera_after.z - camera_before.z).length()
	_expect(orbit_change > 1.0,
		"MODAL CAMERA HANDOFF: mouse yaw changed but the visible chase camera did not orbit")
	_finish(world)

func _dispatch_mouse_press() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)

func _dispatch_mouse_motion(relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	Input.parse_input_event(motion)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish(world: World) -> void:
	for finding in findings:
		push_error(finding)
	print("TUTORIAL CAMERA HANDOFF: clean" if findings.is_empty() else "TUTORIAL CAMERA HANDOFF: %d failure(s)" % findings.size())
	if is_instance_valid(world):
		world.queue_free()
	quit(0 if findings.is_empty() else 1)
