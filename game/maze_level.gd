class_name MazeLevel
extends Node3D

var markers: Array[Marker3D] = []

@onready var corridors: Array[Area3D] = [
	$WindCorridor1, $WindCorridor2, $WindCorridor3, $WindCorridor4,
	$WindCorridor5, $WindCorridor6, $WindCorridor7, $WindCorridor8,
]


func _ready() -> void:
	for child in get_children():
		if child is Marker3D:
			markers.append(child)
	_setup_walls()
	_setup_currents()
	_setup_whirlpool()
	_spawn_test_diver()
	_build_rotate_prompt()
	_build_floor()
	_build_perimeter_walls()
	_build_ceiling()

func _setup_walls():
	_set_wall_position($CSGBox3D, $CurrentWall1, true, true)

# A persistent on-screen hint for _rotate_left_currents_left()/_right()
# below - kept as its own label rather than reusing $HUD/Controls, since
# that one already gets overwritten by the whirlpool's warning/damage
# messages (_on_whirlpool_warned()/_on_diver_sucked_in()) and this
# instruction should stay visible regardless of whatever's happening
# there.
func _build_rotate_prompt() -> void:
	var label := Label.new()
	label.text = "Press L: rotate currents left (WindCorridor2->3, WindCorridor1->2)\nPress H: swing the CurrentWall1/2 hallway open - also moves WindCorridor1's current into WindCorridor2, and WindCorridor2's into WindCorridor3 (between CSGBox3D6/7, pushing north); press again to reverse it all"
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.offset_left = 16.0
	label.offset_top = -64.0
	label.offset_right = 560.0
	label.offset_bottom = -16.0
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	$HUD.add_child(label)

# MOVES THE ACTUAL WALL GEOMETRY - not a current's push zone, the solid
# collision the diver bumps into. CSGBox3D rebuilds its own collision
# automatically whenever its transform changes, so animating
# position/rotation every frame is enough on its own; nothing extra
# needs to be kept in sync.
#
# Swings wall_a/wall_b around `pivot` like a door on a hinge, not a
# straight-line slide to a new spot - each wall's OFFSET from the pivot
# gets rotated by an increasing angle every frame (0 -> yaw_degrees over
# duration seconds), so the pair traces a real arc. Using the far end of
# the hallway itself as the pivot (see _hallway_far_end() below) is what
# makes this read as "extends the hallway" rather than "spins it in
# place" - the new segment picks up exactly where the old one's exit
# already was, since that point never moves during the swing at all.
func swing_hallway(wall_a: CSGBox3D, wall_b: CSGBox3D, pivot: Vector3, yaw_degrees: float = 90.0, duration: float = 1.2) -> Tween:
	var offset_a: Vector3 = wall_a.position - pivot
	var offset_b: Vector3 = wall_b.position - pivot
	var start_yaw_a := wall_a.rotation.y
	var start_yaw_b := wall_b.rotation.y
	var target_yaw := deg_to_rad(yaw_degrees)

	var tw := create_tween()
	tw.tween_method(
		func(t: float) -> void:
			var spin := Basis(Vector3.UP, target_yaw * t)
			wall_a.position = pivot + spin * offset_a
			wall_a.rotation.y = start_yaw_a + target_yaw * t
			wall_b.position = pivot + spin * offset_b
			wall_b.rotation.y = start_yaw_b + target_yaw * t,
		0.0, 1.0, duration
	)
	return tw

# MODIFIED: was the midpoint between wall_a AND wall_b, pushed out by
# HALF the gap between them - that's a point roughly between the two
# walls, not a real endpoint of either one. What's actually wanted is
# wall_a's own endpoint: computed purely from wall_a's own position,
# length (size.x, its length axis) and facing (global_transform.basis.x)
# - doesn't reference wall_b at all, so it's the same physical point
# regardless of where wall_b currently is.
func _wall_endpoint(wall: CSGBox3D, positive_end: bool = false) -> Vector3:
	var forward: Vector3 = wall.global_transform.basis.x.normalized()
	return wall.global_position + forward * wall.size.x * 0.5 * (1.0 if positive_end else -1.0)

# Rotates one wall counterclockwise by exactly 90 degrees, then translates
# it so it continues the named destination wall end-to-end. There are two
# valid non-overlapping continuations (off either end of `target`); choose
# the one requiring the least travel from the moving wall's current centre.
func _rotate_wall_flush(wall: CSGBox3D, target: CSGBox3D, duration := 1.2) -> Tween:
	var target_axis := target.global_transform.basis.x.normalized()
	var target_negative := _wall_endpoint(target)
	var target_positive := _wall_endpoint(target, true)
	var half_length := wall.size.x * 0.5
	var off_negative := target_negative - target_axis * half_length
	var off_positive := target_positive + target_axis * half_length
	var destination := off_negative if wall.global_position.distance_squared_to(off_negative) < wall.global_position.distance_squared_to(off_positive) else off_positive
	destination.y = target.global_position.y

	var start_position := wall.global_position
	var start_yaw := wall.rotation.y
	var end_yaw := start_yaw + PI * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wall, "global_position", destination, duration)
	tw.tween_property(wall, "rotation:y", end_yaw, duration)
	return tw

