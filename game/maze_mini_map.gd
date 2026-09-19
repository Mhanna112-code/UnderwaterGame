# A radar for maze_level.gd's standalone test scene - same circular
# overhead-readout shape as mini_map.gd, trimmed down to what this scene
# actually has: one test diver, no party, no key items, no sonar.
#
# MODIFIED: mini_map.gd reads a fixed world._wall_segments array baked
# once per wall as it's built - that works for World because a wall there
# never moves again once built. This scene's CurrentWall1/CurrentWall2
# actually swing open at runtime (see maze_level.gd's swing_hallway()), so
# a one-time bake would silently go stale the moment that happens. Instead
# this recomputes each wall's own endpoints from the box's CURRENT
# global_transform every draw call - a few extra vector ops 60 times a
# second, in exchange for the radar never lying about a wall that just
# moved.
#
# MODIFIED (removed then reinstated): this used to slice every wall into
# short pieces and reveal them individually as the diver got close (fog
# of war), matching mini_map.gd's own per-piece reveal for the real game.
# That per-piece slicing was dropped, but reveal itself is back - now
# piggybacked on the hall-discovery system below instead of its own
# separate mechanism: a wall doesn't draw AT ALL, on either this radar or
# the big main map, until _update_revealed() has actually resolved it (the
# diver got within view_radius of it at least once). Once resolved, it
# stays drawn forever after - on the main map even once the diver walks
# back away from it, since _wall_to_hall never forgets an entry.
class_name MazeMiniMap
extends Control

var maze_level: MazeLevel

@export var view_radius := 22.0

func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	clip_contents = true
	_build_main_map()

# The world-space endpoints of `box`'s own centerline, right now - the
# longer of its two horizontal dimensions is treated as its length (a
# wall built wide-along-X vs. wide-along-Z), read fresh from box.global_
# transform every call rather than cached, so a wall that swings open
# (CurrentWall1/CurrentWall2) never draws stale.
func _box_segment(box: CSGBox3D) -> Array:
	var half: Vector3 = box.size * 0.5
	var t := box.global_transform
	if box.size.x >= box.size.z:
		return [t * Vector3(-half.x, 0.0, 0.0), t * Vector3(half.x, 0.0, 0.0)]
	return [t * Vector3(0.0, 0.0, -half.z), t * Vector3(0.0, 0.0, half.z)]

func _process(_dt: float) -> void:
	_update_revealed()
	queue_redraw()
	if main_map.visible:
		_refresh_main_map()

# --- Hall discovery & rotation-selection ---
#
# A hall (the player-facing unit - "hall 1", "hall 2", ...) is really one
# WindCorridor's open lane PLUS the two walls that enclose it. Which two
# walls those are is pure geometry and never changes (see
# _compute_corridor_wall_pairs()), but the NAME a hall gets is player-
# facing and assigned progressively in _update_revealed(): a hall isn't
# added to _hall_walls until the diver has actually swum within
# view_radius of one of its two walls, and "WindCorridorN" numbers halls
# in the order they were actually found this playthrough, not by the
# corridor node's own child index. Discovery ALSO gates visibility now
# (see the class comment up top) - a wall isn't drawn anywhere, on the
# radar or the main map, until it's been resolved here at least once.

#
# This is a geometric heuristic, not read from authored data - if two
# corridors sit close enough together that a wall between them ends up
# assigned to the wrong one (or claimed by both), this nearest-two-walls
# rule is what to retune, not the dictionary shape.
var _corridor_wall_pairs: Dictionary = {}   # Area3D -> Array[CSGBox3D], size 2
var _corridor_wall_pairs_computed := false

func _compute_corridor_wall_pairs() -> void:
	if maze_level == null:
		return
	_corridor_wall_pairs.clear()
	for corridor in maze_level.corridors:
		if not is_instance_valid(corridor):
			continue
		var center: Vector3 = corridor.global_position
		var center2 := Vector2(center.x, center.z)
		var ranked: Array = []
		for box in maze_level.wall_boxes:
			if not is_instance_valid(box):
				continue
			var seg := _box_segment(box)
			var a2 := Vector2(seg[0].x, seg[0].z)
			var b2 := Vector2(seg[1].x, seg[1].z)
			ranked.append({"box": box, "dist": _point_to_segment_dist(center2, a2, b2)})
		ranked.sort_custom(func(a, b): return float(a.dist) < float(b.dist))
		var walls: Array[CSGBox3D] = []
		for i in range(mini(2, ranked.size())):
			walls.append(ranked[i].box as CSGBox3D)
		_corridor_wall_pairs[corridor] = walls
	_corridor_wall_pairs_computed = true

