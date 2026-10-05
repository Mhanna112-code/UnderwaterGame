extends SceneTree
# WALL-1: query real moving-wall collision, not just scene node existence.
var world: World
var findings: Array[String] = []
var samples := 0
var c5_cases := 0
var swept_capsule_frames := 0
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
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
	var actor := world.divers[0] as Diver
	actor.global_position = Vector3(265, 2, 16)
	actor.velocity = Vector3.ZERO
	for frame in range(8):
		await physics_frame
	_expect(maze.maze_active, "WALL-1 fixture failed to enter the live embedded maze")
	if OS.get_cmdline_user_args().has("--teardown"):
		await _teardown_probe(maze)
		await _finish()
		return
	if OS.get_cmdline_user_args().has("--interruption-only"):
		await _interruption_probe(maze)
		await _finish()
		return
	var walls: Array = maze.rotatable_wall_sets()[2].walls
	print("WALL_HOME|", walls.map(func(w: CSGBox3D) -> String: return "%s:%s:%s" % [w.name, w.global_position, w.size]))
	(maze.rotatable_wall_sets()[2].rotate as Callable).call()
	for frame in range(12):
		await physics_frame
		for wall: CSGBox3D in walls:
			var half := wall.size.z * 0.5
			var across := wall.global_basis.z.normalized()
			var from := wall.global_position + across * (half + 0.4)
			var to := wall.global_position - across * (half + 0.4)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			_expect(hit.is_empty() or hit.collider != wall,
				"WALL-1 moving %s remains physically solid at frame %d" % [wall.name, frame])
			var skirt := wall.get_node("Skirt") as StaticBody3D
			from.y = skirt.global_position.y
			to.y = from.y
			hit = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			_expect(hit.is_empty() or hit.collider != skirt,
				"WALL-1 moving %s skirt remains physically solid at frame %d" % [wall.name, frame])
			samples += 2
		if not findings.is_empty():
			break
	await create_timer(1.6).timeout
	for wall: CSGBox3D in walls:
		_expect(wall.collision_layer != 0 and (wall.get_node("Skirt") as StaticBody3D).collision_layer != 0,
			"WALL-2 finished rotation leaves %s ghosted" % wall.name)
	if findings.is_empty():
		await _c5_probe(maze)
	if findings.is_empty() and not OS.get_cmdline_user_args().has("--visual-only"):
		await _interruption_probe(maze)
	await _finish()

