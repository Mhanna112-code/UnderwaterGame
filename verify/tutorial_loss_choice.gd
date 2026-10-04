# `tutorial loss: retry/exit choice - losing the scripted first fight opens
# tutorial_result_popup instead of an automatic heal-and-return; Retry heals
# and relaunches the same fight, Exit heals, returns to the world, and still
# triggers the ability popups exactly like the old automatic path did`.
#
# Usage: godot --headless --path . --script verify/tutorial_loss_choice.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

# Drives the actual unit under test - World._on_battle_finished()'s "lost"
# branch - directly, rather than simulating a full real fight down to a
# loss through _advance_turn()'s own turn-by-turn AI (which needs far more
# machinery than this test cares about: move selection, QTEs, enemy AI
# targeting...). Building a real Battle first and marking it
# tutorial_encounter is enough for _on_battle_finished() to read
# battle.tutorial_encounter correctly before it frees it.
func _lose_the_tutorial(world: World) -> void:
	for d in world.divers:
		(d as Diver).stats.hp = 1
	world._start_battle("", false, "angler", world.divers, false, true)
	await process_frame
	world._on_battle_finished("lost")
	await process_frame

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame

	await _lose_the_tutorial(world)

	_expect(world.battle == null, "BATTLE STILL UP: losing the tutorial should have freed the battle screen")
	_expect(world.tutorial_result_popup.visible, "NO CHOICE SHOWN: losing the tutorial should open tutorial_result_popup, not auto-return")
	_expect(paused, "NOT PAUSED: the loss choice should pause the tree like every other modal")
	for d in world.divers:
		_expect((d as Diver).stats.hp == 1, "HEALED TOO EARLY: the party shouldn't be restored until a choice is actually made")

	# Retry: heals, relaunches the same fight, and does NOT show the ability
	# popups (those are for "done with the tutorial", not "trying again").
	# Calls the real button handler (not retry_chosen.emit() directly) so
	# _close()'s own unpause actually runs, same as a real click would.
	world.tutorial_result_popup.call("_on_retry_pressed")
	await process_frame
	_expect(not paused, "STILL PAUSED: choosing Retry should unpause immediately")
	_expect(world.battle != null and world.battle.tutorial_encounter, "NO RETRY BATTLE: choosing Retry should start a new tutorial fight")
	for d in world.divers:
		_expect((d as Diver).stats.hp == (d as Diver).stats.hp_max, "NOT HEALED ON RETRY: the party should be full HP going into the retry")
	var ability_panel := root.get_node_or_null("CharacterAbilityPopup/UI/AbilityExplanationPanel")
	_expect(ability_panel == null or not (ability_panel as Control).visible, "ABILITY POPUP ON RETRY: retrying shouldn't open the world-ability popups")

	# Lose it again, then choose Exit this time.
	await _lose_the_tutorial(world)
	_expect(world.tutorial_result_popup.visible, "NO CHOICE ON SECOND LOSS: the choice should reappear on every tutorial loss, not just the first")
	world.tutorial_result_popup.call("_on_exit_pressed")
	await process_frame
	_expect(world.battle == null, "BATTLE STUCK: choosing Exit should not leave a battle running")
	for d in world.divers:
		var s: CombatantStats = (d as Diver).stats
		_expect(s.hp == s.hp_max, "NOT HEALED ON EXIT: the party should be fully restored on Exit to World")
	await process_frame
	# The deferred _show_ability_popups() call from _on_tutorial_loss_exit()
	# should have landed by now, correctly re-pausing the tree to show that
	# walkthrough - not a stuck pause, the intended next step after exiting.
	ability_panel = root.get_node_or_null("CharacterAbilityPopup/UI/AbilityExplanationPanel")
	_expect(ability_panel != null and (ability_panel as Control).visible, "NO ABILITY POPUP ON EXIT: exiting to world should still open the ability walkthrough, same as the old automatic path did")
	_expect(paused, "NOT PAUSED: the ability popup that just opened should have paused the tree")

	for finding in findings:
		print("FINDING  " + finding)
	if findings.is_empty():
		print("tutorial loss choice   retry and exit both behave correctly")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
