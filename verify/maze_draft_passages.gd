extends SceneTree
# DRAFT-1: an actual Break Room approach must offer the authored outgoing
# passage; not a node-existence or private-trigger test. Fixture placement
# isolates the passage and does not prove the full campaign journey.
var findings: Array[String] = []
var world: World
var path_samples := 0
const SLOT := 918365
var owns_slot := false

func _initialize() -> void:
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
	world.random_encounters_enabled = false
	var maze := world.embedded_maze
	maze.room_encounters_enabled = false
	for actor in world.divers:
		actor.sonar_active = false
	var wall := maze.get_node("Wall11EndCap") as CSGBox3D
	var corridor := maze.get_node("WindCorridorBreakRock") as Area3D
	var side := signf((corridor.get_child(0) as CollisionShape3D).global_position.x - wall.global_position.x)
	var closer := maze.get_node("Wall10Closer") as CSGBox3D
	var z := closer.global_position.z + 1.3 + 2.0
	var initial_diver := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--diver="):
			initial_diver = clampi(int(arg.trim_prefix("--diver=")), 0, 2)
	world.active = initial_diver
	maze.active = initial_diver
	maze._diver = world.divers[initial_diver]
	var actor := world.divers[initial_diver] as Diver
	actor.global_position = Vector3(wall.global_position.x + side * (wall.size.z * 0.5 + 1.2), 1.8, z)
	actor.velocity = Vector3.ZERO
	for frame in range(8):
		await physics_frame
	var prompt := _prompt(maze)
	_expect(maze.maze_active and prompt != null, "DRAFT-1 real Break Room approach offers no outgoing passage")
	if prompt == null:
		await _finish()
		return
	if OS.get_cmdline_user_args().has("--blocked"):
		var blocker := CSGBox3D.new()
		blocker.name = "BlockedExitFixture"
		blocker.size = Vector3(20, 12, 14)
		blocker.use_collision = true
		maze.add_child(blocker)
		blocker.global_position = Vector3(wall.global_position.x - side * 10.0, 1.8, z)
		maze.wall_boxes.append(blocker)
		for frame in range(8):
			await physics_frame
		var departure := actor.global_position
		await _key(KEY_Y)
		_expect(not actor.is_suction_locked() and not maze.draft_passages.busy
			and actor.global_position.distance_to(departure) < 0.05,
			"DRAFT-2 blocked exit starts a tween into the interior of a solid CSG box")
		print("DRAFT_BLOCKED_EXIT|safe_abort=", not actor.is_suction_locked(), "|actor=", actor.global_position)
		await _finish()
		return
	if OS.get_cmdline_user_args().has("--restore"):
		await _key(KEY_N)
		await _restore_probe()
		await _finish()
		return
	if OS.get_cmdline_user_args().has("--cancel"):
		var departure := actor.global_position
		await _key(KEY_Y)
		for frame in range(30):
			await physics_frame
		_expect(actor.is_suction_locked(), "DRAFT-4 teardown probe never entered real motion")
		# Remove the actual transient owner, retaining the shared World actor.
		# Stop fixture dispatch into that now-absent component, not its Tween.
		maze.set_physics_process(false)
		world.set_physics_process(false)
		var passages: Node3D = maze.draft_passages
		maze.remove_child(passages)
		passages.queue_free()
		for frame in range(3):
			await physics_frame
		_expect(not actor.is_suction_locked() and _clear(actor)
			and actor.global_position.distance_to(departure) < 0.05,
			"DRAFT-4 interrupted owner leaves the shared actor locked or buried below resealed floor")
		_expect(_floor_beneath(actor.global_position), "DRAFT-4 teardown leaves the floor hole open")
		print("DRAFT_TEARDOWN|diver=", initial_diver, "|departure=", departure, "|released_at=", actor.global_position)
		maze.draft_passages = null
		await _finish()
		return
	var before := actor.global_position
	await _key(KEY_N)
	for frame in range(5):
		await physics_frame
	_expect(_prompt(maze) == null and actor.global_position.distance_to(before) < 0.2,
		"DRAFT-1 refusing draft moves the party or immediately asks again")
	print("DRAFT_OUTGOING|real approach prompt and No latch=true")
	maze._yaw = PI
	await _hold(KEY_D if side > 0 else KEY_A, 45)
	await _hold(KEY_A if side > 0 else KEY_D, 45)
	_expect(_prompt(maze) != null, "DRAFT-1 leaving and swimming back fails to rearm outgoing question")
	if _prompt(maze) == null:
		await _finish()
		return
	actor.stats.hp = 7
	actor.stats.oxygen = 13.25
	await _key(KEY_Y)
	_expect(actor.is_suction_locked() and not maze.can_capture_campaign_snapshot(),
		"DRAFT-4 accepted passage leaves actor/save ownership unlocked")
	var active_before := maze.active
	for code in [KEY_TAB, KEY_F, KEY_L, KEY_P, KEY_R]:
		await _key(code)
	_expect(maze.active == active_before and not maze.target_selector.selecting,
		"DRAFT-4 passage accepts party/ability input during its motion")
	await _wait_passage(actor, "outgoing diver 0")
	_expect(not actor.is_suction_locked() and not maze.draft_passages.busy,
		"DRAFT-2 outgoing passage leaves a permanent movement lock")
	_expect(signf(actor.global_position.x - wall.global_position.x) == -side,
		"DRAFT-2 accepted draft never reaches the far side of the wall")
	_expect(_clear(actor), "DRAFT-2 outgoing passage drops the capsule into solid geometry")
	_expect(actor.stats.hp == 7 and is_equal_approx(actor.stats.oxygen, 13.25),
		"DRAFT-4 draft refills or spends the party's combat resources")
	await _key(KEY_E)
	_expect(_prompt(maze) == null, "DRAFT-1 E on the outside reverses a one-way outgoing passage")
	var exit := actor.global_position
	await _hold(KEY_A if side > 0 else KEY_D, 20)
	_expect(actor.global_position.distance_to(exit) > 0.5,
		"DRAFT-2 diver cannot actually swim away from the passage exit")
	print("DRAFT_OUTGOING|Yes moved below wall and released actor at clear exit=", exit)
	if not findings.is_empty():
		await _finish()
		return
	# Three distinct production capsules; fixture placement isolates each
	# passage, while real input/physics/tweens must deliver and release them.
	for selected in range(1, 3):
		world.active = selected
		maze.active = selected
		maze._diver = world.divers[selected]
		actor = maze._diver
		actor.global_position = Vector3(wall.global_position.x + side * (wall.size.z * 0.5 + 1.2), 1.8, z)
		actor.velocity = Vector3.ZERO
		for frame in range(6):
			await physics_frame
		_expect(_prompt(maze) != null, "DRAFT-1 diver %d cannot use outgoing draft" % selected)
		await _key(KEY_Y)
		await _wait_passage(actor, "outgoing diver %d" % selected)
		_expect(not actor.is_suction_locked() and _clear(actor)
			and signf(actor.global_position.x - wall.global_position.x) == -side,
			"DRAFT-2 diver %d is trapped at outgoing exit" % selected)
		print("DRAFT_OUTGOING_CASE|diver=", selected, "|exit=", actor.global_position)
	# DRAFT-3: actual published wall rotation, then approach the physical
	# return slot. Generate three actors × home/open × outside/inside.
	var return_cases := 0
	for selected in range(3):
		world.active = selected
		maze.active = selected
		maze._diver = world.divers[selected]
		actor = maze._diver
		for swung in [false, true]:
			actor.global_position = Vector3(263, 2, 16)
			actor.velocity = Vector3.ZERO
			if maze._walls_10_11_swung != swung:
				(maze.rotatable_wall_sets()[2].rotate as Callable).call()
				if swung:
					var rest14: Array = maze._walls_14_15_rest[0]
					var rest15: Array = maze._walls_14_15_rest[1]
					var width10: float = (maze.get_node("CSGBox3D10") as CSGBox3D).size.x
					var x: float = (rest15[1] as Vector3).x - (rest15[0] as CSGBox3D).size.x * 0.5 - width10 + 6.0
					var line: float = (rest14[1] as Vector3).z
					var outside := -signf((rest15[1] as Vector3).z - line)
					actor.global_position = Vector3(x, 1.8, line + outside * 1.5)
					for frame in range(3):
						await physics_frame
					_expect(not actor.is_suction_locked() and not maze.can_capture_campaign_snapshot(),
						"DRAFT-3 incoming passage or stable save activates while walls are still moving")
					actor.global_position = Vector3(263, 2, 16)
				await create_timer(1.6).timeout
			var w11 := maze.get_node("CSGBox3D11") as CSGBox3D
			var w10 := maze.get_node("CSGBox3D10") as CSGBox3D
			# The intended open destination follows wall 14's home line and
			# wall 10's west end, independently of the passage's cached fields.
			var rest14: Array = maze._walls_14_15_rest[0]
			var rest15: Array = maze._walls_14_15_rest[1]
			var return_line: float = (rest14[1] as Vector3).z
			var west10: float = (rest15[1] as Vector3).x - (rest15[0] as CSGBox3D).size.x * 0.5 - w10.size.x
			var return_slot := west10 + 6.0
			var outside := -signf((rest15[1] as Vector3).z - return_line)
			for incoming in [false, true]:
				var approach_side := outside if incoming else -outside
				actor.global_position = Vector3(return_slot, 1.8, return_line + approach_side * (w11.size.z * 0.5 + 1.0))
				actor.velocity = Vector3.ZERO
				for frame in range(8):
					await physics_frame
				if swung and incoming:
					_expect(actor.is_suction_locked(), "DRAFT-3 swung outside return fails to start for diver %d" % selected)
					await _wait_passage(actor, "incoming diver %d" % selected)
					_expect(not actor.is_suction_locked() and _clear(actor)
						and signf(actor.global_position.z - return_line) == -outside,
						"DRAFT-2/3 automatic return strands diver %d" % selected)
					var start := actor.global_position
					maze._yaw = 0.0
					await _hold(KEY_S if outside > 0 else KEY_W, 20)
					_expect(actor.global_position.distance_to(start) > 0.5,
						"DRAFT-2 diver %d cannot swim after automatic return" % selected)
				else:
					_expect(not actor.is_suction_locked(), "DRAFT-3 wrong-side/closed return starts for diver %d" % selected)
				return_cases += 1
				print("DRAFT_RETURN_CASE|diver=", selected, "|swung=", swung, "|incoming=", incoming, "|position=", actor.global_position)
				if not findings.is_empty():
					await _finish()
					return
	print("DRAFT_GENERATED|outgoing_actors=3|return_cases=", return_cases, "|independent_path_samples=", path_samples)
	await _finish()

