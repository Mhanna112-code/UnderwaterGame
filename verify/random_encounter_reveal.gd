extends SceneTree

var findings: Array[String] = []
var world: World
var output := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
		DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		findings.append(message)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280, 720)
	world = load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.route_state.opening_video_seen = true
	world.route_state.prologue_complete = true
	world.route_state.tutorial_complete = true
	root.add_child(world)
	await process_frame
	world.title_screen.new_game_chosen.emit(918281)
	await process_frame
	await physics_frame
	var diver := world.divers[world.active] as Diver
	diver.global_position = Vector3(0, 4, 0)
	world._intro_active = false
	world.random_encounters_enabled = true
	world._move_camera(1.0)
	var before := Vector3(diver.stats.hp, diver.stats.oxygen, world.active)
	var position_before := diver.global_position
	# REVEAL-01: real distance-roll public event, not a fake battle result.
	diver.encounter_triggered.emit()
	await process_frame
	var reveals := get_nodes_in_group("random_encounter_reveal")
	_check(reveals.size() == 1 and world.battle == null,
		"REVEAL-01: random fight must first show enemies in exploration, not immediately replace it with Battle")
	if not reveals.is_empty():
		var shown: Array[String] = []
		for actor in reveals[0].get_children():
			if actor is Goblin:
				shown.append(actor.enemy_id())
		_check(not shown.is_empty(), "REVEAL-01: world reveal has no real enemy actors")
		# REVEAL-03: the same event arriving again may not stack content.
		diver.encounter_triggered.emit()
		await create_timer(0.65, true).timeout
		_check(world.battle == null and get_nodes_in_group("random_encounter_reveal").size() == 1,
			"REVEAL-03: duplicated event bypassed or stacked the reveal")
		_check(diver.global_position.is_equal_approx(position_before) and
			Vector3(diver.stats.hp, diver.stats.oxygen, world.active) == before and world.random_encounters_enabled,
			"REVEAL-03: reveal drifted player, drained stats or changed encounter preference")
		var deadline := Time.get_ticks_msec() + 1500
		var frame := 0
		while world.battle == null and Time.get_ticks_msec() < deadline:
			await create_timer(0.10, true).timeout
			if not output.is_empty():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("reveal-%02d.png" % frame))
				frame += 1
		_check(world.battle != null and get_nodes_in_group("random_encounter_reveal").is_empty(),
			"REVEAL-01: reveal failed to retire and hand off to combat")
		if world.battle != null:
			var actual: Array[String] = []
			for enemy in world.battle.enemies:
				actual.append(enemy.actor.enemy_id())
			_check(actual == shown, "REVEAL-02: displayed %s but fought %s" % [shown, actual])
			if not output.is_empty():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("combat.png"))
	_clear_battle()
	# REVEAL-06: normal preferences and prologue gating retain their priority.
	world.random_encounters_enabled = false
	diver.encounter_triggered.emit()
	await process_frame
	_check(world.battle == null and get_nodes_in_group("random_encounter_reveal").is_empty(), "REVEAL-06: encounters-Off starts a reveal")
	world.random_encounters_enabled = true
	world.route_state.prologue_complete = false
	diver.encounter_triggered.emit()
	await process_frame
	_check(world.battle == null and get_nodes_in_group("random_encounter_reveal").is_empty(), "REVEAL-06: unfinished prologue starts ordinary reveal")
	world.route_state.prologue_complete = true
	# REVEAL-05: retire through the real title and Load flow, not a timer mock.
	diver.encounter_triggered.emit()
	await process_frame
	world._show_title_screen()
	await create_timer(1.7, true).timeout
	_check(world.title_screen.visible and world.battle == null and get_nodes_in_group("random_encounter_reveal").is_empty(), "REVEAL-05: cancelled reveal starts combat behind title")
	world.title_screen.load_game_chosen.emit(918281)
	await process_frame
	await physics_frame
	_check(not world.title_screen.visible and not paused, "REVEAL-05: title Load fails to restore normal world")
	diver.encounter_triggered.emit()
	await process_frame
	world.title_screen.load_game_chosen.emit(918281)
	await create_timer(1.7, true).timeout
	_check(world.battle == null and not paused and get_nodes_in_group("random_encounter_reveal").is_empty(), "REVEAL-05: checkpoint Load leaves stale reveal callback")
	# REVEAL-05: teardown during the reveal must release its temporary pause
	# and cannot leave a callback capable of creating a ghost battle.
	diver.encounter_triggered.emit()
	await process_frame
	world.queue_free()
	await process_frame
	await create_timer(1.7, true).timeout
	_check(not paused and get_nodes_in_group("random_encounter_reveal").is_empty(), "REVEAL-05: scene teardown leaves reveal or its pause alive")
	for finding in findings:
		push_error(finding)
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	await process_frame
	print("RANDOM REVEAL: ", "PASS" if findings.is_empty() else "FAIL")
	quit(0 if findings.is_empty() else 1)

func _clear_battle() -> void:
	if world.battle != null:
		world.battle.free()
		world.battle = null
	world.battling = false
