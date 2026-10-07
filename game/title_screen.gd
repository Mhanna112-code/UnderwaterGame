# Title overlay over the already-built world; keeps the tree paused (process_mode ALWAYS).
# Screens: "main" (New/Load) and "slots", which serves both actions via _pending_action.
class_name TitleScreen
extends Control

const COVER_ART: Texture2D = preload("res://docs/underwater-cover.png")

signal new_game_chosen(slot: int)
signal load_game_chosen(slot: int)
signal load_latest_chosen(slot: int)
signal load_autosave_chosen(slot: int)
signal boss_playtest_chosen
signal special_playtest_chosen
signal spell_playtest_chosen
signal skip_tutorial_chosen
signal blocker_playtest_chosen

var _mode := "main"
var _pending_action := "new"   # "new" | "load"
var _load_error := ""

var _list: VBoxContainer
var _menu_panel: PanelContainer
var _menu_column: VBoxContainer
var _actions_scroll: ScrollContainer
var _boss_playtest_available := false
var _special_playtest_available := false
var _spell_playtest_available := false
var _skip_tutorial_available := false
var _blocker_playtest_available := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# Reset offsets too, or the overlay collapses to (0, 0).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Cover art as the title surface; KEEP_ASPECT_COVERED may crop but never stretches.
	var cover := TextureRect.new()
	cover.name = "CoverArt"
	cover.texture = COVER_ART
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)

	# Contrast floor for the title and buttons over the art.
	var shade := ColorRect.new()
	shade.name = "ReadabilityShade"
	shade.color = Color(0.01, 0.025, 0.055, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.name = "MenuCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	_menu_panel = panel
	panel.name = "MenuPanel"
	panel.custom_minimum_size = Vector2(424, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.045, 0.075, 0.84)
	panel_style.border_color = Color(0.35, 0.68, 0.8, 0.62)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	_menu_column = col
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.name = "GameTitle"
	title.text = "Underwater"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.14, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_actions_scroll = ScrollContainer.new()
	_actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_scroll.add_child(_list)
	col.add_child(_actions_scroll)
	get_viewport().size_changed.connect(_fit_menu)

func _fit_menu() -> void:
	if _actions_scroll == null:
		return
	var view := get_viewport().get_visible_rect().size
	var content_width := minf(360.0, maxf(180.0, view.x - 84.0))
	_menu_panel.custom_minimum_size.x = content_width + 60.0
	_menu_column.custom_minimum_size.x = content_width
	for child in _list.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = content_width
	_actions_scroll.custom_minimum_size = Vector2(content_width, minf(_list.get_combined_minimum_size().y, maxf(100.0, view.y - 155.0)))

func open() -> void:
	_load_error = ""
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mode = "main"
	_refresh()

func close() -> void:
	visible = false

func show_load_error(message: String) -> void:
	_load_error = message
	visible = true
	_mode = "main"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()

# Opt-in review routes, enabled only by query/command-line flags.
func enable_boss_playtest() -> void:
	_boss_playtest_available = true
	if visible and _mode == "main":
		_refresh()

# Review route to the guardian chooser and ability minigames.
func enable_special_playtest() -> void:
	_special_playtest_available = true
	if visible and _mode == "main":
		_refresh()

# Review route for testing spells (see World._on_title_spell_playtest()).
func enable_spell_playtest() -> void:
	_spell_playtest_available = true
	if visible and _mode == "main":
		_refresh()

# Review route: fresh game with the scripted first fight skipped.
func enable_skip_tutorial() -> void:
	_skip_tutorial_available = true
	if visible and _mode == "main":
		_refresh()

# Query-only Bomb Bot review entry.
func enable_blocker_playtest() -> void:
	_blocker_playtest_available = true
	if visible and _mode == "main":
		_refresh()

func _refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if not _load_error.is_empty():
		var error_label := Label.new()
		error_label.text = _load_error
		error_label.custom_minimum_size.x = 360
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error_label.add_theme_color_override("font_color", Color("ffce93"))
		_list.add_child(error_label)
	if _mode == "main":
		_refresh_main()
	else:
		_refresh_slots()
	_fit_menu.call_deferred()

func _refresh_main() -> void:
	var new_btn := Button.new()
	new_btn.text = "New Game"
	new_btn.custom_minimum_size = Vector2(360, 58)
	new_btn.add_theme_font_size_override("font_size", 21)
	new_btn.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	new_btn.pressed.connect(_on_new_game_pressed)
	_wire_menu_button(new_btn)
	_list.add_child(new_btn)
	new_btn.grab_focus()

	if _blocker_playtest_available:
		var blocker_btn := Button.new()
		blocker_btn.text = "Play Bomb Bot Test"
		blocker_btn.tooltip_text = "Run the authored laboratory-blocker battle"
		blocker_btn.custom_minimum_size = Vector2(360, 46)
		blocker_btn.add_theme_font_size_override("font_size", 17)
		blocker_btn.add_theme_color_override("font_color", Color(1.0, 0.68, 0.42))
		blocker_btn.pressed.connect(blocker_playtest_chosen.emit)
		_wire_menu_button(blocker_btn, &"play_ui_start_game")
		_list.add_child(blocker_btn)

	if _boss_playtest_available:
		var boss_btn := Button.new()
		boss_btn.text = "Play Tethys Boss Test"
		boss_btn.tooltip_text = "Glassgoat animation and combat validation"
		boss_btn.custom_minimum_size = Vector2(360, 46)
		boss_btn.add_theme_font_size_override("font_size", 17)
		boss_btn.add_theme_color_override("font_color", Color(1.0, 0.62, 0.62))
		boss_btn.pressed.connect(boss_playtest_chosen.emit)
		_wire_menu_button(boss_btn, &"play_ui_start_game")
		_list.add_child(boss_btn)

	if _special_playtest_available:
		var special_btn := Button.new()
		special_btn.text = "Play Special Encounter Test"
		special_btn.tooltip_text = "Choose a diver and test their ability minigame"
		special_btn.custom_minimum_size = Vector2(360, 46)
		special_btn.add_theme_font_size_override("font_size", 17)
		special_btn.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
		special_btn.pressed.connect(special_playtest_chosen.emit)
		_wire_menu_button(special_btn, &"play_ui_start_game")
		_list.add_child(special_btn)

	if _spell_playtest_available:
		var spell_btn := Button.new()
		spell_btn.text = "Play Spell Test"
		spell_btn.tooltip_text = "Every diver starts with every available spell learned and equipped; press Esc to inspect Party Spells"
		spell_btn.custom_minimum_size = Vector2(360, 46)
		spell_btn.add_theme_font_size_override("font_size", 17)
		spell_btn.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
		spell_btn.pressed.connect(spell_playtest_chosen.emit)
		_wire_menu_button(spell_btn, &"play_ui_start_game")
		_list.add_child(spell_btn)

	if _skip_tutorial_available:
		var skip_btn := Button.new()
		skip_btn.text = "New Game (Skip Tutorial)"
		skip_btn.tooltip_text = "Starts a fresh game with the scripted first fight already marked complete"
		skip_btn.custom_minimum_size = Vector2(360, 46)
		skip_btn.add_theme_font_size_override("font_size", 17)
		skip_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		skip_btn.pressed.connect(skip_tutorial_chosen.emit)
		_wire_menu_button(skip_btn, &"play_ui_start_game")
		_list.add_child(skip_btn)

	# No Load Game until a save exists.
	if not _has_any_save():
		return
	var load_btn := Button.new()
	load_btn.text = "Load Game"
	load_btn.custom_minimum_size = Vector2(360, 40)
	load_btn.add_theme_font_size_override("font_size", 16)
	load_btn.modulate = Color(0.78, 0.82, 0.85)
	load_btn.pressed.connect(_open_slots.bind("load"))
	_wire_menu_button(load_btn, &"play_ui_click")
	_list.add_child(load_btn)

func _on_new_game_pressed() -> void:
	# No saves: start in slot 0 directly; otherwise show the slot picker.
	if not _has_any_save():
		_audio_call(&"play_ui_start_game")
		new_game_chosen.emit(0)
		return
	_audio_call(&"play_ui_click")
	_open_slots("new")

func _has_any_save() -> bool:
	for slot in range(SaveManager.SLOT_COUNT):
		# Corrupt/empty files count as empty slots.
		if not SaveManager.read_slot(slot).is_empty() or not SaveManager.read_autosave(slot).is_empty():
			return true
	return false

func _open_slots(action: String) -> void:
	_pending_action = action
	_mode = "slots"
	_refresh()

# New Game: every slot pickable (occupied ones warn "overwrite"). Load Game: only occupied slots.
func _refresh_slots() -> void:
	var heading := Label.new()
	heading.text = "New Game - choose a slot" if _pending_action == "new" else "Load Game"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	_list.add_child(heading)

	for slot in range(SaveManager.SLOT_COUNT):
		var btn := Button.new()
		btn.name = "LatestSlot%d" % slot
		btn.custom_minimum_size = Vector2(360, 44)
		var data: Dictionary = SaveManager.read_slot(slot)
		if _pending_action == "load":
			var candidates := SaveManager.latest_candidates(slot)
			data = candidates[0].data if not candidates[0].data.is_empty() else candidates[1].data
		if data.is_empty():
			btn.text = "Slot %d - Empty" % (slot + 1)
			if _pending_action == "new" and not SaveManager.read_autosave(slot).is_empty():
				btn.text = "Slot %d - Overwrite previous autosave" % (slot + 1)
			btn.disabled = _pending_action == "load"
		else:
			btn.text = "Slot %d - %s%s" % [
				slot + 1, _summarize(data),
				" (overwrite)" if _pending_action == "new" else " - Latest save",
			]
		btn.pressed.connect(_on_slot_pressed.bind(slot))
		_wire_menu_button(btn, &"play_ui_start_game")
		_list.add_child(btn)
		if _pending_action == "load":
			var manual := SaveManager.read_slot(slot)
			var manual_btn := Button.new()
			manual_btn.name = "ManualSlot%d" % slot
			manual_btn.custom_minimum_size = Vector2(360, 36)
			manual_btn.text = "Slot %d Save Point - %s" % [slot + 1, "Empty" if manual.is_empty() else _summarize(manual)]
			manual_btn.disabled = manual.is_empty()
			manual_btn.pressed.connect(load_game_chosen.emit.bind(slot))
			_wire_menu_button(manual_btn, &"play_ui_start_game")
			_list.add_child(manual_btn)
			var auto_data := SaveManager.read_autosave(slot)
			var auto_btn := Button.new()
			auto_btn.name = "AutosaveSlot%d" % slot
			auto_btn.custom_minimum_size = Vector2(360, 36)
			auto_btn.text = "Slot %d Autosave - %s" % [slot + 1, "Empty" if auto_data.is_empty() else _summarize(auto_data)]
			auto_btn.disabled = auto_data.is_empty()
			auto_btn.pressed.connect(load_autosave_chosen.emit.bind(slot))
			_wire_menu_button(auto_btn, &"play_ui_start_game")
			_list.add_child(auto_btn)

	var back := Button.new()
	back.text = "< Back"
	back.custom_minimum_size = Vector2(360, 36)
	back.pressed.connect(_back_to_main)
	_wire_menu_button(back, &"play_ui_click")
	_list.add_child(back)

func _wire_menu_button(button: Button, press_sound: StringName = &"") -> void:
	button.mouse_entered.connect(_on_menu_button_hover.bind(button))
	# No white focus border on the selected button - it flashes white instead.
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.focus_entered.connect(_start_select_flash.bind(button))
	button.focus_exited.connect(_stop_select_flash.bind(button))
	if not press_sound.is_empty():
		button.pressed.connect(_audio_call.bind(press_sound))

const SELECT_FLASH_ALPHA := 0.32
const SELECT_FLASH_HALF_PERIOD := 0.45

# The selected (focused) button pulses with a white overlay.
func _start_select_flash(button: Button) -> void:
	_stop_select_flash(button)
	var flash := ColorRect.new()
	flash.name = "SelectFlash"
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(flash)
	var tw := flash.create_tween().set_loops()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # runs while paused
	tw.tween_property(flash, "color:a", SELECT_FLASH_ALPHA, SELECT_FLASH_HALF_PERIOD).set_trans(Tween.TRANS_SINE)
	tw.tween_property(flash, "color:a", 0.0, SELECT_FLASH_HALF_PERIOD).set_trans(Tween.TRANS_SINE)

func _stop_select_flash(button: Button) -> void:
	var flash := button.get_node_or_null("SelectFlash")
	if flash != null:
		button.remove_child(flash)
		flash.queue_free()

func _on_menu_button_hover(button: Button) -> void:
	if not button.disabled:
		_audio_call(&"play_ui_hover")

func _audio_call(method: StringName) -> void:
	var owner := get_node_or_null("/root/GameAudio")
	if owner != null:
		owner.call(method)

# One-line party summary; order matches World.CAST.
func _summarize(data: Dictionary) -> String:
	var divers_data: Variant = data.get("divers", [])
	if not divers_data is Array or divers_data.is_empty() or not divers_data[0] is Dictionary:
		return "?"
	var d0: Dictionary = divers_data[0]
	var stats: Variant = d0.get("stats", {})
	if not stats is Dictionary or not typeof(stats.get("level", 1)) in [TYPE_INT, TYPE_FLOAT]:
		return "?"
	return "Lv %d party" % int(stats.get("level", 1))

func _back_to_main() -> void:
	_mode = "main"
	_refresh()

func _on_slot_pressed(slot: int) -> void:
	if _pending_action == "new":
		new_game_chosen.emit(slot)
	else:
		load_latest_chosen.emit(slot)
