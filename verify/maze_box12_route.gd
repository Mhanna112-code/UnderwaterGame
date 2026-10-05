extends "res://verify/maze_current_route.gd"
# BOX12: actual public-input route + captured pre-change checkpoint migration.
var world: World
var capture_legacy := ""
var path_samples := 0
var capture_dir := ""
const SLOT := 918367
var owns_slot := false

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.size = Vector2i(1280, 720) if "--narrow" not in OS.get_cmdline_user_args() else Vector2i(360, 640)
	call_deferred("_run")

func _run() -> void:
	world = load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	# Initialization can reapply project defaults. Resize the live window,
	# then assert the rendered viewport instead of trusting the requested size.
	root.size = Vector2i(1280, 720) if "--narrow" not in OS.get_cmdline_user_args() else Vector2i(360, 640)
	for frame in 3:
		await process_frame
	world.random_encounters_enabled = false
	maze = world.embedded_maze
	maze.room_encounters_enabled = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-legacy="):
			capture_legacy = arg.trim_prefix("--capture-legacy=")
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_legacy.is_empty():
		await _capture_legacy()
	elif "--migration-only" in OS.get_cmdline_user_args():
		await _migration()
	else:
		await _replacement_route()
	await _finish()

func _capture_legacy() -> void:
	var button := maze.get_node("PathButton") as Node3D
	maze._diver.global_position = button.global_position + button.global_basis.z * 1.2
	maze._diver.velocity = Vector3.ZERO
	for frame in 10:
		await physics_frame
	await _key(KEY_E)
	await create_timer(2.0).timeout
	_expect(maze._path_opened and maze.get_node_or_null("PathWallNorth") != null,
		"BOX12-3 capture did not execute the real old E route")
	# An old clear placement which the restored home Box12 will occupy.
	var b12 := maze.get_node("CSGBox3D12") as CSGBox3D
	var b13 := maze.get_node("CSGBox3D13") as CSGBox3D
	var corridor := maze.get_node("WindCorridor4").get_child(0) as CollisionShape3D
	for selected in 3:
		maze.divers[selected].global_position = Vector3(b12.global_position.x + b12.size.x * 0.5 - 1.0,
			1.8, corridor.global_position.z + 4.0 + selected * 1.5)
		maze.divers[selected].stats.hp = 6 + selected
		maze.divers[selected].stats.oxygen = 11.25 + selected
		maze.divers[selected].velocity = Vector3.ZERO
	maze.keys_held = 3
	world.inventory["potion"] = 5
	maze.key_items.append("maze_nav_map")
	for frame in 8:
		await physics_frame
	var data := world._serialize_state()
	_expect(CampaignCheckpoint.valid_maze(data.campaign_checkpoint.maze), "BOX12-3 captured JSON is invalid")
	var file := FileAccess.open(capture_legacy, FileAccess.WRITE)
	_expect(file != null, "BOX12-3 fixture receipt cannot be written")
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	print("BOX12_LEGACY_CAPTURE|source=0d147b9|public_E=true|wall12=", b12.global_position,
		"|wall13=", b13.global_position, "|party=", data.campaign_checkpoint.maze.positions,
		"|file=", capture_legacy)

