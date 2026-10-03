# Central music sequencing contract.
#
# Usage: godot --headless --path . --script verify/audio_manager.gd
extends SceneTree

const TEST_SETTINGS_PATH := "user://deep_zone_audio_test.cfg"

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager_script := load("res://game/audio_manager.gd")
	if manager_script == null:
		findings.append("OWNER: game/audio_manager.gd does not exist")
		_finish()
		return

	_remove_test_settings()
	var manager: Node = manager_script.new()
	manager.set("settings_path", TEST_SETTINGS_PATH)
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

	var replacement_intro := _silent_stream()
	var replacement_loop := _silent_stream()
	manager.play_music_sequence("tethys", replacement_intro, replacement_loop)
	_expect(manager.get_music_state().cue_id == "tethys" and manager.get_music_state().phase == "intro", "REPLACEMENT: new cue did not replace the previous loop")
	manager.advance_music_after_stream_finished()
	_expect(manager.get_music_state().cue_id == "tethys" and manager.get_music_state().phase == "loop", "REPLACEMENT: finished handoff started the retired cue's loop")

	_expect(AudioServer.get_bus_index("Music") >= 0, "BUSES: Music bus is missing")
	_expect(AudioServer.get_bus_index("SFX") >= 0, "BUSES: SFX bus is missing")
	_expect(_named_player_count(manager, "SFXPlayer") == 1, "OWNER: manager does not own exactly one SFX player")
	manager.set_music_volume(0.42)
	manager.set_music_muted(true)
	manager.set_sfx_volume(0.73)
	manager.set_sfx_muted(false)
	manager.save_audio_settings()

	manager.release_streams_for_shutdown()
	manager.queue_free()
	await process_frame

	var restored: Node = manager_script.new()
	restored.set("settings_path", TEST_SETTINGS_PATH)
	root.add_child(restored)
	await process_frame
	_expect(restored.get_audio_settings() == {
		"music_volume": 0.42,
		"music_muted": true,
		"sfx_volume": 0.73,
		"sfx_muted": false,
	}, "SETTINGS: volume/mute values did not survive manager recreation")
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if music_bus >= 0:
		_expect(AudioServer.is_bus_mute(music_bus), "SETTINGS: restored Music mute was not applied to its bus")
		_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), 0.42), "SETTINGS: restored Music volume was not applied to its bus")
	if sfx_bus >= 0:
		_expect(not AudioServer.is_bus_mute(sfx_bus), "SETTINGS: restored SFX mute was not applied to its bus")
		_expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)), 0.73), "SETTINGS: restored SFX volume was not applied to its bus")

	_expect(ProjectSettings.get_setting("autoload/GameAudio", "") == "*res://game/audio_manager.gd", "AUTOLOAD: project does not install the central GameAudio owner")
	restored.play_exploration_music()
	_expect(restored.get_music_state().cue_id == "exploration" and restored.get_music_state().phase == "loop", "CATALOG: exploration did not start its loop")
	restored.play_battle_music()
	_expect(restored.get_music_state().cue_id == "battle" and restored.get_music_state().phase == "intro", "CATALOG: battle did not start its authored intro")
	restored.advance_music_after_stream_finished()
	_expect(restored.get_music_state().cue_id == "battle" and restored.get_music_state().phase == "loop", "CATALOG: battle did not hand off to its authored loop")
	restored.play_tethys_music()
	_expect(restored.get_music_state().cue_id == "tethys" and restored.get_music_state().phase == "loop", "CATALOG: Tethys used an unapproved candidate intro instead of its proven loop")
	restored.play_victory_music()
	_expect(restored.get_music_state().cue_id == "victory" and restored.get_music_state().phase == "intro", "CATALOG: victory did not start with its fanfare")
	restored.play_game_over_music()
	_expect(restored.get_music_state().cue_id == "game_over" and restored.get_music_state().phase == "one_shot", "CATALOG: game over did not start as a one-shot")
	restored.advance_music_after_stream_finished()
	_expect(restored.get_music_state().phase == "stopped", "ONE SHOT: game-over completion did not release music ownership")
	restored.release_streams_for_shutdown()
	restored.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	_remove_test_settings()
	_finish()

func _silent_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	stream.data = PackedByteArray([128, 128, 128, 128])
	return stream

func _music_player_count(manager: Node) -> int:
	return _named_player_count(manager, "MusicPlayer")

func _named_player_count(manager: Node, player_name: String) -> int:
	var count := 0
	for child in manager.get_children():
		if child is AudioStreamPlayer and child.name == player_name:
			count += 1
	return count

func _remove_test_settings() -> void:
	var path := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("AUDIO MANAGER: clean" if findings.is_empty() else "AUDIO MANAGER: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
