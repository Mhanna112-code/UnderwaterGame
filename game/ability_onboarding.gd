# A short, first-free-play walkthrough. It intentionally sits after the
# combat tutorial rather than inside it: the player has just learned a battle
# and now needs to understand how to move, switch divers, and use the three
# exploration verbs without a wall of text competing with the fight.
#
# This is a runtime-built Control like TutorialBook/TitleScreen, not a global
# autoload. World owns the one instance and opens it after a tutorial result,
# which keeps lifecycle, pause state, and test setup local to the scene that
# owns the party and the actual ability bindings.
class_name AbilityOnboarding
extends Control

signal closed

var _world: World
var _pages: Array[Dictionary] = []
var _index := 0

var _panel: PanelContainer
var _progress: Label
var _title: Label
var _body: RichTextLabel
var _key_row: HFlowContainer
var _back: Button
var _next: Button
var _close: Button

func _ready() -> void:
	name = "AbilityOnboarding"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.04, 0.08, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	margin.add_child(column)

	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 13)
	_progress.add_theme_color_override("font_color", Color(0.37, 0.76, 0.92))
	column.add_child(_progress)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 27)
	_title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	column.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0, 130)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_color_override("default_color", Color(0.82, 0.9, 0.94))
	column.add_child(_body)

	_key_row = HFlowContainer.new()
	_key_row.add_theme_constant_override("h_separation", 8)
	_key_row.add_theme_constant_override("v_separation", 8)
	column.add_child(_key_row)

	var divider := HSeparator.new()
	divider.modulate = Color(0.35, 0.55, 0.65, 0.8)
	column.add_child(divider)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)

	_back = _action_button("< Back")
	_back.pressed.connect(go_back)
	actions.add_child(_back)
	_next = _action_button("Next >")
	_next.pressed.connect(advance_page)
	actions.add_child(_next)
	_close = _action_button("Close")
	_close.pressed.connect(dismiss)
	actions.add_child(_close)
	call_deferred("_layout_panel")

# The supplied World is the source of player-facing names and ability data.
# Pages remain data instead of hardcoded child-tree strings so verification can
# compare the tutorial claim with the implementation that actually runs.
func open_for_world(world: World) -> void:
	_world = world
	_pages = _pages_for_world(world)
	if _pages.is_empty():
		return
	_index = 0
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	call_deferred("_layout_panel")

func advance_page() -> void:
	if not visible:
		return
	if _index >= _pages.size() - 1:
		dismiss()
		return
	_index += 1
	_refresh()

func go_back() -> void:
	if not visible or _index <= 0:
		return
	_index -= 1
	_refresh()

func dismiss() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	# Keep a visible cursor after a reading UI closes. The next world click
	# deliberately captures it for mouse-look; no modal-close key can fire an
	# exploration ability through the world underneath.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _world != null:
		_world.mouse_look = false
		_world._update_hud()
	closed.emit()

func current_page_data() -> Dictionary:
	if _pages.is_empty() or _index < 0 or _index >= _pages.size():
		return {}
	var out := (_pages[_index] as Dictionary).duplicate(true)
	out["back_enabled"] = _index > 0
	out["next_enabled"] = _index < _pages.size() - 1
	out["page_index"] = _index
	out["page_count"] = _pages.size()
	return out

func _refresh() -> void:
	var page := current_page_data()
	_progress.text = "WORLD BASICS  ·  %d OF %d" % [_index + 1, _pages.size()]
	_title.text = String(page.get("title", ""))
	_body.text = String(page.get("body", ""))
	_back.disabled = not bool(page.get("back_enabled", false))
	_next.visible = bool(page.get("next_enabled", false))
	_close.text = "Start Swimming" if not bool(page.get("next_enabled", false)) else "Close"
	for child in _key_row.get_children():
		child.queue_free()
	for key in page.get("keys", []) as Array:
		_key_row.add_child(_keycap(String(key)))

