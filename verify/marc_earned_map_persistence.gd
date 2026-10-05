extends SceneTree
## EARN-2: earned map survives real checkpoint/cold Load and never funds doors.
## Chest/door/checkpoint positions are boundary fixtures, not traversal proof.
const SLOT := 918350
var findings: Array[String] = []
var owns_slot := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if SaveManager.slot_exists(SLOT) or FileAccess.file_exists(SaveManager.slot_path(SLOT) + ".pending") \
		or DirAccess.dir_exists_absolute(SaveManager.slot_path(SLOT) + ".pending"):
		findings.append("EARN-2 isolated slot already exists; refusing overwrite")
		await _finish()
		return
	owns_slot = true
	root.size = Vector2i(1280, 720)
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in 12:
		await physics_frame
	var chest := maze.get_node("MapChest") as Node3D
	maze._diver.global_position = chest.global_position + Vector3(0, 1.5, 1.8)
	for frame in 3:
		await physics_frame
	await _key(KEY_E)
	await create_timer(2.2).timeout
	var popup := root.get_node("CharacterAbilityPopup")
	_expect((popup.get_node("%AbilityExplanationPanel") as Control).visible, "EARN-2 actual map acquisition lacks popup")
	await _key(KEY_ESCAPE)
	_expect(maze.key_items.count("maze_nav_map") == 1, "EARN-2 real chest did not supply map fixture")
	maze.campaign_key_items.assign(["current_pearl"])
	# A real map-only party cannot open a keyed door. Then supply one legitimate
	# consumable maze key as the door-boundary fixture, not as map acquisition.
	var door := maze.get_node("MazeDoor16") as KeyDoor
	var box: CollisionShape3D
	for child in door.get_children():
		if child is CollisionShape3D:
			box = child
	if box == null:
		findings.append("EARN-2 door fixture lacks actual collision surface")
		await _finish()
		return
	var half := (box.shape as BoxShape3D).size * 0.5
	maze._diver.global_position = box.global_transform * Vector3(0, -half.y + 0.8, half.z + 0.7)
	for frame in 3:
		await physics_frame
	await _key(KEY_E)
	_expect(not door.is_open() and maze.keys_held == 0 and maze.key_items.has("maze_nav_map"),
		"EARN-2 navigation map is wrongly spendable as a door key")
	# Orange interaction caption has the game's existing E cooldown.
	await create_timer(4.2).timeout
	maze.keys_held = 1
	maze.key_items.append("vortex_key")
	await _key(KEY_E)
	await create_timer(1.5).timeout
	_expect(door.is_open() and maze.keys_held == 0 and maze.key_items.count("maze_nav_map") == 1
		and maze.campaign_key_items == ["current_pearl"], "EARN-2 real door E spends map/relic or fails to spend exactly one key")
	maze._diver.global_position = maze.get_node("MazeCheckpoint").global_position + Vector3.UP
	for frame in 6:
		await physics_frame
	await _key(KEY_P)
	_expect(maze._save_menu.visible, "EARN-2 P did not expose real save menu")
	maze._save_menu.save_requested.emit(maze._diver, SLOT)
	for frame in 6:
		await process_frame
	var saved := SaveManager.read_slot(SLOT)
	_expect(saved.get("campaign_scene") == "maze", "EARN-2 save lost campaign/maze identity")
	if not findings.is_empty():
		await _finish()
		return
	maze.queue_free()
	await process_frame
	var loaded := await _cold_load()
	if loaded != null:
		_expect(loaded.key_items.count("maze_nav_map") == 1 and loaded.keys_held == 0
			and loaded.campaign_key_items == ["current_pearl"], "EARN-2 cold Load loses map or splits spent-key/relic state")
		_expect((loaded.get_node("MazeDoor16") as KeyDoor).is_open(), "EARN-2 cold Load restores consumed key with closed door")
		_expect(loaded._map_chest_open and loaded._dome_levers.is_empty(), "EARN-2 cold Load closes earned chest or resurrects obsolete levers")
		await _key(KEY_L)
		_expect(loaded.get_node("HUD/MazeMiniMap").main_map.visible, "EARN-2 cold Load cannot use acquired map")
		await _key(KEY_ESCAPE) # First-open lesson; does not close the underlying map.
		await _key(KEY_L)
		loaded.world.queue_free()
		await process_frame
	# Explicit old-save migration: no map item, old lever references. New map
	# ownership has no required extra flag, so this must load, not index absent
	# lever nodes, and must not silently invent an earned map.
	(saved.campaign_checkpoint.maze.key_items as Array).erase("maze_nav_map")
	saved.campaign_checkpoint.maze.levers = [{"lever": 0, "diver": 0}, {"lever": 1, "diver": 1}]
	_expect(SaveManager.write_slot(SLOT, saved) == OK, "EARN-2 could not prepare owned old-save variant")
	loaded = await _cold_load()
	if loaded != null:
		await _key(KEY_L)
		_expect(not loaded.get_node("HUD/MazeMiniMap").main_map.visible and not loaded._map_chest_open
			and not loaded.key_items.has("maze_nav_map"), "EARN-2 legacy checkpoint fabricates map ownership/free L")
		_expect(loaded.route_state.prologue_complete and not paused, "EARN-2 legacy maze Load replays opening or stays paused")
	await _finish()

func _cold_load() -> MazeLevel:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.load_game_chosen.emit(SLOT)
	for frame in 20:
		await process_frame
		if world.embedded_maze.maze_active:
			break
	if current_scene != world or not world.embedded_maze.maze_active:
		findings.append("EARN-2 cold title Load did not restore maze")
		return null
	_expect(world._current_slot == SLOT, "EARN-2 cold Load changed selected disposable slot")
	return world.embedded_maze

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame

func _finish() -> void:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	if owns_slot and SaveManager.slot_exists(SLOT):
		_expect(DirAccess.remove_absolute(SaveManager.slot_path(SLOT)) == OK, "EARN-2 cannot remove only verifier-owned test slot")
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC EARNED MAP PERSISTENCE: clean" if findings.is_empty() else "MARC EARNED MAP PERSISTENCE: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
