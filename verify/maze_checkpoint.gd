# INT-04: genuine save-point request and cold title Load must restore one
# maze checkpoint, not a World party with discarded maze progress.
# Setup skips opening/places actors near real triggers; not traversal proof.
extends SceneTree

const SLOT := 918317
var findings: Array[String] = []
var owns_slot := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if SaveManager.slot_exists(SLOT):
		findings.append("INT-04 uniquely owned test slot exists; refusing overwrite")
		await _finish()
		return
	owns_slot = true
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	# Completed-opening fixture, without the review route's onboarding modal.
	world.title_screen.close()
	paused = false
	world.save_point_menu.save_requested.emit(world.divers[0], SLOT)
	world.route_state.set_zone("deep")
	world.route_state.set_maze_door_state("available")
	world.inventory = {"potion": 3}
	world.key_items.assign(["current_pearl"])
	world.divers[1].stats.hp = 0
	world.divers[2].stats.oxygen = 23.5
	world.divers[0].global_position = world.deep_zone_layout.route_points().maze_transition
	for frame in range(14):
		await physics_frame
		if current_scene is MazeLevel:
			break
	if not current_scene is MazeLevel:
		findings.append("INT-04 setup: normal entrance did not reach MazeLevel")
		await _finish()
		return
	var maze := current_scene as MazeLevel
	var point: SavePoint
	for child in maze.get_children():
		if child is SavePoint:
			point = child as SavePoint
	if point == null:
		findings.append("INT-04: normal maze has no identifiable save/recovery point")
		await _finish()
		return
	var set_spec: Dictionary = maze.rotatable_wall_sets()[0]
	(set_spec.rotate as Callable).call()
	await create_timer(2.2).timeout
	var opened_wall := (maze.get_node("CurrentWall1") as Node3D).global_transform
	maze.keys_held = 1
	maze.key_items.assign(["vortex_key"])
	var door := maze.get_node("MazeDoor16") as KeyDoor
	maze.divers[0].global_position = door.global_position + Vector3(0, 1, 0)
	_expect(door.interact(maze.divers[0]), "INT-04 setup: key door refused actual interaction")
	await create_timer(1.5).timeout
	var reward_spot := (maze.get_node("ItemRock2") as Node3D).global_position
	for child in maze.get_children():
		if child is CrackedWall and (child as Node3D).global_position.distance_to(reward_spot) < 0.01:
			(child as CrackedWall).on_shockwave(reward_spot, 1.0)
	await process_frame
	maze.divers[0].global_position = point.global_position
	for frame in range(6):
		await physics_frame
	_expect(maze.divers[1].stats.hp == maze.divers[1].stats.hp_max,
		"INT-04: maze checkpoint contact does not revive a downed companion")
	await _key(KEY_P)
	var menu := _save_menu(maze)
	if menu == null or not menu.visible:
		findings.append("INT-04: P at the maze save point does not expose SavePointMenu")
		await _finish()
		return
	# Public UI contract; isolated slot intentionally outside the three user slots.
	menu.save_requested.emit(maze.divers[0], SLOT)
	for frame in range(6):
		await process_frame
	var saved := SaveManager.read_slot(SLOT)
	_expect(saved.get("campaign_scene", "world") == "maze", "INT-04: save is not identified as a maze checkpoint")
	var pending_path := SaveManager.slot_path(SLOT) + ".pending"
	if FileAccess.file_exists(pending_path) or DirAccess.dir_exists_absolute(pending_path):
		findings.append("INT-04 failure fixture pending path exists; refusing to replace it")
	else:
		# True FileAccess failure at the IO boundary, without mocking the saver.
		var checkpoint_bytes := FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT))
		_expect(DirAccess.make_dir_recursive_absolute(pending_path) == OK, "INT-04 setup: could not create isolated write-rejection fixture")
		maze.inventory = {"potion": 30}
		menu.save_requested.emit(maze.divers[0], SLOT)
		await process_frame
		_expect(FileAccess.get_file_as_bytes(SaveManager.slot_path(SLOT)) == checkpoint_bytes,
			"INT-04 rejected save replaces the last usable checkpoint")
		_expect(maze.campaign_session.selected_slot == SLOT, "INT-04 rejected save changes selected checkpoint")
		_expect(_save_failure(maze), "INT-04 rejected save has no visible failure explanation")
		DirAccess.remove_absolute(pending_path)
	maze.inventory = {"potion": 99}
	maze.divers[1].stats.hp = 0
	maze.keys_held = 99
	maze.queue_free()
	await process_frame
	var cold := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(cold)
	current_scene = cold
	await process_frame
	cold.title_screen.load_game_chosen.emit(SLOT)
	for frame in range(16):
		await process_frame
		if current_scene is MazeLevel:
			break
	if not current_scene is MazeLevel:
		findings.append("INT-04: cold Load discards the saved maze and returns to World")
	else:
		var loaded := current_scene as MazeLevel
		print("MAZE CHECKPOINT RESTORED|inventory=", loaded.inventory, "|keys=", loaded.keys_held)
		_expect(loaded.inventory.size() == 1 and int(loaded.inventory.get("potion", 0)) == 3 and loaded.keys_held == 0,
			"INT-04: saved inventory and spent keys do not roll back together")
		_expect(loaded.campaign_key_items == ["current_pearl"], "INT-04: spell relic mixed with maze keys")
		_expect(loaded.route_state.prologue_complete and not paused,
			"INT-04: completed opening replayed or loaded maze stayed paused")
		_expect(loaded.divers[1].stats.hp == loaded.divers[1].stats.hp_max,
			"INT-04: unsaved downed companion survives checkpoint rollback")
		_expect((loaded.get_node("CurrentWall1") as Node3D).global_transform.is_equal_approx(opened_wall),
			"INT-04: saved open hallway resets on cold Load")
		var loaded_door := loaded.get_node("MazeDoor16") as KeyDoor
		_expect(loaded_door.is_open() and not loaded_door.is_collision_blocking(),
			"INT-04: saved spent key reloads with a closed/blocking door")
		var count := 0
		for child in loaded.get_children():
			if child is ItemOrb and (child as ItemOrb).item_id == "sphere_room_key":
				count += 1
			if child is CrackedWall and (child as Node3D).global_position.distance_to(reward_spot) < 0.01:
				findings.append("INT-04: consumed reward rock respawns on cold Load")
		_expect(count == 1, "INT-04: pending key reward is lost or duplicated on cold Load")
		if findings.is_empty():
			await _real_defeat_and_restart(loaded, opened_wall)
	await _finish()

