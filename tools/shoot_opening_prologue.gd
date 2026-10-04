# Ordinary title/New Game, actual movie completion and real gameplay inputs.
# Usage: godot --path . --resolution 1280x720 --script tools/shoot_opening_prologue.gd -- /tmp/opening-wide
extends SceneTree

var slot := 918301
var outdir := "/tmp/opening-wide"
var world: World
var started_ms := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		outdir = args[0]
	if args.size() > 1:
		slot = int(args[1])
	DirAccess.make_dir_recursive_absolute(outdir)
	call_deferred("_run")

func _run() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await _settle()
	_capture("01-title.png")
	started_ms = Time.get_ticks_msec()
	world.route_state.phase_changed.connect(func(phase: String) -> void:
		print("TIMING|%s|%.3f" % [phase, (Time.get_ticks_msec() - started_ms) / 1000.0]))
	world.title_screen.new_game_chosen.emit(slot)
	await create_timer(8.0).timeout
	_capture("02-video.png")
	await _wait_phase("spawn_exploration", 40.0)
	await _settle()
	_capture("03-quiet-spawn.png")
	# Press physical W, not a teleport/private trigger shortcut.
	var forward := InputEventKey.new()
	forward.physical_keycode = KEY_W
	forward.keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	await _wait_phase("angler", 10.0)
	forward.pressed = false
	Input.parse_input_event(forward)
	await _settle()
	_capture("04-angler.png")
	await _attack("05-angler-move.png", "06-angler-target.png")
	await _wait_phase("octopus_introduction", 10.0)
	await create_timer(8.0).timeout
	_capture("06b-cordys-introduction.png")
	await _wait_phase("octopus_reveal", 25.0)
	await create_timer(1.1).timeout
	_capture("07-cordys-reveal.png")
	await _wait_phase("octopus_response", 12.0)
	await _settle()
	_capture("08-cordys-response.png")
	await _attack("09-cordys-move.png", "10-cordys-target.png")
	await _wait_phase("scripted_defeat", 15.0)
	await create_timer(0.6).timeout
	_capture("11-finisher.png")
	await _wait_phase("octopus_aftermath", 15.0)
	await create_timer(5.0).timeout
	_capture("11b-cordys-aftermath.png")
	await _wait_phase("recovery", 40.0)
	await _settle()
	_capture("12-recovery.png")
	var button := _button(world, "Continue")
	if button == null:
		push_error("Recovery Continue missing")
		await _finish(1)
		return
	button.emit_signal("pressed")
	await _settle()
	_capture("13-optional-training.png")
	var elapsed := (Time.get_ticks_msec() - started_ms) / 1000.0
	print("Normal entry to recovered control: %.2f seconds" % elapsed)
	await _finish(0 if elapsed < 120.0 else 1)

func _attack(move_shot: String, target_shot: String) -> void:
	world.battle.attack_btn.emit_signal("pressed")
	await _settle()
	_capture(move_shot)
	(world.battle.move_buttons[0] as Button).emit_signal("pressed")
	await _settle()
	_capture(target_shot)
	(world.battle.target_buttons[0] as Button).emit_signal("pressed")

func _wait_phase(phase: String, limit: float) -> void:
	var elapsed := 0.0
	while world.route_state.prologue_phase != phase and elapsed < limit:
		await create_timer(0.05).timeout
		elapsed += 0.05
	if elapsed >= limit:
		push_error("Opening phase timed out: %s, got %s" % [phase, world.route_state.prologue_phase])
		await _finish(1)

func _button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == caption and child.is_visible_in_tree():
			return child as Button
		var result := _button(child, caption)
		if result != null:
			return result
	return null

func _settle() -> void:
	for _i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

func _capture(filename: String) -> void:
	var filename_absolute := outdir.path_join(filename)
	root.get_texture().get_image().save_png(filename_absolute)
	print("shot       " + filename_absolute)

func _finish(code: int) -> void:
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(slot)))
	await create_timer(0.2).timeout
	quit(code)