# Shared by _rotate_wall_flush() above (implicitly, via the same tweened
# properties) and _rotate_hallway_1_2()'s return trip below - just animates
# a wall straight to an already-known position/yaw, no endpoint-matching
# math needed since "go back to where you started" doesn't have to pick
# between two candidate destinations the way swinging onto a new target
# wall does.
func _tween_wall_to(wall: CSGBox3D, position: Vector3, yaw: float, duration := 1.2) -> Tween:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wall, "global_position", position, duration)
	tw.tween_property(wall, "rotation:y", yaw, duration)
	return tw

var _endpoint_marker: MeshInstance3D = null

func _show_endpoint_marker(at: Vector3) -> void:
	if _endpoint_marker == null:
		_endpoint_marker = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		_endpoint_marker.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.15, 0.85)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 2.0
		_endpoint_marker.material_override = mat
		add_child(_endpoint_marker)
	_endpoint_marker.global_position = at

# MODIFIED: was wall_a spinning around its own CENTER while wall_b swung
# around wall_a's position - that only keeps wall_a's own center fixed,
# not any actual endpoint (a wall spinning around its own middle still
# moves every point on it other than that middle). What's actually
# wanted is both walls swinging around the SAME fixed point - a real
# endpoint of wall_a (see _wall_endpoint() above) - which is exactly
# what swing_hallway() already does for an arbitrary external pivot, so
# this just calls that instead of needing its own separate tween.
# MODIFIED: was a one-way swing every press - a second H just kept flushing
# wall_a/wall_b onto CSGBox3D/CurrentWall3 again, which (since they'd
# already arrived there) was a no-op tween rather than a way back. Toggled
# instead: the first press swings out to the flush position as before, and
# remembers where wall_a/wall_b started from; the second press tweens
# straight back to that remembered spot rather than flushing again, so H is
# a real open/close toggle, not a one-shot.
#
# MODIFIED: swinging the walls alone opened a physical gap but left it
# blocked anyway - WindCorridor1's own current still ran straight across
# the new path (strength 7 against a 5.0 swim speed - see
# water_current.gd's _on_entered()), so a diver got bounced even with
# nothing solid left in the way. Now the current moves out of WindCorridor1
# entirely on the same press: WindCorridor2's current vacates to
# WindCorridor3 first (the gap between CSGBox3D6/CSGBox3D7, gating that
# route shut - the design doc's own worked example calls for a rotation to
# trade one path for another, never just open one for free), then
# WindCorridor1's current moves into the now-empty WindCorridor2. Closing
# reverses both moves in the opposite order, alongside swinging the walls
# back.
#
# Each corridor gets its own dedicated move function below
# (_rotate_wind_corridor_1_current()/_rotate_wind_corridor_2_current())
# rather than sharing one - WindCorridor2's move needs an explicit
# destination direction (it has to actually block WindCorridor3, not just
# land on whatever a blind 90-degree turn from its old heading happens to
# produce), while WindCorridor1's move is a plain rotate-and-relocate. Both
# go through _currents_by_corridor either way (via rotate_corridors_right()/
# rotate_corridors_left() for corridor 1, and direct WaterCurrent.setup()
# bookkeeping for corridor 2) rather than rotate_currents.gd's now-unused
# RotateCurrents.change_corridor(), which manages its own private current
# outside that dictionary - every "has($WindCorridorN)" guard elsewhere in
# this file reads that dictionary, so a current change_corridor() moved
# would go untracked there.
var _hallway_1_2_swung := false
var _hallway_1_2_home_pos_a: Vector3
var _hallway_1_2_home_yaw_a: float
var _hallway_1_2_home_pos_b: Vector3
var _hallway_1_2_home_yaw_b: float

func _rotate_hallway_1_2() -> void:
	var wall_a: CSGBox3D = $CurrentWall1
	var wall_b: CSGBox3D = $CurrentWall2
	if _hallway_1_2_swung:
		_tween_wall_to(wall_a, _hallway_1_2_home_pos_a, _hallway_1_2_home_yaw_a)
		_tween_wall_to(wall_b, _hallway_1_2_home_pos_b, _hallway_1_2_home_yaw_b)
		_rotate_wind_corridor_1_current(false)
		_rotate_wind_corridor_2_current(false)
		_hallway_1_2_swung = false
		$HUD/Controls.text = "Hallway swinging back..."
		return
	_hallway_1_2_home_pos_a = wall_a.global_position
	_hallway_1_2_home_yaw_a = wall_a.rotation.y
	_hallway_1_2_home_pos_b = wall_b.global_position
	_hallway_1_2_home_yaw_b = wall_b.rotation.y
	_show_endpoint_marker(_wall_endpoint($CSGBox3D, true))
	_rotate_wall_flush(wall_a, $CSGBox3D)
	_rotate_wall_flush(wall_b, $CurrentWall3)
	_rotate_wind_corridor_2_current(true)
	_rotate_wind_corridor_1_current(true)
	_hallway_1_2_swung = true
	$HUD/Controls.text = "Hallway swinging..."

