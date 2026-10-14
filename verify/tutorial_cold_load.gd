extends SceneTree

var failures: Array[String] = []
var world: World

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	await process_frame
	var slot := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--slot="):
			slot = int(arg.trim_prefix("--slot="))
	if slot >= 730000 and slot < 930000:
		await _cold_load(slot)
	elif OS.get_cmdline_user_args().has("--legacy-ended-effects"):
		await _legacy_effects()
	else:
		await _prepare()
	for failure in failures:
		push_error(failure)
	world.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	print("TUTORIAL COLD LOAD|failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _prepare() -> void:
	var slot := 830000 + Time.get_ticks_msec() % 100000
	while SaveManager.slot_exists(slot):
		slot += 1
	world.route_state.prologue_complete = true
	world.route_state.opening_video_seen = true
	world.route_state.tutorial_complete = false
	world.route_state.normalize_prologue_phase()
	world.random_encounters_enabled = false
	(world.divers[0] as Diver).position = Vector3(0, 2, 6)
	if OS.get_cmdline_user_args().has("--downed-starter"):
		(world.divers[0] as Diver).stats.hp = 0
	if SaveManager.write_slot(slot, world._serialize_state()) != OK:
		failures.append("QT11: could not write the declared recovered fixture")
		return
	await world._on_title_load_game(slot)
	_key(KEY_W, true)
	var deadline := Time.get_ticks_msec() + 10000
	while world.battle == null and Time.get_ticks_msec() < deadline:
		await process_frame
	_key(KEY_W, false)
	if world.battle == null:
		failures.append("QT11: actual W swimming never reached the lesson beam")
		return
	var results: Array[String] = []
	world.battle.finished.connect(func(result: String) -> void: results.append(result))
	if OS.get_cmdline_user_args().has("--skip"):
		world.battle.skip_tutorial_btn.emit_signal("pressed")
	deadline = Time.get_ticks_msec() + 60000
	while world.battle != null and Time.get_ticks_msec() < deadline:
		var fight := world.battle
		if OS.get_cmdline_user_args().has("--downed-starter") and fight._tutorial_step == 0 and not fight._busy and fight.main_menu.visible:
			fight.attack_btn.emit_signal("pressed")
			await process_frame
			var has_taught_move := false
			for choice in fight.move_buttons:
				has_taught_move = has_taught_move or choice.text.begins_with("Electric Touch")
			if not has_taught_move:
				failures.append("QT11: saved downed Maxilani leaves the starter asking for an unavailable Electric Touch")
				break
		if fight._tutorial_awaiting_enter:
			fight._tutorial_continue_btn.emit_signal("pressed")
		elif fight._qte_active:
			pass # Allow a natural missed dodge, not a perfect-QTE assumption.
		elif fight.target_menu.visible and not fight.target_buttons.is_empty():
			(fight.target_buttons[0] as Button).emit_signal("pressed")
		elif not fight._busy and fight.move_menu.visible:
			for button in fight.move_buttons:
				if button.is_visible_in_tree() and not button.disabled:
					(button as Button).emit_signal("pressed")
					break
		await create_timer(0.03).timeout
	var expected := "skipped" if OS.get_cmdline_user_args().has("--skip") else "won"
	if failures.is_empty() and (results != [expected] or world.battling or paused):
		failures.append("QT11: actual starter did not release control: %s" % str(results))
	var route := SaveManager.read_slot(slot).get("route_state", {}) as Dictionary
	if not route.get("prologue_complete", false) or not route.get("tutorial_complete", false):
		failures.append("QT11: actual starter did not save independent completion milestones")
	for member in SaveManager.read_slot(slot).get("divers", []):
		var stats := member.stats as Dictionary
		if not (stats.get("statuses", {}) as Dictionary).is_empty() or int(stats.get("evasion_current", stats.evasion)) != int(stats.evasion):
			failures.append("QT15: manual starter checkpoint captured battle effects before deferred scene cleanup")
	if failures.is_empty():
		var witness := FileAccess.open("user://quick_tutorial_cold_%d.json" % slot, FileAccess.WRITE)
		witness.store_string(JSON.stringify({"slot": slot, "mode": expected}))
		witness.close()
		print("COLD_SLOT|", slot, "|mode=", expected)

func _cold_load(slot: int) -> void:
	var witness_path := "user://quick_tutorial_cold_%d.json" % slot
	if not FileAccess.file_exists(witness_path):
		failures.append("QT11: no owned prepare witness; refuse to touch this slot")
		return
	var witness := JSON.parse_string(FileAccess.get_file_as_string(witness_path)) as Dictionary
	if not await world._on_title_load_game(slot):
		failures.append("QT11: cold Load rejected the completed starter save")
		return
	for frame in range(8):
		await process_frame
	if not world.route_state.prologue_complete or not world.route_state.tutorial_complete:
		failures.append("QT11: cold Load forgot completed opening/training")
	if world.battle != null or is_instance_valid(world.light_beam) or world._intro_active or paused:
		failures.append("QT11: cold Load reopened training/combat or retained its control lock")
	if world.route_state.prologue_phase != "complete" or not world.get_node("HUD").visible:
		failures.append("QT11: cold Load did not return directly to the exploration UI")
	if witness.get("mode") == "legacy_resource_fidelity":
		var stats: CombatantStats = world.divers[1].stats
		if stats.status_level("bleed") != 2 or stats.evasion_current != 0 or stats.hp != 7 or stats.oxygen != 53:
			failures.append("QT15: cleanup fix must not reinterpret older valid checkpoint resources")
	else:
		for diver in world.divers:
			if not (diver.stats.statuses as Dictionary).is_empty() or diver.stats.evasion_current != diver.stats.effective_evasion():
				failures.append("QT15: cold Load restored ended tutorial effects or spent Evasion")
	var position_before := (world.divers[world.active] as Diver).position
	_key(KEY_W, true)
	await create_timer(0.6).timeout
	_key(KEY_W, false)
	if (world.divers[world.active] as Diver).position.distance_to(position_before) < 0.2:
		failures.append("QT11: real W input could not move after cold Load")
	if failures.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(slot)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(witness_path))
		print("COLD_RESUMED|", slot, "|movable=true|no_opening=true|no_training=true")

