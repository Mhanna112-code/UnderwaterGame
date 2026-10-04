# OPEN-017/018: completed prologue does not force training; entering, losing,
# retrying, returning, skipping and reloading preserve public availability.
extends SceneTree

const SLOT := 918300
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	# A real recovered save, not a skip-tutorial shortcut. Its training state
	# is explicitly incomplete, as recovery writes it in production.
	world.route_state.opening_video_seen = true
	world.route_state.prologue_complete = true
	world.route_state.tutorial_complete = false
	world.route_state.set_objective("")
	SaveManager.write_slot(SLOT, world._serialize_state())
	await world._on_title_load_game(SLOT)
	await process_frame
	_expect(not paused and world.battle == null, "OPEN-017 completed load forced training")
	_expect(world.light_beam != null, "OPEN-017 completed load lost optional training")
	_expect(world.route_state.objective_id != "tutorial", "OPEN-017 training became the route objective")
	var label := world.find_child("OptionalTrainingLabel", true, false) as Label3D
	_expect(label != null and label.text == "Optional Combat Training", "OPEN-017 optional label absent")
	world._update_intro_sequence()
	_expect(world.battle == null, "OPEN-017 recovery spawn activates training immediately")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	world._unhandled_input(tab)
	_expect(world.active == 1, "OPEN-018 ignoring training locks TAB switching")
	var diver := world.divers[world.active] as Diver
	diver.global_position = Vector3(world.light_beam.global_position.x, 2.0, world.light_beam.global_position.z)
	world._update_intro_sequence()
	await create_timer(0.7).timeout
	_expect(world.battle != null and world.battle.tutorial_encounter, "OPEN-017 voluntary beacon never starts current tutorial")
	if world.battle != null:
		for value in world.divers:
			(value as Diver).stats.hp = 1
		# Drive the declared Battle result boundary; interactive defeat captions
		# are preserved by the inherited combat tutorial gates.
		world._on_battle_finished("lost")
		await create_timer(0.3).timeout
		_expect(world.tutorial_result_popup.visible, "OPEN-017 training loss has no Retry/Return choice")
		world.tutorial_result_popup.call("_on_retry_pressed")
		await process_frame
		_expect(world.battle != null and world.battle.tutorial_encounter, "OPEN-017 Retry does not restart training")
		if world.battle != null:
			# Retry heals the party. Reapply attrition for the second loss so
			# its checkpoint assertion cannot pass on an untouched healthy party.
			for value in world.divers:
				(value as Diver).stats.hp = 1
				(value as Diver).stats.oxygen = 40.0
			world._on_battle_finished("lost")
			await create_timer(0.3).timeout
			world.tutorial_result_popup.call("_on_exit_pressed")
			await process_frame
			await process_frame
			_close_onboarding()
			await process_frame
			_expect(world.battle == null and not paused, "OPEN-017 Return to World left stale battle/pause")
			_expect(not world.route_state.tutorial_complete and world.light_beam.is_visible_in_tree(), "OPEN-017 Return retired training")
			world._update_intro_sequence()
			_expect(world.battle == null, "OPEN-017 Return spawn immediately re-enters training")
			for value in world.divers:
				var stats := (value as Diver).stats
				_expect(stats.hp == stats.hp_max and stats.oxygen >= stats.oxygen_max - 0.1, "OPEN-016 training Return did not restore party")
			var returned_save := SaveManager.read_slot(SLOT)
			for snapshot in returned_save.get("divers", []):
				var saved_stats := (snapshot as Dictionary).get("stats", {}) as Dictionary
				_expect(saved_stats.get("hp", 0) == saved_stats.get("hp_max", -1) and saved_stats.get("oxygen", 0.0) == saved_stats.get("oxygen_max", -1.0), "OPEN-031 training Return leaves an unrestored checkpoint")
			_expect((returned_save.get("route_state", {}) as Dictionary).get("prologue_complete", false), "OPEN-031 training recovery loses opening completion")
			diver = world.divers[world.active] as Diver
			diver.global_position = Vector3(world.light_beam.global_position.x, 2.0, world.light_beam.global_position.z)
			world._update_intro_sequence()
			await create_timer(0.7).timeout
			if world.battle != null:
				var elapsed := 0.0
				while world.battle._busy and elapsed < 5.0:
					if world.battle._tutorial_awaiting_enter:
						var enter := InputEventKey.new()
						enter.keycode = KEY_ENTER
						enter.pressed = true
						world.battle._unhandled_input(enter)
					await create_timer(0.1).timeout
					elapsed += 0.1
				for value in world.divers:
					(value as Diver).stats.hp = 1
					(value as Diver).stats.oxygen = 40.0
				world.battle._on_skip_tutorial_pressed()
				elapsed = 0.0
				while world.battle != null and elapsed < 5.0:
					await create_timer(0.1).timeout
					elapsed += 0.1
				_close_onboarding()
				await process_frame
				_expect(world.route_state.tutorial_complete and world.light_beam == null, "OPEN-017 Skip did not retire training")
				_expect(not paused and world.battle == null, "OPEN-017 Skip did not return world control")
	var saved := SaveManager.read_slot(SLOT)
	_expect((saved.get("route_state", {}) as Dictionary).get("tutorial_complete", false), "OPEN-017 training completion not persisted")
	for snapshot in saved.get("divers", []):
		var saved_stats := (snapshot as Dictionary).get("stats", {}) as Dictionary
		_expect(saved_stats.get("hp", 0) == saved_stats.get("hp_max", -1) and saved_stats.get("oxygen", 0.0) == saved_stats.get("oxygen_max", -1.0), "OPEN-031 training Skip saves pre-recovery attrition")
	world.queue_free()
	await process_frame
	paused = false
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)))
	for finding in findings:
		print("FINDING  " + finding)
	print("OPTIONAL TRAINING: clean" if findings.is_empty() else "OPTIONAL TRAINING: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _close_onboarding() -> void:
	var popup := root.get_node_or_null("CharacterAbilityPopup")
	if popup != null:
		popup.call("_close")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
