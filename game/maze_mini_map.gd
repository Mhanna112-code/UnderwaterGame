# A radar for maze_level.gd's standalone test scene - same circular
# overhead-readout shape as mini_map.gd, trimmed down to what this scene
# actually has: one test diver, no party, no key items, no sonar.
#
# MODIFIED: mini_map.gd reads a fixed world._wall_segments array baked
# once per wall as it's built - that works for World because a wall there
# never moves again once built. This scene's CurrentWall1/CurrentWall2
# actually swing open at runtime (see maze_level.gd's swing_hallway()), so
# a one-time bake would silently go stale the moment that happens. Instead
# this recomputes each piece's own endpoints from the box's CURRENT
# global_transform every draw call - a few extra vector ops 60 times a
# second, in exchange for the radar never lying about a wall that just
# moved.
class_name MazeMiniMap
extends Control

var maze_level: MazeLevel

@export var view_radius := 22.0

# How close the diver has to get to a piece of wall before THAT piece is
# "seen" and stays drawn from then on - a fog-of-war reveal radius, NOT
# the same thing as view_radius above. view_radius only controls how much
# of the map that's ALREADY been revealed fits on the radar right now
# (zoom); SIGHT_RADIUS controls whether a given piece gets revealed in
# the first place, regardless of whether it's currently near enough to be
# on screen. Roughly matches the ~25m real sight distance content/
# sites.gd's own header mentions for dark water, scaled down for this
# tighter test-scene radar.
const SIGHT_RADIUS := 12.0

# Each wall is sliced into pieces roughly this long (world units) for
# reveal purposes, rather than being revealed or hidden as one unit - a
# long corridor wall should light up gradually as you walk its length,
# not all at once the moment you're near either end of it. Smaller means
# smoother/more granular reveal at the cost of a few more line segments
# drawn per wall; this is a reasonable middle ground for this scene's
# wall lengths, not a value with a single correct answer.
const REVEAL_SEGMENT_LENGTH := 2.0

# Which pieces of which wall have been seen - Dictionary[CSGBox3D] ->
# Array[bool], one entry per piece (see _plan_for()'s "count"). A piece
# stays revealed forever once true, same "seen doesn't un-happen when you
# swim away" rule World.revealed_key_items uses for guardians. Built
# lazily per box the first time _pieces_for() sees it - see there.
var _revealed: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	clip_contents = true

func _process(_dt: float) -> void:
	_update_revealed()
	queue_redraw()

# Works out how a wall gets sliced into reveal pieces, purely from the
# box's own LOCAL size (box.size never changes, only its transform does -
# see _piece_segment()'s own comment) - so this is a cheap, pure
# calculation safe to just recompute on demand rather than caching:
#   axis_is_x: whether the wall's LENGTH runs along local X (true) or
#     local Z (false) - same "longer local dimension wins" rule
#     _box_segment() used to use for the whole wall.
#   half_len: half the wall's total length along that axis.
#   count: how many REVEAL_SEGMENT_LENGTH-ish pieces the wall is divided
#     into (at least 1, so even a short wall still has something to
#     reveal).
func _plan_for(box: CSGBox3D) -> Dictionary:
	var axis_is_x: bool = box.size.x >= box.size.z
	var length: float = box.size.x if axis_is_x else box.size.z
	var count: int = maxi(1, int(ceil(length / REVEAL_SEGMENT_LENGTH)))
	return {"axis_is_x": axis_is_x, "half_len": length * 0.5, "count": count}

# Lazily creates `box`'s revealed-pieces array (all false) the first time
# it's asked for, sized to `count` - and just returns the existing array
# on every call after that, since a wall's own piece COUNT never changes
# (it only depends on box.size, which is fixed) even though the pieces'
# own WORLD positions keep changing if the wall swings.
func _pieces_for(box: CSGBox3D, count: int) -> Array:
	if not _revealed.has(box):
		var arr: Array = []
		for i in range(count):
			arr.append(false)
		_revealed[box] = arr
	return _revealed[box]