# WindCorridor1's own current - moves into WindCorridor2 on open (`open` =
# true), back to WindCorridor1 on close, rotating 90 degrees in the same
# move each way via the generic rotate_corridors_right()/rotate_corridors_
# left() above. Must run AFTER _rotate_wind_corridor_2_current(true) on
# open (WindCorridor2 has to be vacated before this current can move into
# it) and BEFORE it on close (this current has to vacate WindCorridor2
# before the other one can move back into it) - see the call order in
# _rotate_hallway_1_2() above.
func _rotate_wind_corridor_1_current(open: bool) -> void:
	if open:
		if _currents_by_corridor.has($WindCorridor1):
			rotate_corridors_right($WindCorridor1, $WindCorridor2)
	else:
		if _currents_by_corridor.has($WindCorridor2):
			rotate_corridors_left($WindCorridor2, $WindCorridor1)

# WindCorridor2's own current - moves into WindCorridor3 (the gap between
# CSGBox3D6/CSGBox3D7) on open, gating that route shut, back to
# WindCorridor2 on close. Direction is set explicitly rather than derived
# by rotating 90 degrees from whatever WindCorridor2 happened to be blowing
# (unlike WindCorridor1's move above) - blocking WindCorridor3 means
# pushing north/"up" specifically, not just whichever direction a blind
# 90-degree turn happens to land on. Closing restores WindCorridor2's
# original POSITIVE_Z - the same direction _setup_currents() gives it at
# the start, so this always returns to exactly where it began rather than
# drifting after repeated open/close cycles.
func _rotate_wind_corridor_2_current(open: bool) -> void:
	if open:
		var current: WaterCurrent = _currents_by_corridor.get($WindCorridor2, null)
		if current == null:
			push_warning("_rotate_hallway_1_2: no current is set up at WindCorridor2")
			return
		current.setup($WindCorridor3, WaterCurrent.direction_to_vector(WaterCurrent.Direction.NEGATIVE_Z), current.strength, false)
		_currents_by_corridor.erase($WindCorridor2)
		_currents_by_corridor[$WindCorridor3] = current
	else:
		var current: WaterCurrent = _currents_by_corridor.get($WindCorridor3, null)
		if current == null:
			push_warning("_rotate_hallway_1_2: no current is set up at WindCorridor3")
			return
		current.setup($WindCorridor2, WaterCurrent.direction_to_vector(WaterCurrent.Direction.POSITIVE_Z), current.strength, false)
		_currents_by_corridor.erase($WindCorridor3)
		_currents_by_corridor[$WindCorridor2] = current
		
# MODIFIED: wall_b's new position was built off wall_a.global_position (its
# CENTER) - wall_a_end was computed right above but then never actually
# used, so wall_b landed offset from wall_a's middle, not its end. The
# offset itself was also sized wrong twice over: wall_a.size.y and
# wall_b.size.y are both HEIGHT (~4), not length - size.x is a wall's
# length axis everywhere else in this file (_wall_endpoint() above) - and
# it multiplied by `forward`, wall_a's own axis, when the offset from the
# touching corner out to wall_b's center needs to run along wall_b's OWN
# axis instead, since wall_b sits perpendicular to wall_a (already true
# from how it's placed in the scene - this function only repositions it,
# it never rotates it).
#
# Reuses _wall_endpoint() above rather than re-deriving wall_a's own
# forward/endpoint by hand - same formula, just solved backwards: instead
# of walking FROM a wall's center TO one of its ends, this walks from the
# known touching point BACK to where wall_b's center must sit so that
# wall_b's own end (left_end picks which one) lands exactly on it.
#
# MODIFIED: wall_b's center used to land exactly ON wall_a_end - fine along
# wall_b's own length (that's the axis the left_end offset already solves
# for), but wall_a_end is a point on wall_a's THICKNESS too, not just its
# length. Since wall_b sits rotated 90 degrees from wall_a, wall_b's own
# thickness axis (size.z) ends up parallel to wall_a's length axis - so
# centering wall_b directly on that point left half of wall_b's thickness
# sitting on the far side of it (correctly clear of wall_a), and the other
# half sitting on the near side, buried back inside wall_a's own body
# instead of starting flush at its face. `clearance` pushes wall_b's center
# half a thickness further out along wall_a's own forward axis (the same
# direction its end already faces away from its body, via `positive_end`'s
# sign) so wall_b's near face lands exactly on wall_a's face instead of
# straddling it.
func _set_wall_position(wall_a: CSGBox3D, wall_b: CSGBox3D, positive_end: bool = false, left_end: bool = false) -> void:
	var wall_a_forward: Vector3 = wall_a.global_transform.basis.x.normalized()
	var wall_a_end := _wall_endpoint(wall_a, positive_end)
	var wall_b_forward: Vector3 = wall_b.global_transform.basis.x.normalized()
	var clearance: Vector3 = wall_a_forward * wall_b.size.z * 0.5 * (1.0 if positive_end else -1.0)
	wall_b.global_position = wall_a_end + clearance + wall_b_forward * wall_b.size.x * 0.5 * (1.0 if left_end else -1.0)
	
	
