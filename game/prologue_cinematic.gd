extends "res://game/opening_video.gd"

## One decoder for both approved portions of Glass's delivered V3 movie.
## Pausing retains the next frame and silences its embedded audio; no seeking,
## second media copy, or replacement of the later lab cutscene is involved.
signal introduction_finished(success: bool)

const INTRODUCTION_SECONDS := 25.0
var _segment := "introduction"

func _ready() -> void:
	video_path = "res://media/cutscenes/octopus_demon_v3.ogv"
	super._ready()
	add_to_group("prologue_cinematic")

func _process(_dt: float) -> void:
	super._process(_dt)
	if _completed:
		return
	if _segment == "introduction" and not _fallback_visible and _video.stream_position >= INTRODUCTION_SECONDS:
		_pause_introduction()

func _pause_introduction() -> void:
	if _segment != "introduction" or _completed:
		return
	_segment = "waiting_for_defeat"
	_video.paused = true
	_watchdog.stop()
	visible = false
	introduction_finished.emit(true)

func resume_aftermath() -> void:
	if _segment != "waiting_for_defeat" or _completed:
		return
	_segment = "aftermath"
	_last_decoder_position = _video.stream_position
	visible = true
	_video.paused = false
	_watchdog.start()

func _unhandled_input(event: InputEvent) -> void:
	# The hidden owner must not swallow the player's response to Cordys.
	if visible:
		super._unhandled_input(event)

func _complete(success: bool) -> void:
	if _completed:
		return
	if _segment == "introduction":
		_segment = "failed_introduction"
		introduction_finished.emit(false)
	super._complete(success)

## Accelerated lifecycle verification only. Normal playback reaches 25 seconds.
func pause_introduction_for_test() -> void:
	_pause_introduction()
