# OPEN-026/035: idle/camera time cannot start the Angler or consume the four
# seconds of actual keyboard swimming before it.
# the opening Angler. No teleport, scripted direction, or private trigger call.
# Only video playback is fast-forwarded; browser movie handoff is a separate gate.
extends SceneTree

const TEST_SLOT := 918302
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(TEST_SLOT)
	await process_frame
	var diver := world.divers[world.active] as Diver
	var origin := diver.global_position
	_expect(not paused, "OPEN-026 quiet spawn keeps World paused")
	await create_timer(15.0).timeout
	_expect(not world.battling and world.route_state.prologue_phase == "spawn_exploration", "OPEN-035 Angler starts without swimming after 15 seconds idle")
	if not world.battling:
		_key(KEY_RIGHT, true)
		await create_timer(0.8).timeout
		_key(KEY_RIGHT, false)
		_key(KEY_LEFT, true)
		await create_timer(0.8).timeout
		_key(KEY_LEFT, false)
		_expect(not world.battling, "OPEN-035 camera-only input starts the Angler")
		_expect(origin.distance_to(diver.global_position) < 0.1, "OPEN-035 no-swim fixture displaced the diver")
		var started := Time.get_ticks_msec()
		_key(KEY_W, true)
		var maximum_displacement := 0.0
		while world.route_state.prologue_phase == "spawn_exploration" and Time.get_ticks_msec() - started < 10000:
			await physics_frame
			maximum_displacement = maxf(maximum_displacement, origin.distance_to(diver.global_position))
		_key(KEY_W, false)
		var elapsed := (Time.get_ticks_msec() - started) / 1000.0
		print("FREE_SWIM|prior_idle_seconds=15|swimming_seconds=%.3f|distance_m=%.3f|phase=%s" % [elapsed, maximum_displacement, world.route_state.prologue_phase])
		_expect(maximum_displacement >= 3.0, "OPEN-026 real W input cannot swim three metres")
		_expect(elapsed >= 4.0, "OPEN-035 prior idle time consumed the four-second swimming window")
		_expect(elapsed < 8.5 and world.route_state.prologue_phase == "angler", "OPEN-026 opening does not progress after usable swimming")
		_expect(world.route_state.encounter_source == "prologue_angler", "OPEN-035 swim started an ordinary/random encounter")
	world.queue_free()
	await process_frame
	paused = false
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	_remove_test_save()
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING FREE SWIM: clean" if findings.is_empty() else "OPENING FREE SWIM: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _remove_test_save() -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
