# QT3/QT10: result-handler plumbing only. Actual combat defeat is separately
# exercised by tutorial_skip_lifecycle.gd --loss. Never claim this injected
# result proves a playable loss.
extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _expect(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
func _run() -> void:
	for choice in ["retry", "exit", "voluntary"]:
		var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
		root.add_child(world)
		await process_frame
		world.title_screen.close()
		paused = false
		world.route_state.prologue_complete = true
		world.route_state.opening_video_seen = true
		world.route_state.normalize_prologue_phase()
		world._intro_active = false
		world.set_physics_process(false)
		world.set_process(false)
		world._build_forced_tutorial_beam()
		if choice == "voluntary":
			world._replay_tutorial_battle(Battle.TUTORIAL_PROFILE_FULL)
			await process_frame
			await _skip_ready(world.battle)
		else:
			await world._start_first_encounter(world.divers[0])
			await process_frame
			world._on_battle_finished("lost")
			await process_frame
			_expect(world.tutorial_result_popup.visible and paused, "QT10: initial loss lacks choice")
			if choice == "retry":
				world.tutorial_result_popup._on_retry_pressed()
				await create_timer(0.8).timeout
				_expect(world.battle != null and world._tutorial_practice == null, "QT10: first Retry was misclassified as optional replay")
				await _skip_ready(world.battle)
			else:
				world.tutorial_result_popup._on_exit_pressed()
		await process_frame
		await process_frame
		_expect(world.route_state.tutorial_complete, "QT3: %s did not release initial training milestone" % choice)
		_expect(world.battle == null and not world.battling and not paused, "QT3: %s did not release normal exploration" % choice)
		_expect(not is_instance_valid(world.light_beam), "QT3: %s left the forced training beacon" % choice)
		world.queue_free()
		await process_frame
	for failure in failures:
		push_error(failure)
	print("TUTORIAL LOSS CHOICE|failures=%d" % failures.size())
	root.get_node("GameAudio").release_streams_for_shutdown()
	quit(0 if failures.is_empty() else 1)

func _skip_ready(fight: Battle) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while fight.skip_tutorial_btn.disabled and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not fight.skip_tutorial_btn.disabled, "QT10: Skip never became usable")
	var outcomes: Array[String] = []
	fight.finished.connect(func(result: String) -> void: outcomes.append(result))
	fight.skip_tutorial_btn.emit_signal("pressed")
	while outcomes.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(outcomes == ["skipped"], "QT10: visible Skip did not finish its real read-delay handoff")
