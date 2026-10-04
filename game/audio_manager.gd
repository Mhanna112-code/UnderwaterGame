# Single owner for music sequencing and, in later increments, game SFX.
#
# Phoenix's paired tracks are authored as an INTRO followed immediately by a
# LOOP with no crossfade. One AudioStreamPlayer makes overlap impossible: the
# finished signal replaces the intro stream with a loop-enabled duplicate and
# starts that same player again.
class_name UnderwaterAudioManager
extends Node

signal music_state_changed(cue_id: String, phase: String)

const EXPLORATION_LOOP: AudioStream = preload("res://audio/music/exploration_loop.ogg")
const BATTLE_INTRO: AudioStream = preload("res://audio/music/battle_intro.ogg")
const BATTLE_LOOP: AudioStream = preload("res://audio/music/battle_loop.ogg")
const TETHYS_LOOP: AudioStream = preload("res://audio/music/tethys_loop.ogg")
const TITLE_CANDIDATE_INTRO: AudioStream = preload("res://audio/music/title_candidate_intro.ogg")
const TITLE_LOOP: AudioStream = preload("res://audio/music/title_loop.ogg")
const VICTORY_CANDIDATE_INTRO: AudioStream = preload("res://audio/music/victory_candidate_intro.ogg")
const VICTORY_LOOP: AudioStream = preload("res://audio/music/victory_loop.ogg")
const GAME_OVER: AudioStream = preload("res://audio/music/game_over.ogg")
const FINAL_BOSS_INTRO: AudioStream = preload("res://audio/music/final_boss_intro.ogg")
const FINAL_BOSS_LOOP: AudioStream = preload("res://audio/music/final_boss_loop.ogg")
const UI_HOVER: AudioStream = preload("res://audio/sfx/ui/hover.wav")
const UI_CLICK: AudioStream = preload("res://audio/sfx/ui/click.wav")
const UI_START_GAME: AudioStream = preload("res://audio/sfx/ui/start_game.wav")
const COMBAT_ATTACK_SWIRL: AudioStream = preload("res://audio/sfx/combat/attack_swirl.ogg")
const COMBAT_SWING: AudioStream = preload("res://audio/sfx/combat/fast_swish_01.ogg")
const COMBAT_MISS: AudioStream = preload("res://audio/sfx/combat/swish_04.ogg")
const COMBAT_DODGE: AudioStream = preload("res://audio/sfx/combat/fast_swish_03.ogg")
const COMBAT_HEAVY_HIT: AudioStream = preload("res://audio/sfx/combat/heavy_hit.ogg")
const COMBAT_SHOCKWAVE: AudioStream = preload("res://audio/sfx/combat/shockwave_swirl.ogg")
const COMBAT_SFX_PLAYER_COUNT := 4

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _combat_sfx_players: Array[AudioStreamPlayer] = []
var _next_combat_sfx_player := 0
var _cue_id := ""
var _phase := "stopped"
var _intro_stream: AudioStream
var _loop_stream: AudioStream
var _intro_gain_db := 0.0
var _loop_gain_db := 0.0
var _active_gain_db := 0.0
var _transition_trace: Array[String] = []
var _sfx_event_trace: Array[String] = []
var settings_path := "user://audio.cfg"
var _music_volume := 1.0
var _music_muted := false
var _sfx_volume := 1.0
var _sfx_muted := false

func _ready() -> void:
	# Title and game-over deliberately pause the SceneTree. Their audio is
	# still a live UI surface, so the global owner must remain processable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_players()
	load_audio_settings()

func _exit_tree() -> void:
	# Release duplicated compressed streams before Godot performs its final
	# ObjectDB/resource leak audit. This is also exercised by headless route
	# verifiers, which create and destroy complete World sessions quickly.
	release_streams_for_shutdown()

func release_streams_for_shutdown() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	if is_instance_valid(_sfx_player):
		_sfx_player.stop()
		_sfx_player.stream = null
	for player in _combat_sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_cue_id = ""
	_phase = "stopped"
	_intro_stream = null
	_loop_stream = null

func play_music_sequence(cue_id: String, intro: AudioStream, loop: AudioStream) -> void:
	play_authored_music_sequence(cue_id, intro, loop, 0.0, 0.0)

