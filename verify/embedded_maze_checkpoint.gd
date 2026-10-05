# EMBED-3: migrate old maze checkpoints and conserve independent World/maze
# state through real JSON and cold Title Load. Never touch player slots.
extends SceneTree

const SLOT := 918359
var owns_slot := false
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if SaveManager.slot_exists(SLOT):
		push_error("EMBED-3 disposable slot exists; refusing overwrite")
		quit(1)
		return
	var world := await _world()
	var maze := world.embedded_maze
	var actors := world.divers.duplicate()
	world.route_state.prologue_complete = true
	world.route_state.opening_video_seen = true
	world.route_state.set_prologue_phase("complete")
	world.route_state.deep_warning_seen = true
	world.route_state.set_zone("deep")
	world.random_encounters_enabled = false
	maze.key_items.assign(["maze_nav_map", "sphere_room_key"])
	maze.keys_held = 2
	var cases := 0
	var last: Dictionary
	for selected in range(3):
		for pattern in range(8):
			for scene in ["world", "maze"]:
				world.active = selected
				maze.active = selected
				maze._diver = world.divers[selected]
				maze.set_maze_active(scene == "maze")
				maze.set_physics_process(false)
				world.route_state.set_zone(scene if scene == "maze" else "deep")
				world.route_state.set_lab_state("cleared" if pattern % 3 == 0 else "locked")
				world.inventory["potion"] = pattern
				for i in range(3):
					var actor := world.divers[i] as Diver
					actor.global_position = Vector3(265 if scene == "maze" else 220, 2, 14 + i * 2)
					actor.stats.hp = 0 if pattern & (1 << i) else 3 + i
					actor.stats.oxygen = 0.0 if pattern % 2 else 13.25 + i
					actor.stats.evasion_current = i
					actor.stats.statuses = {"bleed": {"level": i + 1, "turns": 2}}
					actor.stats.temporary_modifiers = {"accuracy": -i, "evasion": 0}
					actor.sonar_active = false
				var data := world._serialize_state()
				var expected := data.duplicate(true)
				if cases == 0:
					print("EMBED_SAVE_PREFLIGHT|maze_valid=", CampaignCheckpoint.valid_maze(data.campaign_checkpoint.maze),
						"|runtime=", maze.snapshot_matches_runtime(data.campaign_checkpoint.maze),
						"|decode=", CampaignCheckpoint.decode(data) != null)
				# Missing origin is a pre-embedding maze checkpoint. An outer
				# World save must NOT translate its World actor positions.
				if pattern % 2:
					data.campaign_checkpoint.maze = MazeCoordinateFrame.rebase(data.campaign_checkpoint.maze, Vector3.ZERO)
					data.campaign_checkpoint.maze.erase("coordinate_origin")
				var label := "EMBED-3 active=%d downed=%d scene=%s" % [selected, pattern, scene]
				_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(data))), label + " rejected valid checkpoint")
				_expect(world.active == selected and world.inventory["potion"] == pattern
					and maze.keys_held == 2 and maze.key_items == ["maze_nav_map", "sphere_room_key"],
					label + " lost selected diver, consumables or independent maze/map keys")
				for i in range(3):
					_expect(world.divers[i] == actors[i], label + " replaced a shared actor during restore")
					var position: Array = expected.divers[i].position
					_expect(world.divers[i].global_position.distance_to(Vector3(position[0], position[1], position[2])) < 0.001,
						label + " actor restored into the wrong coordinate frame")
					var stats := world.divers[i].stats as CombatantStats
					_expect(stats.hp == (0 if pattern & (1 << i) else 3 + i)
						and is_equal_approx(stats.oxygen, 0.0 if pattern % 2 else 13.25 + i)
						and stats.evasion_current == i and stats.statuses.size() == 1
						and int(stats.statuses.get("bleed", {}).get("level", -1)) == i + 1
						and int(stats.statuses.get("bleed", {}).get("turns", -1)) == 2
						and int(stats.temporary_modifiers.get("accuracy", 999)) == -i
						and int(stats.temporary_modifiers.get("evasion", 999)) == 0,
						label + " refilled or lost party resources/statuses")
				var wall := maze.get_node("CurrentWall1") as CSGBox3D
				var saved_wall: Array = expected.campaign_checkpoint.maze.walls.CurrentWall1.position
				_expect(wall.global_position.distance_to(Vector3(saved_wall[0], saved_wall[1], saved_wall[2])) < 0.001,
					label + " maze geometry restored at standalone coordinates")
				last = data
				cases += 1
				if not findings.is_empty():
					await _finish(world)
					return
	print("EMBED_CHECKPOINT|generated_cases=", cases, "|legacy_origin_cases=24|World_and_maze_locations=true")
	if not findings.is_empty():
		await _finish(world)
		return
	# Real file -> fresh World -> Title Load. One living active character,
	# intentionally depleted resources: this is migration proof, not balance.
	last.campaign_checkpoint.party[2].stats.hp = 5
	last.divers[2].stats.hp = 5
	_expect(SaveManager.write_slot(SLOT, last) == OK, "EMBED-3 could not write disposable fixture")
	owns_slot = SaveManager.slot_exists(SLOT)
	world.queue_free()
	await process_frame
	world = await _world()
	world.title_screen.load_game_chosen.emit(SLOT)
	for frame in range(12):
		await process_frame
	maze = world.embedded_maze
	_expect(current_scene == world and maze.maze_active and not paused and not world.title_screen.visible,
		"EMBED-3 cold maze Load still changes scene or leaves title paused")
	_expect(root.get_viewport().get_camera_3d() == maze.get_node("Camera3D")
		and world._current_slot == SLOT and maze.campaign_session.selected_slot == SLOT,
		"EMBED-3 cold maze Load loses camera or selected checkpoint ownership")
	_expect(maze._diver.global_position.distance_to(Vector3(265, 2, 18)) < 0.001
		and maze.divers[2] == world.divers[2] and maze.divers[2].stats.hp == 5
		and maze.key_items.has("maze_nav_map") and maze.keys_held == 2,
		"EMBED-3 cold old save loses playable position, party or earned map")
	print("EMBED_COLD_LOAD|slot=", SLOT, "|legacy_standalone=true|scene=World|owner=Maze|player_slots_untouched=true")
	await _finish(world)

func _world() -> World:
	var world := load("res://game/world.tscn").instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	world.set_physics_process(false)
	world.embedded_maze.set_physics_process(false)
	for actor in world.divers:
		actor.set_physics_process(false)
	return world

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
		push_error(message)

func _finish(world: World) -> void:
	world.queue_free()
	await process_frame
	if owns_slot:
		DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	print("EMBEDDED CHECKPOINT: clean" if findings.is_empty() else "EMBEDDED CHECKPOINT: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
