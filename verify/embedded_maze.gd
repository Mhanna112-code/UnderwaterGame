extends SceneTree
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://game/world.tscn").instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	var maze: MazeLevel
	for child in world.get_children():
		if child is MazeLevel:
			maze = child
	if maze == null:
		# Measure the real authored footprint for the connecting geometry. This
		# diagnostic is not an entry shortcut or a substitute for the assertion.
		var standalone := load("res://game/maze_level.tscn").instantiate() as MazeLevel
		root.add_child(standalone)
		var points: Array[Vector3] = standalone._collect_bounds_points()
		var low := points[0]
		var high := low
		for point in points:
			low = low.min(point)
			high = high.max(point)
		print("LAYOUT_MEASURE|low=", low, "|high=", high,
			"|entry=", standalone.get_node("DiverEntry").global_position,
			"|floor=", standalone._floor_top_y)
		standalone.queue_free()
		push_error("EMBED-1: normal World has no embedded maze; entry still replaces the scene/party")
		quit(1)
		return
	var actors := world.divers.duplicate()
	for i in range(3):
		_expect(maze.divers[i] == actors[i] and actors[i].get_parent() == world,
			"EMBED-1 maze created a replacement actor")
		_expect(actors[i].global_position.is_equal_approx(World.CAST[i].at),
			"EMBED-1 constructing inactive maze moved the World spawn")
	_expect(root.get_viewport().get_camera_3d() == world.cam,
		"EMBED-1 cold launch maze stole the World camera")
	_expect(not (maze.get_node("HUD") as CanvasLayer).visible,
		"EMBED-1 inactive maze shows its HUD over the title")
	_expect(world.route_state.octopus_state == "unavailable",
		"EMBED-1 constructing inactive maze advances the opening/boss milestone")
	print("EMBED_LAYOUT|bounds=", maze.embedded_bounds, "|entry=", maze.entrance_point())
	if not findings.is_empty():
		_finish()
		return
	print("PASS|EMBED-1 shared actors, unchanged spawn, title camera/HUD ownership")
	world.title_screen.close()
	world.route_state.prologue_complete = true
	world.route_state.opening_video_seen = true
	world.route_state.deep_warning_seen = true
	world.route_state.set_zone("deep")
	world.random_encounters_enabled = false
	world._intro_active = false
	world.yaw = PI
	world._camera_look_override = null
	world.get_node("HUD").visible = true
	paused = false
	for actor in actors:
		actor.sonar_active = false
		actor.global_position = Vector3(220, 1.8, 16)
		actor.velocity = Vector3.ZERO
	var stats: CombatantStats = actors[0].stats
	stats.hp = 7
	stats.oxygen = 13.25
	world.inventory["potion"] = 2
	await _swim_to(actors[0], 263.0, KEY_D)
	_expect(current_scene == world and maze.maze_active,
		"EMBED-4 lab-side ramp did not lead physically into the embedded maze")
	_expect(world.route_state.lab_state == "locked", "EMBED-4 ramp incorrectly requires lab victory")
	_expect(root.get_viewport().get_camera_3d() == maze.get_node("Camera3D")
		and world.get_node("HUD").visible and maze.get_node("HUD").visible
		and not world.hud.is_visible_in_tree()
		and not world.route_objective_panel.is_visible_in_tree()
		and world.hp_bar.is_visible_in_tree(),
		"EMBED-1 entry has competing camera/HUD owners")
	_expect(actors[0].stats == stats and stats.hp == 7 and is_equal_approx(stats.oxygen, 13.25)
		and world.inventory["potion"] == 2 and maze.inventory == world.inventory,
		"EMBED-1 entering ramp replaced/refilled party or inventory")
	await _swim_to(actors[0], 225.0, KEY_A)
	_expect(not maze.maze_active and current_scene == world and root.get_viewport().get_camera_3d() == world.cam,
		"EMBED-4 ramp return strands the player or replaces the scene")
	_expect(world.get_node("HUD").visible and not maze.get_node("HUD").visible,
		"EMBED-1 departure leaves wrong HUD active")
	for i in range(3):
		_expect(world.divers[i] == actors[i], "EMBED-1 physical round trip replaced party nodes")
	print("EMBED_TRAVERSAL|lab_first_requirement=false|outbound_x=263|return_x=225|no_save_writes")
	if not findings.is_empty():
		_finish()
		return
	# EMBED-2: real key input must select once, never in both owners. Park
	# the other actors in the maze only after the real ramp traversal above.
	for actor in actors:
		actor.global_position = Vector3(263, 1.8, 16)
		actor.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await _key(KEY_TAB)
	print("EMBED_TAB|world=", world.active, "|maze=", maze.active, "|owner=", maze.maze_active)
	_expect(world.active == 1 and maze.active == 1 and maze.maze_active,
		"EMBED-2 Tab selected twice or the World still owned maze input")
	await _key(KEY_R)
	_expect(world.random_encounters_enabled and maze.random_encounters_enabled,
		"EMBED-2 maze encounter preference diverges from the World save owner")
	_expect(world._serialize_state().random_encounters_enabled,
		"EMBED-2 saving in maze loses the last R choice")
	# Maze movement rolls ordinary random fights (R on): the maze owns them,
	# never the inactive World.
	actors[1].encounter_triggered.emit()
	await process_frame
	_expect(not world.battling and maze._battling and maze._battle_kind == "random",
		"EMBED-2 maze random fight missing or started by the inactive World")
	if maze._battling and maze._battle != null:
		maze._battle.finished.emit("fled")
		for frame in range(4):
			await process_frame
	# Random fights now roll anywhere in the maze; keep the movement checks below deterministic.
	world.random_encounters_enabled = false
	maze.random_encounters_enabled = false
	# Switch to a World-parked member via real Tab, then leave Maxilani's
	# Sonar active in the inactive maze. Its resource timer must not run there.
	actors[2].global_position = Vector3(220, 1.8, 16)
	await _key(KEY_TAB)
	await physics_frame
	await physics_frame
	_expect(not maze.maze_active and world.active == 2, "EMBED-2 changing area by party selection retains old owner")
	actors[0].sonar_active = true
	actors[0]._sonar_drain_timer = 0.01
	var oxygen_before: float = actors[0].stats.oxygen
	for frame in range(8):
		await physics_frame
	_expect(is_equal_approx(actors[0].stats.oxygen, oxygen_before),
		"EMBED-2 inactive maze actor still spends Sonar Oxygen")
	maze._start_battle("main_boss")
	_expect(not maze._battling, "EMBED-2 inactive maze accepts an encounter")
	print("EMBED_INPUT|Tab_once=true|R_save_conserved=true|inactive_encounters=false|inactive_Oxygen_drain=false")
	if not findings.is_empty():
		_finish()
		return
	# EMBED-4: floating through the opening alone would miss a floor step.
	# Hold sink against both slopes with the real capsule, down and back up.
	actors[2].global_position = Vector3(229, 0.1, 16)
	actors[2].velocity = Vector3.ZERO
	var sink := InputEventKey.new()
	sink.keycode = KEY_SHIFT
	sink.pressed = true
	Input.parse_input_event(sink)
	for frame in range(20):
		await physics_frame
	await _swim_to(actors[2], 262.0, KEY_D)
	_expect(actors[2].global_position.y >= maze._floor_top_y - 0.1
		and actors[2].global_position.y < 0.1, "EMBED-4 descending ramp has a hole or floating obstruction")
	await _swim_to(actors[2], 225.0, KEY_A)
	_expect(actors[2].global_position.y >= -0.1, "EMBED-4 floor seam stops an uphill return")
	sink = InputEventKey.new()
	sink.keycode = KEY_SHIFT
	Input.parse_input_event(sink)
	print("EMBED_FLOOR|sink-held descent and uphill return physically traversed")
	# AIM-2: the shared Musashi must not remain invisible when first-person
	# swimming crosses the ramp boundary and World resumes its ownership.
	actors[0].sonar_active = false
	actors[0].global_position = Vector3(220, 1.8, 16)
	actors[1].global_position = Vector3(263, 1.8, 16)
	actors[1].velocity = Vector3.ZERO
	await _key(KEY_TAB)
	for frame in 3:
		await physics_frame
	await _key(KEY_TAB)
	for frame in 3:
		await physics_frame
	print("EMBED_AIM_SELECTED|world=", world.active, "|maze=", maze.active, "|owner=", maze.maze_active,
		"|world_battle=", world.battling, "|maze_battle=", maze._battling, "|paused=", paused)
	_expect(world.active == 1 and maze.maze_active, "AIM-2 actual Tab did not select shared maze Musashi")
	await _key(KEY_F)
	_expect(not actors[1].model.visible and actors[1].get_parent() == world, "AIM-2 embedded F did not hide only the shared model")
	await _swim_to(actors[1], 225.0, KEY_A)
	_expect(not maze.maze_active and not maze.aiming and actors[1].model.visible
		and world.divers[1] == actors[1] and actors[1].get_parent() == world,
		"AIM-2 actual first-person ramp departure leaves invisible/replaced shared actor")
	print("EMBED_AIM_HANDOFF|actual_ramp_swim=true|same_actor=true|model_restored=true")
	_finish()

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = code
	Input.parse_input_event(release)
	await process_frame
	await physics_frame

func _swim_to(actor: Diver, target_x: float, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	var previous_x := actor.global_position.x
	var crossing_step := 0.0
	for frame in range(600):
		await physics_frame
		var next_x := actor.global_position.x
		if previous_x >= 255.0 and previous_x <= 258.0:
			crossing_step = maxf(crossing_step, absf(next_x - previous_x))
		previous_x = next_x
		if (keycode == KEY_D and actor.global_position.x >= target_x) or (keycode == KEY_A and actor.global_position.x <= target_x):
			break
	event.pressed = false
	Input.parse_input_event(event)
	await physics_frame
	print("EMBED_SWIM|key=", keycode, "|end=", actor.global_position, "|target=", target_x)
	print("EMBED_FRAME_STEP|crossing_max=", crossing_step)
	_expect(crossing_step <= actor.speed / Engine.physics_ticks_per_second * 1.25,
		"EMBED-2 both areas swim the actor in the entry frame")
	_expect(absf(actor.global_position.x - target_x) < 0.5, "EMBED-4 actual key movement blocked on ramp/perimeter")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
		push_error(message)

func _finish() -> void:
	print("EMBEDDED MAZE: clean" if findings.is_empty() else "EMBEDDED MAZE: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
