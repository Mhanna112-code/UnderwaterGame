# Shown by World._show_game_over() the instant a battle ends "lost" (see
# _on_battle_finished()), instead of the old silent auto-restore. Same
# paused-but-interactive shape as TitleScreen - process_mode ALWAYS so its
# two buttons still work while get_tree().paused freezes everything else.
class_name GameOverScreen
extends Control

signal restart_chosen
signal title_chosen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.02, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := Label.new()
	title.text = "The party is overwhelmed..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	col.add_child(title)

	var restart_btn := Button.new()
	restart_btn.text = "Restart from Save Point"
	restart_btn.custom_minimum_size = Vector2(360, 44)
	restart_btn.pressed.connect(func() -> void: restart_chosen.emit())
	col.add_child(restart_btn)

	var title_btn := Button.new()
	title_btn.text = "Return to Title"
	title_btn.custom_minimum_size = Vector2(360, 44)
	title_btn.pressed.connect(func() -> void: title_chosen.emit())
	col.add_child(title_btn)

func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
