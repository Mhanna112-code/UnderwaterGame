extends SceneTree
# WHIRL-1: actual World overlap must not catch through a solid wall.
var findings: Array[String] = []
var world: World
var caught := 0
var last_lost := -99

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
	if "--actor-lifetime" in OS.get_cmdline_user_args():
		await _actor_lifetime()
		await _finish()
		return
	if "--damage" in OS.get_cmdline_user_args():
		await _damage()
		await _finish()
		return
	if "--blocked-return" in OS.get_cmdline_user_args() or "--blocked-matrix" in OS.get_cmdline_user_args():
		await _blocked_return()
		await _finish()
		return
	if "--deactivate" in OS.get_cmdline_user_args():
		await _deactivate()
		await _finish()
		return
	if "--lifecycle" in OS.get_cmdline_user_args():
		await _lifecycle()
		await _finish()
		return
	if "--teardown" in OS.get_cmdline_user_args():
		await _teardown()
		await _finish()
		return
	if "--inactive" in OS.get_cmdline_user_args():
		await _inactive()
		await _finish()
		return
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
		for frame in 90:
			await physics_frame
			await process_frame
		_expect(caught == 1 and actor.stats.hp == 5 and actor.stats.oxygen == 0.0
			and not actor.is_suction_locked() and actor.model.visible
			and actor.global_position.distance_to(whirl.reset_to) < 0.05,
			"WHIRL-1 unobstructed real suction fails reset/damage/release")
		print("WHIRL_OPEN|end=", actor.global_position, "|hp=", actor.stats.hp, "|caught=", caught)
	await _finish()

func _teardown() -> void:
	var whirl: Whirlpool
	for child in world.get_children():
		if child is Whirlpool:
			whirl = child
	_expect(whirl != null, "WHIRL-3 fixture has no authored World whirlpool")
	if whirl == null:
		return
	var actor := world.divers[0] as Diver
	actor.sonar_active = false
	var approach := whirl.global_position + Vector3.RIGHT
	actor.global_position = approach
	actor.velocity = Vector3.ZERO
	actor.stats.hp = 7
	actor.stats.oxygen = 0.0
	_expect(_clear(actor), "WHIRL-3 actual authored approach is not capsule-clear")
	if not findings.is_empty():
		return
	for frame in 12:
		await physics_frame
		await process_frame
	_expect(actor.is_suction_locked(), "WHIRL-3 actual Area overlap did not catch the diver")
	if not findings.is_empty():
		return
	print("WHIRL_TEARDOWN_CAUGHT|point=", approach, "|mid=", actor.global_position, "|visible=", actor.model.visible)
	whirl.queue_free()
	for frame in 6:
		await physics_frame
		await process_frame
	var released := actor.global_position
	_expect(not actor.is_suction_locked() and actor.model.visible and _clear(actor)
		and actor.stats.hp == 7 and actor.stats.oxygen == 0.0,
		"WHIRL-3 removing the owner leaves its surviving shared diver locked/hidden/buried or charges damage")
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	for frame in 30:
		await physics_frame
		await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_W
	Input.parse_input_event(event)
	_expect(actor.global_position.distance_to(released) > 0.75,
		"WHIRL-3 real W cannot swim after hazard owner removal")
	print("WHIRL_TEARDOWN|lock=", actor.is_suction_locked(), "|released=", released,
		"|end=", actor.global_position, "|visible=", actor.model.visible, "|hp=", actor.stats.hp)

