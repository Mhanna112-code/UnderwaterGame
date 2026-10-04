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
	SaveManager.write_slot(SOURCE, world._serialize_state())
	await world._on_title_load_game(SOURCE)
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
	_expect(world._current_slot == SOURCE, "OPEN-030 denied save selects the old target checkpoint")
	_expect("Could not save" in world.banner.text and not "Progress saved" in world.banner.text, "OPEN-030 denied save falsely announces success")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SOURCE)) == source_bytes, "OPEN-030 denied target write changes source checkpoint")
	_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(TARGET)) == target_bytes, "OPEN-030 denied replacement destroys target checkpoint")
	FileAccess.set_unix_permissions(pending, 384)
	world.save_point_menu.save_requested.emit(world.divers[0], TARGET)
	await process_frame
	_expect(world._current_slot == TARGET and "Progress saved" in world.banner.text, "OPEN-030 retry does not select a successful target")
	_expect((SaveManager.read_slot(TARGET).get("route_state", {}) as Dictionary).get("prologue_complete", false), "OPEN-030 cross-slot retry loses opening completion")
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
