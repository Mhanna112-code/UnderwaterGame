extends SceneTree

const SLOT := 918421
var findings: Array[String] = []
var owned := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, bug: String) -> void:
	if not ok:
		findings.append(bug)

func _run() -> void:
	for path in [SaveManager.slot_path(SLOT), SaveManager.autosave_path(SLOT)]:
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".pending") or DirAccess.dir_exists_absolute(path + ".pending"):
			print("Refusing existing disposable fixture: ", path)
			quit(1)
			return
	owned = true
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world._current_slot = SLOT
	world.random_encounters_enabled = false
	for frame in range(10):
		await physics_frame
	_expect(SaveManager.write_slot(SLOT, world._serialize_state()) == OK, "AUTO fixture manual write")
	var manual := FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT))
	world.inventory = {"potion": 7}
	world.battling = true
	world._autosave_timer = World.AUTOSAVE_INTERVAL
	world._tick_autosave(0.1)
	_expect(SaveManager.read_autosave(SLOT).is_empty(), "AUTO-1 unsafe battle saved")
	world.battling = false
	paused = true
	world._tick_autosave(0.1)
	_expect(SaveManager.read_autosave(SLOT).is_empty(), "AUTO-1 paused tree saved")
	paused = false
	world.inventory_menu.open()
	_expect(not world._autosave_safe(), "AUTO-1 menu considered safe")
	world.inventory_menu.close()
	world._tick_autosave(0.1)
	await process_frame
	_expect(not SaveManager.read_autosave(SLOT).is_empty(), "AUTO-1 safe due ticker did not write")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT)) == manual, "AUTO-1 autosave overwrote manual")
	var previous := FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT))
	var pending := SaveManager.autosave_path(SLOT) + ".pending"
	_expect(DirAccess.make_dir_recursive_absolute(pending) == OK, "AUTO failure fixture")
	world.inventory = {"potion": 99}
	world._autosave_timer = World.AUTOSAVE_INTERVAL
	world._tick_autosave(0.1)
	await process_frame
	_expect(FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT)) == previous, "AUTO-2 rejected write destroyed auto")
	DirAccess.remove_absolute(pending)
	world.queue_free()
	await process_frame
	var cold := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(cold)
	current_scene = cold
	await process_frame
	_expect(await cold._on_title_load_game(SLOT, true), "AUTO-2 autosave load failed")
	_expect(cold._current_slot == SLOT and int(cold.inventory.get("potion", 0)) == 7, "AUTO-2 selected auto loaded manual/wrong data")
	_expect(cold.route_state.prologue_complete and not paused, "AUTO-2 completed opener replayed")
	cold.divers[0].global_position = Vector3(263, 2, 16)
	for frame in range(18):
		await physics_frame
	var maze := cold.embedded_maze
	_expect(maze.maze_active, "AUTO maze fixture did not enter")
	maze.keys_held = 11
	maze._chest_reward_pending = true
	cold._autosave_timer = World.AUTOSAVE_INTERVAL
	cold._tick_autosave(0.1)
	_expect(FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT)) == previous, "AUTO-1 unstable maze reward saved")
	maze._chest_reward_pending = false
	cold._tick_autosave(0.1)
	await process_frame
	var maze_auto := SaveManager.read_autosave(SLOT)
	_expect(maze_auto.get("campaign_scene", "") == "maze", "AUTO-1 active maze saved as world")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT)) == manual, "AUTO-1 maze autosave replaced manual")
	previous = FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT))
	cold.queue_free()
	await process_frame
	var maze_load := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(maze_load)
	current_scene = maze_load
	await process_frame
	await maze_load._on_title_load_autosave(SLOT)
	_expect(maze_load.embedded_maze.maze_active and maze_load.embedded_maze.keys_held == 11 and maze_load._current_slot == SLOT,
		"AUTO-2 cold autosave loses embedded maze/keys/selected slot")
	maze_load.queue_free()
	await process_frame
	var fresh := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	fresh.skip_intro_for_test = true
	fresh.skip_tutorial_for_test = true
	root.add_child(fresh)
	current_scene = fresh
	await process_frame
	var denied := SaveManager.slot_path(SLOT) + ".pending"
	_expect(DirAccess.make_dir_recursive_absolute(denied) == OK, "AUTO New Game failure fixture")
	await fresh._on_title_new_game(SLOT)
	_expect(FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT)) == previous, "AUTO-2 rejected New Game deleted auto")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT)) == manual, "AUTO-2 rejected New Game destroyed manual")
	DirAccess.remove_absolute(denied)
	await fresh._on_title_new_game(SLOT)
	_expect(SaveManager.read_autosave(SLOT).is_empty(), "AUTO-2 confirmed New Game retained previous run auto")
	fresh.queue_free()
	await process_frame
	paused = false
	if owned:
		DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
		SaveManager.clear_autosave(SLOT)
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC AUTOSAVES: clean" if findings.is_empty() else "MARC AUTOSAVES: findings")
	quit(0 if findings.is_empty() else 1)
