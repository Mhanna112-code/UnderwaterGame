# The screen a save point actually opens (see world.gd's
# _toggle_save_menu/_update_save_point_prompt) - this is the only entry
# point into spell learning/equipping in the whole game, on purpose.
# Owns navigation between six screens, only one visible at a time:
#   root:      "Save" / "Update Spells"
#   update:    "Equip Spells" / "Learn Spells" / "Back"
#   learn:     SpellTreeUI (its own Back returns here)
#   equip:     SpellEquipUI (its own Back returns here)
#   slots:     one button per save slot (same slots the title screen's own
#              Load/New Game picker shows), plus Back
#   confirm:   "Are you sure you want to overwrite this save progress?"
#              with Yes/No, only reachable from slots when the chosen slot
#              already has data
# world.gd only ever calls open_for()/close() - everything between those
# two calls is this file's business, not world.gd's.
class_name SavePointMenu
extends Control

# MODIFIED (changed): used to just be (diver: Diver) - saving now lets the
# player pick ANY slot (see _build_slots_panel()), not only whichever one
# this run started from, so world.gd needs to know which slot the request
# is actually for.
signal save_requested(diver: Diver, slot: int)

var diver: Diver
var _display_name := ""

var learn_ui: SpellTreeUI
var equip_ui: SpellEquipUI

var _root_panel: Control
var _update_panel: Control
var _slots_panel: Control
var _confirm_panel: Control
var _slots_list: VBoxContainer
var _confirm_label: Label
var _pending_slot := -1

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_root_panel = _build_root_panel()
	add_child(_root_panel)

	_update_panel = _build_update_panel()
	_update_panel.visible = false
	add_child(_update_panel)

	_slots_panel = _build_slots_panel()
	_slots_panel.visible = false
	add_child(_slots_panel)

	_confirm_panel = _build_confirm_panel()
	_confirm_panel.visible = false
	add_child(_confirm_panel)

	learn_ui = SpellTreeUI.new()
	learn_ui.back_pressed.connect(_on_sub_screen_back.bind(learn_ui))
	add_child(learn_ui)

	equip_ui = SpellEquipUI.new()
	equip_ui.back_pressed.connect(_on_sub_screen_back.bind(equip_ui))
	add_child(equip_ui)

# A left-aligned dark panel at a fixed screen position, not a CenterContainer
# - matches inventory_menu.gd's own root panel (same offset_left/offset_top),
# per direct request that the two menus "line up" instead of one being
# centered and the other pinned to the corner.
func _build_left_panel() -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12.0
	col.offset_top = 75.0
	col.offset_right = -50.0
	col.offset_bottom = -50.0
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(360, 0)
	bg.add_child(col)

	return bg

func _panel_column(panel: Control) -> VBoxContainer:
	return panel.get_child(0) as VBoxContainer

func _build_root_panel() -> Control:
	var bg := _build_left_panel()
	var col := _panel_column(bg)

	var title := Label.new()
	title.text = "Save / Update Spells"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(title)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(360, 40)
	save_btn.pressed.connect(_show_slots)
	col.add_child(save_btn)

	var update_btn := Button.new()
	update_btn.text = "Update Spells"
	update_btn.custom_minimum_size = Vector2(360, 40)
	update_btn.pressed.connect(_show_update)
	col.add_child(update_btn)

	return bg

func _build_update_panel() -> Control:
	var bg := _build_left_panel()
	var col := _panel_column(bg)

	var title := Label.new()
	title.text = "Update Spells"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(title)

	var equip_btn := Button.new()
	equip_btn.text = "Equip Spells"
	equip_btn.custom_minimum_size = Vector2(360, 40)
	equip_btn.pressed.connect(func() -> void:
		_update_panel.visible = false
		equip_ui.open_for(diver, _display_name)
	)
	col.add_child(equip_btn)

	var learn_btn := Button.new()
	learn_btn.text = "Learn Spells"
	learn_btn.custom_minimum_size = Vector2(360, 40)
	learn_btn.pressed.connect(func() -> void:
		_update_panel.visible = false
		learn_ui.open_for(diver, _display_name)
	)
	col.add_child(learn_btn)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(360, 36)
	back_btn.pressed.connect(_show_root)
	col.add_child(back_btn)

	return bg

