# A compact, responsive teaching card used only during the first-run route.
# It deliberately replaces the always-on free-swim controls line while a
# player is learning: at this moment, the next action matters more than a
# complete keyboard reference. The normal HUD returns when the maze opens.
class_name OnboardingPanel
extends Control

var _step: Label
var _action: Label
var _instruction: Label
var _ability_chip: Label
var _hint: Label
var _active: Label
var _progress: Label

func _ready() -> void:
	# A lesson should frame the next decision, not occupy the entire horizon.
	# Keep a compact desktop briefing card but let it become nearly full width
	# when the viewport is genuinely narrow.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(22.0, 22.0)
	size = Vector2(438.0, 174.0)
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.name = "Card"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.052, 0.072, 0.9)
	style.border_color = Color(0.26, 0.72, 0.84, 0.82)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 4)
	panel.add_child(rows)
	_step = _label(12, Color(0.4, 0.8, 0.92))
	_step.name = "Step"
	_action = _label(21, Color(0.96, 0.98, 1.0))
	_action.name = "Action"
	_instruction = _label(15, Color(0.78, 0.91, 0.95))
	_instruction.name = "Instruction"
	_ability_chip = _label(14, Color(0.12, 0.23, 0.28))
	_ability_chip.name = "AbilityChip"
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.34, 0.84, 1.0, 0.94)
	chip_style.corner_radius_top_left = 5
	chip_style.corner_radius_top_right = 5
	chip_style.corner_radius_bottom_left = 5
	chip_style.corner_radius_bottom_right = 5
	chip_style.content_margin_left = 9.0
	chip_style.content_margin_right = 9.0
	chip_style.content_margin_top = 3.0
	chip_style.content_margin_bottom = 3.0
	_ability_chip.add_theme_stylebox_override("normal", chip_style)
	_hint = _label(13, Color(0.65, 0.79, 0.83))
	_hint.name = "Hint"
	_active = _label(12, Color(0.96, 0.78, 0.36))
	_active.name = "Active"
	_progress = _label(13, Color(0.45, 1.0, 0.62))
	_progress.name = "Progress"
	rows.add_child(_step)
	rows.add_child(_action)
	rows.add_child(_instruction)
	rows.add_child(_ability_chip)
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
	_step.text = "LESSON %d / 4" % number
	_action.text = title.capitalize()
	var split := action.split("→")
	_instruction.text = split[0].strip_edges() if not split.is_empty() else action
	_ability_chip.text = "  " + (split[1].strip_edges() if split.size() > 1 else action) + "  "
	_ability_chip.visible = true
	_hint.text = hint
	_progress.visible = false

func show_door(title: String, action: String, hint: String, occupied: int) -> void:
	visible = true
	_step.text = "FINAL GATE"
	_action.text = title.capitalize()
	_instruction.text = action
	_ability_chip.visible = false
	_hint.text = hint
	_progress.visible = true
	_progress.text = "PLATES OCCUPIED: %d / 3" % occupied

func set_door_progress(occupied: int) -> void:
	if visible and _progress.visible:
		_progress.text = "PLATES OCCUPIED: %d / 3" % occupied

func show_handoff() -> void:
	visible = true
	_step.text = "FIRST ENCOUNTER"
	_action.text = "Red Angler ahead"
	_instruction.text = "The maze is open."
	_ability_chip.visible = false
	_hint.text = "Swim through the open gate to begin the encounter."
	_progress.visible = false

func set_active_diver(display_name: String, ability: String) -> void:
	if not visible:
		return
	_active.text = "ACTIVE DIVER  ·  %s" % display_name

func _fit_viewport() -> void:
	var viewport_width := get_viewport_rect().size.x
	size.x = minf(438.0, maxf(0.0, viewport_width - 44.0))
