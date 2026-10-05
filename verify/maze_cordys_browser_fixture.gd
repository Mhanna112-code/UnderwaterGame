extends SceneTree
## Disclosed room fixture for actual exported Title Load/W/No/Yes testing.
## Does not prove earning a key, reaching the room or browser save durability.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").show()
	paused = false
	world.random_encounters_enabled = false
	# Ending-isolation fixture: legal unlocks are supplied, not earned. The
	# browser must still confirm, choose ordinary moves and win the real fight.
	var ending := "--ending" in OS.get_cmdline_user_args()
	if ending:
		for diver in world.divers:
			while diver.stats.level < 5:
				diver.stats.gain_xp(10)
			SpellTree.learn_all_available(diver, [])
	world._set_maze_ownership(true)
	var maze := world.embedded_maze
	var door := maze.get_node("MazeDoorMainBoss") as KeyDoor
	maze.keys_held = 1
	maze._diver.global_position = door.global_position + Vector3(-1.5, 1.2, 0)
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key = InputEventKey.new()
	key.keycode = KEY_E
	Input.parse_input_event(key)
	await create_timer(1.5).timeout
	assert(door.is_open(), "Fixture failed to unlock actual main-room door")
	var station := maze._boss_triggers.get("main_boss") as Node3D
	for index in 3:
		maze.divers[index].global_position = station.global_position + Vector3(-10, 1.2, float(index) * 2.0)
		maze.divers[index].velocity = Vector3.ZERO
	maze._yaw = PI / 2.0
	maze._pitch = -0.16
	world.yaw = maze._yaw
	world.pitch = maze._pitch
	await physics_frame
	assert(maze.can_capture_campaign_snapshot(), "Fixture is not a stable campaign state")
	var fixture_path := "/tmp/campaign-ending-browser-fixture.json" if ending else "/tmp/cordys-maze-browser-fixture.json"
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(world._serialize_state()))
	file.close()
	world.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	print("CORDYS BROWSER FIXTURE: isolated recovered campaign, supplied key spent through E; ending legal-kit supplied=" + str(ending))
	quit()
