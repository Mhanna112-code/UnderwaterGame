# Shown by World when the scripted first fight is lost: Try Again or return to the world.
# Plain Control (not a Window), styled like CharacterAbilityPopup.
class_name TutorialResultPopup
extends Control

signal retry_chosen
signal exit_chosen

var _panel: PanelContainer
var _title: Label
var _body: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Anchors alone leave a runtime Control under a CanvasLayer at size zero.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.22)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	col.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 40
	col.add_child(scroll)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("font_color", Color(0.8, 0.88, 0.9))
	scroll.add_child(_body)

	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(row)

	var retry_btn := Button.new()
	retry_btn.text = "Retry"
	retry_btn.custom_minimum_size = Vector2(140, 40)
	retry_btn.pressed.connect(_on_retry_pressed)
	row.add_child(retry_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit to World"
	exit_btn.custom_minimum_size = Vector2(140, 40)
	exit_btn.pressed.connect(_on_exit_pressed)
	row.add_child(exit_btn)
	resized.connect(_sync_layout)
	get_viewport().size_changed.connect(_sync_layout)
	_panel.minimum_size_changed.connect(func() -> void: _sync_layout.call_deferred())
	_sync_layout()

func _sync_layout() -> void:
	if _panel == null:
		return
	var available := get_viewport_rect().size
	_panel.size = Vector2(minf(440, maxf(0, available.x - 24)), minf(320, maxf(0, available.y - 24)))
	_panel.position = (available - _panel.size) * 0.5

func open(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	visible = true
	get_tree().paused = true
	_sync_layout()

func _close() -> void:
	visible = false
	get_tree().paused = false

func _on_retry_pressed() -> void:
	_close()
	retry_chosen.emit()

func _on_exit_pressed() -> void:
	_close()
	exit_chosen.emit()
