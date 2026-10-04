# OPEN-025: guards against the live owner keeping the old monologue or losing
# the title ending. Digest is a reviewed-media identity check, not visual proof.
extends SceneTree

const PATH := "res://media/cutscenes/octopus_prologue.ogv"
const EXPECTED_SHA := "8425b83d2905ae4403caf04fbe067e02264e20325cbbebc05e63f35995663f32"
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(PATH):
		findings.append("OPEN-025 approved monologue-free derivative is missing")
		_finish()
		return
	var stream := load(PATH) as VideoStreamTheora
	_expect(FileAccess.get_sha256(PATH) == EXPECTED_SHA,
		"OPEN-025 derivative differs from the reviewed introduction/title edit")
	_expect(stream != null, "OPEN-025 derivative is not browser-compatible Theora")
	var player := VideoStreamPlayer.new()
	player.stream = stream
	root.add_child(player)
	player.play()
	await process_frame
	_expect(player.get_stream_length() > 31.3 and player.get_stream_length() < 31.5,
		"OPEN-025 edited footage does not retain the 25-second intro plus complete title ending")
	var scene := load("res://game/prologue_cinematic.gd").new() as CanvasLayer
	root.add_child(scene)
	await process_frame
	_expect(scene.video_path == PATH, "OPEN-025 production still plays the long monologue")
	_expect(is_equal_approx(scene.INTRODUCTION_SECONDS, 25.0), "OPEN-025 combat pause changed the retained introduction")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(preset.contains("media/cutscenes/octopus_demon_v3.ogv"),
		"OPEN-025 deferred full movie remains duplicated in the child web export")
	player.stop()
	player.queue_free()
	scene.queue_free()
	await process_frame
	paused = false
	_finish()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("PROLOGUE CINEMATIC ASSET: clean" if findings.is_empty() else "PROLOGUE CINEMATIC ASSET: failed")
	quit(0 if findings.is_empty() else 1)
