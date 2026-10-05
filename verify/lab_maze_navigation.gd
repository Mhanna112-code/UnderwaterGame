extends SceneTree
## Supplied post-Tethys milestone isolates the exit; no earned-victory claim.
var world: World
var findings: Array[String] = []

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
	world.get_node("HUD").visible = true
	paused = false
	world.random_encounters_enabled = false
	world.route_state.set_blocker_state("bomb_bot", "defeated")
	world.route_state.set_blocker_state("sword_slayer", "defeated")
	world.route_state.set_lab_state("cleared")
	world.route_state.set_tethys_state("defeated")
	world.route_state.deep_warning_seen = true
	world._sync_lab_staging()
	for index in 3:
		world.divers[index].global_position = Vector3(175, 2, 16 + index * 2)
		world.divers[index].velocity = Vector3.ZERO
	world.yaw = PI / 2
	await _frames(12)
	var guides := get_nodes_in_group("maze_route_guide")
	if guides.is_empty() or not (guides[0] as Control).is_visible_in_tree():
		print("NAV WITNESS|prologue=", world.route_state.prologue_complete, "|HUD=", world.get_node("HUD").visible,
			"|cam=", world.cam.current, "|paused=", paused, "|aim=", world.aiming,
			"|lab=", world.route_state.lab_state, "|tethys=", world.route_state.tethys_state,
			"|diver=", world.divers[world.active].global_position, "|guide=", guides)
		findings.append("NAV-1 no visible maze direction from the post-Tethys lab exit behind the rock shell")
		await _finish()
		return
	print("NAV-1 visible directional guide at real lab return position")
	var guide := guides[0] as Control
	var checkpoint := world._serialize_state()
	if "--fixture" in OS.get_cmdline_user_args():
		var file := FileAccess.open("/tmp/lab-maze-navigation-fixture.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(checkpoint))
		file.close()
	# Actual input and actual collisions, including the formerly hidden region
	# between the lab facade and the ramp. No subsequent position assignment.
	await _hold(KEY_W, true)
	var deadline := Time.get_ticks_msec() + 24000
	var captured := false
	while not world.embedded_maze.maze_active and Time.get_ticks_msec() < deadline:
		await physics_frame
		if "--visual" in OS.get_cmdline_user_args() and not captured and world.divers[world.active].global_position.x > 195:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/lab-maze-navigation-swim.png")
			captured = true
	await _hold(KEY_W, false)
	_expect(world.embedded_maze.maze_active,
		"NAV-2 following the compass from lab cannot reach the actual maze: " + str(world.divers[world.active].global_position))
	_expect(not guide.is_visible_in_tree(), "NAV-3 lab compass leaks into maze ownership")
	print("NAV-2 actual W swim|position=", world.divers[world.active].global_position, "|maze=", world.embedded_maze.maze_active)
	world.queue_free()
	await process_frame
	world = load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	_expect(world.restore_checkpoint(checkpoint), "NAV-3 completed lab checkpoint could not restore")
	world.title_screen.close()
	world.get_node("HUD").visible = true
	paused = false
	await _frames(12)
	guide = get_nodes_in_group("maze_route_guide")[0] as Control
	_expect(guide.is_visible_in_tree(), "NAV-3 checkpoint restore loses post-lab compass")
	var rng := RandomNumberGenerator.new()
	rng.seed = 504511
	for sample in 18:
		root.size = Vector2i([360, 720, 1280][sample % 3], 720)
		world.yaw = rng.randf_range(-PI, PI)
		await _frames(12)
		var bounds := guide.get_global_rect()
		_expect(bounds.position.x >= 0 and bounds.end.x <= root.size.x and bounds.end.y <= root.size.y
			and bounds.position.y > world.route_objective_panel.get_global_rect().end.y,
			"NAV-4 compass clips viewport or covers the objective at width " + str(root.size.x))
		_expect(not bounds.intersects(world._party_bars_box.get_global_rect())
			and not world.route_objective_panel.get_global_rect().intersects(world._party_bars_box.get_global_rect()),
			"NAV-4 party HP/O2 obscures maze compass or destination text at width " + str(root.size.x))
		var pointer := guide.find_child("Direction", true, false) as Polygon2D
		var diver := world.divers[world.active] as Diver
		var east := Vector3(231, 2, 16) - diver.global_position
		east.y = 0
		var view_forward := -world.cam.global_basis.z
		view_forward.y = 0
		view_forward = view_forward.normalized()
		var view_right := view_forward.cross(Vector3.UP)
		var expected := Vector2(east.dot(view_right), -east.dot(view_forward)).normalized()
		var shown := Vector2.UP.rotated(pointer.rotation)
		_expect(shown.dot(expected) > 0.999, "NAV-4 compass disagrees with camera-relative ramp direction")
	if "--visual" in OS.get_cmdline_user_args():
		for width in [1280, 720, 360]:
			root.size = Vector2i(width, 720)
			world.yaw = PI / 2
			await _frames(18)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/lab-maze-navigation-%d.png" % width)
	world.inventory_menu.open()
	await _frames(3)
	_expect(not guide.is_visible_in_tree(), "NAV-3 compass leaks over inventory")
	world.inventory_menu.close()
	await _frames(3)
	_expect(guide.is_visible_in_tree(), "NAV-3 closing inventory loses compass")
	world._start_battle()
	await process_frame
	# Battle pauses World physics; hidden HUD surfaces must be removed before
	# that pause, not depend on another World frame to notice the new owner.
	_expect(not guide.is_visible_in_tree(), "NAV-3 compass leaks over an actual paused battle")
	await _finish()

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _hold(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func _finish() -> void:
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("LAB MAZE NAVIGATION: clean" if findings.is_empty() else "LAB MAZE NAVIGATION: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
