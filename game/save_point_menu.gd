# Save point menu: root "Save" -> slot picker -> overwrite confirm.
# world.gd only calls open_for()/close().
class_name SavePointMenu
extends Control

signal save_requested(diver: Diver, slot: int)

var diver: Diver

var _root_panel: Control
var _slots_panel: Control
var _confirm_panel: Control
var _slots_list: VBoxContainer
var _confirm_label: Label
var _pending_slot := -1
var _saving_label: Label

# Confirmation blocks navigation and repeat clicks until the write finishes.
func set_saving(on: bool, slot := -1) -> void:
	if _saving_label == null:
		_saving_label = Label.new()
		_saving_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_column(_root_panel).add_child(_saving_label)
	_saving_label.text = "Saving to Slot %d… Please wait." % (slot + 1)
	_saving_label.visible = on
	if on:
		_show_root()
	for button in find_children("*", "Button", true, false):
		(button as Button).disabled = on

func _ready() -> void:
	visible = false
	# Explicitly normalize the backing surface before laying out the panels.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_root_panel = _build_root_panel()
	add_child(_root_panel)

	_slots_panel = _build_slots_panel()
	_slots_panel.visible = false
	add_child(_slots_panel)

	_confirm_panel = _build_confirm_panel()
	_confirm_panel.visible = false
	add_child(_confirm_panel)


# Fixed left-aligned panel, lined up with inventory_menu.gd's.
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
	col.custom_minimum_size = Vector2.ZERO
	bg.add_child(col)

	return bg

func _panel_column(panel: Control) -> VBoxContainer:
	return panel.get_child(0) as VBoxContainer

func _build_root_panel() -> Control:
	var bg := _build_left_panel()
	var col := _panel_column(bg)

	var title := Label.new()
	title.text = "Save Point"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(title)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(0, 40)
	save_btn.pressed.connect(_show_slots)
	col.add_child(save_btn)

	return bg

# One button per slot, same readout as the title screen; rebuilt on every _show_slots().
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
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.pressed.connect(_show_root)
	col.add_child(back_btn)

	return bg

func _refresh_slots_list() -> void:
	for child in _slots_list.get_children():
		child.queue_free()
	for slot in range(SaveManager.SLOT_COUNT):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		var data: Dictionary = SaveManager.read_slot(slot)
		if data.is_empty():
			btn.text = "Slot %d - Empty" % (slot + 1)
		else:
			btn.text = "Slot %d - %s" % [slot + 1, _summarize(data)]
		btn.pressed.connect(_on_slot_pressed.bind(slot, not data.is_empty()))
		_slots_list.add_child(btn)

# Same "Lv N party" summary as title_screen.gd's _summarize().
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
	yes_btn.custom_minimum_size = Vector2(0, 40)
	yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_btn.pressed.connect(_on_confirm_overwrite_yes)
	row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(0, 40)
	no_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

func _show_root() -> void:
	_root_panel.visible = true
	_slots_panel.visible = false
	_confirm_panel.visible = false

func _show_slots() -> void:
	_refresh_slots_list()
	_root_panel.visible = false
	_confirm_panel.visible = false
	_slots_panel.visible = true

func open_for(d: Diver) -> void:
	diver = d
	visible = true
	_show_root()

func close() -> void:
	visible = false
	diver = null