func _replacement_route() -> void:
	var wall := maze.get_node("CSGBox3D12") as CSGBox3D
	var z := clampf(maze._dome_site.z, wall.global_position.z - wall.size.x * 0.5 + 2.6,
		wall.global_position.z + wall.size.x * 0.5 - 2.6)
	var outside := signf(maze._dome_site.x - wall.global_position.x)
	var approach := Vector3(wall.global_position.x - outside * (wall.size.z * 0.5 + 1.2), 1.8, z)
	var selected_cases: Array = [0, 1, 2]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--diver="):
			selected_cases = [clampi(int(arg.trim_prefix("--diver=")), 0, 2)]
	for selected in selected_cases:
		world.active = selected
		maze.active = selected
		maze._diver = world.divers[selected]
		var actor := maze._diver
		# Wrong side and high approach must not offer a reverse or airborne tunnel.
		for invalid in [Vector3(wall.global_position.x + outside * 2.0, 1.8, z), approach + Vector3.UP * 5.0]:
			actor.global_position = invalid
			actor.velocity = Vector3.ZERO
			for frame in 5:
				await physics_frame
			_expect(_prompt(maze) == null and not actor.is_suction_locked(),
				"BOX12-1 wrong-side/high approach starts a passage for diver %d" % selected)
		# A queued reading lesson owns pause even if the player reaches the
		# draft during the same frame. The draft must not stack above/below it.
		var pages: Array[Dictionary] = [{"title": "Ownership probe", "body": "Reading lesson", "slot": null}]
		root.get_node("CharacterAbilityPopup").open(pages, maze)
		actor.global_position = approach
		for frame in 3:
			await process_frame
		await _key(KEY_Y)
		_expect(paused and _prompt(maze) == null, "BOX12-5 draft steals a paused lesson's input")
		await _key(KEY_ESCAPE)
		actor.global_position = approach
		actor.velocity = Vector3.ZERO
		for frame in 8:
			await physics_frame
		_expect(_prompt(maze) != null, "BOX12-1 real hallway approach offers no Box12 draft for diver %d" % selected)
		print("BOX12_APPROACH|diver=", selected, "|actor=", actor.global_position, "|prompt=", _prompt(maze) != null)
		if _prompt(maze) == null:
			return
		await _capture("box12-prompt-%d" % selected)
		var departure := actor.global_position
		if "--blocked" in OS.get_cmdline_user_args():
			var blocker := CSGBox3D.new()
			blocker.name = "BlockedBox12ExitFixture"
			blocker.size = Vector3(20, 12, 14)
			blocker.use_collision = true
			maze.add_child(blocker)
			blocker.global_position = Vector3(wall.global_position.x + outside * 10.0, 1.8, z)
			maze.wall_boxes.append(blocker)
			for frame in 8:
				await physics_frame
			await _key(KEY_Y)
			_expect(not actor.is_suction_locked() and not maze.draft_passages.busy
				and actor.global_position.distance_to(departure) < 0.05,
				"BOX12-2 blocked exit opens a tunnel into solid geometry")
			_expect(_floor_beneath(actor.global_position), "BOX12-2 rejected exit opens the floor")
			print("BOX12_BLOCKED|safe_abort=true|floor_sealed=true")
			return
		if "--cancel" in OS.get_cmdline_user_args():
			await _key(KEY_Y)
			for frame in 30:
				await physics_frame
			_expect(actor.is_suction_locked(), "BOX12-2 cancellation fixture never enters motion")
			await _capture("box12-motion-%d" % selected)
			maze.set_physics_process(false)
			world.set_physics_process(false)
			var passages: Node3D = maze.draft_passages
			maze.remove_child(passages)
			passages.queue_free()
			maze.draft_passages = null
			for frame in 3:
				await physics_frame
			_expect(not actor.is_suction_locked() and _clear(actor)
				and actor.global_position.distance_to(departure) < 0.05 and _floor_beneath(actor.global_position),
				"BOX12-2 teardown leaves the shared actor locked/buried or the floor open")
			print("BOX12_TEARDOWN|diver=", selected, "|released_at=", actor.global_position)
			return
		await _key(KEY_N)
		for frame in 8:
			await physics_frame
		_expect(_prompt(maze) == null and actor.global_position.distance_to(departure) < 0.1,
			"BOX12-1 No moves the actor or repeats without leaving")
		# Real swimming out of and back into range, with currents/collision intact.
		await _swim(approach + Vector3(0, 0, -3.0))
		await _swim_until_prompt(approach)
		_expect(_prompt(maze) != null, "BOX12-1 real reapproach does not rearm question")
		if not findings.is_empty():
			return
		actor.stats.hp = 6 + selected
		actor.stats.oxygen = 0.0
		await _key(KEY_Y)
		_expect(actor.is_suction_locked() and not maze.can_capture_campaign_snapshot(),
			"BOX12-2 accepted tunnel does not own movement/save stability")
		for code in [KEY_F, KEY_TAB, KEY_L, KEY_P, KEY_R]:
			await _key(code)
		_expect(maze.active == selected and not maze.target_selector.selecting,
			"BOX12-2 transient passage accepts party/ability/menu input")
		await _wait_motion(actor)
		_expect(not actor.is_suction_locked() and _clear(actor)
			and signf(actor.global_position.x - wall.global_position.x) == outside,
			"BOX12-2 accepted passage leaves the actor locked/buried/on wrong side")
		_expect(actor.stats.hp == 6 + selected and actor.stats.oxygen == 0.0,
			"BOX12-2 free environmental passage modifies combat resources")
		await _capture("box12-exit-%d" % selected)
		var exit := actor.global_position
		await _swim(exit + Vector3(outside * 1.5, 0, 0))
		_expect(actor.global_position.distance_to(exit) > 0.8,
			"BOX12-2 capsule cannot actually swim away from the exit")
		print("BOX12_TRAVERSE|diver=", selected, "|exit=", exit, "|resources_preserved=true")
		if not findings.is_empty():
			return
	# BOX12-4: actually reach and earn the map from the outside of the new draft.
	var chest := maze.get_node("MapChest") as Node3D
	var goal := chest.global_position + Vector3(0, 1.0, 1.8)
	var capsule := (maze._diver.get_children().filter(func(n: Node) -> bool: return n is CollisionShape3D)[0] as CollisionShape3D).shape as CapsuleShape3D
	# Bucky is taller than Max. Her capsule must clear the raised plinth,
	# not merely reach the chest's nominal interaction height.
	goal.y = maxf(goal.y, MazeLevel.PLINTH_TOP_Y + capsule.height * 0.5 + 0.15)
	# The tall capsule also must not overshoot into the porch ceiling.
	# Use real short key taps with settling, rather than teleporting its Y.
	for tap in 24:
		if absf(maze._diver.global_position.y - goal.y) < 0.07:
			break
		await _hold(KEY_SPACE if maze._diver.global_position.y < goal.y else KEY_SHIFT, 1)
		for frame in 16:
			await physics_frame
	print("BOX12_CHEST_APPROACH|actor=", maze._diver.global_position, "|chest_goal=", goal)
	goal.y = maze._diver.global_position.y
	var route := _no_current_path(goal)
	_expect(not route.is_empty(), "BOX12-4 new fence blocks the outside-to-chest route")
	if route.is_empty():
		for area in maze._currents_by_corridor:
			var shape := (area as Area3D).get_child(0) as CollisionShape3D
			print("BOX12_ACTIVE_CURRENT|area=", area.name, "|at=", shape.global_position, "|size=", (shape.shape as BoxShape3D).size)
		for x in range(280, 334, 2):
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = (maze._diver.get_children().filter(func(n: Node) -> bool: return n is CollisionShape3D)[0] as CollisionShape3D).shape
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, goal.y, maze._dome_site.z))
			query.collision_mask = 1
			var hits := world.get_world_3d().direct_space_state.intersect_shape(query, 8)
			if not hits.is_empty():
				print("BOX12_DIRECT_BLOCK|x=", x, "|hits=", hits.map(func(h: Dictionary) -> String: return String(h.collider.get_path())))
		return
	for waypoint in route:
		await _swim(waypoint)
		if not findings.is_empty():
			return
	var keys := maze.keys_held
	await _key(KEY_E)
	await create_timer(2.2).timeout
	_expect(maze.key_items.count("maze_nav_map") == 1 and maze.keys_held == keys,
		"BOX12-4 actual E chest fails to award one map or changes door keys")
	await _key(KEY_ESCAPE)
	await _key(KEY_L)
	_expect(paused and (maze.get_node("HUD/MazeMiniMap") as MazeMiniMap).main_map.visible,
		"BOX12-4 earned first L cannot open the map lesson")
	await _capture("box12-earned-map")
	await _key(KEY_ESCAPE)
	await _key(KEY_L)
	print("BOX12_EARNED_MAP|real_swim_E_L=true|path_samples=", path_samples)
	if findings.is_empty():
		await _migration()

