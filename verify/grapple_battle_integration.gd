extends SceneTree

var result: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var real_diver := Diver.new()
	real_diver.model_name = "Prototype_1(1910)"
	root.add_child(real_diver)
	await process_frame
	# Force the real opening dispatcher onto the enemy turn so this verifies
	# the ability-id route itself, without manually starting a second copy.
	real_diver.stats.agility = -999

	var battle := Battle.new()
	battle.party_source = [real_diver]
	battle.special_encounter = true
	root.add_child(battle)
	await process_frame
	var party_entry: Dictionary = battle.party[0]
	var hp_before := (party_entry.stats as CombatantStats).hp
	var default_camera_position := Battle.DEFAULT_CAM_POS

	var minigame: GrappleInterceptMinigame = null
	var deadline := Time.get_ticks_msec() + 16000
	while Time.get_ticks_msec() < deadline:
		if minigame == null or not is_instance_valid(minigame):
			for child in battle.get_children():
				if child is GrappleInterceptMinigame:
					minigame = child as GrappleInterceptMinigame
					minigame.finished.connect(func(hits: int, total: int) -> void: result = [hits, total])
					break
		if minigame != null and is_instance_valid(minigame):
			minigame.verification_resolve_closest()
		elif not result.is_empty():
			break
		await process_frame

	# finished resumes Battle's coroutine synchronously through camera/model
	# restoration, then pauses at its closing read timer before advancing.
	await process_frame
	var hp_after := (party_entry.stats as CombatantStats).hp
	var actor_visible := (party_entry.actor as Diver).visible
	var camera_restored := battle._stage_camera.position.distance_to(default_camera_position) < 0.01
	# MODIFIED: was hardcoded [8, 8] - stale since TARGET_COUNT dropped to
	# 5 (see grapple_intercept_minigame.gd's own header). Read the real
	# constant instead of re-hardcoding a number that can drift again.
	var expected := GrappleInterceptMinigame.TARGET_COUNT
	# MODIFIED: was also asserting wrong_hits == 1 and hp_after < hp_before,
	# both driven by deliberately shooting a decoy (auto_hit_decoy(), now
	# removed along with decoys entirely - see grapple_intercept_minigame.gd).
	# verification_resolve_closest() destroys every rock directly before it
	# can ever land, so nothing in this test path damages the diver anymore -
	# hp_after <= hp_before (never healing) is what's actually still
	# guaranteed, not a strict decrease.
	var clean := result == [expected, expected] and hp_after <= hp_before and actor_visible and camera_restored
	print("GRAPPLE BATTLE: result %s, HP %d -> %d, camera %s, actor visible %s" % [
		str(result), hp_before, hp_after, str(camera_restored), str(actor_visible)
	])
	if not clean:
		push_error("GRAPPLE BATTLE: integration contract failed")
		quit(1)
		return
	print("GRAPPLE BATTLE: clean")
	quit()
