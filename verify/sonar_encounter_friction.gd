extends SceneTree
## FR-1: real elapsed-time navigation must not exhaust the combat tank.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Engine callback test with controlled elapsed time: no frame-speed or
	# accelerated-tree assumptions, no mock stats/billing implementation.
	var diver := Diver.new()
	diver.stats = CombatantStats.new()
	diver.passive_id = "sonar"
	diver.toggle_sonar()
	for tick in 1200:
		diver._physics_process(0.1)
	var used := 100.0 - diver.stats.oxygen
	_expect(used >= 19.0 and used <= 21.0 and diver.sonar_active,
		"FR-1 two-minute Sonar navigation depleted %.1f Oxygen instead of about 20" % used)
	print("SONAR BUDGET|seconds=120|used=", used, "|active=", diver.sonar_active)
	diver.free()
	if findings.is_empty():
		_budget_cases()
	if findings.is_empty():
		await _world_site()
	if findings.is_empty():
		await _maze_site()
	if findings.is_empty():
		await _world_authored_variants()
	await _finish()

func _budget_cases() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 506020
	for sample in 48:
		var actor := Diver.new()
		actor.stats = CombatantStats.new()
		actor.passive_id = "sonar"
		actor.toggle_sonar()
		var remaining := 120.0
		while remaining > 0.0000001:
			var dt := minf(remaining, rng.randf_range(0.016, 2.5))
			actor._physics_process(dt)
			remaining -= dt
		_expect(actor.stats.oxygen >= 79.0 and actor.stats.oxygen <= 81.0,
			"FR-1 billing depends on elapsed frame partitions: " + str(actor.stats.oxygen))
		var before := actor.stats.oxygen
		actor.exploration_paused = true
		actor._physics_process(60.0)
		_expect(actor.stats.oxygen == before, "FR-4 paused exploration silently spends combat Oxygen")
		actor.exploration_paused = false
		actor.toggle_sonar()
		actor._physics_process(60.0)
		_expect(actor.stats.oxygen == before, "FR-4 Q-off still drains Oxygen")
		actor.stats.oxygen = 0.0
		_expect(not actor.toggle_sonar(), "FR-4 zero-Oxygen Sonar falsely enables")
		actor.stats.oxygen = 0.5
		actor.toggle_sonar()
		actor._physics_process(6.1)
		_expect(actor.stats.oxygen == 0.0 and not actor.sonar_active, "FR-4 depletion goes negative or leaves Sonar falsely on")
		actor.free()
	var original := Diver.new()
	original.stats = CombatantStats.new()
	original.passive_id = "sonar"
	original.toggle_sonar()
	original._physics_process(3.5)
	var session := CampaignSession.new()
	session.capture_party([original], 0)
	var restored := Diver.new()
	restored.passive_id = "sonar"
	session.restore_party([restored])
	_expect(restored.stats == original.stats, "FR-4 campaign Sonar handoff replaced the shared combat resource")
	restored._physics_process(2.4)
	_expect(restored.stats.oxygen == 100.0, "FR-4 handoff immediately charges a saved partial interval")
	restored._physics_process(0.2)
	_expect(restored.stats.oxygen == 99.0, "FR-4 handoff resets the saved interval or bills twice")
	original.free()
	restored.free()
	print("SONAR TIME PARTITIONS|generated=48|paused_off_zero=true|partial_interval_handoff=true")

