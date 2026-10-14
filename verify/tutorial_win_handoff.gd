# OPEN-039: actual winning attack must expose a usable Continue and finish.
extends SceneTree

var findings: Array[String] = []
var world: World
const SLOT := 918301

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--world-lesson"):
		world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
		root.add_child(world)
		await process_frame
		world.route_state.opening_video_seen = true
		world.route_state.prologue_complete = true
		world.route_state.tutorial_complete = false
		(world.divers[0] as Diver).position = Vector3(0, 2, 6)
		SaveManager.write_slot(SLOT, world._serialize_state())
		await world._on_title_load_game(SLOT)
		print("TRAINING_ENTRY|position=", (world.divers[world.active] as Diver).position, "|beam=", world.light_beam.global_position if world.light_beam != null else Vector3.ZERO)
		_swim(true)
		var deadline := Time.get_ticks_msec() + 8000
		while world.battle == null and Time.get_ticks_msec() < deadline:
			await process_frame
		_swim(false)
		if world.battle == null or not world.battle.tutorial_encounter:
			push_error("OPEN-039 actual swim did not reach optional training (ordinary fight does not count)")
			quit(1)
			return
		await _full_lesson(world.battle)
		return
	var sources: Array[Diver] = []
	for model_name in ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]:
		var diver := Diver.new()
		diver.model_name = model_name
		root.add_child(diver)
		sources.append(diver)
	await process_frame
	var fight := Battle.new()
	fight.tutorial_encounter = true
	fight.party_source = sources
	root.add_child(fight)
	await process_frame
	if OS.get_cmdline_user_args().has("--full-lesson"):
		await _full_lesson(fight)
		return
	# Finish the opening captions before setting the completed-lesson fixture.
	var start_deadline := Time.get_ticks_msec() + 12000
	while not fight._first_fight_prompt_shown or fight._tutorial_awaiting_enter or fight.move_buttons.is_empty() or (fight.move_buttons[0] as Button).disabled:
		if fight._tutorial_awaiting_enter:
			if fight._tutorial_continue_btn.is_visible_in_tree():
				fight._tutorial_continue_btn.emit_signal("pressed")
			else:
				_press_key(KEY_ENTER)
		elif fight._qte_active:
			var center := fight.qte_indicator.position.x + fight.qte_indicator.size.x * 0.5
			if center >= fight.qte_zone.position.x and center <= fight.qte_zone.position.x + fight.qte_zone.size.x:
				_press_key(KEY_X)
		await create_timer(0.05).timeout
		if Time.get_ticks_msec() > start_deadline:
			push_error("OPEN-039 fixture could not finish introductory captions")
			quit(1)
			return
	fight._tutorial_step = fight._TUTORIAL_SCRIPT.size()
	fight._tutorial_enemy_turns = 1
	fight._tutorial_finale_shown = true
	fight._set_tutorial_guard(false)   # the real finale clears the no-knockout guard
	var enemy := fight.enemies[0].stats as CombatantStats
	enemy.hp = 1
	enemy.defense = 0
	enemy.evasion_current = 0
	var actor := fight._acting.stats as CombatantStats
	actor.accuracy = 10
	actor.strength = 10
	var results: Array[String] = []
	fight.finished.connect(func(result: String) -> void: results.append(result))
	fight.attack_btn.emit_signal("pressed")
	await process_frame
	(fight.move_buttons[0] as Button).emit_signal("pressed")
	await process_frame
	(fight.target_buttons[0] as Button).emit_signal("pressed")
	var deadline := Time.get_ticks_msec() + 40000
	while not fight._tutorial_awaiting_enter and results.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	print("WIN_PROBE|log=%s|caption=%s|await=%s|paused=%s" % [fight._current_log_text(), fight._tutorial_caption.text, fight._tutorial_awaiting_enter, paused])
	if not fight._tutorial_awaiting_enter or not fight._tutorial_continue_btn.is_visible_in_tree():
		findings.append("OPEN-039 winning attack never exposes a visible Continue")
	else:
		for _i in range(5):
			await process_frame
		var button := fight._tutorial_continue_btn as Button
		# Dummy headless rendering reports a tiny viewport; it can verify the
		# action/result but not browser-resolution layout. Rendered wide/narrow
		# runs and the real web input gate retain the bounds assertion.
		var clipped := DisplayServer.get_name() != "headless" and not root.get_visible_rect().encloses(button.get_global_rect())
		if clipped or button.disabled:
			findings.append("OPEN-039 victory Continue is clipped or disabled")
		button.emit_signal("pressed")
		await process_frame
		await process_frame
	if results != ["won"]:
		findings.append("OPEN-039 Continue did not finish exactly one real victory: %s" % str(results))
	for finding in findings:
		push_error(finding)
	print("TUTORIAL WIN HANDOFF: clean" if findings.is_empty() else "TUTORIAL WIN HANDOFF: FAILED")
	if is_instance_valid(fight):
		fight.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	quit(0 if findings.is_empty() else 1)

