# Central music sequencing contract.
#
# Usage: godot --headless --path . --script verify/audio_manager.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager_script := load("res://game/audio_manager.gd")
	if manager_script == null:
		findings.append("OWNER: game/audio_manager.gd does not exist")
		_finish()
		return

	var manager: Node = manager_script.new()
	root.add_child(manager)
	await process_frame

	var intro := _silent_stream()
	var loop := _silent_stream()
	manager.play_music_sequence("battle", intro, loop)
	_expect(manager.get_music_state() == {
		"cue_id": "battle",
		"phase": "intro",
		"playing": true,
		"looping": false,
	}, "INTRO: two-part cue did not begin as one non-looping intro")
	_expect(_music_player_count(manager) == 1, "OWNER: manager does not own exactly one music player")

	var initial_trace: Array = manager.get_music_transition_trace()
	manager.play_music_sequence("battle", intro, loop)
	_expect(manager.get_music_transition_trace() == initial_trace, "IDEMPOTENCE: requesting the active cue restarted or stacked it")

	manager.advance_music_after_stream_finished()
	_expect(manager.get_music_state() == {
		"cue_id": "battle",
		"phase": "loop",
		"playing": true,
		"looping": true,
	}, "HANDOFF: intro completion did not become the single looping track")
	var loop_trace: Array = manager.get_music_transition_trace()
	manager.advance_music_after_stream_finished()
	_expect(manager.get_music_transition_trace() == loop_trace, "LOOP: a loop completion incorrectly restarted or stacked playback")

	manager.queue_free()
	await process_frame
	_finish()

func _silent_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	stream.data = PackedByteArray([128, 128, 128, 128])
	return stream

func _music_player_count(manager: Node) -> int:
	var count := 0
	for child in manager.get_children():
		if child is AudioStreamPlayer and child.name == "MusicPlayer":
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("AUDIO MANAGER: clean" if findings.is_empty() else "AUDIO MANAGER: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
