extends SceneTree
## CENTER-1: container animation must not push the Welcome beat to the top.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90502
	var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(720, 480), Vector2i(640, 360)]
	for i in 9:
		sizes.append(Vector2i(rng.randi_range(640, 1600), rng.randi_range(360, 950)))
	for size in sizes:
		root.size = size
		var cutscene := Cutscene.new()
		root.add_child(cutscene)
		cutscene.play_scroll_text("Welcome to the Deep Sea")
		await create_timer(1.15).timeout
		var labels := cutscene.find_children("*", "Label", true, false)
		if labels.size() != 1:
			findings.append("CENTER-1 welcome text not uniquely visible")
		else:
			var label := labels[0] as Label
			var rect := label.get_global_rect()
			var viewport := root.get_visible_rect()
			if rect.get_center().distance_to(viewport.get_center()) > 4.0 or not viewport.encloses(rect):
				findings.append("CENTER-1 welcome is not centered/contained at %s: %s" % [size, rect])
			if "--capture" in OS.get_cmdline_user_args() and size in [Vector2i(1280, 720), Vector2i(720, 480)]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/welcome-centered-%dx%d.png" % [size.x, size.y])
		cutscene.queue_free()
		await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("WELCOME CENTER: clean|sizes=12" if findings.is_empty() else "WELCOME CENTER: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
