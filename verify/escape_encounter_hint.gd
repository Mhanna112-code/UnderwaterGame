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
		var deadline := Time.get_ticks_msec() + 12000
		while world.battling and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect(not world.battling, "ESC-001 actual successful Run failed to return to world")
		var cue := world.get_node_or_null("HUD/EscapeEncounterHint") as Control
		_expect(cue != null and cue.is_visible_in_tree(), "RESTORE-3 successful Run has no three-second R teaching cue")
		if cue != null and cue.visible:
			_expect("R:" in cue.setting_label.text and "off" in cue.help_label.text.to_lower(), "RESTORE-3 escape cue does not teach R/off/recovery")
			_expect(_ignores_pointer(cue), "ESC-006 escape cue blocks normal mouse input")
			await _capture("restored-live")
			var initial_style: Color = cue.get_theme_stylebox("panel").bg_color
			await create_timer(0.2).timeout
			_expect(cue.visible and cue.get_theme_stylebox("panel").bg_color != initial_style, "ESC-005 On reminder never visibly pulses")
			_expect(not world.route_objective_panel.visible and not world.exploration_hud.encounter_label.visible, "ESC-007 duplicate World guidance competes with reminder")
		_expect(world.random_encounters_enabled, "ESC-003 escape forced encounters Off")
		_expect(hp_before == world.divers.map(func(d): return d.stats.hp), "ESC-003 escape healed/damaged party")
		_expect(o2_before == world.divers.map(func(d): return d.stats.oxygen), "ESC-003 escape changed Oxygen")
		await create_timer(3.1).timeout
		await process_frame
		_expect(cue == null or not cue.visible, "ESC-002 untouched On cue flashes beyond three seconds")
		_expect(world.route_objective_panel.visible and world.exploration_hud.encounter_label.visible, "ESC-007 normal World guidance fails to return after reminder")
		# Component timer boundary already proved activated by real Run above.
		# Here real R must update the text without restarting that deadline.
		cue.show_after_escape(true)
		await create_timer(1.9).timeout
		await _key(KEY_R)
		_expect(not world.random_encounters_enabled and "Off" in cue.setting_label.text, "ESC-005 real R failed to update setting/cue")
		var off_style: Color = cue.get_theme_stylebox("panel").bg_color
		await create_timer(0.3).timeout
		_expect(cue.visible and cue.get_theme_stylebox("panel").bg_color == off_style, "ESC-005 Off cue still pulses or ended prematurely")
		await create_timer(0.95).timeout
		_expect(not cue.visible, "ESC-005 real R restarted the three-second deadline")
		(world.divers[world.active] as Diver).encounter_triggered.emit()
		await process_frame
		_expect(not world.battling and not is_instance_valid(world.random_encounter_reveal), "ESC-003 actual encounter starts despite R Off")
		await _key(KEY_R)
		(world.divers[world.active] as Diver).encounter_triggered.emit()
		var failed_fight := await _wait_for_encounter(world)
		if failed_fight != null:
			await _wait_for_run(failed_fight)
			seed(_run_seed(false))
			failed_fight.run_btn.pressed.emit()
			await create_timer(0.5).timeout
			_expect(world.battling and not cue.visible, "ESC-004 failed real Run shows an escape reminder")
			await _wait_for_run(failed_fight)
		else:
			findings.append("ESC-004 failed-Run fixture did not reach real combat")
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
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var hint := current_scene.get_node("HUD/EscapeEncounterHint") as Control
		_expect(hint.is_visible_in_tree() and root.get_visible_rect().encloses(hint.get_global_rect()), "ESC-007 live reminder is hidden/clipped")
		var world := current_scene as World
		for other in [world.minimap, world.hud, world.exploration_hud.active_panel, world.exploration_hud.party_panel]:
			if (other as Control).is_visible_in_tree():
				_expect(not hint.get_global_rect().intersects((other as Control).get_global_rect()), "ESC-007 reminder overlaps %s at %s" % [other.name, root.size])
		root.get_texture().get_image().save_png("/tmp/escape-cue-%s-%dx%d.png" % [view, root.size.x, root.size.y])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
