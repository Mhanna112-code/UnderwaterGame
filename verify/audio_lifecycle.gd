# Real World/Battle music lifecycle contract.
#
# Usage: godot --headless --path . --script verify/audio_lifecycle.gd
extends SceneTree

const TEST_SLOT := 918281

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()
	var audio := root.get_node_or_null("GameAudio")
	if audio == null:
		findings.append("OWNER: GameAudio autoload is absent")
		_finish()
		return
	audio.stop_music()

	var packed := load("res://game/world.tscn") as PackedScene
	var world := packed.instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	_expect(audio.get_music_state().phase == "stopped", "AUTOPLAY: cold title started music before player interaction")

	await world._on_title_new_game(TEST_SLOT)
	_expect(audio.get_music_state().cue_id == "exploration" and audio.get_music_state().phase == "loop", "WORLD: successful New Game did not start exploration music")

	world._start_battle()
	await process_frame
	_expect(audio.get_music_state().cue_id == "battle" and audio.get_music_state().phase == "intro", "BATTLE: ordinary encounter did not replace exploration with Battle intro")
	world._on_battle_finished("won")
	await process_frame
	await process_frame
	_expect(audio.get_music_state().cue_id == "victory" and audio.get_music_state().phase == "intro", "VICTORY: normal win did not replace Battle music with victory fanfare")

	world._start_battle("", true)
	await process_frame
	_expect(audio.get_music_state().cue_id == "tethys" and audio.get_music_state().phase == "loop", "BOSS: Tethys encounter did not replace victory with its boss loop")
	world._on_battle_finished("lost")
	await process_frame
	await process_frame
	_expect(audio.get_music_state().cue_id == "game_over" and audio.get_music_state().phase == "one_shot", "DEFEAT: normal loss did not replace boss music with game-over one-shot")

	world._show_title_screen()
	_expect(audio.get_music_state().phase == "stopped", "TITLE: returning to the title left stale gameplay music active")

	world.queue_free()
	await process_frame
	audio.release_streams_for_shutdown()
	await create_timer(0.15).timeout
	_remove_test_save()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _remove_test_save() -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

func _finish() -> void:
	_remove_test_save()
	for finding in findings:
		print("FINDING  " + finding)
	print("AUDIO LIFECYCLE: clean" if findings.is_empty() else "AUDIO LIFECYCLE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