func _corridor_for_wall(box: CSGBox3D) -> Area3D:
	for corridor in _corridor_wall_pairs:
		if (_corridor_wall_pairs[corridor] as Array[CSGBox3D]).has(box):
			return corridor
	return null

# Builds a wavy "current" path down the middle of `hall_name`'s own two
# walls, in world space - visual flair for _currents (the hall's own
# WindCorridor), not read from anything about the corridor itself, just
# shaped to fit between its two enclosing walls. Matches each of wall A's
# endpoints to whichever of wall B's endpoints is NEARER rather than
# assuming index 0 lines up with index 0 - the two walls' own endpoint
# order has no relationship to each other (they were only ever picked as
# "nearest two walls to this corridor," see _compute_corridor_wall_pairs()),
# so naively pairing them could cross the midline into an hourglass shape
# instead of running straight down the hall's length. Shared by both the
# radar (_draw()) and the main map (_refresh_main_map()) - each just
# projects these same 3D points through its own space afterward.
func _hall_current_path(hall_name: String, segments: int = 14) -> PackedVector3Array:
	var pts := PackedVector3Array()
	if not _hall_walls.has(hall_name):
		return pts
	var walls: Array[CSGBox3D] = _hall_walls[hall_name]
	if walls.size() < 2 or not is_instance_valid(walls[0]) or not is_instance_valid(walls[1]):
		return pts
	var seg_a := _box_segment(walls[0])
	var seg_b := _box_segment(walls[1])
	var a0: Vector3 = seg_a[0]
	var a1: Vector3 = seg_a[1]
	var b0: Vector3 = seg_b[0]
	var b1: Vector3 = seg_b[1]
	var straight: float = a0.distance_to(b0) + a1.distance_to(b1)
	var crossed: float = a0.distance_to(b1) + a1.distance_to(b0)
	var matched_b0: Vector3 = b0 if straight <= crossed else b1
	var matched_b1: Vector3 = b1 if straight <= crossed else b0
	var near0: Vector3 = (a0 + matched_b0) * 0.5
	var near1: Vector3 = (a1 + matched_b1) * 0.5

	var forward: Vector3 = near1 - near0
	var length: float = forward.length()
	if length < 0.01:
		return pts
	forward /= length
	# Perpendicular to the hall's own length, in the XZ plane - not the
	# corridor's real 3D "side" (there isn't one meaningful here, both
	# walls run flat along the ground), just enough to wave the path
	# sideways within the hall's own width.
	var side := Vector3(-forward.z, 0.0, forward.x)
	# Kept a bit short of the full gap (0.6x) so the wave's peaks don't
	# brush against the walls themselves.
	var amplitude: float = a0.distance_to(matched_b0) * 0.5 * 0.6

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var wave := sin(t * TAU) * amplitude
		pts.append(near0.lerp(near1, t) + side * wave)
	return pts

# Player-facing discovery. hall name -> Array[CSGBox3D] size 2, keys
# assigned in the order the diver actually found each hall.
var _hall_walls: Dictionary = {}
# Same keys as _hall_walls (hall name -> that hall's own WindCorridor
# Area3D), built alongside it in _update_revealed() below - lets anything
# that already has a hall name look up its corridor directly instead of
# re-deriving it through _corridor_wall_pairs/_corridor_for_wall.
var _currents: Dictionary = {}
# CSGBox3D -> hall name, once assigned. A wall that turned out to belong
# to no corridor at all gets "" here instead - not a hall, but still
# marked so its adjacency isn't rechecked every single frame forever.
var _wall_to_hall: Dictionary = {}
var _hall_discovery_count := 0

# The hall currently up for rotation (its own two walls) - empty until the
# first hall is ever found. Kept as the actual CSGBox3D pair rather than a
# screen-space PackedVector2Array: the small radar and the main map
# project the same hall into two completely different coordinate spaces,
# and whichever one last redrew would silently stomp the other's cached
# points if this held pixels instead of the underlying walls. Whatever
# eventually highlights the selected hall on screen should project
# selectedHall's own walls itself, on demand, in whichever space it's
# drawing to.
var selectedHall: Array[CSGBox3D] = []
var selectedHallName := ""

# The hall whose CURRENT (its own WindCorridor Area3D) is currently
# selected - independent from selectedHall/selectedHallName above, since
# selecting a hall's walls (_select_rotatable_hall()) and selecting a
# current (_select_rotatable_current()) are two separate actions that can
# each point at a different hall (see _select_next_current()/
# _select_previous_current() for cycling this one on its own).
var selectedCurrent: Area3D
var selectedCurrentName := ""

