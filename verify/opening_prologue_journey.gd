# OPEN-011/013/014/015/016: real combat-button journey must interrupt victory,
# register a negligible hit, defeat and recover without campaign/reward leaks.
extends SceneTree

const SLOT := 918299
var findings: Array[String] = []
var phases: Array[String] = []
var real_loss_case := false
var training_case := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	var fallback_case := OS.get_cmdline_user_args().has("--opening-fallback")
	var save_failure_case := OS.get_cmdline_user_args().has("--opening-save-failure")
	real_loss_case = OS.get_cmdline_user_args().has("--opening-real-loss")
	training_case = OS.get_cmdline_user_args().has("--opening-training-loss")
	if training_case:
		real_loss_case = true
	world.skip_intro_for_test = not (fallback_case or save_failure_case)
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	world.route_state.phase_changed.connect(func(phase: String) -> void: phases.append(phase))
	if fallback_case or save_failure_case:
		# OPEN-027 cross-feature case: acknowledged decoder failure must not
		# force a completed playable prologue to replay on a later death/load.
		world._on_title_new_game(SLOT)
		await process_frame
		if save_failure_case:
			# Only these uniquely owned test files are made unwritable. Keep
			# the actual initial checkpoint readable, with both flags false.
			_set_checkpoint_writable(false)
			world.opening_video.call("finish_for_test")
		else:
			world.opening_video.call("fail_for_test")
			var fallback_continue := _find_button(world.opening_video, "Continue")
			_expect(fallback_continue != null, "OPEN-027 decoder fallback has no Continue")
			if fallback_continue != null:
				fallback_continue.emit_signal("pressed")
		await process_frame
		await process_frame
	else:
		await world._on_title_new_game(SLOT)
	# Engage the actual swimming input, not the removed idle fallback or a
	# private trigger/time jump. Keep the rest of this combat/save journey intact.
	var swim := InputEventKey.new()
	swim.keycode = KEY_W
	swim.physical_keycode = KEY_W
	swim.pressed = true
	Input.parse_input_event(swim)
	await _wait_phase(world, "angler", 10.0)
	swim.pressed = false
	Input.parse_input_event(swim)
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
	if save_failure_case:
		var retry := _find_button(world, "Retry Save")
		_expect(retry != null, "OPEN-028 failed recovery save has no visible Retry Save")
		_expect(continue_button == null, "OPEN-028 failed recovery save offers a false successful Continue")
		var failed_save := SaveManager.read_slot(SLOT)
		print("FAILED CHECKPOINT|", failed_save.get("route_state", {}))
		_expect(not (failed_save.get("route_state", {}) as Dictionary).get("prologue_complete", true), "OPEN-028 fault fixture did not retain the initial checkpoint")
		_expect(paused and world.battling, "OPEN-028 write failure released ordinary play")
		_set_checkpoint_writable(true)
		if retry != null:
			retry.emit_signal("pressed")
			await process_frame
			continue_button = _find_button(world, "Continue")
	_expect(continue_button != null, "OPEN-016 recovery motivation has no Continue action")
	_expect((SaveManager.read_slot(SLOT).get("route_state", {}) as Dictionary).get("prologue_complete", false), "OPEN-027 motivation appeared before its completed checkpoint was durable")
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
	var expected_phases: Array[String] = ["spawn_exploration", "angler", "octopus_introduction", "octopus_reveal", "octopus_response", "scripted_defeat", "octopus_aftermath", "recovery", "complete"]
	if fallback_case or save_failure_case:
		expected_phases.push_front("opening_video")
	_expect(phases == expected_phases, "OPEN-002 public phases missing/duplicated: %s" % [phases])
	if training_case:
		await _skip_optional_training(world)
	# OPEN-018: prove the actual recovered run, with training still incomplete,
	# can start an ordinary encounter. A synthetic completed fixture alone
	# would not prove that the opening handoff unlocked the production signal.
	(world.divers[world.active] as Diver).encounter_triggered.emit()
	await process_frame
	_expect(world.battle != null and not world.battle.prologue_angler_encounter and not world.battle.prologue_octopus_encounter, "OPEN-018 ignoring training leaves ordinary encounters locked")
	# OPEN-027: a later ordinary defeat must not rewind the completed opening.
	# The fast characterization emits the result boundary; --opening-real-loss
	# and --opening-training-loss instead run real enemy damage/defeat. Both
	# restart via the visible button, persistent file and SceneTree reload.
	if world.battle == null:
		await _finish(world)
		return
	if real_loss_case:
		await _lose_through_real_combat(world)
	else:
		world.battle.finished.emit("lost")
	await process_frame
	_expect(world.game_over_screen.is_visible_in_tree(), "OPEN-027 ordinary loss does not show Game Over")
	var restart := _find_button(world, "Restart from Save Point")
	_expect(restart != null, "OPEN-027 Game Over has no restart button")
	print("RESTART SAVED|", SaveManager.read_slot(SLOT).get("route_state", {}))
	if restart == null:
		await _finish(world)
		return
	var old_instance := world.get_instance_id()
	restart.emit_signal("pressed")
	for _i in range(8):
		await process_frame
	var restored := current_scene as World
	_expect(restored != null and restored.get_instance_id() != old_instance, "OPEN-027 restart did not rebuild the World")
	if restored != null:
		print("RESTART LOADED|slot=", restored._current_slot, "|", restored.route_state.to_save_data())
		_expect(restored.route_state.prologue_complete, "OPEN-027 death restart lost the completed opening")
		_expect(restored.route_state.opening_video_seen == not fallback_case, "OPEN-027 restart changed the successful-video milestone")
		_expect(restored.route_state.prologue_phase == "complete", "OPEN-027 death restart enters the opening instead of normal play")
		_expect(not paused and not restored.battling, "OPEN-027 restart does not restore controllable world")
		_expect(get_nodes_in_group("opening_video").is_empty() and get_nodes_in_group("prologue_cinematic").is_empty(), "OPEN-027 restart created a prologue movie")
		_expect(not restored.game_over_screen.is_visible_in_tree(), "OPEN-027 restart leaves Game Over visible")
		_expect(restored._current_slot == SLOT, "OPEN-027 death restart selected a different slot")
		for value in restored.divers:
			var diver := value as Diver
			_expect(diver.stats.hp == diver.stats.hp_max, "OPEN-027 restart loads a dead party")
		# Exercise the independent title Load Game signal after another actual
		# Game Over -> Return to Title reload. The test slot is deliberately
		# outside the three player slots; emitting the public chosen-slot signal
		# avoids overwriting a user's save just to use the picker.
		(restored.divers[restored.active] as Diver).encounter_triggered.emit()
		await process_frame
		if restored.battle != null:
			if real_loss_case:
				await _lose_through_real_combat(restored)
			else:
				restored.battle.finished.emit("lost")
			await process_frame
			var title_button := _find_button(restored, "Return to Title")
			_expect(title_button != null, "OPEN-027 Game Over has no Return to Title")
			if title_button != null:
				title_button.emit_signal("pressed")
				for _i in range(8):
					await process_frame
				restored = current_scene as World
				_expect(restored.title_screen.is_visible_in_tree(), "OPEN-027 Return to Title does not show title")
				restored.title_screen.load_game_chosen.emit(SLOT)
				for _i in range(8):
					await process_frame
				_expect(restored.route_state.prologue_complete and restored.route_state.prologue_phase == "complete", "OPEN-027 title Load Game replays completed prologue")
				_expect(not paused and not restored.battling and not restored.title_screen.is_visible_in_tree(), "OPEN-027 title Load Game does not return normal control")
				_expect(get_nodes_in_group("opening_video").is_empty() and get_nodes_in_group("prologue_cinematic").is_empty(), "OPEN-027 title Load Game creates a prologue movie")
	await _finish(restored)

