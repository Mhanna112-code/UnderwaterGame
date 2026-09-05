# A circular overhead readout centered on whichever diver is active,
# redrawn from scratch every frame via _draw() rather than managed as a
# pile of repositioned child nodes - circles, a rotated arrow, and
# variable-length wall lines are all one draw call each this way, and
# nothing needs to be created/destroyed as walls come in and out of range.
#
# Holds a reference to world.gd itself rather than copies of its data -
# divers/_wall_segments live there and change over time (new walls could
# be built later, divers move every frame); reading them live means this
# never needs to be told to refresh, it just always reflects however the
# world actually looks right now.
class_name MazeMap
extends Control

var world: MazeLevel

@export var view_radius := 200.0   # world units shown at the panel's edge

func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	clip_contents = true

func _process(_dt: float) -> void:
	queue_redraw()

# MODIFIED: this whole function used to assume a World's data model
# (divers/_wall_segments/key_items/revealed_key_items) - none of that
# exists on MazeLevel, which only has a single test diver (_diver) and a
# corridors list. Re-centered on _diver directly, dropped the
# wall-segment and key-item drawing entirely (nothing to read them from
# here), and added corridor rectangles in their place. If MazeLevel ever
# grows its own wall-segment tracking, that block can come back the same
# way it left - clipped per-edge through _clip_to_circle(), same as before.
func _draw() -> void:
	if world == null or world._diver == null:
		return

	var center: Vector3 = world._diver.global_position
	var r: float = size.x * 0.5
	var mid := Vector2(r, r)
	var px_per_unit: float = r / view_radius

	draw_circle(mid, r, Color(0.03, 0.06, 0.08, 0.88))
	draw_arc(mid, r - 1.5, 0.0, TAU, 48, Color(0.5, 0.72, 0.8, 0.55), 1.5)

	_draw_corridors(center, px_per_unit, mid)

	var fwd: Vector3 = -world._diver.global_transform.basis.z
	_draw_arrow(mid, Vector2(fwd.x, fwd.z))

# One translucent rectangle per corridor Area3D, projected straight down
# onto the map (Y dropped, only X/Z kept) - reads its actual box
# (CollisionShape3D/BoxShape3D, same shape water_current.gd looks for)
# rather than assuming anything about size or rotation, so a rotated
# corridor's rectangle comes out correctly rotated on the map too, not
# just axis-aligned.
#
# Culled by center distance rather than truly clipped to the circle like
# the old wall segments were (a rectangle mostly off-screen just doesn't
# draw, rather than being clipped exactly to the rim) - clip_contents on
# this Control still keeps anything drawn from spilling outside the
# panel's own square bounds either way.
func _draw_corridors(center: Vector3, px_per_unit: float, mid: Vector2) -> void:
	if world.corridors == null:
		return
	for area in world.corridors:
		if not is_instance_valid(area):
			continue
		var shape_node := _find_box_shape(area)
		if shape_node == null:
			continue
		if center.distance_to(shape_node.global_position) > view_radius * 1.5:
			continue
		var box := shape_node.shape as BoxShape3D
		var corners := _box_corners_2d(shape_node, box, center)
		var pts := PackedVector2Array()
		for c in corners:
			pts.append(mid + (c as Vector2) * px_per_unit)
		draw_colored_polygon(pts, Color(0.3, 0.65, 0.85, 0.22))
		for i in range(pts.size()):
			draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.45, 0.8, 0.95, 0.6), 1.5)

func _find_box_shape(area: Area3D) -> CollisionShape3D:
	for child in area.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return child as CollisionShape3D
	return null

# The box's 4 top-down corners in world space, via shape_node's own
# global_transform (which carries BOTH the Area3D's rotation and any
# extra rotation the shape itself has relative to it - see
# water_current.gd's own header comment on why several of these boxes
# have that second kind of rotation), then made relative to `center` the
# same way every other position on this map already is.
func _box_corners_2d(shape_node: CollisionShape3D, box: BoxShape3D, center: Vector3) -> Array:
	var t := shape_node.global_transform
	var hx := box.size.x * 0.5
	var hz := box.size.z * 0.5
	var local_corners := [
		Vector3(-hx, 0.0, -hz), Vector3(hx, 0.0, -hz),
		Vector3(hx, 0.0, hz), Vector3(-hx, 0.0, hz),
	]
	var out: Array = []
	for lc in local_corners:
		var world_pos: Vector3 = t * (lc as Vector3)
		out.append(Vector2(world_pos.x, world_pos.z) - Vector2(center.x, center.z))
	return out

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

# Sonar lives on whichever Diver has passive_id == "sonar" (Mermaid), not
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