func _lifecycle() -> void:
	# WHIRL-3: shared actors survive real overlap, owner loss, engine timer
	# interruption and live disk-format restore. No hazard callback is called.
	for child in world.get_children():
		if child is Whirlpool:
			child.queue_free()
	for frame in 6:
		await physics_frame
		await process_frame
	var cases := 0
	for selected in 3:
		world.active = selected
		var actor := world.divers[selected] as Diver
		for phase in ["spiral", "vanish"]:
			for interrupt in ["owner", "scheduler", "restore"]:
				for index in 3:
					world.divers[index].global_position = Vector3(210, 2, 16 + index * 2.0)
					world.divers[index].velocity = Vector3.ZERO
					world.divers[index].sonar_active = false
				actor.global_position = Vector3(226, 2, 16)
				actor.stats.hp = 6
				actor.stats.oxygen = 0.0
				actor.rotation = Vector3(0, 0.35, 0)
				actor.model.rotation = Vector3(0.1, 0.2, 0.3)
				actor.model.visible = true
				var saved: Dictionary = JSON.parse_string(JSON.stringify(world._serialize_state()))
				actor.global_position = Vector3(229.4, 2, 16)
				actor.stats.hp = 7
				var start := actor.global_position
				var whirl := Whirlpool.new()
				whirl.position = Vector3(230, 2, 16)
				whirl.reset_to = Vector3(226, 2, 16)
				whirl.warning_radius = 3.0
				whirl.suction_radius = 0.9
				whirl.suction_height = 12.0
				whirl.pull_duration = 0.5
				whirl.vanish_duration = 0.4
				whirl.damage_min = 2
				whirl.damage_max = 2
				world.add_child(whirl)
				_expect(_clear(actor), "WHIRL-3 generated approach is not capsule-clear")
				var ready := false
				for frame in 100:
					await physics_frame
					await process_frame
					if actor.is_suction_locked() and (phase == "spiral" or not actor.model.visible):
						ready = true
						break
				_expect(ready, "WHIRL-3 generated real overlap did not reach " + phase)
				if not findings.is_empty():
					return
				if interrupt == "owner":
					whirl.queue_free()
				elif interrupt == "scheduler":
					for tween in get_processed_tweens():
						tween.kill()
				else:
					_expect(world.restore_checkpoint(saved), "WHIRL-3 live JSON checkpoint restore was rejected")
				for frame in 75:
					await physics_frame
					await process_frame
				var expected := Vector3(226, 2, 16) if interrupt == "restore" else start
				var expected_hp := 6 if interrupt == "restore" else 7
				print("WHIRL_LIFECYCLE_OBSERVER|at=", actor.global_position, "|wanted=", expected,
					"|rotation=", actor.rotation, "|model_rotation=", actor.model.rotation,
					"|visible=", actor.model.visible, "|hp=", actor.stats.hp, "|clear=", _clear(actor))
				_expect(not actor.is_suction_locked() and actor.model.visible and _clear(actor)
					and actor.global_position.distance_to(expected) < 0.05
					and actor.rotation.distance_to(Vector3(0, 0.35, 0)) < 0.01
					and absf(actor.model.rotation.y - 0.2) < 0.01 and absf(actor.model.rotation.z - 0.3) < 0.01
					and actor.stats.hp == expected_hp and actor.stats.oxygen == 0.0,
					"WHIRL-3 " + phase + "/" + interrupt + " leaves lock/hidden/pose/resource corruption")
				if is_instance_valid(whirl):
					whirl.queue_free()
				for frame in 3:
					await physics_frame
					await process_frame
				var at := actor.global_position
				_key(KEY_W, true)
				for frame in 30:
					await physics_frame
					await process_frame
				_key(KEY_W, false)
				_expect(actor.global_position.distance_to(at) > 0.75, "WHIRL-3 generated interrupted actor cannot really swim")
				print("WHIRL_LIFECYCLE|actor=", selected, "|phase=", phase, "|interrupt=", interrupt,
					"|release=", at, "|hp=", actor.stats.hp, "|lock=", actor.is_suction_locked())
				cases += 1
				if not findings.is_empty():
					return
	print("WHIRL_LIFECYCLE|cases=", cases, "|no_player_files=true")

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _deactivate() -> void:
	var cases := 0
	for selected in 3:
		for phase in ["spiral", "vanish"]:
			# Independent live scenes keep a preceding cancellation's reentry
			# grace from contaminating a generated fresh arrival.
			if cases > 0:
				world.queue_free()
				await process_frame
				world = load("res://game/world.tscn").instantiate() as World
				world.skip_intro_for_test = true
				world.skip_tutorial_for_test = true
				root.add_child(world)
				current_scene = world
				await process_frame
				world.title_screen.close()
				world.random_encounters_enabled = false
				paused = false
			var maze := world.embedded_maze
			var whirl := maze._corridor_4_whirlpool
			maze.set_maze_active(false)
			for index in 3:
				world.divers[index].global_position = Vector3(210, 2, 16 + index * 2.0)
				world.divers[index].velocity = Vector3.ZERO
				world.divers[index].sonar_active = false
			world.active = selected
			var actor := world.divers[selected] as Diver
			var start := whirl.global_position
			start.y = 1.8
			actor.global_position = start
			actor.stats.hp = 7
			actor.stats.oxygen = 0.0
			actor.model.visible = true
			_expect(_clear(actor) and whirl.armed and not bool(whirl.bypass.call()),
				"WHIRL-3 active actual corridor fixture lacks clear water/armed hazard without current bypass")
			world._set_maze_ownership(true)
			var ready := false
			for frame in 160:
				await physics_frame
				await process_frame
				if actor.is_suction_locked() and (phase == "spiral" or not actor.model.visible):
					ready = true
					break
			_expect(ready and maze.maze_active, "WHIRL-3 actual active corridor failed catch/phase " + phase)
			if not findings.is_empty():
				return
			_expect(not maze.can_capture_campaign_snapshot(), "WHIRL-3 suction pose is incorrectly accepted as a stable maze checkpoint")
			maze.set_maze_active(false)
			for frame in 6:
				await physics_frame
				await process_frame
			_expect(not actor.is_suction_locked() and actor.model.visible and _clear(actor)
				and actor.stats.hp == 7 and actor.stats.oxygen == 0.0
				and actor.global_position.distance_to(start) < 0.05,
				"WHIRL-3 disabling the actual maze during " + phase + " retains motion ownership")
			if not findings.is_empty():
				return
			world._set_maze_ownership(true)
			_key(KEY_W, true)
			for frame in 30:
				await physics_frame
				await process_frame
			_key(KEY_W, false)
			_expect(actor.global_position.distance_to(start) > 0.75 and not actor.is_suction_locked(),
				"WHIRL-3 reactivated shared actor cannot swim away after canceled suction")
			print("WHIRL_DEACTIVATE|actor=", selected, "|phase=", phase, "|release=", start,
				"|end=", actor.global_position, "|hp=", actor.stats.hp)
			cases += 1
			if not findings.is_empty():
				return
	print("WHIRL_DEACTIVATE|cases=", cases, "|no_player_files=true")

