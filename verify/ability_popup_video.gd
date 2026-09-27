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
	var pages: Array[Dictionary] = [{
		"title": "Video regression probe",
		"body": "The player must remain inside MediaFrame.",
		"media": "swap",
	}]
	popup.call("open", pages)
	await create_timer(1.5, true).timeout
	var frame := popup.get_node_or_null("UI/AbilityExplanationPanel/Margin/VBoxContainer/ContentRow/MediaFrame") as Control
	var player := _first_video_player(frame)
	if frame == null:
		_failures.append("MediaFrame is missing")
	elif player == null:
		_failures.append("Swap media did not create a VideoStreamPlayer")
	else:
		if not player.expand:
			_failures.append("VideoStreamPlayer.expand is false; source dimensions can expand the popup")
		if player.get_stream_position() <= 0.1:
			_failures.append("VideoStreamPlayer did not advance while the popup paused the game")
		if frame.size.x > 200.0 or frame.size.y > 200.0:
			_failures.append("MediaFrame expanded to %s instead of its small embedded size" % frame.size)
		if player.size.x > frame.size.x + 2.0 or player.size.y > frame.size.y + 2.0:
			_failures.append("Video player %s exceeds MediaFrame %s" % [player.size, frame.size])
	popup.call("_close")
	_finish()

func _first_video_player(node: Node) -> VideoStreamPlayer:
	if node == null:
		return null
	for child in node.get_children():
		if child is VideoStreamPlayer:
			return child as VideoStreamPlayer
	return null

func _finish() -> void:
	for failure in _failures:
		print("VIDEO-POPUP FAILURE: " + failure)
	print("VIDEO-POPUP: clean" if _failures.is_empty() else "VIDEO-POPUP: %d failure(s)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