# Each WaterCurrent is a plain controller object, not something attached
# to the Area3D itself (see water_current.gd) - built and wired up here
# instead, so both which Area3D it watches and which way it blows are
# set from this file, in one place, rather than living on the node in
# the editor.
#
# Direction was picked per corridor by finding each one's own long axis
# in WORLD space (which way a current should flow along, not across) -
# not always the same as its CollisionShape3D's local X/Z, since several
# of these (WindCorridor5/6/7/8/3) have that shape rotated ~90 degrees
# relative to their own Area3D parent. First pass, not verified in-game -
# if any of these turn out to blow into a wall instead of down the
# corridor, flip it to the opposite Direction (POSITIVE_X <-> NEGATIVE_X,
# POSITIVE_Z <-> NEGATIVE_Z) rather than changing the axis.
#
# MODIFIED: was setting up SIX currents (1/2/3/6/7/8), not the two clean
# pairs the rotate functions above/below actually assume - the left
# group's window only ever has TWO currents (starting at {1,2}, not
# {1,2,3} all at once), and the right group's only ever has two as well
# (starting at {4,6}, not {6,7,8} with 4 missing entirely). With the old
# setup, _rotate_left_currents_left()'s and _rotate_right_currents_
# right()'s own boundary checks would have immediately (and wrongly)
# reported both groups as already maxed out, since WindCorridor3/7/8 all
# had currents sitting there uncounted by the pair logic. Trimmed to
# exactly the two starting pairs.
func _setup_currents() -> void:
	_add_current($WindCorridor1, WaterCurrent.Direction.NEGATIVE_Z)
	_add_current($WindCorridor2, WaterCurrent.Direction.NEGATIVE_X)
	_add_current($WindCorridor4, WaterCurrent.Direction.POSITIVE_Z)
	_add_current($WindCorridor6, WaterCurrent.Direction.NEGATIVE_Z)
	
# MODIFIED: both of these were calling rotate_corridors_right()/_left()
# as if they were methods ON an Area3D (e.g. left_areas[0].
# rotate_corridors_right(...)) - those are defined below on MazeLevel
# itself, not on Area3D, so this would have errored the instant either
# ran. Called as plain functions now. rotate_corridors_right()/_left()
# also no longer take a `dir` argument (see their own updated comment) -
# they read each current's existing direction off itself now, so this
# doesn't have to track/pass it by hand.
#
# Shifts the currents down the chain: WindCorridor2's current moves to
# WindCorridor3 first, THEN WindCorridor1's current moves into the
# now-empty WindCorridor2 - order matters, 2->3 has to happen first or
# WindCorridor2 would still have its OLD current sitting there when
# WindCorridor1's tries to move in.
# "Left"/"right" here name which direction the WHOLE two-current window
# slides along the 1-2-3 chain, not which way any one current's own flow
# spins - the window only ever sits at {1,2} or {2,3} (two adjacent
# corridors at a time), so there are exactly two positions and two
# directions between them.
#
# MODIFIED: was moving currents toward HIGHER-numbered corridors in BOTH
# functions (only the inner rotate_corridors_left()/_right() call - which
# only affects a moved current's own new flow direction, not which
# corridor it moves to - differed) - so "rotate right" and "rotate left"
# were doing the identical corridor shift, just spinning the moved
# currents differently. Fixed to actually move toward LOWER-numbered
# corridors here: WindCorridor2's current retreats to WindCorridor1
# first, then WindCorridor3's current moves into the now-empty
# WindCorridor2 - same "move into the vacant slot closest to it first"
# ordering _rotate_left_currents_right() already uses, just mirrored.
func _rotate_left_currents_right() -> void:
	if _currents_by_corridor.has($WindCorridor2) and _currents_by_corridor.has($WindCorridor3):
		$HUD/Controls.text = "Currents are already as far right as they can go."
		return
	rotate_corridors_right($WindCorridor2, $WindCorridor3)
	rotate_corridors_right($WindCorridor1, $WindCorridor2)
	$HUD/Controls.text = "Currents rotated right."

