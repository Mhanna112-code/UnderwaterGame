extends SceneTree
## END-5: another run's checkpoint must not enable an ending's restart action.
## Completed/room fixtures isolate save ownership, NOT winning or balance.
const SLOT_A := 918441
const SLOT_B := 918442
var findings: Array[String] = []
var world: World
var owns_slots := false
var denied_auto_staging := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for slot in [SLOT_A, SLOT_B]:
		for path in [SaveManager.slot_path(slot), SaveManager.autosave_path(slot)]:
			if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".pending") or DirAccess.dir_exists_absolute(path + ".pending"):
				print("Refusing existing restart fixture: ", path)
				quit(1)
				return
	owns_slots = true
	world = load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world._current_slot = SLOT_A
	world.random_encounters_enabled = false
	world._set_maze_ownership(true)
	if "--denied" in OS.get_cmdline_user_args():
		await _denied_capture()
		await _finish()
		return
	await world._capture_pre_boss_autosave()
	var auto_a := FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT_A))
	_expect(not auto_a.is_empty(), "END-5 first owned checkpoint was not captured")
	var completed := world._serialize_state().duplicate(true)
	completed.route_state.octopus_state = "defeated"
	completed.campaign_checkpoint.maze.boss_triggers.erase("main_boss")
	_expect(SaveManager.write_slot(SLOT_B, completed) == OK, "END-5 completed-load fixture cannot be written")
	var manual_b := FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT_B))
	# Actual Return to Title reload, then the public chosen-slot Load signal.
	world._on_game_over_title()
	for frame in 15:
		await process_frame
	world = current_scene as World
	_expect(world != null and world.title_screen.visible, "END-5 actual return did not show title")
	world.title_screen.load_game_chosen.emit(SLOT_B)
	for frame in 20:
		await process_frame
	var screens := get_nodes_in_group("campaign_completion")
	_expect(screens.size() == 1, "END-5 completed slot did not show ending")
	if screens.size() == 1:
		var screen := screens[0] as CanvasLayer
		_expect(screen.restart_button.disabled and not "autosaved right before" in screen.status.text,
			"END-5 completed slot with no autosave offers another run's pre-boss restart")
	_expect(not FileAccess.file_exists(SaveManager.autosave_path(SLOT_B)), "END-5 loading another slot fabricated an autosave")
	_expect(auto_a == FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT_A)), "END-5 loading another run changed first slot bytes")
	_expect(manual_b == FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT_B)), "END-5 ending load rewrote completed fixture")
	if "--candidates" in OS.get_cmdline_user_args():
		var before_boss := JSON.parse_string(auto_a.get_string_from_utf8()) as Dictionary
		var cases := 0
		for area in ["world", "maze"]:
			for defeated in [false, true]:
				for station_present in [false, true]:
					var candidate := before_boss.duplicate(true)
					candidate.campaign_scene = area
					candidate.route_state.octopus_state = "defeated" if defeated else "available"
					if not station_present:
						candidate.campaign_checkpoint.maze.boss_triggers.erase("main_boss")
					_expect(SaveManager.write_autosave(SLOT_B, candidate) == OK, "END-7 owned candidate write failed")
					world._on_game_over_title()
					for frame in 15:
						await process_frame
					world = current_scene as World
					world.title_screen.load_game_chosen.emit(SLOT_B)
					for frame in 20:
						await process_frame
					var ending := get_nodes_in_group("campaign_completion")
					var expected_restart: bool = area == "maze" and not defeated and station_present
					_expect(ending.size() == 1 and (ending[0] as CanvasLayer).restart_button.disabled != expected_restart,
						"END-7 wrong pre-boss restart availability: %s defeated=%s station=%s" % [area, defeated, station_present])
					_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT_B)) == manual_b,
						"END-7 inspecting candidate rewrote completed manual bytes")
					cases += 1
		print("PRE-BOSS CANDIDATE MATRIX|generated_cases=", cases)
	await _finish()

func _denied_capture() -> void:
	_expect(SaveManager.write_autosave(SLOT_A, world._serialize_state()) == OK,
		"END-6 previous owned autosave cannot be written")
	var previous := FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT_A))
	var staging := SaveManager.autosave_path(SLOT_A) + ".pending"
	_expect(DirAccess.make_dir_recursive_absolute(staging) == OK, "END-6 denied autosave staging cannot be created")
	denied_auto_staging = true
	world.divers[0].stats.hp = 3
	await world._capture_pre_boss_autosave()
	# Declared completed fixture isolates the ending's save-status boundary.
	# It is not evidence of a legal combat win or earned journey.
	world.route_state.octopus_state = "defeated"
	world.embedded_maze.campaign_completed.emit()
	await process_frame
	var screens := get_nodes_in_group("campaign_completion")
	_expect(screens.size() == 1, "END-6 completed fixture did not show ending")
	if screens.size() == 1:
		var screen := screens[0] as CanvasLayer
		_expect(not screen.restart_button.disabled, "END-6 denied write loses available current-session restart")
		_expect(not "autosaved right before" in screen.status.text and "session" in screen.status.text.to_lower()
			and "failed" in screen.status.text.to_lower(), "END-6 denied pre-boss write falsely promises a saved restart")
	_expect(FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT_A)) == previous,
		"END-6 denied pre-boss write replaces previous checkpoint bytes")
	if screens.size() == 1:
		(screens[0] as CanvasLayer).restart_button.pressed.emit()
		for frame in 30:
			await process_frame
		world = current_scene as World
		_expect(world != null and not paused and world._current_slot == SLOT_A
			and world.divers[0].stats.hp == 3 and world.route_state.octopus_state != "defeated",
			"END-6 available session restart does not restore its unsaved pre-boss party")
		_expect(FileAccess.get_file_as_bytes(SaveManager.autosave_path(SLOT_A)) == previous,
			"END-6 session restart rewrites the last usable saved checkpoint")

func _finish() -> void:
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	if owns_slots:
		if denied_auto_staging:
			DirAccess.remove_absolute(SaveManager.autosave_path(SLOT_A) + ".pending")
		for slot in [SLOT_A, SLOT_B]:
			for path in [SaveManager.slot_path(slot), SaveManager.autosave_path(slot)]:
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(path)
	for finding in findings:
		print("FINDING ", finding)
	print("PRE-BOSS RESTART OWNERSHIP|findings=", findings.size(), "|two_owned_slots=true|not_balance=true")
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
