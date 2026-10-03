# Browser-ready intake contract for Glassgoat's revised Octopus cutscene.
#
# Usage: godot --headless --path . --script verify/octopus_cutscene_asset.gd
extends SceneTree

const PATH := "res://media/cutscenes/octopus_demon_v3.ogv"
const EXPECTED_SHA := "8cad2b4924837aedd38eac035ff9733231d550f3754b487f220fd97f2588033c"

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(PATH):
		findings.append("OCTO-MEDIA-001: canonical browser-ready V3 cutscene is missing")
		_finish()
		return
	_expect(FileAccess.get_sha256(PATH) == EXPECTED_SHA,
		"OCTO-MEDIA-002: runtime cutscene digest does not match the reviewed V3 derivative")
	_expect(not FileAccess.file_exists("res://media/cutscenes/Octopus_demonV3.mp4")
		and not FileAccess.file_exists("res://media/cutscenes/octopus_demon_v2.ogv"),
		"OCTO-MEDIA-001: duplicate or browser-unsafe Octopus cutscene was committed")

	var stream := load(PATH)
	_expect(stream is VideoStreamTheora,
		"OCTO-MEDIA-001: V3 cutscene did not import as VideoStreamTheora")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OCTOPUS CUTSCENE INTAKE: clean" if findings.is_empty() else "OCTOPUS CUTSCENE INTAKE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
