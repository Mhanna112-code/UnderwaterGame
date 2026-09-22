class_name TutorialResultPopup
extends Control

signal retry_chosen
signal exit_chosen

var _title: Label
var _body: Label
var _retry_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250.0
	panel.offset_top = -130.0
	panel.offset_right = 250.0
	panel.offset_bottom = 130.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.22)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	column.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("font_color", Color(0.82, 0.9, 0.94))
	column.add_child(_body)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(actions)
	_retry_button = Button.new()
	_retry_button.text = "Try Again"
	_retry_button.tooltip_text = "Restart the safe practice fight"
	_retry_button.custom_minimum_size = Vector2(160, 42)
	_retry_button.pressed.connect(_retry)
	actions.add_child(_retry_button)
	var exit := Button.new()
	exit.text = "Return to World"
	exit.tooltip_text = "Leave practice and continue safely in the world"
	exit.custom_minimum_size = Vector2(180, 42)
	exit.pressed.connect(_exit)
	actions.add_child(exit)

func open(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	visible = true
	get_tree().paused = true
	call_deferred("_focus_retry")

func _focus_retry() -> void:
	if visible and _retry_button != null:
		_retry_button.grab_focus()

func _close() -> void:
	visible = false
	get_tree().paused = false

func _retry() -> void:
	_close()
	retry_chosen.emit()

func _exit() -> void:
	_close()
	exit_chosen.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	match (event as InputEventKey).keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_retry()
		KEY_ESCAPE:
			_exit()
		_:
			return
	get_viewport().set_input_as_handled()
