# Non-blocking overlay beat: backdrop and text fade in, hold, fade out, then free.
class_name Cutscene
extends CanvasLayer

signal finished

func play_scroll_text(text: String) -> void:
	layer = 15  # above the HUD, below Battle (10)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# CenterContainer handles centering.
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
	# CenterContainer owns position, so don't animate y.
	tw.parallel().tween_property(label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(1.6)
	tw.tween_property(bg, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)
