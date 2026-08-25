# Cold-launch and title-flow regression for issue #44.
# Usage: godot --headless --path . --script verify/title_screen.gd
extends SceneTree

var findings: Array[String] = []
var _saved_files: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_backup_real_slots()
	_remove_all_slots()

	# First launch: one obvious action, no dead Load path, and one click starts.
	var fresh := await _fresh_world()
	_check_exclusive_fullscreen(fresh, "fresh launch")
	var fresh_buttons := _find_buttons(fresh.title_screen)
	if fresh_buttons.size() != 1 or (fresh_buttons[0] as Button).text != "New Game":
		findings.append("FIRST ACTION: a fresh install must show only New Game")
	else:
		(fresh_buttons[0] as Button).pressed.emit()
		await process_frame
		_check_world_started(fresh, "one-click New Game")
	fresh.queue_free()
	await process_frame
	paused = false

	# Returning player: New is primary, Load secondary, and both slot pickers
	# occupy the same readable centered surface.
	SaveManager.write_slot(0, {"divers": [{"stats": {"level": 3}}]})
	var returning := await _fresh_world()
	_check_exclusive_fullscreen(returning, "returning launch")
	var main_buttons := _find_buttons(returning.title_screen)
	if main_buttons.size() != 2:
		findings.append("RETURNING ACTIONS: expected New Game and Load Game")
	else:
		var new_btn := main_buttons[0] as Button
		var load_btn := main_buttons[1] as Button
		if new_btn.text != "New Game" or load_btn.text != "Load Game":
			findings.append("ACTION ORDER: New Game must precede Load Game")
		if new_btn.custom_minimum_size.y <= load_btn.custom_minimum_size.y:
			findings.append("PRIMARY ACTION: New Game is not visually larger than Load Game")

		new_btn.pressed.emit()
		await process_frame
		_check_slot_screen(returning.title_screen, "New Game")
		returning.title_screen._back_to_main()
		await process_frame
		var refreshed := _find_buttons(returning.title_screen)
		(refreshed[1] as Button).pressed.emit()
		await process_frame
		_check_slot_screen(returning.title_screen, "Load Game")

	_restore_real_slots()
	print("title flow            first-run, main, new slots, and load slots clean" if findings.is_empty() else "title flow            FAILED")
	for finding in findings:
		push_error(finding)
	quit(0 if findings.is_empty() else 1)

func _fresh_world() -> World:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	return world

func _check_exclusive_fullscreen(world: World, context: String) -> void:
	if not world.title_screen.visible:
		findings.append("TITLE HIDDEN (%s)" % context)
	if world.get_node("HUD").visible:
		findings.append("HUD LEAK (%s)" % context)
	var viewport_size := root.get_visible_rect().size
	if not world.title_screen.size.is_equal_approx(viewport_size):
		findings.append("TITLE RECT (%s): %s vs %s" % [context, world.title_screen.size, viewport_size])

func _check_world_started(world: World, context: String) -> void:
	if world.title_screen.visible:
		findings.append("TITLE STUCK (%s)" % context)
	if not world.get_node("HUD").visible:
		findings.append("HUD MISSING (%s)" % context)
	if paused:
		findings.append("WORLD PAUSED (%s)" % context)

func _check_slot_screen(title: TitleScreen, context: String) -> void:
	var buttons := _find_buttons(title)
	if buttons.size() != SaveManager.SLOT_COUNT + 1:
		findings.append("%s SLOTS: expected three slots and Back, got %d" % [context, buttons.size()])
		return
	for i in range(1, buttons.size()):
		if (buttons[i] as Button).global_position.y - (buttons[i - 1] as Button).global_position.y < 36.0:
			findings.append("%s BUNCHED: buttons %d and %d overlap" % [context, i - 1, i])

func _find_buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			found.append(child as Button)
		found.append_array(_find_buttons(child))
	return found

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
