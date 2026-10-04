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
	await process_frame
	await process_frame
	var fight := world.battle
	_expect(fight != null, "ESC-001 ordinary encounter did not boot")
	if fight != null:
		await _wait_for_run(fight)
		var hp_before: Array = world.divers.map(func(d): return d.stats.hp)
		var o2_before: Array = world.divers.map(func(d): return d.stats.oxygen)
		seed(_run_seed(true))
		fight.run_btn.pressed.emit()
		await create_timer(1.85).timeout
		_expect(not world.battling, "ESC-001 actual successful Run failed to return to world")
		var cue := world.get_node_or_null("HUD/EscapeEncounterHint") as Control
		_expect(cue != null and cue.is_visible_in_tree(), "ESC-001 successful escape has no visible encounter-toggle cue")
		_expect(world.random_encounters_enabled, "ESC-003 cue forced encounters Off")
		_expect(hp_before == world.divers.map(func(d): return d.stats.hp), "ESC-003 escape cue healed/damaged party")
		_expect(o2_before == world.divers.map(func(d): return d.stats.oxygen), "ESC-003 escape cue changed Oxygen")
		if cue != null:
			print("ESCAPE VIEW|viewport=", root.get_visible_rect(), "|cue=", cue.get_global_rect())
			_expect("Encounters (On)" in cue.setting_label.text, "ESC-001 cue does not show actual R setting")
			_expect(root.get_visible_rect().encloses(cue.get_global_rect()), "ESC-007 cue clipped")
			_expect(not cue.get_global_rect().intersects(world.route_objective_panel.get_global_rect()), "ESC-007 cue overlaps objective")
			_expect(not cue.get_global_rect().intersects(Rect2(Vector2(root.size.x - 166, 10), Vector2(156, 156))), "ESC-007 cue overlaps minimap")
			_expect(_ignores_pointer(cue), "ESC-006 informational cue blocks pointer input")
			await _capture("on")
			var first_color: Color = cue.get_theme_stylebox("panel").bg_color
			await create_timer(0.3).timeout
			_expect(cue.get_theme_stylebox("panel").bg_color != first_color, "ESC-002 On cue is not pulsing")
			await create_timer(2.6).timeout
			_expect(not cue.visible and world.random_encounters_enabled, "ESC-002 untouched On cue stays visible or changes setting")
			# Failed Run is the actual battle button with a probability fixture,
			# not a fabricated result signal. AI counterattack stays unchanged.
			(world.divers[world.active] as Diver).encounter_triggered.emit()
			await process_frame
			await process_frame
			fight = world.battle
			await _wait_for_run(fight)
			seed(_run_seed(false))
			fight.run_btn.pressed.emit()
			await create_timer(0.1).timeout
			_expect(world.battling and not cue.visible and "Can't get clear" in fight.log_label.get_parsed_text(), "ESC-004 failed Run showed exploration cue")
			await _wait_for_run(fight)
			seed(_run_seed(true))
			fight.run_btn.pressed.emit()
			await create_timer(1.8).timeout
			_expect(not world.battling and cue.visible, "ESC-001 eventual escape after failed Run loses cue")
			await _key(KEY_R)
			_expect(not world.random_encounters_enabled and "Encounters (Off)" in cue.setting_label.text, "ESC-005 real R fails to update setting/cue")
			await _capture("off")
			first_color = cue.get_theme_stylebox("panel").bg_color
			await create_timer(0.3).timeout
			_expect(cue.get_theme_stylebox("panel").bg_color == first_color, "ESC-005 Off cue keeps pulsing")
			(world.divers[world.active] as Diver).encounter_triggered.emit()
			await process_frame
			_expect(not world.battling, "ESC-003 R Off fails to gate actual ordinary encounter event")
			await create_timer(2.5).timeout
			_expect(not cue.visible, "ESC-005 R update extends cue forever")
			# Repeated escape uses one node. A next battle must retire it at once.
			await _key(KEY_R)
			(world.divers[world.active] as Diver).encounter_triggered.emit()
			await process_frame
			await process_frame
			fight = world.battle
			await _wait_for_run(fight)
			seed(_run_seed(true))
			fight.run_btn.pressed.emit()
			await create_timer(1.8).timeout
			_expect(cue.visible, "ESC-006 repeated escape lost single cue owner")
			(world.divers[world.active] as Diver).encounter_triggered.emit()
			await process_frame
			_expect(world.battling and not cue.visible, "ESC-006 old cue leaks into new battle")
			# Retire the real battle before exercising the public Load lifecycle.
			await process_frame
			fight = world.battle
			await _wait_for_run(fight)
			seed(_run_seed(true))
			fight.run_btn.pressed.emit()
			await create_timer(1.8).timeout
			world.title_screen.load_game_chosen.emit(SLOT)
			await process_frame
			await process_frame
			_expect(not cue.visible and world.random_encounters_enabled, "ESC-006 Load resurrects escape cue or changes saved setting")
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