# OPEN-027/018 cross-feature path: real recovery → voluntary existing training
# → public Skip → onboarding dismissal → ordinary enemy-caused death/reload.
func _skip_optional_training(world: World) -> void:
	var diver := world.divers[world.active] as Diver
	diver.global_position = Vector3(world.light_beam.global_position.x, 2.0, world.light_beam.global_position.z)
	world._update_intro_sequence()
	await create_timer(0.7).timeout
	_expect(world.battle != null and world.battle.tutorial_encounter, "OPEN-027 recovered run cannot voluntarily enter training")
	if world.battle == null:
		return
	var elapsed := 0.0
	while world.battle != null and elapsed < 10.0:
		var button := _find_button(world.battle, "Continue")
		if button != null and not button.disabled:
			button.emit_signal("pressed")
		var skip := world.battle.skip_tutorial_btn
		if skip != null and skip.is_visible_in_tree() and not skip.disabled:
			skip.emit_signal("pressed")
		await create_timer(0.1).timeout
		elapsed += 0.1
	var onboarding := root.get_node_or_null("CharacterAbilityPopup")
	if onboarding != null:
		onboarding.call("_close")
	await process_frame
	_expect(world.battle == null and not paused and world.route_state.tutorial_complete, "OPEN-027 optional Skip fails to return control")
	var state := SaveManager.read_slot(SLOT).get("route_state", {}) as Dictionary
	_expect(state.get("tutorial_complete", false) and state.get("prologue_complete", false), "OPEN-027 training save loses completed opening")

