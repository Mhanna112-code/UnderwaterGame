# Native visual inspection of production geometry. Fixture location and lab
# victory state are explicit; these frames are not proof of earned progression.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var outdir := args[0] if not args.is_empty() else "/tmp/pr100-lab-ramp"
	DirAccess.make_dir_recursive_absolute(outdir)
	var world := load("res://game/world.tscn").instantiate() as World
	root.add_child(world)
	current_scene = world
	await process_frame
	world.title_screen.close()
	world.route_state.prologue_complete = true
	world.route_state.opening_video_seen = true
	world.route_state.deep_warning_seen = true
	world.route_state.set_zone("deep")
	world.route_state.set_lab_state("cleared")
	world.route_state.set_tethys_state("defeated")
	world.route_state.set_objective("enter_maze")
	world._sync_lab_staging()
	world._intro_active = false
	world._camera_look_override = null
	world.random_encounters_enabled = false
	world.set_physics_process(false)
	world.embedded_maze.set_physics_process(false)
	for i in range(3):
		world.divers[i].global_position = Vector3(211, 2, 16 + i * 2)
		world.divers[i].set_physics_process(false)
	world.get_node("HUD").visible = true
	world.yaw = PI * 0.5
	world.pitch = -0.08
	world._move_camera(1.0)
	world._update_hp_bar()
	world._update_oxygen_bar()
	world._update_hud()
	world._update_deep_zone_visuals()
	world._update_active_cursor()
	paused = false
	await _capture(outdir.path_join("approach.png"))
	world.divers[0].global_position = Vector3(242, 1.8, 16)
	world._move_camera(1.0)
	world._update_active_cursor()
	await _capture(outdir.path_join("ramp.png"))
	# Inspect the low floor seam separately, without changing the geometry.
	world.get_node("HUD").visible = false
	world.cam.global_position = Vector3(244, 8, 34)
	world.cam.look_at(Vector3(244, 0, 16), Vector3.UP)
	await _capture(outdir.path_join("floor-seam-diagnostic.png"))
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.call("release_streams_for_shutdown")
	quit()

func _capture(path: String) -> void:
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("LAB RAMP CAPTURE|", path)
