# INT-04: live return and World checkpoint history must not reset the maze,
# refill party resources or teleport immediately back through the entrance.
# Trigger placement/lab flags are fixtures, not full navigation/balance proof.
extends SceneTree

const SLOT_BASE := 918319
var findings: Array[String] = []
var owned_slots: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for i in range(12):
		if SaveManager.slot_exists(SLOT_BASE + i):
			findings.append("INT-04 return fixture slot exists; refusing overwrite")
			await _finish()
			return
	for active in range(3):
		for downed in [false, true]:
			for lab_first in [false, true]:
				await _case(active, downed, lab_first)
				if not findings.is_empty():
					await _finish()
					return
	await _finish()

func _case(selected: int, downed: bool, lab_first: bool) -> void:
	var slot := SLOT_BASE + owned_slots.size()
	owned_slots.append(slot)
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.save_point_menu.save_requested.emit(world.divers[0], slot)
	world.random_encounters_enabled = false
	world.inventory = {"potion": 3}
	world.key_items.assign(["current_pearl"])
	world.route_state.set_zone("deep")
	world.route_state.set_maze_door_state("available")
	if lab_first:
		world.route_state.set_blocker_state("bomb_bot", "defeated")
		world.route_state.set_blocker_state("sword_slayer", "defeated")
		world.route_state.set_lab_state("cleared")
		world.route_state.set_tethys_state("defeated")
	world.active = selected
	var downed_index := (selected + 1) % 3
	for i in range(3):
		world.divers[i].stats.hp = 4 + i
		world.divers[i].stats.oxygen = 70.5 + i
		world.divers[i].stats.spell_points = 3
		SpellTree.learn_all_available(world.divers[i], world.key_items)
	if downed:
		world.divers[downed_index].stats.hp = 0
	world.divers[selected].global_position = world.deep_zone_layout.route_points().maze_transition
	for frame in range(16):
		await physics_frame
		if current_scene is MazeLevel:
			break
	if not current_scene is MazeLevel:
		findings.append("INT-04 return setup: actual World entrance did not reach Maze")
		return
	var maze := current_scene as MazeLevel
	var exit := maze.get_node_or_null("CampaignExit") as Node3D
	if exit == null:
		findings.append("INT-04: maze has no explicit normally reachable World return")
		return
	maze.keys_held = 1
	maze.key_items.assign(["vortex_key"])
	var door := maze.get_node("MazeDoor16") as KeyDoor
	maze.divers[selected].global_position = door.global_position + Vector3.UP
	_expect(door.interact(maze.divers[selected]), "INT-04 return setup: real door did not consume key")
	await create_timer(1.5).timeout
	maze.inventory["potion"] = 5
	var resources: Array = []
	var kit: Array = []
	for diver in maze.divers:
		resources.append(diver.stats)
		kit.append(diver.known_spells.duplicate())
	maze.divers[selected].global_position = exit.global_position + Vector3.UP
	await _key(KEY_E)
	for frame in range(16):
		await physics_frame
		if current_scene is World:
			break
	if not current_scene is World:
		findings.append("INT-04: E at the maze exit does not restore World")
		return
	var returned := current_scene as World
	_expect(not paused and not returned.title_screen.visible and returned.opening_video == null,
		"INT-04: live return opens title/movie instead of controllable World")
	_expect(returned.active == selected and int(returned.inventory.get("potion", 0)) == 5
		and returned.key_items == ["current_pearl"] and not returned.random_encounters_enabled,
		"INT-04: return loses active/inventory/relic/preference")
	for i in range(3):
		_expect(returned.divers[i].stats == resources[i] and returned.divers[i].known_spells == kit[i],
			"INT-04: live return reconstructs resource identity or earned kit")
		_expect(returned.divers[i].stats.hp == (0 if downed and i == downed_index else 4 + i),
			"INT-04: live return heals or revives without rest")
		_expect(absf(returned.divers[i].stats.oxygen - (70.5 + i)) < 0.05,
			"INT-04: live return refills Oxygen")
	_expect(returned.route_state.tethys_state == ("defeated" if lab_first else "locked")
		and returned.route_state.bomb_bot_state == ("defeated" if lab_first else "available"),
		"INT-04: independent lab progression is reset/conflated")
	for frame in range(12):
		await physics_frame
	_expect(current_scene == returned, "INT-04: World return spawns inside entrance and bounces back to Maze")
	if not findings.is_empty():
		return
	# Public Save menu contract intentionally uses an isolated non-user slot.
	returned.save_point_menu.save_requested.emit(returned.divers[selected], slot)
	await process_frame
	returned.queue_free()
	await process_frame
	var cold := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(cold)
	current_scene = cold
	await process_frame
	cold.title_screen.load_game_chosen.emit(slot)
	for frame in range(12):
		await physics_frame
	_expect(current_scene == cold and not paused and cold.opening_video == null,
		"INT-04: World checkpoint with maze history loads wrong scene/opening")
	_expect(cold.route_state.tethys_state == ("defeated" if lab_first else "locked"),
		"INT-04: World history Load changes independent lab state")
	cold.divers[selected].global_position = cold.deep_zone_layout.route_points().maze_transition
	for frame in range(16):
		await physics_frame
		if current_scene is MazeLevel:
			break
	if not current_scene is MazeLevel:
		findings.append("INT-04: cold World continuation cannot re-enter Maze")
		return
	var reentered := current_scene as MazeLevel
	var reloaded_door := reentered.get_node("MazeDoor16") as KeyDoor
	_expect(reloaded_door.is_open() and not reloaded_door.is_collision_blocking() and reentered.keys_held == 0,
		"INT-04: saved World history forgets open door/spent key on re-entry")
	_expect(int(reentered.inventory.get("potion", 0)) == 5 and reentered.campaign_key_items == ["current_pearl"],
		"INT-04: re-entry reconstructs inventory or mixes campaign relics")
	_expect(reentered.divers.all(func(d: Diver) -> bool: return d.stats.hp == d.stats.hp_max),
		"INT-04: actual World rest checkpoint did not restore party")
	print("MAZE WORLD RETURN CASE|active=", selected, "|downed=", downed, "|lab_first=", lab_first)
	current_scene.queue_free()
	await process_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for slot in owned_slots:
		DirAccess.remove_absolute(SaveManager.slot_path(slot))
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE WORLD RETURN: 12 cases clean" if findings.is_empty() else "MAZE WORLD RETURN: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
