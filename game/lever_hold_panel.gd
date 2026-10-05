class_name LeverHoldPanel
extends Panel

# Shown above the orange caption while the active diver is holding one of
# the dome's levers and the other lever is still free: a "lever on" sign (a
# drawn lever thrown to ON) with "Press E to release the lever" under it.

const PANEL_SIZE := Vector2(380, 150)
const ON_GREEN := Color(0.35, 0.95, 0.5)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.13, 0.92)
	style.border_color = Color(0.45, 0.7, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -PANEL_SIZE.x * 0.5
	offset_right = PANEL_SIZE.x * 0.5
	offset_top = -340.0
	offset_bottom = -340.0 + PANEL_SIZE.y

	var sign_label := Label.new()
	sign_label.text = "LEVER ON"
	sign_label.add_theme_font_size_override("font_size", 30)
	sign_label.add_theme_color_override("font_color", ON_GREEN)
	sign_label.position = Vector2(150, 26)
	sign_label.size = Vector2(210, 44)
	sign_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sign_label)

	var hint := Label.new()
	hint.text = "Press E to release the lever"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 100)
	hint.size = Vector2(PANEL_SIZE.x, 32)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

# The sign: a little plate with a lever base and its handle thrown over to
# a green ON position.
func _draw() -> void:
	var plate := Rect2(Vector2(24, 14), Vector2(110, 74))
	draw_rect(plate, Color(0.12, 0.16, 0.2))
	draw_rect(plate, ON_GREEN, false, 2.0)
	var pivot := Vector2(79, 74)
	draw_rect(Rect2(pivot + Vector2(-24, -4), Vector2(48, 12)), Color(0.35, 0.38, 0.42))
	var tip := pivot + Vector2(28, -40)
	draw_line(pivot, tip, ON_GREEN, 6.0, true)
	draw_circle(tip, 7.0, ON_GREEN)
	draw_circle(pivot, 5.0, Color(0.6, 0.62, 0.66))
