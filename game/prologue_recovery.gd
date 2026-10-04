class_name PrologueRecovery
extends CanvasLayer

signal continued
const MOTIVATION := "Grow stronger. Find a way to defeat Cordys."

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("prologue_recovery")
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("06131c")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 280.0
	panel.add_theme_constant_override("separation", 28)
	center.add_child(panel)
	var text := Label.new()
	text.text = MOTIVATION
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 26)
	text.add_theme_color_override("font_color", Color("d5edf5"))
	panel.add_child(text)
	var button := Button.new()
	button.text = "Continue"
	button.custom_minimum_size = Vector2(200, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: continued.emit())
	panel.add_child(button)
	button.grab_focus()
	var resize := func() -> void:
		panel.custom_minimum_size.x = minf(600.0, maxf(280.0, get_viewport().get_visible_rect().size.x - 48.0))
	get_viewport().size_changed.connect(resize)
	resize.call()
