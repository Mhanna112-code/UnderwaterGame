# The other half of "Update Spells": SpellTreeUI is where you buy a spell,
# this is where you decide which known ones are actually active for battle
# (see Diver.equipped_spells/MAX_EQUIPPED_SPELLS). A toggle button per
# known spell - pressed means equipped. Buying a spell doesn't equip it
# automatically, so this screen is also the only place a freshly learned
# spell actually becomes usable.
#
# Same rebuild-on-refresh approach as SpellTreeUI/MiniMap, same
# tooltip_text-for-hover-description approach, same back_pressed signal
# handing control back to SavePointMenu's update submenu rather than
# closing the whole flow.
class_name SpellEquipUI
extends Control

signal back_pressed

var diver: Diver

var _title_label: Label
var _points_label: Label
var _list: VBoxContainer

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

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(90, 0)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	root.add_child(back_btn)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	root.add_child(_title_label)

	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 24)
	_points_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	root.add_child(_points_label)

	var hint := Label.new()
	hint.text = "Hover a spell for details. Click to equip or unequip it."
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	root.add_child(hint)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(320, 0)
	_list.add_theme_constant_override("separation", 6)
	root.add_child(_list)

func open_for(d: Diver, display_name: String = "") -> void:
	diver = d
	visible = true
	_title_label.text = "%s's Loadout" % (display_name if display_name != "" else d.model_name)
	_refresh()

func close() -> void:
	visible = false
	diver = null

func _refresh() -> void:
	if diver == null:
		return
	_points_label.text = "Equipped: %d / %d" % [
		diver.equipped_spells.size(), Diver.MAX_EQUIPPED_SPELLS
	]

	for child in _list.get_children():
		child.queue_free()

	if diver.known_spells.is_empty():
		var empty := Label.new()
		empty.text = "No spells learned yet - visit Learn Spells first."
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_list.add_child(empty)
		return

	for spell_id in diver.known_spells:
		var def: Dictionary = SpellTree.find_def(diver.model_name, spell_id)
		var equipped: bool = diver.equipped_spells.has(spell_id)
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = equipped
		btn.tooltip_text = String(def.get("description", ""))
		btn.text = "%s - %d O2%s" % [
			String(def.get("display", spell_id)), int(def.get("oxygen_cost", 0.0)),
			" (equipped)" if equipped else ""
		]
		# Disabled only in the one case where pressing it couldn't do
		# anything: not equipped and the loadout is already full - an
		# equipped spell should always be free to unequip.
		btn.disabled = not equipped and not SpellTree.can_equip(diver, spell_id)
		btn.pressed.connect(_on_spell_toggled.bind(spell_id))
		_list.add_child(btn)

func _on_spell_toggled(spell_id: String) -> void:
	if diver.equipped_spells.has(spell_id):
		SpellTree.unequip(diver, spell_id)
	else:
		SpellTree.equip(diver, spell_id)
	_refresh()
