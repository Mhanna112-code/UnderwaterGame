# OPEN-030: failed cross-slot save must not select an older incomplete opening.
extends SceneTree

const SOURCE := 918306
const TARGET := 918307
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for slot in [SOURCE, TARGET]:
		if SaveManager.slot_exists(slot) or FileAccess.file_exists(SaveManager.slot_path(slot) + ".pending"):
			findings.append("OPEN-030 owned fixture exists; refusing overwrite")
			_finish()
			return
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	SaveManager.write_slot(TARGET, world._serialize_state())
	world.route_state.prologue_complete = true
	world.route_state.opening_video_seen = true
	# This test starts at a stable post-training checkpoint. A completed
	# opening alone deliberately restores the forced beam's intro ownership,
	# where current World correctly rejects manual saving before any IO.
	world.route_state.tutorial_complete = true
	SaveManager.write_slot(SOURCE, world._serialize_state())
	await world._on_title_load_game(SOURCE)
	print("SLOT_SWITCH_OBSERVATION|loaded_complete=", world.route_state.prologue_complete,
		"|tutorial_complete=", world.route_state.tutorial_complete, "|paused=", paused,
		"|title=", world.title_screen.visible, "|battle=", world.battling,
		"|popup=", world.tutorial_result_popup.visible, "|special=", world.special_encounter_prompt.visible,
		"|whirlpool=", Whirlpool.busy_in(world), "|intro=", world._intro_active,
		"|transition=", world._transitioning_to_encounter,
		"|maze_active=", world.embedded_maze.maze_active,
		"|maze_stable=", world.embedded_maze.can_capture_campaign_snapshot())
	var source_bytes := FileAccess.get_file_as_bytes(SaveManager.slot_path(SOURCE))
	var target_bytes := FileAccess.get_file_as_bytes(SaveManager.slot_path(TARGET))
	# Deny the real atomic writer's staging file, not a mocked return value.
	var pending := SaveManager.slot_path(TARGET) + ".pending"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	file.store_string("owned failure fixture")
	file.close()
	FileAccess.set_unix_permissions(pending, 256)
	world.save_point_menu.save_requested.emit(world.divers[0], TARGET)
	await process_frame
	print("SLOT_SWITCH_OBSERVATION|denied_notice=", world.banner.text, "|selected=", world._current_slot)
	_expect(world._current_slot == SOURCE, "OPEN-030 denied save selects the old target checkpoint")
	_expect("Could not save" in world.banner.text and not "Progress saved" in world.banner.text, "OPEN-030 denied save falsely announces success")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SOURCE)) == source_bytes, "OPEN-030 denied target write changes source checkpoint")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(TARGET)) == target_bytes, "OPEN-030 denied replacement destroys target checkpoint")
	FileAccess.set_unix_permissions(pending, 384)
	world.save_point_menu.save_requested.emit(world.divers[0], TARGET)
	await process_frame
	print("SLOT_SWITCH_OBSERVATION|retry_notice=", world.banner.text, "|selected=", world._current_slot)
	_expect(world._current_slot == TARGET, "OPEN-030 retry does not select a successful target")
	_expect((SaveManager.read_slot(TARGET).get("route_state", {}) as Dictionary).get("prologue_complete", false), "OPEN-030 cross-slot retry loses opening completion")
	# MSG-6: the real retry commits immediately, but its notice follows the
	# still-readable failure instead of erasing it. Keep both IO and UI oracles.
	_expect("Could not save" in world.banner.text, "MSG-6 successful retry overwrites unread failure")
	var deadline := Time.get_ticks_msec() + 5500
	while not "Progress saved" in world.banner.text and Time.get_ticks_msec() < deadline:
		await physics_frame
	_expect("Progress saved" in world.banner.text, "MSG-6 committed retry never announces success after failure")
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for slot in [SOURCE, TARGET]:
		for path in [SaveManager.slot_path(slot), SaveManager.slot_path(slot) + ".pending"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("CHECKPOINT SLOT SWITCH: clean" if findings.is_empty() else "CHECKPOINT SLOT SWITCH: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
