class_name SwitchMinigameModal
extends CanvasLayer

# Opened by pressing E at the strong-enemy room's black switch box. A large
# centred panel (room for a minigame) with three parallel vertical white
# lines. One random portrait from each diver's pool appears in a row at the
# panel's top right, spaced the same as the lines, then each tweens across
# onto its line, then begin_travel() sets them all moving down their lines
# toward the big numbers 1-3 under the lines. Lines the player draws between
# two vertical lines snap into straight rungs; a portrait travelling down
# that reaches a rung's end on its line crosses the rung to the other line
# and carries on down from there (each rung once per portrait). A portrait
# coming down onto a portrait already settled at the bottom of its line
# bumps into it, rises clear, moves over to the nearest free line and keeps
# going down there. E starts it again (retry_requested), Esc closes it. The tree
# isn't paused - MazeLevel freezes itself while this is open instead, so its
# _input() can still see mouse presses (see contains_screen_point()).

signal closed
signal retry_requested                # E: start the puzzle again
signal portrait_arrived(index: int)   # a portrait settled at the bottom of a line
signal all_arrived                    # all three settled on different lines

const PANEL_SIZE := Vector2(1220, 700)   # nearly the whole 1280x720 view
const LINE_WIDTH := 4.0
const LINE_TOP := 150.0          # where the lines start, from the panel top
const LINE_BOTTOM_MARGIN := 90.0    # leaves room for the numbers below
const NUMBER_FONT_SIZE := 64
const NUMBER_GAP := 6.0             # line end -> number top
const TRAVEL_SPEED := 28.0          # px/s down the line
const PORTRAIT_SIZE := Vector2(88, 82)     # 410x384 at about 21%
const START_TOP := 48.0
const START_RIGHT_MARGIN := 24.0
const TWEEN_TIME := 0.8
const TWEEN_STAGGER := 0.15
const DRAW_WIDTH := 4.0
const DRAW_COLOR := Color(1.0, 0.85, 0.3)    # while the mouse is drawing
const RUNG_COLOR := Color.WHITE              # once snapped between two lines
const SNAP_DISTANCE := 45.0                  # px from a line's centre that counts as "on" it
const REJECT_COLOR := Color(1.0, 0.25, 0.25)  # flash for a line drawn too close to another
const MIN_RUNG_GAP := 40.0     # px: rung ends on the same line must be at least this far apart
const CROSS_SPEED := 160.0     # px/s along a rung
# A portrait coming down a line whose bottom is already taken bumps into
# the settled portrait (its foot this far above the line's bottom), then
# rises to DETOUR_CLEARANCE above that portrait's top and moves across to
# the nearest free line at that height (see _detour_to_free_lane()).
const BUMP_STEP := 70.0
const DETOUR_CLEARANCE := 10.0

const POOLS := [
	[
		"res://portraits/maxilani_pool/maxilani_01_normal.png",
		"res://portraits/maxilani_pool/maxilani_02_smile.png",
		"res://portraits/maxilani_pool/maxilani_03_eyes_closed.png",
		"res://portraits/maxilani_pool/maxilani_04_smirk.png",
		"res://portraits/maxilani_pool/maxilani_05_grimace.png",
		"res://portraits/maxilani_pool/maxilani_06_surprised.png",
		"res://portraits/maxilani_pool/maxilani_07_sad.png",
		"res://portraits/maxilani_pool/maxilani_08_wink.png",
	],
	[
		"res://portraits/bucky_pool/bucky_01_calm.png",
		"res://portraits/bucky_pool/bucky_02_grin.png",
		"res://portraits/bucky_pool/bucky_03_love.png",
		"res://portraits/bucky_pool/bucky_04_angry.png",
		"res://portraits/bucky_pool/bucky_05_crying.png",
		"res://portraits/bucky_pool/bucky_06_frown.png",
		"res://portraits/bucky_pool/bucky_07_bored.png",
		"res://portraits/bucky_pool/bucky_08_surprised.png",
	],
	[
		"res://portraits/musashi_pool/cyclops_01_calm.png",
		"res://portraits/musashi_pool/cyclops_02_wavy.png",
		"res://portraits/musashi_pool/cyclops_03_content.png",
		"res://portraits/musashi_pool/cyclops_04_grin.png",
		"res://portraits/musashi_pool/cyclops_05_angry.png",
		"res://portraits/musashi_pool/cyclops_06_surprised.png",
		"res://portraits/musashi_pool/cyclops_07_pout.png",
		"res://portraits/musashi_pool/cyclops_08_mystery.png",
	],
]