func _blocked_return() -> void:
	if "--blocked-matrix" in OS.get_cmdline_user_args():
		var cases := 0
		for selected in 3:
			for csg in [false, true]:
				for angle in [0.0, PI * 0.5]:
					for phase in ["spiral", "vanish"]:
						await _blocked_case(selected, csg, angle, phase)
						cases += 1
						if not findings.is_empty():
							return
		print("WHIRL_BLOCKED_MATRIX|cases=", cases, "|no_player_files=true")
	else:
		await _blocked_case(0, true, 0.0, "spiral")

func _blocked_case(selected: int, csg: bool, angle: float, phase: String) -> void:
	world.active = selected
	for index in 3:
		world.divers[index].global_position = Vector3(210, 2, 16 + index * 2.0)
		world.divers[index].velocity = Vector3.ZERO
		world.divers[index].sonar_active = false
	var actor := world.divers[selected] as Diver
	actor.global_position = Vector3(229.4, 2, 16)
	actor.velocity = Vector3.ZERO
	actor.sonar_active = false
	actor.stats.hp = 7
	actor.stats.oxygen = 0.0
	var whirl := Whirlpool.new()
	whirl.position = Vector3(230, 2, 16)
	whirl.reset_to = Vector3(226, 2, 16)
	whirl.suction_radius = 0.9
	whirl.suction_height = 12.0
	whirl.warning_radius = 3.0
	whirl.pull_duration = 1.4
	world.add_child(whirl)
	_expect(_clear(actor), "WHIRL-3 blocked-return initial approach is not clear")
	var ready := false
	for frame in 160:
		await physics_frame
		await process_frame
		if actor.is_suction_locked() and (phase == "spiral" or not actor.model.visible):
			ready = true
			break
	_expect(ready, "WHIRL-3 blocked-return actual overlap did not catch/vanish")
	if not findings.is_empty():
		return
	var block: Node3D
	if csg:
		var box := CSGBox3D.new()
		box.size = Vector3(4, 6, 6)
		box.use_collision = true
		block = box
	else:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4, 6, 6)
		shape.shape = box
		body.add_child(shape)
		block = body
	world.add_child(block)
	block.global_position = Vector3(229.4, 2, 16)
	block.rotation.y = angle
	for frame in 6:
		await physics_frame
		await process_frame
	whirl.queue_free()
	for frame in 6:
		await physics_frame
		await process_frame
	var local := block.global_transform.affine_inverse() * actor.global_position
	var buried := absf(local.x) < 2 + actor.radius and absf(local.z) < 3 + actor.radius and absf(local.y) < 3 + actor.height * 0.5
	_expect(not buried and _clear(actor) and not actor.is_suction_locked() and actor.model.visible
		and actor.stats.hp == 7 and actor.stats.oxygen == 0.0,
		"WHIRL-3 cancellation releases inside a newly solid CSG departure")
	var at := actor.global_position
	var move_key := 0
	for candidate in [[KEY_W, Vector3.BACK], [KEY_S, Vector3.FORWARD], [KEY_A, Vector3.RIGHT], [KEY_D, Vector3.LEFT]]:
		var query := PhysicsShapeQueryParameters3D.new()
		for child in actor.get_children():
			if child is CollisionShape3D:
				query.shape = child.shape
				query.transform = child.global_transform
		query.collision_mask = 1
		query.exclude = [actor.get_rid()]
		query.motion = (candidate[1] as Vector3) * 2.0
		var fractions := actor.get_world_3d().direct_space_state.cast_motion(query)
		if fractions[0] >= 0.99:
			move_key = int(candidate[0])
			break
	_expect(move_key != 0, "WHIRL-3 blocked-return fixture has no physically clear swim direction")
	if move_key == 0:
		return
	_key(move_key, true)
	for frame in 30:
		await physics_frame
		await process_frame
	_key(move_key, false)
	_expect(actor.global_position.distance_to(at) > 0.75, "WHIRL-3 blocked-return recovery cannot really swim")
	print("WHIRL_BLOCKED_RETURN|actor=", selected, "|csg=", csg, "|angle=", angle, "|phase=", phase,
		"|release=", at, "|buried=", buried, "|key=", move_key, "|end=", actor.global_position, "|hp=", actor.stats.hp)
	block.queue_free()
	for frame in 4:
		await physics_frame
		await process_frame

