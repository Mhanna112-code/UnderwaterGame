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
# How close the diver has to get to a wall (nearest point) to reveal its
# group - "running into" it, not merely having it inside the radar circle.
@export var reveal_distance := 5.0

const WALL_COLOR := Color(0.6, 0.64, 0.68, 0.9)
const SELECTED_WALL_COLOR := Color(1.0, 0.82, 0.32, 1.0)
const FLOW_COLOR := Color(0.28, 0.82, 1.0, 0.95)
const ROOM_COLOR := Color(0.78, 0.66, 0.95, 0.95)

# Walls that reveal together: the moment the diver is within view_radius of
# ANY wall in a group, every wall in that group appears on both maps. Any
# wall in wall_boxes not named here (or in SECRET_ROOMS) reveals on its own.
const REVEAL_GROUPS := [
	["CSGBox3D", "CurrentWall3"],
	["CurrentWall1", "CurrentWall2"],
	["CSGBox3D6", "CSGBox3D7"],
	["CSGBox3D12", "CSGBox3D13"],
	["CSGBox3D8", "CSGBox3D9"],
	["CSGBox3D10", "CSGBox3D11"],
	["CSGBox3D14", "CSGBox3D15"],
	["CSGBox3D16", "CSGBox3D16North"],   # one wall, door in the middle
	["CSGBox3D27"],                      # the wall between 14 and 19
	["CSGBox3D18", "CSGBox3D19"],
	["CSGBox3D20", "CSGBox3D21"],
	["CSGBox3D22"],
	["CSGBox3D23"],
]

# Secret rooms reveal the same way, but draw as one closed box spanning
# their walls' extent rather than as the individual walls.
const SECRET_ROOMS := [
	["CSGBox3D24", "CSGBox3D25", "RewardChamberWestWall"],
	# 29, 33, 30, 32 and the door wall between 30 and 32: the whole block
	# (the secret boss room plus the hall in front of it).
	["CSGBox3D29", "CSGBox3D33", "CSGBox3D33North", "CSGBox3D30", "CSGBox3D32", "Box30DoorWallA", "Box30DoorWallB", "SecretBossRoomBack"],
	# The secret boss room.
	["CSGBox3D30", "Box30DoorWallA", "Box30DoorWallB", "SecretBossRoomBack"],
	# The main boss room.
	["MainBossRoomNorth", "MainBossRoomSouth", "MainBossRoomEast"],
]

var _reveal_groups_built := false
var _wall_groups: Array = []          # Array of Array[CSGBox3D]
var _room_walls: Array = []           # Array of Array[CSGBox3D], one per SECRET_ROOMS entry
var _room_wall_set: Dictionary = {}   # CSGBox3D -> true; drawn only as part of its room box
var _revealed_walls: Dictionary = {}  # CSGBox3D -> true
var _revealed_rooms: Dictionary = {}  # SECRET_ROOMS index -> true
var _main_map_room_lines: Dictionary = {}   # SECRET_ROOMS index -> Line2D
const SELECTED_FLOW_COLOR := Color(1.0, 0.68, 0.28, 1.0)
const HIDDEN_MARKER_COLOR := Color(1.0, 0.18, 0.18)   # hidden objects (sphere room)
const STRONG_ZONE_COLOR := Color(1.0, 0.15, 0.15)   # the strong encounter zone, flashing

# 0..1, pulsing - how bright the strong encounter zone is right now.
func _zone_alpha() -> float:
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.2)


func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	clip_contents = true
	_build_main_map()
	var blink := create_tween()
	blink.set_loops()
	blink.tween_callback(func() -> void: _rotatable_blink_on = not _rotatable_blink_on)
	blink.tween_interval(ROTATABLE_BLINK_INTERVAL)

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
	# While the map is closed the selection keeps tracking whatever wall set
	# and current are nearest, so that's what's selected when L opens it.
	# While it's open the player's arrow-key choice stands.
	# Unless the player has picked something themselves on the open map,
	# whatever wall set and current are nearest stay selected - map open or
	# not (the lever-dome map stays open while the levers are held).
	if not main_map.visible:
		_selection_manual = false
	if main_map.visible and _selection_manual:
		_validate_selection()
	else:
		_update_selected_rotatable_set()
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

# A corridor's real centre is its CollisionShape3D's, not the Area3D's own
# origin - the Area3D nodes sit away from the volumes they actually cover,
# which paired every corridor past the first with the same far-off walls.
func _corridor_center(corridor: Area3D) -> Vector3:
	for child in corridor.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).global_transform.origin
	return corridor.global_position

func _compute_corridor_wall_pairs() -> void:
	if maze_level == null:
		return
	_corridor_wall_pairs.clear()
	for corridor in maze_level.corridors:
		if not is_instance_valid(corridor):
			continue
		var center: Vector3 = _corridor_center(corridor)
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

# Player-facing discovery. hall name -> Array[CSGBox3D] size 2, keys
# assigned in the order the diver actually found each hall.
var _hall_walls: Dictionary = {}
# Hall name -> the actual WindCorridor Area3D enclosed by that hall's walls.
# This is deliberately distinct from raw #72's permanent hall-to-current
# association: `H` and `L` move controller objects between areas, so only
# MazeLevel._currents_by_corridor tells us where a flow truly exists now.
var _hall_corridors: Dictionary = {}
# A corridor may have no unique nearest wall pair (several share an authored
# boundary), but the player can still see and feel its flow. Track visual
# discovery separately from the wall-pair heuristic so a live current never
# vanishes simply because that heuristic assigned a shared wall elsewhere.
var _discovered_corridors: Dictionary = {}
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

# The currently highlighted *active flow area*.  It never names a wall pair
# or an old controller location. Shift+arrow cycles this independently from
# selectedHallName so map readers can inspect a current without losing their
# wall selection.
var selectedCurrentCorridor: Area3D

# The selected rotatable wall set (one entry of MazeLevel.rotatable_wall_sets()),
# or {}. While the map is closed it tracks the set nearest the diver (and
# selectedCurrentCorridor the nearest current); once L opens the map,
# Left/Right steps through revealed sets and Shift+Left/Right through
# currents. The map blinks both; E rotates the set, R the current.
var selected_rotatable_set: Dictionary = {}
var _rotatable_blink_on := true
const ROTATABLE_BLINK_INTERVAL := 0.4
const BLINK_FLOW_COLOR := Color(0.62, 0.96, 1.0, 1.0)
const DIM_FLOW_COLOR := Color(0.28, 0.82, 1.0, 0.3)

