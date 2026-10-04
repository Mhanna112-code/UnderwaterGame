extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await world._on_title_new_game(918302)
	world._update_prologue_trigger(0.4)
	world._update_prologue_trigger(7.2)
	await process_frame
	var fight := world.battle
	await fight.reveal_prologue_octopus()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	print("camera=", fight._stage_cam.global_position, " bounds=", fight.enemies[0].actor.visual_bounds(), " body=", fight.enemies[0].actor.current_pose_bounds())
	var args := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(args[0] if not args.is_empty() else "/tmp/cordys-stage.png")
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(918302)))
	quit()