func _migration() -> void:
	var captured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://verify/fixtures/maze_control_route_0d147b9.json"))
	var wall := maze.get_node("CSGBox3D12") as CSGBox3D
	var home := wall.global_transform
	var cases := 0
	for selected in 3:
		for standalone in [false, true]:
			for owned in [false, true]:
				for placement in ["captured", "overlap", "unaffected"]:
					var data := captured.duplicate(true)
					data.active = selected
					if not owned:
						data.campaign_checkpoint.maze.key_items.erase("maze_nav_map")
					# A captured clear old placement can occupy home Box12. Also
					# exercise a party member not overlapping the changed layout.
					if placement != "captured":
						for i in 3:
							var point := Vector3(home.origin.x + 0.05, 1.8, home.origin.z + float(i) * 2.0) if placement == "overlap" else Vector3(265.0 + i * 2.0, 1.8, 16)
							data.divers[i].position = CampaignSession.vector_data(point)
							data.campaign_checkpoint.maze.positions[i] = CampaignSession.vector_data(point)
					if standalone:
						data.campaign_checkpoint.maze = MazeCoordinateFrame.rebase(data.campaign_checkpoint.maze, Vector3.ZERO)
						data.campaign_checkpoint.maze.erase("coordinate_origin")
					var before := JSON.stringify(data)
					_expect(world.restore_checkpoint(JSON.parse_string(before)), "BOX12-3 captured old route rejected on Load")
					for frame in 8:
						await physics_frame
					_expect(JSON.stringify(data) == before, "BOX12-3 restore mutates input checkpoint")
					_expect(maze.get_node_or_null("PathButton") == null and maze.get_node_or_null("PathWallNorth") == null
						and maze.get_node_or_null("PathWallSouth") == null, "BOX12-3 old Load recreates the competing raised route")
					_expect(wall.global_transform.is_equal_approx(home), "BOX12-3 old Load restores swung Box12")
					_expect(world.active == selected and maze.active == selected and maze.keys_held == 3
						and world.inventory["potion"] == 5 and maze.key_items.has("maze_nav_map") == owned,
						"BOX12-3 migration loses selected actor, keys, inventory or earned map")
					for i in 3:
						var actor := world.divers[i] as Diver
						_expect(_clear(actor) and actor.stats.hp == 6 + i and is_equal_approx(actor.stats.oxygen, 11.25 + i),
							"BOX12-3 migration strands/refills party member %d" % i)
					var reserialized := world._serialize_state()
					_expect(CampaignCheckpoint.valid_maze(reserialized.campaign_checkpoint.maze)
						and not reserialized.campaign_checkpoint.maze.walls.has("PathWallNorth"),
						"BOX12-3 migrated save is invalid or writes retired geometry")
					cases += 1
					print("BOX12_MIGRATION|actor=", selected, "|legacy_frame=", standalone, "|map_owned=", owned, "|placement=", placement,
						"|position=", maze._diver.global_position)
					if not findings.is_empty():
						return
	print("BOX12_MIGRATION|generated_cases=", cases, "|captured_old_public_E_source=0d147b9")

	# Actual slot IO and cold Title Load, using a guarded disposable slot.
	if SaveManager.slot_exists(SLOT):
		_expect(false, "BOX12-3 disposable slot already exists; refusing to overwrite")
		return
	# Load the raw historical raised-path save cold, not only a checkpoint
	# already normalized by this run's live restore.
	var durable := captured.duplicate(true)
	durable.active = 2
	_expect(SaveManager.write_slot(SLOT, durable) == OK, "BOX12-3 migrated save cannot be written")
	owns_slot = SaveManager.slot_exists(SLOT)
	if not owns_slot:
		return
	world.queue_free()
	await process_frame
	world = load("res://game/world.tscn").instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.load_game_chosen.emit(SLOT)
	for frame in 12:
		await physics_frame
	maze = world.embedded_maze
	_expect(not paused and not world.title_screen.visible and maze.maze_active and world.active == 2
		and world._current_slot == SLOT and maze.keys_held == 3 and world.inventory["potion"] == 5
		and maze.key_items.count("maze_nav_map") == 1, "BOX12-3 cold Title Load loses owner/slot/resources/map")
	_expect(maze.get_node_or_null("PathWallNorth") == null and _clear(maze._diver),
		"BOX12-3 cold Load recreates the old route or buries the actor")
	var before := maze._diver.global_position
	await _swim(before + Vector3(1.5, 0, 0))
	_expect(maze._diver.global_position.distance_to(before) > 0.8,
		"BOX12-3 migrated cold-loaded actor cannot actually swim")
	print("BOX12_COLD_LOAD|slot=", SLOT, "|raw_legacy_PathWalls=true|real_swim=true|player_slots_untouched=true")