func _wait_passage(actor: Diver, label: String) -> void:
	# DRAFT-2: an endpoint-only test accepts a tween through a solid floor.
	# Independently query every real physics frame, not the tween keyframes.
	for frame in range(110):
		await physics_frame
		if actor.is_suction_locked():
			path_samples += 1
			_expect(_floor_beneath(Vector3(265, 1.8, 16)), "DRAFT-2 %s removes the floor outside its bounded tunnel" % label)
			if not _clear(actor):
				_expect(false, "DRAFT-2 %s clips solid geometry at physics frame %d" % [label, frame])
				return
	_expect(_floor_beneath(actor.global_position), "DRAFT-2 %s leaves an unsealed floor after release" % label)

func _restore_probe() -> void:
	# DRAFT-5: production JSON restore must carry the latest wall geometry,
	# including checkpoints produced before this underpass was integrated.
	var maze := world.embedded_maze
	if SaveManager.slot_exists(SLOT):
		_expect(false, "DRAFT-5 disposable slot exists; refusing to overwrite it")
		return
	var last: Dictionary
	for actor in world.divers:
		actor.global_position = Vector3(265, 1.8, 16)
		actor.velocity = Vector3.ZERO
	if not maze._walls_10_11_swung:
		(maze.rotatable_wall_sets()[2].rotate as Callable).call()
		await create_timer(1.6).timeout
	for legacy in [false, true]:
		for selected in range(3):
			world.active = selected
			maze.active = selected
			maze._diver = world.divers[selected]
			for actor in world.divers:
				actor.global_position = Vector3(265, 1.8, 16)
				actor.velocity = Vector3.ZERO
			world.inventory["potion"] = 5
			maze._diver.stats.hp = 7
			maze._diver.stats.oxygen = 13.25
			var data := world._serialize_state()
			if legacy:
				# Actual pre-port geometry: wall 11 continued wall 14's west
				# end, rather than sharing swung wall 10's west end.
				var rest14: Array = maze._walls_14_15_rest[0]
				var w14 := rest14[0] as CSGBox3D
				var w11 := maze.get_node("CSGBox3D11") as CSGBox3D
				data.campaign_checkpoint.maze.walls.CSGBox3D11.position[0] = (rest14[1] as Vector3).x - w14.size.x * 0.5 - w11.size.x * 0.5
				# This was clear beyond the old wall's east end, but the new
				# alignment occupies it. Load must not bury a saved player.
				var wall10 := maze.get_node("CSGBox3D10") as CSGBox3D
				var old_clear := Vector3(wall10.global_position.x - wall10.size.x * 0.5 + 1.0, 1.8, (rest14[1] as Vector3).z)
				data.divers[selected].position = CampaignSession.vector_data(old_clear)
				data.campaign_checkpoint.maze.positions[selected] = CampaignSession.vector_data(old_clear)
				data.campaign_checkpoint.maze = MazeCoordinateFrame.rebase(data.campaign_checkpoint.maze, Vector3.ZERO)
				data.campaign_checkpoint.maze.erase("coordinate_origin")
			var label := "DRAFT-5 legacy=%s diver=%d" % [legacy, selected]
			last = data.duplicate(true)
			_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(data))), label + " rejects checkpoint")
			if legacy:
				print("DRAFT_LEGACY_POSITION|diver=", selected, "|restored=", world.divers[selected].global_position,
					"|immediately_clear=", _clear(world.divers[selected]))
			for frame in range(8):
				await physics_frame
			var wall11 := maze.get_node("CSGBox3D11") as CSGBox3D
			var wall10 := maze.get_node("CSGBox3D10") as CSGBox3D
			var west11 := wall11.global_position.x - wall11.size.x * 0.5
			var west10 := wall10.global_position.x - wall10.size.x * 0.5
			_expect(absf(west11 - west10) < 0.01, label + " restores superseded misaligned wall ends")
			_expect(_clear(maze._diver), label + " buries a saved actor in the migrated wall")
			if not findings.is_empty():
				return
			var outside := -signf(wall10.global_position.z - wall11.global_position.z)
			var actor := maze._diver
			actor.global_position = Vector3(west10 + 6.0, 1.8, wall11.global_position.z + outside * (wall11.size.z * 0.5 + 1.0))
			for frame in range(8):
				await physics_frame
			_expect(actor.is_suction_locked(), label + " restores an unusable return passage")
			await _wait_passage(actor, label)
			_expect(not actor.is_suction_locked() and _clear(actor)
				and signf(actor.global_position.z - wall11.global_position.z) == -outside,
				label + " cannot actually return after load")
			_expect(world.active == selected and actor.stats.hp == 7
				and is_equal_approx(actor.stats.oxygen, 13.25) and world.inventory["potion"] == 5,
				label + " loses or refills shared state")
			print("DRAFT_RESTORE|legacy=", legacy, "|diver=", selected, "|west_alignment=", west11 - west10, "|real_return=", actor.global_position)
			if not findings.is_empty():
				return
	print("DRAFT_RESTORE|JSON_cases=6|legacy_standalone_cases=3|independent_path_samples=", path_samples)
	_expect(SaveManager.write_slot(SLOT, last) == OK, "DRAFT-5 disposable checkpoint write failed")
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
	for frame in range(12):
		await physics_frame
	maze = world.embedded_maze
	_expect(not paused and not world.title_screen.visible and maze.maze_active
		and world._current_slot == SLOT and world.active == 2,
		"DRAFT-5 legacy cold Title Load loses selected slot/actor/maze ownership")
	var wall11 := maze.get_node("CSGBox3D11") as CSGBox3D
	var wall10 := maze.get_node("CSGBox3D10") as CSGBox3D
	var west := wall10.global_position.x - wall10.size.x * 0.5
	_expect(absf(west - wall11.global_position.x + wall11.size.x * 0.5) < 0.01,
		"DRAFT-5 cold legacy Load restores superseded wall alignment")
	maze.room_encounters_enabled = false
	var outside := -signf(wall10.global_position.z - wall11.global_position.z)
	maze._diver.global_position = Vector3(west + 6.0, 1.8, wall11.global_position.z + outside * (wall11.size.z * 0.5 + 1.0))
	for frame in range(8):
		await physics_frame
	_expect(maze._diver.is_suction_locked(), "DRAFT-5 cold-loaded return never starts")
	await _wait_passage(maze._diver, "cold legacy Load")
	_expect(not maze._diver.is_suction_locked() and _clear(maze._diver)
		and maze._diver.stats.hp == 7 and is_equal_approx(maze._diver.stats.oxygen, 13.25)
		and world.inventory["potion"] == 5,
		"DRAFT-5 cold return leaves capsule trapped or loses resources")
	print("DRAFT_COLD_LOAD|legacy=true|slot=", SLOT, "|live_return=true|player_slots_untouched=true")