func _real_defeat_and_restart(maze: MazeLevel, wall: Transform3D) -> void:
	# An attainable wounded party, not inflated stats or an injected outcome.
	# Trigger placement is a fixture; the production boss resolves all damage.
	var previous_speed := Engine.time_scale
	Engine.time_scale = 8.0
	var loss_seed := 970405
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--loss-seed="):
			loss_seed = int(arg.trim_prefix("--loss-seed="))
	seed(loss_seed)
	maze.inventory = {"potion": 99}
	maze.keys_held = 99
	for diver in maze.divers:
		diver.stats.hp = 1
	var sigil := maze.get_node("BossSigil_main_boss") as Node3D
	maze.divers[maze.active].global_position = sigil.global_position + Vector3.UP
	var screen: GameOverScreen
	var attacks := 0
	var outcomes: Array[String] = []
	var observed_battle: Battle
	var captions := 0
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		screen = _recovery_screen(maze)
		if screen != null and screen.visible:
			break
		var battle: Battle
		for child in maze.get_children():
			if child is Battle:
				battle = child as Battle
		# Ordinary enemy QTEs can expose a one-time Continue explanation.
		# Read/continue it through the real button, but never press the QTE:
		# its normal timeout still delivers damage. Ignoring this legitimate
		# input owner made a waiting fight look like broken death recovery.
		if battle != null and battle._tutorial_continue_btn.is_visible_in_tree() \
			and not battle._tutorial_continue_btn.disabled:
			battle._tutorial_continue_btn.pressed.emit()
			captions += 1
			await process_frame
		if battle != null and battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled:
			if observed_battle != battle:
				observed_battle = battle
				battle.finished.connect(func(result: String) -> void: outcomes.append(result))
			battle.attack_btn.pressed.emit()
			await process_frame
			for button in battle.move_buttons:
				if (button as Button).is_visible_in_tree() and not (button as Button).disabled:
					(button as Button).pressed.emit()
					await process_frame
					if not battle.target_buttons.is_empty():
						(battle.target_buttons[0] as Button).pressed.emit()
						attacks += 1
					break
		await process_frame
	Engine.time_scale = previous_speed
	_expect(screen != null and screen.visible and paused, "INT-04: real maze defeat has no exclusive checkpoint recovery screen")
	_expect(maze.divers.all(func(d: Diver) -> bool: return d.stats.hp == 0), "INT-04: defeat silently revives party instead of awaiting recovery")
	print("MAZE CHECKPOINT REAL LOSS|player_actions=", attacks, "|captions_continued=", captions, "|outcomes=", outcomes,
		"|HP=", maze.divers.map(func(d: Diver) -> int: return d.stats.hp), "|battle_kind=", maze._battle_kind)
	if screen == null or not screen.visible:
		return
	screen.restart_chosen.emit()
	for frame in range(24):
		await process_frame
		if current_scene is MazeLevel and current_scene != maze:
			break
	if not current_scene is MazeLevel or current_scene == maze:
		findings.append("INT-04: Restart does not rebuild the saved maze")
		return
	var restored := current_scene as MazeLevel
	_expect(restored.route_state.prologue_complete and not paused, "INT-04: Restart replays opening or leaves maze frozen")
	_expect(restored.keys_held == 0 and int(restored.inventory.get("potion", 0)) == 3,
		"INT-04: Restart retains unsaved inventory/key changes")
	_expect(restored.divers.all(func(d: Diver) -> bool: return d.stats.hp == d.stats.hp_max),
		"INT-04: Restart does not restore saved party health")
	_expect((restored.get_node("CurrentWall1") as Node3D).global_transform.is_equal_approx(wall),
		"INT-04: Restart resets saved puzzle geometry")

func _recovery_screen(node: Node) -> GameOverScreen:
	if node is GameOverScreen:
		return node as GameOverScreen
	for child in node.get_children():
		var screen := _recovery_screen(child)
		if screen != null:
			return screen
	return null

func _save_menu(node: Node) -> SavePointMenu:
	if node is SavePointMenu:
		return node as SavePointMenu
	for child in node.get_children():
		var menu := _save_menu(child)
		if menu != null:
			return menu
	return null

func _save_failure(node: Node) -> bool:
	if node is Label and (node as Label).is_visible_in_tree() and (node as Label).text.contains("Could not save"):
		return true
	for child in node.get_children():
		if _save_failure(child):
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
	if owns_slot:
		DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	for finding in findings:
		print("FINDING  " + finding)
	print("MAZE CHECKPOINT: clean" if findings.is_empty() else "MAZE CHECKPOINT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