func _hold(code: Key, frames: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	for frame in frames:
		await physics_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await physics_frame

func _swim_until_prompt(goal: Vector3) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(click)
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	var deadline := Time.get_ticks_msec() + 10000
	while _prompt(maze) == null and Time.get_ticks_msec() < deadline:
		var delta := goal - maze._diver.global_position
		var desired := atan2(delta.x, delta.z)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-angle_difference(maze._yaw, desired) / 0.004, 0)
		Input.parse_input_event(motion)
		await physics_frame
	await _release_movement()

func _wait_motion(actor: Diver) -> void:
	for frame in 110:
		await physics_frame
		if actor.is_suction_locked():
			path_samples += 1
			if frame >= 15:
				_expect((maze.get_node("Camera3D") as Camera3D).global_position.y > maze._floor_top_y + 3.0,
					"BOX12-6 passage camera sinks below the floor into the diver model")
			_expect(_floor_beneath(Vector3(265, 1.8, 16)), "BOX12-2 tunnel removes unrelated floor")
			_expect(_clear(actor), "BOX12-2 transient motion clips solid floor/skirt/wall at frame %d" % frame)
			if not findings.is_empty():
				return
	_expect(_floor_beneath(actor.global_position), "BOX12-2 completed tunnel leaves a permanent hole")