# Blink clock for selectedHall's highlight on the SMALL RADAR's _draw()
# only - the main map's own blink is separate (see _restart_main_map_blink()
# down by _main_map_hall_lines), since it tweens real Line2D nodes
# directly instead. The radar has no persistent line Nodes to tween: every
# wall there is redrawn from scratch each frame via draw_line()/
# draw_multiline(), so "blinking" just means _draw() skips
# selectedHallName's own lines for one redraw whenever this is false.
# _process() already calls queue_redraw() every frame regardless of this,
# so flipping it here is picked up on the very next redraw with no extra
# signal needed. Started once in _ready() - a single looping clock works
# for whichever hall is selected at any given moment, it doesn't need
# restarting when selection changes (unlike the main map's tween, which
# targets specific nodes and so DOES need restarting - see
# _restart_main_map_blink()).
var _hall_blink_on := true

func _start_hall_blink() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_callback(func(): _hall_blink_on = true)
	tween.tween_interval(0.5)
	tween.tween_callback(func(): _hall_blink_on = false)
	tween.tween_interval(0.5)

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
	_update_revealed_groups(diver_pos)
	_update_found_pois(diver_pos)
	# A corridor - and so the current running through it - becomes visible
	# once a wall enclosing it has been revealed.
	for corridor in maze_level.corridors:
		if not is_instance_valid(corridor) or _discovered_corridors.has(corridor):
			continue
		var pair: Array = _corridor_wall_pairs.get(corridor, [])
		# Or once the diver is actually in it - a wide corridor's walls can
		# sit just past reveal_distance from its middle.
		if pair.any(func(box) -> bool: return _revealed_walls.has(box)) or corridor.overlaps_body(maze_level._diver) or diver_pos.distance_to(_corridor_center(corridor)) <= reveal_distance:
			_discovered_corridors[corridor] = true
	# Hall naming/selection now follows reveal instead of doing its own
	# distance check, and secret-room walls never join a hall.
	for box in maze_level.wall_boxes:
		if not is_instance_valid(box) or _wall_to_hall.has(box):
			continue
		if not _revealed_walls.has(box) or _room_wall_set.has(box):
			continue
		var corridor := _corridor_for_wall(box)
		if corridor == null:
			_wall_to_hall[box] = ""
			continue
		_hall_discovery_count += 1
		var hall_name := "WindCorridor%d" % _hall_discovery_count
		var walls: Array[CSGBox3D] = _corridor_wall_pairs[corridor]
		_hall_walls[hall_name] = walls
		_hall_corridors[hall_name] = corridor
		for wall in walls:
			_wall_to_hall[wall] = hall_name
		# Halls no longer become the selection on discovery - selection is
		# the nearest rotatable wall set (_update_selected_rotatable_set()).

# True once the player has chosen a wall set or current themselves (arrow
# keys, or R moving a current) on the open map; closing the map hands
# selection back to "nearest".
var _selection_manual := false
# How near a rotatable wall set has to be for it to be picked automatically.
const AUTO_SELECT_RADIUS_SCALE := 2.0   # x view_radius

# Picks the rotatable set nearest the diver: at least one of its walls must
# already be revealed, and the diver within AUTO_SELECT_RADIUS_SCALE x
# view_radius of one of them.
func _update_selected_rotatable_set() -> void:
	selected_rotatable_set = {}
	if maze_level == null or maze_level._diver == null or not is_instance_valid(maze_level._diver):
		return
	var diver_pos: Vector3 = maze_level._diver.global_position
	var diver2 := Vector2(diver_pos.x, diver_pos.z)
	var best_dist := INF
	for wall_set in maze_level.rotatable_wall_sets():
		var nearest := INF
		var any_revealed := false
		for box in wall_set["walls"]:
			if not is_instance_valid(box):
				continue
			any_revealed = any_revealed or _revealed_walls.has(box)
			var seg := _box_segment(box)
			nearest = minf(nearest, _point_to_segment_dist(diver2, Vector2(seg[0].x, seg[0].z), Vector2(seg[1].x, seg[1].z)))
		if any_revealed and nearest <= view_radius * AUTO_SELECT_RADIUS_SCALE and nearest < best_dist:
			best_dist = nearest
			selected_rotatable_set = wall_set
	selectedCurrentCorridor = _nearest_current(diver_pos)

# The active, discovered current whose corridor centre is nearest `at`.
func _nearest_current(at: Vector3) -> Area3D:
	var best: Area3D = null
	var best_dist := INF
	for corridor in maze_level._currents_by_corridor:
		if not is_instance_valid(corridor) or not _is_discovered_corridor(corridor as Area3D):
			continue
		var dist := _distance_to_corridor(corridor as Area3D, at)
		if dist < best_dist:
			best_dist = dist
			best = corridor as Area3D
	return best

# How far `at` is from the nearest point of a corridor's push zone (0 inside
# it) - fairer than its centre, since some corridors are long.
func _distance_to_corridor(corridor: Area3D, at: Vector3) -> float:
	for child in corridor.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			var half := (shape_node.shape as BoxShape3D).size * 0.5
			var local := shape_node.global_transform.affine_inverse() * at
			var inside := local.clamp(-half, half)
			return (shape_node.global_transform * inside).distance_to(at)
	return _corridor_center(corridor).distance_to(at)

# Drops a selection that no longer exists or is no longer discovered.
func _validate_selection() -> void:
	if selectedCurrentCorridor != null and (not is_instance_valid(selectedCurrentCorridor) or not maze_level._currents_by_corridor.has(selectedCurrentCorridor) or not _is_discovered_corridor(selectedCurrentCorridor)):
		selectedCurrentCorridor = null

# Left/Right on the open map: step through the rotatable wall sets the diver
# has revealed (at least one wall seen), the way Shift+Left/Right steps
# through currents.
func _cycle_selected_set(direction: int) -> void:
	var sets: Array = []
	for wall_set in maze_level.rotatable_wall_sets():
		for box in wall_set["walls"]:
			if is_instance_valid(box) and _revealed_walls.has(box):
				sets.append(wall_set)
				break
	if sets.is_empty():
		return
	var index := -1
	for i in sets.size():
		if sets[i]["name"] == selected_rotatable_set.get("name", ""):
			index = i
	if index == -1:
		index = 0 if direction > 0 else sets.size() - 1
	else:
		index = wrapi(index + direction, 0, sets.size())
	selected_rotatable_set = sets[index]
	_selection_manual = true

# The active current running between a set's walls right now: the current
# corridor nearest the middle of the set, if it sits inside the gap between
# the walls. Read live, so after a rotation it follows wherever the walls
# and currents actually ended up (or is null if no current runs there).
func _current_between(wall_set: Dictionary) -> Area3D:
	var centres: Array[Vector2] = []
	for box in wall_set.get("walls", []):
		if is_instance_valid(box):
			centres.append(Vector2((box as CSGBox3D).global_position.x, (box as CSGBox3D).global_position.z))
	if centres.size() < 2:
		return null
	var mid := (centres[0] + centres[1]) * 0.5
	var half_gap := centres[0].distance_to(centres[1]) * 0.5
	var best: Area3D = null
	var best_dist := half_gap
	for corridor in maze_level._currents_by_corridor:
		var area := corridor as Area3D
		if area == null or not is_instance_valid(area):
			continue
		var area_center := _corridor_center(area)
		var d := Vector2(area_center.x, area_center.z).distance_to(mid)
		if d < best_dist:
			best_dist = d
			best = area
	return best

