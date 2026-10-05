extends SceneTree
## MSG-1/3: actual R/Q and modal input must not destroy unread announcements.
var findings: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	root.size = Vector2i(1280, 720)
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	world.get_node("HUD").show() # Explicit active-exploration fixture, not a New Game claim.
	paused = false
	await _notice_sequence(world, world.banner, false)
	if findings.is_empty():
		await _save_contact_sequence(world)
	world.queue_free()
	await process_frame
	if findings.is_empty():
		var maze := (load("res://game/maze_level.tscn") as PackedScene).instantiate() as MazeLevel
		root.add_child(maze)
		current_scene = maze
		for frame in 8:
			await physics_frame
		_expect(maze._banner == null or maze._banner.text.is_empty(), "MSG-4 new Maze inherits a freed World's transient notices")
		# Map/modal presentation fixture; acquisition is tested independently.
		maze.key_items.append("maze_nav_map")
		(maze.get_node("HUD/MazeMiniMap") as MazeMiniMap).intro_seen = true
		await _key(KEY_R)
		await _notice_sequence(maze, maze._banner, true, true)
		if findings.is_empty():
			await _queued_interaction_sequence(maze)
		maze.queue_free()
		await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("ORANGE MESSAGES: clean" if findings.is_empty() else "ORANGE MESSAGES: failed")
	quit(0 if findings.is_empty() else 1)

func _notice_sequence(owner: Node, banner: Label, map_owner: bool, already_r := false) -> void:
	var kind := "Maze" if map_owner else "World"
	if not already_r:
		await _key(KEY_R)
	var first := banner.text
	_expect(banner.is_visible_in_tree(), "MSG-1 fixture has no readable active HUD in " + kind)
	_expect(first.begins_with("Random encounters "), "MSG-1 real R does not display encounter state in " + kind)
	await _key(KEY_Q)
	_expect(banner.text == first, "MSG-1 real Q overwrites unread R notice in " + kind)
	await _capture(kind.to_lower() + "-r-before-q")
	if not findings.is_empty():
		return
	await create_timer(4.25, true).timeout
	_expect(banner.text.begins_with("Sonar "), "MSG-1 next Q notice never follows R in " + kind)
	await _capture(kind.to_lower() + "-queued-q")
	for i in 20:
		await _key(KEY_R)
	_expect(banner.text.begins_with("Sonar "), "MSG-2 rapid R wipes current non-toggle notice in " + kind)
	await create_timer(4.25, true).timeout
	var expected := "Random encounters %s." % ("on" if owner.random_encounters_enabled else "off")
	_expect(banner.text == expected, "MSG-2 toggle queue reports stale preference in " + kind)
	await _key(KEY_L if map_owner else KEY_ESCAPE)
	if map_owner:
		_expect(owner.get_node("HUD/MazeMiniMap").main_map.visible, "MSG-3 actual L fixture did not open the map")
		_expect(not banner.visible, "MSG-3 orange banner draws through the map")
	else:
		_expect(owner.inventory_menu.visible, "MSG-3 actual Escape did not open inventory")
	await create_timer(4.25, true).timeout
	await _key(KEY_L if map_owner else KEY_ESCAPE)
	await physics_frame
	_expect(banner.text == expected and (not map_owner or banner.visible), "MSG-3 hidden modal/map consumed unread notice in " + kind)
	print("ORANGE INPUT|", kind, "|R/Q FIFO, twenty R coalescing and hidden-owner preservation")