# The authored trim is local to a cue and composes with the player's Music bus
# setting. It must never rewrite the persistent volume slider: the opening can
# therefore be intentionally quieter without making the rest of the game quiet.
func play_authored_music_sequence(
		cue_id: String,
		intro: AudioStream,
		loop: AudioStream,
		intro_gain_db: float,
		loop_gain_db: float) -> void:
	_ensure_players()
	if cue_id == _cue_id and _phase != "stopped":
		return
	stop_music()
	_cue_id = cue_id
	_intro_gain_db = intro_gain_db
	_loop_gain_db = loop_gain_db
	_intro_stream = _non_looping_copy(intro)
	_loop_stream = _looping_copy(loop)
	if _intro_stream != null:
		_phase = "intro"
		_apply_active_music_gain(_intro_gain_db)
		_music_player.stream = _intro_stream
		_start_player(_music_player)
		_record_transition()
	elif _loop_stream != null:
		_phase = "loop"
		_apply_active_music_gain(_loop_gain_db)
		_music_player.stream = _loop_stream
		_start_player(_music_player)
		_record_transition()
	else:
		stop_music()

func play_music_once(cue_id: String, stream: AudioStream) -> void:
	_ensure_players()
	if cue_id == _cue_id and _phase == "one_shot":
		return
	stop_music()
	if stream == null:
		return
	_cue_id = cue_id
	_phase = "one_shot"
	_music_player.stream = _non_looping_copy(stream)
	_start_player(_music_player)
	_record_transition()

func play_exploration_music() -> void:
	play_music_sequence("exploration", null, EXPLORATION_LOOP)

func play_battle_music() -> void:
	play_music_sequence("battle", BATTLE_INTRO, BATTLE_LOOP)

func play_tethys_music() -> void:
	# The delivered "verb tail" is not labelled INTRO and has not passed the
	# browser listening audit. Use the explicitly authored seamless loop.
	play_music_sequence("tethys", null, TETHYS_LOOP)

func play_title_music() -> void:
	# This pair remains candidate pending the binding listening audit. Keeping
	# ownership here prevents TitleScreen from choosing raw files itself.
	play_music_sequence("title", TITLE_CANDIDATE_INTRO, TITLE_LOOP)

func play_victory_music() -> void:
	play_music_sequence("victory", VICTORY_CANDIDATE_INTRO, VICTORY_LOOP)

func play_game_over_music() -> void:
	play_music_once("game_over", GAME_OVER)

func play_prologue_exploration_music() -> void:
	play_authored_music_sequence("prologue_exploration", null, EXPLORATION_LOOP, -7.0, -7.0)

func play_prologue_battle_music() -> void:
	play_authored_music_sequence("prologue_battle", BATTLE_INTRO, BATTLE_LOOP, 0.0, -7.0)

func play_cordys_music() -> void:
	play_authored_music_sequence("cordys", FINAL_BOSS_INTRO, FINAL_BOSS_LOOP, -1.0, -4.5)

func stop_music() -> void:
	_ensure_players()
	_music_player.stop()
	_music_player.stream = null
	_cue_id = ""
	_phase = "stopped"
	_intro_stream = null
	_loop_stream = null
	_intro_gain_db = 0.0
	_loop_gain_db = 0.0
	_apply_active_music_gain(0.0)

# Public because this is the semantic production callback connected to the
# AudioStreamPlayer's `finished` signal. Tests drive the same transition
# without waiting through a full authored track.
func advance_music_after_stream_finished() -> void:
	if _phase == "one_shot":
		stop_music()
		return
	if _phase != "intro" or _loop_stream == null:
		return
	_phase = "loop"
	_apply_active_music_gain(_loop_gain_db)
	_music_player.stream = _loop_stream
	_start_player(_music_player)
	_record_transition()

func get_music_state() -> Dictionary:
	return {
		"cue_id": _cue_id,
		"phase": _phase,
		"playing": _phase != "stopped",
		"looping": _phase == "loop",
	}

func get_music_gain_state() -> Dictionary:
	return {
		"intro_db": _intro_gain_db,
		"loop_db": _loop_gain_db,
		"active_db": _active_gain_db,
	}

func get_music_transition_trace() -> Array[String]:
	return _transition_trace.duplicate()

func play_ui_hover() -> void:
	_play_sfx("ui_hover", UI_HOVER)

func play_ui_click() -> void:
	_play_sfx("ui_click", UI_CLICK)

