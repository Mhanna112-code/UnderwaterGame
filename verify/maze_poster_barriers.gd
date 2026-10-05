extends SceneTree
# POSTER-1: real swimming must not pass around the authored poster wall.
var world: World
var findings: Array[String] = []
var maze: MazeLevel
var west_gap := Vector2.ZERO
var east_gap := Vector2.ZERO
var line := 0.0
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	world = load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = false
	maze = world.embedded_maze
	maze.room_encounters_enabled = false
	maze._strong_room_seen = true
	maze._switch_explained = true
	var actor := world.divers[0] as Diver
	actor.global_position = Vector3(265, 2, 16)
	for frame in range(8):
		await physics_frame
	_expect(maze.maze_active, "POSTER-1 fixture did not enter the shared maze")
	var poster := maze.get_node("HallwayEndWall") as CSGBox3D
	var axis := poster.global_basis.x.normalized()
	var a := poster.global_position - axis * poster.size.x * 0.5
	var b := poster.global_position + axis * poster.size.x * 0.5
	var west := minf(a.x, b.x)
	var floor_shape := maze.get_node("MazeFloorCollision").get_child(0) as CollisionShape3D
	var left := floor_shape.global_position.x - (floor_shape.shape as BoxShape3D).size.x * 0.5
	var x := lerpf(left + 3.0, west - 3.0, 0.5)
	line = poster.global_position.z
	var east := maxf(a.x, b.x)
	var b6 := maze.get_node("CSGBox3D6") as CSGBox3D
	west_gap = Vector2(left + 1.0, west)
	east_gap = Vector2(east, b6.global_position.x - b6.size.z * 0.5)
	if "--restore" in OS.get_cmdline_user_args():
		await _restores()
		await _finish()
		return
	if "--matrix" in OS.get_cmdline_user_args():
		await _matrix()
		await _finish()
		return
	actor.global_position = Vector3(x, 2, line - 2.0)
	actor.velocity = Vector3.ZERO
	maze._yaw = 0.0
	for frame in range(3):
		await physics_frame
		await process_frame
	_expect(_clear(actor), "POSTER-1 boundary approach fixture is not capsule-clear")
	print("POSTER_APPROACH|edge=", left, "|poster_west=", west, "|line=", line, "|start=", actor.global_position)
	if findings.is_empty():
		await _hold(KEY_W, 80)
		print("POSTER_SWIM|end=", actor.global_position, "|owner=", maze.maze_active, "|velocity=", actor.velocity)
		_expect(actor.global_position.z < line - actor.radius,
			"POSTER-1 real W swimming bypasses the poster wall's western end")
		if not capture_dir.is_empty():
			for frame in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			var file := capture_dir.path_join("poster-west-blocked.png")
			_expect(root.get_texture().get_image().save_png(file) == OK, "POSTER-1 native capture failed")
			print("POSTER_CAPTURE|file=", file, "|normal_shared_maze_camera=true")
	await _finish()

func _matrix() -> void:
	var cases := 0
	var rays := 0
	# Independent physical coverage: probe both gaps and their poster/end
	# seams every 25 cm, below and above the normal capsule centre.
	for span in [west_gap, east_gap]:
		var x := (span as Vector2).x
		while x <= (span as Vector2).y + 0.25:
			for y in [maze._floor_top_y + 0.15, 2.0, 5.5]:
				var query := PhysicsRayQueryParameters3D.create(Vector3(x, y, line - 1.5), Vector3(x, y, line + 1.5), 1)
				_expect(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
					"POSTER-1 physical boundary has a seam at x=%s y=%s" % [x, y])
				rays += 1
			x += 0.25
	if not findings.is_empty():
		return
	for selected in 3:
		world.active = selected
		maze.active = selected
		maze._diver = world.divers[selected]
		var actor := maze._diver
		for gap in [west_gap, east_gap]:
			for fraction in [0.3, 0.7]:
				for high in [false, true]:
					for side in [-1.0, 1.0]:
						var x := lerpf((gap as Vector2).x, (gap as Vector2).y, fraction)
						var y := 2.0
						if high:
							var up := PhysicsRayQueryParameters3D.create(Vector3(x, y, line + side * 2.0), Vector3(x, 30, line + side * 2.0), 1)
							var hit := world.get_world_3d().direct_space_state.intersect_ray(up)
							_expect(not hit.is_empty(), "POSTER-1 generated high approach has no physical ceiling")
							if hit.is_empty():
								return
							y = minf(6.0, (hit.position as Vector3).y - actor.height * 0.5 - 0.2)
						actor.global_position = Vector3(x, y, line + side * 2.0)
						actor.velocity = Vector3.ZERO
						maze._yaw = 0.0
						for frame in 3:
							await physics_frame
							await process_frame
						_expect(_clear(actor), "POSTER-1 generated approach is not capsule-clear")
						if not findings.is_empty():
							return
						var before := actor.global_position
						await _hold(KEY_W if side < 0.0 else KEY_S, 60)
						var moved := actor.global_position.distance_to(before)
						_expect(moved > 0.5 and (actor.global_position.z - line) * side >= actor.radius + 0.45,
							"POSTER-1 diver %d gap=%s side=%s y=%s crosses the boundary or never swims" % [selected, gap, side, y])
						print("POSTER_MATRIX|actor=", selected, "|gap=", gap, "|fraction=", fraction, "|side=", side,
							"|y=", y, "|moved=", moved, "|end=", actor.global_position)
						cases += 1
						if not findings.is_empty():
							return
	print("POSTER_MATRIX|cases=", cases, "|independent_physical_rays=", rays)

