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
class_name Maze_MiniMap
extends Control

var world: World

@export var view_radius := 22.0   # world units shown at the panel's edge
# A radar for maze_level.gd's standalone test scene - same circular
# overhead-readout shape as mini_map.gd, trimmed down to what this scene
# actually has: one test diver, no party, no key items, no sonar.
#
# MODIFIED: mini_map.gd reads a fixed world._wall_segments array baked
# once per wall as it's built - that works for World because a wall there
# never moves again once built. This scene's CurrentWall1/CurrentWall2
# actually swing open at runtime (see maze_level.gd's swing_hallway()), so
# a one-time bake would silently go stale the moment that happens. Instead
# this recomputes each CSGBox3D's own centerline from its CURRENT
# global_transform every draw call - a few extra vector ops 60 times a
# second, in exchange for the radar never lying about a wall that just
# moved.

# How close the diver has to get to a wall before it's "seen" and stays
# drawn from then on - a fog-of-war reveal radius, NOT the same thing as
# view_radius above. view_radius only controls how much of the map that's
# ALREADY been revealed fits on the radar right now (zoom); SIGHT_RADIUS
# controls whether a wall gets revealed in the first place, regardless of
# whether it's currently near enough to be on screen. Roughly matches the
# ~25m real sight distance content/sites.gd's own header mentions for dark
# water, scaled down for this tighter test-scene radar.
const SIGHT_RADIUS := 12.0

# Which walls have ever been seen - keyed by the CSGBox3D node itself
# rather than an index, since wall_boxes' order/contents never change but
# a Dictionary keyed by instance is simplest to check membership on. Once
# true, stays true for the rest of the run - "seen" doesn't un-happen when
# you swim away, same as World.revealed_key_items never un-reveals a
# guardian once sonar's found it.
var _revealed: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	clip_contents = true

func _process(_dt: float) -> void:
	_update_revealed()
	queue_redraw()


# Closest distance from `p` to any point ON the segment a->b, not to its
# endpoints - project p onto the infinite line through a/b, clamp that
# projection to the segment's own [0, 1] range (so it can't slide past
# either end), then measure to wherever that clamped point landed. This is
# the standard point-to-segment distance formula; the clamp is the whole
# trick; without it this would just be "closest endpoint," which reads a
# long wall you're walking parallel to (but not near either end of) as far
# away when you're actually right next to its middle.
static func _point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _draw() -> void:
	if maze_level == null or maze_level._diver == null or not is_instance_valid(maze_level._diver):
		return

	var center: Vector3 = maze_level._diver.global_position
	var r: float = size.x * 0.5
	var mid := Vector2(r, r)
	var px_per_unit: float = r / view_radius

	draw_circle(mid, r, Color(0.03, 0.06, 0.08, 0.88))
	draw_arc(mid, r - 1.5, 0.0, TAU, 48, Color(0.5, 0.72, 0.8, 0.55), 1.5)

	for box in maze_level.wall_boxes:
		# Fog of war: unrevealed walls draw nothing at all, regardless of
		# whether they'd otherwise fall inside view_radius - "on the radar's
		# current zoom circle" and "actually seen at some point" are two
		# separate questions, and this is the one that gates drawing at all.
		if not is_instance_valid(box) or not _revealed.get(box, false):
			continue
		var seg := _box_segment(box)
		var rel_a: Vector2 = Vector2(seg[0].x, seg[0].z) - Vector2(center.x, center.z)
		var rel_b: Vector2 = Vector2(seg[1].x, seg[1].z) - Vector2(center.x, center.z)
		var clipped: Array = _clip_to_circle(rel_a, rel_b, view_radius)
		if clipped.is_empty():
			continue
		draw_line(
			mid + (clipped[0] as Vector2) * px_per_unit,
			mid + (clipped[1] as Vector2) * px_per_unit,
			Color(0.6, 0.64, 0.68, 0.9), 2.0
		)

	var fwd: Vector3 = -maze_level._diver.global_transform.basis.z
	_draw_arrow(mid, Vector2(fwd.x, fwd.z))

# Same "pick whichever horizontal axis is actually the wall's length"
# rule World._build_wall() uses for _wall_segments, just read from the
# box's live size/global_transform instead of baked at build time - a
# rotated box's local +X axis is what world_basis.x actually points along
# after the transform, so this stays correct even mid-swing.
func _box_segment(box: CSGBox3D) -> Array:
	var half: Vector3 = box.size * 0.5
	var t := box.global_transform
	if box.size.x >= box.size.z:
		return [t * Vector3(-half.x, 0.0, 0.0), t * Vector3(half.x, 0.0, 0.0)]
	return [t * Vector3(0.0, 0.0, -half.z), t * Vector3(0.0, 0.0, half.z)]


func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	clip_contents = true

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if world == null or world.divers.is_empty():
		return

	var divers: Array = world.divers
	var walls: Array = get_tree().get_nodes_in_group("Wall")
	var active: int = world.active
	var center: Vector3 = (divers[active] as Diver).global_position
	var r: float = size.x * 0.5
	var mid := Vector2(r, r)
	var px_per_unit: float = r / view_radius

	draw_circle(mid, r, Color(0.03, 0.06, 0.08, 0.88))
	draw_arc(mid, r - 1.5, 0.0, TAU, 48, Color(0.5, 0.72, 0.8, 0.55), 1.5)

	# Walls: clipped to the circle itself, not just culled by whole segment -
	# a segment with one endpoint inside view_radius and one well outside it
	# used to draw straight through the rim into the square panel's corner
	# space (clip_contents only clips to the panel's rectangle, not the
	# circle drawn inside it). _clip_to_circle solves for where the segment
	# actually crosses the view_radius boundary and only the portion inside
	# gets drawn.
	var fog_distance := _project(d.global_position + view_radius, center, px_per_unit, mid)

	for seg in walls:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
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

# Whole-segment reveal, not partial - a wall becomes visible entirely the
# moment the diver gets within SIGHT_RADIUS of ANY point on it (nearest
# point on the segment, not just its endpoints - see
# _point_to_segment_dist()), rather than only the nearby portion of a long
# wall lighting up. Good enough at this scene's wall lengths; a maze with
# much longer corridor pieces would want to split each one into shorter
# sub-segments first so a far end can stay hidden while the near end is
# already walked.
func _update_revealed() -> void:
	if maze_level == null or maze_level._diver == null or not is_instance_valid(maze_level._diver):
		return
	var pos: Vector3 = walls
	var pos2 := Vector2(pos.x, pos.z)
	for box in maze_level.wall_boxes:
		if not is_instance_valid(box) or _revealed.get(box, false):
			continue
		var seg := _box_segment(box)
		_draw_objects_within_radius()
		
func _draw_objects_within_radius() -> void:
	for i in range(2):
		diver.
		
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
