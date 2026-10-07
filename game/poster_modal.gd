class_name PosterModal
extends CanvasLayer

# Close-up of a maze wall poster (MazePoster) with its number under the portrait.
# Closed by the X button or Esc.

signal closed

# 330 wide = MazePoster.ART_BASE * 1.1; tall enough for the portrait frame
# (ends at 259 base units) plus the number under it.
const ART_SIZE := Vector2(330, 392)
const NUMBER_FONT_SIZE := 96
const INK := Color(0.12, 0.14, 0.3)
const PAD := 24.0

var poster: MazePoster

func _init(for_poster: MazePoster) -> void:
	poster = for_poster

func _ready() -> void:
	layer = 90   # above the HUD captions, below CharacterAbilityPopup (100)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel_size := Vector2(ART_SIZE.x + PAD * 2.0, ART_SIZE.y + PAD * 2.0)
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.13, 1.0)
	style.border_color = Color(0.45, 0.7, 0.85)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	add_child(panel)

	var art := MazePoster.build_art(ART_SIZE, poster.portrait, poster.scribble_seed, false)
	art.position = Vector2(PAD, PAD)
	panel.add_child(art)

	# The number, in ink on the paper, right under the portrait frame.
	var k := ART_SIZE.x / MazePoster.ART_BASE.x
	var frame_bottom := 259.0 * k
	var number := Label.new()
	number.text = str(poster.number)
	number.add_theme_font_size_override("font_size", NUMBER_FONT_SIZE)
	number.add_theme_color_override("font_color", INK)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.position = Vector2(0, frame_bottom)
	number.size = Vector2(ART_SIZE.x, ART_SIZE.y - frame_bottom)
	art.add_child(number)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.size = Vector2(36, 36)
	close_button.position = Vector2(panel_size.x - 36 - 8, 8)
	close_button.pressed.connect(close)
	panel.add_child(close_button)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	closed.emit()
	queue_free()