func _save_contact_sequence(world: World) -> void:
	await create_timer(4.3).timeout
	# Completed-opening/seen-lesson near-save-point fixture; real movement
	# and Area3D contact below, not a normal New Game progression claim.
	world.route_state.prologue_complete = true
	world._save_point_tutorial_seen = true
	var point := world._save_points[0] as SavePoint
	var diver := world.divers[world.active] as Diver
	world.yaw = 0.0
	world.pitch = 0.0
	for i in world.divers.size():
		world.divers[i].global_position = point.global_position + Vector3(8 + i * 3, 0, -5)
		world.divers[i].velocity = Vector3.ZERO
		world.divers[i].sonar_active = false
		world.divers[i].stats.hp = 1
		world.divers[i].stats.oxygen = 0
	diver.global_position = point.global_position + Vector3(0, 0, -3.5)
	for frame in 5:
		await physics_frame
	_expect(not point.has_diver(diver), "MSG-4 near-save fixture already occupies the contact volume")
	await _key(KEY_R)
	var unread := world.banner.text
	await _key(KEY_P)
	_expect(world.banner.text == unread and not world.save_point_menu.visible, "MSG-4 off-point P overwrites R or opens a save menu")
	var move := InputEventKey.new()
	move.keycode = KEY_W
	move.pressed = true
	Input.parse_input_event(move)
	var deadline := Time.get_ticks_msec() + 1800
	while not point.has_diver(diver) and Time.get_ticks_msec() < deadline:
		await physics_frame
	move = InputEventKey.new()
	move.keycode = KEY_W
	Input.parse_input_event(move)
	for frame in 8:
		await physics_frame
	_expect(point.has_diver(diver), "MSG-4 actual W did not reach the real save point")
	_expect(world.banner.text == unread, "MSG-4 save contact overwrites the unread notice")
	await _capture("world-contact-unread")
	for member in world.divers:
		_expect(member.stats.hp == member.stats.hp_max and is_equal_approx(member.stats.oxygen, member.stats.oxygen_max),
			"MSG-4 queued notice prevents save contact restoring the whole party")
	await _key(KEY_P)
	_expect(world.save_point_menu.visible, "MSG-3 contact P did not open the real Save menu")
	await create_timer(4.25).timeout
	await _key(KEY_P)
	_expect(world.banner.text == unread, "MSG-3 Save menu consumes unread orange feedback")
	await create_timer(4.1).timeout
	_expect(world.banner.text == "No save point nearby.", "MSG-4 next notice is replaced by the held Save prompt")
	await create_timer(4.25).timeout
	_expect(world.banner.text.contains("Press P"), "MSG-4 held Save prompt does not return after notices drain")
	await _capture("world-contact-prompt")
	await create_timer(4.25).timeout
	_expect(world.banner.text.contains("Press P"), "MSG-4 held Save prompt fades despite continued contact")
	await _key(KEY_P)
	_expect(world.save_point_menu.visible, "MSG-4 real P cannot open the restored save prompt")
	await _key(KEY_P)
	_expect(not world.save_point_menu.visible and world.banner.text.contains("Press P"), "MSG-4 closing real P loses the held prompt")
	print("ORANGE INPUT|World|actual W save contact restores all resources behind two notices; persistent P returns")

func _queued_interaction_sequence(maze: MazeLevel) -> void:
	await create_timer(4.3).timeout
	# Near-interaction fixture: no reward or puzzle state is granted.
	var rock := maze.find_child("SplitRock", true, false) as Node3D
	_expect(rock != null, "MSG-5 split-rock fixture is missing")
	if rock == null:
		return
	var diver := maze.divers[maze.active] as Diver
	diver.global_position = rock.global_position + Vector3(0, 2, 2.5)
	diver.velocity = Vector3.ZERO
	for frame in 8:
		await physics_frame
	_expect(maze._switch_prompt != null and maze._switch_prompt.visible, "MSG-5 no actual E prompt near split rock")
	await _key(KEY_R)
	var first := maze._banner.text
	await _key(KEY_E)
	for frame in 3:
		await physics_frame
	_expect(maze._banner.text == first and not maze._switch_prompt.visible, "MSG-5 queued interaction overwrites R or leaves E prompt active")
	await create_timer(4.2).timeout
	_expect(maze._banner.text.contains("broken in half"), "MSG-5 actual E feedback never reaches the banner")
	await _capture("maze-queued-e")
	await create_timer(3.8).timeout
	await _key(KEY_E)
	await create_timer(1.5).timeout
	_expect(maze._banner.text.is_empty() and maze._switch_prompt.visible, "MSG-5 repeated E renews notice or cooldown strands the prompt")
	await _key(KEY_E)
	_expect(maze._banner.text.contains("broken in half"), "MSG-5 drained cooldown never permits the next interaction")
	print("ORANGE INPUT|Maze|queued real E hides prompt, repeated E cannot prolong notice, next E works after drain")

func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

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