func _damage() -> void:
	var cases := 0
	for selected in 3:
		world.active = selected
		for hp in [0, 1, 2, 7]:
			for damage in [0, 2, 10]:
				for index in 3:
					world.divers[index].global_position = Vector3(210, 2, 16 + index * 2.0)
					world.divers[index].velocity = Vector3.ZERO
					world.divers[index].sonar_active = false
				var actor := world.divers[selected] as Diver
				actor.global_position = Vector3(229.4, 2, 16)
				actor.stats.hp = hp
				actor.stats.oxygen = 0.0
				actor.model.visible = true
				var whirl := Whirlpool.new()
				whirl.position = Vector3(230, 2, 16)
				whirl.reset_to = Vector3(226, 2, 16)
				whirl.suction_radius = 0.9
				whirl.suction_height = 12.0
				whirl.warning_radius = 3.0
				whirl.pull_duration = 0.1
				whirl.vanish_duration = 0.05
				whirl.damage_min = damage
				whirl.damage_max = damage
				caught = 0
				last_lost = -99
				whirl.diver_sucked_in.connect(func(_actor: Diver, lost: int) -> void:
					caught += 1
					last_lost = lost
				)
				world.add_child(whirl)
				for frame in 60:
					await physics_frame
					await process_frame
				var expected_loss := mini(damage, maxi(hp - 1, 0))
				_expect(caught == 1 and last_lost == expected_loss and actor.stats.hp == hp - expected_loss
					and actor.stats.oxygen == 0.0 and actor.model.visible and not actor.is_suction_locked()
					and _clear(actor) and actor.global_position.distance_to(whirl.reset_to) < 0.05,
					"WHIRL-4 actual completed suction revives/downed, knocks out living, reports negative loss or spends O2")
				print("WHIRL_DAMAGE|actor=", selected, "|before=", hp, "|damage=", damage,
					"|after=", actor.stats.hp, "|reported=", last_lost, "|completions=", caught)
				whirl.queue_free()
				for frame in 3:
					await physics_frame
					await process_frame
				cases += 1
				if not findings.is_empty():
					return
	print("WHIRL_DAMAGE|cases=", cases, "|no_player_files=true")