func _restores() -> void:
	# POSTER-3: these generated JSON placements were legal before the new
	# static fences. Use the real World restore boundary, not the migrator.
	for i in 3:
		var actor := world.divers[i] as Diver
		actor.stats.hp = 6 + i
		actor.stats.oxygen = 0.0 if i == 1 else 11.25 + i
		actor.stats.evasion_current = i
		actor.stats.statuses = {"bleed": {"level": 1, "turns": 2}}
	maze.keys_held = 3
	world.inventory["potion"] = 5
	maze.key_items.append("maze_nav_map")
	var baseline := world._serialize_state()
	var cases := 0
	for selected in 3:
		for legacy in [false, true]:
			for gap in [west_gap, east_gap]:
				for side in [-1.0, 0.0, 1.0]:
					var data := baseline.duplicate(true)
					data.active = selected
					var downed := (selected + 1) % 3 if "--downed" in OS.get_cmdline_user_args() else -1
					for i in 3:
						var point := Vector3(lerpf((gap as Vector2).x, (gap as Vector2).y, 0.3 + i * 0.2), 2.0, line + side * 0.2)
						data.divers[i].position = CampaignSession.vector_data(point)
						data.campaign_checkpoint.maze.positions[i] = CampaignSession.vector_data(point)
						if i == downed:
							data.divers[i].stats.hp = 0
							data.campaign_checkpoint.party[i].stats.hp = 0
					if legacy:
						data.campaign_checkpoint.maze = MazeCoordinateFrame.rebase(data.campaign_checkpoint.maze, Vector3.ZERO)
						data.campaign_checkpoint.maze.erase("coordinate_origin")
					var input_json := JSON.stringify(data)
					_expect(world.restore_checkpoint(JSON.parse_string(input_json)), "POSTER-3 generated saved fence placement rejected")
					for frame in 6:
						await physics_frame
						await process_frame
					var actor := world.divers[selected] as Diver
					_expect(_clear(actor), "POSTER-3 Load leaves the selected capsule buried in the new fence")
					_expect(JSON.stringify(data) == input_json, "POSTER-3 Load mutated its source JSON")
					if not findings.is_empty():
						print("POSTER_RESTORE_RED|actor=", selected, "|legacy=", legacy, "|gap=", gap,
							"|side=", side, "|position=", actor.global_position)
						return
					var away := signf(actor.global_position.z - line)
					var before := actor.global_position
					maze._yaw = 0.0
					await _hold(KEY_W if away > 0.0 else KEY_S, 30)
					_expect(actor.global_position.distance_to(before) > 0.75 and _clear(actor),
						"POSTER-3 restored actor cannot actually swim away")
					for i in 3:
						var other := world.divers[i] as Diver
						_expect(_clear(other) and other.stats.hp == (0 if i == downed else 6 + i)
							and is_equal_approx(other.stats.oxygen, 0.0 if i == 1 else 11.25 + i),
							"POSTER-3 migration strands/refills party member %d" % i)
						var bleed: Dictionary = other.stats.statuses.get("bleed", {})
						_expect(other.stats.evasion_current == i and int(bleed.get("level", 0)) == 1 and int(bleed.get("turns", 0)) == 2,
							"POSTER-3 restore loses stored evasion/statuses for party member %d" % i)
						if not findings.is_empty():
							print("POSTER_RESOURCE_PROBE|actor=", i, "|evasion=", other.stats.evasion_current, "|statuses=", other.stats.statuses)
					_expect(world.active == selected and maze.active == selected and maze.keys_held == 3
						and world.inventory["potion"] == 5 and maze.key_items.count("maze_nav_map") == 1,
						"POSTER-3 migration loses selected actor, keys, map or inventory")
					print("POSTER_RESTORE|actor=", selected, "|legacy=", legacy, "|gap=", gap,
						"|side=", side, "|downed=", downed, "|clear_and_swimmable=true")
					cases += 1
					if not findings.is_empty():
						return
	print("POSTER_RESTORE|generated_JSON_cases=", cases, "|no_player_files=true")

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

func _clear(actor: Diver) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	for child in actor.get_children():
		if child is CollisionShape3D:
			query.shape = child.shape
			query.transform = child.global_transform
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	paused = false
	world.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MAZE POSTER BARRIERS: clean" if findings.is_empty() else "MAZE POSTER BARRIERS: findings=%d" % findings.size())
	quit(0 if findings.is_empty() else 1)
