extends SceneTree
# WHIRL-1: actual World overlap must not catch through a solid wall.
var findings: Array[String] = []
var world: World
var caught := 0

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
	world.random_encounters_enabled = false
	paused = false
	if "--matrix" in OS.get_cmdline_user_args():
		await _matrix()
		await _finish()
		return
	var actor := world.divers[0] as Diver
	actor.sonar_active = false
	actor.global_position = Vector3(228.8, 2, 16)
	actor.velocity = Vector3.ZERO
	actor.stats.hp = 7
	actor.stats.oxygen = 0.0
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.15, 6, 6)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = Vector3(229.5, 2, 16)
	for frame in 3:
		await physics_frame
	_expect(_clear(actor), "WHIRL-1 captured approach fixture is not capsule-clear")
	if not findings.is_empty():
		await _finish()
		return
	var whirl := Whirlpool.new()
	whirl.position = Vector3(230, 2, 16)
	whirl.reset_to = Vector3(226, 2, 16)
	whirl.suction_radius = 0.9
	whirl.suction_height = 12.0
	whirl.warning_radius = 3.0
	whirl.pull_radius = 2.0
	whirl.pull_speed = 2.0
	whirl.pull_duration = 0.4
	whirl.vanish_duration = 0.1
	whirl.damage_min = 2
	whirl.damage_max = 2
	whirl.diver_sucked_in.connect(func(_d: Diver, _amount: int) -> void: caught += 1)
	world.add_child(whirl)
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(actor.global_position, whirl.global_position, 1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	_expect(not hit.is_empty() and hit.collider == wall, "WHIRL-1 fixture has no real intervening wall")
	var start := actor.global_position
	var saw_lock := actor.is_suction_locked()
	for frame in 50:
		await physics_frame
		await process_frame
		saw_lock = saw_lock or actor.is_suction_locked()
	print("WHIRL_OCCLUDED|start=", start, "|end=", actor.global_position, "|lock_seen=", saw_lock,
		"|hp=", actor.stats.hp, "|caught=", caught)
	_expect(not saw_lock and caught == 0 and actor.stats.hp == 7
		and actor.global_position.distance_to(Vector3(228.8, 2, 16)) < 0.05,
		"WHIRL-1 real suction/pull catches a diver through a solid wall")
	if findings.is_empty():
		wall.queue_free()
		for frame in 3:
			await physics_frame
		# Actor already overlaps the warning zone; moving into the real
		# suction core must still work after wall removal, without callbacks.
		actor.global_position = Vector3(229.4, 2, 16)
		actor.velocity = Vector3.ZERO
		for frame in 50:
			await physics_frame
			await process_frame
		_expect(caught == 1 and actor.stats.hp == 5 and actor.stats.oxygen == 0.0
			and not actor.is_suction_locked() and actor.model.visible
			and actor.global_position.distance_to(whirl.reset_to) < 0.05,
			"WHIRL-1 unobstructed real suction fails reset/damage/release")
		print("WHIRL_OPEN|end=", actor.global_position, "|hp=", actor.stats.hp, "|caught=", caught)
	await _finish()

func _matrix() -> void:
	var cases := 0
	for selected in 3:
		world.active = selected
		var actor := world.divers[selected] as Diver
		for csg in [false, true]:
			for cylinder in [false, true]:
				for angle in [0.0, PI * 0.5]:
					for i in 3:
						world.divers[i].global_position = Vector3(210, 2, 16 + i * 2.0)
						world.divers[i].velocity = Vector3.ZERO
						world.divers[i].sonar_active = false
					var axis := Vector3.RIGHT.rotated(Vector3.UP, angle)
					var centre := Vector3(230, 2, 16)
					var before := centre - axis * (0.9 + actor.radius * 0.7)
					actor.global_position = before
					actor.velocity = Vector3.ZERO
					actor.stats.hp = 7
					actor.stats.oxygen = 0.0
					var wall: Node3D
					if csg:
						var box := CSGBox3D.new()
						box.size = Vector3(0.15, 6, 6)
						box.use_collision = true
						wall = box
					else:
						var body := StaticBody3D.new()
						var shape := CollisionShape3D.new()
						var box := BoxShape3D.new()
						box.size = Vector3(0.15, 6, 6)
						shape.shape = box
						body.add_child(shape)
						wall = body
					world.add_child(wall)
					wall.global_position = centre - axis * 0.5
					wall.rotation.y = angle
					for frame in 6:
						await physics_frame
						await process_frame
					var query := PhysicsRayQueryParameters3D.create(actor.global_position, centre, 1)
					var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
					_expect(not hit.is_empty() and hit.collider == wall and _clear(actor),
						"WHIRL-1 generated wall fixture lacks real obstruction or capsule clearance")
					if not findings.is_empty():
						return
					var whirl := Whirlpool.new()
					whirl.position = centre
					# The actual World ramp has north/south side rails. The reset
					# remains in its clear approach irrespective of panel yaw.
					whirl.reset_to = centre - Vector3.RIGHT * 4.0
					whirl.suction_radius = 0.9
					whirl.suction_height = 12.0 if cylinder else 0.0
					whirl.warning_radius = 3.0
					whirl.pull_radius = 2.0
					whirl.pull_speed = 2.0
					whirl.pull_duration = 0.4
					whirl.vanish_duration = 0.1
					whirl.damage_min = 2
					whirl.damage_max = 2
					_expect(_clear_at(actor, whirl.reset_to), "WHIRL-1 generated reset fixture is not capsule-clear")
					if not findings.is_empty():
						return
					caught = 0
					whirl.diver_sucked_in.connect(func(_d: Diver, _amount: int) -> void: caught += 1)
					world.add_child(whirl)
					var saw_lock := false
					for frame in 40:
						await physics_frame
						await process_frame
						saw_lock = saw_lock or actor.is_suction_locked()
					_expect(not saw_lock and caught == 0 and actor.stats.hp == 7 and actor.global_position.distance_to(before) < 0.05,
						"WHIRL-1 generated suction/drag crosses solid wall")
					if not findings.is_empty():
						return
					wall.queue_free()
					for frame in 3:
						await physics_frame
					actor.global_position = centre - axis * 0.6
					actor.velocity = Vector3.ZERO
					var open_ray := actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.global_position, centre, 1))
					_expect(open_ray.is_empty(), "WHIRL-1 open fixture still has an authored intervening solid")
					if not findings.is_empty():
						return
					for frame in 40:
						await physics_frame
						await process_frame
					_expect(caught == 1 and actor.stats.hp == 5 and actor.stats.oxygen == 0.0
						and not actor.is_suction_locked() and actor.model.visible and actor.global_position.distance_to(whirl.reset_to) < 0.05,
						"WHIRL-1 generated open suction fails to reset/damage/release")
					print("WHIRL_MATRIX|actor=", selected, "|csg=", csg, "|cylinder=", cylinder, "|angle=", angle,
						"|blocked_then_open=true|caught=", caught, "|end=", actor.global_position)
					whirl.queue_free()
					for frame in 4:
						await physics_frame
						await process_frame
					cases += 1
					if not findings.is_empty():
						return
	print("WHIRL_MATRIX|cases=", cases, "|no_player_files=true")

func _clear(actor: Diver) -> bool:
	return _clear_at(actor, actor.global_position)

func _clear_at(actor: Diver, at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	for child in actor.get_children():
		if child is CollisionShape3D:
			query.shape = child.shape
			query.transform = child.global_transform
			query.transform.origin += at - actor.global_position
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	world.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("WHIRLPOOL SAFETY: clean" if findings.is_empty() else "WHIRLPOOL SAFETY: findings=%d" % findings.size())
	quit(0 if findings.is_empty() else 1)
