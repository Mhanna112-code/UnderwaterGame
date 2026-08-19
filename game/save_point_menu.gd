# The screen a save point actually opens (see world.gd's
# _toggle_save_menu/_update_save_point_prompt) - this is the only entry
# point into spell learning/equipping in the whole game, on purpose.
# Owns navigation between four screens, only one visible at a time:
#   root:   "Save" / "Update Spells"
#   update: "Equip Spells" / "Learn Spells" / "Back"
#   learn:  SpellTreeUI (its own Back returns here)
#   equip:  SpellEquipUI (its own Back returns here)
# world.gd only ever calls open_for()/close() - everything between those
# two calls is this file's business, not world.gd's.
class_name SavePointMenu
extends Control

signal save_requested(diver: Diver)

var diver: Diver
var _display_name := ""

var learn_ui: SpellTreeUI
var equip_ui: SpellEquipUI

var _root_panel: Control
var _update_panel: Control

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_root_panel = _build_root_panel()
	add_child(_root_panel)

	_update_panel = _build_update_panel()
	_update_panel.visible = false
	add_child(_update_panel)

	learn_ui = SpellTreeUI.new()
	learn_ui.back_pressed.connect(_on_sub_screen_back.bind(learn_ui))
	add_child(learn_ui)

	equip_ui = SpellEquipUI.new()
	equip_ui.back_pressed.connect(_on_sub_screen_back.bind(equip_ui))
	add_child(equip_ui)

func _build_root_panel() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	# CenterContainer, not PRESET_CENTER anchors with hand-picked offsets -
	# the anchor-point approach put the box's center at the wrong place
	# (top-left corner instead of screen center), cutting the whole panel
	# half off-screen. A CenterContainer positions its child from its own
	# resolved rect and the child's minimum size, the same reliable
	# full-rect-based layout every other screen in this project already
	# uses (see spell_tree_ui.gd's root VBoxContainer), instead of a
	# separate anchor calculation that can end up anchored to the wrong
	# origin.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "Save / Update Spells"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	box.add_child(title)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	box.add_child(save_btn)

	var update_btn := Button.new()
	update_btn.text = "Update Spells"
	update_btn.pressed.connect(_show_update)
	box.add_child(update_btn)

	return bg

func _build_update_panel() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "Update Spells"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	box.add_child(title)

	var equip_btn := Button.new()
	equip_btn.text = "Equip Spells"
	equip_btn.pressed.connect(func() -> void:
		_update_panel.visible = false
		equip_ui.open_for(diver, _display_name)
	)
	box.add_child(equip_btn)

	var learn_btn := Button.new()
	learn_btn.text = "Learn Spells"
	learn_btn.pressed.connect(func() -> void:
		_update_panel.visible = false
		learn_ui.open_for(diver, _display_name)
	)
	box.add_child(learn_btn)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.pressed.connect(_show_root)
	box.add_child(back_btn)

	return bg

func _on_sub_screen_back(screen: Control) -> void:
	screen.close()
	_show_update()

func _show_root() -> void:
	_root_panel.visible = true
	_update_panel.visible = false
	learn_ui.close()
	equip_ui.close()

func _show_update() -> void:
	_root_panel.visible = false
	_update_panel.visible = true

# No real persistence exists yet (see the wider save/load roadmap this was
# scaffolded ahead of) - this is honest about that rather than pretending
# to write anything. world.gd's handler just banners a confirmation; the
# signal is here so a real save_manager.gd can hook in later without this
# file changing at all.
func _on_save_pressed() -> void:
	save_requested.emit(diver)

func open_for(d: Diver, display_name: String = "") -> void:
	diver = d
	_display_name = display_name
	visible = true
	_show_root()

func close() -> void:
	visible = false
	diver = null
	learn_ui.close()
	equip_ui.close()
