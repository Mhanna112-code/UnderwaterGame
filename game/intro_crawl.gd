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

const SCROLL_DURATION := 26.0
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
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = false
	finished.emit()