func _main_map_line_for(box: CSGBox3D) -> Line2D:
	var hall_name: String = _wall_to_hall.get(box, "")
	if hall_name == "":
		return _main_map_lone_lines.get(box, null) as Line2D
	if not _main_map_hall_lines.has(hall_name) or not _hall_walls.has(hall_name):
		return null
	var index := (_hall_walls[hall_name] as Array[CSGBox3D]).find(box)
	var lines: Array[Line2D] = _main_map_hall_lines[hall_name]
	return lines[index] if index >= 0 and index < lines.size() else null

# Resets every wall/current line to normal, then blinks the selected set's
# walls (amber <-> normal) and the current between them (bright <-> dim).
# Walls blink by colour rather than visibility so a selected wall never
# looks like an open gap.
func _apply_rotatable_highlight() -> void:
	for hall_name in _main_map_hall_lines:
		for line in (_main_map_hall_lines[hall_name] as Array[Line2D]):
			line.visible = true
			line.default_color = WALL_COLOR
			line.width = 2.0
	for box in _main_map_lone_lines:
		var lone := _main_map_lone_lines[box] as Line2D
		lone.default_color = WALL_COLOR
		lone.width = 2.0
	for corridor in _main_map_current_lines:
		(_main_map_current_lines[corridor] as Line2D).default_color = FLOW_COLOR
		(_main_map_current_lines[corridor] as Line2D).width = 2.2
		if _main_map_current_heads.has(corridor):
			(_main_map_current_heads[corridor] as Polygon2D).color = FLOW_COLOR
	if not selected_rotatable_set.is_empty():
		for box in selected_rotatable_set["walls"]:
			var line := _main_map_line_for(box as CSGBox3D)
			if line != null:
				line.default_color = SELECTED_WALL_COLOR if _rotatable_blink_on else WALL_COLOR
				line.width = 3.2
	var current := selectedCurrentCorridor
	if current != null and _main_map_current_lines.has(current):
		var flow_color := BLINK_FLOW_COLOR if _rotatable_blink_on else DIM_FLOW_COLOR
		(_main_map_current_lines[current] as Line2D).default_color = flow_color
		(_main_map_current_lines[current] as Line2D).width = 3.4
		if _main_map_current_heads.has(current):
			(_main_map_current_heads[current] as Polygon2D).color = flow_color

# R: rotate the selected current to its paired corridor, and keep it
# selected in its new place (that corridor counts as discovered - the
# player just sent a current into it).
func _rotate_selected_current() -> void:
	if selectedCurrentCorridor == null:
		return
	var moved_to: Area3D = maze_level.rotate_current_in(selectedCurrentCorridor)
	if moved_to != null:
		_discovered_corridors[moved_to] = true
		selectedCurrentCorridor = moved_to
		_selection_manual = true   # keep following the current just moved

func _rotate_selected_set() -> void:
	if selected_rotatable_set.is_empty():
		return
	(selected_rotatable_set["rotate"] as Callable).call()

# Resolves REVEAL_GROUPS/SECRET_ROOMS node names once, then gives every
# remaining wall its own single-wall group.
func _build_reveal_groups() -> void:
	var grouped: Dictionary = {}
	for names in REVEAL_GROUPS:
		var group: Array[CSGBox3D] = []
		for wall_name in names:
			var box := maze_level.get_node_or_null(String(wall_name)) as CSGBox3D
			if box != null:
				group.append(box)
				grouped[box] = true
		if not group.is_empty():
			_wall_groups.append(group)
	for names in SECRET_ROOMS:
		var room: Array[CSGBox3D] = []
		for wall_name in names:
			var box := maze_level.get_node_or_null(String(wall_name)) as CSGBox3D
			if box != null:
				room.append(box)
				grouped[box] = true
				_room_wall_set[box] = true
		_room_walls.append(room)
	for box in maze_level.wall_boxes:
		if is_instance_valid(box) and not grouped.has(box):
			var single: Array[CSGBox3D] = [box]
			_wall_groups.append(single)
	_reveal_groups_built = true

# Within reveal_distance of the wall's nearest point (not its midpoint), so
# a long wall reveals as soon as you reach any part of it.
func _wall_in_reach(box: CSGBox3D, diver_pos: Vector3) -> bool:
	if not is_instance_valid(box):
		return false
	var seg := _box_segment(box)
	return _point_to_segment_dist(Vector2(diver_pos.x, diver_pos.z), Vector2(seg[0].x, seg[0].z), Vector2(seg[1].x, seg[1].z)) <= reveal_distance

func _any_wall_in_reach(walls: Array, diver_pos: Vector3) -> bool:
	for box in walls:
		if _wall_in_reach(box as CSGBox3D, diver_pos):
			return true
	return false

func _update_revealed_groups(diver_pos: Vector3) -> void:
	if not _reveal_groups_built:
		_build_reveal_groups()
	for group in _wall_groups:
		if _revealed_walls.has(group[0]):
			continue
		if _any_wall_in_reach(group, diver_pos):
			for box in group:
				_revealed_walls[box] = true
	for i in range(_room_walls.size()):
		if _revealed_rooms.has(i) or (_room_walls[i] as Array).is_empty():
			continue
		if _any_wall_in_reach(_room_walls[i], diver_pos):
			_revealed_rooms[i] = true

