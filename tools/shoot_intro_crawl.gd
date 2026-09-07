# Captures the opening story crawl as a sequence of PNG frames for
# assembling into a demo GIF (see verification/ - frames aren't committed,
# only the assembled GIF is). Speeds the crawl's own tween up 4x so a
# reasonably short capture run still shows the whole scroll start-to-finish,
# rather than only the first few seconds of a 26s real-time crawl.
# Usage: godot --headless --path . --script tools/shoot_intro_crawl.gd -- <frame_dir>
extends SceneTree

var frame_dir := "/tmp/intro-frames"
const SPEED_SCALE := 4.0
const FPS := 15

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		frame_dir = String(args[0])
	call_deferred("_run")

func _run() -> void:
	var crawl := IntroCrawl.new()
	root.add_child(crawl)
	await process_frame
	crawl.open()
	await process_frame
	if crawl._tween != null and crawl._tween.is_valid():
		crawl._tween.set_speed_scale(SPEED_SCALE)

	DirAccess.make_dir_recursive_absolute(frame_dir)
	var demo_duration: float = IntroCrawl.SCROLL_DURATION / SPEED_SCALE + 0.5
	var total_frames := int(demo_duration * FPS)
	for i in range(total_frames):
		await create_timer(1.0 / FPS).timeout
		root.get_texture().get_image().save_png(frame_dir.path_join("frame_%04d.png" % i))
	print("captured %d frames to %s" % [total_frames, frame_dir])
	quit()
