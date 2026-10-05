# INT-02: a genuine E/Esc excursion must not reset maze or campaign state.
# Placement and starting keys are fixtures, not proof of puzzle traversal.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	await process_frame
	maze.active = 2
	# Use Tab through the actual handler to update its active camera/actor.
	maze.active = 1
	await _key(KEY_TAB)
	maze.divers[0].stats.hp = 6
	maze.divers[1].stats.hp = 0
	maze.divers[2].stats.hp = 4
	maze.divers[2].stats.oxygen = 43.25
	maze.inventory = {"potion": 3}
	maze.keys_held = 3
	maze.key_items.assign(["sphere_room_key", "vortex_key", "abyss_key"])
	var wall_homes: Dictionary = {}
	var wall_opened: Dictionary = {}
	for chosen in maze.rotatable_wall_sets():
		for wall in chosen.walls:
			wall_homes[String(wall.name)] = (wall as Node3D).global_transform
		(chosen.rotate as Callable).call()
		await create_timer(2.2).timeout
		for wall in chosen.walls:
			wall_opened[String(wall.name)] = (wall as Node3D).global_transform
	var door := maze.get_node("MazeDoor16") as KeyDoor
	maze.divers[2].global_position = door.global_position + Vector3(0, 1, 0)
	_expect(door.interact(maze.divers[2]), "INT-02 setup: real key door refused interaction")
	await create_timer(1.5).timeout
	_expect(door.is_open() and not door.is_collision_blocking() and maze.keys_held == 2,
		"INT-02 setup: door did not open and consume exactly one key")
	var reward_spot := (maze.get_node("ItemRock2") as Node3D).global_position
	var rock: CrackedWall
	for child in maze.get_children():
		if child is CrackedWall and (child as CrackedWall).global_position.distance_to(reward_spot) < 0.01:
			rock = child as CrackedWall
	if rock == null:
		findings.append("INT-02 setup: reward rock missing")
	else:
		rock.on_shockwave(reward_spot, 1.0)
	await process_frame
	_expect(_pending_key(maze, reward_spot), "INT-02 setup: broken rock did not leave the expected loose key")
	var panel := maze.get_node_or_null("SecretWallEntrance") as Node3D
	if panel == null:
		findings.append("INT-02: normal maze never builds its secret excursion entrance")
		await _finish()
		return
	var face := float(panel.get_meta("face"))
	maze.divers[2].global_position = panel.global_position + Vector3(face * 1.5, 0, 0)
	await _key(KEY_E)
	for frame in range(8):
		await process_frame
		if current_scene is FlowField:
			break
	if not current_scene is FlowField:
		findings.append("INT-02: E at secret panel did not enter the actual excursion")
	else:
		var secret := current_scene as FlowField
		_expect(secret.diver.model_name == "Prototype_V(1922)", "INT-02: wrong diver entered secret scene")
		_expect(secret.diver.stats.hp == 4 and absf(secret.diver.stats.oxygen - 43.25) < 1,
			"INT-02: secret entry refilled the active diver")
		await _key(KEY_ESCAPE)
		for frame in range(8):
			await process_frame
			if current_scene is MazeLevel:
				break
		if not current_scene is MazeLevel:
			findings.append("INT-02: Esc did not return to MazeLevel")
		else:
			var returned := current_scene as MazeLevel
			_expect(returned.active == 2, "INT-02: return selected a different diver")
			_expect(returned.inventory == {"potion": 3} and returned.keys_held == 2,
				"INT-02: return erased inventory or refunded/spent a maze key")
			_expect(returned.divers[0].stats.hp == 6 and returned.divers[1].stats.hp == 0
				and returned.divers[2].stats.hp == 4, "INT-02: party damage/downed state reset")
			var returned_door := returned.get_node("MazeDoor16") as KeyDoor
			await process_frame
			_expect(returned_door.is_open() and not returned_door.is_collision_blocking(),
				"INT-02: opened door closed again or blocks passage")
			for wall_name in wall_opened:
				_expect((returned.get_node(wall_name) as Node3D).global_transform.is_equal_approx(wall_opened[wall_name]),
					"INT-02: physical puzzle wall reset: " + wall_name)
			_expect(_pending_key(returned, reward_spot), "INT-02: uncollected reward disappeared")
			for child in returned.get_children():
				if child is CrackedWall and (child as CrackedWall).global_position.distance_to(reward_spot) < 0.01:
					findings.append("INT-02: consumed reward rock respawned")
			for return_set in returned.rotatable_wall_sets():
				(return_set.rotate as Callable).call()
				await create_timer(2.2).timeout
				for wall in return_set.walls:
					_expect((wall as Node3D).global_transform.is_equal_approx(wall_homes[String(wall.name)]),
						"INT-02: restored wall cannot rotate back to its real home: " + String(wall.name))
	await _finish()

func _finish() -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE SECRET CONTINUITY: clean" if findings.is_empty() else "MAZE SECRET CONTINUITY: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _pending_key(scene: Node, spot: Vector3) -> bool:
	for child in scene.get_children():
		if child is ItemOrb and (child as ItemOrb).item_id == "sphere_room_key" and (child as ItemOrb).global_position.distance_to(spot) < 0.1:
			return true
	return false

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
