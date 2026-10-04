# OPEN-043/044/045: local guidance must follow physical zone/contact,
# not a sticky saved objective or another diver's position.
extends SceneTree
const SLOT := 918311
var findings: Array[String] = []
var world: World

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if SaveManager.slot_exists(SLOT):
		push_error("Owned local-guidance slot already exists; refusing overwrite")
		quit(1)
		return
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var fixture := world._serialize_state()
	fixture.route_state = {"opening_video_seen": true, "prologue_complete": true, "tutorial_complete": true, "objective_id": "find_lab", "zone_id": "deep", "deep_warning_seen": true}
	fixture.divers[0].position = [60.8, 2, 30]
	fixture.random_encounters_enabled = false # isolate spatial guidance
	fixture.save_point_tutorial_seen = true # prior onboarding, no review popup
	SaveManager.write_slot(SLOT, fixture)
	world.title_screen.load_game_chosen.emit(SLOT)
	await process_frame
	await process_frame
	_expect(world.route_objective_panel.visible and "laboratory" in world.route_objective_label.text.to_lower(), "OPEN-043 Deep Load has no visible lab instruction")
	await _capture("deep")
	# Camera default W goes +Z, so face west before W; real S returns east.
	world.yaw = -PI * 0.5
	await _hold(KEY_W, 0.6)
	_expect((world.divers[0] as Diver).position.x < 60.0, "OPEN-043 fixture did not swim into Shallows")
	_expect_shallows("SHALLOW-002 leaving Deep must replace lab text with Shallows purpose")
	await _capture("shallows")
	_expect(world.route_state.objective_id == "find_lab", "OPEN-043 leaving Deep erases pending lab progression")
	await _hold(KEY_S, 1.2)
	_expect((world.divers[0] as Diver).position.x >= 60.0, "OPEN-043 fixture did not swim back into Deep")
	_expect(world.route_objective_panel.visible, "OPEN-043 re-entering Deep with same objective fails to restore text")
	# OPEN-044 can be enabled separately after OPEN-043's first red is fixed.
	if OS.get_cmdline_user_args().has("--puzzle"):
		await _spatial_cases()
		await _puzzle()
	await _finish()

func _puzzle() -> void:
	world.yaw = PI * 0.5
	(world.divers[0] as Diver).position = Vector3(11.4, 2.0, 10.0)
	await _hold(KEY_W, 0.55)
	_expect(world.route_objective_panel.visible and "bucky" in world.route_objective_label.text.to_lower() and "wall" in world.route_objective_label.text.to_lower(), "OPEN-044 touching puzzle entrance has no short Bucky/wall instruction")
	_expect("(TAB)" in world.route_objective_label.text, "OPEN-049 Bucky/wall hint omits parenthesized TAB switching key")
	await _capture("puzzle")
	# Leave without breaking it, then return; the hint is proximity, not a latch.
	await _hold(KEY_S, 1.2)
	_expect((world.divers[world.active] as Diver).position.x < 12.0, "OPEN-044 fixture did not leave puzzle proximity")
	_expect_shallows("SHALLOW-003 leaving puzzle must restore Shallows purpose")
	await _hold(KEY_W, 1.2)
	_expect(world.route_objective_panel.visible, "OPEN-044 puzzle hint fails to return before wall is broken")
	(world.divers[2] as Diver).position = Vector3(14.2, 2.0, 10.0)
	await _tap(KEY_TAB)
	await _tap(KEY_TAB)
	await _tap(KEY_E) # real Bucky Shockwave; no injected broken signal
	await create_timer(0.4).timeout
	_expect(world.consumed_world_ids.has("entrance_blockade"), "OPEN-044 real Bucky Shockwave did not break entrance")
	_expect_shallows("SHALLOW-003 successful Shockwave must retire wall hint in favor of Shallows purpose")
	await _capture("broken")
	world.save_point_menu.save_requested.emit(world.divers[world.active], SLOT)
	world.title_screen.load_game_chosen.emit(SLOT)
	await process_frame
	await process_frame
	_expect_shallows("SHALLOW-003 Load must preserve Shallows purpose instead of resurrecting consumed-wall hint")