# Corners of the axis-aligned box spanning a secret room's walls, in world
# space (y unused), in draw order.
func _room_corners(i: int) -> Array[Vector3]:
	var rect := Rect2()
	var first := true
	if maze_level != null and i < SECRET_ROOMS.size():
		var real: Rect2 = maze_level.map_room_rect(SECRET_ROOMS[i])
		if real.size != Vector2.ZERO:
			rect = real
			first = false
			return [
				Vector3(rect.position.x, 0.0, rect.position.y), Vector3(rect.end.x, 0.0, rect.position.y),
				Vector3(rect.end.x, 0.0, rect.end.y), Vector3(rect.position.x, 0.0, rect.end.y),
			]
	for box in _room_walls[i]:
		if not is_instance_valid(box):
			continue
		for p in _box_segment(box):
			var p2 := Vector2((p as Vector3).x, (p as Vector3).z)
			if first:
				rect = Rect2(p2, Vector2.ZERO)
				first = false
			else:
				rect = rect.expand(p2)
	return [
		Vector3(rect.position.x, 0.0, rect.position.y), Vector3(rect.end.x, 0.0, rect.position.y),
		Vector3(rect.end.x, 0.0, rect.end.y), Vector3(rect.position.x, 0.0, rect.end.y),
	]

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
		if not is_instance_valid(box) or not _revealed_walls.has(box) or _room_wall_set.has(box):
			continue
		var seg := _box_segment(box)
		var rel_a: Vector2 = Vector2(seg[0].x, seg[0].z) - Vector2(center.x, center.z)
		var rel_b: Vector2 = Vector2(seg[1].x, seg[1].z) - Vector2(center.x, center.z)
		var clipped: Array = _clip_to_circle(rel_a, rel_b, view_radius)
		if clipped.is_empty():
			continue
		var p_a: Vector2 = (clipped[0] as Vector2) * px_per_unit + mid
		var p_b: Vector2 = (clipped[1] as Vector2) * px_per_unit + mid
		var hall_name: String = _wall_to_hall.get(box, "")
		if hall_name == "":
			draw_line(p_a, p_b, Color(0.6, 0.64, 0.68, 0.9), 2.0)
			continue
		# PackedVector2Array is copied when read out of a Dictionary, so
		# appending in place left every hall's list empty and hall walls
		# (e.g. CurrentWall1/2) never drew on the radar. Write it back.
		var hall_list: PackedVector2Array = hall_points.get(hall_name, PackedVector2Array())
		hall_list.append(p_a)
		hall_list.append(p_b)
		hall_points[hall_name] = hall_list
	_radar_hall_points = hall_points
	for hall_name in hall_points:
		var points := hall_points[hall_name] as PackedVector2Array
		# A hall can be known to the minimap while every one of its segments
		# is outside this radar circle. Godot rejects an empty polyline and
		# otherwise prints an error every redraw.
		if points.size() >= 2:
			var wall_color := SELECTED_WALL_COLOR if hall_name == selectedHallName else WALL_COLOR
			var wall_width := 2.8 if hall_name == selectedHallName else 2.0
			draw_multiline(points, wall_color, wall_width)

	# While the big map is open (where E rotates them), the selected
	# rotatable walls blink amber here too, drawn over their normal lines.
	if main_map.visible and _rotatable_blink_on and not selected_rotatable_set.is_empty():
		for box in selected_rotatable_set["walls"]:
			if not is_instance_valid(box) or not _revealed_walls.has(box):
				continue
			var sel_seg := _box_segment(box)
			var sel_clip: Array = _clip_to_circle(Vector2(sel_seg[0].x - center.x, sel_seg[0].z - center.z), Vector2(sel_seg[1].x - center.x, sel_seg[1].z - center.z), view_radius)
			if sel_clip.is_empty():
				continue
			draw_line((sel_clip[0] as Vector2) * px_per_unit + mid, (sel_clip[1] as Vector2) * px_per_unit + mid, SELECTED_WALL_COLOR, 2.8)

	# Revealed secret rooms: one closed box each, clipped edge by edge.
	for i in _revealed_rooms:
		var corners := _room_corners(i)
		for k in range(4):
			var c_a: Vector3 = corners[k]
			var c_b: Vector3 = corners[(k + 1) % 4]
			var rel_ra := Vector2(c_a.x - center.x, c_a.z - center.z)
			var rel_rb := Vector2(c_b.x - center.x, c_b.z - center.z)
			var edge: Array = _clip_to_circle(rel_ra, rel_rb, view_radius)
			if edge.is_empty():
				continue
			draw_line((edge[0] as Vector2) * px_per_unit + mid, (edge[1] as Vector2) * px_per_unit + mid, ROOM_COLOR, 2.0)

	# Current arrows are derived from the live controller dictionary, not from
	# whatever two walls happened to be closest when a hall was discovered.
	# A current therefore disappears from Corridor 1 and reappears in Corridor
	# 3 as soon as H makes that real relocation.
	for corridor in maze_level._currents_by_corridor:
		if not _is_discovered_corridor(corridor as Area3D):
			continue
		_draw_current_flow(corridor as Area3D, maze_level._currents_by_corridor[corridor] as WaterCurrent, center, mid, px_per_unit)

	# Hidden objects (the sphere room's spheres) as red circles.
	for p in maze_level.hidden_marker_positions():
		var rel := Vector2(p.x - center.x, p.z - center.z)
		if rel.length() <= view_radius:
			draw_circle(rel * px_per_unit + mid, 2.0, HIDDEN_MARKER_COLOR)
	# Sonar: the secret item room's unbroken rocks.
	for p in maze_level.sonar_rock_positions():
		var rel := Vector2(p.x - center.x, p.z - center.z)
		if rel.length() <= view_radius:
			draw_circle(rel * px_per_unit + mid, 3.5, HIDDEN_MARKER_COLOR)

	# The strong encounter zone, flashing red (clipped to the radar circle).
	var zone := maze_level.strong_zone_for_map(_revealed_walls)
	if zone.size != Vector2.ZERO:
		var local := PackedVector2Array()
		for c in [zone.position, Vector2(zone.end.x, zone.position.y), zone.end, Vector2(zone.position.x, zone.end.y)]:
			local.append((c - Vector2(center.x, center.z)) * px_per_unit + mid)
		var circle := PackedVector2Array()
		for k in 32:
			circle.append(mid + Vector2.from_angle(TAU * k / 32.0) * (r - 2.0))
		var a := _zone_alpha()
		for piece in Geometry2D.intersect_polygons(local, circle):
			draw_colored_polygon(piece, Color(STRONG_ZONE_COLOR, 0.12 + 0.28 * a))
			var outline := piece.duplicate()
			outline.append(piece[0])
			draw_polyline(outline, Color(STRONG_ZONE_COLOR, 0.5 + 0.5 * a), 1.5)

	# Corridor numbers and the things found so far.
	for corridor in maze_level.corridors:
		if not _is_discovered_corridor(corridor):
			continue
		var cc := _corridor_center(corridor)
		var crel := Vector2(cc.x - center.x, cc.z - center.z)
		if crel.length() <= view_radius - 2.0:
			_draw_corridor_tag(self, crel * px_per_unit + mid, corridor, 10)
	for poi in _found_pois():
		var prel := Vector2((poi["pos"] as Vector3).x - center.x, (poi["pos"] as Vector3).z - center.z)
		if prel.length() <= view_radius - 2.0:
			_draw_poi(self, prel * px_per_unit + mid, poi, 0.8)

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

