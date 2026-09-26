# Shown by World._show_game_over() the instant a battle ends "lost" (see
# _on_battle_finished()), instead of the old silent auto-restore. Same
# paused-but-interactive shape as TitleScreen - process_mode ALWAYS so its
# two buttons still work while get_tree().paused freezes everything else.
class_name GameOverScreen
extends Control

signal restart_chosen
signal title_chosen

var _detail: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# Like TitleScreen, this is created directly under a CanvasLayer. Anchors
	# alone preserve the runtime Control's initial zero-sized offsets; reset
	# both so CenterContainer receives the real viewport instead of bunching
	# the defeat message and buttons into the upper-left corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(360, 0)
	_detail.add_theme_color_override("font_color", Color(0.76, 0.87, 0.91))
	col.add_child(_detail)

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

func open(restart_detail: String = "") -> void:
	_detail.text = restart_detail if restart_detail != "" else "Restart from your most recent save point."
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