func _actor_lifetime() -> void:
	for index in 3:
		world.divers[index].global_position = Vector3(210, 2, 16 + index * 2.0)
		world.divers[index].velocity = Vector3.ZERO
		world.divers[index].sonar_active = false
	var cases := 0
	for selected in 3:
		for phase in ["spiral", "vanish"]:
			var actor := Diver.new()
			actor.model_name = world.divers[selected].model_name
			world.add_child(actor)
			actor.global_position = Vector3(229.4, 2, 16)
			var whirl := Whirlpool.new()
			whirl.position = Vector3(230, 2, 16)
			whirl.reset_to = Vector3(226, 2, 16)
			whirl.suction_radius = 0.9
			whirl.suction_height = 12.0
			whirl.warning_radius = 3.0
			whirl.pull_duration = 0.5
			whirl.vanish_duration = 0.4
			world.add_child(whirl)
			var ready := false
			for frame in 100:
				await physics_frame
				await process_frame
				if actor.is_suction_locked() and (phase == "spiral" or not actor.model.visible):
					ready = true
					break
			_expect(ready, "WHIRL-3 disposable real actor never reached its removal phase")
			if not findings.is_empty():
				return
			actor.queue_free()
			for frame in 75:
				await physics_frame
				await process_frame
			_expect(not whirl.busy(), "WHIRL-3 removed actor retains hazard ownership")
			var replacement := Diver.new()
			replacement.model_name = world.divers[selected].model_name
			world.add_child(replacement)
			replacement.global_position = Vector3(229.4, 2, 16)
			caught = 0
			whirl.diver_sucked_in.connect(func(_actor: Diver, _lost: int) -> void: caught += 1)
			for frame in 120:
				await physics_frame
				await process_frame
			_expect(caught == 1 and not replacement.is_suction_locked() and _clear(replacement)
				and replacement.global_position.distance_to(whirl.reset_to) < 0.05,
				"WHIRL-3 removed actor leaves hazard unable to catch/release a new live actor")
			print("WHIRL_ACTOR_LIFETIME|rig=", selected, "|phase=", phase, "|replacement_completions=", caught)
			replacement.queue_free()
			whirl.queue_free()
			for frame in 3:
				await physics_frame
				await process_frame
			cases += 1
			if not findings.is_empty():
				return
	for selected in 3:
		var actor := world.divers[selected] as Diver
		var at := Vector3(229.4, 2, 16)
		actor.global_position = at
		actor.velocity = Vector3.ZERO
		actor.stats.hp = 7
		actor.stats.oxygen = 0.0
		actor.collision_mask = [5, 9, 17][selected]
		actor.set_suction_locked(true)
		actor.model.visible = false
		var whirl := Whirlpool.new()
		whirl.position = Vector3(230, 2, 16)
		whirl.suction_radius = 0.9
		whirl.warning_radius = 3.0
		world.add_child(whirl)
		for frame in 12:
			await physics_frame
			await process_frame
		print("WHIRL_NONSTEAL_OBSERVER|actor=", selected, "|own_busy=", whirl.busy(), "|positions=",
			world.divers.map(func(d: Diver) -> Vector3: return d.global_position), "|locked=", actor.is_suction_locked())
		_expect(not whirl.busy(), "WHIRL-3 hazard steals a preexisting lock")
		whirl.queue_free()
		for frame in 6:
			await physics_frame
			await process_frame
		_expect(actor.is_suction_locked() and not actor.model.visible and actor.stats.hp == 7
			and actor.stats.oxygen == 0.0 and actor.global_position.distance_to(at) < 0.05
			and actor.collision_mask == [5, 9, 17][selected],
			"WHIRL-3 hazard teardown clears an external lock/model/mask owner or charges resources")
		print("WHIRL_NONSTEAL|actor=", selected, "|mask=", actor.collision_mask, "|lock=", actor.is_suction_locked())
		actor.set_suction_locked(false)
		actor.model.visible = true
		actor.global_position = Vector3(210, 2, 16 + selected * 2.0)
		cases += 1
	print("WHIRL_ACTOR_LIFETIME|cases=", cases, "|no_player_files=true")

