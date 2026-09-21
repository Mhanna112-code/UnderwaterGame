# Shown by World when the scripted first fight ends in a loss - same visual
# recipe as CharacterAbilityPopup (dark blue PanelContainer, white border,
# light text; a plain Control toggled by visibility rather than a Window,
# for the same crash-avoidance reason documented on that class), but with
# two action buttons instead of a paged Next/Close, since there's a real
# choice here (try again, or head back to the world) rather than more pages
# to read through.
class_name TutorialResultPopup
extends Control

signal retry_chosen
signal exit_chosen

var _panel: PanelContainer
var _title: Label
var _body: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# _and_offsets_ matters - PRESET_FULL_RECT anchors alone leave this
	# Control's initial zero-size offsets untouched, collapsing it (and the
	# centered panel inside it) into a tiny rect in the corner instead of the
	# full viewport - same fix title_screen.gd's own header comment documents
	# needing for exactly this "runtime Control parented directly under a
	# CanvasLayer, nothing above it to inherit a size from" situation.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -220.0
	_panel.offset_top = -110.0
	_panel.offset_right = 220.0
	_panel.offset_bottom = 110.0
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
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	col.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("font_color", Color(0.8, 0.88, 0.9))
	col.add_child(_body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
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

func open(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	visible = true
	get_tree().paused = true

func _close() -> void:
	visible = false
	get_tree().paused = false

func _on_retry_pressed() -> void:
	_close()
	retry_chosen.emit()

func _on_exit_pressed() -> void:
	_close()
	exit_chosen.emit()
