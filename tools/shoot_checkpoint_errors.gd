# OPEN-028/029 visual boundary: render the actual recovery/title error owners.
# Does not create, load, or change player save slots.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var outdir := args[0] if not args.is_empty() else "/tmp/checkpoint-errors"
	DirAccess.make_dir_recursive_absolute(outdir)
	var recovery := PrologueRecovery.new()
	root.add_child(recovery)
	recovery.show_save_failure()
	await _capture(outdir.path_join("retry-save.png"))
	recovery.clear_save_failure()
	await _capture(outdir.path_join("save-restored.png"))
	recovery.queue_free()
	await process_frame
	var title := TitleScreen.new()
	root.add_child(title)
	title.show_load_error("Could not load Slot 1. Choose another save or start a new game.")
	await _capture(outdir.path_join("load-error.png"))
	title.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	quit()

func _capture(path: String) -> void:
	for _i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CHECKPOINT ERROR CAPTURE|", path)
