extends SceneTree
## INT-06: real keys must not stack map/checkpoint/swap owners.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for selected in range(3):
		var maze := await _enter(selected)
		if maze != null:
			await _map_checkpoint(maze)
			if findings.is_empty():
				await _save_owner(maze, selected)
				await _swap_owner(maze, selected)
				await _map_geometry(maze)
				await _room_policy(maze, selected)
			maze.world.queue_free()
			await process_frame
		if not findings.is_empty():
			break
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE INPUT OWNERSHIP: clean" if findings.is_empty() else "MAZE INPUT OWNERSHIP: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _enter(selected: int) -> MazeLevel:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	world.route_state.set_zone("deep")
	world.route_state.set_maze_door_state("available")
	world.active = selected
	var maze := world.embedded_maze
	world.divers[selected].global_position = Vector3(maze.embedded_bounds.position.x - 1.5, 1.8, 16)
	world.yaw = PI * 0.5
	var swim := InputEventKey.new()
	swim.keycode = KEY_W
	swim.pressed = true
	Input.parse_input_event(swim)
	for frame in range(35):
		await physics_frame
		if maze.maze_active:
			break
	swim = InputEventKey.new()
	swim.keycode = KEY_W
	Input.parse_input_event(swim)
	await physics_frame
	if current_scene != world or not maze.maze_active:
		findings.append("INT-06 fixture actual World entrance did not reach Maze")
		world.queue_free()
		await process_frame
		return null
	# Input composition fixture after acquisition; marc_earned_map exercises
	# earning the map through actual swimming/E rather than this grant.
	maze.key_items.append("maze_nav_map")
	for i in range(3):
		maze.divers[i].global_position = maze.get_node("MazeCheckpoint").global_position + Vector3(3 * (i - selected), 1.8, 0)
		maze.divers[i].velocity = Vector3.ZERO
	for frame in range(8):
		await physics_frame
	return maze

func _map_checkpoint(maze: MazeLevel) -> void:
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	await _key(KEY_L)
	_expect(map.main_map.visible, "INT-06 L did not open real overview")
	await _key(KEY_P)
	_expect(map.main_map.visible and not maze._save_menu.visible,
		"INT-06 P stacks checkpoint menu onto open maze map")
	await _key(KEY_ESCAPE)
	_expect(map.main_map.visible and not maze.inventory_menu.visible,
		"INT-06 Esc stacks inventory onto open maze map")
	var active := maze.active
	await _key(KEY_TAB)
	_expect(maze.active == active, "INT-06 map Tab steals active diver")
	await _key(KEY_F)
	_expect(not maze.target_selector.selecting and maze.divers[active].can_use_ability(),
		"CTL-3 map F leaks exploration ability through overview ownership")
	await _key(KEY_L)
	_expect(not map.main_map.visible, "INT-06 map cannot relinquish ownership with L")
	print("MAZE INPUT CASE|active=", active, "|owner=map")

func _save_owner(maze: MazeLevel, selected: int) -> void:
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	await _key(KEY_P)
	_expect(maze._save_menu.visible, "INT-06 real checkpoint P did not open save owner")
	await _key(KEY_L)
	await _key(KEY_TAB)
	await _key(KEY_E)
	await _key(KEY_F)
	await _key(KEY_R)
	_expect(maze._save_menu.visible and not map.main_map.visible and maze.active == selected
		and not maze.target_selector.selecting and not maze.inventory_menu.visible and not maze.random_encounters_enabled,
		"INT-06 save owner leaked map/diver/ability input")
	await _key(KEY_ESCAPE)
	_expect(not maze._save_menu.visible and not maze.inventory_menu.visible,
		"INT-06 closing save owner also opens inventory")
	print("MAZE INPUT CASE|active=", selected, "|owner=save")

func _swap_owner(maze: MazeLevel, selected: int) -> void:
	# Public selector activation is a fixture; only Maxilani uses Swap in play.
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	_expect(maze.target_selector.start_selection(maze.divers[selected]), "INT-06 selector has no valid target")
	var first := maze.target_selector.current_target()
	await _key(KEY_L)
	await _key(KEY_P)
	await _key(KEY_TAB)
	await _key(KEY_R)
	await _key(KEY_F)
	_expect(maze.target_selector.selecting and not map.main_map.visible and not maze._save_menu.visible
		and not maze.inventory_menu.visible and maze.active == selected and not maze.random_encounters_enabled,
		"INT-06 Swap owner leaked map/save/diver input")
	await _key(KEY_RIGHT)
	_expect(maze.target_selector.current_target() != first, "INT-06 real arrow did not cycle Swap target")
	await _key(KEY_ESCAPE)
	_expect(not maze.target_selector.selecting and not maze.inventory_menu.visible,
		"INT-06 cancelling Swap also opens inventory")
	print("MAZE INPUT CASE|active=", selected, "|owner=swap")

