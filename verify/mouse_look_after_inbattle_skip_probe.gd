# Throwaway probe: starts a REAL tutorial battle, presses the in-battle
# "Skip Tutorial" button (battle.gd's skip_tutorial_btn, not the title
# screen's separate skip-tutorial shortcut), clicks through the post-fight
# CharacterAbilityPopup, then checks whether mouse-look actually got
# restored - matching the exact path a player takes when they hit Skip
# Tutorial mid-fight rather than at the title screen.
# Usage: godot --headless --path . --script verify/mouse_look_after_inbattle_skip_probe.gd
extends SceneTree

const TIMEOUT_MS := 15000

var world: World
var result := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame

	world.title_screen.new_game_chosen.emit(1)
	await process_frame
	await process_frame

	world._start_battle("", false, "angler", world.divers, false, true)
	await process_frame
	await process_frame

	var battle: Battle = world.battle
	if battle == null:
		print("NO BATTLE")
		quit(1)
		return
	battle.finished.connect(func(r): result = r)

	print("mouse_look right before skip press: %s" % world.mouse_look)
	print("skip_tutorial_btn exists: %s" % (battle.skip_tutorial_btn != null))

	var pressed := false
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while result == "" and Time.get_ticks_msec() < deadline:
		# Acknowledge any scripted-intro caption exactly as Enter would (same
		# trick verify/tutorial_exit.gd uses), so _busy actually clears and
		# the Skip Tutorial press below isn't silently swallowed by
		# _on_skip_tutorial_pressed()'s own "if _busy: return" guard.
		if world.battle != null and world.battle._tutorial_awaiting_enter:
			world.battle._tutorial_awaiting_enter = false
		if not pressed and world.battle != null and not world.battle._busy \
				and world.battle.skip_tutorial_btn != null and not world.battle.skip_tutorial_btn.disabled:
			world.battle.skip_tutorial_btn.pressed.emit()
			pressed = true
		await process_frame

	print("skip button was pressed: %s" % pressed)
	print("battle result: %s" % result)

	await process_frame
	await process_frame
	await process_frame

	print("mouse_look right after battle finished: %s" % world.mouse_look)

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
		close_btn.pressed.emit()
		await process_frame
		await process_frame
		guard += 1
	print("panel visible after clicking through: %s (took %d clicks)" % [panel.visible, guard])

	await process_frame
	await process_frame

	print("mouse_look after popup closed: %s" % world.mouse_look)

	quit(0)
