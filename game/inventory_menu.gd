# Escape-key pause menu: Items, Party Spells, Combat Help (reference + tutorial replays), Audio.
# Item and party-spell effects resolve only via World.use_inventory_item()/use_party_spell().
# Built in code in _ready() and rebuilt on refresh, like SpellTreeUI/SavePointMenu.
class_name InventoryMenu
extends Control

# World or MazeLevel: both expose the party/inventory operations used below.
# Tutorial replay actions are offered only when the owning scene supports them.
var world: Node
var audio_manager: Node

# "items" | "spells_root" | "spells_target"; Back from spells_target returns to spells_root.
var _mode := "items"
var _pending_spell: Dictionary = {}
var _pending_caster: Diver = null

var _hint: Label
var _list: VBoxContainer
var _items_tab: Button
var _spells_tab: Button
var _help_tab: Button
var _audio_tab: Button
var _title_tab: Button
var _confirm_title: Control
var _content: VBoxContainer
var _scroll: ScrollContainer
var _shade: TextureRect
var _header_rule: ColorRect

func _ready() -> void:
	visible = false
	# Reset anchors and offsets together; anchor-only sizing can leave a zero-size hit/backdrop rect.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0.0, 0.02, 0.04, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Marc's dimmed world and left-to-right shade, kept within the viewport.
	_shade = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.01, 0.04, 0.07, 0.9))
	grad.set_color(1, Color(0.01, 0.04, 0.07, 0.0))
	grad.add_point(0.45, Color(0.01, 0.04, 0.07, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2.ZERO
	tex.fill_to = Vector2.RIGHT
	_shade.texture = tex
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)

	var root := VBoxContainer.new()
	_content = root
	root.name = "MenuContent"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Match the HUD label's 12px inset; SavePointMenu uses the same offsets.
	root.offset_left = 12.0
	root.offset_top = 75.0
	root.offset_right = -12.0
	root.offset_bottom = -12.0
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	root.add_child(header)
	var paused := Label.new()
	paused.text = "PAUSED  ·  Esc to resume"
	paused.add_theme_font_size_override("font_size", 14)
	paused.add_theme_color_override("font_color", Color(0.55, 0.8, 0.95))
	header.add_child(paused)
	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	header.add_child(title)
	_header_rule = ColorRect.new()
	_header_rule.color = Color(0.45, 0.75, 0.95, 0.6)
	_header_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(_header_rule)

	# Four campaign tabs, not Marc's three-tab baseline. Wrap rather than
	# dropping Audio or extending hit targets beyond a narrow browser screen.
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 10)
	tabs.add_theme_constant_override("v_separation", 8)
	root.add_child(tabs)
	_items_tab = Button.new()
	_items_tab.text = "Items"
	_items_tab.toggle_mode = true
	_items_tab.pressed.connect(_switch_to.bind("items"))
	tabs.add_child(_items_tab)
	_spells_tab = Button.new()
	_spells_tab.text = "Party Spells"
	_spells_tab.toggle_mode = true
	_spells_tab.pressed.connect(_switch_to.bind("spells_root"))
	tabs.add_child(_spells_tab)
	_help_tab = Button.new()
	_help_tab.text = "Combat Help"
	_help_tab.toggle_mode = true
	_help_tab.pressed.connect(_switch_to.bind("help"))
	tabs.add_child(_help_tab)
	_audio_tab = Button.new()
	_audio_tab.name = "AudioTab"
	_audio_tab.text = "Audio"
	_audio_tab.toggle_mode = true
	_audio_tab.pressed.connect(_switch_to.bind("audio"))
	tabs.add_child(_audio_tab)
	_title_tab = Button.new()
	_title_tab.name = "TitleTab"
	_title_tab.text = "Main Menu"
	_title_tab.toggle_mode = true
	_title_tab.pressed.connect(_switch_to.bind("title"))
	tabs.add_child(_title_tab)
	for tab in [_items_tab, _spells_tab, _help_tab, _audio_tab, _title_tab]:
		_style_tab(tab)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.add_theme_color_override("font_color", Color(0.72, 0.82, 0.88))
	root.add_child(_hint)

	# Scrolls so the tall Combat Help content stays reachable.
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.name = "ContentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Minimum reading height; EXPAND_FILL owns the remaining space.
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(0, 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	resized.connect(_sync_layout)
	_sync_layout()

func _sync_layout() -> void:
	if not is_instance_valid(_content):
		return
	_content.offset_top = 20.0 if size.y < 600.0 else 75.0
	_content.add_theme_constant_override("separation", 10 if size.y < 600.0 else 18)
	_scroll.custom_minimum_size = Vector2(0, clampf(size.y * 0.27, 100.0, 240.0))
	_shade.offset_right = minf(760.0, size.x)
	_header_rule.custom_minimum_size = Vector2(minf(320.0, maxf(0.0, size.x - 24.0)), 2.0)

# Marc's selected cyan tile; all four tabs share the same accessible states.
func _style_tab(tab: Button) -> void:
	tab.add_theme_font_size_override("font_size", 17)
	var states := {
		"normal": [Color(0.1, 0.17, 0.22, 0.95), Color(0.3, 0.45, 0.55)],
		"hover": [Color(0.16, 0.26, 0.33, 0.95), Color(0.55, 0.8, 0.95)],
		"pressed": [Color(0.45, 0.78, 0.95), Color(0.75, 0.92, 1.0)],
		"hover_pressed": [Color(0.55, 0.85, 1.0), Color(0.85, 0.96, 1.0)],
		"focus": [Color(0, 0, 0, 0), Color(0.75, 0.92, 1.0)],
	}
	for state in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[state][0]
		sb.border_color = states[state][1]
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		sb.draw_center = state != "focus"
		tab.add_theme_stylebox_override(state, sb)
	tab.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	tab.add_theme_color_override("font_hover_color", Color.WHITE)
	tab.add_theme_color_override("font_pressed_color", Color(0.02, 0.07, 0.1))
	tab.add_theme_color_override("font_hover_pressed_color", Color(0.02, 0.07, 0.1))

# Opening this pauses the SceneTree; this menu keeps processing and handles Esc to close.
var _paused_tree := false
var _was_tree_paused := false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and _paused_tree:
		get_viewport().set_input_as_handled()
		if is_instance_valid(_confirm_title):
			_cancel_return_to_title()   # Esc backs out of the Yes/No first
		else:
			close()

func open() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _paused_tree and is_inside_tree():
		_was_tree_paused = get_tree().paused
		get_tree().paused = true
		_paused_tree = true
	# Draw over World's HP/O2 bars, which are created after this menu.
	move_to_front()
	visible = true
	_refresh_world_overlays()
	_switch_to("items")

func close() -> void:
	_cancel_return_to_title()
	visible = false
	if _paused_tree and is_inside_tree():
		get_tree().paused = _was_tree_paused
	_paused_tree = false
	_refresh_world_overlays()

# World normally updates these every frame; it's paused while this is open.
func _refresh_world_overlays() -> void:
	if world != null and is_instance_valid(world) and world.has_method("_update_maze_route_guide"):
		world.call("_update_maze_route_guide")

func _switch_to(mode: String) -> void:
	_mode = mode
	if mode == "items":
		_pending_spell = {}
		_pending_caster = null
	_items_tab.button_pressed = mode == "items"
	_spells_tab.button_pressed = mode in ["spells_root", "spells_target"]
	_help_tab.button_pressed = mode == "help"
	_audio_tab.button_pressed = mode == "audio"
	_title_tab.button_pressed = mode == "title"
	refresh()

func refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	match _mode:
		"items":
			_refresh_items()
		"spells_root":
			_refresh_spells_root()
		"spells_target":
			_refresh_spells_target()
		"help":
			_refresh_help()
		"audio":
			_refresh_audio()
		"title":
			_refresh_title()

func _refresh_audio() -> void:
	_hint.text = "Set music and sound effect levels. Changes are saved automatically."
	var audio := _audio_owner()
	if audio == null:
		var unavailable := Label.new()
		unavailable.text = "Audio settings are unavailable."
		unavailable.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		_list.add_child(unavailable)
		return
	var settings: Dictionary = audio.call("get_audio_settings")
	_add_audio_channel(
		"Music",
		"MusicVolumeSlider",
		"MusicMuteToggle",
		float(settings.get("music_volume", 1.0)),
		bool(settings.get("music_muted", false)),
		"music"
	)
	_add_audio_channel(
		"Sound effects",
		"SFXVolumeSlider",
		"SFXMuteToggle",
		float(settings.get("sfx_volume", 1.0)),
		bool(settings.get("sfx_muted", false)),
		"sfx"
	)

func _add_audio_channel(
	label_text: String,
	slider_name: String,
	mute_name: String,
	volume: float,
	muted: bool,
	channel: String
) -> void:
	var heading := Label.new()
	heading.text = label_text
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_list.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_list.add_child(row)
	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = clampf(volume, 0.0, 1.0) * 100.0
	slider.custom_minimum_size = Vector2(120.0, 36.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "%s level" % label_text
	row.add_child(slider)
	var value_label := Label.new()
	value_label.name = "%sValue" % slider_name
	value_label.text = "%d%%" % int(round(slider.value))
	value_label.custom_minimum_size = Vector2(56.0, 36.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	slider.value_changed.connect(_on_audio_volume_changed.bind(channel, value_label))

	var mute := CheckButton.new()
	mute.name = mute_name
	mute.text = "Mute %s" % label_text.to_lower()
	mute.button_pressed = muted
	mute.custom_minimum_size = Vector2(180.0, 40.0)
	mute.toggled.connect(_on_audio_mute_toggled.bind(channel))
	_list.add_child(mute)

func _on_audio_volume_changed(value: float, channel: String, value_label: Label) -> void:
	value_label.text = "%d%%" % int(round(value))
	var audio := _audio_owner()
	if audio == null:
		return
	if channel == "music":
		audio.call("set_music_volume", value / 100.0)
	else:
		audio.call("set_sfx_volume", value / 100.0)
	audio.call("save_audio_settings")

func _on_audio_mute_toggled(muted: bool, channel: String) -> void:
	var audio := _audio_owner()
	if audio == null:
		return
	if channel == "music":
		audio.call("set_music_muted", muted)
	else:
		audio.call("set_sfx_muted", muted)
	audio.call("save_audio_settings")

func _audio_owner() -> Node:
	if is_instance_valid(audio_manager):
		return audio_manager
	return get_node_or_null("/root/GameAudio")

func _refresh_items() -> void:
	_hint.text = "Use any available items on any party members."
	if world == null or world.inventory.is_empty():
		var empty := Label.new()
		empty.text = "No items yet"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_list.add_child(empty)
		return

	for item_id in world.inventory.keys():
		var count: int = int(world.inventory[item_id])
		if count <= 0:
			continue
		var def: Dictionary = Items.ITEMS.get(item_id, {})
		# Same word-wrapped blue-bordered tooltip panel as the battle menu.
		var btn := TooltipButton.new()
		btn.text = String(def.get("display", item_id))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = String(def.get("description", ""))
		if bool(def.get("battle_only", false)):
			btn.tooltip_text = "This item can only be used in battle. " + btn.tooltip_text
		btn.custom_minimum_size = Vector2(0, 40)
		# Visible background so the count tile reads as part of the same row.
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.03, 0.09, 0.12)
		btn_style.border_color = Color(0.18, 0.34, 0.4)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn_style.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("disabled", btn_style)
		# Disabled rather than hidden when it wouldn't help the steered diver.
		if not world.divers.is_empty():
			# Battle-only items are greyed out; this menu only opens outside battle.
			btn.disabled = bool(def.get("battle_only", false)) \
				or not Items.would_help(item_id, (world.divers[world.active] as Diver).stats)
		btn.pressed.connect(_on_use_item_pressed.bind(item_id))
		# Count tile pinned to the button's right edge, vertically centered.
		var count_tile := PanelContainer.new()
		count_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tile_style := StyleBoxFlat.new()
		tile_style.bg_color = Color(0.0, 0.0, 0.0, 0.85)
		tile_style.set_corner_radius_all(4)
		tile_style.set_content_margin_all(2)
		count_tile.add_theme_stylebox_override("panel", tile_style)
		count_tile.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		count_tile.offset_left = -32
		count_tile.offset_right = -8
		count_tile.offset_top = -12
		count_tile.offset_bottom = 12
		btn.add_child(count_tile)

		var count_label := Label.new()
		count_label.text = str(count)
		count_label.add_theme_font_size_override("font_size", 16)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_tile.add_child(count_label)

		_list.add_child(btn)

func _on_use_item_pressed(item_id: String) -> void:
	if world == null:
		return
	world.use_inventory_item(item_id)
	refresh()

# _start_battle() closes this menu itself.
func _on_replay_tutorial_pressed() -> void:
	var w := _help_world()
	if w != null:
		close()
		w.call("_replay_tutorial_battle")

# Replays the Maxilani special-encounter lesson; never grants the guarded item.
func _on_character_abilities_pressed() -> void:
	close()
	var w := _help_world()
	if w != null:
		w.call("_show_ability_popups")

func _on_saving_help_pressed() -> void:
	close()
	var pages: Array[Dictionary] = [TutorialContent.saving_page()]
	(get_node("/root/CharacterAbilityPopup") as Node).call("open", pages)

# --- Main Menu tab: back to the title screen, after a Yes/No confirmation ---
func _refresh_title() -> void:
	_hint.text = "Leave this game and go back to the title screen. Game will autosave first."
	var btn := Button.new()
	btn.name = "ReturnToTitle"
	btn.text = "Return To Title Screen"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(_ask_return_to_title)
	_list.add_child(btn)

func _ask_return_to_title() -> void:
	if is_instance_valid(_confirm_title):
		return
	var shade := ColorRect.new()
	shade.name = "ReturnToTitleConfirm"
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_confirm_title = shade
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.1)
	style.border_color = Color(0.3, 0.6, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var question := Label.new()
	question.name = "Question"
	question.text = "Are you sure you would like to return to title screen? Game will autosave first."
	question.add_theme_font_size_override("font_size", 18)
	question.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	col.add_child(question)
	# Shown in place of the buttons while the autosave runs.
	var status := Label.new()
	status.name = "SaveStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	status.visible = false
	col.add_child(status)
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var yes := Button.new()
	yes.name = "Yes"
	yes.text = "Yes"
	yes.custom_minimum_size = Vector2(110, 40)
	yes.pressed.connect(_confirm_return_to_title)
	row.add_child(yes)
	var no := Button.new()
	no.name = "No"
	no.text = "No"
	no.custom_minimum_size = Vector2(110, 40)
	no.pressed.connect(_cancel_return_to_title)
	row.add_child(no)
	no.grab_focus()

func _cancel_return_to_title() -> void:
	if _title_saving:
		return   # can't back out mid-save
	if is_instance_valid(_confirm_title):
		_confirm_title.queue_free()
	_confirm_title = null

var _title_saving := false
const TITLE_SAVE_MIN_SECONDS := 0.8   # keep "Autosaving..." readable even when the write is instant

# Yes: autosave first (indicator in the modal), then go to the title. If the save
# fails, ask before leaving anyway (skip_save = that second Yes).
func _confirm_return_to_title(skip_save := false) -> void:
	if _title_saving or not is_instance_valid(_confirm_title):
		return
	if not skip_save and world != null and world.has_method("autosave_now"):
		var row := _confirm_title.find_child("Buttons", true, false) as Control
		var status := _confirm_title.find_child("SaveStatus", true, false) as Label
		var question := _confirm_title.find_child("Question", true, false) as Label
		_title_saving = true
		row.visible = false
		status.text = "Autosaving..."
		status.visible = true
		var pulse := status.create_tween().set_loops()
		pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # the tree is paused under this menu
		pulse.tween_property(status, "modulate:a", 0.35, 0.4)
		pulse.tween_property(status, "modulate:a", 1.0, 0.4)
		var started := Time.get_ticks_msec()
		var error: Error = await world.call("autosave_now")
		var remaining := TITLE_SAVE_MIN_SECONDS - (Time.get_ticks_msec() - started) / 1000.0
		if remaining > 0.0:
			await get_tree().create_timer(remaining).timeout
		pulse.kill()
		status.modulate.a = 1.0
		_title_saving = false
		if error != OK and error != ERR_UNCONFIGURED:
			status.text = "Autosave failed."
			question.text = "Autosave failed. Return to title screen anyway?"
			var yes := row.find_child("Yes", false, false) as Button
			for connection in yes.pressed.get_connections():
				yes.pressed.disconnect(connection.callable)
			yes.pressed.connect(_confirm_return_to_title.bind(true))
			row.visible = true
			return
		if error == OK:
			status.text = "Saved."
	_cancel_return_to_title()
	close()
	get_tree().paused = false
	if world != null and world.has_method("return_to_title"):
		world.call("return_to_title")
	else:
		# Standalone maze scene: the title screen lives in the World scene.
		get_tree().change_scene_to_file("res://game/world.tscn")

func _on_replay_special_encounter_tutorial_pressed() -> void:
	var w := _help_world()
	if w != null:
		close()
		w.call("_replay_special_encounter_tutorial", "attack_up", "angler")

# One button per living diver x inventory spell; disabled when unaffordable.
func _refresh_spells_root() -> void:
	_hint.text = "Party members' known spells"
	if world == null:
		return
	var any := false
	for d in world.divers:
		for spell in world._inventory_spells_for(d as Diver):
			any = true
			var label: String = String(spell.get("display", spell.get("name", "")))
			var cost: float = float(spell.get("oxygen_cost", 0.0))
			# Same word-wrapped tooltip panel the battle menu uses.
			var btn := TooltipButton.new()
			btn.text = "%s: %s%s" % [
				world._display_name((d as Diver).model_name), label,
				" (downed)" if (d as Diver).stats.hp <= 0 else "",
			]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if cost > 0.0:
				# Same blue "16O2" badge as the battle move menu.
				var plate := PanelContainer.new()
				plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var plate_style := StyleBoxFlat.new()
				plate_style.bg_color = Color(0.05, 0.08, 0.1, 0.85)
				plate_style.set_corner_radius_all(4)
				plate_style.content_margin_left = 4
				plate_style.content_margin_right = 4
				plate.add_theme_stylebox_override("panel", plate_style)
				plate.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
				plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
				plate.grow_vertical = Control.GROW_DIRECTION_BOTH
				plate.offset_right = -8
				plate.offset_left = -8
				btn.add_child(plate)
				var badge := Label.new()
				badge.text = "%dO2" % int(cost)
				badge.add_theme_font_size_override("font_size", 14)
				badge.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				plate.add_child(badge)
			btn.tooltip_text = String(spell.get("description", spell.get("hint", "")))
			btn.custom_minimum_size = Vector2(0, 40)
			btn.disabled = not world.can_afford_party_spell(spell, d as Diver)
			btn.pressed.connect(_on_spell_chosen.bind(spell, d as Diver))
			_list.add_child(btn)
	if not any:
		var empty := Label.new()
		empty.text = "No party spells known yet."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_list.add_child(empty)

func _on_spell_chosen(spell: Dictionary, caster: Diver) -> void:
	_pending_spell = spell
	_pending_caster = caster
	_mode = "spells_target"
	refresh()

# "heal" targets the living; "revive" only the downed.
func _valid_targets_for(spell: Dictionary) -> Array:
	if world == null:
		return []
	var effect := String(spell.get("effect", ""))
	if effect == "revive":
		return world.divers.filter(func(d: Diver) -> bool: return d.stats.hp <= 0)
	# Heals: living and not already at full health.
	return world.divers.filter(func(d: Diver) -> bool: return d.stats.hp > 0 and d.stats.hp < d.stats.hp_max)

func _refresh_spells_target() -> void:
	_hint.text = "Choose who this lands on."
	var back := Button.new()
	back.text = "< Back"
	back.custom_minimum_size = Vector2(0, 36)
	back.pressed.connect(_switch_to.bind("spells_root"))
	_list.add_child(back)

	for d in _valid_targets_for(_pending_spell):
		var diver := d as Diver
		var s := diver.stats
		var btn := Button.new()
		btn.text = "%s (%d / %d HP)" % [world._display_name(diver.model_name), s.hp, s.hp_max]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_target_chosen.bind(diver))
		_list.add_child(btn)

func _on_target_chosen(target: Diver) -> void:
	if world == null or _pending_caster == null:
		return
	world.use_party_spell(_pending_spell, _pending_caster, target)
	_mode = "spells_root"
	refresh()

# Reference text only; entries come from TutorialContent tables.
# Combat Help's lessons live on World. In the maze this menu's `world` is the
# MazeLevel, so use the World it's embedded in.
func _help_world() -> Node:
	if world is World:
		return world
	if world != null and world.get("world") is World:
		return world.get("world")
	return null

func _refresh_help() -> void:
	_hint.text = "Stats, effects, and status conditions"
	var w := _help_world()
	if w != null:
		var replay_btn := Button.new()
		replay_btn.text = "Replay Tutorial Fight"
		replay_btn.custom_minimum_size = Vector2(0, 40)
		replay_btn.pressed.connect(_on_replay_tutorial_pressed)
		_list.add_child(replay_btn)
		if bool(w.get("ability_popups_seen")):
			var abilities_btn := Button.new()
			abilities_btn.text = "Character Abilities"
			abilities_btn.custom_minimum_size = Vector2(0, 40)
			abilities_btn.pressed.connect(_on_character_abilities_pressed)
			_list.add_child(abilities_btn)
		if bool(w.get("special_encounter_left")):
			var replay_special_btn := Button.new()
			replay_special_btn.text = "Replay Special Encounter Tutorial"
			replay_special_btn.custom_minimum_size = Vector2(0, 40)
			replay_special_btn.pressed.connect(_on_replay_special_encounter_tutorial_pressed)
			_list.add_child(replay_special_btn)
		# The Saving lesson, once it has been shown at a save point.
		if bool(w.get("_save_point_tutorial_seen")):
			var saving_btn := Button.new()
			saving_btn.text = "Saving"
			saving_btn.custom_minimum_size = Vector2(0, 40)
			saving_btn.pressed.connect(_on_saving_help_pressed)
			_list.add_child(saving_btn)
	_add_help_section("Stats", TutorialContent.STAT_GLOSSARY)
	var effect_entries: Array[Dictionary] = []
	for kind in TutorialContent.EFFECT_KIND_EXPLANATIONS:
		effect_entries.append(TutorialContent.EFFECT_KIND_EXPLANATIONS[kind] as Dictionary)
	_add_help_section("Effects", effect_entries)
	_add_help_section("Status Conditions", TutorialContent.STATUS_CONDITIONS)

func _add_help_section(heading: String, entries: Array[Dictionary]) -> void:
	# Gap above each section so Stats / Effects / Status Conditions read apart.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	_list.add_child(gap)
	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.add_theme_font_size_override("font_size", 15)
	heading_label.add_theme_color_override("font_color", Color(0.5, 0.65, 0.7))
	_list.add_child(heading_label)
	for entry in entries:
		var title := Label.new()
		title.text = String(entry.get("title", ""))
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		_list.add_child(title)
		var body := Label.new()
		body.text = String(entry.get("body", ""))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_color_override("font_color", Color(0.8, 0.88, 0.9))
		_list.add_child(body)
