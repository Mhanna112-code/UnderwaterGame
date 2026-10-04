# Runtime combat-SFX contract.
#
# Usage: godot --headless --path . --script verify/combat_sfx_playback.gd
extends SceneTree

class SilentBattle extends Battle:
	func _ready() -> void:
		pass

class FeedbackActor extends Node3D:
	func head_offset() -> float:
		return 1.0

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager_script := load("res://game/audio_manager.gd")
	_expect(manager_script != null, "COMBAT-SFX-001: audio manager could not be loaded")
	if manager_script == null:
		_finish()
		return
	var manager: Node = manager_script.new()
	manager.name = "TestGameAudio"
	root.add_child(manager)
	await process_frame

	manager.clear_sfx_event_trace()
	manager.play_combat_swing(false)
	manager.play_combat_result(true, false, false)
	manager.play_combat_result(false, true, false)
	manager.play_shockwave()
	var trace: Array = manager.get_sfx_event_trace()
	_expect(trace == ["combat_swing", "combat_hit", "combat_dodge", "shockwave"],
		"COMBAT-SFX-001/002/004: semantic playback trace was %s" % [trace])

	var combat_players: Array[AudioStreamPlayer] = []
	for child in manager.get_children():
		if child is AudioStreamPlayer and String(child.name).begins_with("CombatSFX"):
			combat_players.append(child as AudioStreamPlayer)
	_expect(combat_players.size() >= 2,
		"COMBAT-SFX-002: combat sounds have no overlap-safe player pool")
	var owned_streams := 0
	for player in combat_players:
		_expect(player.bus == "SFX", "COMBAT-SFX-005: %s bypasses the SFX bus" % player.name)
		if player.stream != null:
			owned_streams += 1
	_expect(owned_streams >= 2,
		"COMBAT-SFX-002: swing/result playback did not retain distinct active streams")

	# Battle's real result-feedback surface must drive the audio event; testing
	# the manager alone would still allow a silent production battle.
	var game_audio := root.get_node_or_null("GameAudio")
	_expect(game_audio != null, "COMBAT-SFX-003: project GameAudio autoload is unavailable")
	if game_audio != null:
		game_audio.clear_sfx_event_trace()
		var battle := SilentBattle.new()
		root.add_child(battle)
		var stage := SubViewport.new()
		stage.size = Vector2i(320, 180)
		root.add_child(stage)
		battle.set("_stage_vp", stage)
		var actor := FeedbackActor.new()
		stage.add_child(actor)
		battle.call("_show_combat_feedback", {"actor": actor}, {
			"hit": true,
			"damage": 3,
			"dodged": false,
			"debuff": "",
			"changed": 0,
			"effects": [],
		})
		_expect(game_audio.get_sfx_event_trace() == ["combat_hit"],
			"COMBAT-SFX-003: Battle result feedback did not request combat_hit")
		# Let the production floating-feedback tween finish and release the
		# autoload's compressed stream before the ObjectDB leak audit.
		await create_timer(1.2).timeout
		game_audio.release_streams_for_shutdown()
		await create_timer(0.2).timeout
		battle.queue_free()
		stage.queue_free()
		await process_frame

	manager.release_streams_for_shutdown()
	await create_timer(0.2).timeout
	for player in combat_players:
		_expect(player.stream == null,
			"COMBAT-SFX-006: %s retained its stream during shutdown" % player.name)
	manager.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("COMBAT SFX PLAYBACK: clean" if findings.is_empty() else "COMBAT SFX PLAYBACK: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
