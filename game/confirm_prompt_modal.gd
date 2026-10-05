class_name ConfirmPromptModal
extends CanvasLayer

# A yes/no question in the middle of the screen (styled like PosterModal).
# Yes: the Yes button or Y. No: the No button, N or Esc. "No" has focus, so
# Enter/Space press the safe choice. Emits `answered` once, then frees itself.

signal answered(yes: bool)

const PANEL_SIZE := Vector2(560, 210)

var message := ""
var _done := false

func _init(text: String) -> void:
	message = text

func _ready() -> void:
	layer = 90   # above the HUD captions, below CharacterAbilityPopup (100)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.03, 0.05, 1.0)
	style.border_color = Color(1.0, 0.3, 0.25)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(panel)

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.8))
	label.position = Vector2(24, 24)
	label.size = Vector2(PANEL_SIZE.x - 48, 100)
	panel.add_child(label)

	var yes := Button.new()
	yes.text = "Yes (Y)"
	yes.add_theme_font_size_override("font_size", 20)
	yes.size = Vector2(150, 44)
	yes.position = Vector2(PANEL_SIZE.x * 0.5 - 170, PANEL_SIZE.y - 68)
	yes.pressed.connect(func() -> void: _answer(true))
	panel.add_child(yes)

	var no := Button.new()
	no.text = "No (N)"
	no.add_theme_font_size_override("font_size", 20)
	no.size = Vector2(150, 44)
	no.position = Vector2(PANEL_SIZE.x * 0.5 + 20, PANEL_SIZE.y - 68)
	no.pressed.connect(func() -> void: _answer(false))
	panel.add_child(no)
	no.grab_focus.call_deferred()   # the safe choice is the default

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo):
		return
	match (event as InputEventKey).keycode:
		KEY_Y:
			get_viewport().set_input_as_handled()
			_answer(true)
		KEY_N, KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_answer(false)

func _answer(yes: bool) -> void:
	if _done:
		return
	_done = true
	answered.emit(yes)
	queue_free()