var panel: Panel
var line_xs: Array[float] = []      # each line's centre x, panel space
var portraits: Array[TextureRect] = []
var number_labels: Array[Label] = []
var traveling := false
# Per portrait: which line it's on now, whether it's mid-rung, whether it
# has settled at its stop, and the rungs it has already crossed.
var lane: Array[int] = [0, 1, 2]
var _crossing: Array[bool] = [false, false, false]
var _settled: Array[bool] = [false, false, false]
var _used_rungs: Array = [[], [], []]
# The line the mouse is drawing right now (null when not drawing), and every
# drawn line that snapped straight across between two vertical lines:
# {"node": Line2D, "from": line index, "to": line index, "from_y": y, "to_y": y}
# (panel space, from/to in the order they were drawn).
var _drawing_line: Line2D
var _rung_layer: Control   # drawn lines go here, under the portraits
var rungs: Array[Dictionary] = []
# Set by MazeLevel before this enters the tree: each diver's portrait (the
# same picture as their wall poster; null = a random one), and the clues
# from the posters already looked at: [{"texture", "number"}] - listed down
# the left side, portrait then the number it has to end up on.
var portrait_textures: Array = []
# Optional: the lane (0-2) each diver's portrait starts in - MazeLevel picks
# them so every portrait starts in a wrong lane. Empty = lane i for diver i.
var start_lanes: Array = []
var clue_entries: Array = []
var _result_label: Label

func _ready() -> void:
	layer = 90   # above the HUD captions, below CharacterAbilityPopup (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.13, 1.0)
	style.border_color = Color(0.45, 0.7, 0.85)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	add_child(panel)

	# Three lines at 1/4, 2/4, 3/4 of the panel's width.
	var spacing := PANEL_SIZE.x / 4.0
	for i in 3:
		var x := spacing * (i + 1)
		line_xs.append(x)
		var line := ColorRect.new()
		line.color = Color.WHITE
		line.position = Vector2(x - LINE_WIDTH * 0.5, LINE_TOP)
		line.size = Vector2(LINE_WIDTH, _line_bottom() - LINE_TOP)
		panel.add_child(line)
		# Its number, big, centred just under the line's bottom end.
		var number := Label.new()
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", NUMBER_FONT_SIZE)
		number.add_theme_color_override("font_color", Color.WHITE)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.size = Vector2(100, NUMBER_FONT_SIZE * 1.3)
		number.position = Vector2(x - 50.0, _line_bottom() + NUMBER_GAP)
		panel.add_child(number)
		number_labels.append(number)

	var hint := Label.new()
	hint.text = "E: try again    Esc: close"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	hint.position = Vector2(18, PANEL_SIZE.y - 30)
	panel.add_child(hint)

	_rung_layer = Control.new()
	_rung_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_rung_layer)

	# Portraits: a row at the top right, the same spacing as the lines,
	# the rightmost one START_RIGHT_MARGIN in from the panel's right edge.
	var row_right_x := PANEL_SIZE.x - START_RIGHT_MARGIN - PORTRAIT_SIZE.x * 0.5
	if start_lanes.size() == 3:
		for i in 3:
			lane[i] = int(start_lanes[i])
	for i in 3:
		var pool: Array = POOLS[i]
		var tex := load(pool[randi() % pool.size()]) as Texture2D
		if i < portrait_textures.size() and portrait_textures[i] is Texture2D:
			tex = portrait_textures[i]
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size = PORTRAIT_SIZE
		var start_center_x := row_right_x - spacing * (2 - lane[i])
		rect.position = Vector2(start_center_x - PORTRAIT_SIZE.x * 0.5, START_TOP)
		panel.add_child(rect)
		portraits.append(rect)

	var instruction := Label.new()
	instruction.text = "Swap the portraits to the right lanes!"
	instruction.add_theme_font_size_override("font_size", 24)
	instruction.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.position = Vector2(0, 10)
	instruction.size = Vector2(PANEL_SIZE.x, 32)
	panel.add_child(instruction)
	_build_clues()
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 26)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.position = Vector2(0, PANEL_SIZE.y - 46)
	_result_label.size = Vector2(PANEL_SIZE.x, 40)
	_result_label.visible = false
	panel.add_child(_result_label)
	_slide_onto_lines()