# One button per SaveManager slot, same "Slot N - Lv X party" / "Slot N -
# Empty" readout title_screen.gd's own _refresh_slots()/_summarize() show -
# this is deliberately the exact same slot list a player already knows from
# New Game/Load Game, not a second, differently-worded picker. Rebuilt every
# time _show_slots() runs (not just once in _ready()) so it always reflects
# whatever just got written, in case the player saves more than once in the
# same visit to this menu.
func _build_slots_panel() -> Control:
	var bg := _build_left_panel()
	var col := _panel_column(bg)

	var title := Label.new()
	title.text = "Choose a slot to save to"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(title)

	_slots_list = VBoxContainer.new()
	_slots_list.add_theme_constant_override("separation", 8)
	col.add_child(_slots_list)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(360, 36)
	back_btn.pressed.connect(_show_root)
	col.add_child(back_btn)

	return bg

func _refresh_slots_list() -> void:
	for child in _slots_list.get_children():
		child.queue_free()
	for slot in range(SaveManager.SLOT_COUNT):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(360, 44)
		var data: Dictionary = SaveManager.read_slot(slot)
		if data.is_empty():
			btn.text = "Slot %d - Empty" % (slot + 1)
		else:
			btn.text = "Slot %d - %s" % [slot + 1, _summarize(data)]
		btn.pressed.connect(_on_slot_pressed.bind(slot, not data.is_empty()))
		_slots_list.add_child(btn)

# Same one-line "Lv N party" readout title_screen.gd's own _summarize()
# builds - not shared code (title_screen.gd's copy is private to that
# script), but deliberately the same logic/wording so a slot reads
# identically whichever screen it's seen from.
func _summarize(data: Dictionary) -> String:
	var divers_data: Array = data.get("divers", [])
	if divers_data.is_empty():
		return "?"
	var d0: Dictionary = divers_data[0]
	var stats: Dictionary = d0.get("stats", {})
	return "Lv %d party" % int(stats.get("level", 1))

func _on_slot_pressed(slot: int, occupied: bool) -> void:
	if occupied:
		_pending_slot = slot
		_confirm_label.text = "Slot %d already has progress. Are you sure you want to overwrite this save progress?" % (slot + 1)
		_slots_panel.visible = false
		_confirm_panel.visible = true
		return
	save_requested.emit(diver, slot)

func _build_confirm_panel() -> Control:
	var bg := _build_left_panel()
	var col := _panel_column(bg)

	_confirm_label = Label.new()
	_confirm_label.text = ""
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(_confirm_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(175, 40)
	yes_btn.pressed.connect(_on_confirm_overwrite_yes)
	row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(175, 40)
	no_btn.pressed.connect(_on_confirm_overwrite_no)
	row.add_child(no_btn)

	return bg

func _on_confirm_overwrite_yes() -> void:
	var slot := _pending_slot
	_pending_slot = -1
	_confirm_panel.visible = false
	save_requested.emit(diver, slot)

func _on_confirm_overwrite_no() -> void:
	_pending_slot = -1
	_confirm_panel.visible = false
	_show_slots()

func _on_sub_screen_back(screen: Control) -> void:
	screen.close()
	_show_update()

func _show_root() -> void:
	_root_panel.visible = true
	_update_panel.visible = false
	_slots_panel.visible = false
	_confirm_panel.visible = false
	learn_ui.close()
	equip_ui.close()

func _show_update() -> void:
	_root_panel.visible = false
	_update_panel.visible = true
	_slots_panel.visible = false
	_confirm_panel.visible = false

func _show_slots() -> void:
	_refresh_slots_list()
	_root_panel.visible = false
	_update_panel.visible = false
	_confirm_panel.visible = false
	_slots_panel.visible = true

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
