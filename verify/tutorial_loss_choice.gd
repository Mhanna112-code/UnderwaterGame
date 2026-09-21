# The tutorial loss modal is a distinct recovery path: it must not become a
# normal game-over, and Retry/Exit must both restore the party safely.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _lose_tutorial(world: World) -> void:
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

	await _lose_tutorial(world)
	_expect(world.battle == null, "BATTLE STILL UP after tutorial loss")
	_expect(world.tutorial_result_popup.visible, "NO TUTORIAL LOSS CHOICE")
	_expect(paused, "LOSS CHOICE DID NOT PAUSE")
	for d in world.divers:
		_expect((d as Diver).stats.hp == 1, "PARTY HEALED BEFORE PLAYER CHOSE")

	world.tutorial_result_popup.call("_retry")
	await process_frame
	_expect(not paused, "RETRY LEFT THE TREE PAUSED")
	_expect(world.battle != null and world.battle.tutorial_encounter, "RETRY DID NOT RESTART TUTORIAL")
	_expect(not world.ability_onboarding.visible, "RETRY OPENED WORLD-CONTROL HANDOFF INSIDE THE LESSON")
	for d in world.divers:
		_expect((d as Diver).stats.hp == (d as Diver).stats.hp_max, "RETRY DID NOT HEAL PARTY")

	await _lose_tutorial(world)
	_expect(world.tutorial_result_popup.visible, "LOSS CHOICE DID NOT RETURN")
	world.tutorial_result_popup.call("_exit")
	await process_frame
	_expect(world.battle == null, "EXIT LEFT A BATTLE RUNNING")
	# Exit now hands a first-time player to the world-controls walkthrough
	# instead of silently dropping them into open water. It intentionally keeps
	# the tree paused until the player dismisses that onboarding, then must
	# restore the same playable world this test historically checked for.
	_expect(world.ability_onboarding.visible, "EXIT DID NOT OPEN WORLD-CONTROL HANDOFF")
	_expect(paused, "EXIT HANDOFF DID NOT PAUSE WORLD WHILE READING")
	world.ability_onboarding.call("dismiss")
	await process_frame
	_expect(not paused, "EXIT HANDOFF LEFT THE TREE PAUSED AFTER DISMISS")
	for d in world.divers:
		_expect((d as Diver).stats.hp == (d as Diver).stats.hp_max, "EXIT DID NOT HEAL PARTY")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial loss choice   retry and exit both behave correctly")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
