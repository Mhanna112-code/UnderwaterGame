# A plain Button whose tooltip actually word-wraps and stays on screen.
# Godot's default tooltip is a single unwrapped Label - a long status-effect
# explanation (see battle.gd's _populate_move_menu()) just renders as one
# line wide enough to run off either edge of the viewport, or below the
# bottom near the HUD's lower edge. Overriding _make_custom_tooltip() here
# swaps in a Label with real autowrap and a fixed max width instead, so any
# tooltip built on this button class wraps into a short paragraph no matter
# how long the text is. Used by _menu_button() (battle.gd) for every menu
# button, not just the ones that currently set tooltip_text.
class_name TooltipButton
extends Button

const MAX_WIDTH := 260.0

func _make_custom_tooltip(for_text: String) -> Object:
	# Godot's DEFAULT tooltip silently shows nothing for an empty
	# tooltip_text, but that skip is specific to the default mechanism -
	# once this override exists, Godot calls it regardless and displays
	# whatever it returns, even an empty panel. Returning null here is what
	# actually opts a button with nothing to say out of showing one at all.
	if for_text == "":
		return null
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.13, 0.97)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10.0)
	style.border_color = Color(0.3, 0.45, 0.55)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	label.add_theme_color_override("font_color", Color(0.88, 0.93, 0.96))
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)
	return panel
