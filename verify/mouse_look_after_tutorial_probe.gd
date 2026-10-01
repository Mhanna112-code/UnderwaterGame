# Throwaway probe: skips the tutorial, clicks all the way through the
# post-tutorial CharacterAbilityPopup, then checks whether mouse-look
# actually got restored - to find why it "doesn't work" without guessing.
# Usage: godot --headless --path . --script verify/mouse_look_after_tutorial_probe.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.enable_skip_tutorial()
	world.title_screen.skip_tutorial_chosen.emit()
	await process_frame
	await process_frame
	await process_frame

	print("mouse_look right after skip: %s" % world.mouse_look)
	print("Input.mouse_mode right after skip: %s" % Input.mouse_mode)

	var popup := root.get_node_or_null("CharacterAbilityPopup") as Control
	if popup == null:
		print("NO POPUP FOUND")
		quit(1)
		return
	var panel := popup.get_node("%AbilityExplanationPanel") as PanelContainer
	print("panel visible: %s" % panel.visible)

	var close_btn := popup.get_node("%PopupClose") as Button
	var guard := 0
	while panel.visible and guard < 10:
		print("  click %d, button text: %s" % [guard, close_btn.text])
		close_btn.pressed.emit()
		await process_frame
		await process_frame
		guard += 1
	print("panel visible after clicking through: %s (took %d clicks)" % [panel.visible, guard])

	await process_frame
	await process_frame

	print("mouse_look after popup closed: %s" % world.mouse_look)
	print("Input.mouse_mode after popup closed: %s (CAPTURED=%s)" % [Input.mouse_mode, Input.MOUSE_MODE_CAPTURED])

	quit(0)
