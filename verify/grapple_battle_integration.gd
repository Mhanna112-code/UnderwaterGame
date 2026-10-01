extends SceneTree

var result: Array = []
var timed_out_wave_impacts := 0

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
	var default_camera_position := battle._stage_cam.global_position
	var default_camera_fov := battle._stage_cam.fov
	var timed_out_wave_damage := 0
	var wave_composition_is_valid := false
	var vortex_moves_toward_diver := false
	var sampled_vortex_motion := false
	var sampled_final_click_window := false
	var special_stage_has_depth := false
	var every_live_target_was_aimable := true
	var closest_wave_distance := INF
	var widest_vortex_radius := 0.0
	var forced_one_timeout := false

	var minigame: GrappleInterceptMinigame = null
	var deadline := Time.get_ticks_msec() + 16000
	while Time.get_ticks_msec() < deadline:
		if minigame == null or not is_instance_valid(minigame):
			for child in battle.get_children():
				if child is GrappleInterceptMinigame:
					minigame = child as GrappleInterceptMinigame
					minigame.finished.connect(func(hits: int, total: int) -> void: result = [hits, total])
					minigame.object_hit.connect(func() -> void: timed_out_wave_impacts += 1)
					break
		if minigame != null and is_instance_valid(minigame):
			special_stage_has_depth = minigame.enemy_actor.global_position.distance_to(minigame.target_actor.global_position) >= 6.5
			# This is the regression that the old all-clear test could never
			# catch: a live wave must contain two spheres of each color and must
			# deal Battle-owned damage if it arrives uncleared.
			if minigame._vortex_active:
				every_live_target_was_aimable = every_live_target_was_aimable and minigame.vortex_targets_are_aimable()
				closest_wave_distance = minf(closest_wave_distance, minigame._vortex_center.distance_to(minigame.stage_camera.global_position))
				for entry in minigame._vortex_spheres:
					widest_vortex_radius = maxf(widest_vortex_radius, (entry.pos2d as Vector2).length())
			if minigame._vortex_active and not sampled_vortex_motion:
				var start_distance := minigame._vortex_center.distance_to(minigame.stage_camera.global_position)
				await create_timer(0.35).timeout
				var later_distance := minigame._vortex_center.distance_to(minigame.stage_camera.global_position)
				vortex_moves_toward_diver = later_distance < start_distance - 0.05
				sampled_vortex_motion = true
			elif minigame._vortex_active and not sampled_final_click_window:
				# Observe the last playable moment, not merely the launch. A wave
				# that becomes unclickable near the diver is the precise regression
				# this contract prevents.
				await create_timer(GrappleInterceptMinigame.VORTEX_TRAVEL_TIME - 0.45).timeout
				every_live_target_was_aimable = every_live_target_was_aimable and minigame.vortex_targets_are_aimable()
				closest_wave_distance = minf(closest_wave_distance, minigame._vortex_center.distance_to(minigame.stage_camera.global_position))
				for entry in minigame._vortex_spheres:
					widest_vortex_radius = maxf(widest_vortex_radius, (entry.pos2d as Vector2).length())
				sampled_final_click_window = true
			elif minigame._vortex_active and not forced_one_timeout:
				var yellow := 0
				var green := 0
				var safe := 0
				for entry in minigame._vortex_spheres:
					if bool(entry.is_yellow):
						yellow += 1
					else:
						green += 1
					if bool(entry.is_yellow) == minigame._vortex_safe_is_yellow:
						safe += 1
				wave_composition_is_valid = minigame._vortex_spheres.size() == 4 and yellow == 2 and green == 2 and safe == GrappleInterceptMinigame.TARGET_COUNT
				# Exercise the identical timeout callback that the five-second
				# travel tween invokes, without making this regression test wait.
				minigame._on_vortex_reached_player()
				forced_one_timeout = true
				await process_frame
				timed_out_wave_damage = hp_before - (party_entry.stats as CombatantStats).hp
			elif forced_one_timeout:
				minigame.verification_resolve_closest()
		elif not result.is_empty():
			break
		await process_frame

	# finished resumes Battle's coroutine synchronously through camera/model
	# restoration, then pauses at its closing read timer before advancing.
	await process_frame
	var hp_after := (party_entry.stats as CombatantStats).hp
	var actor_visible := (party_entry.actor as Diver).visible
	var camera_restored := battle._stage_cam.global_position.distance_to(default_camera_position) < 0.05 and is_equal_approx(battle._stage_cam.fov, default_camera_fov)
	# MODIFIED: was hardcoded [8, 8] - stale since TARGET_COUNT dropped to
	# 5 (see grapple_intercept_minigame.gd's own header). Read the real
	# constant instead of re-hardcoding a number that can drift again.
	#
	# MODIFIED: TARGET_COUNT is now just ONE vortex wave's worth (2) - the
	# real total across the whole encounter (finished.emit()'s own second
	# argument) is TARGET_COUNT * TOTAL_VORTEX_WAVES.
	var expected := GrappleInterceptMinigame.TARGET_COUNT * GrappleInterceptMinigame.TOTAL_VORTEX_WAVES
	# One intentionally uncleared wave leaves four cleared safe targets across
	# the remaining two waves. Its impact must be the actual Battle damage
	# callback, not merely a minigame-local signal.
	var clean := result == [expected - GrappleInterceptMinigame.TARGET_COUNT, expected] and forced_one_timeout and wave_composition_is_valid and special_stage_has_depth and vortex_moves_toward_diver and sampled_final_click_window and every_live_target_was_aimable and widest_vortex_radius >= 1.45 and closest_wave_distance >= GrappleInterceptMinigame.VORTEX_PLAYER_STANDOFF - 0.1 and closest_wave_distance <= GrappleInterceptMinigame.VORTEX_PLAYER_STANDOFF + 0.5 and timed_out_wave_impacts == 1 and timed_out_wave_damage > 0 and hp_after <= hp_before and actor_visible and camera_restored
	print("GRAPPLE BATTLE: result %s, wave 4=%s, stage depth=%s, moves toward diver=%s, targets aimable=%s, widest radius %.2f, closest wave %.2f, timeout impacts %d, timeout damage %d, HP %d -> %d, camera %s, actor visible %s" % [
		str(result), str(wave_composition_is_valid), str(special_stage_has_depth), str(vortex_moves_toward_diver), str(every_live_target_was_aimable), widest_vortex_radius, closest_wave_distance, timed_out_wave_impacts, timed_out_wave_damage, hp_before, hp_after, str(camera_restored), str(actor_visible)
	])
	if not clean:
		push_error("GRAPPLE BATTLE: integration contract failed")
		quit(1)
		return
	print("GRAPPLE BATTLE: clean")
	quit()