func _rotate_left_currents_left() -> void:
	if _currents_by_corridor.has($WindCorridor1) and _currents_by_corridor.has($WindCorridor2):
		$HUD/Controls.text = "Currents are already as far left as they can go."
		return
	rotate_corridors_left($WindCorridor2, $WindCorridor1)
	rotate_corridors_left($WindCorridor3, $WindCorridor2)
	$HUD/Controls.text = "Currents rotated left."

# The "right areas" pair - same two-current-window idea as the left group
# above, but over WindCorridor4-8 with a gap of 2 between the pair
# instead of 1, so it has three positions instead of two:
# {4,6} <-> {5,7} <-> {6,8}. Every one of these four transitions moves
# each current to a corridor the OTHER current isn't currently at (no
# shared corridor between an old pair and the adjacent new pair anywhere
# in this chain), so unlike the left group's {1,2}<->{2,3} shift, move
# order never risks a collision here - both rotate_corridors_*() calls
# in each block below are safe in either order.
func _rotate_right_currents_left() -> void:
	if _currents_by_corridor.has($WindCorridor4) and _currents_by_corridor.has($WindCorridor6):
		$HUD/Controls.text = "Currents are already as far left as they can go."
		return
	if _currents_by_corridor.has($WindCorridor6) and _currents_by_corridor.has($WindCorridor8):
		rotate_corridors_left($WindCorridor6, $WindCorridor5)
		rotate_corridors_left($WindCorridor8, $WindCorridor7)
		$HUD/Controls.text = "Currents rotated left."
		return
	if _currents_by_corridor.has($WindCorridor5) and _currents_by_corridor.has($WindCorridor7):
		rotate_corridors_left($WindCorridor5, $WindCorridor4)
		rotate_corridors_left($WindCorridor7, $WindCorridor6)
		$HUD/Controls.text = "Currents rotated left."
		return
	push_warning("_rotate_right_currents_left: right-group currents aren't at a recognized position")

func _rotate_right_currents_right() -> void:
	if _currents_by_corridor.has($WindCorridor6) and _currents_by_corridor.has($WindCorridor8):
		$HUD/Controls.text = "Currents are already as far right as they can go."
		return
	if _currents_by_corridor.has($WindCorridor4) and _currents_by_corridor.has($WindCorridor6):
		rotate_corridors_right($WindCorridor4, $WindCorridor5)
		rotate_corridors_right($WindCorridor6, $WindCorridor7)
		$HUD/Controls.text = "Currents rotated right."
		return
	if _currents_by_corridor.has($WindCorridor5) and _currents_by_corridor.has($WindCorridor7):
		rotate_corridors_right($WindCorridor5, $WindCorridor6)
		rotate_corridors_right($WindCorridor7, $WindCorridor8)
		$HUD/Controls.text = "Currents rotated right."
		return
	push_warning("_rotate_right_currents_right: right-group currents aren't at a recognized position")

# Every corridor gets its own permanent WaterCurrent (unlike
# rotate_currents.gd's RotateCurrents, which moves ONE current between
# corridors, leaving whichever one it just left with nothing) - tracked
# here by Area3D so a specific corridor's current can be looked back up
# and reconfigured later via change_corridor_direction(), without
# touching any of the others.
var _currents_by_corridor: Dictionary = {}

func _add_current(target_area: Area3D, dir: WaterCurrent.Direction) -> void:
	var current := WaterCurrent.new()
	add_child(current)
	# show_debug_visual = false - a real current shouldn't render as a
	# visible glowing box, that was only ever a development aid to see the
	# push zone while getting the sizing/direction right.
	# Diver swim speed is 5.0. A traversal-blocking current must exceed that
	# speed, otherwise holding directly upstream still produces forward motion.
	current.setup(target_area, WaterCurrent.direction_to_vector(dir), 7.0, false)
	_currents_by_corridor[target_area] = current

# Moves the WaterCurrent that's currently at origArea over to newArea,
# rotating its own flow direction 90 degrees in the process - looked up
# by origArea, not by name or index, and re-filed under newArea in
# _currents_by_corridor once it's moved (otherwise a later lookup by
# origArea would still find "a current" there even though it's actually
# watching newArea now, and newArea would never be findable at all).
#
# MODIFIED: no longer takes a `dir` argument - WaterCurrent.
# vector_to_direction() reads the current's own existing orientation
# back into a Direction, so the caller doesn't have to separately track
# "which way is this corridor's current facing right now" itself.
#
# Calling setup() again (even on a different area) is safe -
# WaterCurrent.setup() tears itself down first (see its own header
# comment), disconnecting from origArea and rebuilding its bubble
# stream/debug visual fresh at newArea. Every other corridor's own
# current is untouched.
func rotate_corridors_right(origArea: Area3D, newArea: Area3D) -> void:
	_rotate_corridor(origArea, newArea, true)

func rotate_corridors_left(origArea: Area3D, newArea: Area3D) -> void:
	_rotate_corridor(origArea, newArea, false)

