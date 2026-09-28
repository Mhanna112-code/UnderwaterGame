# Records the first Grapple Intercept vortex at close special-encounter
# spacing. It deliberately does not auto-clear a sphere: the proof is the
# whole colored cluster visibly travelling toward the diver.
# Usage: godot --path . --script tools/shoot_grapple_intercept.gd -- /tmp/grapple-frames
extends SceneTree

var frame_dir := "/tmp/grapple-intercept-frames"
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
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
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
	# Match the special-encounter stage spacing. The Goblin is far enough away
	# for the wave to visibly travel, yet its final 3 m click window remains
	# inside the player's bounded aim cone.
	diver.global_position = Vector3(0.0, 0.0, 2.2)
	# MODIFIED (added): the grapple target is enemy_actor himself now, not
	# a group of thrown rocks - required for run() to do anything at all
	# (see its own guard).
	var enemy := Goblin.new()
	viewport.add_child(enemy)
	enemy.global_position = Vector3(0.6, 0.0, -4.6)

	var minigame := GrappleInterceptMinigame.new()
	minigame.stage_root = viewport
	minigame.stage_camera = camera
	minigame.target_actor = diver
	minigame.enemy_actor = enemy
	minigame.source_position = enemy.global_position + Vector3.UP * enemy.height
	root.add_child(minigame)
	minigame.run()

	# Wait through the minigame's title beat, then capture its first incoming
	# wave before the five-second arrival timeout can start the next one.
	await create_timer(GrappleInterceptMinigame.TITLE_HOLD + 0.1).timeout
	var start_distance := minigame._vortex_center.distance_to(camera.global_position)
	var frame := 0
	while frame < 76:
		await create_timer(1.0 / 20.0).timeout
		root.get_texture().get_image().save_png(frame_dir.path_join("frame_%03d.png" % frame))
		frame += 1
	var end_distance := minigame._vortex_center.distance_to(camera.global_position)
	print("GRAPPLE GIF: first-wave distance %.2f -> %.2f across %d frames" % [start_distance, end_distance, frame])
	minigame.queue_free()
	quit(0 if end_distance < start_distance else 1)
