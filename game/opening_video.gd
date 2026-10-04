class_name OpeningVideo
extends CanvasLayer

## First-run cinematic owner.
##
## This intentionally does not share lifecycle or controls with
## LabVideoCutscene. They reuse the same temporary media bytes, but the opening
## is non-skippable while the later lab scene remains skippable.

signal completed(success: bool)

const DEFAULT_VIDEO := "res://media/cutscenes/mermaid_freak.ogv"
const DECODER_WATCHDOG_SECONDS := 4.0

@export_file("*.ogv") var video_path := DEFAULT_VIDEO
@export var local_volume_db := -6.0

var _video: VideoStreamPlayer
var _fallback: VBoxContainer
var _continue_button: Button
var _watchdog: Timer
var _completed := false
var _fallback_visible := false
var _last_decoder_position := 0.0

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("opening_video")

	var shade := ColorRect.new()
	shade.name = "InputBlocker"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color.BLACK
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var aspect := AspectRatioContainer.new()
	aspect.name = "OpeningAspect"
	aspect.set_anchors_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_child(aspect)

	var frame := PanelContainer.new()
	frame.name = "OpeningFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.BLACK
	frame.add_theme_stylebox_override("panel", frame_style)
	aspect.add_child(frame)

	_video = VideoStreamPlayer.new()
	_video.name = "OpeningMedia"
	_video.expand = true
	_video.bus = &"Music"
	_video.volume_db = local_volume_db
	_video.mouse_filter = Control.MOUSE_FILTER_STOP
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.stream = load(video_path) as VideoStream
	_video.finished.connect(_on_video_finished)
	frame.add_child(_video)

	_fallback = VBoxContainer.new()
	_fallback.name = "DecoderFallback"
	_fallback.set_anchors_preset(Control.PRESET_CENTER)
	_fallback.offset_left = -220.0
	_fallback.offset_top = -70.0
	_fallback.offset_right = 220.0
	_fallback.offset_bottom = 70.0
	_fallback.alignment = BoxContainer.ALIGNMENT_CENTER
	_fallback.add_theme_constant_override("separation", 18)
	_fallback.visible = false
	shade.add_child(_fallback)

	var fallback_text := Label.new()
	fallback_text.text = "The opening video could not play."
	fallback_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_text.add_theme_font_size_override("font_size", 22)
	fallback_text.add_theme_color_override("font_color", Color("d9edf4"))
	_fallback.add_child(fallback_text)

	_continue_button = Button.new()
	_continue_button.name = "Continue"
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(220.0, 48.0)
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_button.pressed.connect(_on_fallback_continue)
	_fallback.add_child(_continue_button)

	_watchdog = Timer.new()
	_watchdog.name = "DecoderWatchdog"
	_watchdog.one_shot = false
	_watchdog.wait_time = DECODER_WATCHDOG_SECONDS
	_watchdog.timeout.connect(_on_decoder_watchdog)
	add_child(_watchdog)

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _video.stream == null:
		_show_decoder_fallback()
	else:
		_video.play()
		_watchdog.start()

func _process(_dt: float) -> void:
	if _completed or _fallback_visible or not is_instance_valid(_video) or _video.paused:
		return
	# Web Theora can continue advancing its clock after EOF without emitting
	# finished. Use the complete decoder-reported length, not a wall-clock
	# timeout or hard-coded asset duration, so a future replacement is intact.
	var duration := _video.get_stream_length()
	if duration > 0.0 and _video.stream_position >= duration:
		_on_video_finished()

func _unhandled_input(event: InputEvent) -> void:
	if _completed or not event.is_pressed():
		return
	# First-run playback has no skip path. Consume keyboard and mouse events so
	# neither Escape nor gameplay controls reach the paused world underneath.
	get_viewport().set_input_as_handled()

func _on_video_finished() -> void:
	_complete(true)

func _on_decoder_watchdog() -> void:
	if _completed or _fallback_visible:
		return
	# A decoder can claim playing while never advancing, including a stall
	# after a valid first frame. Observe progress for every grace interval,
	# not just the initial playing flag, to prevent a permanent black lock.
	var position_now := _video.stream_position
	if position_now <= _last_decoder_position + 0.01:
		_show_decoder_fallback()
	else:
		_last_decoder_position = position_now

func _show_decoder_fallback() -> void:
	if _completed or _fallback_visible:
		return
	_fallback_visible = true
	if is_instance_valid(_watchdog):
		_watchdog.stop()
	if is_instance_valid(_video):
		_video.stop()
		_video.visible = false
	_fallback.visible = true
	_continue_button.grab_focus()

func _on_fallback_continue() -> void:
	_complete(false)

func _complete(success: bool) -> void:
	if _completed:
		return
	_completed = true
	if is_instance_valid(_watchdog):
		_watchdog.stop()
	if is_instance_valid(_video):
		_video.stop()
	visible = false
	completed.emit(success)
	queue_free()

## Explicit verification seams. They are never called by production flow.
func finish_for_test() -> void:
	_complete(true)

func fail_for_test() -> void:
	_show_decoder_fallback()
