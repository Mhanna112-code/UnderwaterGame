# Circular overhead map centred on the active diver, redrawn every frame in _draw().
# Reads World's divers/_wall_pieces live; only pieces World has marked "revealed" are drawn.
class_name MiniMap
extends Control

var world: World

@export var view_radius := 22.0   # world units shown at the panel's edge

func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	clip_contents = true

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if world == null or world.divers.is_empty():
		return

	var divers: Array = world.divers
	var active: int = world.active
	var center: Vector3 = (divers[active] as Diver).global_position
	var r: float = size.x * 0.5
	var mid := Vector2(r, r)
	var px_per_unit: float = r / view_radius

	draw_circle(mid, r, Color(0.03, 0.06, 0.08, 0.88))
	draw_arc(mid, r - 1.5, 0.0, TAU, 48, Color(0.5, 0.72, 0.8, 0.55), 1.5)

	_draw_lines_at_overlapping_areas(center, px_per_unit, mid)

	for i in range(divers.size()):
		var d: Diver = divers[i]
		# Plain cull for points; the active diver is always at the centre.
		if i != active and center.distance_to(d.global_position) > view_radius:
			continue
		var p := _project(d.global_position, center, px_per_unit, mid)
		if i == active:
			var fwd: Vector3 = -d.global_transform.basis.z
			_draw_arrow(p, Vector2(fwd.x, fwd.z))
		else:
			draw_circle(p, 4.0, Color(0.85, 0.8, 0.3))

	_draw_key_item_markers(center, r, px_per_unit, mid)

# Draws only revealed wall pieces, so corridors appear gradually.
func _draw_lines_at_overlapping_areas(center: Vector3, px_per_unit: float, mid: Vector2) -> void:
	for piece in world._wall_pieces:
		if not bool(piece.revealed):
			continue
		var a: Vector3 = piece.line_a
		var b: Vector3 = piece.line_b
		var rel_a: Vector2 = Vector2(a.x, a.z) - Vector2(center.x, center.z)
		var rel_b: Vector2 = Vector2(b.x, b.z) - Vector2(center.x, center.z)
		var clipped: Array = _clip_to_circle(rel_a, rel_b, view_radius)
		if clipped.is_empty():
			continue
		draw_line(
			mid + (clipped[0] as Vector2) * px_per_unit,
			mid + (clipped[1] as Vector2) * px_per_unit,
			Color(0.6, 0.64, 0.68, 0.9), 2.0
		)

# Revealed, unclaimed key items pulse red: a dot in range, else a rim arrow. Shown only while sonar is on.
const MARKER_PULSE_SPEED := 3.0
# Red markers show only within this vertical distance (metres) of the diver.
const MARKER_HEIGHT_RANGE := 1.5

static func within_marker_height(viewer_y: float, marker_y: float) -> bool:
	return absf(viewer_y - marker_y) <= MARKER_HEIGHT_RANGE

# Sonar lives on the diver with passive_id "sonar", not necessarily the active one.
func _sonar_currently_active() -> bool:
	for d in world.divers:
		if (d as Diver).passive_id == "sonar":
			return (d as Diver).sonar_active
	return false

func _draw_key_item_markers(center: Vector3, r: float, px_per_unit: float, mid: Vector2) -> void:
	if not _sonar_currently_active():
		return
	var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * MARKER_PULSE_SPEED)
	var marker_color := Color(0.95, 0.15, 0.15, pulse)
	_draw_item_rock_markers(center, px_per_unit, mid, marker_color)
	for entry in ItemGuardian.spots():
		var item_id := String(entry.item)
		# Only beating the site's enemy and winning its item clears the circle.
		if world.cleared_item_sites.has(String(entry.get("site", item_id))) or not world.revealed_key_items.has(item_id):
			continue
		var pos: Vector3 = entry.at
		if not within_marker_height(center.y, pos.y):
			continue
		var rel := Vector2(pos.x, pos.z) - Vector2(center.x, center.z)
		var dist: float = maxf(rel.length(), 0.01)   # guards the /dist normalize below
		if dist <= view_radius:
			# Item encounters are the larger circle; item rocks are small solid circles.
			draw_circle(mid + rel * px_per_unit, 5.5, marker_color)
			draw_arc(mid + rel * px_per_unit, 5.5, 0.0, TAU, 20, Color(1.0, 0.75, 0.75, pulse), 1.2)
		else:
			var dir := rel / dist
			_draw_marker_arrow(mid + dir * (r - 8.0), dir, marker_color)

# Unbroken item-holding rocks (not ambush rocks), sonar-gated, in-radius only.
func _draw_item_rock_markers(center: Vector3, px_per_unit: float, mid: Vector2, color: Color) -> void:
	for id in world._cracked_walls:
		if not String(id).begins_with("rock_") or id in World.ROCK_AMBUSH_IDS:
			continue
		var rock := world._cracked_walls[id] as Node3D
		if not is_instance_valid(rock) or rock.is_queued_for_deletion():
			continue
		if not within_marker_height(center.y, rock.global_position.y):
			continue
		var rel := Vector2(rock.global_position.x, rock.global_position.z) - Vector2(center.x, center.z)
		if rel.length() <= view_radius:
			draw_circle(mid + rel * px_per_unit, 3.5, color)

# Rim-pinned arrow toward an out-of-range key item.
func _draw_marker_arrow(p: Vector2, facing: Vector2, color: Color) -> void:
	var side := Vector2(-facing.y, facing.x)
	var tip := p + facing * 5.0
	var back_l := p - facing * 3.0 + side * 3.0
	var back_r := p - facing * 3.0 - side * 3.0
	draw_polygon(PackedVector2Array([tip, back_l, back_r]), PackedColorArray([color]))

func _project(pos: Vector3, center: Vector3, px_per_unit: float, mid: Vector2) -> Vector2:
	return mid + Vector2(pos.x - center.x, pos.z - center.z) * px_per_unit

# Clips segment rel_a->rel_b to the circle of `radius` at the origin; [] if outside.
func _clip_to_circle(rel_a: Vector2, rel_b: Vector2, radius: float) -> Array:
	var d: Vector2 = rel_b - rel_a
	var dd: float = d.dot(d)
	if dd < 0.000001:
		return [rel_a, rel_b] if rel_a.length() <= radius else []
	var b_coef: float = 2.0 * rel_a.dot(d)
	var c_coef: float = rel_a.dot(rel_a) - radius * radius
	var disc: float = b_coef * b_coef - 4.0 * dd * c_coef
	if disc < 0.0:
		return []   # the line never comes within radius of the center at all
	var sq: float = sqrt(disc)
	var t1: float = (-b_coef - sq) / (2.0 * dd)
	var t2: float = (-b_coef + sq) / (2.0 * dd)
	var lo: float = maxf(t1, 0.0)
	var hi: float = minf(t2, 1.0)
	if lo > hi:
		return []   # in-circle range and segment range don't overlap
	return [rel_a + d * lo, rel_a + d * hi]

# The active diver is an arrow so its facing is visible.
func _draw_arrow(p: Vector2, facing: Vector2) -> void:
	if facing.length() < 0.01:
		facing = Vector2(0, -1)
	facing = facing.normalized()
	var side := Vector2(-facing.y, facing.x)
	var tip := p + facing * 7.0
	var back_l := p - facing * 4.0 + side * 4.5
	var back_r := p - facing * 4.0 - side * 4.5
	draw_polygon(
		PackedVector2Array([tip, back_l, back_r]),
		PackedColorArray([Color(0.35, 0.95, 0.55)])
	)
