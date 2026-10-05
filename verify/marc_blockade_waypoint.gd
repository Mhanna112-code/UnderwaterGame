extends SceneTree
const SLOT := 918499
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if SaveManager.slot_exists(SLOT):
		print("FINDING FOLLOW-4 disposable slot already exists; refusing overwrite")
		quit(1)
		return
	var world := await _world()
	world.route_state.prologue_complete = false
	await _frames(3)
	var arrow := world.find_child("BlockadeWaypoint", true, false) as MeshInstance3D
	_expect(arrow == null or not arrow.visible, "FOLLOW-3 waypoint appears before recovery")
	world.route_state.prologue_complete = true
	world.route_state.tutorial_complete = false
	world.route_state.set_prologue_phase("complete")
	await _frames(3)
	arrow = world.find_child("BlockadeWaypoint", true, false) as MeshInstance3D
	if arrow == null:
		findings.append("FOLLOW-3 completed recovery has no visible blockade waypoint")
		await _finish(world)
		return
	var wall := world._cracked_walls["entrance_blockade"] as CrackedWall
	var rng := RandomNumberGenerator.new()
	rng.seed = 72103
	for sample in 12:
		var diver := world.divers[world.active] as Diver
		diver.global_position = Vector3(rng.randf_range(-12, 5), 2, rng.randf_range(16, 24))
		diver.velocity = Vector3.ZERO
		await _frames(3)
		_expect(arrow.is_visible_in_tree() and arrow.get_parent() == diver, "FOLLOW-3 waypoint no longer follows active diver")
		var target_direction := (wall.global_position - arrow.global_position).normalized()
		_expect((-arrow.global_basis.z).normalized().dot(target_direction) > 0.999,
			"FOLLOW-3 waypoint points somewhere other than physical blockade")
		await _tap(KEY_TAB)
	(world.divers[world.active] as Diver).global_position = wall.global_position - Vector3(4, 0, 0)
	await _frames(3)
	_expect(not arrow.visible, "FOLLOW-4 waypoint stays visible within 6 metres")
	# This approach also enters the real recovery pad. Dismiss its first-use
	# lesson with normal input; a paused lesson is not resumed exploration.
	if paused:
		await _tap(KEY_ESCAPE)
	(world.divers[world.active] as Diver).global_position = Vector3(0, 2, 20)
	await _frames(3)
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _frames(100)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/marc-blockade-waypoint-%dx%d.png" % [root.size.x, root.size.y])
	world._start_battle()
	await _frames(3)
	_expect(not arrow.visible, "FOLLOW-4 waypoint leaks over actual battle")
	# Use Battle's production result signal, not partial test-only cleanup.
	world.battle.finished.emit("fled")
	await _frames(3)
	_expect(arrow.visible, "FOLLOW-4 waypoint fails to return after battle: paused=%s position=%s title=%s hud=%s" % [paused, (world.divers[world.active] as Diver).global_position, world.title_screen.visible, world.get_node("HUD").visible])
	world._enter_maze_scene(true)
	await _frames(3)
	_expect(not arrow.visible, "FOLLOW-4 waypoint points back through active maze")
	world._set_maze_ownership(false)
	for i in world.divers.size():
		(world.divers[i] as Diver).global_position = Vector3(-3 + i * 3, 2, 20)
	await _frames(3)
	# Actual Tab/F selects Bucky and breaks the real authored target.
	while world.active != 2:
		await _tap(KEY_TAB)
	(world.divers[2] as Diver).global_position = wall.global_position - Vector3(2, 0, 0)
	await _frames(3)
	await _tap(KEY_F)
	await _frames(5)
	_expect(world.consumed_world_ids.has("entrance_blockade"), "FOLLOW-4 actual Bucky F did not consume blockade")
	_expect(world.find_child("BlockadeWaypoint", true, false) == null, "FOLLOW-4 waypoint survives actual target break")
	var checkpoint := world._serialize_state()
	_expect(SaveManager.write_slot(SLOT, checkpoint) == OK, "FOLLOW-4 disposable completed save failed")
	world.queue_free()
	await process_frame
	world = await _world()
	world.title_screen.load_game_chosen.emit(SLOT)
	await _frames(8)
	_expect(world.route_state.prologue_complete and world.consumed_world_ids.has("entrance_blockade"), "FOLLOW-4 cold Load lost completed/broken checkpoint")
	_expect(world.find_child("BlockadeWaypoint", true, false) == null, "FOLLOW-4 cold Load resurrects consumed waypoint")
	await _finish(world)

func _world() -> World:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").visible = true
	paused = false
	world.random_encounters_enabled = false
	return world

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _tap(key: Key) -> void:
	var input := InputEventKey.new()
	input.keycode = key
	input.pressed = true
	Input.parse_input_event(input)
	await _frames(2)
	input = InputEventKey.new()
	input.keycode = key
	Input.parse_input_event(input)
	await _frames(2)

func _expect(ok: bool, description: String) -> void:
	if not ok:
		findings.append(description)

func _finish(world: World) -> void:
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	if SaveManager.slot_exists(SLOT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)))
	for finding in findings:
		print("FINDING ", finding)
	print("MARC BLOCKADE WAYPOINT: clean" if findings.is_empty() else "MARC BLOCKADE WAYPOINT: findings=%d" % findings.size())
	quit(0 if findings.is_empty() else 1)