func _rotate_corridor(origArea: Area3D, newArea: Area3D, turn_right: bool) -> void:
	var current: WaterCurrent = _currents_by_corridor.get(origArea, null)
	if current == null:
		push_warning("rotate_corridors: no current is set up at %s" % origArea.name)
		return
	var current_dir := WaterCurrent.vector_to_direction(current.orientation)
	var new_dir := _rotate_right(current_dir) if turn_right else _rotate_left(current_dir)
	current.setup(newArea, WaterCurrent.direction_to_vector(new_dir), current.strength, false)
	_currents_by_corridor.erase(origArea)
	_currents_by_corridor[newArea] = current
	
static func _rotate_right(dir: WaterCurrent.Direction) -> WaterCurrent.Direction:
	match dir:
		WaterCurrent.Direction.NEGATIVE_Z:
			return WaterCurrent.Direction.NEGATIVE_X
		WaterCurrent.Direction.NEGATIVE_X:
			return WaterCurrent.Direction.POSITIVE_Z
		WaterCurrent.Direction.POSITIVE_Z:
			return WaterCurrent.Direction.POSITIVE_X
		WaterCurrent.Direction.POSITIVE_X:
			return WaterCurrent.Direction.NEGATIVE_Z
	return dir

# The exact reverse of _rotate_right() above - same four directions, same
# cycle, walked the other way around: NEGATIVE_Z -> POSITIVE_X ->
# POSITIVE_Z -> NEGATIVE_X -> back to NEGATIVE_Z.
static func _rotate_left(dir: WaterCurrent.Direction) -> WaterCurrent.Direction:
	match dir:
		WaterCurrent.Direction.NEGATIVE_Z:
			return WaterCurrent.Direction.POSITIVE_X
		WaterCurrent.Direction.POSITIVE_X:
			return WaterCurrent.Direction.POSITIVE_Z
		WaterCurrent.Direction.POSITIVE_Z:
			return WaterCurrent.Direction.NEGATIVE_X
		WaterCurrent.Direction.NEGATIVE_X:
			return WaterCurrent.Direction.NEGATIVE_Z
	return dir

# Same class world.gd's own highway gap uses (see whirlpool.gd) - a
# warned approach, then a suction pull no swimming can fight once caught,
# docking HP and sweeping the diver back to reset_to. Defaults to
# DiverEntry's own position for reset_to since that's already a known-safe
# spot in this level - point it somewhere more specific once there's a
# real "just before the whirlpool" approach point worth resetting to
# instead.
func _setup_whirlpool() -> void:
	var whirlpool := Whirlpool.new()
	whirlpool.position = Vector3(35.99, -4.12, 71.67)
	whirlpool.reset_to = $DiverEntry.position
	whirlpool.warned.connect(_on_whirlpool_warned)
	whirlpool.diver_sucked_in.connect(_on_diver_sucked_in)
	add_child(whirlpool)

func _on_whirlpool_warned() -> void:
	$HUD/Controls.text = "Danger - a whirlpool lies just ahead!"

func _on_diver_sucked_in(_d: Diver, amount: int) -> void:
	$HUD/Controls.text = "You were sucked into the whirlpool! (-%d HP)" % amount

# CSGBox3D's collision (now that every wall has use_collision = true, see
# maze_level.tscn) only covers the wall's own box - nothing stops a diver
# from just sinking below a wall's bottom edge and swimming under it, since
# SPACE/SHIFT have no floor of their own here the way world.gd's open dive
# site does (_build_site()). One flat invisible slab, positioned right
# under the walls and spanning the whole level - same shape as
# _build_ceiling() below, just at the opposite end: the X/Z footprint
# reuses _collect_bounds_points()/_PERIMETER_MARGIN so it covers the same
# full extent, and the height is pinned to the lowest wall bottom in the
# scene (mirroring how _build_perimeter_walls() already uses that same
# minimum for its own vertical placement) rather than any one wall by name.
#
# Sits below the whirlpool's own position (game/whirlpool.gd's
# _setup_whirlpool() places it at y=-4.12, lower than every wall's bottom
# edge) - the whirlpool's suction sets the diver's position directly rather
# than moving through normal collision response, so it still pulls them
# down past this floor, but a diver just swimming down on their own now
# stops here instead of reaching that depth by hand.
const _FLOOR_CLEARANCE := 1.0
const _FLOOR_THICKNESS := 2.0