func _c5_probe(maze: MazeLevel) -> void:
	# Independent bounds: physical corridor western corners, Box8/9 faces,
	# and the home north endpoints of walls10/11. No call to _c5_zone().
	var corridor_shape: CollisionShape3D
	for child in maze.get_node("WindCorridor5").get_children():
		if child is CollisionShape3D:
			corridor_shape = child
	var extent := (corridor_shape.shape as BoxShape3D).size * 0.5
	var west := INF
	for x in [-extent.x, extent.x]:
		for z in [-extent.z, extent.z]:
			west = minf(west, (corridor_shape.global_transform * Vector3(x, 0, z)).x)
	var b8 := maze.get_node("CSGBox3D8") as CSGBox3D
	var b9 := maze.get_node("CSGBox3D9") as CSGBox3D
	var zlo := minf(b8.global_position.z, b9.global_position.z)
	var zhi := maxf(b8.global_position.z, b9.global_position.z)
	var east := -INF
	for home in maze._walls_10_11_home:
		east = maxf(east, (home[1] as Vector3).x)
	print("C5_ORACLE|west=", west, "|east=", east, "|z=", zlo, "..", zhi)
	# Put the current in its normal paired corridor instead of deleting it.
	# Separate current-on differential trials follow; this isolates wall carry.
	if not OS.get_cmdline_user_args().has("--currents"):
		maze.rotate_corridors_right(maze.get_node("WindCorridor5"), maze.get_node("WindCorridor6"))
	var home_data: Dictionary
	if maze._walls_10_11_swung:
		(maze.rotatable_wall_sets()[2].rotate as Callable).call()
		await create_timer(1.5).timeout
	home_data = world._serialize_state()
	for selected in range(3):
		for opening in [true, false]:
			for fraction in [0.2, 0.5, 0.8]:
				if OS.get_cmdline_user_args().has("--visual-only") and (not opening or not is_equal_approx(fraction, 0.5)):
					continue
				_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(home_data))), "WALL-1 generated home fixture restore rejected")
				world.active = selected
				maze.active = selected
				maze._diver = world.divers[selected]
				var actor := maze._diver
				if not opening:
					(maze.rotatable_wall_sets()[2].rotate as Callable).call()
					await create_timer(1.5).timeout
				var initial := Vector3(lerpf(west + 2.0, east - 2.0, fraction), _height(actor, maze), (zlo + zhi) * 0.5)
				actor.global_position = initial
				actor.velocity = Vector3.ZERO
				for frame in range(4):
					await physics_frame
				_expect(_clear(actor, maze), "WALL-1 invalid generated C5 capsule placement: " + str(actor.global_position))
				if not findings.is_empty():
					return
				actor.stats.hp = 7
				actor.stats.oxygen = 0
				(maze.rotatable_wall_sets()[2].rotate as Callable).call()
				var collided := false
				for frame in range(95):
					var before := actor.global_position
					await physics_frame
					for wall: CSGBox3D in maze.rotatable_wall_sets()[2].walls:
						if _overlap_volume(actor, before, wall):
							swept_capsule_frames += 1
							collided = true
					# Physics/current motion stays bounded by the live velocity;
					# a direct moving-wall shove is an additional displacement.
					var permitted := actor.velocity.length() / Engine.physics_ticks_per_second + 0.04
					if before.x >= west and before.x <= east and before.z >= zlo and before.z <= zhi:
						_expect(before.distance_to(actor.global_position) <= permitted,
							"WALL-1 diver %d is carried/shoved in C5 at frame %d (%s -> %s)" % [selected, frame, before, actor.global_position])
					if not findings.is_empty():
						print("C5_FAILED_FRAME|zone=", maze.call("_c5_zone"), "|velocity=", actor.velocity, "|push=", actor.external_push,
							"|moving=", maze._moving_wall_nodes.keys(), "|wall10=", maze.get_node("CSGBox3D10").global_position)
						for wall: CSGBox3D in maze.rotatable_wall_sets()[2].walls:
							print("C5_COLLISION_LAYERS|wall=", wall.name, "|layer=", wall.collision_layer, "|skirt=", wall.get_node("Skirt").collision_layer)
						for i in actor.get_slide_collision_count():
							print("C5_SLIDE|", actor.get_slide_collision(i).get_collider().get_path())
						return
					if frame == 40 and opening and is_equal_approx(fraction, 0.5) and not capture_dir.is_empty():
						await RenderingServer.frame_post_draw
						_expect(root.get_texture().get_image().save_png(capture_dir.path_join("c5-motion-%d.png" % selected)) == OK,
							"WALL-1 native motion screenshot could not be saved")
				_expect(_clear(actor, maze) and not actor.is_suction_locked() and maze.can_capture_campaign_snapshot(),
					"WALL-2 C5 rotation ends inside solids or retains input/save ownership")
				_expect(actor.stats.hp == 7 and actor.stats.oxygen == 0, "WALL-1 C5 rotation changes HP/Oxygen")
				if opening and is_equal_approx(fraction, 0.5) and not capture_dir.is_empty():
					await create_timer(0.8).timeout
					await RenderingServer.frame_post_draw
					_expect(root.get_texture().get_image().save_png(capture_dir.path_join("c5-released-%d.png" % selected)) == OK,
						"WALL-2 native release screenshot could not be saved")
				c5_cases += 1
				print("C5_CASE|diver=", selected, "|opening=", opening, "|fraction=", fraction,
					"|swept=", collided, "|start=", initial, "|end=", actor.global_position)
	_expect(swept_capsule_frames > 0, "WALL-1 generated C5 cases never actually meet a swept wall")

func _interruption_probe(maze: MazeLevel) -> void:
	for actor in world.divers:
		actor.global_position = Vector3(265, 2, 16)
		actor.velocity = Vector3.ZERO
	for frame in range(8):
		await physics_frame
	var baseline := world._serialize_state()
	var walls: Array = maze.rotatable_wall_sets()[2].walls
	for selected in range(3):
		for delay in [3, 25, 55]:
			var selected_data := baseline.duplicate(true)
			selected_data.active = selected
			_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(selected_data))), "WALL-2 initial checkpoint restore rejected")
			(maze.rotatable_wall_sets()[2].rotate as Callable).call()
			for frame in range(delay):
				await physics_frame
			_expect(not maze.can_capture_campaign_snapshot(), "WALL-2 live rotation is incorrectly saveable")
			_expect(world.restore_checkpoint(JSON.parse_string(JSON.stringify(selected_data))), "WALL-2 mid-rotation restore rejected")
			_expect(world.active == selected and maze.active == selected, "WALL-2 checkpoint loses selected diver")
			for frame in range(95):
				await physics_frame
				for wall: CSGBox3D in walls:
					var spec: Dictionary = baseline.campaign_checkpoint.maze.walls[String(wall.name)]
					_expect(wall.position.distance_to(CampaignSession.vector_from(spec.position)) < 0.01,
						"WALL-2 old Tween overwrites loaded wall " + String(wall.name))
			_expect(maze.can_capture_campaign_snapshot(), "WALL-2 checkpoint leaves stale wall-motion ownership")
			_expect(walls.all(func(w: CSGBox3D) -> bool: return w.collision_layer != 0 and (w.get_node("Skirt") as StaticBody3D).collision_layer != 0),
				"WALL-2 checkpoint leaves disabled collision")
			print("WALL_RESTORE|actor=", selected, "|delay_frames=", delay, "|loaded_geometry_retained=true")
			if not findings.is_empty():
				return
		var actor := maze._diver
		var before := actor.global_position
		await _hold(KEY_W, 20)
		_expect(actor.global_position.distance_to(before) > 0.5, "WALL-2 restored diver %d cannot actually swim" % selected)
	# Kill one actual registered Tween: no finished callback will arrive for it.
	(maze.rotatable_wall_sets()[2].rotate as Callable).call()
	for frame in range(25):
		await physics_frame
	var pending := get_processed_tweens()
	var killed := false
	for tween in pending:
		if tween.is_valid():
			tween.kill()
			killed = true
	_expect(killed, "WALL-2 fixture did not interrupt the live Tween scheduler")
	for frame in range(8):
		await physics_frame
	_expect(maze.can_capture_campaign_snapshot() and walls.all(func(w: CSGBox3D) -> bool: return w.collision_layer != 0),
		"WALL-2 killed Tween leaves geometry/input permanently in motion")
	print("WALL_KILL|settled_target=", maze._walls_10_11_swung, "|saveable=", maze.can_capture_campaign_snapshot())
	if not findings.is_empty():
		return
	# Disable the actual subtree while a fresh rotation is in flight. No
	# inactive owner may retain a suspended collider or unsaveable motion.
	(maze.rotatable_wall_sets()[2].rotate as Callable).call()
	for frame in range(25):
		await physics_frame
	world.set_physics_process(false)
	maze.set_maze_active(false)
	for frame in range(6):
		await physics_frame
	_expect(maze.can_capture_campaign_snapshot() and walls.all(func(w: CSGBox3D) -> bool: return w.collision_layer != 0),
		"WALL-2 inactive maze retains ghosted colliders or unsaveable wall motion")
	maze.set_maze_active(true)
	world.set_physics_process(true)
	await _hold(KEY_W, 20)
	print("WALL_INACTIVE|reentered=true|geometry_settled=true|owner_released=true")