# A WaterCurrent is authoritative only through its collision Area3D and
# orientation. Its map shaft starts and ends inside that same BoxShape3D,
# matching the actual region that pushes a diver. This intentionally replaces
# the raw PR's attractive but wall-derived sine wave, which could continue to
# claim a current after its controller had moved somewhere else.
func _flow_path_for_corridor(corridor: Area3D, current: WaterCurrent) -> PackedVector3Array:
	var points := PackedVector3Array()
	if corridor == null or current == null or current.area != corridor or current.orientation.length_squared() < 0.0001:
		return points
	var shape_node: CollisionShape3D
	for child in corridor.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			shape_node = child as CollisionShape3D
			break
	if shape_node == null:
		return points
	var shape := shape_node.shape as BoxShape3D
	var flow := current.orientation.normalized()
	var local_flow := shape_node.global_transform.basis.inverse() * flow
	var travel_extent := absf(local_flow.x) * shape.size.x + absf(local_flow.y) * shape.size.y + absf(local_flow.z) * shape.size.z
	if travel_extent < 0.01:
		return points
	var center := shape_node.global_transform * Vector3.ZERO
	# Stay slightly inside both ends: the arrow describes the push zone without
	# visually crossing the two solid end walls that frame it.
	var half_span := travel_extent * 0.42
	points.append(center - flow * half_span)
	points.append(center + flow * half_span)
	return points

func _is_discovered_corridor(corridor: Area3D) -> bool:
	return corridor != null and _discovered_corridors.has(corridor)

# Rebind discovered geometry to fresh scene nodes. Instance IDs are not save
# identities, and discovering the return panel must not erase earlier halls.
func campaign_discovery() -> Dictionary:
	var data := {"walls": [], "rooms": _revealed_rooms.keys(), "corridors": [],
		"halls": [], "count": _hall_discovery_count, "pois": _found_poi_ids.keys()}
	for wall in _revealed_walls:
		if is_instance_valid(wall):
			data.walls.append(String((wall as Node).name))
	for corridor in _discovered_corridors:
		if is_instance_valid(corridor):
			data.corridors.append(String((corridor as Node).name))
	for hall_name in _hall_walls:
		var names: Array[String] = []
		for wall in _hall_walls[hall_name]:
			if is_instance_valid(wall):
				names.append(String((wall as Node).name))
		var corridor := _hall_corridors.get(hall_name) as Node
		data.halls.append({"name": String(hall_name), "walls": names,
			"corridor": String(corridor.name) if is_instance_valid(corridor) else ""})
	return data

func restore_campaign_discovery(data: Dictionary) -> void:
	_revealed_walls.clear()
	_revealed_rooms.clear()
	_discovered_corridors.clear()
	_hall_walls.clear()
	_hall_corridors.clear()
	_wall_to_hall.clear()
	_found_poi_ids.clear()
	for name_value in data.walls:
		var wall := maze_level.get_node_or_null(String(name_value)) as CSGBox3D
		if wall != null:
			_revealed_walls[wall] = true
			_wall_to_hall[wall] = ""
	for room in data.rooms:
		_revealed_rooms[int(room)] = true
	for name_value in data.corridors:
		var corridor := maze_level.get_node_or_null(String(name_value)) as Area3D
		if corridor != null:
			_discovered_corridors[corridor] = true
	for spec in data.halls:
		var walls: Array[CSGBox3D] = []
		for name_value in spec.walls:
			var wall := maze_level.get_node_or_null(String(name_value)) as CSGBox3D
			if wall != null:
				walls.append(wall)
				_wall_to_hall[wall] = String(spec.name)
		_hall_walls[String(spec.name)] = walls
		_hall_corridors[String(spec.name)] = maze_level.get_node_or_null(String(spec.corridor))
	_hall_discovery_count = int(data.count)
	for id in data.pois:
		_found_poi_ids[String(id)] = true
	_main_map_bounds_computed = false
	_corridor_wall_pairs_computed = false

func _draw_current_flow(corridor: Area3D, current: WaterCurrent, center: Vector3, mid: Vector2, px_per_unit: float) -> void:
	var path := _flow_path_for_corridor(corridor, current)
	if path.size() < 2:
		return
	var rel_a := Vector2(path[0].x - center.x, path[0].z - center.z)
	var rel_b := Vector2(path[1].x - center.x, path[1].z - center.z)
	var clipped := _clip_to_circle(rel_a, rel_b, view_radius)
	if clipped.is_empty():
		return
	var start := (clipped[0] as Vector2) * px_per_unit + mid
	var end := (clipped[1] as Vector2) * px_per_unit + mid
	# Same blue wavy line + arrowhead as the big map. The selected current
	# blinks bright/dim blue only while the big map is open (where R can
	# rotate it); otherwise it's drawn like every other current.
	var color := FLOW_COLOR
	if corridor == selectedCurrentCorridor and main_map.visible:
		color = BLINK_FLOW_COLOR if _rotatable_blink_on else DIM_FLOW_COLOR
	_draw_wavy_flow_arrow(start, end, color, 2.0)

func _draw_wavy_flow_arrow(start: Vector2, end: Vector2, color: Color, width: float) -> void:
	var facing := end - start
	if facing.length() < 0.01:
		return
	facing = facing.normalized()
	var base := end - facing * 7.0
	draw_polyline(_wavy_points(start, base, end), color, width)
	var side := Vector2(-facing.y, facing.x)
	draw_polygon(PackedVector2Array([end, base + side * 3.6, base - side * 3.6]), PackedColorArray([color]))

func _draw_flow_arrow(start: Vector2, end: Vector2, color: Color, width: float) -> void:
	var facing := end - start
	if facing.length() < 0.01:
		return
	draw_line(start, end, color, width)
	facing = facing.normalized()
	var side := Vector2(-facing.y, facing.x)
	var base := end - facing * 7.0
	draw_polygon(PackedVector2Array([end, base + side * 3.6, base - side * 3.6]), PackedColorArray([color]))

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
# Room kept clear at the top for the title and at the bottom for the legend,
# so the whole maze is drawn between them.
const MAIN_MAP_HEADER := 44.0
const MAIN_MAP_FOOTER := 30.0
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
# Area3D -> Line2D / Polygon2D. These keys are live corridor nodes rather
# than discovery-order hall names: moving an active controller from Corridor
# 2 to Corridor 3 must move the visual with the controller, not leave it
# attached to the old hall.
var _main_map_current_lines: Dictionary = {}
var _main_map_current_heads: Dictionary = {}
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
	# A selected wall is highlighted rather than blinked invisible. A blink can
	# look like an open gap precisely while the player is deciding whether it is
	# safe to swim there; a persistent warm outline conveys selection without
	# making the collision map lie.
	for hall_name in _main_map_hall_lines:
		var lines: Array[Line2D] = _main_map_hall_lines[hall_name]
		var hall_selected: bool = hall_name == selectedHallName
		for line in lines:
			line.visible = true
			line.default_color = SELECTED_WALL_COLOR if hall_selected else WALL_COLOR
			line.width = 3.2 if hall_selected else 2.0

