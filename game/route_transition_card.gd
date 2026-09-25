# Temporary, explicit handoff UI for the core route.  This intentionally
# avoids pretending to be final narration: it states the immediate change,
# gives the player a single Continue action, and yields to Glassgoat's final
# cutscene work when that arrives.
class_name RouteTransitionCard
extends Control

signal continued

var _title: Label
var _body: RichTextLabel
var _continue: Button

func _ready() -> void:
	name = "RouteTransitionCard"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.05, 0.08, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = -164.0
	panel.offset_bottom = 164.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	margin.add_child(column)

	var eyebrow := Label.new()
	eyebrow.text = "ROUTE UPDATE"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.42, 0.82, 0.96))
	column.add_child(eyebrow)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 27)
	_title.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	column.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(0, 100)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_color_override("default_color", Color(0.8, 0.9, 0.95))
	column.add_child(_body)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.custom_minimum_size = Vector2(150, 42)
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.29, 0.38, 1.0)))
	_continue.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.42, 0.54, 1.0)))
	_continue.add_theme_stylebox_override("pressed", _button_style(Color(0.05, 0.19, 0.26, 1.0)))
	_continue.pressed.connect(dismiss)
	column.add_child(_continue)

func open_card(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continue.grab_focus()

func dismiss() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	continued.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := event as InputEventKey
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			dismiss()
			get_viewport().set_input_as_handled()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.14, 0.99)
	style.border_color = Color(0.28, 0.72, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	return style

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.44, 0.86, 1.0, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	return style
