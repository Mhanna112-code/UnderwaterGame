# Production passage and camera, isolated by fixture placement. These frames
# are not earned-route, browser, balance or full-campaign acceptance.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(360, 640) if args.has("--narrow") else Vector2i(1280, 720)
	var outdir := args[0] if not args.is_empty() else "/tmp/pr100-maze-drafts"
	DirAccess.make_dir_recursive_absolute(outdir)
	var world := load("res://game/world.tscn").instantiate() as World
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
	var passage: Node3D = maze.draft_passages
	var cap := maze.get_node("Wall11EndCap") as CSGBox3D
	world.divers[0].global_position = Vector3(cap.global_position.x + passage.break_side * (cap.size.z * 0.5 + 1.2), 1.8, passage.outgoing_z)
	for frame in range(8):
		await physics_frame
	maze._yaw = -PI * 0.5
	maze._pitch = 0.15
	maze._move_camera(1.0)
	await _capture(outdir.path_join("outgoing-question.png"))
	await _key(KEY_N)
	for frame in range(15):
		await physics_frame
	await _capture(outdir.path_join("outgoing-approach.png"))
	await _key(KEY_E)
	await _key(KEY_Y)
	for frame in range(28):
		await physics_frame
	await _capture(outdir.path_join("outgoing-in-motion.png"))
	for frame in range(100):
		await physics_frame
	maze._yaw = PI * 0.5
	maze._pitch = 0.15
	maze._move_camera(1.0)
	await _capture(outdir.path_join("outgoing-exit.png"))
	world.divers[0].global_position = Vector3(265, 1.8, 16)
	(maze.rotatable_wall_sets()[2].rotate as Callable).call()
	await create_timer(2.0).timeout
	world.divers[0].global_position = Vector3(passage.return_x, 1.8, passage.return_z + passage.return_side * 4.0)
	maze._yaw = 0.0 if passage.return_side > 0 else PI
	maze._pitch = 0.15
	for frame in range(15):
		await physics_frame
	maze._move_camera(1.0)
	await _capture(outdir.path_join("return-approach.png"))
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	quit()

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

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("DRAFT_CAPTURE|", path)
