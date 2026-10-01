# A paged tutorial overlay - one topic per page, Prev/Next to move between
# them, Close to dismiss. Content-agnostic: pass whatever `pages` array you
# want (see content/tutorial_content.gd's GENERAL_PAGES for the shape:
# [{"title": String, "body": String}, ...]) rather than this class owning
# any particular tutorial's wording, so the same book can show the new-game
# walkthrough, a reopened "Help" screen, or a future topic-specific one
# with no changes here.
#
# Same paused-but-interactive shape as TitleScreen/SpecialEncounterPrompt -
# process_mode ALWAYS so input still works while get_tree().paused freezes
# the world underneath.
class_name TutorialBook
extends Control

signal closed

var _pages: Array[Dictionary] = []
var _index := 0

var _title_label: Label
var _body_label: Label
var _page_label: Label
var _prev_btn: Button
var _next_btn: Button
var _close_btn: Button
var _x_close_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# PRESET_FULL_RECT anchors alone leave offsets at zero, which for a
	# runtime-built Control parented directly under a CanvasLayer (nothing
	# above it to inherit a size from) collapses the whole rect to (0, 0) -
	# same fix special_encounter_prompt.gd/title_screen.gd already needed.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(col)

	_page_label = Label.new()
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_color_override("font_color", Color(0.5, 0.65, 0.7))
	col.add_child(_page_label)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	col.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body_label.custom_minimum_size = Vector2(560, 160)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.add_theme_color_override("font_color", Color(0.8, 0.88, 0.9))
	col.add_child(_body_label)

	var button_row := HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button_row.add_theme_constant_override("separation", 12)
	col.add_child(button_row)

	_prev_btn = Button.new()
	_prev_btn.text = "< Back"
	_prev_btn.custom_minimum_size = Vector2(120, 40)
	_prev_btn.pressed.connect(_step.bind(-1))
	button_row.add_child(_prev_btn)

	_next_btn = Button.new()
	_next_btn.text = "Next >"
	_next_btn.custom_minimum_size = Vector2(120, 40)
	_next_btn.pressed.connect(_step.bind(1))
	button_row.add_child(_next_btn)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(120, 40)
	_close_btn.pressed.connect(_on_close_pressed)
	button_row.add_child(_close_btn)

	# Always-available exit independent of which page you're on - the
	# Prev/Next/Close row (above) already dismisses via Close, but a corner
	# X reads as the universal "get me out of this modal" control everyone
	# already expects, same job as _on_close_pressed() either way.
	_x_close_btn = Button.new()
	_x_close_btn.text = "×"
	var x_btn_size := Vector2(36, 36)
	_x_close_btn.custom_minimum_size = x_btn_size
	_x_close_btn.add_theme_font_size_override("font_size", 20)
	_x_close_btn.pressed.connect(_on_close_pressed)
	# Explicit anchors/offsets from a fixed size, not
	# set_anchors_and_offsets_preset()'s PRESET_MODE_MINSIZE - see
	# character_ability_popup.gd's own corner X for why that undershoots
	# (it measures get_combined_minimum_size() before add_child(), so
	# before the size/font overrides just above have actually taken).
	var x_inset := 16.0
	_x_close_btn.anchor_left = 1.0
	_x_close_btn.anchor_right = 1.0
	_x_close_btn.anchor_top = 0.0
	_x_close_btn.anchor_bottom = 0.0
	_x_close_btn.offset_right = -x_inset
	_x_close_btn.offset_left = -x_inset - x_btn_size.x
	_x_close_btn.offset_top = x_inset
	_x_close_btn.offset_bottom = x_inset + x_btn_size.y
	add_child(_x_close_btn)

# `pages` must have at least one entry - callers own the content, this just
# renders whatever's handed to it.
func open(pages: Array[Dictionary]) -> void:
	if pages.is_empty():
		return
	_pages = pages
	_index = 0
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()

func _refresh() -> void:
	var page := _pages[_index]
	_page_label.text = "%d / %d" % [_index + 1, _pages.size()]
	_title_label.text = String(page.get("title", ""))
	_body_label.text = String(page.get("body", ""))
	_prev_btn.disabled = _index <= 0
	# "Next" carries you forward right up to the last page, where only
	# Close is left - no dead click on a "Next" that has nowhere to go.
	_next_btn.visible = _index < _pages.size() - 1

# Pulses whichever button actually moves the player forward right now -
# Next on every page but the last, Close once Next has hidden itself (see
# _refresh() above) - so there's always exactly one flashing button
# pointing at "what to press next", same sine-pulse shape as [pulse] BBCode
# text elsewhere (pulse_text_effect.gd) rather than a second effect system.
func _process(_delta: float) -> void:
	if not visible:
		return
	var flash := 0.35 + 0.65 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0))
	var forward_btn := _next_btn if _next_btn.visible else _close_btn
	_next_btn.modulate.a = flash if forward_btn == _next_btn else 1.0
	_close_btn.modulate.a = flash if forward_btn == _close_btn else 1.0

func _step(dir: int) -> void:
	_index = clampi(_index + dir, 0, _pages.size() - 1)
	_refresh()

func _on_close_pressed() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_close_pressed()