func _build_clues() -> void:
	if clue_entries.is_empty():
		return
	var box := VBoxContainer.new()
	box.position = Vector2(24, 52)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Clues"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0))
	box.add_child(title)
	for entry in clue_entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var pic := TextureRect.new()
		pic.texture = entry["texture"]
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = PORTRAIT_SIZE
		row.add_child(pic)
		var number := Label.new()
		number.text = str(entry["number"])
		number.add_theme_font_size_override("font_size", 52)
		number.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.custom_minimum_size = Vector2(44, PORTRAIT_SIZE.y)
		row.add_child(number)
		box.add_child(row)

# Shown once every portrait has settled.
# `placed`: for each portrait, whether it ended on its right lane - a green
# check or a red X goes beside each one.
func show_result(correct: bool, placed: Array = []) -> void:
	_result_label.text = "Correct!" if correct else "Not quite... (E to try again, Esc to close)"
	_result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45) if correct else Color(1.0, 0.4, 0.4))
	_result_label.visible = true
	for i in mini(placed.size(), portraits.size()):
		_add_mark(portraits[i], bool(placed[i]))

func set_result_text(text: String) -> void:
	_result_label.text = text

# A check or an X just right of a portrait's top corner.
func _add_mark(portrait: Control, right: bool) -> void:
	var at := portrait.position + Vector2(PORTRAIT_SIZE.x + 8, 8)
	var color := Color(0.3, 1.0, 0.45) if right else Color(1.0, 0.3, 0.3)
	var strokes: Array = [[Vector2(0, 14), Vector2(9, 24), Vector2(28, 0)]] if right else [[Vector2(0, 0), Vector2(24, 24)], [Vector2(24, 0), Vector2(0, 24)]]
	for stroke in strokes:
		var line := Line2D.new()
		line.width = 6.0
		line.default_color = color
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		for pt in stroke:
			line.add_point(at + (pt as Vector2))
		panel.add_child(line)

