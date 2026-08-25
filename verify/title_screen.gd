# Cold-launch title regression for issue #44.
# Usage: godot --headless --path . --script verify/title_screen.gd
extends SceneTree

const TEST_SLOT := 918274
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame

	if not world.title_screen.visible:
		findings.append("TITLE HIDDEN: cold launch did not open the title screen")
	if world.get_node("HUD").visible:
		findings.append("HUD LEAK: world HUD remains visible behind the title")
	var viewport_size := root.get_visible_rect().size
	if not world.title_screen.size.is_equal_approx(viewport_size):
		findings.append("TITLE RECT: overlay %s does not fill viewport %s" % [world.title_screen.size, viewport_size])

	var buttons := _find_buttons(world.title_screen)
	if buttons.size() != 2:
		findings.append("MAIN ACTIONS: expected New Game and Load Game, got %d buttons" % buttons.size())
	elif absf((buttons[0] as Button).global_position.y - (buttons[1] as Button).global_position.y) < 40.0:
		findings.append("BUNCHED ACTIONS: New Game and Load Game overlap vertically")

	world.title_screen.new_game_chosen.emit(TEST_SLOT)
	await process_frame
	if world.title_screen.visible:
		findings.append("TITLE STUCK: title remains visible after New Game")
	if not world.get_node("HUD").visible:
		findings.append("HUD MISSING: world HUD did not return after New Game")
	if paused:
		findings.append("WORLD PAUSED: New Game did not resume the scene tree")

	print("cold title             exclusive, centered, and transitions clean" if findings.is_empty() else "cold title             FAILED")
	for finding in findings:
		push_error(finding)
	_remove_test_save()
	quit(0 if findings.is_empty() else 1)

func _find_buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			found.append(child as Button)
		found.append_array(_find_buttons(child))
	return found

func _remove_test_save() -> void:
	var path := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
