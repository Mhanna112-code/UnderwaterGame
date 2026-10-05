# OPEN-023: interrupted movie must retain one decoder and its position, without
# continuing audio or blocking combat while hidden. Timing proof also requires
# the ordinary rendered journey; this accelerated test does not prove pacing.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var combat_button := Button.new()
	combat_button.text = "Attack"
	combat_button.position = Vector2(20, 20)
	combat_button.size = Vector2(200, 60)
	root.add_child(combat_button)
	var clicks: Array[bool] = []
	combat_button.pressed.connect(func() -> void: clicks.append(true))
	var path := "res://game/prologue_cinematic.gd"
	if not FileAccess.file_exists(path):
		findings.append("OPEN-023 split cinematic owner is missing")
		_finish()
		return
	var scene := (load(path) as Script).new() as CanvasLayer
	root.add_child(scene)
	await process_frame
	var video := _find_video(scene)
	var introductions: Array[bool] = []
	var completions: Array[bool] = []
	scene.introduction_finished.connect(func(ok: bool) -> void: introductions.append(ok))
	scene.completed.connect(func(ok: bool) -> void: completions.append(ok))
	await create_timer(0.3).timeout
	var before := video.stream_position
	scene.pause_introduction_for_test()
	await create_timer(0.2).timeout
	_expect(not scene.visible and video.paused, "OPEN-023 hidden introduction still plays or obscures combat")
	_expect(absf(video.stream_position - before) < 0.1, "OPEN-023 paused introduction loses its position")
	_expect(introductions == [true] and completions.is_empty(), "OPEN-023 introduction completes/frees the whole movie")
	scene.pause_introduction_for_test()
	_expect(introductions.size() == 1, "OPEN-023 repeated boundary emits twice")
	paused = false # The same World handoff used for Cordys combat.
	await process_frame
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = Vector2(50, 40)
		click.global_position = click.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await process_frame
	_expect(clicks == [true], "OPEN-023 hidden cinematic blocks a real GUI Attack click")
	paused = true
	scene.resume_aftermath()
	_expect(scene.visible and not video.paused, "OPEN-023 aftermath cannot resume")
	_expect(_find_video(scene) == video, "OPEN-023 aftermath creates a second decoder")
	_expect(absf(video.stream_position - before) < 0.1, "OPEN-023 aftermath restarts the introduction")
	scene.finish_for_test()
	_expect(completions == [true], "OPEN-023 aftermath does not finish once")
	await process_frame
	paused = false
	combat_button.queue_free()
	await process_frame
	_finish()

func _find_video(node: Node) -> VideoStreamPlayer:
	for child in node.get_children():
		if child is VideoStreamPlayer:
			return child
		var found := _find_video(child)
		if found != null:
			return found
	return null

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("SPLIT CINEMATIC: clean" if findings.is_empty() else "SPLIT CINEMATIC: failed")
	quit(0 if findings.is_empty() else 1)
