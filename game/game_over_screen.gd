# Defeat screen shown when a battle is lost; process_mode ALWAYS so buttons work while paused.
class_name GameOverScreen
extends Control

signal restart_chosen
signal continue_chosen
signal title_chosen

var _continue_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# Reset offsets too, or the content collapses into the top-left corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.02, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(minf(360, maxf(180, get_viewport_rect().size.x - 40)), 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := Label.new()
	title.text = "The party is overwhelmed..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	col.add_child(title)

	var continue_btn := TooltipButton.new()
	_continue_btn = continue_btn
	continue_btn.name = "ContinueLatestSave"
	continue_btn.text = "Continue from Last Autosave"
	continue_btn.custom_minimum_size = Vector2(0, 44)
	continue_btn.pressed.connect(func() -> void: continue_chosen.emit())
	col.add_child(continue_btn)

	var restart_btn := Button.new()
	restart_btn.name = "RestartSavePoint"
	restart_btn.text = "Restart from Save Point"
	restart_btn.custom_minimum_size = Vector2(0, 44)
	restart_btn.pressed.connect(func() -> void: restart_chosen.emit())
	col.add_child(restart_btn)

	var title_btn := Button.new()
	title_btn.text = "Return to Title"
	title_btn.custom_minimum_size = Vector2(0, 44)
	title_btn.pressed.connect(func() -> void: title_chosen.emit())
	col.add_child(title_btn)
	resized.connect(func() -> void:
		col.custom_minimum_size.x = minf(360, maxf(180, get_viewport_rect().size.x - 40)))

# `autosave_info`: tooltip for the first option (divers' levels and how long
# ago the autosave was made); empty for none.
func open(autosave_info := "") -> void:
	if _continue_btn != null:
		_continue_btn.tooltip_text = autosave_info
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
