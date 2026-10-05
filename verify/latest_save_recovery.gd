# SAVE-1: ordinary Load silently discards newer autosaved progress.
# Disposable slot only; real chosen-slot signal and recovery buttons/writers.
extends SceneTree

const SLOT := 918527
var findings: Array[String] = []

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
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	var checkpoint := world._serialize_state()
	checkpoint["inventory"] = {"potion": 1}
	_expect(SaveManager.write_slot(SLOT, checkpoint) == OK, "fixture manual write")
	checkpoint["inventory"] = {"potion": 7}
	_expect(SaveManager.write_autosave(SLOT, checkpoint) == OK, "fixture autosave write")
	# Exercise the title's default selection signal without touching player slots.
	world.title_screen.load_latest_chosen.emit(SLOT)
	await process_frame
	await process_frame
	_expect(int(world.inventory.get("potion", 0)) == 7, "SAVE-1 default Load restored older manual inventory instead of newer autosave")
	_expect(world.route_state.prologue_complete and world.opening_video == null and not paused, "SAVE-1 latest load replayed opening/froze world")
	SaveManager.clear_autosave(SLOT)
	_expect(await world._on_title_load_latest(SLOT) and int(world.inventory.get("potion", 0)) == 1, "SAVE-4 missing auto blocks manual load")
	SaveManager.write_autosave(SLOT, checkpoint)
	DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	_expect(await world._on_title_load_latest(SLOT) and int(world.inventory.get("potion", 0)) == 7, "SAVE-4 auto-only slot cannot load")
	# Legacy file times are the only persisted ordering evidence available.
	checkpoint["inventory"] = {"potion": 2}
	_fixture_write(SaveManager.slot_path(SLOT), checkpoint)
	await create_timer(2.1).timeout
	checkpoint["inventory"] = {"potion": 8}
	_fixture_write(SaveManager.autosave_path(SLOT), checkpoint)
	_expect(await world._on_title_load_latest(SLOT) and int(world.inventory.get("potion", 0)) == 8, "SAVE-3 legacy newer auto ignored")
	# SAVE-3: independent last-successful-write oracle over generated alternations.
	var rng := RandomNumberGenerator.new()
	rng.seed = 527
	for value in range(10, 34):
		checkpoint["inventory"] = {"potion": value}
		var automatic := rng.randi_range(0, 1) == 1
		var error := SaveManager.write_autosave(SLOT, checkpoint) if automatic else SaveManager.write_slot(SLOT, checkpoint)
		_expect(error == OK and not checkpoint.has("save_sequence"), "SAVE-3 writer failed or mutated caller snapshot")
		_expect(await world._on_title_load_latest(SLOT), "SAVE-3 ordered load failed")
		_expect(int(world.inventory.get("potion", 0)) == value, "SAVE-3 newer successful write lost")
	checkpoint["inventory"] = {"potion": 4}
	SaveManager.write_slot(SLOT, checkpoint)
	var manual := FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT))
	# SAVE-4: parsed-but-incompatible newer data must not poison valid fallback.
	for invalid in [{}, {"divers": "broken"}, {"divers": [{}, {}, {}], "active": 99}]:
		SaveManager.write_autosave(SLOT, invalid)
		_expect(await world._on_title_load_latest(SLOT) and int(world.inventory.get("potion", 0)) == 4, "SAVE-4 corrupt newer auto blocked valid manual")
		_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT)) == manual, "SAVE-4 load overwrote fallback checkpoint")
	checkpoint["inventory"] = {"potion": 9}
	SaveManager.write_autosave(SLOT, checkpoint)
	var auto_bytes := FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT))
	# SAVE-6: a rejected/rolled-back write cannot advance the restored ordering.
	checkpoint["inventory"] = {"potion": 99}
	SaveManager.write_slot(SLOT, checkpoint)
	SaveManager.rollback_slot(SLOT, true, manual)
	_expect(await world._on_title_load_latest(SLOT) and int(world.inventory.get("potion", 0)) == 9, "SAVE-6 rollback changed latest choice")
	_expect(FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT)) == auto_bytes, "SAVE-6 rollback changed other snapshot")
	var pending := SaveManager.slot_path(SLOT) + ".pending"
	DirAccess.make_dir_recursive_absolute(pending)
	_expect(SaveManager.write_slot(SLOT, checkpoint) != OK, "SAVE-6 pending-directory fault was not exercised")
	DirAccess.remove_absolute(pending)
	_expect(await world._on_title_load_latest(SLOT) and int(world.inventory.get("potion", 0)) == 9, "SAVE-6 failed write advanced newest snapshot")
	# SAVE-2: actual recovery UI button -> scene reload -> latest persisted data.
	world._show_game_over()
	for shape in [Vector2i(1280, 720), Vector2i(720, 360), Vector2i(360, 640)]:
		root.size = shape
		for frame in range(4):
			await process_frame
		var viewport := Rect2(Vector2.ZERO, Vector2(shape))
		for name in ["ContinueLatestSave", "RestartSavePoint"]:
			var button := world.game_over_screen.find_child(name, true, false) as Button
			_expect(viewport.encloses(button.get_global_rect()), "SAVE-5 recovery button clipped at " + str(shape))
	root.size = Vector2i(1280, 720)
	(world.game_over_screen.find_child("ContinueLatestSave", true, false) as Button).pressed.emit()
	await _wait_reload(world)
	world = current_scene as World
	_expect(world != null and int(world.inventory.get("potion", 0)) == 9 and not paused, "SAVE-2 world recovery ignored newer auto")
	# SAVE-5: safe manual checkpoint remains selectable even with newer auto.
	world._show_game_over()
	(world.game_over_screen.find_child("RestartSavePoint", true, false) as Button).pressed.emit()
	await _wait_reload(world)
	world = current_scene as World
	_expect(int(world.inventory.get("potion", 0)) == 4, "SAVE-5 explicit manual recovery loaded auto")
	world._enter_maze_scene(true)
	await process_frame
	var maze := world.embedded_maze
	maze.keys_held = 11
	checkpoint = world._serialize_state()
	SaveManager.write_autosave(SLOT, checkpoint)
	maze.keys_held = 0
	maze._show_campaign_game_over()
	(maze._game_over.find_child("ContinueLatestSave", true, false) as Button).pressed.emit()
	await _wait_reload(world)
	world = current_scene as World
	_expect(world.embedded_maze.maze_active and world.embedded_maze.keys_held == 11 and not paused, "SAVE-2 maze recovery lost newer autosaved keys/ownership")
	_expect(world.route_state.prologue_complete and world.opening_video == null, "SAVE-2 maze recovery replayed opener")
	# Both invalid: retain title/error, never invent a fresh run or change files.
	SaveManager.write_slot(SLOT, {"divers": "bad"})
	SaveManager.write_autosave(SLOT, {"divers": []})
	var invalid_manual := FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT))
	var invalid_auto := FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT))
	_expect(not await world._on_title_load_latest(SLOT), "SAVE-4 both-invalid load accepted")
	_expect(world.title_screen.visible and paused and world._current_slot == -1, "SAVE-4 both-invalid load has no actionable title")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT)) == invalid_manual and FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT)) == invalid_auto, "SAVE-4 failed load rewrote invalid evidence")
	world.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	SaveManager.clear_autosave(SLOT)
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("LATEST SAVE RECOVERY: clean" if findings.is_empty() else "LATEST SAVE RECOVERY: findings")
	quit(0 if findings.is_empty() else 1)

func _wait_reload(previous: World) -> void:
	for frame in range(60):
		await process_frame
		if current_scene is World and current_scene != previous and not paused:
			return

func _fixture_write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