func _floor_beneath(at: Vector3) -> bool:
	var top: float = world.embedded_maze._floor_top_y
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, top + 0.05, at.z), Vector3(at.x, top - 1.0, at.z), 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider is StaticBody3D

func _clear(actor: Diver) -> bool:
	# CSG collision is a concave triangle surface: a capsule wholly inside
	# an opaque box can produce no intersect_shape hit. Independently reject
	# interiors too, otherwise a buried save or tunneled path looks "clear".
	for wall in world.embedded_maze.wall_boxes:
		if not is_instance_valid(wall) or not wall.visible or not wall.use_collision:
			continue
		var p: Vector3 = wall.global_transform.affine_inverse() * actor.global_position
		var half: Vector3 = wall.size * 0.5
		if absf(p.x) < half.x and absf(p.y) < half.y and absf(p.z) < half.z:
			print("DRAFT_SOLID_INTERIOR|wall=", wall.name, "|actor=", actor.global_position)
			return false
	for child in actor.get_children():
		if child is CollisionShape3D:
			var shape := child as CollisionShape3D
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape.shape
			query.transform = shape.global_transform
			query.collision_mask = actor.collision_mask
			query.exclude = [actor.get_rid()]
			var hits := world.get_world_3d().direct_space_state.intersect_shape(query, 8)
			if not hits.is_empty():
				print("DRAFT_COLLISION|position=", actor.global_position, "|shape=", shape.shape,
					"|colliders=", hits.map(func(h: Dictionary) -> String: return String(h.collider.get_path())))
			return hits.is_empty()
	return false

func _hold(code: Key, frames: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	for frame in range(frames):
		await physics_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await physics_frame

func _prompt(node: Node) -> ConfirmPromptModal:
	if node is ConfirmPromptModal and not node.is_queued_for_deletion():
		return node
	for child in node.get_children():
		var prompt := _prompt(child)
		if prompt != null:
			return prompt
	return null

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
	world.queue_free()
	await process_frame
	if owns_slot:
		DirAccess.remove_absolute(SaveManager.slot_path(SLOT))
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE DRAFT PASSAGES: clean" if findings.is_empty() else "MAZE DRAFT PASSAGES: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