# Neither selection blinks on the radar - only on the main map (see
# _restart_main_map_blink()/_restart_main_map_current_blink()), which
# tweens real persistent Line2D nodes' .visible directly. The radar has
# no persistent line Nodes to tween at all: every wall there is redrawn
# from scratch each frame via draw_line()/draw_multiline(), so blinking it
# too would mean skipping a draw call on a timer - deliberately not done,
# the radar always shows everything discovered solid.

# Same shape as _main_map_hall_lines further down, just for the small
# radar - not consumed by anything yet (nothing currently supports
# clicking this 150x150 view to select a hall), but built the same way in
# _draw() below so that's a small addition later rather than a redesign.
var _radar_hall_points: Dictionary = {}

# Walks every not-yet-resolved wall and, once the diver has actually gotten
# within view_radius of it, resolves it: no adjacent corridor -> marked ""
# (drawn on its own, never grouped); an adjacent corridor -> both of that
# corridor's walls are folded into a new _hall_walls entry together (even
# if the diver has only physically reached one of the two so far) and
# named by discovery order.
func _update_revealed() -> void:
	if maze_level == null or maze_level._diver == null or not is_instance_valid(maze_level._diver):
		return
	if not _corridor_wall_pairs_computed:
		_compute_corridor_wall_pairs()
	var diver_pos: Vector3 = maze_level._diver.global_position
	for box in maze_level.wall_boxes:
		if not is_instance_valid(box) or _wall_to_hall.has(box):
			continue
		var seg := _box_segment(box)
		var wall_mid: Vector3 = (seg[0] + seg[1]) * 0.5
		if wall_mid.distance_to(diver_pos) > view_radius:
			continue
		var corridor := _corridor_for_wall(box)
		if corridor == null:
			_wall_to_hall[box] = ""
			continue
		_hall_discovery_count += 1
		var hall_name := "WindCorridor%d" % _hall_discovery_count
		var walls: Array[CSGBox3D] = _corridor_wall_pairs[corridor]
		_hall_walls[hall_name] = walls
		_currents[hall_name] = corridor
		for wall in walls:
			_wall_to_hall[wall] = hall_name
		# Every newly found hall becomes the selection, not just the first
		# one - discovering a new hall is the player's cue that this is the
		# one to look at right now. _select_next_hall()/_select_previous_hall()
		# below are what let them move off it again afterward. Both the
		# hall (walls) and its current start selected together - without
		# this, selectedCurrentName would sit at "" until the player
		# happened to press a Shift+arrow at least once.
		_select_rotatable_hall(hall_name)
		_select_rotatable_current(hall_name)

# Points selectedHall at `hall_name`'s own wall pair. Called the moment a
# new hall is first discovered (see _update_revealed()) so there's always
# something selected as soon as one exists, and reusable later by whatever
# click handler lets the player pick a DIFFERENT already-found hall to
# rotate instead (see _pick_hall_at() below for hit-testing a click
# against a hall's drawn lines).
func _select_rotatable_hall(hall_name: String) -> void:
	if not _hall_walls.has(hall_name):
		return
	selectedHall = _hall_walls[hall_name]
	selectedHallName = hall_name
	_restart_main_map_blink()

# Same idea as _select_rotatable_hall() above, but for selectedCurrent -
# points it at `hall_name`'s own WindCorridor Area3D (_currents), kept
# fully independent of which hall's WALLS are selected.
func _select_rotatable_current(hall_name: String) -> void:
	if not _hall_walls.has(hall_name):
		return
	selectedCurrent = _currents[hall_name]
	selectedCurrentName = hall_name
	_restart_main_map_current_blink()

# Moves the selection to the next/previous discovered hall, wrapping
# around at either end - _hall_walls' own key order is discovery order
# (GDScript Dictionaries preserve insertion order), so this is really just
# "the hall found right after/before the current one," matching how the
# player thinks about cycling through what they've found so far. Halls
# not yet discovered aren't in _hall_walls at all, so they're never a
# valid cycle target. A no-op with nothing discovered yet.
func _select_next_hall() -> void:
	_cycle_selected_hall(1)

func _select_previous_hall() -> void:
	_cycle_selected_hall(-1)

func _cycle_selected_hall(direction: int) -> void:
	var names := _hall_walls.keys()
	if names.is_empty():
		return
	var idx := names.find(selectedHallName)
	idx = wrapi((0 if idx == -1 else idx) + direction, 0, names.size())
	_select_rotatable_hall(names[idx])

