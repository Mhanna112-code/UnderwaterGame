# OPEN-005/006: impact ducking must recover authored gain, cue replacement must
# cancel stale envelopes, and neither operation may rewrite user volume.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio := root.get_node("GameAudio") as UnderwaterAudioManager
	var settings := audio.get_audio_settings()
	audio.play_cordys_music()
	if not audio.has_method("duck_music") or not audio.has_method("fade_music_in"):
		findings.append("OPEN-005 authored cue owner lacks impact/fade envelope")
	else:
		audio.call("duck_music", -8.0, 0.2)
		await create_timer(0.15).timeout
		_expect(float(audio.get_music_gain_state().active_db) < -5.0, "OPEN-005 player hit never ducks boss cue: %s" % [audio.get_music_gain_state()])
		await create_timer(0.5).timeout
		_expect(is_equal_approx(float(audio.get_music_gain_state().active_db), -1.0), "OPEN-005 duck does not restore authored intro trim")
		audio.call("duck_music", -8.0, 0.3)
		audio.play_exploration_music()
		await create_timer(0.5).timeout
		_expect(audio.get_music_state().cue_id == "exploration" and is_zero_approx(float(audio.get_music_gain_state().active_db)), "OPEN-005 stale duck corrupts restored exploration")
		audio.call("fade_music_in", 0.2)
		_expect(float(audio.get_music_gain_state().active_db) <= -40.0, "OPEN-005 recovery fade starts at full volume")
		await create_timer(0.3).timeout
		_expect(is_zero_approx(float(audio.get_music_gain_state().active_db)), "OPEN-005 recovery fade never restores normal mix")
	_expect(audio.get_audio_settings() == settings, "OPEN-006 authored envelope changed user settings")
	audio.release_streams_for_shutdown()
	for finding in findings:
		print("FINDING  " + finding)
	print("PROLOGUE ENVELOPE: clean" if findings.is_empty() else "PROLOGUE ENVELOPE: failed")
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
