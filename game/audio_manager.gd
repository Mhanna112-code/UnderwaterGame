# Single owner for music sequencing and, in later increments, game SFX.
#
# Phoenix's paired tracks are authored as an INTRO followed immediately by a
# LOOP with no crossfade. One AudioStreamPlayer makes overlap impossible: the
# finished signal replaces the intro stream with a loop-enabled duplicate and
# starts that same player again.
class_name UnderwaterAudioManager
extends Node

signal music_state_changed(cue_id: String, phase: String)

var _music_player: AudioStreamPlayer
var _cue_id := ""
var _phase := "stopped"
var _intro_stream: AudioStream
var _loop_stream: AudioStream
var _transition_trace: Array[String] = []

func _ready() -> void:
	_ensure_players()

func play_music_sequence(cue_id: String, intro: AudioStream, loop: AudioStream) -> void:
	_ensure_players()
	if cue_id == _cue_id and _phase != "stopped":
		return
	stop_music()
	_cue_id = cue_id
	_intro_stream = _non_looping_copy(intro)
	_loop_stream = _looping_copy(loop)
	if _intro_stream != null:
		_phase = "intro"
		_music_player.stream = _intro_stream
		_music_player.play()
		_record_transition()
	elif _loop_stream != null:
		_phase = "loop"
		_music_player.stream = _loop_stream
		_music_player.play()
		_record_transition()
	else:
		stop_music()

func stop_music() -> void:
	_ensure_players()
	_music_player.stop()
	_music_player.stream = null
	_cue_id = ""
	_phase = "stopped"
	_intro_stream = null
	_loop_stream = null

# Public because this is the semantic production callback connected to the
# AudioStreamPlayer's `finished` signal. Tests drive the same transition
# without waiting through a full authored track.
func advance_music_after_stream_finished() -> void:
	if _phase != "intro" or _loop_stream == null:
		return
	_phase = "loop"
	_music_player.stream = _loop_stream
	_music_player.play()
	_record_transition()

func get_music_state() -> Dictionary:
	return {
		"cue_id": _cue_id,
		"phase": _phase,
		"playing": _phase != "stopped",
		"looping": _phase == "loop",
	}

func get_music_transition_trace() -> Array[String]:
	return _transition_trace.duplicate()

func _ensure_players() -> void:
	if is_instance_valid(_music_player):
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	_music_player.finished.connect(advance_music_after_stream_finished)
	add_child(_music_player)

func _record_transition() -> void:
	_transition_trace.append("%s:%s" % [_cue_id, _phase])
	music_state_changed.emit(_cue_id, _phase)

func _non_looping_copy(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var copy := stream.duplicate() as AudioStream
	_set_stream_loop(copy, false)
	return copy

func _looping_copy(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var copy := stream.duplicate() as AudioStream
	_set_stream_loop(copy, true)
	return copy

func _set_stream_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
