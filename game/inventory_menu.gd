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

var world: World
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

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# MODIFIED (changed): offset_top was 50 - the world HUD's own diver-name/
	# Match the HUD label's 12px left inset and sit shortly below its two
	# lines, leaving enough room for the controls hint without a large gap.
	# SavePointMenu uses the same offsets so both menu surfaces line up.
	root.offset_left = 12.0
	root.offset_top = 75.0
	root.offset_right = -50.0
	root.offset_bottom = -50.0
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	root.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
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

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
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
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A floor, not the actual size - size_flags_vertical above still lets it
	# grow to fill whatever's left in `root` at any given resolution. This
	# just guarantees a real reading window even if that "remaining space"
	# calculation ever comes out smaller than expected, rather than the
	# scroll view quietly shrinking to a sliver just because Items/Party
	# Spells (the other two tabs sharing this same _list/scroll) rarely have
	# enough entries to make the difference visible there.
	scroll.custom_minimum_size = Vector2(0, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(0, 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

func open() -> void:
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
	slider.custom_minimum_size = Vector2(340.0, 36.0)
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
		btn.custom_minimum_size = Vector2(340, 40)
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
func _on_replay_special_encounter_tutorial_pressed() -> void:
	if world != null:
		world._replay_special_encounter_tutorial("attack_up", "angler")

# The F1 walkthrough (world.gd's _unhandled_input(), TutorialContent.
# GENERAL_PAGES) was only ever reachable by that keybind - this gives it a
# discoverable, mouse-only way back in too, right next to the button that
# replays the scripted fight itself.
func _on_replay_tutorial_guide_pressed() -> void:
	if world != null:
		world.tutorial_book.open(TutorialContent.GENERAL_PAGES)

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
			var btn := Button.new()
			btn.text = "%s: %s%s" % [
				world._display_name((d as Diver).model_name), label,
				"" if cost <= 0.0 else " (%d O2)" % int(cost),
			]
			btn.tooltip_text = String(spell.get("description", spell.get("hint", "")))
			btn.custom_minimum_size = Vector2(340, 40)
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
	return world.divers.filter(func(d: Diver) -> bool: return d.stats.hp > 0)

func _refresh_spells_target() -> void:
	_hint.text = "Choose who this lands on."
	var back := Button.new()
	back.text = "< Back"
	back.custom_minimum_size = Vector2(340, 36)
	back.pressed.connect(_switch_to.bind("spells_root"))
	_list.add_child(back)

	for d in _valid_targets_for(_pending_spell):
		var diver := d as Diver
		var s := diver.stats
		var btn := Button.new()
		btn.text = "%s (%d / %d HP)" % [world._display_name(diver.model_name), s.hp, s.hp_max]
		btn.custom_minimum_size = Vector2(340, 40)
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
	if world != null:
		var replay_btn := Button.new()
		replay_btn.text = "Replay Tutorial Fight"
		replay_btn.custom_minimum_size = Vector2(340, 40)
		replay_btn.pressed.connect(_on_replay_tutorial_pressed)
		_list.add_child(replay_btn)
		var replay_special_btn := Button.new()
		replay_special_btn.text = "Replay Special Encounter Tutorial"
		replay_special_btn.custom_minimum_size = Vector2(340, 40)
		replay_special_btn.pressed.connect(_on_replay_special_encounter_tutorial_pressed)
		_list.add_child(replay_special_btn)
		var replay_guide_btn := Button.new()
		replay_guide_btn.text = "Reopen Tutorial Guide"
		replay_guide_btn.custom_minimum_size = Vector2(340, 40)
		replay_guide_btn.pressed.connect(_on_replay_tutorial_guide_pressed)
		_list.add_child(replay_guide_btn)
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
