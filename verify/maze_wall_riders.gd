extends SceneTree
# RIDER-1: actual swept contact must retain along-wall offset, not merely push.
var world: World
var findings: Array[String] = []
var carried_frames := 0
var cases := 0
var capture_dir := ""
# At embedded x≈367, float32 position/inverse-yaw quantization is ~3e-5m.
# Allow 0.1mm contact precision, not a gameplay-sized penetration allowance.
const CONTACT_EPSILON := 0.0001

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
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
	# Isolated geometry fixture, not first-time onboarding acceptance.
	maze._strong_room_seen = true
	maze._switch_explained = true
	var actor := world.divers[0] as Diver
	actor.global_position = Vector3(265, 2, 16)
	for frame in range(8):
		await physics_frame
	_expect(maze.maze_active, "RIDER-1 fixture did not enter embedded maze")
	for selected in range(3):
		(world.divers[selected] as Diver).global_position = Vector3(265 + selected * 2, 2, 16)
	var home := world._serialize_state()
	if OS.get_cmdline_user_args().has("--lifecycle"):
		await _lifecycle(maze, home)
		await _finish()
		return
	if OS.get_cmdline_user_args().has("--ownership"):
		await _ownership(maze, home)
		await _finish()
		return
	var indices := [0, 1, 2] if OS.get_cmdline_user_args().has("--matrix") else [1]
	for index in indices:
		_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(home))), "RIDER-3 baseline restore rejected")
		var set_spec: Dictionary = maze.rotatable_wall_sets()[index]
		var open_data: Dictionary
		(set_spec.rotate as Callable).call()
		await create_timer(1.5).timeout
		open_data = world._serialize_state()
		var destinations: Array[Transform3D] = []
		for destination_wall: CSGBox3D in set_spec.walls:
			destinations.append(destination_wall.global_transform)
		for closing in ([false, true] if OS.get_cmdline_user_args().has("--matrix") else [false]):
			var fixture: Dictionary = open_data if closing else home
			# Observe the action's actual direction with all actors parked;
			# test input is the public map callable, not a private hinge helper.
			_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(fixture))), "RIDER-3 direction fixture restore rejected")
			var directions: Array[float] = []
			var starts: Array[Transform3D] = []
			for wall: CSGBox3D in set_spec.walls:
				starts.append(wall.global_transform)
			(set_spec.rotate as Callable).call()
			for frame in range(4):
				await physics_frame
				await process_frame
			for w in range(set_spec.walls.size()):
				var wall := set_spec.walls[w] as CSGBox3D
				var local := Vector3(wall.size.x * 0.3, 0, 0)
				directions.append(signf((wall.global_transform * local - starts[w] * local).dot(starts[w].basis.z)))
			for selected in (range(3) if OS.get_cmdline_user_args().has("--matrix") else range(1)):
				for w in (range(2) if OS.get_cmdline_user_args().has("--matrix") else range(1)):
					_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(fixture))), "RIDER-3 generated fixture restore rejected")
					world.active = selected
					maze.active = selected
					maze._diver = world.divers[selected]
					await _trial(maze, set_spec, w, directions[w], selected, closing, destinations[w])
					if not findings.is_empty():
						await _finish()
						return
	await _finish()

