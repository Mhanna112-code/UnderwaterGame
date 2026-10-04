class_name PrologueRecovery
extends CanvasLayer

signal continued
const MOTIVATION := "Grow stronger. Find a way to defeat Cordys."
var _save_status: Label
var _continue_button: Button

class RecoveryBackdrop extends Control:
	func _draw() -> void:
		# Quiet, stationary shafts of water light. No flashing, motion gate,
		# extra media owner or input surface during checkpoint confirmation.
		for offset in [-0.32, 0.02, 0.36]:
			var x: float = size.x * (0.5 + float(offset))
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, 0), Vector2(x + size.x * 0.07, 0),
				Vector2(x + size.x * 0.30, size.y), Vector2(x - size.x * 0.15, size.y)
			]), Color(0.21, 0.53, 0.59, 0.035))
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

func _button_style(background: String, border: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 26
	style.content_margin_right = 26
	return style

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("prologue_recovery")
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("06131c")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	gradient.colors = PackedColorArray([Color("17444e"), Color("0b2431"), Color("06131c")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, -0.15)
	texture.fill_to = Vector2(0.5, 1.0)
	var light := TextureRect.new()
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light.texture = texture
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(light)
	var shafts := RecoveryBackdrop.new()
	shafts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shafts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(shafts)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card := PanelContainer.new()
	card.name = "RecoveryCard"
	var card_style := _button_style("091d29", "264552")
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 32
	card_style.content_margin_right = 32
	card_style.content_margin_top = 32
	card_style.content_margin_bottom = 32
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 18)
	card.add_child(panel)
	var eyebrow := Label.new()
	eyebrow.text = "YOU SURVIVED"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color("83b6c0"))
	panel.add_child(eyebrow)
	var text := Label.new()
	text.name = "RecoveryMotivation"
	text.text = "Grow stronger."
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 40)
	text.add_theme_color_override("font_color", Color("e4f5f5"))
	panel.add_child(text)
	var purpose := Label.new()
	purpose.name = "RecoveryPurpose"
	purpose.text = "Find a way to defeat Cordys."
	purpose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	purpose.add_theme_font_size_override("font_size", 21)
	purpose.add_theme_color_override("font_color", Color("b5d1db"))
	panel.add_child(purpose)
	var divider := ColorRect.new()
	divider.color = Color("4e8793")
	divider.custom_minimum_size = Vector2(48, 2)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)
	_save_status = Label.new()
	_save_status.text = "Could not save your checkpoint. Free storage or enable saving, then retry."
	_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_status.add_theme_font_size_override("font_size", 16)
	_save_status.add_theme_color_override("font_color", Color("ffce93"))
	_save_status.visible = false
	panel.add_child(_save_status)
	var button := Button.new()
	_continue_button = button
	button.text = "Continue"
	button.custom_minimum_size = Vector2(224, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("e3f6f6"))
	button.add_theme_stylebox_override("normal", _button_style("174552", "4d8592"))
	button.add_theme_stylebox_override("hover", _button_style("216071", "83c5cf"))
	button.add_theme_stylebox_override("pressed", _button_style("10333f", "83c5cf"))
	button.add_theme_stylebox_override("disabled", _button_style("112b38", "264552"))
	var focus := _button_style("00000000", "b4e5eb")
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(func() -> void: continued.emit())
	panel.add_child(button)
	button.grab_focus()
	var resize := func() -> void:
		var width := get_viewport().get_visible_rect().size.x
		card.custom_minimum_size.x = minf(620.0, maxf(280.0, width - 40.0))
		text.add_theme_font_size_override("font_size", 32 if width < 500 else 40)
	get_viewport().size_changed.connect(resize)
	resize.call()

func show_save_failure() -> void:
	_save_status.visible = true
	_continue_button.text = "Retry Save"
	_continue_button.disabled = false
	_continue_button.grab_focus()

func show_saving() -> void:
	_save_status.visible = false
	_continue_button.text = "Saving checkpoint..."
	_continue_button.disabled = true

func clear_save_failure() -> void:
	_save_status.visible = false
	_continue_button.text = "Continue"
	_continue_button.disabled = false
