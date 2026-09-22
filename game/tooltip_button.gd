# A Button whose supplementary text remains readable at the edge of the
# combat HUD. Godot's stock tooltip is a single unwrapped line, which turns
# a useful move explanation into off-screen text on the bottom panel.
class_name TooltipButton
extends Button

const MAX_WIDTH := 300.0

func _make_custom_tooltip(for_text: String) -> Object:
	# An empty tooltip must stay absent. Returning an empty Control here would
	# create a blank, distracting panel for ordinary navigation buttons.
	if for_text.is_empty():
		return null
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.07, 0.1, 0.97)
	style.border_color = Color(0.32, 0.62, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(MAX_WIDTH, 0.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.98))
	panel.add_child(label)
	return panel
