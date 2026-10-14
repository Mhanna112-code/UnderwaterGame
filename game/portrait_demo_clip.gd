class_name PortraitDemoClip
extends Control

# Live-drawn looping demo of the portrait minigame for the explainer popup.
# Portraits follow lines started in their lane and shift to the nearest free lane; runs while paused.

const LOOP := 10.0
const DRAW_1 := Vector2(0.6, 1.5)    # [start, end] of drawing the first line
const DRAW_2 := Vector2(1.8, 2.7)
const DROP_START := 3.0              # first portrait starts falling
const DROP_EACH := 2.0               # seconds per portrait's fall
const PORTRAIT := Vector2(30, 28)
const LINE_COLOR := Color.WHITE
const DRAW_COLOR := Color(1.0, 0.85, 0.3)

var textures: Array = []   # three portraits (Texture2D or null)
var _t := 0.0
var _routes: Array = []    # per portrait, its path (rebuilt if the size changes)
var _routes_size := Vector2.ZERO

func _init(portrait_textures: Array = []) -> void:
	textures = portrait_textures
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	_t = fmod(_t + dt, LOOP)
	queue_redraw()

func _lane_x(i: int) -> float:
	return size.x * (0.25 + 0.25 * i)

func _top() -> float:
	return 14.0 + PORTRAIT.y

func _bottom() -> float:
	return size.y - 26.0

# The two lines: [from lane (where it was started), to lane, height].
func _rungs() -> Array:
	return [[0, 1, lerpf(_top(), _bottom(), 0.35)], [1, 2, lerpf(_top(), _bottom(), 0.62)]]

# Each portrait's path: down its lane, across lines started there, then to the nearest free lane.
func _build_routes() -> void:
	_routes.clear()
	_routes_size = size
	var taken: Array[int] = []
	for start in 3:
		var lane := start
		var pts := PackedVector2Array([Vector2(_lane_x(lane), _top())])
		for r in _rungs():
			if int(r[0]) == lane:
				pts.append(Vector2(_lane_x(lane), float(r[2])))
				lane = int(r[1])
				pts.append(Vector2(_lane_x(lane), float(r[2])))
		var bump_y := _bottom() - PORTRAIT.y - 8.0
		if taken.has(lane):
			var free := -1
			for l in 3:
				if not taken.has(l) and (free == -1 or absi(l - lane) < absi(free - lane) or (absi(l - lane) == absi(free - lane) and l > free)):
					free = l
			pts.append(Vector2(_lane_x(lane), bump_y))
			lane = free
			pts.append(Vector2(_lane_x(lane), bump_y))
		pts.append(Vector2(_lane_x(lane), _bottom()))
		taken.append(lane)
		_routes.append(pts)

func _along(pts: PackedVector2Array, f: float) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var want := total * clampf(f, 0.0, 1.0)
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if want <= seg:
			return pts[i].lerp(pts[i + 1], want / maxf(seg, 0.001))
		want -= seg
	return pts[pts.size() - 1]

# Wobbly hand-drawn stroke from a to b; `n` varies the wobble.
func _hand_point(a: Vector2, b: Vector2, u: float, n: int) -> Vector2:
	var slant := (u - 0.5) * (10.0 if n == 0 else -12.0)
	var wobble := sin(u * TAU * 1.5 + n) * 4.0
	return a.lerp(b, u) + Vector2(0, slant + wobble)

func _draw() -> void:
	if _routes.is_empty() or _routes_size != size:
		_build_routes()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.08, 0.13))
	for i in 3:
		var x := _lane_x(i)
		draw_line(Vector2(x, _top()), Vector2(x, _bottom()), LINE_COLOR, 2.0)
		draw_string(font, Vector2(x - 5, size.y - 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, LINE_COLOR)
	# Lines drawn by hand, then snapping straight with an arrowhead.
	var cursor := Vector2(-100, -100)
	var rungs := _rungs()
	for n in 2:
		var span := DRAW_1 if n == 0 else DRAW_2
		var a := Vector2(_lane_x(int(rungs[n][0])), float(rungs[n][2]))
		var b := Vector2(_lane_x(int(rungs[n][1])), float(rungs[n][2]))
		var f := clampf((_t - span.x) / (span.y - span.x), 0.0, 1.0)
		if _t < span.x:
			continue
		if _t >= span.y:
			draw_line(a, b, LINE_COLOR, 2.5)
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			var tip := b - dir * 3.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 8.0 + side * 5.0, tip - dir * 8.0 - side * 5.0]), LINE_COLOR)
			var since := _t - span.y
			if since < 0.35:
				draw_line(a, b, Color(1, 1, 1, 1.0 - since / 0.35), 6.0)
			continue
		var stroke := PackedVector2Array()
		for k in 21:
			stroke.append(_hand_point(a, b, f * k / 20.0, n))
		draw_polyline(stroke, DRAW_COLOR, 2.5)
		cursor = _hand_point(a, b, f, n)
	# Portraits: waiting at the top, then each falling in turn.
	for i in 3:
		var fall := clampf((_t - DROP_START - DROP_EACH * i) / DROP_EACH, 0.0, 1.0)
		var p := _along(_routes[i], fall)
		var r := Rect2(p - Vector2(PORTRAIT.x * 0.5, PORTRAIT.y), PORTRAIT)
		if i < textures.size() and textures[i] is Texture2D:
			draw_texture_rect(textures[i], r, false)
		else:
			draw_rect(r, [Color(0.85, 0.4, 0.4), Color(0.4, 0.6, 0.95), Color(0.95, 0.7, 0.3)][i])
		draw_rect(r, Color(1, 1, 1, 0.6), false, 1.0)
	# The mouse while it draws.
	if cursor.x > -50:
		var tip := cursor
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(0, 13), tip + Vector2(4, 10), tip + Vector2(9, 9)]), Color.WHITE)
		draw_string(font, tip + Vector2(10, 18), "click + drag", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DRAW_COLOR)
