extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _enter_special(world: World, diver: Diver, item_id: String) -> Battle:
	# No guardian node to find and trigger anymore - _offer_special_encounter()
	# is the real entry point both a random-encounter roll
	# (World._on_encounter_triggered()) and the special-playtest route use to
	# open this now, so calling it directly exercises the same path a player
	# actually takes. Site/reachability existence is verify/encounters.gd's
	# job, not this lifecycle test's.
	var enemy_id := "angler"
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		if String(entry.item) == item_id:
			enemy_id = String(entry.get("enemy", "angler"))
			break
	world._pending_guardian_enemy_id = enemy_id
	world._offer_special_encounter(item_id)
	_check(world.special_encounter_prompt.visible, "chooser did not open")
	world.special_encounter_prompt.diver_chosen.emit(diver.model_name)
	await process_frame
	return world.battle

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.new_game_chosen.emit(1)
	await process_frame
	# The very first special encounter of a real game skips this chooser
	# entirely and forces Maxilani straight into battle instead (see World.
	# _offer_special_encounter()) - verify/encounters.gd's own
	# _check_first_special_encounter_skips_prompt() is what tests that path.
	# Every check below is about the chooser/dispatcher's steady-state
	# lifecycle (loss/win restores, the playtest route), so it forces past
	# the one-time skip up front rather than tripping over it by accident.
	world.player_first_special_encounter = false
	# The chooser is a real player-facing entry point, so keep its embedded
	# tutorial recording in a 16:9 frame.  A portrait slot made the video
	# itself render as a tiny letterboxed strip even though the selector had
	# plenty of horizontal space.
	world.special_encounter_prompt._on_enter_pressed()
	await process_frame
	var media_frame := world.special_encounter_prompt._media_frame
	_check(
		is_equal_approx(media_frame.custom_minimum_size.x / media_frame.custom_minimum_size.y, 16.0 / 9.0),
		"chooser tutorial-video frame is not 16:9"
	)
	var swap_crop: Variant = TutorialContent.SPECIAL_ENCOUNTER_VIDEO_CROPS.get("swap")
	_check(swap_crop is Vector4 and (swap_crop as Vector4).z > 0.0 and (swap_crop as Vector4).w > 0.0, "padded Swap recording has no in-game crop")
	world.special_encounter_prompt.close()

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
	# MODIFIED (changed): a win used to fill HP/oxygen to max - now matches
	# a loss's own restore, reverting to whatever the diver had on entering
	# the encounter (entry_hp/entry_oxygen, captured by _enter_special()
	# just above) rather than leaving a win in better shape than a loss.
	_check(diver.stats.hp == entry_hp, "win did not restore entry HP")
	_check(is_equal_approx(diver.stats.oxygen, entry_oxygen), "win did not restore entry oxygen")
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
