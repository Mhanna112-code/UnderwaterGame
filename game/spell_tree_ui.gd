# Scaffolding for the spell-tree screen: three columns (one per
# SpellTree.branches() entry), a button per spell in that branch, spent
# points and unmet requirements just disable the button rather than
# hiding it - seeing what you can't afford/haven't unlocked yet is part of
# planning which branch to spend on next. Hovering a button shows its
# description via Godot's own tooltip (Button.tooltip_text) rather than a
# hand-built popup - it's exactly what that property is for.
#
# Every diver has their own tree now (see SpellTree.SPELL_TREES), so the
# columns can't be built once in _ready() and reused - open_for() rebuilds
# them fresh for whichever diver's tree is being viewed. Branch order is
# still fixed (SpellTree.BRANCH_ORDER) so the screen doesn't reshuffle
# left-to-right depending on whose tree is open.
#
# Rebuilds its buttons from scratch on every _refresh() rather than
# tracking diffs, same tradeoff MiniMap's _draw() makes - simpler to get
# right than incremental updates.
#
# Reached only through SavePointMenu now, never directly - back_pressed is
# how it hands control back to the update submenu instead of just hiding
# itself, so the player lands back on Equip/Learn/Back, not out of the
# save-point flow entirely.
#
# THIS IS SCAFFOLDING, not the finished screen: no tree-line connectors
# between prerequisite spells (columns just list every node in the branch
# top to bottom), no icons. Good enough to prove the data/gating work
# end-to-end; the visual layer is a later pass once real spell content
# exists to look at.
class_name SpellTreeUI
extends Control

signal back_pressed

var diver: Diver

# Placeholder until game/quest_manager.gd exists - passed through to
# SpellTree.can_learn()/learn() exactly like a real key-item list would be,
# so wiring in the real one later is a one-line change here, not a
# rewrite of this screen.
var key_items: Array = []

var _title_label: Label
var _points_label: Label
var _columns_box: HBoxContainer
var _branch_columns: Dictionary = {}   # branch name -> VBoxContainer

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
	hint.text = "Hover a spell for details. Click to learn it."
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	root.add_child(hint)

	_columns_box = HBoxContainer.new()
	_columns_box.add_theme_constant_override("separation", 40)
	root.add_child(_columns_box)

func open_for(d: Diver, display_name: String = "") -> void:
	diver = d
	visible = true
	_title_label.text = "%s's Spell Tree" % (display_name if display_name != "" else d.model_name)
	_rebuild_columns()
	_refresh()

func close() -> void:
	visible = false
	diver = null

# Rebuilt every open_for() rather than once in _ready(), since which
# branches/spells exist depends on diver.model_name now (see
# SpellTree.SPELL_TREES) - a screen built for one diver's tree can't just
# be relabeled for another's, the columns themselves need different
# spells in them.
func _rebuild_columns() -> void:
	for child in _columns_box.get_children():
		child.queue_free()
	_branch_columns.clear()

	for branch in SpellTree.branches(diver.model_name):
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(230, 0)
		col.add_theme_constant_override("separation", 6)

		var header := Label.new()
		header.text = String(branch).capitalize()
		header.add_theme_font_size_override("font_size", 19)
		header.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
		col.add_child(header)

		_columns_box.add_child(col)
		_branch_columns[branch] = col

func _refresh() -> void:
	if diver == null:
		return
	_points_label.text = "Spell Points: %d" % diver.stats.spell_points

	for branch in SpellTree.branches(diver.model_name):
		var col: VBoxContainer = _branch_columns[branch]
		# First child is the header Label - only clear buttons below it.
		for child in col.get_children():
			if child is Button:
				child.queue_free()

		for spell_id in SpellTree.tree_for(diver.model_name)[branch]:
			var def: Dictionary = SpellTree.spell_def(diver.model_name, branch, spell_id)
			var btn := Button.new()
			btn.tooltip_text = String(def.get("description", ""))
			var ox_cost: int = int(def.get("oxygen_cost", 0.0))
			if diver.known_spells.has(spell_id):
				btn.text = "%s - learned (%d O2/cast)" % [def.display, ox_cost]
				btn.disabled = true
			else:
				var cost: int = def.cost
				btn.text = "%s (%d pt%s, %d O2/cast)" % [def.display, cost, "" if cost == 1 else "s", ox_cost]
				btn.disabled = not SpellTree.can_learn(diver, branch, spell_id, key_items)
				btn.pressed.connect(_on_spell_pressed.bind(branch, spell_id))
			col.add_child(btn)

func _on_spell_pressed(branch: String, spell_id: String) -> void:
	SpellTree.learn(diver, branch, spell_id, key_items)
	_refresh()
