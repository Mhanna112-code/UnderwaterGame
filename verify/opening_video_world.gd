# World/save integration for the first-run opening.
#
# Bugs caught:
# - OPEN-001: successful viewing is not persisted or an acknowledged decoder
#   fallback is falsely persisted as a successful viewing.
# - OPEN-002: load bypasses an interrupted opening or replays a completed one.
#
# Usage: godot --headless --path . --script verify/opening_video_world.gd
extends SceneTree

const SUCCESS_SLOT := 918296
const FAILURE_SLOT := 918297

var findings: Array[String] = []
var saved_files: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_backup_slot(SUCCESS_SLOT)
	_backup_slot(FAILURE_SLOT)
	_remove_slot(SUCCESS_SLOT)
	_remove_slot(FAILURE_SLOT)
	await _test_successful_viewing()
	await _test_decoder_failure_retry()
	_restore_slots()
	_finish()

func _test_successful_viewing() -> void:
	var world := await _fresh_world()
	world._on_title_new_game(SUCCESS_SLOT)
	await process_frame
	_expect(world.opening_video != null, "OPEN-002 New Game did not create opening owner")
	if world.opening_video != null:
		world.opening_video.call("finish_for_test")
	await process_frame
	await process_frame
	var data := SaveManager.read_slot(SUCCESS_SLOT)
	var route := data.get("route_state", {}) as Dictionary
	_expect(route.get("opening_video_seen", false) == true,
		"OPEN-001 completed opening milestone was not persisted")
	world.queue_free()
	await process_frame
	paused = false

	var loaded := await _fresh_world()
	loaded._on_title_load_game(SUCCESS_SLOT)
	await process_frame
	await process_frame
	_expect(loaded.opening_video == null,
		"OPEN-002 completed opening replayed after Load Game")
	_expect(not paused and loaded.get_node("HUD").visible,
		"OPEN-002 completed opening did not restore controllable world")
	loaded.queue_free()
	await process_frame
	paused = false

func _test_decoder_failure_retry() -> void:
	var world := await _fresh_world()
	world._on_title_new_game(FAILURE_SLOT)
	await process_frame
	_expect(world.opening_video != null, "OPEN-004 failure setup has no opening owner")
	if world.opening_video != null:
		world.opening_video.call("fail_for_test")
		var button := _first_button(world.opening_video)
		_expect(button != null, "OPEN-004 failure fallback has no Continue action")
		if button != null:
			button.emit_signal("pressed")
	await process_frame
	await process_frame
	var data := SaveManager.read_slot(FAILURE_SLOT)
	var route := data.get("route_state", {}) as Dictionary
	_expect(route.get("opening_video_seen", true) == false,
		"OPEN-001 decoder failure was falsely saved as a successful viewing")
	world.queue_free()
	await process_frame
	paused = false

	var loaded := await _fresh_world()
	loaded._on_title_load_game(FAILURE_SLOT)
	await process_frame
	_expect(loaded.opening_video != null,
		"OPEN-002 interrupted/failed opening did not replay on Load Game")
	if loaded.opening_video != null:
		loaded.opening_video.call("finish_for_test")
	await process_frame
	loaded.queue_free()
	await process_frame
	paused = false

func _fresh_world() -> World:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	return world

func _first_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child as Button
		var nested := _first_button(child)
		if nested != null:
			return nested
	return null

func _backup_slot(slot: int) -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(slot))
	if FileAccess.file_exists(absolute):
		saved_files[slot] = FileAccess.get_file_as_bytes(absolute)

func _remove_slot(slot: int) -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(slot))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

func _restore_slots() -> void:
	for slot in [SUCCESS_SLOT, FAILURE_SLOT]:
		_remove_slot(slot)
		if saved_files.has(slot):
			var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(slot))
			var file := FileAccess.open(absolute, FileAccess.WRITE)
			file.store_buffer(saved_files[slot] as PackedByteArray)
			file.close()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING VIDEO WORLD: clean" if findings.is_empty() else "OPENING VIDEO WORLD: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