# OPEN-027: actual Run failure → enemy attack → QTE timeout → party death →
# Battle._lose() → Game Over. A low-HP fixture represents ordinary attrition;
# no HP-zero/result/completion injection bypasses the defeat pipeline.
func _lose_through_real_combat(world: World) -> void:
	for value in world.divers:
		(value as Diver).stats.hp = 1
		(value as Diver).stats.defense = 0
		(value as Diver).stats.evasion = 0
		(value as Diver).stats.evasion_current = 0
	var elapsed := 0.0
	var actions := 0
	while not world.game_over_screen.is_visible_in_tree() and elapsed < 90.0:
		if world.battle == null:
			findings.append("OPEN-027 ordinary battle ended without Game Over")
			return
		var caption_continue := _find_button(world.battle, "Continue")
		if caption_continue != null and not caption_continue.disabled:
			caption_continue.emit_signal("pressed")
			await create_timer(0.1).timeout
			elapsed += 0.1
			continue
		var run := world.battle.run_btn
		if run.is_visible_in_tree() and not run.disabled:
			print("DEATH ACTION|party=", world.battle.party.map(func(entry: Dictionary) -> int: return (entry.stats as CombatantStats).hp), "|enemies=", world.battle.enemies.map(func(entry: Dictionary) -> String: return String(entry.display_name)))
			# Deterministic randomness is only a fixture: arrange a blocked
			# escape, then let the production move/damage/QTE pipeline run.
			var fixture_seed := 701 + actions * 31
			seed(fixture_seed)
			while randf() < 0.9:
				fixture_seed += 1
				seed(fixture_seed)
			seed(fixture_seed)
			run.emit_signal("pressed")
			actions += 1
		await create_timer(0.1).timeout
		elapsed += 0.1
	_expect(world.game_over_screen.is_visible_in_tree(), "OPEN-027 real enemy attacks never reached ordinary Game Over")
	_expect(actions > 0, "OPEN-027 real-death scenario bypassed player combat actions")
	for value in world.divers:
		_expect((value as Diver).stats.hp <= 0, "OPEN-027 Game Over appeared before actual party defeat")
	print("REAL ORDINARY DEATH|actions=", actions, "|seconds=", elapsed)

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
	_set_checkpoint_writable(true)
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	paused = false
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(SLOT))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	if FileAccess.file_exists(absolute + ".pending"):
		DirAccess.remove_absolute(absolute + ".pending")
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING JOURNEY: clean" if findings.is_empty() else "OPENING JOURNEY: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _set_checkpoint_writable(writable: bool) -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(SLOT))
	if not writable and not FileAccess.file_exists(absolute + ".pending"):
		var pending := FileAccess.open(absolute + ".pending", FileAccess.WRITE)
		pending.store_string("owned failure-fixture candidate")
		pending.close()
	for filename in [absolute, absolute + ".pending"]:
		if FileAccess.file_exists(filename):
			var result := FileAccess.set_unix_permissions(filename, 384 if writable else 256)
			_expect(result == OK, "OPEN-028 could not establish/restore the owned file permission fixture")
