# Spell-tree screen (scaffolding): one column per branch in BRANCH_ORDER, unaffordable spells disabled not hidden.
# Rebuilt per diver in open_for(); reached only via SavePointMenu, returning through back_pressed.
class_name SpellTreeUI
extends Control

signal back_pressed

var diver: Diver

# Placeholder until a real key-item source exists.
var key_items: Array = []

var _title_label: Label
var _points_label: Label
var _columns_box: HBoxContainer
var _branch_columns: Dictionary = {}   # branch name -> VBoxContainer

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	# Full-screen and opaque so world HUD text can't overlap it.
	bg.color = Color(0.02, 0.05, 0.08, 1.0)
	# Backdrop must not eat clicks meant for the spell buttons.
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_columns_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

# Columns depend on the diver's tree, so they're rebuilt per open_for().
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
		# Keep the header Label (first child).
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
