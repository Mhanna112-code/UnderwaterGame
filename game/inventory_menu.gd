# The Escape-key pause menu - three tabs. "Items" (potions and anything else
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
# self-cost numbers again outside of a fight. One real action button sits
# above all of that, though: replaying the scripted first fight on demand
# (World._replay_tutorial_battle()) - both the tutorial's own win and loss
# screens mention it lives here, for anyone who wants to see it again or
# missed something the first time.
#
# Same build-once-in-_ready()/rebuild-on-refresh shape as SpellTreeUI/
# SpellEquipUI/SavePointMenu - nothing here is scene-file based, on purpose,
# matching the rest of this project.
class_name InventoryMenu
extends Control

var world: World

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

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 50.0
	root.offset_top = 50.0
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

	_hint = Label.new()
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
	_list.custom_minimum_size = Vector2(360, 0)
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

func _refresh_items() -> void:
	_hint.text = "Using an item applies it to whoever you're currently steering."
	if world == null or world.inventory.is_empty():
		var empty := Label.new()
		empty.text = "No items yet"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_list.add_child(empty)
		return

	for item_id in world.inventory.keys():
		var count: int = int(world.inventory[item_id])
		if count <= 0:
			continue
		var def: Dictionary = Items.ITEMS.get(item_id, {})
		var btn := Button.new()
		btn.text = "Use %s (x%d)" % [String(def.get("display", item_id)), count]
		btn.tooltip_text = String(def.get("description", ""))
		btn.custom_minimum_size = Vector2(340, 40)
		# Disabled rather than hidden when it wouldn't help the currently
		# steered diver right now (full HP for a potion, full oxygen for a
		# cell, etc.) - same "show what you can't use yet" convention
		# spell_tree_ui.gd/the Party Spells tab already use, so the item
		# doesn't just vanish from the list, and world.use_inventory_item()
		# refuses the same way if this were ever somehow clicked anyway.
		if not world.divers.is_empty():
			btn.disabled = not Items.would_help(item_id, (world.divers[world.active] as Diver).stats)
		btn.pressed.connect(_on_use_item_pressed.bind(item_id))
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
		body.custom_minimum_size = Vector2(360, 0)
		body.add_theme_color_override("font_color", Color(0.8, 0.88, 0.9))
		_list.add_child(body)
