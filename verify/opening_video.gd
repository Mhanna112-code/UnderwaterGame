# First-run opening video ownership and policy contract.
#
# Bugs caught:
# - OPEN-003: changing the opening policy also changes the independent lab
#   cutscene's existing skip policy.
# - OPEN-004: the temporary opening is duplicated, stretched, cropped, routed
#   around Music volume, skippable, or decoder failure leaves a black lock.
#
# Usage: godot --headless --path . --script verify/opening_video.gd
extends SceneTree

const OPENING_OWNER_PATH := "res://game/opening_video.gd"
const LAB_OWNER_PATH := "res://game/lab_video_cutscene.gd"
const EXPECTED_VIDEO := "res://media/cutscenes/mermaid_freak.ogv"

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists(OPENING_OWNER_PATH):
		findings.append("OPEN-003 opening video owner is missing")
		_finish()
		return
	var opening_script := load(OPENING_OWNER_PATH) as Script
	var lab_script := load(LAB_OWNER_PATH) as Script
	if opening_script == null:
		findings.append("OPEN-003 opening video owner does not load")
		_finish()
		return
	var opening := opening_script.new() as CanvasLayer
	root.add_child(opening)
	await process_frame
	_test_opening_layout(opening)
	_test_opening_skip_policy(opening)
	_test_failure_fallback(opening_script)
	await process_frame
	_test_lab_policy_remains_independent(lab_script)
	await process_frame
	_finish()

func _test_opening_layout(opening: CanvasLayer) -> void:
	_expect(opening.get("video_path") == EXPECTED_VIDEO,
		"OPEN-004 opening does not reuse the canonical Mermaid OGV reference")
	var videos := _descendants_of_type(opening, "VideoStreamPlayer")
	_expect(videos.size() == 1,
		"OPEN-004 opening must own exactly one VideoStreamPlayer, got %d" % videos.size())
	if videos.size() == 1:
		var video := videos[0] as VideoStreamPlayer
		_expect(video.bus == &"Music", "OPEN-004 opening video bypasses the Music bus")
		_expect(is_equal_approx(video.volume_db, -6.0),
			"OPEN-004 opening local trim is %.2f dB, expected -6 dB" % video.volume_db)
		_expect(video.expand, "OPEN-004 video cannot expand into its responsive frame")
	var aspects := _descendants_of_type(opening, "AspectRatioContainer")
	_expect(aspects.size() == 1,
		"OPEN-004 opening must have exactly one aspect owner, got %d" % aspects.size())
	if aspects.size() == 1:
		var aspect := aspects[0] as AspectRatioContainer
		_expect(is_equal_approx(aspect.ratio, 16.0 / 9.0), "OPEN-004 opening frame is not 16:9")
		_expect(aspect.stretch_mode == AspectRatioContainer.STRETCH_FIT,
			"OPEN-004 opening frame crops or stretches instead of fitting")
	_expect(paused, "OPEN-004 opening does not pause world processing")

func _test_opening_skip_policy(opening: CanvasLayer) -> void:
	var completions: Array[bool] = []
	opening.completed.connect(func(success: bool) -> void: completions.append(success))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	opening.call("_unhandled_input", escape)
	_expect(completions.is_empty(), "OPEN-003 Escape skipped the first-run opening")
	_expect(opening.visible, "OPEN-003 Escape hid the first-run opening")
	_expect(opening.has_method("finish_for_test"), "OPEN-004 debug fast-forward seam is missing")
	if opening.has_method("finish_for_test"):
		opening.call("finish_for_test")
	_expect(completions == [true], "OPEN-004 successful playback did not complete exactly once")

func _test_failure_fallback(opening_script: Script) -> void:
	var fallback := opening_script.new() as CanvasLayer
	root.add_child(fallback)
	await process_frame
	var completions: Array[bool] = []
	fallback.completed.connect(func(success: bool) -> void: completions.append(success))
	_expect(fallback.has_method("fail_for_test"), "OPEN-004 decoder failure seam is missing")
	if fallback.has_method("fail_for_test"):
		fallback.call("fail_for_test")
	var buttons := _descendants_of_type(fallback, "Button")
	_expect(buttons.size() == 1, "OPEN-004 decoder failure does not expose one concise Continue fallback")
	if buttons.size() == 1:
		var button := buttons[0] as Button
		_expect(button.visible and button.text == "Continue",
			"OPEN-004 decoder fallback is not a visible Continue action")
		button.emit_signal("pressed")
	_expect(completions == [false], "OPEN-004 acknowledged decoder failure did not continue exactly once")

func _test_lab_policy_remains_independent(lab_script: Script) -> void:
	var lab := lab_script.new() as CanvasLayer
	root.add_child(lab)
	await process_frame
	var results: Array[bool] = []
	lab.completed.connect(func(skipped: bool) -> void: results.append(skipped))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	lab.call("_unhandled_input", escape)
	_expect(results == [true], "OPEN-003 lab cutscene lost its independent Escape-to-skip behavior")

func _descendants_of_type(node: Node, type_name: String) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		if child.is_class(type_name):
			result.append(child)
		result.append_array(_descendants_of_type(child, type_name))
	return result

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING VIDEO: clean" if findings.is_empty() else "OPENING VIDEO: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
