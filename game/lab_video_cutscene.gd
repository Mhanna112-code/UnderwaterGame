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

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.025, 0.04, 0.98)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 28.0
	layout.offset_top = 20.0
	layout.offset_right = -28.0
	layout.offset_bottom = -20.0
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	shade.add_child(layout)

	var heading := Label.new()
	heading.text = "The Broken Office"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color("8eeeff"))
	layout.add_child(heading)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aspect.custom_minimum_size = Vector2(320.0, 180.0)
	layout.add_child(aspect)

	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.BLACK
	frame_style.border_color = Color("55cddd")
	frame_style.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	aspect.add_child(frame)

	_video = VideoStreamPlayer.new()
	_video.name = "MermaidVideo"
	_video.expand = true
	_video.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_video.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_video.stream = load(MERMAID_VIDEO) as VideoStream
	_video.finished.connect(_on_video_finished)
	frame.add_child(_video)

	_action_button = Button.new()
	_action_button.name = "CutsceneAction"
	_action_button.text = "Skip Cutscene"
	_action_button.custom_minimum_size = Vector2(220.0, 48.0)
	_action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action_button.pressed.connect(_on_action_pressed)
	layout.add_child(_action_button)

	var hint := Label.new()
	hint.text = "Escape skips. Press Continue when the scene ends."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("b8cbd2"))
	layout.add_child(hint)

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _video.stream == null:
		_finished_playing = true
		_action_button.text = "Continue"
	else:
		_video.play()
	_action_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if _completed or not event.is_pressed():
		return
	if event is InputEventKey:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			_complete(true)
		elif _finished_playing and (key == KEY_ENTER or key == KEY_KP_ENTER):
			_complete(false)

func _on_video_finished() -> void:
	_finished_playing = true
	_action_button.text = "Continue"
	_action_button.grab_focus()

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