func _teardown_probe(maze: MazeLevel) -> void:
	var walls: Array = maze.rotatable_wall_sets()[2].walls
	# Non-default authored layers must be restored, not hardcoded to 1.
	walls[0].collision_layer = 5
	walls[0].get_node("Skirt").collision_layer = 9
	var child_body := walls[0].get_node("SplitRock/Body") as StaticBody3D
	child_body.collision_layer = 17
	(maze.rotatable_wall_sets()[2].rotate as Callable).call()
	for frame in range(25):
		await physics_frame
	_expect(not maze.can_capture_campaign_snapshot(), "WALL-2 teardown never entered rotation")
	var target_data: Array = maze._walls_10_11_targets()
	# Retain shared World actors and stop test dispatch into an absent subtree;
	# remove the real owner, not its cleanup helper or a mocked Tween.
	world.set_physics_process(false)
	world.remove_child(maze)
	for frame in range(3):
		await physics_frame
	_expect(walls[0].collision_layer == 5 and walls[0].get_node("Skirt").collision_layer == 9 and child_body.collision_layer == 17,
		"WALL-2 removed owner leaves wall/skirt/attached-rock layers corrupted")
	for spec in target_data:
		var wall := spec[0] as CSGBox3D
		_expect(wall.position.distance_to(spec[1]) < 0.01, "WALL-2 removed owner leaves half-rotated geometry")
	_expect(world.divers.all(func(d: Diver) -> bool: return is_instance_valid(d) and not d.is_suction_locked()),
		"WALL-2 removed maze locks or destroys surviving World actors")
	print("WALL_TEARDOWN|shared_actors_alive=true|layers=5,9,17|settled_geometry=true")
	world.embedded_maze = null
	maze.free()

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

func _height(actor: Diver, maze: MazeLevel) -> float:
	var cap := _capsule(actor)
	return maze._floor_top_y + (cap.shape as CapsuleShape3D).height * 0.5 + 0.12

func _capsule(actor: Diver) -> CollisionShape3D:
	for child in actor.get_children():
		if child is CollisionShape3D:
			return child
	return null

func _overlap_volume(actor: Diver, at: Vector3, wall: CSGBox3D) -> bool:
	var cap := _capsule(actor).shape as CapsuleShape3D
	var local: Vector3 = wall.global_transform.affine_inverse() * at
	var half := wall.size * 0.5
	var segment := cap.height * 0.5 - cap.radius
	var gap := Vector3(maxf(absf(local.x) - half.x, 0), maxf(absf(local.y) - half.y - segment, 0), maxf(absf(local.z) - half.z, 0))
	return gap.length_squared() < cap.radius * cap.radius

func _clear(actor: Diver, maze: MazeLevel) -> bool:
	for wall in maze.wall_boxes:
		if is_instance_valid(wall) and wall.use_collision and wall.collision_layer != 0 and _overlap_volume(actor, actor.global_position, wall):
			return false
	var shape := _capsule(actor)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
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
	print("MAZE WALL MOTION: clean | physical_samples=", samples, "|C5_cases=", c5_cases, "|swept_capsule_frames=", swept_capsule_frames) if findings.is_empty() else print("MAZE WALL MOTION: findings=", findings.size())
	quit(0 if findings.is_empty() else 1)