func _trial(maze: MazeLevel, set_spec: Dictionary, wall_index: int, side: float, selected: int, closing: bool, destination: Transform3D) -> void:
	var wall := set_spec.walls[wall_index] as CSGBox3D
	var actor := world.divers[selected] as Diver
	var cap := _shape(actor)
	var p := wall.global_transform * Vector3(wall.size.x * 0.3, 0, side * (wall.size.z * 0.5 + actor.radius + 0.15))
	p.y = maze._floor_top_y + (cap.shape as CapsuleShape3D).height * 0.5 + 0.12
	actor.global_position = p
	actor.velocity = Vector3.ZERO
	actor.stats.hp = 7
	actor.stats.oxygen = 0
	actor.collision_mask = 5
	for frame in range(3):
		await physics_frame
	_expect(_clear(actor, maze), "RIDER-1 initial capsule is not clear: " + str(actor.global_position))
	print("RIDER_START|wall=", wall.name, "|diver=", selected, "|closing=", closing, "|position=", actor.global_position, "|size=", wall.size)
	if findings.is_empty():
		(set_spec.rotate as Callable).call()
		var offset := Vector3.ZERO
		var contacted := false
		var contact_position := Vector3.ZERO
		var obstruction: CSGBox3D
		var field: WaterCurrent
		var field_area: Area3D
		var current_frames := 0
		for frame in range(65):
			var before := actor.global_position
			await physics_frame
			await process_frame
			if frame % 20 == 0:
				print("RIDER_FRAME|", frame, "|wall=", wall.global_position, "|yaw=", wall.rotation.y, "|actor=", actor.global_position, "|local=", wall.global_transform.affine_inverse() * actor.global_position)
			if not contacted and actor.global_position.distance_to(before) > 0.1 and absf((wall.global_transform.affine_inverse() * actor.global_position).z) < wall.size.z * 0.5 + actor.radius + 0.2:
				contacted = true
				offset = wall.global_transform.affine_inverse() * actor.global_position
				contact_position = actor.global_position
				print("RIDER_CONTACT|frame=", frame, "|offset=", offset)
			elif contacted:
				var actual := wall.global_transform.affine_inverse() * actor.global_position
				carried_frames += 1
				_expect(absf(actual.x - offset.x) < 0.12 and absf(actual.z - offset.z) < 0.12,
					"RIDER-1 passenger lost wall-local offset at frame %d: expected %s got %s" % [frame, offset, actual])
				if not findings.is_empty():
					break
			if contacted and frame == 10 and OS.get_cmdline_user_args().has("--blocked"):
				# Introduce a real opaque CSG volume at the preferred final
				# landing after capture. A surface-only check misses its center.
				obstruction = CSGBox3D.new()
				obstruction.size = Vector3(2.5, 6, 2.5)
				obstruction.use_collision = true
				maze.add_child(obstruction)
				obstruction.global_position = destination * offset
				maze.wall_boxes.append(obstruction)
			if contacted and frame == 10 and OS.get_cmdline_user_args().has("--currents"):
				field_area = Area3D.new()
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(60, 12, 60)
				shape.shape = box
				field_area.add_child(shape)
				maze.add_child(field_area)
				field_area.global_position = wall.global_position
				field = WaterCurrent.new()
				maze.add_child(field)
				field.setup(field_area, Vector3.RIGHT, 7, false)
			if contacted and actor.external_push.length() > 1.0:
				current_frames += 1
			if frame == 40 and not capture_dir.is_empty():
				await _capture("rider-moving")
		if findings.is_empty():
			_expect(contacted and carried_frames > 10, "RIDER-1 fixture lacks sustained real swept contact")
		if findings.is_empty():
			_expect(actor.global_position.distance_to(contact_position) > 4.0, "RIDER-1 passenger did not travel with wall")
			await create_timer(0.6).timeout
			if not _clear(actor, maze):
				print("RIDER_CLEAR_DEBUG|at=", actor.global_position, "|velocity=", actor.velocity, "|locked=", actor.is_suction_locked())
				for box in maze.wall_boxes:
					if is_instance_valid(box) and _overlaps(actor, actor.global_position, box):
						print("RIDER_OVERLAP_DEBUG|wall=", box.name, "|local=", box.global_transform.affine_inverse() * actor.global_position, "|size=", box.size, "|radius=", actor.radius)
			_expect(_clear(actor, maze), "RIDER-2 released capsule overlaps solid geometry")
			if is_instance_valid(obstruction):
				_expect(not _overlaps(actor, actor.global_position, obstruction), "RIDER-2 release ignores newly blocked solid-volume landing")
				maze.wall_boxes.erase(obstruction)
				obstruction.queue_free()
			if is_instance_valid(field):
				_expect(current_frames > 20, "RIDER-4 current fixture never physically overlaps passenger")
				field.teardown()
				field.queue_free()
				field_area.queue_free()
			_expect(not actor.is_suction_locked(), "RIDER-3 passenger remains locked after finish")
			_expect(actor.collision_mask == 5, "RIDER-3 passenger loses non-default collision mask")
			_expect(actor.stats.hp == 7 and actor.stats.oxygen == 0, "RIDER-3 rotation changes combat resources")
			var away := wall.global_basis.z * side
			maze._yaw = atan2(away.x, away.z)
			var before := actor.global_position
			await _hold(KEY_W, 20)
			_expect(actor.global_position.distance_to(before) > 0.5, "RIDER-3 released passenger cannot actually swim")
			cases += 1
			print("RIDER_RELEASE|wall=", wall.name, "|diver=", selected, "|clear=true|mask=", actor.collision_mask, "|swim=", actor.global_position.distance_to(before))
			if not capture_dir.is_empty():
				await create_timer(0.8).timeout
				await _capture("rider-released")

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) == OK, "RIDER-2 native capture could not be saved")

