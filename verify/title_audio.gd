# Main-menu UI sound semantic contract.
#
# Usage: godot --headless --path . --script verify/title_audio.gd
extends SceneTree

var findings: Array[String] = []
var _saved_files: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_backup_real_slots()
	_remove_all_slots()
	var audio := root.get_node_or_null("GameAudio")
	if audio == null:
		findings.append("OWNER: GameAudio autoload is absent")
		_finish()
		return

	var fresh := await _fresh_title()
	audio.clear_sfx_event_trace()
	var new_button := _find_button(fresh, "New Game")
	new_button.mouse_entered.emit()
	new_button.pressed.emit()
	_expect(audio.get_sfx_event_trace() == ["ui_hover", "ui_start_game"], "FRESH: New Game did not produce Hover then Start Game exactly once")
	fresh.queue_free()
	await process_frame

	SaveManager.write_slot(0, {"divers": [{"stats": {"level": 2}}]})
	var returning := await _fresh_title()
	audio.clear_sfx_event_trace()
	var returning_new := _find_button(returning, "New Game")
	returning_new.mouse_entered.emit()
	returning_new.pressed.emit()
	await process_frame
	_expect(audio.get_sfx_event_trace() == ["ui_hover", "ui_click"], "NAVIGATION: opening the slot picker did not use Hover then Click")

	audio.clear_sfx_event_trace()
	var slot := _first_slot_button(returning)
	await create_timer(0.3).timeout # deliberate hover after navigation acknowledgement
	slot.mouse_entered.emit()
	slot.pressed.emit()
	_expect(audio.get_sfx_event_trace() == ["ui_hover", "ui_start_game"], "SLOT: choosing a run did not use Hover then Start Game")

	returning._back_to_main()
	await process_frame
	_find_button(returning, "Load Game").pressed.emit()
	await process_frame
	audio.clear_sfx_event_trace()
	var back := _find_button(returning, "< Back")
	await create_timer(0.3).timeout
	back.mouse_entered.emit()
	back.pressed.emit()
	_expect(audio.get_sfx_event_trace() == ["ui_hover", "ui_click"], "BACK: menu navigation did not use Hover then Click")

	returning.queue_free()
	await process_frame
	audio.release_streams_for_shutdown()
	await create_timer(0.15).timeout
	_finish()

func _fresh_title() -> TitleScreen:
	var title := TitleScreen.new()
	root.add_child(title)
	await process_frame
	title.open()
	await process_frame
	await create_timer(0.3).timeout
	return title

func _find_button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
		var nested := _find_button(child, text)
		if nested != null:
			return nested
	return null

func _first_slot_button(title: TitleScreen) -> Button:
	for child in title._list.get_children():
		if child is Button and (child as Button).text.begins_with("Slot "):
			return child as Button
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _backup_real_slots() -> void:
	for slot in range(SaveManager.SLOT_COUNT):
		var path := ProjectSettings.globalize_path(SaveManager.slot_path(slot))
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			_saved_files[path] = file.get_buffer(file.get_length())

func _remove_all_slots() -> void:
	for slot in range(SaveManager.SLOT_COUNT):
		var path := ProjectSettings.globalize_path(SaveManager.slot_path(slot))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _restore_real_slots() -> void:
	_remove_all_slots()
	for path in _saved_files:
		DirAccess.make_dir_recursive_absolute(String(path).get_base_dir())
		var file := FileAccess.open(String(path), FileAccess.WRITE)
		file.store_buffer(_saved_files[path] as PackedByteArray)

func _finish() -> void:
	_restore_real_slots()
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING  " + finding)
	print("TITLE AUDIO: clean" if findings.is_empty() else "TITLE AUDIO: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
