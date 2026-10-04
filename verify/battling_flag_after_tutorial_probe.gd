# Throwaway probe: checks world.battling and world._intro_active after the
# tutorial fight ends - _unhandled_input()'s very first line is
# "if battling: return", so if that flag is stuck true, camera look (and
# E/Q/R/Tab) would all silently do nothing, which reads exactly like
# "camera look is disabled" even though mouse_look/Input.mouse_mode are
# both fine.
# Usage: godot --headless --path . --script verify/battling_flag_after_tutorial_probe.gd
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

	print("battling during fight: %s" % world.battling)
	print("_intro_active during fight: %s" % world._intro_active)

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
	print("battling right after battle cleared: %s" % world.battling)
	print("_intro_active right after battle cleared: %s" % world._intro_active)
	print("tree paused right after battle cleared: %s" % paused)

	var popup := root.get_node_or_null("CharacterAbilityPopup") as Control
	if popup == null:
		print("NO POPUP FOUND")
		quit(1)
		return
	var panel := popup.get_node("%AbilityExplanationPanel") as PanelContainer
	var close_btn := popup.get_node("%PopupClose") as Button
	var guard := 0
	while panel.visible and guard < 10:
		close_btn.pressed.emit()
		await process_frame
		await process_frame
		guard += 1

	print("---after popup fully closed---")
	print("battling: %s" % world.battling)
	print("_intro_active: %s" % world._intro_active)
	print("tree paused: %s" % paused)
	print("mouse_look: %s" % world.mouse_look)

	# Simulate the actual mouse-motion input event a real player's mouse
	# move would generate, straight through _unhandled_input(), the same
	# entry point a real InputEventMouseMotion goes through.
	var before_yaw: float = world.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50, 0)
	world._unhandled_input(motion)
	print("yaw changed from simulated mouse motion: %s (before=%.4f after=%.4f)" % [
		not is_equal_approx(before_yaw, world.yaw), before_yaw, world.yaw])

	world.queue_free()
	quit(0)
