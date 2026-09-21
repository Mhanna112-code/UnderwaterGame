# Throwaway probe: simulates actually pressing "New Game (Skip Tutorial)"
# on the title screen and reports what happens, to find why it "doesn't
# work" without guessing blind.
# Usage: godot --headless --path . --script verify/skip_tutorial_button_probe.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	# Same thing --skip-tutorial does at boot - makes the button appear.
	world.title_screen.enable_skip_tutorial()

	print("title_screen visible: %s" % world.title_screen.visible)
	print("skip_tutorial_available: %s" % world.title_screen._skip_tutorial_available)
	print("skip_tutorial_for_test (before click): %s" % world.skip_tutorial_for_test)
	print("first_encounter_done (before click): %s" % world._first_encounter_done)

	world.title_screen.skip_tutorial_chosen.emit()
	await process_frame
	await process_frame
	await process_frame

	print("skip_tutorial_for_test (after click): %s" % world.skip_tutorial_for_test)
	print("first_encounter_done (after click): %s" % world._first_encounter_done)
	print("title_screen visible (after click): %s" % world.title_screen.visible)
	print("HUD visible (after click): %s" % world.get_node("HUD").visible)
	print("tree paused (after click): %s" % paused)
	var popup := root.get_node_or_null("CharacterAbilityPopup") as Control
	print("ability popup exists: %s, visible: %s" % [popup != null, popup != null and popup.visible])

	quit(0)