func _legacy_effects() -> void:
	var slot := 830000 + Time.get_ticks_msec() % 100000
	while SaveManager.slot_exists(slot):
		slot += 1
	world.route_state.prologue_complete = true
	world.route_state.opening_video_seen = true
	world.route_state.tutorial_complete = true
	world.route_state.normalize_prologue_phase()
	world.random_encounters_enabled = false
	var member := world.divers[1] as Diver
	member.stats.hp = 7
	member.stats.oxygen = 53
	member.stats.add_status("bleed", 2)
	member.stats.evasion_current = 0
	SaveManager.write_slot(slot, world._serialize_state())
	var bytes_before := FileAccess.get_file_as_bytes(SaveManager.slot_path(slot))
	await world._on_title_load_game(slot)
	if member.stats.status_level("bleed") != 2 or member.stats.evasion_current != 0:
		failures.append("QT15: valid legacy checkpoint effects were silently erased")
	if member.stats.hp != 7 or member.stats.oxygen != 53:
		failures.append("QT15: effect normalization must not heal earned HP/Oxygen")
	if FileAccess.get_file_as_bytes(SaveManager.slot_path(slot)) != bytes_before:
		failures.append("QT15: loading legacy effects rewrote the source checkpoint")
	if failures.is_empty():
		var witness := FileAccess.open("user://quick_tutorial_cold_%d.json" % slot, FileAccess.WRITE)
		witness.store_string(JSON.stringify({"slot": slot, "mode": "legacy_resource_fidelity"}))
		witness.close()
		print("COLD_SLOT|", slot, "|mode=legacy_resource_fidelity|hp=7|oxygen=53")

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