# Same idea as _select_next_hall()/_select_previous_hall() above, but
# cycles selectedCurrentName instead - its OWN position in _hall_walls'
# key order, not selectedHallName's, since the two selections are
# independent (see selectedCurrent's own comment).
func _select_next_current() -> void:
	_cycle_selected_current(1)

func _select_previous_current() -> void:
	_cycle_selected_current(-1)

func _cycle_selected_current(direction: int) -> void:
	var names := _hall_walls.keys()
	if names.is_empty():
		return
	var idx := names.find(selectedCurrentName)
	idx = wrapi((0 if idx == -1 else idx) + direction, 0, names.size())
	_select_rotatable_current(names[idx])

func _draw() -> void:
	if maze_level == null or maze_level._diver == null or not is_instance_valid(maze_level._diver):
		return

	var center: Vector3 = maze_level._diver.global_position
	var r: float = size.x * 0.5
	var mid := Vector2(r, r)
	var px_per_unit: float = r / view_radius

	draw_circle(mid, r, Color(0.03, 0.06, 0.08, 0.88))
	draw_arc(mid, r - 1.5, 0.0, TAU, 48, Color(0.5, 0.72, 0.8, 0.55), 1.5)

	# Only walls _update_revealed() has actually resolved draw at all - an
	# undiscovered wall shows up on neither this radar nor the main map.
	# Of the resolved ones, anything folded into a hall is grouped under
	# that hall's key (so a future click-to-select can test against one
	# hall's lines at a time); anything resolved but standalone just draws
	# as its own independent line.
	var hall_points: Dictionary = {}
	for box in maze_level.wall_boxes:
		if not is_instance_valid(box) or not _wall_to_hall.has(box):
			continue
		var seg := _box_segment(box)
		var rel_a: Vector2 = Vector2(seg[0].x, seg[0].z) - Vector2(center.x, center.z)
		var rel_b: Vector2 = Vector2(seg[1].x, seg[1].z) - Vector2(center.x, center.z)
		var clipped: Array = _clip_to_circle(rel_a, rel_b, view_radius)
		if clipped.is_empty():
			continue
		var p_a: Vector2 = (clipped[0] as Vector2) * px_per_unit + mid
		var p_b: Vector2 = (clipped[1] as Vector2) * px_per_unit + mid
		var hall_name: String = _wall_to_hall[box]
		if hall_name == "":
			draw_line(p_a, p_b, Color(0.6, 0.64, 0.68, 0.9), 2.0)
			continue
		if not hall_points.has(hall_name):
			hall_points[hall_name] = PackedVector2Array()
		(hall_points[hall_name] as PackedVector2Array).append(p_a)
		(hall_points[hall_name] as PackedVector2Array).append(p_b)
	_radar_hall_points = hall_points
	# No blink here, deliberately - the selected hall/current only blink on
	# the main map (see _restart_main_map_blink()/
	# _restart_main_map_current_blink()). The radar always draws every
	# discovered hall solid.
	for hall_name in hall_points:
		var points := hall_points[hall_name] as PackedVector2Array
		# A hall can be known to the minimap while every one of its segments
		# is outside this radar circle. Godot rejects an empty polyline and
		# otherwise prints an error every redraw.
		if points.size() >= 2:
			draw_multiline(points, Color(0.6, 0.64, 0.68, 0.9), 2.0)
		_draw_current(hall_name, center, mid, px_per_unit)

	var fwd: Vector3 = -maze_level._diver.global_transform.basis.z
	_draw_arrow(mid, Vector2(fwd.x, fwd.z))

# Draws hall_name's own wavy current line (_hall_current_path()) on the
# small radar - points beyond view_radius are simply dropped rather than
# precisely circle-clipped the way the straight wall segments are
# (_clip_to_circle()); a decorative curve fraying at the radar's edge
# reads fine, and exactly clipping a multi-point curve to a circle would
# need far more math for very little visual difference.
func _draw_current(hall_name: String, center: Vector3, mid: Vector2, px_per_unit: float) -> void:
	var path := _hall_current_path(hall_name)
	if path.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in path:
		var rel: Vector2 = Vector2(p.x, p.z) - Vector2(center.x, center.z)
		if rel.length() > view_radius:
			continue
		pts.append(rel * px_per_unit + mid)
	if pts.size() >= 2:
		draw_polyline(pts, Color(0.35, 0.75, 0.95, 0.85), 1.5)

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

