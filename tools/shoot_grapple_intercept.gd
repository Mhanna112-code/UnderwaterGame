# Records Diver Boy's first-person grapple-intercept minigame using its
# verification aim helper so the proof is deterministic.
# Usage: godot --path . --script tools/shoot_grapple_intercept.gd -- /tmp/grapple-frames
extends SceneTree

var frame_dir := "/tmp/grapple-intercept-frames"
var result: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		frame_dir = String(args[0])
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.62, 0.7)
	env.ambient_light_energy = 1.3
	environment.environment = env
	viewport.add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	light.light_energy = 1.4
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 72.0
	viewport.add_child(camera)
	var diver := Diver.new()
	diver.model_name = "Prototype_1(1910)"
	viewport.add_child(diver)

	var minigame := GrappleInterceptMinigame.new()
	minigame.stage_root = viewport
	minigame.stage_camera = camera
	minigame.target_actor = diver
	minigame.source_position = Vector3(0.0, 1.4, -9.0)
	minigame.finished.connect(func(hits: int, total: int) -> void: result = [hits, total])
	root.add_child(minigame)
	minigame.run()

	await process_frame
	await process_frame
	var frame := 0
	var next_shot := Time.get_ticks_msec() + 900
	var demonstrated_decoy := false
	while result.is_empty() and frame < 260:
		if Time.get_ticks_msec() >= next_shot:
			if not demonstrated_decoy and minigame.auto_hit_decoy():
				demonstrated_decoy = true
				next_shot = Time.get_ticks_msec() + 650
			elif minigame.auto_intercept_closest():
				next_shot = Time.get_ticks_msec() + 430
		await create_timer(1.0 / 20.0).timeout
		root.get_texture().get_image().save_png(frame_dir.path_join("frame_%03d.png" % frame))
		frame += 1
	# Hold the completed score long enough to read in the loop.
	diver.visible = false
	for hold in range(20):
		await create_timer(1.0 / 20.0).timeout
		root.get_texture().get_image().save_png(frame_dir.path_join("frame_%03d.png" % frame))
		frame += 1
	print("GRAPPLE GIF: %s across %d frames" % [str(result), frame])
	quit(0 if result == [8, 8] else 1)