func _build_floor() -> void:
	var wall_min_y := INF
	for child in get_children():
		if child is CSGBox3D:
			var box := child as CSGBox3D
			wall_min_y = minf(wall_min_y, box.position.y - box.size.y * 0.5)
	if wall_min_y == INF:
		return

	var points := _collect_bounds_points()
	if points.is_empty():
		return
	var min_pt: Vector3 = points[0]
	var max_pt: Vector3 = points[0]
	for p in points:
		min_pt = min_pt.min(p)
		max_pt = max_pt.max(p)
	var padded_min := min_pt - Vector3(_PERIMETER_MARGIN, 0.0, _PERIMETER_MARGIN)
	var padded_max := max_pt + Vector3(_PERIMETER_MARGIN, 0.0, _PERIMETER_MARGIN)
	var span_x := padded_max.x - padded_min.x
	var span_z := padded_max.z - padded_min.z
	var center_x := (padded_min.x + padded_max.x) * 0.5
	var center_z := (padded_min.z + padded_max.z) * 0.5

	var floor_y := wall_min_y - _FLOOR_CLEARANCE - _FLOOR_THICKNESS * 0.5

	_build_invisible_wall(
		Vector3(center_x, floor_y, center_z),
		Vector3(span_x, _FLOOR_THICKNESS, span_z))

# A perimeter around the whole level, same idea as world.gd's own
# _build_boundary_walls() for the open dive site - invisible collision
# only, tall enough that rising over the top isn't a way around it either,
# well clear of every wall so a diver can't just swim wide around the
# maze's own corridors and walls to skip them entirely.
#
# Computed from the level's actual geometry rather than a hand-measured
# box: every CSGBox3D wall's corners, every WindCorridor Area3D's own
# BoxShape3D corners (several of those reach further than any wall, e.g.
# the WindCorridor6-9 cluster), the whirlpool's position, and every
# Marker3D (DiverEntry plus the numbered waypoints) all fold into one
# combined X/Z bounding rectangle - so this stays correct as the maze
# grows without anyone having to update a hardcoded boundary here to match.
const _PERIMETER_MARGIN := 10.0
const _PERIMETER_WALL_HEIGHT := 80.0
const _PERIMETER_THICKNESS := 4.0

func _collect_bounds_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for child in get_children():
		if child is CSGBox3D:
			var box := child as CSGBox3D
			var half: Vector3 = box.size * 0.5
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					points.append(box.global_transform * Vector3(half.x * sx, 0.0, half.z * sz))
		elif child is Area3D:
			for shape_node in child.get_children():
				if shape_node is CollisionShape3D and (shape_node as CollisionShape3D).shape is BoxShape3D:
					var cs := shape_node as CollisionShape3D
					var b := (cs.shape as BoxShape3D).size * 0.5
					for sx in [-1.0, 1.0]:
						for sz in [-1.0, 1.0]:
							points.append(cs.global_transform * Vector3(b.x * sx, 0.0, b.z * sz))
		elif child is Marker3D or child is Whirlpool:
			points.append((child as Node3D).global_position)
	return points

func _build_perimeter_walls() -> void:
	var points := _collect_bounds_points()
	if points.is_empty():
		return
	var min_pt: Vector3 = points[0]
	var max_pt: Vector3 = points[0]
	for p in points:
		min_pt = min_pt.min(p)
		max_pt = max_pt.max(p)

	var padded_min := min_pt - Vector3(_PERIMETER_MARGIN, 0.0, _PERIMETER_MARGIN)
	var padded_max := max_pt + Vector3(_PERIMETER_MARGIN, 0.0, _PERIMETER_MARGIN)
	var span_x := padded_max.x - padded_min.x
	var span_z := padded_max.z - padded_min.z
	var center_x := (padded_min.x + padded_max.x) * 0.5
	var center_z := (padded_min.z + padded_max.z) * 0.5
	var wall_y := min_pt.y + _PERIMETER_WALL_HEIGHT * 0.5

	_build_invisible_wall(
		Vector3(center_x, wall_y, padded_min.z - _PERIMETER_THICKNESS * 0.5),
		Vector3(span_x + _PERIMETER_THICKNESS * 2.0, _PERIMETER_WALL_HEIGHT, _PERIMETER_THICKNESS))
	_build_invisible_wall(
		Vector3(center_x, wall_y, padded_max.z + _PERIMETER_THICKNESS * 0.5),
		Vector3(span_x + _PERIMETER_THICKNESS * 2.0, _PERIMETER_WALL_HEIGHT, _PERIMETER_THICKNESS))
	_build_invisible_wall(
		Vector3(padded_min.x - _PERIMETER_THICKNESS * 0.5, wall_y, center_z),
		Vector3(_PERIMETER_THICKNESS, _PERIMETER_WALL_HEIGHT, span_z + _PERIMETER_THICKNESS * 2.0))
	_build_invisible_wall(
		Vector3(padded_max.x + _PERIMETER_THICKNESS * 0.5, wall_y, center_z),
		Vector3(_PERIMETER_THICKNESS, _PERIMETER_WALL_HEIGHT, span_z + _PERIMETER_THICKNESS * 2.0))

func _build_invisible_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