# Closest distance from `p` to any point ON the segment a->b, not to its
# endpoints - project p onto the infinite line through a/b, clamp that
# projection to the segment's own [0, 1] range (so it can't slide past
# either end), then measure to wherever that clamped point landed. Used by
# _compute_corridor_wall_pairs() (wall-to-corridor distance) and _pick_hall_at()
# (hit-testing a click against a hall's drawn lines).
static func _point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)

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

# --- Big persistent overview map, opened/closed with M ---
# The small radar above recenters on the diver every frame (see _draw()'s
# own `center`) - fine for "what's near me right now," wrong for a
# standing overview, since anything already drawn would slide around the
# panel the instant the diver moves. This map uses a FIXED origin instead
# (_main_map_origin, computed once from the maze's own real bounds and
# never touched again), so a wall drawn here stays at the same pixel
# forever.
const MAIN_MAP_SIZE := 500.0
# Empty space kept between the maze's own drawn extent and the panel's
# edge, on every side - without this, a wall sitting exactly on the
# maze's outer boundary would draw right at pixel 0, half-clipped by the
# panel edge/border.
const MAIN_MAP_MARGIN := 14.0
var main_map: Control
var _main_map_px_per_unit := 1.0
var _main_map_origin := Vector2.ZERO
var _main_map_bounds_computed := false
# Keyed by hall name (String, e.g. "WindCorridor1") -> one real Line2D per
# wall in that hall (size 2, same order as _hall_walls[hall_name]) - a
# persistent child of main_map rather than a PackedVector2Array rebuilt
# every frame, so blinking the selected hall (_restart_main_map_blink())
# can just tween these nodes' own .visible directly. A separate Line2D per
# wall rather than one 4-point Line2D for the whole hall: Line2D always
# connects its points into ONE continuous polyline, so a single Line2D
# covering both walls would draw a spurious diagonal connecting wall A's
# far end to wall B's near end. Created lazily, the first time a hall is
# actually discovered (see _update_main_map_hall_line()); .points get
# refreshed every frame after that in _refresh_main_map(), same as before,
# since a wall can still swing open after its hall was first found.
var _main_map_hall_lines: Dictionary = {}
# CSGBox3D -> its own persistent Line2D, for RESOLVED walls that turned
# out to belong to no hall (see _wall_to_hall - undiscovered walls never
# get an entry here at all). One per wall rather than combined into a
# single Line2D for the same reason as _main_map_hall_lines above.
var _main_map_lone_lines: Dictionary = {}
# Hall name -> one persistent Line2D carrying that hall's own wavy current
# path (_hall_current_path()) - one per hall (not per wall) since a
# current is a single wavy line, not a pair. Created lazily the first
# time a hall's current is drawn (see _update_main_map_current_line()),
# same lazy-creation-then-reposition pattern as _main_map_hall_lines/
# _main_map_lone_lines above.
var _main_map_current_lines: Dictionary = {}
var _main_map_diver_pos := Vector2.ZERO
# Draws the diver arrow + border above every wall Line2D - see its own
# z_index comment in _build_main_map().
var _main_map_overlay: Control

# The blink tween currently animating whichever hall is selectedHallName's
# own Line2D nodes on the main map - re-created (not reused) every time
# selection changes, since a Tween created with create_tween() is tied to
# whatever it was told to animate at creation time; there's no "retarget"
# operation, so switching halls means killing the old one and building a
# fresh one against the new hall's nodes instead.
var _main_map_blink_tween: Tween

# Restarts the main map's hall-highlight blink to target whichever hall is
# currently selectedHallName. Called both when selection actually changes
# (_select_rotatable_hall()) and the first time the selected hall's own
# Line2D nodes get created (_update_main_map_hall_line() - selection can
# happen before the main map has ever been opened, in which case there's
# nothing to tween yet until it is).
func _restart_main_map_blink() -> void:
	if _main_map_blink_tween != null and _main_map_blink_tween.is_valid():
		_main_map_blink_tween.kill()
	# Reset every hall back to fully visible first - otherwise a hall that
	# was mid-blink (invisible) when selection moved on to a different hall
	# would be left stuck invisible forever, with nothing left animating it
	# back.
	for lines in _main_map_hall_lines.values():
		for line in (lines as Array[Line2D]):
			line.visible = true
	if not _main_map_hall_lines.has(selectedHallName):
		return
	var lines: Array[Line2D] = _main_map_hall_lines[selectedHallName]
	_main_map_blink_tween = create_tween()
	_main_map_blink_tween.set_loops()
	_main_map_blink_tween.tween_interval(0.5)
	_main_map_blink_tween.tween_callback(func():
		for line in lines:
			line.visible = false
	)
	_main_map_blink_tween.tween_interval(0.5)
	_main_map_blink_tween.tween_callback(func():
		for line in lines:
			line.visible = true
	)

