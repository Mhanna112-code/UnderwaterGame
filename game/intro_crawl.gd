# Opening story crawl shown once on New Game (never on Load). Paused-but-interactive overlay.
class_name IntroCrawl
extends Control

signal finished

const TEXT_WIDTH := 560.0
# Scroll speed sized so each line stays readable; the crawl lengthens on short viewports.
const MIN_SCROLL_DURATION := 55.0
const MIN_LINE_VISIBLE_SECONDS := 30.0
const SCROLL_EXIT_PADDING := 40.0

const STORY_TEXT := "Three strangers, one dive site.\n\nA drifter who grew up more at home in open water than on land. A boy who ran out of reasons to stay on the surface. A soldier with nothing left topside worth defending.\n\nNone of them chose each other. Each of them had already lost everything a normal life was supposed to give - and each had heard the same rumor: that somewhere in the drowned dark below, there was treasure enough to buy it all back.\n\nThe ocean does not care what brought you to it. It only asks what you're willing to lose to leave with something.\n\nThey went down anyway."

var _text_label: Label
var _tween: Tween
var _done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# IGNORE so clicks reach _unhandled_input() (the skip handler).
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	# offset_top/bottom animate the scroll; left/right stay fixed so wrap width doesn't change.
	_text_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_text_label.offset_left = -TEXT_WIDTH * 0.5
	_text_label.offset_right = TEXT_WIDTH * 0.5
	# Children default to STOP too; IGNORE so clicks on the text still skip.
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_label)

	var skip_hint := Label.new()
	skip_hint.text = "Press E or click to skip"
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# Deferred so the wrapped height is known.
	call_deferred("_start_scroll")

# Plain vertical scroll from below the bottom edge to past the top.
func _start_scroll() -> void:
	var vp_height: float = get_viewport_rect().size.y
	var text_height: float = _text_label.get_combined_minimum_size().y
	_text_label.offset_top = vp_height
	_text_label.offset_bottom = vp_height + text_height
	var target_top: float = -text_height - SCROLL_EXIT_PADDING
	var scroll_duration := readable_scroll_duration(vp_height, text_height)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_text_label, "offset_top", target_top, scroll_duration)
	_tween.tween_property(_text_label, "offset_bottom", target_top + text_height, scroll_duration)
	_tween.set_parallel(false)
	_tween.tween_callback(_finish)

# Duration grows with travel distance so each line stays on screen long enough (used by verification).
static func readable_scroll_duration(viewport_height: float, text_height: float) -> float:
	var safe_viewport := maxf(1.0, viewport_height)
	var total_distance := safe_viewport + maxf(0.0, text_height) + SCROLL_EXIT_PADDING
	var duration_for_line_window := MIN_LINE_VISIBLE_SECONDS * total_distance / safe_viewport
	return maxf(MIN_SCROLL_DURATION, duration_for_line_window)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _done:
		return
	var is_skip_key: bool = event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_E
	var is_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if is_skip_key or is_click:
		# Mark handled so the skip press doesn't also trigger world.gd's E ability.
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