func _refresh_current_highlight() -> void:
	for corridor in _main_map_current_lines:
		var selected: bool = corridor == selectedCurrentCorridor
		var line := _main_map_current_lines[corridor] as Line2D
		line.default_color = SELECTED_FLOW_COLOR if selected else FLOW_COLOR
		line.width = 3.4 if selected else 2.2
		if _main_map_current_heads.has(corridor):
			(_main_map_current_heads[corridor] as Polygon2D).color = SELECTED_FLOW_COLOR if selected else FLOW_COLOR
	_refresh_map_copy()

# Common setup for every Line2D this main map creates (hall or standalone)
# - added as a child of main_map so it renders in the same panel-space
# coordinates _project_to_main_map() already produces (main_map's own
# transform is identity, so a Line2D child at the default position 0,0
# treats its .points as directly being that panel space).
func _make_main_map_line() -> Line2D:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = WALL_COLOR
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
	var usable_w: float = MAIN_MAP_SIZE - MAIN_MAP_MARGIN * 2.0
	var usable_h: float = MAIN_MAP_SIZE - MAIN_MAP_HEADER - MAIN_MAP_FOOTER
	_main_map_px_per_unit = minf(usable_w / span_x, usable_h / span_z)
	_main_map_bounds_computed = true

func _build_main_map() -> void:
	main_map = Control.new()
	main_map.name = "MazeMainMap"
	main_map.size = Vector2(MAIN_MAP_SIZE, MAIN_MAP_SIZE)
	main_map.custom_minimum_size = Vector2(MAIN_MAP_SIZE, MAIN_MAP_SIZE)
	main_map.position = Vector2(18.0, 76.0)
	main_map.clip_contents = true
	main_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_map.z_index = 4
	# Starts closed - L toggles it (see _unhandled_input()).
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
	_build_main_map_copy()

func _make_map_label(node_name: String, text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.07, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 3
	main_map.add_child(label)
	return label

func _build_main_map_copy() -> void:
	_make_map_label("MazeMapTitle", "MAZE NAVIGATION   [L] Close", Vector2(16, 10), Vector2(468, 28), 19, Color(0.86, 0.94, 1.0))
	# The legend: each map symbol drawn as it appears on the map, with what
	# it means to its right.
	var legend := Control.new()
	legend.name = "MazeMapLegend"
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.z_index = 3
	legend.position = Vector2(16, MAIN_MAP_SIZE - 26)
	legend.size = Vector2(468, 22)
	legend.draw.connect(_draw_legend.bind(legend))
	main_map.add_child(legend)
	_build_map_help()

const LEGEND_TEXT_COLOR := Color(0.73, 0.87, 0.96)
const LEGEND_FONT_SIZE := 13

func _draw_legend(legend: Control) -> void:
	var font := ThemeDB.fallback_font
	var mid_y := legend.size.y * 0.5
	var x := 0.0
	for entry in [["wall", "walls"], ["current", "current"], ["you", "you"], ["room", "visited room"]]:
		var icon_w := 22.0
		match String(entry[0]):
			"wall":
				legend.draw_line(Vector2(x, mid_y), Vector2(x + icon_w, mid_y), WALL_COLOR, 2.0)
			"current":
				var pts := PackedVector2Array()
				for k in 9:
					var u := k / 8.0
					pts.append(Vector2(x + u * (icon_w - 6.0), mid_y + sin(u * TAU * 1.5) * 2.5))
				legend.draw_polyline(pts, FLOW_COLOR, 2.0)
				var tip := Vector2(x + icon_w, mid_y)
				legend.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-6, -4), tip + Vector2(-6, 4)]), FLOW_COLOR)
			"you":
				var c := Vector2(x + icon_w * 0.5, mid_y)
				legend.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(-5.5, 5), c + Vector2(5.5, 5)]), Color(0.35, 0.95, 0.55))
			"room":
				legend.draw_rect(Rect2(x + 2, mid_y - 6, icon_w - 4, 12), ROOM_COLOR, false, 2.0)
		x += icon_w + 6.0
		var label := String(entry[1])
		legend.draw_string(font, Vector2(x, mid_y + LEGEND_FONT_SIZE * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, LEGEND_TEXT_COLOR)
		x += font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE).x + 18.0

# The controls, big and clear, in a panel right under the map: walls and
# currents only move from here.
var _map_help: PanelContainer
var _map_help_label: RichTextLabel

func _build_map_help() -> void:
	_map_help = PanelContainer.new()
	_map_help.name = "MazeMapHelp"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.1, 1.0)
	style.border_color = Color(0.45, 0.7, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_map_help.add_theme_stylebox_override("panel", style)
	_map_help.position = main_map.position + Vector2(0, MAIN_MAP_SIZE + 6)
	_map_help.custom_minimum_size = Vector2(MAIN_MAP_SIZE, 0)
	_map_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_help.z_index = 4
	# The keys drawn as the same dark key badges as the ability popup
	# (Slot._badge()).
	_map_help_label = RichTextLabel.new()
	_map_help_label.bbcode_enabled = true
	_map_help_label.fit_content = true
	_map_help_label.scroll_active = false
	_map_help_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_map_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_help_label.add_theme_font_size_override("normal_font_size", 16)
	_map_help_label.add_theme_color_override("default_color", Color(0.92, 0.97, 1.0))
	_map_help_label.text = "%s / %s  choose a selected hallway   ·   %s  rotate it\n%s + %s / %s  choose a selected current   ·   %s  rotate it" % [
		Slot._badge("Left"), Slot._badge("Right"), Slot._badge("E"),
		Slot._badge("Shift"), Slot._badge("Left"), Slot._badge("Right"), Slot._badge("R"),
	]
	_map_help.add_child(_map_help_label)
	main_map.get_parent().add_child(_map_help)
	_map_help.visible = false
	main_map.visibility_changed.connect(_refresh_map_copy)

func _refresh_map_copy() -> void:
	if main_map == null:
		return
	var title := main_map.get_node_or_null("MazeMapTitle") as Label
	if title != null:
		title.text = "MAZE NAVIGATION   " + (maze_level.lever_map_close_hint() if maze_level != null and maze_level.levers_map_mode() else "[L] Close")
	var legend := main_map.get_node_or_null("MazeMapLegend") as Control
	if legend != null:
		legend.visible = maze_level == null or not maze_level.levers_map_mode()
		if _map_help != null:
			# The lever map has its own controls list under the map instead.
			_map_help.visible = main_map.visible and legend.visible
			# The bottom-left HUD captions sit where the help panel goes.
			for caption in ["Controls", "GoalLabel"]:
				var node := get_parent().get_node_or_null(caption) as CanvasItem
				if node != null:
					node.visible = not _map_help.visible

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo):
		return
	if maze_level != null and (maze_level._battling or maze_level.any_modal_open()):
		return
	var key_event := event as InputEventKey
	var keycode: Key = key_event.keycode
	# While both dome levers are held, MazeLevel decides what opens/closes
	# the map and which keys are off-limits (see handle_lever_map_key());
	# the map's own select/rotate keys below still apply.
	if maze_level != null and maze_level.handle_lever_map_key(keycode):
		get_viewport().set_input_as_handled()
		return
	if keycode == KEY_L:
		main_map.visible = not main_map.visible
		_selection_manual = false
		if main_map.visible:
			_update_selected_rotatable_set()
			main_map.queue_redraw()
		get_viewport().set_input_as_handled()
	elif main_map.visible and keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
		# Confirm: rotate the blinking set. Handled here so E doesn't also
		# reach MazeLevel's relic interaction while the map is open.
		_rotate_selected_set()
		get_viewport().set_input_as_handled()
	elif main_map.visible and keycode in [KEY_LEFT, KEY_RIGHT] and key_event.shift_pressed:
		_cycle_selected_current(1 if keycode == KEY_RIGHT else -1)
		get_viewport().set_input_as_handled()
	elif main_map.visible and keycode in [KEY_LEFT, KEY_RIGHT]:
		_cycle_selected_set(1 if keycode == KEY_RIGHT else -1)
		get_viewport().set_input_as_handled()
	elif main_map.visible and keycode == KEY_R:
		_rotate_selected_current()
		get_viewport().set_input_as_handled()

