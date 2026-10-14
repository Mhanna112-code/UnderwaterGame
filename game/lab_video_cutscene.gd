class_name LabVideoCutscene
extends CanvasLayer

signal completed(skipped: bool)

const MERMAID_VIDEO := "res://media/cutscenes/mermaid_freak.ogv"

var _video: VideoStreamPlayer
var _action_button: Button
var _completed := false
var _finished_playing := false

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("lab_video_cutscene")

	# Same look as OpeningVideo: full-screen film on black, small mouse-only
	# Skip Cutscene at the bottom right.
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color.BLACK
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_child(aspect)

	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.BLACK
	frame.add_theme_stylebox_override("panel", frame_style)
	aspect.add_child(frame)

	_video = VideoStreamPlayer.new()
	_video.name = "MermaidVideo"
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_STOP
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.stream = load(MERMAID_VIDEO) as VideoStream
	_video.finished.connect(_on_video_finished)
	frame.add_child(_video)

	# Mouse-only (FOCUS_NONE) so Enter/Space can't skip by accident; Esc still skips.
	_action_button = Button.new()
	_action_button.name = "CutsceneAction"
	_action_button.text = "Skip Cutscene"
	_action_button.focus_mode = Control.FOCUS_NONE
	_action_button.add_theme_font_size_override("font_size", 14)
	_action_button.modulate.a = 0.75
	_action_button.anchor_left = 1.0
	_action_button.anchor_top = 1.0
	_action_button.anchor_right = 1.0
	_action_button.anchor_bottom = 1.0
	_action_button.offset_left = -136.0
	_action_button.offset_top = -50.0
	_action_button.offset_right = -16.0
	_action_button.offset_bottom = -16.0
	_action_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_action_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_action_button.pressed.connect(_on_action_pressed)
	shade.add_child(_action_button)

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _video.stream == null:
		# Nothing to show - continue straight into the game.
		_finished_playing = true
		call_deferred("_complete", false)
	else:
		_video.play()

# Web Theora may not emit finished at EOF (same guard as OpeningVideo).
func _process(_dt: float) -> void:
	if _completed or _finished_playing or not is_instance_valid(_video) or _video.stream == null:
		return
	var duration := _video.get_stream_length()
	if duration > 0.0 and _video.stream_position >= duration:
		_on_video_finished()

func _unhandled_input(event: InputEvent) -> void:
	if _completed or not event.is_pressed():
		return
	# Consume all input so nothing reaches the paused world.
	get_viewport().set_input_as_handled()
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		_complete(true)

# No Continue step: the scene hands straight back to the game when it ends.
func _on_video_finished() -> void:
	_finished_playing = true
	_complete(false)

func _on_action_pressed() -> void:
	_complete(not _finished_playing)

func _complete(skipped: bool) -> void:
	if _completed:
		return
	_completed = true
	if is_instance_valid(_video):
		_video.stop()
	visible = false
	get_tree().paused = false
	completed.emit(skipped)
	queue_free()
