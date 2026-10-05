extends SceneTree
## Disclosed supplied kit/cleared blockers; browser still swims into the real
## lab, skips its movie normally and wins with ordinary move/target controls.
## No player slot is written. This is not earned campaign/balance evidence.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	world.route_state.set_lab_state("available")
	world.route_state.set_blocker_state("bomb_bot", "defeated")
	world.route_state.set_blocker_state("sword_slayer", "defeated")
	world.route_state.deep_warning_seen = true
	for index in world.divers.size():
		var diver := world.divers[index] as Diver
		while diver.stats.level < 5:
			diver.stats.gain_xp(10)
		SpellTree.learn_all_available(diver, [])
		diver.sonar_active = false
		diver.global_position = world.deep_zone_layout.route_points().lab + Vector3(-9.0, 0, float(index) * 2.0)
		diver.velocity = Vector3.ZERO
	# World camera starts at yaw0 on Load: A moves +X toward the office.
	# No test-only camera state is required or forced into the runtime.
	await physics_frame
	assert(not world.battling and world.route_state.lab_state == "available", "Fixture entered lab before actual browser swim")
	assert(world.embedded_maze.can_capture_campaign_snapshot()
		and world.divers.all(func(d: Diver) -> bool: return not d.is_grappling() and not d.is_suction_locked()),
		"Lab browser fixture has a transient movement/puzzle")
	var data := world._serialize_state()
	assert(CampaignCheckpoint.decode(data) != null, "Lab browser fixture is invalid")
	var file := FileAccess.open("/tmp/campaign-lab-browser-fixture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	world.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	print("LAB BROWSER FIXTURE: supplied legal level-five kit/cleared blockers, west of unlocked lab; no player slot written")
	quit()