func play_ui_start_game() -> void:
	_play_sfx("ui_start_game", UI_START_GAME)

# Combat uses a short round-robin pool instead of the UI player's
# stop-and-replace policy. An attack swing and its impact are separate pieces
# of feedback and must be able to overlap without either one cutting off.
func play_combat_swing(heavy: bool = false) -> void:
	_play_combat_sfx("combat_heavy_swing" if heavy else "combat_swing",
		COMBAT_ATTACK_SWIRL if heavy else COMBAT_SWING, -3.0 if heavy else -5.0)

func play_combat_result(hit: bool, dodged: bool = false, heavy: bool = false) -> void:
	if hit and not dodged:
		_play_combat_sfx("combat_heavy_hit" if heavy else "combat_hit", COMBAT_HEAVY_HIT,
			-2.0 if heavy else -8.0)
	elif dodged:
		_play_combat_sfx("combat_dodge", COMBAT_DODGE, -4.0)
	else:
		_play_combat_sfx("combat_miss", COMBAT_MISS, -5.0)

func play_shockwave() -> void:
	_play_combat_sfx("shockwave", COMBAT_SHOCKWAVE, -7.0)

func get_sfx_event_trace() -> Array[String]:
	return _sfx_event_trace.duplicate()

func clear_sfx_event_trace() -> void:
	_sfx_event_trace.clear()

func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_settings("Music", _music_volume, _music_muted)

func set_music_muted(value: bool) -> void:
	_music_muted = value
	_apply_bus_settings("Music", _music_volume, _music_muted)

func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_settings("SFX", _sfx_volume, _sfx_muted)

func set_sfx_muted(value: bool) -> void:
	_sfx_muted = value
	_apply_bus_settings("SFX", _sfx_volume, _sfx_muted)

func get_audio_settings() -> Dictionary:
	return {
		"music_volume": _music_volume,
		"music_muted": _music_muted,
		"sfx_volume": _sfx_volume,
		"sfx_muted": _sfx_muted,
	}

func save_audio_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "music_muted", _music_muted)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.set_value("audio", "sfx_muted", _sfx_muted)
	return config.save(settings_path)

func load_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		_music_volume = clampf(float(config.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
		_music_muted = bool(config.get_value("audio", "music_muted", false))
		_sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
		_sfx_muted = bool(config.get_value("audio", "sfx_muted", false))
	_apply_bus_settings("Music", _music_volume, _music_muted)
	_apply_bus_settings("SFX", _sfx_volume, _sfx_muted)

func _ensure_players() -> void:
	if is_instance_valid(_music_player):
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	_music_player.finished.connect(advance_music_after_stream_finished)
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)
	for index in range(COMBAT_SFX_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "CombatSFX%d" % index
		player.bus = "SFX"
		add_child(player)
		_combat_sfx_players.append(player)

func _apply_bus_settings(bus_name: String, volume: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, muted)

func _apply_active_music_gain(value_db: float) -> void:
	_active_gain_db = value_db
	if is_instance_valid(_music_player):
		_music_player.volume_db = value_db

func _play_sfx(event_id: String, stream: AudioStream) -> void:
	_ensure_players()
	_sfx_player.stop()
	_sfx_player.stream = _non_looping_copy(stream)
	_start_player(_sfx_player)
	_sfx_event_trace.append(event_id)

func _play_combat_sfx(event_id: String, stream: AudioStream, volume_db: float) -> void:
	_ensure_players()
	if _combat_sfx_players.is_empty() or stream == null:
		return
	var player := _combat_sfx_players[_next_combat_sfx_player]
	_next_combat_sfx_player = (_next_combat_sfx_player + 1) % _combat_sfx_players.size()
	player.stop()
	player.stream = _non_looping_copy(stream)
	player.volume_db = volume_db
	_start_player(player)
	_sfx_event_trace.append(event_id)

# Headless gates verify semantic cue ownership and transition state, not sound
# hardware. Starting a compressed stream there creates an Ogg playback object
# that Godot's immediate SceneTree.quit() leak audit can observe before the
# dummy audio thread retires it. Native and web play normally; headless tests
# keep the exact stream/state contracts without manufacturing a false leak.
func _start_player(player: AudioStreamPlayer) -> void:
	if DisplayServer.get_name() == "headless":
		return
	player.play()

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
