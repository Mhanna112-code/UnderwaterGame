# A plain Button whose tooltip word-wraps and always opens directly ABOVE
# the button. Used by _menu_button() (battle.gd) for every menu button.
#
# Godot's built-in tooltip opens below the mouse cursor and only flips above
# when it would run past the bottom of the screen. The battle menu sits at
# the bottom edge, so whether a given move's tooltip "fit" below depended on
# its text height and exactly where the cursor was - one move's tooltip
# opened below (Crushing Haymaker) while its neighbours' flipped above. This
# button suppresses the built-in tooltip (_get_tooltip() returns "") and
# shows its own panel instead, positioned from the button's rect rather than
# the cursor, so every tooltip lands in the same place.
class_name TooltipButton
extends Button

const MAX_WIDTH := 260.0
# Gap between the button's top edge and the tooltip's bottom edge.
const GAP := 6.0
const SCREEN_MARGIN := 4.0

var _hover_layer: CanvasLayer
var _hover_panel: Control
# A child Timer (not an await on a SceneTreeTimer) so a pending show dies
# with the button when the move menu frees and rebuilds its buttons.
var _delay_timer: Timer
# Frames left before placing the panel - an autowrapped Label only knows
# its wrapped height after a layout pass.
var _place_frames := 0

func _ready() -> void:
	set_process(false)
	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	# Same delay the built-in tooltip uses.
	_delay_timer.wait_time = float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5))
	_delay_timer.timeout.connect(_show_hover)
	add_child(_delay_timer)
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_hide_hover)
	pressed.connect(_hide_hover)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_hide_hover()
	)

# Suppresses Godot's own tooltip; tooltip_text still holds the text.
func _get_tooltip(_at_position: Vector2) -> String:
	return ""

func _on_hover_start() -> void:
	_hide_hover()
	if tooltip_text != "":
		_delay_timer.start()

func _show_hover() -> void:
	if not is_visible_in_tree() or tooltip_text == "":
		return
	# Its own top CanvasLayer so the tooltip draws over every other HUD
	# element regardless of tree order.
	_hover_layer = CanvasLayer.new()
	_hover_layer.layer = 128
	_hover_panel = _build_panel(tooltip_text)
	_hover_panel.visible = false
	_hover_layer.add_child(_hover_panel)
	add_child(_hover_layer)
	_place_frames = 2
	set_process(true)

func _process(_delta: float) -> void:
	if _hover_panel == null:
		set_process(false)
		return
	_place_frames -= 1
	if _place_frames > 0:
		return
	set_process(false)
	_hover_panel.reset_size()
	var panel_size := _hover_panel.size
	var xf := get_global_transform_with_canvas()
	var button_pos := xf.origin
	var button_size := size * xf.get_scale()
	var screen := get_viewport().get_visible_rect().size
	var x := clampf(button_pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, screen.x - panel_size.x - SCREEN_MARGIN))
	var y := button_pos.y - panel_size.y - GAP
	# Only when there's genuinely no room above (never for the bottom HUD).
	if y < SCREEN_MARGIN:
		y = button_pos.y + button_size.y + GAP
	_hover_panel.position = Vector2(x, y)
	_hover_panel.visible = true

func _hide_hover() -> void:
	if _delay_timer != null:
		_delay_timer.stop()
	set_process(false)
	if _hover_layer != null and is_instance_valid(_hover_layer):
		_hover_layer.queue_free()
	_hover_layer = null
	_hover_panel = null

func _build_panel(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.13, 0.97)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	style.border_color = Color(0.3, 0.45, 0.55)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	label.add_theme_color_override("font_color", Color(0.88, 0.93, 0.96))
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)
	return panel