# Each portrait slides to sit centred on top of its line.
func _slide_onto_lines() -> void:
	var tw := create_tween().set_parallel(true)
	for i in portraits.size():
		var target := Vector2(line_xs[lane[i]] - PORTRAIT_SIZE.x * 0.5, LINE_TOP - PORTRAIT_SIZE.y - 6.0)
		tw.tween_property(portraits[i], "position", target, TWEEN_TIME) \
			.set_delay(TWEEN_STAGGER * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(begin_travel)

# Whether a viewport/screen position (e.g. a mouse press) is on the panel.
func contains_screen_point(point: Vector2) -> bool:
	return panel.get_global_rect().has_point(point)

# Left click on the modal: start a new line with just that first point.
# `point` is a viewport position (InputEventMouseButton.position).
func begin_lines_drawing(point: Vector2) -> void:
	clear_drawing_line()
	if not contains_screen_point(point):
		return
	_drawing_line = Line2D.new()
	_drawing_line.width = DRAW_WIDTH
	_drawing_line.default_color = DRAW_COLOR
	_drawing_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_drawing_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_drawing_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_drawing_line.add_point(_to_panel(point))
	_rung_layer.add_child(_drawing_line)

# Left button still held and the mouse moved: add a point at the new mouse
# position. Leaving the modal clears the line and its points.
func continue_lines_drawing(point: Vector2) -> void:
	if _drawing_line == null:
		return
	if not contains_screen_point(point):
		clear_drawing_line()
		return
	_drawing_line.add_point(_to_panel(point))


# Left button released. If the line starts near one vertical line and ends
# near the next one, with both ends within the lines' height, it's replaced
# by a straight line locked onto those two lines at the same heights, and
# kept in `rungs`. A longer line (past both, or across more than one gap)
# goes between the two neighbouring lines whose middle is nearest its
# centre, straight across at the centre's height. Otherwise it's cleared.
func finish_lines_drawing() -> void:
	if _drawing_line == null:
		return
	var start := _drawing_line.get_point_position(0)
	var end := _drawing_line.get_point_position(_drawing_line.get_point_count() - 1)
	var from := _line_near(start)
	var to := _line_near(end)
	var from_y := start.y
	var to_y := end.y
	if from == -1 or to == -1 or absi(from - to) != 1:
		# Not neatly from one line to the next (overshooting both, or
		# reaching across more than one gap): if it's long enough to mean
		# something, its centre decides - straight across between whichever
		# two neighbouring lines have their middle closest to it.
		var centre := (start + end) * 0.5
		var gap := line_xs[1] - line_xs[0]
		if absf(end.x - start.x) < gap * 0.6 or centre.y < LINE_TOP or centre.y > _line_bottom():
			clear_drawing_line()
			return
		var best := 0
		for k in line_xs.size() - 1:
			var mid := (line_xs[k] + line_xs[k + 1]) * 0.5
			if absf(centre.x - mid) < absf(centre.x - (line_xs[best] + line_xs[best + 1]) * 0.5):
				best = k
		# Started on the left = leads right, and the other way round.
		from = best if start.x <= end.x else best + 1
		to = best + 1 if start.x <= end.x else best
		from_y = centre.y
		to_y = centre.y
	var a := Vector2(line_xs[from], from_y)
	var b := Vector2(line_xs[to], to_y)
	if _too_close_to_a_rung(from, from_y, to, to_y, a, b):
		_reject_drawing_line(a, b)
		return
	_drawing_line.clear_points()
	_drawing_line.add_point(a)
	_drawing_line.add_point(b)
	_drawing_line.default_color = RUNG_COLOR
	var dir := (b - a).normalized()
	var head := Polygon2D.new()
	head.color = RUNG_COLOR
	var tip := b - dir * 6.0
	head.polygon = PackedVector2Array([tip, tip - dir * 16.0 + Vector2(-dir.y, dir.x) * 9.0, tip - dir * 16.0 - Vector2(-dir.y, dir.x) * 9.0])
	_drawing_line.add_child(head)
	rungs.append({"node": _drawing_line, "from": from, "to": to, "from_y": from_y, "to_y": to_y})
	_drawing_line = null   # kept on the panel as a rung

# A new rung may not end within MIN_RUNG_GAP of another rung's end on the
# same line, nor cross another rung.
func _too_close_to_a_rung(from: int, from_y: float, to: int, to_y: float, a: Vector2, b: Vector2) -> bool:
	for rung in rungs:
		for end in [[from, from_y], [to, to_y]]:
			var y := _rung_y_on(rung, end[0])
			if y != INF and absf(y - float(end[1])) < MIN_RUNG_GAP:
				return true
		var r_a := Vector2(line_xs[rung["from"]], rung["from_y"])
		var r_b := Vector2(line_xs[rung["to"]], rung["to_y"])
		if Geometry2D.segment_intersects_segment(a, b, r_a, r_b) != null:
			return true
	return false

# Where `rung` ends on line `line_index`, or INF if it doesn't end there.
func _rung_y_on(rung: Dictionary, line_index: int) -> float:
	if rung["from"] == line_index:
		return rung["from_y"]
	if rung["to"] == line_index:
		return rung["to_y"]
	return INF

# Shows the would-be rung (a to b) in red for a moment, then removes it.
func _reject_drawing_line(a: Vector2, b: Vector2) -> void:
	var line := _drawing_line
	_drawing_line = null
	line.clear_points()
	line.add_point(a)
	line.add_point(b)
	line.default_color = REJECT_COLOR
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.5)
	tw.tween_callback(line.queue_free)

func clear_drawing_line() -> void:
	if _drawing_line != null:
		_drawing_line.clear_points()
		_drawing_line.queue_free()
		_drawing_line = null

# Index of the vertical line `p` (panel space) is on: within SNAP_DISTANCE
# of its centre and between its top and bottom. -1 if none.
func _line_near(p: Vector2) -> int:
	if p.y < LINE_TOP or p.y > _line_bottom():
		return -1
	for i in line_xs.size():
		if absf(p.x - line_xs[i]) <= SNAP_DISTANCE:
			return i
	return -1

func _to_panel(point: Vector2) -> Vector2:
	return point - panel.global_position

func _line_bottom() -> float:
	return PANEL_SIZE.y - LINE_BOTTOM_MARGIN

# Starts every portrait moving down its line toward its number.
func begin_travel() -> void:
	traveling = true

# The y of a portrait's bottom-centre - the point that runs along the lines
# and rungs.
func _foot_y(i: int) -> float:
	return portraits[i].position.y + PORTRAIT_SIZE.y

func _set_foot(i: int, foot: Vector2) -> void:
	portraits[i].position = foot - Vector2(PORTRAIT_SIZE.x * 0.5, PORTRAIT_SIZE.y)

# Whether another portrait has already settled at the bottom of portrait
# i's line.
func _lane_taken(i: int) -> bool:
	for j in portraits.size():
		if j != i and _settled[j] and lane[j] == lane[i]:
			return true
	return false

