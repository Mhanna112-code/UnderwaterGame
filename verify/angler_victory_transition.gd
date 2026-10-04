# VICT-001: real Angler kill must give a readable victory before any movie.
extends SceneTree
const SLOT := 918323
var findings: Array[String] = []
var _recording := false
var _frames_finished := true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 720)
	if SaveManager.slot_exists(SLOT):
		print("FINDING owned test slot exists; refusing overwrite")
		quit(1)
		return
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var checkpoint := world._serialize_state() # fixture skips initial Mermaid only
	checkpoint.route_state = {"opening_video_seen": true, "prologue_complete": false, "tutorial_complete": false}
	SaveManager.write_slot(SLOT, checkpoint)
	world.title_screen.load_game_chosen.emit(SLOT)
	await process_frame
	await process_frame
	var audio := root.get_node("GameAudio")
	var settings: Dictionary = audio.get_audio_settings()
	var phases: Array[String] = []
	world.route_state.phase_changed.connect(func(phase: String) -> void:
		phases.append(phase)
		if phase == "angler_victory" and OS.get_cmdline_user_args().has("--capture"):
			_recording = true
			_frames_finished = false
			_record_frames()
	)
	var swim := InputEventKey.new()
	swim.keycode = KEY_W
	swim.physical_keycode = KEY_W
	swim.pressed = true
	Input.parse_input_event(swim)
	await _wait_phase(world, "angler", 12.0)
	_expect(world.route_state.prologue_phase == "angler", "VICT-001 setup did not enter combat through actual W swimming; phase=%s, position=%s" % [world.route_state.prologue_phase, world.divers[world.active].position])
	swim.pressed = false
	Input.parse_input_event(swim)
	var fight := world.battle
	var elapsed := 0.0
	while fight != null and world.route_state.prologue_phase == "angler" and elapsed < 35.0:
		if fight.attack_btn.is_visible_in_tree() and not fight.attack_btn.disabled:
			fight.attack_btn.pressed.emit()
			await process_frame
			if not fight.move_buttons.is_empty():
				(fight.move_buttons[0] as Button).pressed.emit()
				await process_frame
				if not fight.target_buttons.is_empty():
					(fight.target_buttons[0] as Button).pressed.emit()
		await create_timer(0.05).timeout
		elapsed += 0.05
	_expect(world.route_state.prologue_phase == "angler_victory", "VICT-001 real kill jumps straight to movie instead of readable victory")
	_expect(_visible_text(world, "victory"), "VICT-001 no visible Victory acknowledgement")
	_expect(get_nodes_in_group("prologue_cinematic").is_empty(), "VICT-001 movie already obscures victory")
	if world.route_state.prologue_phase == "angler_victory":
		var started := Time.get_ticks_msec()
		var positions: Array = world.divers.map(func(d): return d.position)
		var hp: Array = world.divers.map(func(d): return d.stats.hp)
		var encounters_before := world.random_encounters_enabled
		await create_timer(0.35).timeout
		_expect(_visible_text(world, "victory", 0.9) and _visible_text(world, "defeated", 0.9), "VICT-001 winning copy is transparent/unreadable")
		_expect(audio.get_music_state().cue_id == "prologue_victory" and audio.get_music_gain_state().active_db == -9.0, "VICT-003 victory fanfare is missing or not locally quiet")
		await _key(KEY_ESCAPE)
		await _key(KEY_R)
		await _key(KEY_W)
		_expect(paused and world.battle == fight and not world.inventory_menu.visible, "VICT-004 bridge input opens a menu or loses Battle ownership")
		_expect(positions == world.divers.map(func(d): return d.position) and hp == world.divers.map(func(d): return d.stats.hp), "VICT-004 gameplay moves/damages actors during bridge")
		_expect(world.random_encounters_enabled == encounters_before, "VICT-004 R leaks through paused bridge")
		await _capture("victory")
		await _wait_phase(world, "octopus_notice", 4.0)
		await create_timer(0.5).timeout
		_expect(_visible_text(world, "not gone unnoticed", 0.9), "VICT-002 readable victory-to-threat connection missing")
		_expect(audio.get_music_state().phase == "stopped", "VICT-003 victory music overlaps suspense")
		await _capture("notice")
		await _wait_phase(world, "octopus_omen", 3.0)
		await create_timer(0.35).timeout
		_expect(_visible_text(world, "something stirs", 0.9), "VICT-002 visible omen missing")
		await _capture("omen")
		await create_timer(0.7).timeout
		_expect(_visible_text(world, "something stirs", 0.9) and get_nodes_in_group("prologue_cinematic").is_empty(), "VICT-002 omen flashes away before it can be read")
		await _wait_phase(world, "octopus_introduction", 3.0)
		var duration := float(Time.get_ticks_msec() - started) / 1000.0
		_expect(duration >= 5.5 and duration <= 7.5, "VICT-002 bridge is abrupt or overlong: %.2fs" % duration)
		_expect(phases == ["angler", "angler_victory", "octopus_notice", "octopus_omen", "octopus_introduction"], "VICT-002 ordered public beats missing/duplicated: %s" % [phases])
		_expect(world.battle == fight and not world.route_state.prologue_complete and not world.route_state.tutorial_complete,
			"VICT-005 bridge prematurely completes opening/training or replaces Battle")
		for diver in world.divers:
			_expect(diver.stats.xp == 0 and diver.stats.spell_points == 0 and diver.known_spells.is_empty(), "VICT-005 bridge grants campaign progression")
		_expect(audio.get_audio_settings() == settings and audio.get_music_state().phase == "stopped", "VICT-003 bridge changes player volume/mute or overlaps movie")
		print("VICTORY BRIDGE|seconds=", duration, "|phases=", phases, "|music=", audio.get_music_state())
		if OS.get_cmdline_user_args().has("--capture"):
			await create_timer(2.0).timeout
			await _capture("movie")
	_recording = false
	while not _frames_finished:
		await process_frame
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for suffix in ["", ".pending"]:
		var file: String = ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)) + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	for finding in findings:
		print("FINDING  " + finding)
	print("ANGLER VICTORY BRIDGE: clean" if findings.is_empty() else "ANGLER VICTORY BRIDGE: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _wait_phase(world: World, phase: String, limit: float) -> void:
	var elapsed := 0.0
	while world.route_state.prologue_phase != phase and elapsed < limit:
		await create_timer(0.05).timeout
		elapsed += 0.05

func _visible_text(node: Node, needle: String, minimum_alpha: float = 0.0) -> bool:
	if node is Label and node.is_visible_in_tree() and needle in node.text.to_lower() and _alpha(node) >= minimum_alpha:
		_expect(root.get_visible_rect().encloses(node.get_global_rect()), "VICT-007 readable copy clips outside viewport")
		return true
	for child in node.get_children():
		if _visible_text(child, needle, minimum_alpha):
			return true
	return false

func _alpha(node: Node) -> float:
	var value := 1.0
	while node != null:
		if node is CanvasItem:
			value *= node.modulate.a
		node = node.get_parent()
	return value

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _capture(beat: String) -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		root.get_texture().get_image().save_png("/tmp/angler-victory-%s-%dx%d.png" % [beat, root.size.x, root.size.y])

func _record_frames() -> void:
	var directory := "/tmp/angler-victory-frames-%dx%d" % [root.size.x, root.size.y]
	DirAccess.make_dir_recursive_absolute(directory)
	var frame := 0
	while _recording:
		await process_frame
		root.get_texture().get_image().save_png("%s/frame-%04d.png" % [directory, frame])
		frame += 1
		await create_timer(0.15).timeout
	_frames_finished = true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