func _hold(code: Key, frames: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	for frame in range(frames):
		await physics_frame
		await process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await physics_frame

func _lifecycle(maze: MazeLevel, home: Dictionary) -> void:
	for selected in range(3):
		for mode in ["restore", "kill", "inactive", "removed", "c5-arrival"]:
			_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(home))), "RIDER-3 lifecycle baseline restore rejected")
			world.active = selected
			maze.active = selected
			maze._diver = world.divers[selected]
			var actor := maze._diver
			actor.stats.hp = 7
			actor.stats.oxygen = 0
			actor.collision_mask = 5
			var fixture := world._serialize_state()
			var loaded_pose := actor.global_position
			var set_spec: Dictionary = maze.rotatable_wall_sets()[2 if mode == "c5-arrival" else 1]
			var wall := set_spec.walls[0] as CSGBox3D
			var initial := wall.global_transform * Vector3(wall.size.x * 0.3, 0, wall.size.z * 0.5 + actor.radius + 0.15)
			initial.y = maze._floor_top_y + (_shape(actor).shape as CapsuleShape3D).height * 0.5 + 0.12
			actor.global_position = initial
			actor.velocity = Vector3.ZERO
			for frame in range(3):
				await physics_frame
				await process_frame
			_expect(_clear(actor, maze), "RIDER-3 lifecycle fixture starts buried")
			(set_spec.rotate as Callable).call()
			for frame in range(25):
				await physics_frame
				await process_frame
			_expect(actor.is_suction_locked() and actor.collision_mask == 0, "RIDER-3 lifecycle never captured a passenger")
			match mode:
				"c5-arrival":
					maze.rotate_corridors_right(maze.get_node("WindCorridor5"), maze.get_node("WindCorridor6"))
					actor.global_position = Vector3(360, initial.y, -3)
					for frame in range(95):
						var before := actor.global_position
						await physics_frame
						await process_frame
						_expect(not actor.is_suction_locked() and actor.collision_mask == 5,
							"RIDER-4 arriving C5 occupant remains a wall passenger")
						_expect(actor.global_position.distance_to(before) <= actor.velocity.length() / 60.0 + 0.08,
							"RIDER-4 wall directly carries an arriving passenger back out of C5")
					print("RIDER_C5_ARRIVAL|end=", actor.global_position, "|velocity=", actor.velocity)
				"restore":
					_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(fixture))), "RIDER-3 live passenger restore rejected")
					_expect(actor.global_position.distance_to(loaded_pose) < 0.01, "RIDER-3 cancellation overwrites loaded party pose")
					for frame in range(95):
						await physics_frame
						await process_frame
						_expect(actor.global_position.distance_to(loaded_pose) < 0.02, "RIDER-3 old passenger motion overwrites loaded party pose later")
				"kill":
					for tween in get_processed_tweens():
						if tween.is_valid():
							tween.kill()
					for frame in range(10):
						await physics_frame
						await process_frame
				"inactive":
					world.set_physics_process(false)
					maze.set_maze_active(false)
					for frame in range(4):
						await physics_frame
					maze.set_maze_active(true)
					world.set_physics_process(true)
				"removed":
					world.set_physics_process(false)
					world.remove_child(maze)
					_expect(is_instance_valid(actor) and not actor.is_suction_locked() and actor.collision_mask == 5,
						"RIDER-3 removed owner destroys or locks shared party actor")
					world.add_child(maze)
					maze.set_maze_active(true)
					world.set_physics_process(true)
			for frame in range(4):
				await physics_frame
				await process_frame
			_expect(not actor.is_suction_locked() and actor.collision_mask == 5, "RIDER-3 %s leaves lock/mask corrupted" % mode)
			_expect(_clear(actor, maze), "RIDER-3 %s strands capsule in solids" % mode)
			_expect(maze.can_capture_campaign_snapshot(), "RIDER-3 %s remains unsaveable" % mode)
			_expect(actor.stats.hp == 7 and actor.stats.oxygen == 0, "RIDER-3 %s changes resources" % mode)
			maze._yaw = -PI * 0.5 if mode not in ["restore", "c5-arrival"] else 0.0
			var before := actor.global_position
			await _hold(KEY_W, 20)
			_expect(actor.global_position.distance_to(before) > 0.5, "RIDER-3 %s cannot resume real swimming" % mode)
			cases += 1
			print("RIDER_LIFECYCLE|diver=", selected, "|mode=", mode, "|clear=true|mask=", actor.collision_mask)
			if not findings.is_empty():
				return

