# Actual production decoder boundary; no accelerated pause or injected seek.
# Usage: godot --path . --script tools/shoot_prologue_title.gd
extends SceneTree

var owner: CanvasLayer
var player: VideoStreamPlayer
var done := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	owner = load("res://game/prologue_cinematic.gd").new() as CanvasLayer
	root.add_child(owner)
	player = owner.get_node("InputBlocker/OpeningAspect/OpeningFrame/OpeningMedia")
	owner.introduction_finished.connect(func(_ok: bool) -> void: done = true)
	while not done:
		await create_timer(0.1).timeout
	print("TITLE DIAGNOSTIC paused at ", player.stream_position)
	await create_timer(1.0).timeout
	owner.resume_aftermath()
	for i in range(6):
		await create_timer(0.9).timeout
		if not is_instance_valid(player):
			break
		var frame := player.get_video_texture().get_image()
		print("TITLE DIAGNOSTIC ", i, " position ", player.stream_position, " image ", hash(frame.get_data()))
		frame.save_png("/tmp/prologue-title-native-%d.png" % i)
	await create_timer(2.0).timeout
	if is_instance_valid(owner):
		owner.queue_free()
	await process_frame
	paused = false
	quit()
