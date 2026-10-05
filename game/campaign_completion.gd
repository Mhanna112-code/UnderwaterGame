extends CanvasLayer
## Exclusive ending surface. World owns checkpoint IO and the paused party.
signal restart_chosen
signal title_chosen

var status: Label
var restart_button: Button
var title_button: Button

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("campaign_completion")
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("06131c")
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	shade.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)
	var heading := Label.new()
	heading.text = "Game complete"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("e4f5f5"))
	column.add_child(heading)
	var detail := Label.new()
	detail.text = "Cordys is defeated."
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 22)
	detail.add_theme_color_override("font_color", Color("83b6c0"))
	column.add_child(detail)
	status = Label.new()
	status.name = "CheckpointStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 16)
	column.add_child(status)
	restart_button = Button.new()
	restart_button.name = "RestartFromAutoSave"
	restart_button.text = "Restart from Auto Save"
	restart_button.custom_minimum_size.y = 48
	restart_button.pressed.connect(func() -> void: restart_chosen.emit())
	column.add_child(restart_button)
	title_button = Button.new()
	title_button.name = "ReturnToTitle"
	title_button.text = "Return to Title"
	title_button.custom_minimum_size.y = 48
	title_button.pressed.connect(func() -> void: title_chosen.emit())
	column.add_child(title_button)
	var resize := func() -> void:
		column.custom_minimum_size.x = minf(560.0, maxf(1.0, get_viewport().get_visible_rect().size.x - 48.0))
	get_viewport().size_changed.connect(resize)
	resize.call()

# has_autosave: whether a pre-boss autosave exists to restart from.
func show_options(has_autosave: bool) -> void:
	status.text = "The game was autosaved right before the Cordys fight." if has_autosave 		else "No autosave from before the Cordys fight is available."
	restart_button.disabled = not has_autosave
	(restart_button if has_autosave else title_button).grab_focus()
