# A compact, responsive teaching card used only during the first-run route.
# It deliberately replaces the always-on free-swim controls line while a
# player is learning: at this moment, the next action matters more than a
# complete keyboard reference. The normal HUD returns when the maze opens.
class_name OnboardingPanel
extends Control

var _step: Label
var _action: Label
var _hint: Label
var _active: Label
var _progress: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_left = 14.0
	offset_top = 14.0
	offset_right = -14.0
	offset_bottom = 176.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.name = "Card"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.07, 0.09, 0.92)
	style.border_color = Color(0.32, 0.84, 1.0, 0.75)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 3)
	panel.add_child(rows)
	_step = _label(15, Color(0.42, 0.88, 1.0))
	_step.name = "Step"
	_action = _label(21, Color.WHITE)
	_action.name = "Action"
	_hint = _label(15, Color(0.72, 0.86, 0.88))
	_hint.name = "Hint"
	_active = _label(14, Color(0.96, 0.8, 0.34))
	_active.name = "Active"
	_progress = _label(15, Color(0.45, 1.0, 0.62))
	_progress.name = "Progress"
	rows.add_child(_step)
	rows.add_child(_action)
	rows.add_child(_hint)
	rows.add_child(_active)
	rows.add_child(_progress)
	_progress.visible = false
	visible = false

func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func show_step(number: int, title: String, action: String, hint: String) -> void:
	visible = true
	_step.text = "STEP %d OF 4  ·  %s" % [number, title]
	_action.text = action
	_hint.text = hint
	_progress.visible = false

func show_door(title: String, action: String, hint: String, occupied: int) -> void:
	visible = true
	_step.text = "FINAL GATE  ·  " + title
	_action.text = action
	_hint.text = hint
	_progress.visible = true
	_progress.text = "PLATES OCCUPIED: %d / 3" % occupied

func set_door_progress(occupied: int) -> void:
	if visible and _progress.visible:
		_progress.text = "PLATES OCCUPIED: %d / 3" % occupied

func show_handoff() -> void:
	visible = true
	_step.text = "FIRST COMBAT"
	_action.text = "RED ANGLER AHEAD"
	_hint.text = "Swim through the open gate to begin the encounter."
	_progress.visible = false

func set_active_diver(display_name: String, ability: String) -> void:
	if not visible:
		return
	_active.text = "YOU ARE SWIMMING: %s  ·  E: %s" % [display_name, ability.capitalize()]