func _pages_for_world(world: World) -> Array[Dictionary]:
	var maxilani := _name_for(world, "swap", "Maxilani")
	var musashi := _name_for(world, "grapple", "Musashi")
	var bucky := _name_for(world, "shockwave", "Bucky")
	return [
		{
			"id": "world-controls",
			"title": "You are in control",
			"body": "[color=#79c7e8]WASD[/color] swims in the direction the camera faces. Move the [color=#79c7e8]mouse[/color] or use the arrow keys to look around. [color=#79c7e8]TAB[/color] switches the active diver. Each diver brings a different way through the world.",
			"keys": ["WASD  Swim", "Mouse / arrows  Look", "TAB  Switch diver"],
			"ability_id": "",
			"passive_id": "",
			"requires_aim": false,
			"environmental_oxygen_cost": 0,
		},
		{
			"id": "swap-sonar",
			"title": "%s · Swap and Sonar" % maxilani,
			"body": "Switch to %s with [color=#79c7e8]TAB[/color]. Press [color=#79c7e8]E[/color] to choose a teammate, use [color=#79c7e8]Left / Right[/color] to choose, then [color=#79c7e8]Enter[/color] to swap places. Press [color=#79c7e8]Q[/color] to toggle Sonar when %s is active; it reveals nearby hidden sites and spends [color=#79c7e8]3 O2 every 3 seconds[/color] while on." % [maxilani, maxilani],
			"keys": ["TAB  %s" % maxilani, "E  Swap", "Left / Right  Choose", "Enter  Confirm", "Q  Sonar"],
			"ability_id": "swap",
			"passive_id": "sonar",
			"requires_aim": false,
			"environmental_oxygen_cost": 0,
			"sonar_oxygen_per_tick": 3,
			"sonar_tick_seconds": 3,
		},
		{
			"id": "grapple",
			"title": "%s · Grapple" % musashi,
			"body": "Switch to %s with [color=#79c7e8]TAB[/color]. Press [color=#79c7e8]E[/color] to enter aim mode, look at a golden grapple anchor, then [color=#79c7e8]left-click[/color] to fire. [color=#79c7e8]Right-click[/color] cancels aim. A missed grapple costs no oxygen, so try again if the beam does not connect." % musashi,
			"keys": ["TAB  %s" % musashi, "E  Aim", "Left click  Fire", "Right click  Cancel"],
			"ability_id": "grapple",
			"passive_id": "",
			"requires_aim": true,
			"environmental_oxygen_cost": 0,
		},
		{
			"id": "shockwave",
			"title": "%s · Shockwave" % bucky,
			"body": "Switch to %s with [color=#79c7e8]TAB[/color], then press [color=#79c7e8]E[/color] to send a shockwave in every direction. It breaks nearby objects built to respond to it, including route blockades. Shockwave has a short cooldown, but it does [color=#79c7e8]not use oxygen[/color]." % bucky,
			"keys": ["TAB  %s" % bucky, "E  Shockwave"],
			"ability_id": "shockwave",
			"passive_id": "",
			"requires_aim": false,
			"environmental_oxygen_cost": 0,
		},
	]

func _name_for(world: World, ability_id: String, fallback: String) -> String:
	for diver in world.divers:
		if diver is Diver and String((diver as Diver).ability_id) == ability_id:
			return Cast.display_name((diver as Diver).model_name)
	return fallback

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.09, 0.15, 0.98)
	style.border_color = Color(0.32, 0.78, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	return style

func _action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(118, 42)
	return button

func _keycap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", _keycap_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	cap.add_child(margin)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.87, 0.94, 0.98))
	margin.add_child(label)
	return cap

func _keycap_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.16, 0.23)
	style.border_color = Color(0.24, 0.49, 0.61)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _layout_panel() -> void:
	if _panel == null:
		return
	var viewport := get_viewport_rect().size
	var width := clampf(viewport.x - 32.0, 280.0, 760.0)
	var height := clampf(viewport.y - 32.0, 280.0, 460.0)
	_panel.size = Vector2(width, height)
	_panel.position = (viewport - _panel.size) * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_panel()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	match (event as InputEventKey).keycode:
		KEY_LEFT:
			go_back()
		KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER:
			advance_page()
		KEY_ESCAPE:
			dismiss()
		_:
			return
	get_viewport().set_input_as_handled()
