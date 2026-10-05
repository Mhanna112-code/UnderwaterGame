extends SceneTree
## EARN-4: earned navigation belongs to maze exploration, not every position.
var findings: Array[String] = []
var cases := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
	root.add_child(maze)
	current_scene = maze
	for frame in 12:
		await physics_frame
	maze.room_encounters_enabled = false
	maze.random_encounters_enabled = false
	maze._strong_room_seen = true # No tutorial warning modal in boundary fixtures.
	maze._puppet_prompt_cooldown = 100000.0 # Separate approach/confirmation tests own this modal.
	# Freeze actor locomotion at sampled boundary positions. Currents and
	# collision/whirlpool motion have their own physical acceptance tests;
	# moving this fixture back inside would make an outside-input oracle false.
	for diver in maze.divers:
		diver._suction_locked = true
	# Boundary fixture, NOT acquisition or traversal proof. EARN-1 earns it.
	maze.key_items.append("maze_nav_map")
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	map.intro_seen = true # Post-lesson boundary fixture; first-open has its own real-E/L test.
	var badge := maze.get_node("HUD/MazeExplorationControls").find_child("MazeMapAvailability", true, false) as Label
	var bounds := maze.nav_map_area()
	print("EARNED MAP REGION|bounds=", bounds)
	var home := maze.get_node("DiverEntry").global_position as Vector3
	var chest := maze.get_node("MapChest").global_position as Vector3
	_expect(bounds.has_point(Vector2(home.x, home.z)) and bounds.has_point(Vector2(chest.x, chest.z)),
		"EARN-4 authored entrance or actual Control Room chest is outside the navigation region")
	var rng := RandomNumberGenerator.new()
	rng.seed = 970404
	for active in 3:
		_expect(maze.active == active, "EARN-4 fixture did not select each distinct diver")
		# Every edge and generated interior points, with independent expected
		# states; no call to can_open_nav_map is used as the result oracle.
		for sample in 12:
			var inside := bounds.position + bounds.size * Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9))
			var outside := inside
			match sample % 4:
				0: outside.x = bounds.position.x - 2
				1: outside.x = bounds.end.x + 2
				2: outside.y = bounds.position.y - 2
				3: outside.y = bounds.end.y + 2
			for point in [inside, outside]:
				# Disable swim only for the frame-stable boundary fixture; UI and
				# production input still run, and physics owns badge/map closure.
				maze._diver.set("speed", 0.0)
				maze._diver.global_position = Vector3(point.x, 2, point.y)
				maze._diver.velocity = Vector3.ZERO
				for frame in 2:
					await physics_frame
				# Generated points can cross genuine proximity explanations.
				# Dismiss those through Escape; this test covers map bounds,
				# not whether L should bypass another modal owner.
				for attempt in 3:
					if not maze.any_modal_open():
						break
					await _key(KEY_ESCAPE)
					await process_frame
				_expect(not maze.any_modal_open(), "EARN-4 boundary fixture retained a separate modal owner")
				# Declining the real puppet prompt deliberately backs the diver
				# away. Restore this boundary fixture after that public dismissal,
				# during its normal cooldown, rather than mislabeling the new
				# inside position as an outside-map defect.
				maze._diver.global_position = Vector3(point.x, 2, point.y)
				for frame in 2:
					await physics_frame
				_expect(maze._diver.global_position.distance_to(Vector3(point.x, 2, point.y)) < 0.1,
					"EARN-4 boundary fixture moved before its input oracle")
				var allowed: bool = point == inside
				_expect(badge != null and badge.visible == allowed,
					"EARN-4 HUD advertises unavailable L or hides available L")
				await _key(KEY_L)
				_expect(map.main_map.visible == allowed, "EARN-4 actual L ignores acquired-map region|active=%d sample=%d expected=%s position=%s modal=%s battle=%s" % [active, sample, allowed, maze._diver.global_position, maze.any_modal_open(), maze._battling])
				if map.main_map.visible:
					# Move across a boundary while the map owns input; physics
					# must relinquish it without requiring a second L.
					maze._diver.global_position = Vector3(outside.x, 2, outside.y)
					for frame in 2:
						await physics_frame
					_expect(not map.main_map.visible, "EARN-4 overview remains open outside its navigation region")
				cases += 1
		if active < 2:
			# Only one Tab between active-diver cases.
			maze._diver.global_position = home
			await _key(KEY_TAB)
	maze.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC EARNED MAP REGION: clean|generated=%d" % cases if findings.is_empty() else "MARC EARNED MAP REGION: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

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
