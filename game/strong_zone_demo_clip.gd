class_name StrongZoneDemoClip
extends Control

# A looping little map for the "Strong enemy encounters" popup: a few maze
# walls, the strong encounter zone flashing red the way it does on the real
# maps, and the player's green arrow swimming into it. Runs while the tree is
# paused (the popup pauses it).

const LOOP := 5.0
const WALL_COLOR := Color(0.6, 0.64, 0.68, 0.9)
const ZONE_COLOR := Color(1.0, 0.15, 0.15)
const YOU_COLOR := Color(0.35, 0.95, 0.55)

var _t := 0.0

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	_t = fmod(_t + dt, LOOP)
	queue_redraw()

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.06, 0.08))
	# The zone, flashing.
	var zone := Rect2(s.x * 0.45, s.y * 0.18, s.x * 0.42, s.y * 0.5)
	var pulse := 0.5 + 0.5 * sin(_t * TAU * 1.2)
	draw_rect(zone, Color(ZONE_COLOR, 0.12 + 0.28 * pulse))
	draw_rect(zone, Color(ZONE_COLOR, 0.5 + 0.5 * pulse), false, 2.0)
	# Some walls: a corridor leading up into the zone, and its sides.
	var w := 2.0
	draw_line(Vector2(s.x * 0.12, s.y * 0.82), Vector2(s.x * 0.55, s.y * 0.82), WALL_COLOR, w)
	draw_line(Vector2(s.x * 0.12, s.y * 0.95), Vector2(s.x * 0.68, s.y * 0.95), WALL_COLOR, w)
	draw_line(Vector2(s.x * 0.55, s.y * 0.82), Vector2(s.x * 0.55, s.y * 0.68), WALL_COLOR, w)
	draw_line(Vector2(s.x * 0.68, s.y * 0.95), Vector2(s.x * 0.68, s.y * 0.68), WALL_COLOR, w)
	draw_line(zone.position, Vector2(zone.end.x, zone.position.y), WALL_COLOR, w)
	draw_line(zone.position, Vector2(zone.position.x, zone.end.y), WALL_COLOR, w)
	draw_line(Vector2(zone.end.x, zone.position.y), zone.end, WALL_COLOR, w)
	# You: along the corridor, then up into the zone.
	var path := [Vector2(s.x * 0.18, s.y * 0.885), Vector2(s.x * 0.615, s.y * 0.885), Vector2(s.x * 0.615, s.y * 0.4)]
	var f := clampf(_t / (LOOP * 0.8), 0.0, 1.0)
	var leg1 := (path[0] as Vector2).distance_to(path[1])
	var leg2 := (path[1] as Vector2).distance_to(path[2])
	var d := f * (leg1 + leg2)
	var p: Vector2
	var dir: Vector2
	if d <= leg1:
		p = (path[0] as Vector2).lerp(path[1], d / leg1)
		dir = Vector2.RIGHT
	else:
		p = (path[1] as Vector2).lerp(path[2], (d - leg1) / leg2)
		dir = Vector2.UP
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([p + dir * 8.0, p - dir * 5.0 + side * 5.5, p - dir * 5.0 - side * 5.5]), YOU_COLOR)
	if zone.has_point(p):
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, s.y * 0.13), "Strong encounters here!", HORIZONTAL_ALIGNMENT_CENTER, s.x, 13, Color(1.0, 0.55, 0.45))
