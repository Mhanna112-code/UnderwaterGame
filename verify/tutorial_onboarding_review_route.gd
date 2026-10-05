# `tutorial guide replay: Combat Help opens the real guide without stacked
# full-screen menus or a hidden query-only title action`.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world._intro_active = false
	world._first_encounter_done = true
	world.inventory_menu.open()
	world.inventory_menu.call("_switch_to", "help")
	await process_frame
	var review_button := _button_named(world.inventory_menu, "Reopen Tutorial Guide")
	_expect(review_button != null, "ONBOARDING REPLAY: Combat Help has no mouse-accessible tutorial guide action")
	if review_button != null:
		review_button.pressed.emit()
		await process_frame
	_expect(not world.inventory_menu.visible, "ONBOARDING REPLAY: Inventory remained stacked beneath the tutorial guide")
	_expect(world.tutorial_book.visible, "ONBOARDING REPLAY: action did not open the real TutorialBook")
	_expect(world.battle == null, "ONBOARDING REPLAY: opening help unexpectedly started combat")
	_expect(paused, "ONBOARDING REPLAY: guide did not pause world input")
	world.tutorial_book.call("_on_close_pressed")
	await process_frame
	_expect(not paused, "ONBOARDING REPLAY: closing the guide left the world paused")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial onboarding route  Combat Help opens the guide without stacked overlays")
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	quit(0 if findings.is_empty() else 1)

func _button_named(node: Node, text_value: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == text_value:
			return child as Button
		var nested := _button_named(child, text_value)
		if nested != null:
			return nested
	return null

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