func _spatial_cases() -> void:
	var diver := world.divers[0] as Diver
	# Independent concrete oracle at visible contact points and unrelated water.
	for case in [
		[Vector3(14, 2, 10), true], [Vector3(20, 2, 5), true],
		[Vector3(20, 2, 15), true], [Vector3(14, 20, 10), false],
		[Vector3(20, 2, 22), false], [Vector3(50, 2, 10), false],
	]:
		diver.position = case[0]
		diver.velocity = Vector3.ZERO
		await physics_frame
		await process_frame
		if case[1]:
			_expect(world.route_objective_panel.visible and "wall" in world.route_objective_label.text.to_lower(), "OPEN-045 room contact lacks wall guidance at %s" % diver.position)
		else:
			_expect_shallows("SHALLOW-003 altitude/unrelated water must show Shallows purpose at %s" % diver.position)
	# Bounded position property: arbitrary clear-water Shallows points must
	# never show the retained lab objective or room instruction.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9045
	for _i in range(24):
		diver.position = Vector3(rng.randf_range(30, 58), rng.randf_range(10, 24), rng.randf_range(-50, -20))
		diver.velocity = Vector3.ZERO
		await physics_frame
		await process_frame
		_expect_shallows("SHALLOW-002/003 clear Shallows water must show zone/purpose, not lab/puzzle")
	# Proximity of an inactive diver must not guide the selected one.
	diver.position = Vector3(14, 2, 10)
	await physics_frame
	await process_frame
	await _tap(KEY_TAB)
	_expect_shallows("SHALLOW-003 inactive diver must not replace selected diver's Shallows purpose with wall hint")
	await _tap(KEY_TAB)
	await _tap(KEY_TAB)
	# Load a valid unfinished checkpoint through the public path, rather than
	# mutating a milestone in a completed running session without its handoff.
	var completed := world._serialize_state()
	var unfinished := completed.duplicate(true)
	unfinished.route_state.prologue_complete = false
	unfinished.route_state.tutorial_complete = false
	unfinished.route_state.objective_id = ""
	SaveManager.write_slot(SLOT, unfinished)
	world.title_screen.load_game_chosen.emit(SLOT)
	await process_frame
	await process_frame
	_expect(not world.route_objective_panel.visible, "OPEN-045 room hint interrupts unfinished opener")
	SaveManager.write_slot(SLOT, completed)
	world.title_screen.load_game_chosen.emit(SLOT)
	await process_frame
	await process_frame

func _capture(view: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	var saved_yaw := world.yaw
	if view == "puzzle" or view == "broken":
		# Look diagonally through the entrance so the existing save crystal
		# immediately behind the diver does not occlude the scene.
		world.yaw = 2.1
	await create_timer(0.5).timeout
	await process_frame
	if world.route_objective_panel.visible:
		_expect(root.get_visible_rect().encloses(world.route_objective_panel.get_global_rect()), "OPEN-045 visible hint is clipped")
	root.get_texture().get_image().save_png("/tmp/local-guidance-%s.png" % view)
	world.yaw = saved_yaw

func _hold(code: Key, seconds: float) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(seconds).timeout
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _tap(code: Key) -> void:
	await _hold(code, 0.05)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _expect_shallows(message: String) -> void:
	var text := world.route_objective_label.text.to_lower()
	_expect(world.route_objective_panel.visible and "shallows" in text and "stronger" in text and not "laboratory" in text and not "wall" in text, message + ": " + text)

func _finish() -> void:
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
	print("LOCAL WORLD GUIDANCE: clean" if findings.is_empty() else "LOCAL WORLD GUIDANCE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
