extends RefCounted
## Scene-owned transient FIFO. Its owner advances readable exploration time;
## hidden HUD, battle and paused modal time must not consume announcements.
const MAX_PENDING := 4
var _text := ""
var _remaining := 0.0
var _pending: Array[Dictionary] = []

func current_text() -> String:
	return _text

func seconds_left() -> float:
	return _remaining

func pending_messages() -> Array[String]:
	var result: Array[String] = []
	for message in _pending:
		result.append(String(message.text))
	return result

func clear() -> void:
	_text = ""
	_remaining = 0.0
	_pending.clear()

func push(text: String, seconds := 4.0) -> void:
	if text.is_empty():
		clear()
		return
	seconds = maxf(seconds, 0.01)
	if _text.is_empty() or _remaining <= 0:
		_text = text
		_remaining = seconds
		return
	if _text == text:
		_remaining = maxf(_remaining, seconds)
		return
	var toggle := _toggle_kind(text)
	if not toggle.is_empty():
		_pending = _pending.filter(func(message: Dictionary) -> bool: return _toggle_kind(String(message.text)) != toggle)
		if _toggle_kind(_text) == toggle:
			_text = text
			_remaining = seconds
			return
	for message in _pending:
		if String(message.text) == text:
			return
	_pending.append({"text": text, "seconds": seconds})
	# Marc's bounded newest-four pending policy. Current text gets its full
	# readable time; duplicate/toggle feedback cannot accumulate a backlog.
	while _pending.size() > MAX_PENDING:
		_pending.pop_front()

func advance(delta: float) -> void:
	_remaining = maxf(0, _remaining - maxf(0, delta))
	if _remaining > 0:
		return
	if _pending.is_empty():
		_text = ""
	else:
		var next: Dictionary = _pending.pop_front()
		_text = String(next.text)
		_remaining = float(next.seconds)

func _toggle_kind(text: String) -> String:
	if text.begins_with("Random encounters on") or text.begins_with("Random encounters off"):
		return "encounters"
	if text.begins_with("Sonar on") or text.begins_with("Sonar off"):
		return "sonar"
	return ""
