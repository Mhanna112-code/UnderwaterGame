# OPEN-011/013/014/015/016: real combat-button journey must interrupt victory,
# register a negligible hit, defeat and recover without campaign/reward leaks.
extends SceneTree

const SLOT := 918299
var findings: Array[String] = []
var phases: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	world.route_state.phase_changed.connect(func(phase: String) -> void: phases.append(phase))
	await world._on_title_new_game(SLOT)
	world.call("_update_prologue_trigger", 0.4)
	world.call("_update_prologue_trigger", 7.2)
	await process_frame
	if world.battle == null:
		findings.append("OPEN-011 journey failed to start Angler")
		await _finish(world)
		return
	var original := world.battle
	var campaign_state: String = world.route_state.octopus_state
	await _attack(original)
	await _wait_phase(world, "octopus_introduction", 12.0)
	var movie := await _wait_movie()
	_expect(movie != null, "OPEN-023 Cordys introduction has no movie owner")
	if movie != null:
		_expect(root.get_node("GameAudio").get_music_state().phase == "stopped", "OPEN-005 music overlaps Cordys introduction")
		movie.pause_introduction_for_test()
	await _wait_phase(world, "octopus_response", 12.0)
	_expect(world.battle == original, "OPEN-011 Cordys did not retain the same Battle owner")
	if world.route_state.prologue_phase != "octopus_response":
		findings.append("OPEN-011 Angler victory never became a playable Cordys response; phase=%s" % world.route_state.prologue_phase)
		await _finish(world)
		return
	_expect(original.enemies.size() == 1 and String(original.enemies[0].display_name) == "Cordys", "OPEN-012 Cordys actor/state absent")
	_expect((original._player_stats_ui.panel as Control).is_visible_in_tree(), "OPEN-014 Cordys response lost the player's stat panel")
	var cordys_hp: int = (original.enemies[0].stats as CombatantStats).hp
	var swings: Array[String] = []
	original.player_swing_staged.connect(func(_a: Node3D, _b: Node3D) -> void: swings.append("hit"))
	await _attack(original)
	await _wait_phase(world, "octopus_aftermath", 20.0)
	_expect(not world.route_state.prologue_complete, "OPEN-024 recovery saved completion before aftermath finished")
	_expect(_find_button(world, "Continue") == null, "OPEN-024 recovery message appeared over aftermath")
	_expect(root.get_node("GameAudio").get_music_state().phase == "stopped", "OPEN-005 boss music overlaps aftermath")
	if is_instance_valid(movie):
		movie.finish_for_test()
	await _wait_phase(world, "recovery", 20.0)
	_expect(not swings.is_empty(), "OPEN-014 Cordys response ignored real attack input")
	if is_instance_valid(original):
		var hp_now: int = (original.enemies[0].stats as CombatantStats).hp
		_expect(hp_now < cordys_hp and hp_now >= int(cordys_hp * 0.98), "OPEN-014 Cordys hit was absent or not negligible")
	_expect(world.route_state.prologue_phase == "recovery", "OPEN-015 scripted defeat did not enter recovery")
	var elapsed := 0.0
	while elapsed < 4.0 and _find_button(world, "Continue") == null:
		await create_timer(0.1).timeout
		elapsed += 0.1
	var continue_button := _find_button(world, "Continue")
	_expect(continue_button != null, "OPEN-016 recovery motivation has no Continue action")
	if continue_button != null:
		continue_button.emit_signal("pressed")
	await process_frame
	await process_frame
	_expect(world.route_state.prologue_complete, "OPEN-016 recovery did not commit prologue_complete")
	_expect(not world.route_state.tutorial_complete, "OPEN-017 prologue falsely completed optional training")
	_expect(world.route_state.octopus_state == campaign_state, "OPEN-013 prologue mutated campaign Octopus state")
	_expect(not paused and not world.battling, "OPEN-016 recovery did not return world control")
	_expect(not world.game_over_screen.visible, "OPEN-015 scripted defeat showed normal Game Over")
	for value in world.divers:
		var diver := value as Diver
		_expect(diver.stats.hp == diver.stats.hp_max and diver.stats.oxygen >= diver.stats.oxygen_max - 0.1, "OPEN-016 recovery did not restore every diver")
		_expect(diver.stats.xp == 0 and diver.stats.spell_points == 0 and diver.known_spells.is_empty(), "OPEN-010 prologue granted progression")
	var save := SaveManager.read_slot(SLOT)
	_expect((save.get("route_state", {}) as Dictionary).get("prologue_complete", false), "OPEN-016 recovery save milestone missing")
	_expect(phases == ["spawn_exploration", "angler", "octopus_introduction", "octopus_reveal", "octopus_response", "scripted_defeat", "octopus_aftermath", "recovery", "complete"], "OPEN-002 public phases missing/duplicated: %s" % [phases])
	await _finish(world)

func _attack(fight: Battle) -> void:
	fight.attack_btn.emit_signal("pressed")
	await process_frame
	if fight.move_buttons.is_empty():
		findings.append("OPEN-014 Attack opened no moves")
		return
	(fight.move_buttons[0] as Button).emit_signal("pressed")
	await process_frame
	_expect(fight._selected_move_panel.is_visible_in_tree(), "OPEN-014 selected attack feedback is hidden")
	if fight.target_buttons.is_empty():
		findings.append("OPEN-014 selected attack has no target")
		return
	(fight.target_buttons[0] as Button).emit_signal("pressed")

func _wait_phase(world: World, phase: String, limit: float) -> void:
	var elapsed := 0.0
	while world.route_state.prologue_phase != phase and elapsed < limit:
		await create_timer(0.1).timeout
		elapsed += 0.1

func _wait_movie() -> CanvasLayer:
	for _i in range(30):
		var movie := get_first_node_in_group("prologue_cinematic") as CanvasLayer
		if movie != null:
			return movie
		await create_timer(0.1).timeout
	return null

func _find_button(node: Node, text_value: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == text_value and (child as Button).is_visible_in_tree():
			return child as Button
		var found := _find_button(child, text_value)
		if found != null:
			return found
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish(world: World) -> void:
	world.queue_free()
	await process_frame
	paused = false
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(SLOT))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING JOURNEY: clean" if findings.is_empty() else "OPENING JOURNEY: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