# Absolute panel-space projection - MAIN_MAP_MARGIN + (world offset from
# the maze's own min corner) * scale, so the maze's top-left corner lands
# near the panel's top-left corner (with just the margin's breathing
# room), not centered on the panel the way the small radar centers on the
# diver.
func _project_to_main_map(pos: Vector3) -> Vector2:
	return Vector2(MAIN_MAP_MARGIN, MAIN_MAP_HEADER) + (Vector2(pos.x, pos.z) - _main_map_origin) * _main_map_px_per_unit

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
		if not is_instance_valid(box) or not _revealed_walls.has(box) or _room_wall_set.has(box):
			continue
		var seg := _box_segment(box)
		var p_a := _project_to_main_map(seg[0])
		var p_b := _project_to_main_map(seg[1])
		var hall_name: String = _wall_to_hall.get(box, "")
		if hall_name == "":
			_update_main_map_lone_line(box, p_a, p_b)
		else:
			_update_main_map_hall_line(hall_name, box, p_a, p_b)
	for i in _revealed_rooms:
		if not _main_map_room_lines.has(i):
			var room_line := _make_main_map_line()
			room_line.default_color = ROOM_COLOR
			room_line.closed = true
			_main_map_room_lines[i] = room_line
		var room_points := PackedVector2Array()
		for corner in _room_corners(i):
			room_points.append(_project_to_main_map(corner))
		(_main_map_room_lines[i] as Line2D).points = room_points
	_refresh_current_lines()
	_apply_rotatable_highlight()
	_refresh_map_copy()
	if maze_level._diver != null and is_instance_valid(maze_level._diver):
		_main_map_diver_pos = _project_to_main_map(maze_level._diver.global_position)
	main_map.queue_redraw()
	_main_map_overlay.queue_redraw()

func _refresh_current_lines() -> void:
	var active_discovered: Dictionary = {}
	for corridor in maze_level._currents_by_corridor:
		var area := corridor as Area3D
		if area == null or not _is_discovered_corridor(area):
			continue
		var current := maze_level._currents_by_corridor[corridor] as WaterCurrent
		if current == null:
			continue
		active_discovered[area] = true
		_update_main_map_current_line(area, current)
	for stale in _main_map_current_lines.keys():
		if active_discovered.has(stale):
			continue
		var stale_line := _main_map_current_lines[stale] as Line2D
		stale_line.queue_free()
		_main_map_current_lines.erase(stale)
		if _main_map_current_heads.has(stale):
			(_main_map_current_heads[stale] as Polygon2D).queue_free()
			_main_map_current_heads.erase(stale)
	_refresh_current_highlight()

func _update_main_map_current_line(corridor: Area3D, current: WaterCurrent) -> void:
	var path := _flow_path_for_corridor(corridor, current)
	if path.size() < 2:
		return
	var start := _project_to_main_map(path[0])
	var end := _project_to_main_map(path[1])
	if not _main_map_current_lines.has(corridor):
		var line := _make_main_map_line()
		line.name = "Current_%s" % corridor.name
		line.default_color = FLOW_COLOR
		line.width = 2.2
		_main_map_current_lines[corridor] = line
		var head := Polygon2D.new()
		head.name = "CurrentArrow_%s" % corridor.name
		head.color = FLOW_COLOR
		main_map.add_child(head)
		_main_map_current_heads[corridor] = head
	var facing := end - start
	if facing.length() < 0.01:
		(_main_map_current_lines[corridor] as Line2D).points = PackedVector2Array([start, end])
		return
	facing = facing.normalized()
	(_main_map_current_lines[corridor] as Line2D).points = _wavy_points(start, end - facing * 10.0, end)
	var side := Vector2(-facing.y, facing.x)
	var base := end - facing * 10.0
	(_main_map_current_heads[corridor] as Polygon2D).polygon = PackedVector2Array([end, base + side * 4.8, base - side * 4.8])

# A sine wave from `start` to `wave_end`, then straight into `end` (the
# arrow tip), so the current reads as moving water. First/last points stay
# exactly start/end, so the line still spans the live flow area.
func _wavy_points(start: Vector2, wave_end: Vector2, end: Vector2) -> PackedVector2Array:
	const WAVELENGTH := 14.0
	const AMPLITUDE := 3.0
	var points := PackedVector2Array()
	var run := wave_end - start
	var length := run.length()
	if length < 1.0:
		return PackedVector2Array([start, end])
	var along := run / length
	var side := Vector2(-along.y, along.x)
	var steps := maxi(2, int(length / 2.0))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var dist := length * t
		var offset := sin(dist / WAVELENGTH * TAU) * AMPLITUDE * (1.0 if i < steps else 0.0)
		points.append(start + along * dist + side * offset)
	points.append(end)
	return points

