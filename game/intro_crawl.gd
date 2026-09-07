# Shown once, right after a brand-new game actually starts (see world.gd's
# _on_title_new_game()) - a black screen with the game's opening story
# scrolling upward, Star-Wars-crawl style. Never shown on Load Game or a
# "Return to Title" replay of the title screen - a returning player has
# already read this once, and a save always resumes past this point.
# Same "paused but interactive" shape as TitleScreen/GameOverScreen/
# SpecialEncounterPrompt (process_mode ALWAYS so input still works while
# get_tree().paused freezes the world underneath), built in code with no
# .tscn, same convention as those three.
class_name IntroCrawl
extends Control

signal finished

const SCROLL_DURATION := 30.0
const TEXT_WIDTH := 560.0

const STORY_TEXT := "Three strangers, one dive site.\n\nA drifter who grew up more at home in open water than on land. A boy who ran out of reasons to stay on the surface. A soldier with nothing left topside worth defending.\n\nNone of them chose each other. Each of them had already lost everything a normal life was supposed to give - and each had heard the same rumor: that somewhere in the drowned dark below, there was treasure enough to buy it all back.\n\nThe ocean does not care what brought you to it. It only asks what you're willing to lose to leave with something.\n\nThey went down anyway."

var _text_label: Label
var _tween: Tween
var _done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# STOP, not IGNORE - a click anywhere on screen is a valid way to skip,
	# same reasoning as the skip hint label below.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_text_label = Label.new()
	_text_label.text = STORY_TEXT
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.add_theme_font_size_override("font_size", 22)
	_text_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.95))
	# Anchored to horizontal-center, top=0 - offset_top/offset_bottom (set
	# once real layout size is known, see _start_scroll()) are what actually
	# animate to produce the scroll; left/right stay fixed so wrapping
	# width never changes mid-scroll.
	_text_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_text_label.offset_left = -TEXT_WIDTH * 0.5
	_text_label.offset_right = TEXT_WIDTH * 0.5
	add_child(_text_label)

	var skip_hint := Label.new()
	skip_hint.text = "Press E or click to skip"
	skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hint.offset_left = -220.0
	skip_hint.offset_top = -32.0
	skip_hint.offset_right = -16.0
	skip_hint.offset_bottom = -8.0
	skip_hint.add_theme_font_size_override("font_size", 14)
	skip_hint.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))
	add_child(skip_hint)

"""
func _build_tutorial_panel() -> Control:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)

	var heading := Label.new()
	heading.text = "Choose who goes"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	col.add_child(heading)

	# Left arrow / 3D preview / right arrow, side by side - the preview
	# itself is a small SubViewport with its own camera and one live Diver
	# instance, same recipe battle.gd's own stage uses (SubViewportContainer
	# + SubViewport + Camera3D + Diver.new()), just facing the camera
	# instead of facing away (battle's party puppets show their backs to
	# the camera on purpose - a showcase screen wants the opposite).
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)

	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(280, 260)
	preview_container.stretch = true
	row.add_child(preview_container)

	var cam := Camera3D.new()
	cam.fov = 55.0

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(_name_label)


	var button_row := HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button_row.add_theme_constant_override("separation", 12)
	col.add_child(button_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "Send Them In"
	confirm_btn.custom_minimum_size = Vector2(180, 40)
	confirm_btn.pressed.connect(func() -> void: diver_chosen.emit(String(ROSTER[_carousel_index])))
	button_row.add_child(confirm_btn)

	return col
"""


func open() -> void:
	visible = true
	_done = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Deferred so the label has actually gone through one layout pass first
	# - get_combined_minimum_size() below needs its real wrapped height,
	# which isn't known until the width set in _ready() has been applied.
	call_deferred("_start_scroll")

# Starts just below the bottom edge and scrolls up until fully past the
# top - both edges of the label move together at the same rate (a plain
# vertical scroll, not a receding-into-the-distance crawl; simpler, and
# still reads as "rolling text" without needing a 3D-perspective label).
func _start_scroll() -> void:
	var vp_height: float = get_viewport_rect().size.y
	var text_height: float = _text_label.get_combined_minimum_size().y
	_text_label.offset_top = vp_height
	_text_label.offset_bottom = vp_height + text_height
	var target_top: float = -text_height - 40.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_text_label, "offset_top", target_top, SCROLL_DURATION)
	_tween.tween_property(_text_label, "offset_bottom", target_top + text_height, SCROLL_DURATION)
	_tween.set_parallel(false)
	_tween.tween_callback(_finish)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _done:
		return
	var is_skip_key: bool = event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_E
	var is_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if is_skip_key or is_click:
		# MODIFIED (added): this E press (or click) was consumed right here
		# to skip the intro - without marking it handled, the SAME event
		# kept propagating to every other _unhandled_input() in the tree,
		# including world.gd's, which fires _start_ability() unconditionally
		# on E. That's why skipping the intro with E also fired Maxilani's
		# swap ability the instant the world loaded underneath it.
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false
	finished.emit()
