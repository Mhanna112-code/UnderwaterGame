# ESC-001: actual Run -> actual World handoff, never an injected result.
extends SceneTree
const SLOT := 918321
var findings: Array[String] = []

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
	var checkpoint := world._serialize_state() # setup fixture only
	checkpoint.route_state = {"opening_video_seen": true, "prologue_complete": true, "tutorial_complete": true}
	checkpoint.random_encounters_enabled = true
	checkpoint.divers[0].sonar_active = false
	SaveManager.write_slot(SLOT, checkpoint)
	world.title_screen.load_game_chosen.emit(SLOT)
	await process_frame
	await process_frame
	(world.divers[world.active] as Diver).encounter_triggered.emit()
	var fight := await _wait_for_encounter(world)
	_expect(fight != null, "ESC-001 ordinary encounter did not boot")
	if fight != null:
		await _wait_for_run(fight)
		var hp_before: Array = world.divers.map(func(d): return d.stats.hp)
		var o2_before: Array = world.divers.map(func(d): return d.stats.oxygen)
		seed(_run_seed(true))
		fight.run_btn.pressed.emit()
		await create_timer(Battle.LOG_READ_DELAY + 0.5).timeout
		_expect(not world.battling, "ESC-001 actual successful Run failed to return to world")
		var cue := world.get_node_or_null("HUD/EscapeEncounterHint") as Control
		# The post-escape cue was removed on request: escaping shows only the
		# "You successfully ran away." notice; the HP-bar badge shows R.
		_expect(cue == null or not cue.is_visible_in_tree(), "ESC-001 removed post-escape encounter cue still appears")
		_expect(world.random_encounters_enabled, "ESC-003 escape forced encounters Off")
		_expect(hp_before == world.divers.map(func(d): return d.stats.hp), "ESC-003 escape healed/damaged party")
		_expect(o2_before == world.divers.map(func(d): return d.stats.oxygen), "ESC-003 escape changed Oxygen")
	# Separate public-component cases, not a fabricated World escape result.
	# Already-Off and paused-menu expiry share the same absolute deadline.
	var isolated := preload("res://game/encounter_escape_hint.gd").new()
	root.add_child(isolated)
	isolated.show_after_escape(false)
	var steady: Color = isolated.get_theme_stylebox("panel").bg_color
	await create_timer(0.3).timeout
	_expect("Encounters (Off)" in isolated.setting_label.text and isolated.get_theme_stylebox("panel").bg_color == steady,
		"ESC-005 already-Off cue pulses or invites encounters On")
	paused = true
	await create_timer(2.85).timeout
	_expect(not isolated.visible, "ESC-002 paused menu makes cue persist forever")
	paused = false
	isolated.queue_free()
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for suffix in ["", ".pending"]:
		var path: String = ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)) + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for finding in findings:
		print("FINDING  " + finding)
	print("ESCAPE CUE: clean" if findings.is_empty() else "ESCAPE CUE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _wait_for_run(fight: Battle) -> void:
	var elapsed := 0.0
	while (not fight.main_menu.is_visible_in_tree() or fight.run_btn.disabled) and elapsed < 40.0:
		await create_timer(0.1).timeout
		elapsed += 0.1
	_expect(fight.main_menu.is_visible_in_tree() and not fight.run_btn.disabled, "ESC-001 actual Run unavailable")

func _wait_for_encounter(world: World) -> Battle:
	# Ordinary combat now deliberately follows a 1.5-second in-water reveal.
	# Waiting two frames falsely rejected that valid player-visible transition.
	var deadline := Time.get_ticks_msec() + 5000
	while world.battle == null and Time.get_ticks_msec() < deadline:
		await process_frame
	return world.battle

func _run_seed(success: bool) -> int:
	for candidate in range(1000):
		seed(candidate)
		if (randf() <= Battle.RUN_CHANCE) == success:
			return candidate
	return 0

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

func _ignores_pointer(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _ignores_pointer(child):
			return false
	return true

func _capture(view: String) -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		root.get_texture().get_image().save_png("/tmp/escape-cue-%s-%dx%d.png" % [view, root.size.x, root.size.y])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