func _full_lesson(fight: Battle) -> void:
	var results: Array[String] = []
	fight.finished.connect(func(result: String) -> void: results.append(result))
	var deadline := Time.get_ticks_msec() + 180000
	var last_state := ""
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		var state := "%d|%s|%s|%s" % [fight._tutorial_step, fight._current_log_text(), fight._tutorial_caption.text, fight._tutorial_awaiting_enter]
		if state != last_state:
			print("LESSON|", state)
			last_state = state
		if fight._tutorial_awaiting_enter:
			if fight._tutorial_continue_btn.is_visible_in_tree():
				fight._tutorial_continue_btn.emit_signal("pressed")
			else:
				_press_key(KEY_ENTER)
		elif fight._qte_active:
			var center := fight.qte_indicator.position.x + fight.qte_indicator.size.x * 0.5
			if center >= fight.qte_zone.position.x and center <= fight.qte_zone.position.x + fight.qte_zone.size.x:
				_press_key(KEY_X)
		elif fight.target_menu.visible and not fight.target_buttons.is_empty():
			var button := fight.target_buttons[0] as Button
			# Hover-only targets deliberately look enabled, but their public
			# mouse mask rejects clicks until the explanation is acknowledged.
			# Emitting pressed through that guard skips a required real lesson
			# and leaves its hover coroutine waiting on a replaced button.
			if button.disabled or button.button_mask == 0:
				button.emit_signal("mouse_entered")
			else:
				button.emit_signal("pressed")
		elif not fight._busy and fight.move_menu.visible:
			var chosen: Button
			for candidate in fight.move_buttons:
				var button := candidate as Button
				if button.is_visible_in_tree() and not button.disabled:
					if chosen == null:
						chosen = button
			if chosen != null:
				chosen.emit_signal("pressed")
		elif not fight._busy and fight.main_menu.visible and not fight.attack_btn.disabled:
			fight.attack_btn.emit_signal("pressed")
		await create_timer(0.1).timeout
	print("FULL_LESSON_RESULT|", results)
	if results != ["won"]:
		findings.append("OPEN-039 full tutorial never returns a real victory")
	if world != null:
		await process_frame
		var popup := root.get_node_or_null("CharacterAbilityPopup") as Control
		if popup != null:
			for _i in range(10):
				var close := popup.get_node_or_null("%PopupClose") as Button
				if close != null and close.is_visible_in_tree():
					close.emit_signal("pressed")
				await process_frame
				await process_frame
		if world.battle != null or world.battling or paused:
			findings.append("OPEN-039 real victory did not release world control")
		var route := SaveManager.read_slot(SLOT).get("route_state", {}) as Dictionary
		if not route.get("tutorial_complete", false) or not route.get("prologue_complete", false):
			findings.append("OPEN-039 victory did not persist both independent milestones")
		var before := (world.divers[world.active] as Diver).global_position
		_swim(true)
		await create_timer(0.5).timeout
		_swim(false)
		if (world.divers[world.active] as Diver).global_position.distance_to(before) < 0.2:
			findings.append("OPEN-039 world remains immobile after victory")
	for finding in findings:
		push_error(finding)
	if is_instance_valid(fight):
		fight.queue_free()
	if world != null:
		world.queue_free()
		DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	quit(0 if findings.is_empty() else 1)

func _swim(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	Input.parse_input_event(event)

func _press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
