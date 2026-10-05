extends SceneTree
# RIDER-1: actual swept contact must retain along-wall offset, not merely push.
var world: World
var findings: Array[String] = []
var carried_frames := 0

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
	# Isolated geometry fixture, not first-time onboarding acceptance.
	maze._strong_room_seen = true
	maze._switch_explained = true
	var actor := world.divers[0] as Diver
	actor.global_position = Vector3(265, 2, 16)
	for frame in range(8):
		await physics_frame
	_expect(maze.maze_active, "RIDER-1 fixture did not enter embedded maze")
	var set_spec: Dictionary = maze.rotatable_wall_sets()[1]
	var wall := set_spec.walls[0] as CSGBox3D
	var cap := _shape(actor)
	var p := wall.global_transform * Vector3(wall.size.x * 0.3, 0, wall.size.z * 0.5 + actor.radius + 0.15)
	p.y = maze._floor_top_y + (cap.shape as CapsuleShape3D).height * 0.5 + 0.12
	actor.global_position = p
	actor.velocity = Vector3.ZERO
	actor.stats.hp = 7
	actor.stats.oxygen = 0
	for frame in range(3):
		await physics_frame
	_expect(_clear(actor, maze), "RIDER-1 initial capsule is not clear: " + str(actor.global_position))
	print("RIDER_START|wall=", wall.name, "|position=", actor.global_position, "|size=", wall.size)
	if findings.is_empty():
		(set_spec.rotate as Callable).call()
		var offset := Vector3.ZERO
		var contacted := false
		var contact_position := Vector3.ZERO
		for frame in range(65):
			var before := actor.global_position
			await physics_frame
			await process_frame
			if frame % 10 == 0:
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
		_expect(contacted and carried_frames > 10, "RIDER-1 fixture lacks sustained real swept contact")
		if findings.is_empty():
			_expect(actor.global_position.distance_to(contact_position) > 4.0, "RIDER-1 passenger did not travel with wall")
			await create_timer(0.6).timeout
			_expect(_clear(actor, maze), "RIDER-2 released capsule overlaps solid geometry")
			_expect(not actor.is_suction_locked(), "RIDER-3 passenger remains locked after finish")
			_expect(actor.stats.hp == 7 and actor.stats.oxygen == 0, "RIDER-3 rotation changes combat resources")
	await _finish()

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
	return gap.length_squared() < capsule.radius * capsule.radius

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
	print("MAZE WALL RIDERS: clean | retained_frames=", carried_frames) if findings.is_empty() else print("MAZE WALL RIDERS: findings=", findings.size())
	quit(0 if findings.is_empty() else 1)
