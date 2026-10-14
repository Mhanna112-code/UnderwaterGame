# Read-only combat reference. Owns its pause/focus, never a combat action.
class_name CombatReference
extends Control

var _panel: PanelContainer
var _close_button: Button
var _opened := false
var _prior_pause := false
var _prior_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _prior_focus: WeakRef

func _ready() -> void:
	name = "CombatReference"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.05, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.08, 0.11)
	style.border_color = Color(0.3, 0.65, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "Combat Help"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Combat is paused while you read."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.6, 0.8, 0.85))
	column.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.name = "ReferenceScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 8)
	scroll.add_child(entries)
	_add_section(entries, "Stats", TutorialContent.STAT_GLOSSARY)
	var effects: Array[Dictionary] = []
	for effect in TutorialContent.EFFECT_KIND_EXPLANATIONS.values():
		effects.append(effect as Dictionary)
	_add_section(entries, "Effects", effects)
	_add_section(entries, "Status Conditions", TutorialContent.STATUS_CONDITIONS)
	_close_button = Button.new()
	_close_button.name = "CloseReference"
	_close_button.text = "Back to Battle (Esc)"
	_close_button.custom_minimum_size = Vector2(0, 44)
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	resized.connect(_sync_layout)
	# Wrapping is measured after the first layout; discard a stale minimum
	# from the tiny construction viewport instead of leaving Close offscreen.
	_panel.minimum_size_changed.connect(func() -> void: _sync_layout.call_deferred())
	get_viewport().size_changed.connect(_sync_layout)
	_sync_layout()

func _add_section(column: VBoxContainer, heading: String, entries: Array[Dictionary]) -> void:
	var section := Label.new()
	section.text = heading
	section.add_theme_font_size_override("font_size", 20)
	section.add_theme_color_override("font_color", Color(0.5, 0.85, 0.95))
	column.add_child(section)
	for entry in entries:
		var title := Label.new()
		title.text = String(entry.get("title", ""))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 18)
		column.add_child(title)
		var body := Label.new()
		body.text = String(entry.get("body", ""))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 16)
		body.add_theme_color_override("font_color", Color(0.8, 0.9, 0.94))
		column.add_child(body)

func _sync_layout() -> void:
	if _panel == null:
		return
	var available := get_viewport_rect().size
	_panel.size = Vector2(minf(700.0, maxf(0, available.x - 24)), minf(640.0, maxf(0, available.y - 24)))
	_panel.position = (available - _panel.size) * 0.5

func open() -> void:
	if _opened:
		return
	_prior_pause = get_tree().paused
	_prior_mouse_mode = Input.mouse_mode
	var focus := get_viewport().gui_get_focus_owner()
	_prior_focus = weakref(focus) if focus != null else null
	_opened = true
	visible = true
	move_to_front()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sync_layout()
	_close_button.grab_focus()

func close() -> void:
	if not _opened:
		return
	visible = false
	_opened = false
	get_tree().paused = _prior_pause
	Input.mouse_mode = _prior_mouse_mode
	var focus := _prior_focus.get_ref() as Control if _prior_focus != null else null
	if is_instance_valid(focus) and focus.is_visible_in_tree():
		focus.grab_focus()
	_prior_focus = null

func _input(event: InputEvent) -> void:
	if not _opened:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func _exit_tree() -> void:
	if _opened:
		get_tree().paused = _prior_pause
		Input.mouse_mode = _prior_mouse_mode