# Same idea as _main_map_blink_tween above, but for selectedCurrentName's
# own current Line2D (_main_map_current_lines) - a separate tween/variable
# pair rather than folded into the hall blink, since the selected current
# and the selected hall can differ (see _select_rotatable_current()).
var _main_map_current_blink_tween: Tween

func _restart_main_map_current_blink() -> void:
	if _main_map_current_blink_tween != null and _main_map_current_blink_tween.is_valid():
		_main_map_current_blink_tween.kill()
	for line in _main_map_current_lines.values():
		(line as Line2D).visible = true
	if not _main_map_current_lines.has(selectedCurrentName):
		return
	var line: Line2D = _main_map_current_lines[selectedCurrentName]
	_main_map_current_blink_tween = create_tween()
	_main_map_current_blink_tween.set_loops()
	_main_map_current_blink_tween.tween_interval(0.5)
	_main_map_current_blink_tween.tween_callback(func(): line.visible = false)
	_main_map_current_blink_tween.tween_interval(0.5)
	_main_map_current_blink_tween.tween_callback(func(): line.visible = true)

# Common setup for every Line2D this main map creates (hall or standalone)
# - added as a child of main_map so it renders in the same panel-space
# coordinates _project_to_main_map() already produces (main_map's own
# transform is identity, so a Line2D child at the default position 0,0
# treats its .points as directly being that panel space).
func _make_main_map_line() -> Line2D:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.6, 0.64, 0.68, 0.9)
	main_map.add_child(line)
	return line

# Scans maze_level's actual geometry once (not every frame - a maze's
# real footprint doesn't change after it's built) for the min/max corner
# of everything in it, then derives both the fixed origin (the min
# corner - so the maze's own top-left lands at the panel's top-left) and
# the scale (whichever axis needs to shrink MORE to fit its own span into
# the panel, used for BOTH axes so the maze doesn't stretch out of
# proportion).
func _compute_main_map_bounds() -> void:
	if maze_level == null:
		return
	var points: Array[Vector3] = maze_level._collect_bounds_points()
	if points.is_empty():
		return
	var min_pt: Vector3 = points[0]
	var max_pt: Vector3 = points[0]
	for p in points:
		min_pt = min_pt.min(p)
		max_pt = max_pt.max(p)
	_main_map_origin = Vector2(min_pt.x, min_pt.z)
	var span_x: float = maxf(max_pt.x - min_pt.x, 1.0)
	var span_z: float = maxf(max_pt.z - min_pt.z, 1.0)
	var usable: float = MAIN_MAP_SIZE - MAIN_MAP_MARGIN * 2.0
	_main_map_px_per_unit = minf(usable / span_x, usable / span_z)
	_main_map_bounds_computed = true

func _build_main_map() -> void:
	main_map = Control.new()
	main_map.custom_minimum_size = Vector2(MAIN_MAP_SIZE, MAIN_MAP_SIZE)
	main_map.clip_contents = true
	main_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Starts closed - M toggles it (see _unhandled_input()).
	main_map.visible = false
	main_map.draw.connect(_on_main_map_draw)
	# NOT add_child(main_map) on `self` - this Control is only 150x150 AND
	# has clip_contents = true, which clips every descendant's drawing to
	# that 150x150 rect regardless of how big main_map itself claims to
	# be. A sibling under the same parent this radar already lives under
	# gets the full 500x500 instead.
	get_parent().add_child(main_map)

	# A CanvasItem's own draw calls always render before its children's, so
	# now that walls are real Line2D children of main_map (instead of also
	# being drawn inline in _on_main_map_draw()), the diver arrow + border
	# can no longer just be drawn at the end of that same function - that
	# would put them BEHIND the wall lines, not on top. z_index = 1 pins
	# this overlay above every wall Line2D regardless of when each one gets
	# created (they all default to z_index 0, same as main_map itself).
	_main_map_overlay = Control.new()
	_main_map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_map_overlay.z_index = 1
	_main_map_overlay.draw.connect(_on_main_map_overlay_draw)
	main_map.add_child(_main_map_overlay)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo):
		return
	var key_event := event as InputEventKey
	var keycode: Key = key_event.keycode
	# Shift+arrow branches come FIRST, as part of the SAME if/elif chain as
	# the plain arrow ones below (they used to be two separate chains, so
	# Shift+Right fired both _select_next_hall() AND _select_next_current()
	# at once - the plain KEY_RIGHT check had no idea Shift was held).
	# event.shift_pressed (this specific event's own modifier state) rather
	# than polling Input.is_key_pressed(KEY_SHIFT) separately.
	if keycode == KEY_M:
		main_map.visible = not main_map.visible
		if main_map.visible:
			main_map.queue_redraw()
		get_viewport().set_input_as_handled()
	elif keycode == KEY_RIGHT and key_event.shift_pressed:
		_select_next_current()
		get_viewport().set_input_as_handled()
	elif keycode == KEY_LEFT and key_event.shift_pressed:
		_select_previous_current()
		get_viewport().set_input_as_handled()
	elif keycode == KEY_RIGHT:
		_select_next_hall()
		get_viewport().set_input_as_handled()
	elif keycode == KEY_LEFT:
		_select_previous_hall()
		get_viewport().set_input_as_handled()

