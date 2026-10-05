extends SceneTree
# SAVE-1: public request while a real hazard owns the actor must preserve bytes.
const SOURCE := 918422
const TARGET := 918423
var findings: Array[String] = []
var owns_files := false
var world: World

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for slot in [SOURCE, TARGET]:
		var path := SaveManager.slot_path(slot)
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".pending") or DirAccess.dir_exists_absolute(path + ".pending"):
			print("Refusing existing manual-save fixture: ", path)
			quit(1)
			return
	owns_files = true
	world = load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").show()
	paused = false
	world.random_encounters_enabled = false
	world._current_slot = SOURCE
	if "--reading" in OS.get_cmdline_user_args():
		await _reading()
		await _finish()
		return
	var actor := world.divers[0] as Diver
	actor.global_position = Vector3(228.8, 2, 16)
	actor.velocity = Vector3.ZERO
	actor.sonar_active = false
	for frame in 5:
		await physics_frame
	_expect(SaveManager.write_slot(SOURCE, world._serialize_state()) == OK, "SAVE-1 source fixture failed")
	_expect(SaveManager.write_slot(TARGET, world._serialize_state()) == OK, "SAVE-1 target fixture failed")
	var source_bytes := FileAccess.get_file_as_bytes(SaveManager.slot_path(SOURCE))
	var target_bytes := FileAccess.get_file_as_bytes(SaveManager.slot_path(TARGET))
	var whirl := Whirlpool.new()
	whirl.position = actor.global_position
	whirl.reset_to = Vector3(226, 2, 16)
	whirl.suction_radius = 0.9
	whirl.warning_radius = 3.0
	whirl.pull_duration = 1.0
	whirl.vanish_duration = 0.5
	world.add_child(whirl)
	for frame in 6:
		await physics_frame
		await process_frame
	_expect(actor.is_suction_locked(), "SAVE-1 actual overlap did not acquire actor")
	world.save_point_menu.open_for(actor)
	world.save_point_menu.save_requested.emit(actor, TARGET)
	await process_frame
	_expect(world._current_slot == SOURCE, "SAVE-1 unstable request switches selected slot")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(TARGET)) == target_bytes,
		"SAVE-1 caught actor overwrites the usable target checkpoint")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SOURCE)) == source_bytes,
		"SAVE-1 rejected request overwrites source checkpoint")
	# Preserve the message queue contract: a regional notice already being
	# read must finish before the save rejection, rather than being erased.
	var notice_deadline := Time.get_ticks_msec() + 6500
	while not "Wait" in world.banner.text and Time.get_ticks_msec() < notice_deadline:
		await physics_frame
		await process_frame
	_expect("Wait" in world.banner.text and not "Progress saved" in world.banner.text,
		"SAVE-1 unstable checkpoint has no actionable wait explanation")
	print("WORLD_MANUAL_SAVE|caught=true|selected=", world._current_slot,
		"|target_unchanged=", FileAccess.get_file_as_bytes(SaveManager.slot_path(TARGET)) == target_bytes,
		"|notice=", world.banner.text)
	if not findings.is_empty():
		await _finish()
		return
	whirl.queue_free()
	for frame in 10:
		await physics_frame
	world.inventory = {"potion": 7}
	print("SAVE_STABILITY_OBSERVER|maze_stable=", world.embedded_maze.can_capture_campaign_snapshot(),
		"|maze_active=", world.embedded_maze.maze_active, "|paused=", paused,
		"|locks=", world.divers.map(func(d: Diver) -> bool: return d.is_suction_locked()),
		"|grapples=", world.divers.map(func(d: Diver) -> bool: return d.is_grappling()),
		"|whirl_busy=", Whirlpool.busy_in(world), "|intro=", world._intro_active,
		"|title=", world.title_screen.visible, "|special=", world.special_encounter_prompt.visible,
		"|popup=", world.tutorial_result_popup.visible)
	world.save_point_menu.open_for(actor)
	world.save_point_menu.save_requested.emit(actor, TARGET)
	await process_frame
	_expect(world._current_slot == TARGET and int(SaveManager.read_slot(TARGET).inventory.get("potion", 0)) == 7,
		"SAVE-1 stable retry cannot save the actual current inventory/selected slot")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SOURCE)) == source_bytes,
		"SAVE-1 successful cross-slot retry overwrites the source")
	var stable_target := FileAccess.get_file_as_bytes(SaveManager.slot_path(TARGET))
	var pending := SaveManager.slot_path(SOURCE) + ".pending"
	_expect(DirAccess.make_dir_recursive_absolute(pending) == OK, "SAVE-2 cannot create denied staging fixture")
	world.save_point_menu.open_for(actor)
	world.save_point_menu.save_requested.emit(actor, SOURCE)
	await process_frame
	_expect(world._current_slot == TARGET and FileAccess.get_file_as_bytes(SaveManager.slot_path(SOURCE)) == source_bytes
		and FileAccess.get_file_as_bytes(SaveManager.slot_path(TARGET)) == stable_target,
		"SAVE-2 actual denied staging IO loses selected slot or exact previous bytes")
	DirAccess.remove_absolute(pending)
	world.save_point_menu.open_for(actor)
	world.save_point_menu.save_requested.emit(actor, SOURCE)
	await process_frame
	_expect(world._current_slot == SOURCE and int(SaveManager.read_slot(SOURCE).inventory.get("potion", 0)) == 7,
		"SAVE-2 permission retry does not save current progress")
	print("WORLD_MANUAL_SAVE|stable_retry=true|denied_staging=true|source_preserved=true|permission_retry=true")
	await _finish()

func _reading() -> void:
	var actor := world.divers[0] as Diver
	var point := world._save_points[0] as SavePoint
	world._save_point_tutorial_seen = true
	world.yaw = 0.0
	actor.global_position = point.global_position
	actor.velocity = Vector3.ZERO
	for frame in 8:
		await physics_frame
	_expect(point.has_diver(actor), "SAVE-3 fixture has no actual authored save-point contact")
	_key(KEY_P, true)
	await process_frame
	_key(KEY_P, false)
	await process_frame
	_expect(world.save_point_menu.visible, "SAVE-3 actual P did not open reading")
	var at := actor.global_position
	var before_oxygen := actor.stats.oxygen
	actor.sonar_active = true
	_key(KEY_W, true)
	for frame in 240:
		await physics_frame
		await process_frame
	_key(KEY_W, false)
	_expect(actor.global_position.distance_to(at) < 0.02, "SAVE-3 held W swims behind Save reading")
	_expect(actor.stats.oxygen == before_oxygen, "SAVE-3 Sonar bills Oxygen behind Save reading")
	_key(KEY_P, true)
	await process_frame
	_key(KEY_P, false)
	await process_frame
	_key(KEY_W, true)
	for frame in 35:
		await physics_frame
		await process_frame
	_key(KEY_W, false)
	_expect(not world.save_point_menu.visible and actor.global_position.distance_to(at) > 0.5,
		"SAVE-3 closing Save reading does not restore real swimming")
	print("WORLD_SAVE_READING|actual_P_and_W=true|no_files_written=true|resumed_swim=true")

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _expect(ok: bool, bug: String) -> void:
	if not ok:
		findings.append(bug)

func _finish() -> void:
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	paused = false
	if owns_files:
		for slot in [SOURCE, TARGET]:
			for path in [SaveManager.slot_path(slot), SaveManager.slot_path(slot) + ".pending"]:
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(path)
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("WORLD MANUAL SAVE: clean" if findings.is_empty() else "WORLD MANUAL SAVE: findings")
	quit(0 if findings.is_empty() else 1)
