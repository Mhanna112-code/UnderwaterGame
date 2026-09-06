# A circular overhead readout centered on whichever diver is active,
# redrawn from scratch every frame via _draw() rather than managed as a
# pile of repositioned child nodes - circles, a rotated arrow, and
# variable-length wall lines are all one draw call each this way, and
# nothing needs to be created/destroyed as walls come in and out of range.
#
# Holds a reference to world.gd itself rather than copies of its data -
# divers/_wall_pieces live there and change over time (new walls could
# be built later, divers move every frame); reading them live means this
# never needs to be told to refresh, it just always reflects however the
# world actually looks right now. Each _wall_pieces entry carries its own
# "revealed" flag (fog of war): World's own detection area
# (_update_wall_visibility(), sized to this exact view_radius - see
# _build_wall_sight_area()) is what actually reveals a piece, this just
# reads whether that's happened yet before drawing it - see
# _draw_lines_at_overlapping_areas().
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
		# A point can't be partially clipped like a wall segment can - it's
		# either within view_radius or it isn't, so this is a plain cull
		# rather than a geometric clip. The active diver is always at
		# distance 0 from itself (it *is* center), so this can only ever
		# skip one of the other two.
		if i != active and center.distance_to(d.global_position) > view_radius:
			continue
		var p := _project(d.global_position, center, px_per_unit, mid)
		if i == active:
			var fwd: Vector3 = -d.global_transform.basis.z
			_draw_arrow(p, Vector2(fwd.x, fwd.z))
		else:
			draw_circle(p, 4.0, Color(0.85, 0.8, 0.3))

	_draw_key_item_markers(center, r, px_per_unit, mid)

# Draws only the wall PIECES World's own detection area has actually
# found (see World._wall_pieces/_update_wall_visibility()) - not whole
# walls, so a long corridor lights up gradually as you swim its length
# rather than all at once the moment any part of it is found. Each
# revealed piece is still clipped to the circle itself, not just culled
# by whole segment - a piece with one endpoint inside view_radius and one
# well outside it would otherwise draw straight through the rim into the
# square panel's corner space (clip_contents only clips to the panel's
# rectangle, not the circle drawn inside it). _clip_to_circle solves for
# where the piece actually crosses the view_radius boundary and only the
# portion inside gets drawn.
func _draw_lines_at_overlapping_areas(center: Vector3, px_per_unit: float, mid: Vector2) -> void:
	for piece in world._wall_pieces:
		if not bool(piece.revealed):
			continue
		var a: Vector3 = piece.a
		var b: Vector3 = piece.b
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

# One pulsing red marker per key-item zone (ItemGuardian.spots()) sonar has
# ever revealed (World.revealed_key_items) that hasn't been claimed yet
# (World.key_items) - a dot at its real position if that's within
# view_radius of the map center, otherwise a small arrow pinned to the
# rim and pointing toward it, so a revealed item never just disappears
# for being far away (the plain-cull the diver dots above use would do
# exactly that). Drawn after the diver dots, on top, since a revealed
# item is more actionable information than a background NPC diver.
#
# Only actually drawn while sonar is currently ON, though
# (_sonar_currently_active() below) - revealed_key_items is permanent
# memory (an id never leaves it just because sonar turned off), but the
# minimap markers themselves are meant to read as "sonar is showing you
# this right now," not "sonar has ever shown you this" - toggling off
# hides both the dot and the arrow immediately, toggling back on brings
# back whatever's already been revealed with no re-ping needed.
const MARKER_PULSE_SPEED := 3.0

# Sonar lives on whichever Diver has passive_id == "sonar" (Maxilani), not
# necessarily divers[active] - sonar_active persists on her own instance
# even after TAB-switching to someone else, since _physics_process() runs
# on every diver node independently regardless of which one's currently
# steered. So this has to search for her rather than just checking
# world.divers[world.active].
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
	for entry in ItemGuardian.spots():
		var item_id := String(entry.item)
		if world.key_items.has(item_id) or not world.revealed_key_items.has(item_id):
			continue
		var pos: Vector3 = entry.at
		var rel := Vector2(pos.x, pos.z) - Vector2(center.x, center.z)
		var dist: float = maxf(rel.length(), 0.01)   # guards the /dist normalize below
		if dist <= view_radius:
			draw_circle(mid + rel * px_per_unit, 5.0, marker_color)
		else:
			# RESTORED: this branch had gone missing, leaving
			# _draw_marker_arrow() defined but never called - an
			# out-of-range revealed item drew nothing at all instead of
			# the rim arrow the comment above already promised.
			var dir := rel / dist
			_draw_marker_arrow(mid + dir * (r - 8.0), dir, marker_color)

# Same small-triangle shape _draw_arrow() below uses for the active
# diver, just parameterized on color/facing instead of hardcoded green
# and diver-sized - this one's a rim-pinned pointer toward an
# out-of-range key item, not a "this is you" marker.
func _draw_marker_arrow(p: Vector2, facing: Vector2, color: Color) -> void:
	var side := Vector2(-facing.y, facing.x)
	var tip := p + facing * 5.0
	var back_l := p - facing * 3.0 + side * 3.0
	var back_r := p - facing * 3.0 - side * 3.0
	draw_polygon(PackedVector2Array([tip, back_l, back_r]), PackedColorArray([color]))

func _project(pos: Vector3, center: Vector3, px_per_unit: float, mid: Vector2) -> Vector2:
	return mid + Vector2(pos.x - center.x, pos.z - center.z) * px_per_unit

# Solves for the portion of segment rel_a->rel_b (both already relative to
# the map's center, in world units) that actually lies within radius of
# the origin - [] if none of it does. Standard line/circle clip:
# parametrize the segment as rel_a + t*(rel_b - rel_a), t in [0, 1], and
# solve |point|^2 == radius^2 for t. That's a quadratic in t, and because
# a circle's interior is convex, the set of t where the point is inside
# is always a single contiguous range [t1, t2] (possibly empty or
# reversed if the line never reaches the circle) - clamping that range to
# the segment's own [0, 1] gives exactly the visible sub-segment.
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

# The active diver reads as an arrow, not a circle, so facing is visible
# at a glance - the other two are interchangeable dots, this one is "you."
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