func _inactive() -> void:
	# WHIRL-2: verify, rather than assume, whether inactive child overlap
	# signals can acquire ownership of a parked shared actor.
	# The selected World actor stays outside; a parked shared party member
	# enters the actual authored inactive maze whirlpool, not a dummy hazard.
	world.divers[0].global_position = Vector3(220, 2, 16)
	world.divers[0].velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
	var maze := world.embedded_maze
	var whirl := maze._corridor_4_whirlpool
	var actor := world.divers[1] as Diver
	_expect(not maze.maze_active and whirl.armed and not bool(whirl.bypass.call()),
		"WHIRL-2 inactive fixture does not have an armed authored hazard without bypass")
	var point := whirl.global_position
	point.y = 1.8
	actor.global_position = point
	actor.velocity = Vector3.ZERO
	actor.stats.hp = 7
	actor.stats.oxygen = 0.0
	_expect(_clear(actor), "WHIRL-2 inactive actual whirlpool approach is not capsule-clear")
	if not findings.is_empty():
		return
	var locked := false
	for frame in 15:
		await physics_frame
		await process_frame
		locked = locked or actor.is_suction_locked()
	_expect(not locked and actor.stats.hp == 7 and actor.stats.oxygen == 0.0
		and actor.model.visible and actor.global_position.distance_to(point) < 0.05,
		"WHIRL-2 inactive maze catches/moves a parked shared diver")
	_expect(root.get_viewport().get_camera_3d() == world.cam and not maze.get_node("HUD").visible,
		"WHIRL-2 inactive fixture changes the selected World camera/HUD owner")
	_expect(not is_instance_valid(Whirlpool._warning_caption) or not Whirlpool._warning_caption.visible,
		"WHIRL-2 inactive maze shows its root-owned danger caption")
	print("WHIRL_INACTIVE|active_world=", world.active, "|maze_active=", maze.maze_active,
		"|hazard_can_process=", whirl.can_process(), "|lock_seen=", locked, "|point=", point,
		"|end=", actor.global_position, "|hp=", actor.stats.hp)

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
					for frame in 90:
						await physics_frame
						await process_frame
					print("WHIRL_OPEN_OBSERVER|actor=", selected, "|caught=", caught, "|hp=", actor.stats.hp,
						"|at=", actor.global_position, "|visible=", actor.model.visible, "|locked=", actor.is_suction_locked())
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
