extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _enter_special(world: World, diver: Diver, item_id: String) -> Battle:
	var guardian: ItemGuardian = null
	for child in world.get_children():
		if child is ItemGuardian and (child as ItemGuardian).item_id == item_id:
			guardian = child as ItemGuardian
			break
	_check(guardian != null, "guarded site was not built")
	if guardian == null:
		return null
	guardian.triggered.emit(item_id)
	_check(world.special_encounter_prompt.visible, "chooser did not open")
	world.special_encounter_prompt.diver_chosen.emit(diver.model_name)
	await process_frame
	return world.battle

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	world.title_screen.new_game_chosen.emit(1)
	await process_frame

	var diver := world.divers[0] as Diver
	var entry_hp := diver.stats.hp - 3
	var entry_oxygen := diver.stats.oxygen - 7.0
	diver.stats.hp = entry_hp
	diver.stats.oxygen = entry_oxygen
	var battle := await _enter_special(world, diver, "current_pearl")
	_check(battle != null and battle.special_encounter, "chooser did not create a special battle")
	_check(battle != null and battle.party.size() == 1, "special battle did not contain exactly one diver")
	_check(world._pending_reward_item == "current_pearl", "special battle lost its guarded reward")
	diver.stats.hp = 1
	diver.stats.oxygen = 2.0
	battle.finished.emit("lost")
	await process_frame
	_check(diver.stats.hp == entry_hp, "loss did not restore entry HP")
	_check(is_equal_approx(diver.stats.oxygen, entry_oxygen), "loss did not restore entry oxygen")
	_check(not world.game_over_screen.visible, "special loss opened game over")

	battle = await _enter_special(world, diver, "current_pearl")
	diver.stats.hp = 1
	diver.stats.oxygen = 2.0
	battle.finished.emit("won")
	await process_frame
	_check(diver.stats.hp == diver.stats.hp_max, "win did not fill HP")
	_check(is_equal_approx(diver.stats.oxygen, diver.stats.oxygen_max), "win did not fill oxygen")
	_check(world.key_items.has("current_pearl"), "win did not grant the guarded item")

	# The web-only review route must exercise the real chooser/dispatcher but
	# return to the title without granting an item or damaging a save-backed run.
	world._on_title_special_playtest()
	_check(world.special_encounter_prompt.visible, "special playtest route did not open the chooser")
	var playtest_diver := world.divers[1] as Diver
	var playtest_hp := playtest_diver.stats.hp
	world.special_encounter_prompt.diver_chosen.emit(playtest_diver.model_name)
	await process_frame
	_check(world.battle != null and world.battle.special_encounter, "special playtest route did not start a special battle")
	world.battle.finished.emit("lost")
	await process_frame
	await process_frame
	_check(world.title_screen.visible, "special playtest route did not return to title")
	_check(playtest_diver.stats.hp == playtest_hp, "special playtest route did not restore entry HP")

	for finding in findings:
		print("FINDING  " + finding)
	print("SPECIAL ENCOUNTERS: clean" if findings.is_empty() else "SPECIAL ENCOUNTERS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