# The world-space endpoints of piece `i` (0-indexed, out of `plan.count`
# total) of `box`, right now. Same local-point-times-transform idea
# _box_segment() used for a whole wall, just applied to a fraction of it:
# lerp() walks from one end of the wall's local length to the other, and
# piece i covers the i/count -> (i+1)/count slice of that range - so
# piece 0 is the first REVEAL_SEGMENT_LENGTH-ish stretch, piece
# count-1 is the last, and every local point in between still gets
# multiplied through box.global_transform to land wherever the box
# actually is/however it's actually rotated right now.
func _piece_segment(box: CSGBox3D, plan: Dictionary, i: int) -> Array:
	var t := box.global_transform
	var half_len: float = plan.half_len
	var count: int = plan.count
	var start: float = lerpf(-half_len, half_len, float(i) / float(count))
	var end: float = lerpf(-half_len, half_len, float(i + 1) / float(count))
	if plan.axis_is_x:
		return [t * Vector3(start, 0.0, 0.0), t * Vector3(end, 0.0, 0.0)]
	return [t * Vector3(0.0, 0.0, start), t * Vector3(0.0, 0.0, end)]

# Same reveal idea as before, just checked per PIECE instead of per whole
# wall - a piece flips to revealed the moment the diver's within
# SIGHT_RADIUS of that piece specifically, which is what lets one end of
# a long wall stay fogged while the near end is already lit up.
func _update_revealed() -> void:
	if maze_level == null or maze_level._diver == null or not is_instance_valid(maze_level._diver):
		return
	var pos: Vector3 = maze_level._diver.global_position
	var pos2 := Vector2(pos.x, pos.z)
	for box in maze_level.wall_boxes:
		if not is_instance_valid(box):
			continue
		var plan := _plan_for(box)
		var pieces := _pieces_for(box, plan.count)
		for i in range(plan.count):
			if pieces[i]:
				continue
			var seg := _piece_segment(box, plan, i)
			var a2 := Vector2(seg[0].x, seg[0].z)
			var b2 := Vector2(seg[1].x, seg[1].z)
			if _point_to_segment_dist(pos2, a2, b2) <= SIGHT_RADIUS:
				pieces[i] = true

# Closest distance from `p` to any point ON the segment a->b, not to its
# endpoints - project p onto the infinite line through a/b, clamp that
# projection to the segment's own [0, 1] range (so it can't slide past
# either end), then measure to wherever that clamped point landed. This is
# the standard point-to-segment distance formula; the clamp is the whole
# trick; without it this would just be "closest endpoint," which reads a
# piece you're walking parallel to (but not near either end of) as far
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
		if not is_instance_valid(box):
			continue
		var plan := _plan_for(box)
		var pieces := _pieces_for(box, plan.count)
		for i in range(plan.count):
			# Fog of war, per piece: an unrevealed piece draws nothing at
			# all, regardless of whether it'd otherwise fall inside
			# view_radius - "on the radar's current zoom circle" and
			# "actually seen at some point" are two separate questions,
			# and this is the one that gates drawing at all.
			if not pieces[i]:
				continue
			var seg := _piece_segment(box, plan, i)
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

# Identical to mini_map.gd's own _clip_to_circle() - see its comment there
# for the derivation. Duplicated rather than shared because Control has no
# common non-World base both minimaps could hang a shared helper off of.
func _clip_to_circle(rel_a: Vector2, rel_b: Vector2, radius: float) -> Array:
	var d: Vector2 = rel_b - rel_a
	var dd: float = d.dot(d)
	if dd < 0.000001:
		return [rel_a, rel_b] if rel_a.length() <= radius else []
	var b_coef: float = 2.0 * rel_a.dot(d)
	var c_coef: float = rel_a.dot(rel_a) - radius * radius
	var disc: float = b_coef * b_coef - 4.0 * dd * c_coef
	if disc < 0.0:
		return []
	var sq: float = sqrt(disc)
	var t1: float = (-b_coef - sq) / (2.0 * dd)
	var t2: float = (-b_coef + sq) / (2.0 * dd)
	var lo: float = maxf(t1, 0.0)
	var hi: float = minf(t2, 1.0)
	if lo > hi:
		return []
	return [rel_a + d * lo, rel_a + d * hi]

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
