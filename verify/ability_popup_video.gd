# Ensures a delivered tutorial OGV stays embedded in the paused ability
# popup, rather than using its 1920x1080 source dimensions to cover the UI.
# Usage: godot --headless --path . --script verify/ability_popup_video.gd
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var popup := root.get_node_or_null("CharacterAbilityPopup") as Control
	if popup == null:
		_failures.append("CharacterAbilityPopup autoload is missing")
		_finish()
		return
	# Drive the real post-tutorial walkthrough rather than manufacturing a
	# test-only Grapple page. That catches a missing `media: "grapple"` entry
	# in World's production page list.
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.call("_show_ability_popups")
	for page_index in range(3):
		popup.call("_on_next_pressed")
		await process_frame
	await create_timer(1.5, true).timeout
	var frame := popup.get_node_or_null("UI/AbilityExplanationPanel/Margin/VBoxContainer/ContentRow/MediaFrame") as Control
	var players := _video_players_in(frame)
	var player := players[0] if players.size() == 1 else null
	if frame == null:
		_failures.append("MediaFrame is missing")
	elif players.size() != 1:
		_failures.append("Grapple media created %d video players; expected exactly one" % players.size())
	elif player == null:
		_failures.append("Grapple media did not create a VideoStreamPlayer")
	else:
		if not player.expand:
			_failures.append("VideoStreamPlayer.expand is false; source dimensions can expand the popup")
		if player.get_stream_position() <= 0.1:
			_failures.append("VideoStreamPlayer did not advance while the popup paused the game")
		var expected_frame_size := TutorialContent.VIDEO_FRAME_SIZE
		if frame.size.x > expected_frame_size.x + 2.0 or frame.size.y > expected_frame_size.y + 2.0:
			_failures.append("MediaFrame expanded to %s instead of its %s embedded size" % [frame.size, expected_frame_size])
		if player.size.x > frame.size.x + 2.0 or player.size.y > frame.size.y + 2.0:
			_failures.append("Video player %s exceeds MediaFrame %s" % [player.size, frame.size])
	# Rebuilding the same page must replace its prior player, not leave a
	# second stream drawing over the first one.
	popup.call("_refresh_media", "grapple")
	await create_timer(0.2, true).timeout
	var refreshed_players := _video_players_in(frame)
	if refreshed_players.size() != 1:
		_failures.append("Refreshing Grapple media left %d video players; expected one" % refreshed_players.size())
	popup.call("_close")
	world.queue_free()
	_finish()

func _video_players_in(node: Node) -> Array[VideoStreamPlayer]:
	var result: Array[VideoStreamPlayer] = []
	if node == null:
		return result
	for child in node.get_children():
		if child is VideoStreamPlayer:
			result.append(child as VideoStreamPlayer)
		result.append_array(_video_players_in(child))
	return result

func _finish() -> void:
	for failure in _failures:
		print("VIDEO-POPUP FAILURE: " + failure)
	print("VIDEO-POPUP: clean" if _failures.is_empty() else "VIDEO-POPUP: %d failure(s)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