func _cycle_selected_current(direction: int) -> void:
	var corridors: Array = []
	for corridor in maze_level._currents_by_corridor:
		if _is_discovered_corridor(corridor as Area3D):
			corridors.append(corridor)
	corridors.sort_custom(func(a, b) -> bool: return String((a as Node).name) < String((b as Node).name))
	if corridors.is_empty():
		return
	var index := corridors.find(selectedCurrentCorridor)
	index = wrapi((0 if index == -1 else index) + direction, 0, corridors.size())
	selectedCurrentCorridor = corridors[index] as Area3D
	_selection_manual = true
	_refresh_current_highlight()

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
	if maze_level != null:
		for hp in maze_level.hidden_marker_positions():
			_main_map_overlay.draw_circle(_project_to_main_map(hp), 2.0, HIDDEN_MARKER_COLOR)
		for rp in maze_level.sonar_rock_positions():
			_main_map_overlay.draw_circle(_project_to_main_map(rp), 3.5, HIDDEN_MARKER_COLOR)
		var zone := maze_level.strong_zone_for_map(_revealed_walls)
		if zone.size != Vector2.ZERO:
			var p0 := _project_to_main_map(Vector3(zone.position.x, 0, zone.position.y))
			var p1 := _project_to_main_map(Vector3(zone.end.x, 0, zone.end.y))
			var a := _zone_alpha()
			_main_map_overlay.draw_rect(Rect2(p0, p1 - p0), Color(STRONG_ZONE_COLOR, 0.12 + 0.28 * a))
			_main_map_overlay.draw_rect(Rect2(p0, p1 - p0), Color(STRONG_ZONE_COLOR, 0.5 + 0.5 * a), false, 2.0)
		for corridor in maze_level.corridors:
			if _is_discovered_corridor(corridor):
				_draw_corridor_tag(_main_map_overlay, _project_to_main_map(_corridor_center(corridor)), corridor, 11)
		for poi in _found_pois():
			_draw_poi(_main_map_overlay, _project_to_main_map(poi["pos"] as Vector3), poi, 1.0)
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

# --- Points of interest -----------------------------------------------------------
# Things the diver has come across (MazeLevel.map_points_of_interest()):
# each appears on both maps once the diver has been within its radius (or
# inside its rect), and stays.
var _found_poi_ids: Dictionary = {}

func _update_found_pois(diver_pos: Vector3) -> void:
	if not maze_level.has_method("map_points_of_interest"):
		return
	var d2 := Vector2(diver_pos.x, diver_pos.z)
	for poi in maze_level.map_points_of_interest():
		var id := String(poi["id"])
		if _found_poi_ids.has(id):
			continue
		if poi.has("rect"):
			if (poi["rect"] as Rect2).has_point(d2):
				_found_poi_ids[id] = true
		else:
			var p := poi["pos"] as Vector3
			if is_inf(float(poi["radius"])) or d2.distance_to(Vector2(p.x, p.z)) <= float(poi["radius"]):
				_found_poi_ids[id] = true

func _found_pois() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if maze_level == null or not maze_level.has_method("map_points_of_interest"):
		return out
	for poi in maze_level.map_points_of_interest():
		if _found_poi_ids.has(String(poi["id"])):
			out.append(poi)
	return out

# "C1", "C2", ... (or "BR" for WindCorridorBreakRock) at a corridor's centre.
func _draw_corridor_tag(ci: CanvasItem, p: Vector2, corridor: Area3D, font_size: int) -> void:
	var tag := String(corridor.name).replace("WindCorridor", "")
	tag = "BR" if tag == "BreakRock" else "C" + tag
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ci.draw_string_outline(font, p + Vector2(-w * 0.5, font_size * 0.35), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.01, 0.04, 0.07, 0.95))
	ci.draw_string(font, p + Vector2(-w * 0.5, font_size * 0.35), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.55, 0.85, 1.0))

func _draw_poi(ci: CanvasItem, p: Vector2, poi: Dictionary, k: float) -> void:
	var done := bool(poi.get("done", false))
	match String(poi["kind"]):
		"poster":
			# A little sheet of paper with a portrait square; green once read.
			var sz := Vector2(14, 17) * k
			ci.draw_rect(Rect2(p - sz * 0.5, sz), Color(0.55, 0.95, 0.55) if done else Color(0.92, 0.87, 0.74))
			var pic := Rect2(p - Vector2(5.5, 7.0) * k, Vector2(11, 11) * k)
			if poi.get("texture") is Texture2D:
				ci.draw_texture_rect(poi["texture"], pic, false)
			else:
				ci.draw_rect(pic, Color(0.18, 0.15, 0.12))
			ci.draw_rect(Rect2(p - sz * 0.5, sz), Color(0.1, 0.1, 0.1), false, 1.0)
		"chest":
			var sz := Vector2(12, 8) * k
			ci.draw_rect(Rect2(p - sz * 0.5, sz), Color(0.5, 0.3, 0.12))
			ci.draw_rect(Rect2(p - Vector2(sz.x * 0.5, 1.0 * k), Vector2(sz.x, 2.0 * k)), Color(1.0, 0.8, 0.25))
			ci.draw_rect(Rect2(p - Vector2(1.2, 1.6) * k, Vector2(2.4, 3.2) * k), Color(1.0, 0.85, 0.3) if not done else Color(0.3, 0.3, 0.3))
			ci.draw_rect(Rect2(p - sz * 0.5, sz), Color(0.1, 0.06, 0.02), false, 1.0)
		"switch":
			var sz := Vector2(8, 8) * k
			ci.draw_rect(Rect2(p - sz * 0.5, sz), Color(0.05, 0.05, 0.05))
			ci.draw_circle(p, 2.2 * k, Color(0.25, 1.0, 0.4) if done else Color(1.0, 0.2, 0.2))
			ci.draw_rect(Rect2(p - sz * 0.5, sz), Color(0.7, 0.7, 0.7), false, 1.0)
		"key":
			var gold := Color(1.0, 0.82, 0.25)
			ci.draw_arc(p + Vector2(-3, 0) * k, 2.6 * k, 0.0, TAU, 12, gold, 1.8)
			ci.draw_line(p + Vector2(-0.4, 0) * k, p + Vector2(5.5, 0) * k, gold, 1.8)
			ci.draw_line(p + Vector2(3.6, 0) * k, p + Vector2(3.6, 2.6) * k, gold, 1.6)
			ci.draw_line(p + Vector2(5.3, 0) * k, p + Vector2(5.3, 2.2) * k, gold, 1.6)
		"broken_rock":
			var blue := Color(0.12, 0.22, 0.7)
			var a := 3.5 * k
			ci.draw_line(p + Vector2(-a, -a), p + Vector2(a, a), blue, 2.2)
			ci.draw_line(p + Vector2(-a, a), p + Vector2(a, -a), blue, 2.2)
		"rock":
			ci.draw_circle(p, 5.0 * k, Color(0.45, 0.42, 0.38))
			ci.draw_line(p + Vector2(-1, -5) * k, p + Vector2(1, 5) * k, Color(0.08, 0.08, 0.08), 1.5)
		"room_label":
			var font := ThemeDB.fallback_font
			var size := int(12 * k)
			var text := String(poi.get("label", ""))
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			ci.draw_string_outline(font, p + Vector2(-w * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.01, 0.04, 0.07, 0.95))
			ci.draw_string(font, p + Vector2(-w * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ROOM_COLOR)