func _floor_beneath(at: Vector3) -> bool:
	var top: float = maze._floor_top_y
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, top + 0.05, at.z), Vector3(at.x, top - 1.0, at.z), 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider is StaticBody3D

func _clear(actor: Diver) -> bool:
	for wall in maze.wall_boxes:
		if not is_instance_valid(wall) or not wall.visible or not wall.use_collision:
			continue
		var p: Vector3 = wall.global_transform.affine_inverse() * actor.global_position
		var half: Vector3 = wall.size * 0.5
		if absf(p.x) < half.x and absf(p.y) < half.y and absf(p.z) < half.z:
			print("BOX12_SOLID_INTERIOR|wall=", wall.name, "|position=", actor.global_position)
			return false
	for child in actor.get_children():
		if child is CollisionShape3D:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = child.shape
			query.transform = child.global_transform
			query.collision_mask = actor.collision_mask
			query.exclude = [actor.get_rid()]
			var hits := world.get_world_3d().direct_space_state.intersect_shape(query, 8)
			if not hits.is_empty():
				print("BOX12_COLLISION|actor=", actor.global_position, "|hits=", hits.map(func(h: Dictionary) -> String: return String(h.collider.get_path())))
			return hits.is_empty()
	return false

func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	var requested := Vector2i(360, 640) if "--narrow" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	_expect(rendered.get_size() == requested, "BOX12 capture uses a stale viewport size")
	_expect(rendered.save_png(capture_dir.path_join(label + ".png")) == OK,
		"BOX12 capture failed")

func _prompt(node: Node) -> ConfirmPromptModal:
	if node is ConfirmPromptModal and not node.is_queued_for_deletion():
		return node
	for child in node.get_children():
		var found := _prompt(child)
		if found != null:
			return found
	return null

func _finish() -> void:
	paused = false
	await _release_movement()
	world.queue_free()
	await process_frame
	if owns_slot:
		DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE BOX12 ROUTE: clean" if findings.is_empty() else "MAZE BOX12 ROUTE: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
