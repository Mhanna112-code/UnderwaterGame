# A short, non-blocking overlay beat: backdrop and centered text fade in,
# hold long enough to read, both fade back out, then this
# frees itself. Doesn't pause the world or steal input - world.gd just
# fires one of these and moves on, same as _announce() does for banner
# text, just a heavier beat for a one-time moment (see world.gd's
# _check_gap_puzzle calling this once the 3-plate gate opens).
class_name Cutscene
extends CanvasLayer

signal finished

func play_scroll_text(text: String) -> void:
	layer = 15   # above the normal HUD, below Battle's own layer (10 is Battle - this only ever plays outside combat, but staying above it costs nothing)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# CenterContainer, not manually-anchored offsets - see save_point_menu.gd
	# for why a hand-picked anchor/offset combo is the wrong tool here.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	label.modulate.a = 0.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(label)

	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.75, 0.6)
	# CenterContainer exclusively owns position. A y=0 animation here moves
	# its laid-out child to the screen's top rather than to the screen's center.
	tw.parallel().tween_property(label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(1.6)
	tw.tween_property(bg, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)