func _world_site() -> void:
	var world := load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").visible = true
	paused = false

	world.player_first_special_encounter = false # Steady-state chooser fixture.
	world.special_encounter_left = true # Persist the supplied completed first-site lesson too.
	var onboarding := AbilityOnboarding.new()
	world.get_node("HUD").add_child(onboarding)
	onboarding.open_for_world(world)
	onboarding.advance_page()
	var page := onboarding.current_page_data()
	_expect(page.get("sonar_oxygen_per_tick") == 1 and page.get("sonar_tick_seconds") == 6
		and "1 O2 every 6 seconds" in String(page.body)
		and "guarded sites still work" in String(page.body), "FR-5 actual onboarding retains old drain/access rules")
	onboarding.dismiss()
	onboarding.queue_free()
	var actor := world.divers[0] as Diver
	actor.global_position = Vector3(-45, 2.6, 27)
	actor.velocity = Vector3.ZERO
	actor.sonar_active = false
	world.yaw = PI
	await _key(KEY_Q)
	await _settle(15)
	_expect(world.revealed_key_items.has("attack_up"), "FR-2 real Q failed to reveal the nearby reef destination")
	await _key(KEY_Q)
	await _key(KEY_R)
	_expect(not world.random_encounters_enabled and not actor.sonar_active, "FR-2 Q/R input did not establish quiet travel")
	actor.encounter_triggered.emit() # Guaranteed roll witness, not random luck.
	await _settle(3)
	_expect(world.battle == null and not world._transitioning_to_encounter,
		"FR-2 R-off still starts ordinary combat outside the site")
	var fixture := FileAccess.open("/tmp/sonar-friction-world-fixture.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify(world._serialize_state()))
	fixture.close()
	await _press(KEY_W, true)
	var deadline := Time.get_ticks_msec() + 8000
	while not world.special_encounter_prompt.visible and Time.get_ticks_msec() < deadline:
		await physics_frame
	await _press(KEY_W, false)
	_expect(world.special_encounter_prompt.visible and paused,
		"FR-2 actual swim into the red-dot site with Q/R off never opened the chooser: " + str(actor.global_position))
	if world.special_encounter_prompt.visible:
		world.special_encounter_prompt.cancelled.emit()
		await _settle(15)
		_expect(not world.special_encounter_prompt.visible and not paused,
			"FR-3 canceled R-off site loops without leaving its radius")
	print("FR WORLD|R=", world.random_encounters_enabled, "|Q=", actor.sonar_active, "|position=", actor.global_position)
	world.queue_free()
	await process_frame
	paused = false

func _maze_site() -> void:
	var maze := load("res://game/maze_level.tscn").instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	maze.room_encounters_enabled = false # No claim about strong-room combat.
	await _settle(8)
	var point := Vector3(64, maze._floor_top_y + 1.5, 52)
	var actor := maze.divers[0] as Diver
	actor.global_position = point + Vector3(0, 0, 6)
	actor.velocity = Vector3.ZERO
	actor.sonar_active = false
	maze._yaw = PI
	await _key(KEY_Q)
	await _settle(5)
	_expect(not maze.special_sites.points_of_interest().is_empty(), "FR-2 Maze Q failed to reveal a nearby special site")
	await _key(KEY_Q)
	await _key(KEY_R)
	_expect(not maze.random_encounters_enabled and not actor.sonar_active, "FR-2 Maze Q/R failed quiet-travel setup")
	await _press(KEY_W, true)
	var deadline := Time.get_ticks_msec() + 8000
	while not maze.special_sites.prompt.visible and Time.get_ticks_msec() < deadline:
		await physics_frame
	await _press(KEY_W, false)
	_expect(maze.special_sites.prompt.visible and paused,
		"FR-2 real Maze approach with Q/R off failed special chooser: " + str(actor.global_position))
	if maze.special_sites.prompt.visible:
		maze.special_sites.prompt.cancelled.emit()
		await _settle(12)
		_expect(not maze.special_sites.prompt.visible and not paused, "FR-3 Maze R-off cancel retriggers every frame")
	print("FR MAZE|R=", maze.random_encounters_enabled, "|Q=", actor.sonar_active, "|position=", actor.global_position)
	maze.queue_free()
	await process_frame
	paused = false

func _world_authored_variants() -> void:
	# Removing R's site gate must preserve the first special lesson and plain
	# guardian dispatch, not flatten every destination into a repeat chooser.
	for site_id in ["reef", "shallows"]:
		var world := load("res://game/world.tscn").instantiate() as World
		world.skip_intro_for_test = true
		world.skip_tutorial_for_test = true
		root.add_child(world)
		current_scene = world
		await process_frame
		world.title_screen.close()
		world.get_node("HUD").visible = true
		paused = false
		world.player_first_special_encounter = true
		world.random_encounters_enabled = false
		var site: Dictionary = Sites.by_id(site_id)
		var actor := world.divers[0] as Diver
		actor.global_position = (site.at as Vector3) + Vector3(0, 0, float(site.radius) + 2.5)
		actor.velocity = Vector3.ZERO
		actor.sonar_active = false
		world.yaw = PI
		await _press(KEY_W, true)
		var deadline := Time.get_ticks_msec() + 6000
		while world.battle == null and Time.get_ticks_msec() < deadline:
			await physics_frame
		await _press(KEY_W, false)
		_expect(world.battle != null, "FR-2 R-off lost authored first lesson/plain guardian: " + site_id)
		if world.battle != null:
			_expect(world.battle.reward_item_on_win == String(site.item), "FR-3 R-off authored reward changed: " + site_id)
			_expect(world.battle.special_encounter if site_id == "reef" else world.battle.guardian_encounter,
				"FR-3 authored dispatch no longer preserves its encounter type: " + site_id)
		world.queue_free()
		await process_frame
		paused = false
	print("FR WORLD VARIANTS|first_special_lesson_R_off=true|plain_guardian_R_off=true|reward_preserved=true")

func _press(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func _key(code: Key) -> void:
	await _press(code, true)
	await _press(code, false)

func _settle(frames: int) -> void:
	for frame in frames:
		await physics_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("SONAR ENCOUNTER FRICTION: clean" if findings.is_empty() else "SONAR ENCOUNTER FRICTION: failed")
	quit(0 if findings.is_empty() else 1)
