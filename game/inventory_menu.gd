# The Escape-key pause menu - four tabs. "Items" (potions and anything else
# Items.ITEMS defines as a consumable) applies straight to whoever you're
# currently steering, same as before. "Party Spells" is any known move/
# spell tagged "inventory": true (see battle.gd's BASE_MOVES/spell_tree.gd's
# own header comments) - Maxilani's free base Heal, plus any learned "heal"/
# "revive" spell, castable by ANY party member on ANY party member, not
# just whoever's currently active. Items don't apply themselves the instant
# they're picked up anymore - an orb/guardian reward just adds to
# World.inventory now (see world.gd's _on_item_orb_collected()/
# _grant_reward_item()), and World.use_inventory_item()/use_party_spell()
# (called from here) are the only places those effects actually resolve.
# "Combat Help" is mostly pure reference - a Stats glossary (content/
# tutorial_content.gd's STAT_GLOSSARY), an Effects section (TutorialContent.
# EFFECT_KIND_EXPLANATIONS - "Self Cost"/"Evasion Reduction", the parts of a
# move that aren't a CombatantStats status), and status condition writeups
# (STATUS_CONDITIONS) for whoever wants the full Blindness/Stun/Flash-Blast-
# self-cost numbers again outside of a fight. Three real action buttons sit
# above all of that: replaying the scripted first fight, replaying the
# special-encounter tutorial, and reopening the paged walkthrough
# (World.tutorial_book, TutorialContent.GENERAL_PAGES), previously only
# reachable via the F1 keybind.
#
# Same build-once-in-_ready()/rebuild-on-refresh shape as SpellTreeUI/
# SavePointMenu - nothing here is scene-file based, on purpose,
# matching the rest of this project. "Audio" is the player-facing surface for
# the global Music/SFX bus levels and mute state owned by GameAudio.
class_name InventoryMenu
extends Control

# World or MazeLevel: both expose the party/inventory operations used below.
# Tutorial replay actions are offered only when the owning scene supports them.
var world: Node
var audio_manager: Node

# "items" | "spells_root" | "spells_target" - spells_root lists every
# living diver's inventory-tagged spells (one button per caster+spell
# pair); spells_target only shows once a spell's been picked, listing who
# it can land on (see _valid_targets_for()). Back from spells_target
# returns to spells_root, not to the Items tab - same "back one step, not
# all the way out" shape battle.gd's own move/target menus already use.
var _mode := "items"
var _pending_spell: Dictionary = {}
var _pending_caster: Diver = null

var _hint: Label
var _list: VBoxContainer
var _items_tab: Button
var _spells_tab: Button
var _help_tab: Button
var _audio_tab: Button
var _content: VBoxContainer
var _scroll: ScrollContainer
var _shade: TextureRect
var _header_rule: ColorRect

func _ready() -> void:
	visible = false
	# Runtime Controls begin with zero-sized offsets. Reset anchors and offsets
	# together so the menu actually owns the viewport under a CanvasLayer at
	# every browser size; anchor-only sizing can leave a zero-width hit/backdrop
	# rectangle even though descendants happen to draw outside it.
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
	# MODIFIED (changed): offset_top was 50 - the world HUD's own diver-name/
	# Match the HUD label's 12px left inset and sit shortly below its two
	# lines, leaving enough room for the controls hint without a large gap.
	# SavePointMenu uses the same offsets so both menu surfaces line up.
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
	_spells_tab.text = "Party members' known spells"
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
	for tab in [_items_tab, _spells_tab, _help_tab, _audio_tab]:
		_style_tab(tab)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.add_theme_color_override("font_color", Color(0.72, 0.82, 0.88))
	root.add_child(_hint)

	# ScrollContainer, not _list added straight to root - Combat Help's own
	# content (Stats + Effects + Status Conditions + the Replay Tutorial
	# Fight button) is tall enough to run past the bottom of the screen with
	# nothing to scroll it into view, unlike Items/Party Spells which rarely
	# have enough entries to hit this. size_flags_vertical on the scroll
	# view (not _list itself) is what gives it a bounded height to actually
	# scroll within, rather than just growing to fit its content like any
	# other container would.
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.name = "ContentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A floor, not the actual size - size_flags_vertical above still lets it
	# grow to fill whatever's left in `root` at any given resolution. This
	# just guarantees a real reading window even if that "remaining space"
	# calculation ever comes out smaller than expected, rather than the
	# scroll view quietly shrinking to a sliver just because Items/Party
	# Spells (the other two tabs sharing this same _list/scroll) rarely have
	# enough entries to make the difference visible there.
	# Keep a useful reading window without forcing the VBox below the viewport
	# at 720px or narrow/mobile heights. EXPAND_FILL owns the remaining space.
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

func open() -> void:
	# World creates its HP/O2 bars after this menu. Paint the modal over those
	# siblings as well, not just over the 3D world; otherwise bars cover Help
	# text and Audio controls even when all rectangles pass layout checks.
	move_to_front()
	visible = true
	_switch_to("items")

func close() -> void:
	visible = false