# Absolute panel-space projection - MAIN_MAP_MARGIN + (world offset from
# the maze's own min corner) * scale, so the maze's top-left corner lands
# near the panel's top-left corner (with just the margin's breathing
# room), not centered on the panel the way the small radar centers on the
# diver.
func _project_to_main_map(pos: Vector3) -> Vector2:
	return Vector2(MAIN_MAP_MARGIN, MAIN_MAP_MARGIN) + (Vector2(pos.x, pos.z) - _main_map_origin) * _main_map_px_per_unit

# Keeps every resolved wall's Line2D up to date, projected through the
# fixed origin instead of the small radar's diver-relative one - only
# walls _update_revealed() has actually resolved are touched at all, an
# undiscovered wall gets no Line2D yet (and so shows up nowhere on the
# main map) until the diver has swum up to it on the radar first. Node
# creation only happens once per wall (see _update_main_map_hall_line()/
# _update_main_map_lone_line()), but .points get reassigned every frame
# regardless, same live re-projection as before - a wall can still swing
# open after its hall was first found, and a stale cached Line2D would
# silently lie about where it is.
func _refresh_main_map() -> void:
	if not _main_map_bounds_computed:
		_compute_main_map_bounds()
		if not _main_map_bounds_computed:
			return
	for box in maze_level.wall_boxes:
		if not is_instance_valid(box) or not _wall_to_hall.has(box):
			continue
		var seg := _box_segment(box)
		var p_a := _project_to_main_map(seg[0])
		var p_b := _project_to_main_map(seg[1])
		var hall_name: String = _wall_to_hall[box]
		if hall_name == "":
			_update_main_map_lone_line(box, p_a, p_b)
		else:
			_update_main_map_hall_line(hall_name, box, p_a, p_b)
	for hall_name in _hall_walls:
		_update_main_map_current_line(hall_name)
	if maze_level._diver != null and is_instance_valid(maze_level._diver):
		_main_map_diver_pos = _project_to_main_map(maze_level._diver.global_position)
	main_map.queue_redraw()
	_main_map_overlay.queue_redraw()

# hall_name's own wavy current line on the main map - a single persistent
# Line2D (see _main_map_current_lines' own comment for why one, not a
# pair like the walls get), created lazily then just repositioned every
# frame after that, same pattern as _update_main_map_lone_line() below.
func _update_main_map_current_line(hall_name: String) -> void:
	var path := _hall_current_path(hall_name)
	if path.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in path:
		pts.append(_project_to_main_map(p))
	var is_new := not _main_map_current_lines.has(hall_name)
	if is_new:
		var line := _make_main_map_line()
		line.default_color = Color(0.35, 0.75, 0.95, 0.85)
		line.width = 1.5
		_main_map_current_lines[hall_name] = line
	(_main_map_current_lines[hall_name] as Line2D).points = pts
	if is_new and hall_name == selectedCurrentName:
		_restart_main_map_current_blink()

# One persistent Line2D per standalone wall - created the first time this
# particular box is seen, just repositioned on every call after that.
func _update_main_map_lone_line(box: CSGBox3D, p_a: Vector2, p_b: Vector2) -> void:
	if not _main_map_lone_lines.has(box):
		_main_map_lone_lines[box] = _make_main_map_line()
	(_main_map_lone_lines[box] as Line2D).points = PackedVector2Array([p_a, p_b])