func _ownership(maze: MazeLevel, home: Dictionary) -> void:
	for selected in range(3):
		for already_locked in [true, false]:
			_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(home))), "RIDER-4 ownership fixture restore rejected")
			var actor := world.divers[selected] as Diver
			var set_spec: Dictionary = maze.rotatable_wall_sets()[1]
			var wall := set_spec.walls[0] as CSGBox3D
			var at := wall.global_transform * Vector3(wall.size.x * 0.3, 0, wall.size.z * 0.5 + actor.radius + 0.15)
			at.y = maze._floor_top_y + (_shape(actor).shape as CapsuleShape3D).height * 0.5 + 0.12
			actor.global_position = at
			actor.velocity = Vector3.ZERO
			actor.stats.hp = 0 # Downed body still exists; do not revive/refill it.
			actor.stats.oxygen = 0
			actor.collision_mask = 5
			actor.set_suction_locked(already_locked)
			(set_spec.rotate as Callable).call()
			var offset := Vector3.ZERO
			for frame in range(65):
				await physics_frame
				await process_frame
				if already_locked:
					_expect(actor.global_position.distance_to(at) < 0.01 and actor.is_suction_locked() and actor.collision_mask == 5,
						"RIDER-4 wall steals an existing motion owner's pose/lock/mask")
				elif frame == 10:
					offset = wall.global_transform.affine_inverse() * actor.global_position
					_expect(actor.is_suction_locked() and actor.collision_mask == 0, "RIDER-4 downed passenger was not captured")
				elif frame > 10:
					var actual := wall.global_transform.affine_inverse() * actor.global_position
					_expect(absf(actual.x - offset.x) < 0.12 and absf(actual.z - offset.z) < 0.12,
						"RIDER-4 downed passenger loses wall-local offset")
			await create_timer(0.6).timeout
			_expect(actor.is_suction_locked() == already_locked and actor.collision_mask == 5, "RIDER-4 completion clears another owner's lock or loses mask")
			_expect(actor.stats.hp == 0 and actor.stats.oxygen == 0, "RIDER-4 motion revives/refills downed passenger")
			actor.set_suction_locked(false) # Release only the fixture's own lock.
			_expect(_clear(actor, maze), "RIDER-4 downed/protected actor ends in solids")
			cases += 1
			print("RIDER_OWNERSHIP|diver=", selected, "|preexisting_lock=", already_locked, "|hp=0|oxygen=0|mask=5")
			if not findings.is_empty():
				return

func _shape(actor: Diver) -> CollisionShape3D:
	for child in actor.get_children():
		if child is CollisionShape3D:
			return child
	return null

func _overlaps(actor: Diver, at: Vector3, wall: CSGBox3D) -> bool:
	var capsule := _shape(actor).shape as CapsuleShape3D
	var local := wall.global_transform.affine_inverse() * at
	var h := wall.size * 0.5
	var segment := capsule.height * 0.5 - capsule.radius
	var gap := Vector3(maxf(absf(local.x) - h.x, 0), maxf(absf(local.y) - h.y - segment, 0), maxf(absf(local.z) - h.z, 0))
	return gap.length_squared() < pow(capsule.radius - CONTACT_EPSILON, 2)

func _clear(actor: Diver, maze: MazeLevel) -> bool:
	for wall in maze.wall_boxes:
		if is_instance_valid(wall) and wall.use_collision and wall.collision_layer != 0 and _overlaps(actor, actor.global_position, wall):
			return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape(actor).shape
	query.transform = _shape(actor).global_transform
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	paused = false
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE WALL RIDERS: clean | cases=", cases, "|retained_frames=", carried_frames) if findings.is_empty() else print("MAZE WALL RIDERS: findings=", findings.size())
	quit(0 if findings.is_empty() else 1)