func _switch_to(mode: String) -> void:
	_mode = mode
	if mode == "items":
		_pending_spell = {}
		_pending_caster = null
	_items_tab.button_pressed = mode == "items"
	_spells_tab.button_pressed = mode in ["spells_root", "spells_target"]
	_help_tab.button_pressed = mode == "help"
	_audio_tab.button_pressed = mode == "audio"
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
	_hint.text = "Using an item applies it to whoever you're currently steering."
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
		var btn := Button.new()
		# MODIFIED (changed): was "Use %s (x%d)" as the button's own text -
		# the count now lives in its own tile at the button's right edge
		# instead (see the plate/badge built below, same "opaque plate
		# behind a number" convention battle.gd's _add_power_badge() uses
		# for a move's power badge), so the button's text is just the
		# item's name, left-aligned so it doesn't visually crowd the tile.
		btn.text = String(def.get("display", item_id))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = String(def.get("description", ""))
		btn.custom_minimum_size = Vector2(0, 40)
		# MODIFIED (fixed): the count tile is correctly anchored inside this
		# button's own rect (8px in from its true right edge), but Godot's
		# default Button theme has no visible background in its normal
		# (non-hover) state - against this menu's own dark panel background,
		# that made the button read as invisible, so the tile looked like it
		# was floating disconnected in empty space past "Potion" rather than
		# sitting inside the same row. A real background/border ties them
		# together as one visible row, same dark-bordered-panel look used
		# elsewhere in this game (e.g. battle.gd's swap demo frame).
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.03, 0.09, 0.12)
		btn_style.border_color = Color(0.18, 0.34, 0.4)
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(4)
		btn_style.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("disabled", btn_style)
		# Disabled rather than hidden when it wouldn't help the currently
		# steered diver right now (full HP for a potion, full oxygen for a
		# cell, etc.) - same "show what you can't use yet" convention
		# spell_tree_ui.gd/the Party Spells tab already use, so the item
		# doesn't just vanish from the list, and world.use_inventory_item()
		# refuses the same way if this were ever somehow clicked anyway.
		if not world.divers.is_empty():
			btn.disabled = not Items.would_help(item_id, (world.divers[world.active] as Diver).stats)
		btn.pressed.connect(_on_use_item_pressed.bind(item_id))
		# A black tile pinned to the button's own right edge, vertically
		# centered - same "opaque plate behind a number" idea as battle.gd's
		# _add_power_badge() (a move's power badge), just centered on this
		# button's right edge instead of its top-right corner, since this
		# button is a wide horizontal bar rather than a small square tile.
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

# _start_battle() (called via _replay_tutorial_battle()) closes this menu
# itself, same as starting any other fight - nothing extra needed here.
func _on_replay_tutorial_pressed() -> void:
	if world != null:
		world._replay_tutorial_battle()

# Replay the first special-encounter lesson from Combat Help without needing
# to discover a sonar site first. This is the Maxilani practice encounter;
# its tutorial path never grants the guarded item.
func _on_character_abilities_pressed() -> void:
	close()
	world._show_ability_popups()

func _on_replay_special_encounter_tutorial_pressed() -> void:
	if world != null:
		world._replay_special_encounter_tutorial("attack_up", "angler")

# One button per living diver x their inventory-tagged spells (see
# World._inventory_spells_for()) - disabled rather than hidden when that
# diver can't currently afford it, same "show what you can't afford yet"
# convention spell_tree_ui.gd already uses, so a low-oxygen diver's spells
# don't just silently vanish from the list.
func _refresh_spells_root() -> void:
	_hint.text = "Any party member's known heal/revive spells - pick who casts, then who it lands on."
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

# "heal" lands on anyone still standing (self included); "revive" only on
# whoever's actually down - same target-pool split battle.gd's
# _on_move_chosen() already draws between the two effects.
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

# Plain reference text, no buttons - one section heading plus a title/body
# Label pair per entry, so a new stat/effect/status only ever needs adding
# to its own TutorialContent table, not here too.
func _refresh_help() -> void:
	_hint.text = "Stats, effects, and status conditions"
	if world != null and world.has_method("_replay_tutorial_battle"):
		var replay_btn := Button.new()
		replay_btn.text = "Replay Tutorial Fight"
		replay_btn.custom_minimum_size = Vector2(0, 40)
		replay_btn.pressed.connect(_on_replay_tutorial_pressed)
		_list.add_child(replay_btn)
	if world != null and world.has_method("_show_ability_popups") and bool(world.get("ability_popups_seen")):
		var abilities_btn := Button.new()
		abilities_btn.text = "Character Abilities"
		abilities_btn.custom_minimum_size = Vector2(0, 40)
		abilities_btn.pressed.connect(_on_character_abilities_pressed)
		_list.add_child(abilities_btn)
	# Only once the party has left a special encounter in any way.
	if world != null and world.has_method("_replay_special_encounter_tutorial") and bool(world.get("special_encounter_left")):
		var replay_special_btn := Button.new()
		replay_special_btn.text = "Replay Special Encounter Tutorial"
		replay_special_btn.custom_minimum_size = Vector2(0, 40)
		replay_special_btn.pressed.connect(_on_replay_special_encounter_tutorial_pressed)
		_list.add_child(replay_special_btn)
	_add_help_section("Stats", TutorialContent.STAT_GLOSSARY)
	var effect_entries: Array[Dictionary] = []
	for kind in TutorialContent.EFFECT_KIND_EXPLANATIONS:
		effect_entries.append(TutorialContent.EFFECT_KIND_EXPLANATIONS[kind] as Dictionary)
	_add_help_section("Effects", effect_entries)
	_add_help_section("Status Conditions", TutorialContent.STATUS_CONDITIONS)

func _add_help_section(heading: String, entries: Array[Dictionary]) -> void:
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
