# Throwaway probe: completes the tutorial fight by actually winning it (not
# skipping), clicks through the post-fight CharacterAbilityPopup, then
# checks whether mouse-look got restored. Same acknowledge-the-caption
# trick as verify/tutorial_exit.gd.
# Usage: godot --headless --path . --script verify/mouse_look_after_win_probe.gd
extends SceneTree

const TIMEOUT_MS := 15000

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world._start_battle("", false, "angler", world.divers, false, true)
	await process_frame

	var battle: Battle = world.battle
	if battle == null:
		print("NO BATTLE")
		quit(1)
		return

	print("mouse_look before win: %s" % world.mouse_look)

	for enemy_entry in battle.enemies:
		(enemy_entry.stats as CombatantStats).hp = 0
	battle._tutorial_step = battle._TUTORIAL_SCRIPT.size()
	battle._tutorial_enemy_turns = 1
	battle._tutorial_finale_shown = false
	battle._qte_active = false
	battle._advance_turn()

	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while world.battle != null and Time.get_ticks_msec() < deadline:
		if world.battle._tutorial_awaiting_enter:
			world.battle._tutorial_awaiting_enter = false
		await process_frame

	print("world.battle cleared: %s" % (world.battle == null))
	print("mouse_look right after battle cleared: %s" % world.mouse_look)

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

	world.queue_free()
	quit(0)
