# `optional training menu: every deferred lesson stays reachable from Combat
# Help without extending the mandatory opening or trapping the player in a
# nested modal`.
#
# Usage: godot --headless --path . --script verify/optional_training_menu.gd
extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").visible = true
	world._first_encounter_done = true
	world.inventory_menu.open_combat_help()
	await process_frame

	var ability_button := _button_named(world.inventory_menu, "World Ability Training")
	var advanced_button := _button_named(world.inventory_menu, "Advanced Combat Guide")
	_expect(ability_button != null,
		"TRAINING-MENU-1: Combat Help has no visible World Ability Training entry")
	_expect(advanced_button != null,
		"TRAINING-MENU-1: Combat Help has no visible Advanced Combat Guide entry")

	if ability_button != null:
		ability_button.pressed.emit()
		await process_frame
		_expect(world.ability_onboarding.visible and not world.inventory_menu.visible,
			"TRAINING-MENU-1: World Ability Training did not replace Combat Help with its reachable walkthrough")
		_expect(world.ability_onboarding.current_page_data().get("id", "") == "world-controls",
			"TRAINING-MENU-1: World Ability Training did not begin with steerable world controls")
		world.ability_onboarding.dismiss()
		await process_frame
		_expect(not paused and world.get_node("HUD").visible,
			"TRAINING-MENU-1: closing World Ability Training did not return to usable world controls")

	world.inventory_menu.open_combat_help()
	await process_frame
	advanced_button = _button_named(world.inventory_menu, "Advanced Combat Guide")
	if advanced_button != null:
		advanced_button.pressed.emit()
		await process_frame
		_expect(world.tutorial_book.visible and not world.inventory_menu.visible,
			"TRAINING-MENU-2: Advanced Combat Guide did not replace Combat Help with the optional guide")
		_expect(world.tutorial_book.current_page_data().get("title", "") == "Advanced Combat Guide",
			"TRAINING-MENU-2: guide opened unrelated tutorial content instead of advanced combat")
		var next := _button_named(world.tutorial_book, "Next >")
		if next != null:
			next.pressed.emit()
			await process_frame
		_expect(world.tutorial_book.current_page_data().get("title", "") == "Combat Basics",
			"TRAINING-MENU-2: guide omitted the first deferred combat concept after its overview")

	for failure in failures:
		push_error(failure)
	print("OPTIONAL TRAINING MENU: %s" % ("clean" if failures.is_empty() else "%d failure(s)" % failures.size()))
	world.queue_free()
	quit(0 if failures.is_empty() else 1)

func _button_named(node: Node, text_value: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == text_value:
			return child as Button
		var nested := _button_named(child, text_value)
		if nested != null:
			return nested
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