# The line nearest portrait i's with no other portrait on it (ties go to
# the right), or -1 if every line has someone.
func _nearest_free_lane(i: int) -> int:
	var best := -1
	for l in line_xs.size():
		var used := false
		for j in portraits.size():
			if j != i and lane[j] == l:
				used = true
		if used:
			continue
		if best == -1 or absi(l - lane[i]) < absi(best - lane[i]) or (absi(l - lane[i]) == absi(best - lane[i]) and l > best):
			best = l
	return best

# The nearest rung end on portrait i's line strictly below its foot, that it
# hasn't crossed yet. {} if none.
func _next_rung(i: int) -> Dictionary:
	var best := {}
	var best_y := INF
	var foot := _foot_y(i)
	for rung in rungs:
		if (_used_rungs[i] as Array).has(rung):
			continue
		# A line only carries a portrait over if it was started in the lane
		# that portrait is in; meeting its other end, it carries on down.
		if int(rung["from"]) != lane[i]:
			continue
		var y := _rung_y_on(rung, lane[i])
		if y > foot + 0.01 and y <= _line_bottom() + 0.01 and y < best_y:
			best_y = y
			best = rung
	return best

func _process(dt: float) -> void:
	if not traveling:
		return
	for i in portraits.size():
		if _crossing[i] or _settled[i]:
			continue
		var rung := _next_rung(i)
		var taken := _lane_taken(i)
		var stop := _line_bottom() - BUMP_STEP if taken else _line_bottom()
		var target := stop if rung.is_empty() else minf(_rung_y_on(rung, lane[i]), stop)
		# A portrait that crossed onto a taken line below the bump point
		# reacts where it is rather than moving back up first.
		target = maxf(target, _foot_y(i))
		var foot := minf(_foot_y(i) + TRAVEL_SPEED * dt, target)
		_set_foot(i, Vector2(line_xs[lane[i]], foot))
		if foot < target:
			continue
		if not rung.is_empty() and is_equal_approx(target, _rung_y_on(rung, lane[i])):
			_cross_rung(i, rung)
		elif taken:
			_detour_to_free_lane(i)
		else:
			_settled[i] = true
			portrait_arrived.emit(i)
	if not _settled.has(false) and _all_on_different_lines():
		traveling = false
		all_arrived.emit()

# Portrait i has bumped into the portrait settled at the bottom of its line:
# it rises clear of that portrait, moves across to the nearest free line,
# and is then free to carry on down (and take rungs) there.
func _detour_to_free_lane(i: int) -> void:
	var free := _nearest_free_lane(i)
	if free == -1:
		return
	_crossing[i] = true
	portraits[i].move_to_front()
	var start := Vector2(line_xs[lane[i]], _foot_y(i))
	var above := Vector2(start.x, minf(start.y, _line_bottom() - PORTRAIT_SIZE.y - DETOUR_CLEARANCE))
	var across := Vector2(line_xs[free], above.y)
	var tw := create_tween()
	tw.tween_method(func(f: Vector2) -> void: _set_foot(i, f), start, above, start.distance_to(above) / CROSS_SPEED)
	tw.tween_method(func(f: Vector2) -> void: _set_foot(i, f), above, across, above.distance_to(across) / CROSS_SPEED)
	tw.tween_callback(func() -> void:
		lane[i] = free
		_crossing[i] = false)

func _all_on_different_lines() -> bool:
	return lane[0] != lane[1] and lane[1] != lane[2] and lane[0] != lane[2]

# Slides portrait i along `rung` to its end on the other line.
func _cross_rung(i: int, rung: Dictionary) -> void:
	(_used_rungs[i] as Array).append(rung)
	_crossing[i] = true
	var other: int = rung["to"] if rung["from"] == lane[i] else rung["from"]
	var start := Vector2(line_xs[lane[i]], _foot_y(i))
	var end := Vector2(line_xs[other], _rung_y_on(rung, other))
	var tw := create_tween()
	tw.tween_method(func(f: Vector2) -> void: _set_foot(i, f), start, end, start.distance_to(end) / CROSS_SPEED)
	tw.tween_callback(func() -> void:
		lane[i] = other
		_crossing[i] = false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif (event as InputEventKey).keycode == KEY_E:
			get_viewport().set_input_as_handled()
			retry_requested.emit()

func close() -> void:
	closed.emit()
	queue_free()