# One persistent Line2D per wall in the hall (see _main_map_hall_lines'
# own comment for why it's one-per-wall rather than one-per-hall) - the
# pair is created together the first time ANY of the hall's walls is seen,
# indexed to match _hall_walls[hall_name]'s own wall order so box always
# lands on the same Line2D across calls. If this is the hall the player
# currently has selected, kick the blink tween off now that there's
# something real for it to animate (see _restart_main_map_blink()).
func _update_main_map_hall_line(hall_name: String, box: CSGBox3D, p_a: Vector2, p_b: Vector2) -> void:
	var is_new := not _main_map_hall_lines.has(hall_name)
	if is_new:
		var lines: Array[Line2D] = []
		var walls: Array[CSGBox3D] = _hall_walls[hall_name]
		for i in range(walls.size()):
			lines.append(_make_main_map_line())
		_main_map_hall_lines[hall_name] = lines
	var walls: Array[CSGBox3D] = _hall_walls[hall_name]
	var idx := walls.find(box)
	if idx == -1:
		return
	var lines: Array[Line2D] = _main_map_hall_lines[hall_name]
	lines[idx].points = PackedVector2Array([p_a, p_b])
	if is_new and hall_name == selectedHallName:
		_restart_main_map_blink()

# The nearest HALL to a click at `p` on main_map (by name, e.g. "1"), or
# "" if nothing is within `max_dist` pixels - tests against each hall's
# own Line2D nodes (_main_map_hall_lines, both its walls together), so
# clicking near either wall of a hall selects that whole hall as one unit
# rather than one specific wall.
func _pick_hall_at(p: Vector2, max_dist: float = 10.0) -> String:
	var best := ""
	var best_dist := max_dist
	for hall_name in _main_map_hall_lines:
		for line in (_main_map_hall_lines[hall_name] as Array[Line2D]):
			var pts := line.points
			if pts.size() < 2:
				continue
			var d := _point_to_segment_dist(p, pts[0], pts[1])
			if d < best_dist:
				best_dist = d
				best = hall_name
	return best

# The actual drawing - only ever called BY Godot, in response to
# queue_redraw() above, never called directly. main_map has no script of
# its own to override _draw() on, so the `draw` signal (connected in
# _build_main_map()) is what hooks a plain runtime Control into this
# callback instead.
func _on_main_map_draw() -> void:
	main_map.draw_rect(Rect2(Vector2.ZERO, main_map.size), Color(0.03, 0.06, 0.08, 0.92))
	# Walls themselves are no longer drawn here - _main_map_hall_lines and
	# _main_map_lone_lines are real Line2D children of main_map now (see
	# _make_main_map_line()), so Godot renders them on its own, right after
	# this background (a CanvasItem's own draw calls happen before its
	# children's). Blinking the selected hall is handled by
	# _restart_main_map_blink() tweening those nodes' .visible directly,
	# not by skipping a draw call here. The diver arrow and border used to
	# draw here too, right after the walls - moved to _main_map_overlay
	# (see _on_main_map_overlay_draw()) since they need to render ABOVE
	# the wall Line2D children now, which this function's own draw calls
	# can't do (a parent always draws before its children, regardless of
	# call order within its own _draw).

# Same idea as _on_main_map_draw() above, but for _main_map_overlay - see
# its z_index comment in _build_main_map() for why the diver arrow and
# border live in a separate node now instead of drawing here directly.
func _on_main_map_overlay_draw() -> void:
	var fwd := Vector2(0, -1)
	if maze_level != null and maze_level._diver != null and is_instance_valid(maze_level._diver):
		var f: Vector3 = -maze_level._diver.global_transform.basis.z
		fwd = Vector2(f.x, f.z)
	if fwd.length() < 0.01:
		fwd = Vector2(0, -1)
	fwd = fwd.normalized()
	var side := Vector2(-fwd.y, fwd.x)
	# _main_map_diver_pos is already an absolute panel-space point (see
	# _project_to_main_map()), not relative to panel center.
	var p := _main_map_diver_pos
	var tip := p + fwd * 9.0
	var back_l := p - fwd * 5.0 + side * 5.5
	var back_r := p - fwd * 5.0 - side * 5.5
	_main_map_overlay.draw_polygon(
		PackedVector2Array([tip, back_l, back_r]),
		PackedColorArray([Color(0.35, 0.95, 0.55)])
	)
	# Blue border, drawn last so it sits on top of the walls/arrow rather
	# than under them - filled=false makes this an outline, not a filled
	# rect over the whole panel.
	_main_map_overlay.draw_rect(Rect2(Vector2.ZERO, main_map.size), Color(0.3, 0.55, 0.95), false, 3.0)