# Invisible ceiling capping the whole level - one flat slab spanning the
# same X/Z footprint _build_perimeter_walls() above already computes
# (_collect_bounds_points()/_PERIMETER_MARGIN, reused rather than
# recomputed), positioned just above CurrentWall1's own top edge
# specifically - not the tallest wall anywhere in the scene. Several walls
# (CSGBox3D24-28) run much taller than CurrentWall1, at y=6.5 with a
# 14-unit height; a ceiling pinned to those would trap a diver rising
# through that part of the level instead of just closing off rising up and
# over the corridor CurrentWall1 itself gates, which is the one this was
# actually asked to cap.
#
# Read once here in _ready(), before _rotate_hallway_1_2() can ever run -
# CurrentWall1's height at that moment is its pristine placed position, not
# wherever a later swing has left it (the swing only changes its X/Z
# position and yaw, never its own height, so this stays correct regardless,
# but reading it this early is what guarantees that rather than assuming it).
const _CEILING_CLEARANCE := 1.0
const _CEILING_THICKNESS := 2.0

func _build_ceiling() -> void:
	var points := _collect_bounds_points()
	if points.is_empty():
		return
	var min_pt: Vector3 = points[0]
	var max_pt: Vector3 = points[0]
	for p in points:
		min_pt = min_pt.min(p)
		max_pt = max_pt.max(p)

	var padded_min := min_pt - Vector3(_PERIMETER_MARGIN, 0.0, _PERIMETER_MARGIN)
	var padded_max := max_pt + Vector3(_PERIMETER_MARGIN, 0.0, _PERIMETER_MARGIN)
	var span_x := padded_max.x - padded_min.x
	var span_z := padded_max.z - padded_min.z
	var center_x := (padded_min.x + padded_max.x) * 0.5
	var center_z := (padded_min.z + padded_max.z) * 0.5

	var wall_a := $CurrentWall1 as CSGBox3D
	var ceiling_y := wall_a.position.y + wall_a.size.y * 0.5 + _CEILING_CLEARANCE + _CEILING_THICKNESS * 0.5

	_build_invisible_wall(
		Vector3(center_x, ceiling_y, center_z),
		Vector3(span_x, _CEILING_THICKNESS, span_z))

# ============================================================
# A standalone swimmable diver for testing this level in isolation -
# this scene has no World node (that's what normally builds/drives one -
# see world.gd's own CAST loop and _physics_process()), so a minimal
# version of the same controls lives here instead: WASD relative to
# camera look, Space/Shift to rise/sink, click-drag to look around. Not
# meant to replace playing through world.gd for real - just enough to
# walk into WindCorridor1 and feel what it does.
# ============================================================

# Prototype_V(1922) ("Marine Man") specifically - the only diver with no
# "passive" entry in Diver.BASE_STATS (see diver.gd), so nothing it does
# during normal swimming ever reaches for the `world` reference (sonar's
# passive drain, key-item reveals) that this standalone scene has no real
# World node to provide. Its shockwave ability doesn't need one either.
const TEST_DIVER_MODEL := "Prototype_V(1922)"

var _diver: Diver
var _yaw := 0.0
var _pitch := -0.16
var _cam_dist := 6.5
var _mouse_look := false

func _spawn_test_diver() -> void:
	_diver = Diver.new()
	_diver.model_name = TEST_DIVER_MODEL
	# A short swim before WindCorridor1 (its box sits around x=4.9, z=4.4),
	# approaching along -Z toward it - close enough to reach quickly, far
	# enough to actually feel the current take hold before arriving.
	_diver.position = $DiverEntry.position
	add_child(_diver)

func _player_dir() -> Vector3:
	var f := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		f.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		f.y += 1.0
	if Input.is_key_pressed(KEY_A):
		f.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		f.x += 1.0
	if f == Vector2.ZERO:
		return Vector3.ZERO
	f = f.normalized()
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	var right := Vector3(-cos(_yaw), 0, sin(_yaw))
	return (right * f.x - fwd * f.y).normalized()

func _player_rise() -> float:
	var r := 0.0
	if Input.is_key_pressed(KEY_SPACE):
		r += 1.0
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		r -= 1.0
	return r

func _physics_process(dt: float) -> void:
	if _diver == null:
		return
	_diver.swim(_player_dir(), _player_rise(), dt)
	_move_camera(dt)

func _move_camera(dt: float) -> void:
	var cam: Camera3D = $Camera3D
	var dir := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch))
	var focus: Vector3 = _diver.global_position + Vector3(0, _diver.height * 0.35, 0)
	var want: Vector3 = focus - dir * _cam_dist
	want.y = maxf(want.y, 0.6)
	cam.global_position = cam.global_position.lerp(want, clampf(dt * 8.0, 0.0, 1.0))
	cam.look_at(focus, Vector3.UP)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_look = true
	elif e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_look = false
	elif e is InputEventMouseMotion and _mouse_look:
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.004
		_pitch = clampf(_pitch - mm.relative.y * 0.003, -1.1, 0.7)
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_L:
		_rotate_left_currents_left()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_H:
		_rotate_hallway_1_2()