func _map_geometry(maze: MazeLevel) -> void:
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	var corridor := maze.get_node("WindCorridor1") as Area3D
	var shape: CollisionShape3D
	for child in corridor.get_children():
		if child is CollisionShape3D:
			shape = child as CollisionShape3D
	if shape == null:
		findings.append("INT-06 fixture corridor has no physical push area")
		return
	var centre := shape.global_position
	maze.divers[maze.active].global_position = centre
	for frame in range(4):
		await physics_frame
		await process_frame
	await _key(KEY_L)
	var selected_current := map.selectedCurrentCorridor
	_expect(selected_current != null and not map.selected_rotatable_set.is_empty(),
		"INT-06 actual discovery did not expose nearby current/wall controls")
	if selected_current != null:
		var current: WaterCurrent = maze._currents_by_corridor[selected_current]
		var walls: Array[Transform3D] = []
		for wall in map.selected_rotatable_set.get("walls", []):
			walls.append((wall as Node3D).global_transform)
		await _key(KEY_E, true)
		_expect(map.selectedCurrentCorridor != selected_current and maze._currents_by_corridor.values().has(current)
			and not maze.random_encounters_enabled,
			"MAP-1 Ctrl+E did not move the same live current exclusively")
		for i in walls.size():
			_expect((map.selected_rotatable_set.walls[i] as Node3D).global_transform.is_equal_approx(walls[i]),
				"MAP-1 Ctrl+E rotated walls instead of only the selected current")
		if not findings.is_empty():
			return
		var moved := map.selectedCurrentCorridor
		await _key(KEY_R)
		_expect(maze.random_encounters_enabled and maze.campaign_session.random_encounters_enabled
			and map.selectedCurrentCorridor == moved,
			"MAP-1 open-map R is dead, moves a current, or loses campaign preference")
		await _key(KEY_R)
		_expect(not maze.random_encounters_enabled and not maze.campaign_session.random_encounters_enabled,
			"MAP-1 second open-map R did not turn encounters Off")
	if not map.selected_rotatable_set.is_empty():
		var wall: CSGBox3D = map.selected_rotatable_set.walls[0]
		var before := wall.global_transform
		await _key(KEY_E)
		await create_timer(1.7).timeout
		_expect(not wall.global_transform.is_equal_approx(before) and not maze.target_selector.selecting
			and not maze._save_menu.visible and not maze._battling,
			"INT-06 map E did not rotate real wall exclusively")
	await _key(KEY_L)
	await _key(KEY_R)
	_expect(maze.random_encounters_enabled and maze.campaign_session.random_encounters_enabled,
		"MAP-1 closed-map R did not synchronize preference")
	await _key(KEY_R)
	print("MAZE INPUT GEOMETRY|active=", maze.active, "|real_CtrlE/R/E=checked")

func _room_policy(maze: MazeLevel, selected: int) -> void:
	maze.random_encounters_enabled = false
	maze.room_encounters_enabled = true
	maze.divers[selected].global_position = maze.get_node("MazeCheckpoint").global_position + Vector3.UP
	await physics_frame
	maze.divers[selected].start_random_encounter()
	await process_frame
	_expect(not maze._battling, "INT-06 forced encounter policy leaked outside strong room")
	var room := maze._strong_room_rect()
	maze.divers[selected].global_position = Vector3(room.get_center().x, 0, room.get_center().y)
	await physics_frame
	await process_frame
	var popup := root.get_node_or_null("CharacterAbilityPopup")
	if popup != null and paused:
		(popup.get_node("%PopupClose") as Button).pressed.emit()
		await process_frame
	maze.room_encounters_enabled = false
	await _key(KEY_R)
	_expect(not maze.random_encounters_enabled, "MAP-2 R changes the forced-room encounter preference")
	maze.divers[selected].start_random_encounter()
	await process_frame
	_expect(not maze._battling, "INT-06 Marc's local developer Off was ignored")
	maze.room_encounters_enabled = true
	maze.divers[selected].start_random_encounter()
	await process_frame
	_expect(maze._battling and maze._battle != null and not maze.random_encounters_enabled,
		"INT-06 campaign Off bypasses Marc's forced strong room")
	print("MAZE ROOM POLICY|active=", selected, "|outside=blocked|developer_off=blocked|global_off_local_on=battle")

func _key(code: Key, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.ctrl_pressed = ctrl
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.ctrl_pressed = ctrl
	Input.parse_input_event(event)
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
