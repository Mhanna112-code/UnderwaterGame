extends Control
## Read-only exploration presentation. World still owns resources and input.
## Only the active diver has meters; teammates have compact numeric rows.
const HEALTH := Color(0.96, 0.43, 0.36)
const OXYGEN := Color(0.22, 0.76, 0.9)
const TEXT := Color(0.92, 0.97, 1.0)

var active_panel: PanelContainer
var party_panel: PanelContainer
var party_rows: VBoxContainer
var active_name: Label
var hp_bar: ProgressBar
var hp_label: Label
var oxygen_bar: ProgressBar
var oxygen_label: Label
var health_fill: StyleBoxFlat
var encounter_label: Label
var switch_hint: Label
var _rows: Array[Dictionary] = []

func _ready() -> void:
	name = "ExplorationHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_panel = _panel("PartyStatus")
	party_rows = VBoxContainer.new()
	party_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_rows.add_theme_constant_override("separation", 5)
	party_panel.add_child(party_rows)
	for i in range(3):
		var row := HBoxContainer.new()
		row.name = "Teammate%d" % i
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		party_rows.add_child(row)
		var character := _label("", TEXT, 14)
		character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(character)
		var hp := _label("", HEALTH, 13)
		row.add_child(hp)
		var oxygen := _label("", OXYGEN, 13)
		row.add_child(oxygen)
		_rows.append({"row": row, "name": character, "health": hp, "oxygen": oxygen})
	switch_hint = _label("TAB  Switch diver", TEXT, 13)
	party_rows.add_child(switch_hint)
	active_panel = _panel("ActiveDiverStatus")
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	active_panel.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	active_name = _label("", TEXT, 18)
	header.add_child(active_name)
	header.add_child(_label("ACTIVE", Color(0.3, 0.94, 0.72), 11))
	var hp_row := _meter_row(column)
	hp_label = _label("Health", TEXT, 13)
	hp_label.custom_minimum_size.x = 135
	hp_row.add_child(hp_label)
	hp_bar = _meter(HEALTH)
	health_fill = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	hp_row.add_child(hp_bar)
	var oxygen_row := _meter_row(column)
	oxygen_label = _label("Oxygen", OXYGEN, 13)
	oxygen_label.custom_minimum_size.x = 135
	oxygen_row.add_child(oxygen_label)
	oxygen_bar = _meter(OXYGEN)
	oxygen_row.add_child(oxygen_bar)
	encounter_label = _label("", TEXT, 13)
	encounter_label.name = "EncounterStatus"
	encounter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(encounter_label)

func refresh(party: Array[Dictionary], selected: int, encounters_on: bool, switch_available: bool) -> void:
	if party.is_empty() or selected < 0 or selected >= party.size():
		return
	var stats := party[selected].stats as CombatantStats
	active_name.text = String(party[selected].name)
	hp_bar.max_value = maxf(1, stats.hp_max)
	hp_bar.value = stats.hp
	hp_label.text = "Health  %d/%d%s" % [stats.hp, stats.hp_max, _health_warning(stats)]
	oxygen_bar.max_value = maxf(1, stats.oxygen_max)
	oxygen_bar.value = stats.oxygen
	oxygen_label.text = "Oxygen  %d/%d%s" % [int(stats.oxygen), int(stats.oxygen_max), " LOW" if stats.oxygen <= stats.oxygen_max * 0.2 else ""]
	for i in range(_rows.size()):
		var entry := _rows[i]
		(entry.row as Control).visible = i < party.size() and i != selected
		if i >= party.size() or i == selected:
			continue
		var other := party[i].stats as CombatantStats
		(entry.name as Label).text = String(party[i].name)
		(entry.health as Label).text = "HP %d/%d%s" % [other.hp, other.hp_max, _health_warning(other)]
		var percent := int(ceil(clampf(other.oxygen / maxf(1, other.oxygen_max), 0, 1) * 100))
		(entry.oxygen as Label).text = "Oxygen %d%%" % percent
	switch_hint.text = "TAB  Switch diver" if switch_available else "Switching available after the tutorial"
	encounter_label.text = "●  Random encounters: %s" % ("ON" if encounters_on else "OFF")
	encounter_label.add_theme_color_override("font_color", TEXT if encounters_on else Color(0.67, 0.75, 0.81))

func layout_for(viewport_size: Vector2, map_rect: Rect2, maze_controls_bottom := 0.0) -> void:
	var narrow := viewport_size.x < 600
	var width := minf(350, viewport_size.x - 32)
	_rect(party_panel, Rect2(16, maxf(16, maze_controls_bottom + 8), width, 86))
	_rect(active_panel, Rect2((viewport_size.x - width) * 0.5, viewport_size.y - 108, width, 92))
	var status_width := minf(230, viewport_size.x - 32)
	_rect(encounter_label, Rect2(viewport_size.x - status_width - 16, map_rect.end.y + 5, status_width, 24))
	# Numeric rows shrink their font, not their meaning, on narrow screens.
	for entry in _rows:
		for key in ["name", "health", "oxygen"]:
			(entry[key] as Label).add_theme_font_size_override("font_size", 12 if narrow else (14 if key == "name" else 13))

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.105, 0.9)
	style.border_color = Color(0.22, 0.47, 0.58, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func _panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", panel_style())
	add_child(panel)
	return panel

func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _meter_row(column: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	return row

func _meter(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.step = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(60, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	var background := fill.duplicate() as StyleBoxFlat
	background.bg_color = Color(0.13, 0.23, 0.28)
	bar.add_theme_stylebox_override("background", background)
	return bar

func _health_warning(stats: CombatantStats) -> String:
	if stats.hp <= 0:
		return " DOWN"
	return " LOW" if stats.hp <= stats.hp_max * 0.25 else ""

func _rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
