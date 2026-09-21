class_name MazeLevel
extends Node3D

# A wall's physical ends.  These names are intentionally kept at the API
# boundary: callers choose a named authored exit only when the level design
# explicitly requires one; automatic continuations never expose these signs.
enum WallEnd {
	NEGATIVE,
	POSITIVE,
}

var markers: Array[Marker3D] = []

# Every scene-authored CSGBox3D wall, read live by maze_mini_map.gd each
# frame rather than baked into fixed [start, end] segments the way
# World._build_wall() does for _wall_segments - CurrentWall1/CurrentWall2
# actually swing open (see swing_hallway()), so a one-time bake would go
# stale the moment that happens. Keeping the node references and
# recomputing each box's own centerline from its CURRENT global_transform
# every draw call is what keeps the radar honest through that swing.
var wall_boxes: Array[CSGBox3D] = []

@onready var corridors: Array[Area3D] = [
	$WindCorridor1, $WindCorridor2, $WindCorridor3, $WindCorridor4,
	$WindCorridor5, $WindCorridor6, $WindCorridor7, $WindCorridor8,
]


func _ready() -> void:
	for child in get_children():
		if child is Marker3D:
			markers.append(child)
		elif child is CSGBox3D:
			wall_boxes.append(child)
	_setup_walls()
	_setup_currents()
	_setup_whirlpool()
	_spawn_test_diver()
	_build_levers()
	_build_rotate_prompt()
	_build_floor()
	_build_perimeter_walls()
	_build_ceiling()
	_build_minimap()
	_build_item_rocks()
	_build_completion_ui()
	$HUD/Controls.text = "Hallway: CLOSED — press H to open the route to the relic."

# Reward rocks scattered through the maze - the same disguised-as-scenery
# CrackedWall world.gd's own _build_breakable_rocks() spawns at a hardcoded
# position list, just placed at whichever Marker3D nodes are tagged
# "ItemRock" in THIS scene instead - adding another one is tagging another
# marker with that group, not editing code.
func _build_item_rocks() -> void:
	for node in get_tree().get_nodes_in_group("ItemRock"):
		var marker := node as Node3D
		if marker == null:
			continue
		var rock := CrackedWall.new()
		rock.span = Vector3(1.1, 1.1, 1.1)
		# A lone, undiscoverable scenery-rock reward is not a viable manual
		# completion target in this standalone scene: it has no World sonar
		# loop to reveal it. Make the final relic read as an interactable
		# cracked formation, just like the game's ability gates.
		rock.disguised_as_scenery_rock = false
		rock.position = marker.global_position
		rock.broken.connect(_on_item_rock_broken.bind(marker.name, marker.global_position))
		add_child(rock)

# Single-model .glb (unlike divers.glb, which stacks several models at the
# origin and needs its own extraction step in lineup.gd - this one's just
# the orb, load-and-instantiate is enough) - res://art/characters/ matches
# where divers.glb already lives. Two other identical copies of this file
# also sit at res://golden_energy_orb.glb and res://game/golden_energy_orb.glb;
# worth deleting once this is confirmed as the one being used.
const GOLDEN_ENERGY_ORB_SCENE := preload("res://art/characters/golden_energy_orb.glb")
var goldenOrbs: Array = []
# The standalone maze has one authored reward chamber. Completion is a public
# gameplay state rather than an inference from a temporary orb node: callers
# and the end-to-end regression can ask whether the player actually finished
# the level after reaching and breaking that relic.
signal maze_completed(marker_name: String)
var _completed := false

func is_completed() -> bool:
	return _completed

func _build_completion_ui() -> void:
	var label := Label.new()
	label.name = "MazeComplete"
	label.text = "MAZE COMPLETE\nRelic secured"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -190.0
	label.offset_top = -54.0
	label.offset_right = 190.0
	label.offset_bottom = 54.0
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.1))
	label.add_theme_constant_override("outline_size", 8)
	label.visible = false
	$HUD.add_child(label)
# `marker_name`/`spot` are the broken ItemRock's own name and position,
# bound at connect time in _build_item_rocks() - a real drop table would
# vary by which one broke (see world.gd's own Items/ItemOrb pipeline for
# what that looks like for real; this standalone test scene has none of
# that, so every ItemRock just drops the same orb for now).
func _on_item_rock_broken(marker_name: String, spot: Vector3) -> void:
	var orb := GOLDEN_ENERGY_ORB_SCENE.instantiate()
	# The source orb is authored at boss-scale. At the relic site it should read
	# as a collectable glow above the broken formation, not fill the third-person
	# camera and hide the completion confirmation.
	orb.scale = Vector3.ONE * 0.35
	orb.position = spot + Vector3(0.0, 1.25, 0.0)
	goldenOrbs.append(orb)
	add_child(orb)
	if _completed:
		return
	_completed = true
	var completion_label := $HUD.get_node("MazeComplete") as Label
	completion_label.visible = true
	$HUD/Controls.text = "Relic secured. Maze complete."
	maze_completed.emit(marker_name)

func _setup_walls():
	# This is an authored, intentional perpendicular join: CurrentWall1 starts
	# on CSGBox3D's positive exit with its own positive end as the anchor.  It
	# is therefore named here instead of being encoded as `_set_...(true, true)`.
	_attach_wall_to_perpendicular_exit(
		$CSGBox3D, $CurrentWall1, WallEnd.POSITIVE, WallEnd.POSITIVE
	)
	_place_csgbox6_at_hallway_target()

# CSGBox3D6 does NOT rotate or move at runtime at all - it's placed exactly
# ONCE, here, at the position/rotation CurrentWall1 WOULD end up at if the
# H-key hallway swing (_rotate_hallway_1_2()) were triggered right now,
# using the same named-continuation math (_nearest_wall_continuation()) that
# swing itself uses to actually place CurrentWall1
# there. CurrentWall1 never has to actually swing for this to be correct -
# this just precomputes that same hypothetical destination up front and
# leaves CSGBox3D6 sitting there permanently, whether or not H is ever
# pressed.
func _place_csgbox6_at_hallway_target() -> void:
	var wall_a: CSGBox3D = $CurrentWall1
	var wall_6: CSGBox3D = $CSGBox3D6
	var wall_7: CSGBox3D = $CSGBox3D7

	# CSGBox3D6's own rotation is fixed before its placement. One
	# more 90-degree turn off CurrentWall1's own hypothetical H-rotated yaw
	# - the same relationship CurrentWall1 has to CSGBox3D.
	var wall1_h_yaw: float = wall_a.rotation.y + PI * 0.5
	wall_6.rotation.y = wall1_h_yaw + PI * 0.5

	# CSGBox3D6 attaches to CurrentWall1's FUTURE far end, not to CSGBox3D
	# with a world-X correction.  The latter accidentally used a static
	# reference frame: after CurrentWall1's 90-degree turn it stayed
	# perpendicular, but its nearest edge stopped short of the wall's end.
	# Compute the same destination CurrentWall1 will use on H, find that
	# destination's named outer endpoint, then place wall_6's near edge on
	# that endpoint.  Everything is expressed in the rotated wall's local
	# axes, so changing either length or initial maze orientation preserves
	# the flush join.
	var wall_orig = $CSGBox3D
	var wall1_target: Dictionary = _nearest_wall_continuation(wall_a, wall_orig)
	var wall1_target_yaw := float(wall1_target.yaw)
	var wall1_target_position := wall1_target.position as Vector3
	var wall1_future: Dictionary = _wall_geometry_at(wall1_target_position, wall1_target_yaw, wall_a.size)
	var wall1_outer_end := wall1_future["positive_end"] as Vector3
	var wall1_outward_axis := wall1_future["long_axis"] as Vector3
	wall_6.global_position = _position_beyond_wall_end(
		wall1_outer_end, wall1_outward_axis, wall_a.size.z,
		wall_6.rotation.y, wall_6.size.x, wall_6.size.z, WallEnd.NEGATIVE
	)

	# CSGBox3D7 is the opposite *static* boundary of the northbound passage,
	# not another part of CurrentWall1's moving assembly. It must begin on the
	# same cross-line as CSGBox3D6, but remain laterally separated to form the
	# passage. Project its pre-existing offset onto Box6's side axis: this
	# preserves the authored lane width while discarding only the stale forward
	# and vertical offsets left behind when Box6 was corrected above. Box7 never
	# moves during H, so it cannot sweep into CurrentWall1's opened position.
	var wall_6_geometry: Dictionary = _wall_geometry(wall_6)
	var lane_side := wall_6_geometry["side_axis"] as Vector3
	var authored_offset := wall_7.global_position - wall_6.global_position
	var preserved_lane_offset := lane_side * authored_offset.dot(lane_side)
	wall_7.global_position = wall_6.global_position + preserved_lane_offset

# Two levers placed together near the requested spot (8.8, 1.5, -34), a
# short reach apart so both are reachable from one spot without the
# trigger volumes overlapping (see lever.gd's own COL radius of 1.1).
# Neither is wired to anything yet - lever.gd is deliberately
# ability-agnostic (see its own header comment), so what pulling either
# one should actually do (a gate, a current, the CurrentWall1/2 swing
# that's on a raw H keypress today) is a follow-up decision, not guessed
# at here.
func _build_levers() -> void:
	var lever_a := Lever.new()
	lever_a.name = "Lever1"
	lever_a.position = Vector3(8.8, 1.5, -34.0)
	add_child(lever_a)

	var lever_b := Lever.new()
	lever_b.name = "Lever2"
	lever_b.position = Vector3(10.3, 1.5, -34.0)
	add_child(lever_b)

# Same top-right corner placement as World's own real minimap (see
# world.gd's _ready()) - MazeMiniMap only needs this level itself
# (wall_boxes + the test diver), so there's no extra wiring beyond handing
# it `self`.
func _build_minimap() -> void:
	var minimap := MazeMiniMap.new()
	minimap.maze_level = self
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -166.0
	minimap.offset_top = 10.0
	minimap.offset_right = -10.0
	minimap.offset_bottom = 166.0
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(minimap)

# A persistent on-screen hint for _rotate_left_currents_left()/_right()
# below - kept as its own label rather than reusing $HUD/Controls, since
# that one already gets overwritten by the whirlpool's warning/damage
# messages (_on_whirlpool_warned()/_on_diver_sucked_in()) and this
# instruction should stay visible regardless of whatever's happening
# there.
func _build_rotate_prompt() -> void:
	var label := Label.new()
	label.text = "Goal: press H, follow the northbound channel into the reward chamber, then press E beside the cracked relic.\nL rotates the left currents; H opens or closes the CurrentWall1/2 hallway."
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.offset_left = 16.0
	label.offset_top = -64.0
	label.offset_right = 560.0
	label.offset_bottom = -16.0
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	$HUD.add_child(label)

# Returns the wall's useful physical geometry in world space.  `basis.x` is
# deliberately contained here: no level-placement caller needs to remember
# whether a particular scene instance's apparent forward direction is local
# X, world Z, or the negative of either.
func _wall_geometry(wall: CSGBox3D) -> Dictionary:
	return _wall_geometry_at(wall.global_position, wall.rotation.y, wall.size)

# The transform variant supports placing a static wall against another wall's
# *future* destination without mutating the moving node to inspect it.
func _wall_geometry_at(center: Vector3, yaw: float, size: Vector3) -> Dictionary:
	var long_axis := Basis(Vector3.UP, yaw).x.normalized()
	var side_axis := Basis(Vector3.UP, yaw).z.normalized()
	var half_length := size.x * 0.5
	return {
		"center": center,
		"long_axis": long_axis,
		"side_axis": side_axis,
		"size": size,
		"negative_end": center - long_axis * half_length,
		"positive_end": center + long_axis * half_length,
	}

func _wall_end_sign(end: int) -> float:
	return 1.0 if end == WallEnd.POSITIVE else -1.0

func _wall_end(geometry: Dictionary, end: int) -> Vector3:
	return geometry["positive_end"] as Vector3 if end == WallEnd.POSITIVE else geometry["negative_end"] as Vector3

# The two physically valid end-to-end continuations of `target`.  This is a
# query rather than an action, so a caller can inspect or choose a placement
# without reverse-engineering either wall's local coordinate system.
func _wall_continuation_candidates(moving_wall: CSGBox3D, target_wall: CSGBox3D) -> Array[Dictionary]:
	var target_geometry: Dictionary = _wall_geometry(target_wall)
	var target_axis := target_geometry["long_axis"] as Vector3
	var target_negative := target_geometry["negative_end"] as Vector3
	var target_positive := target_geometry["positive_end"] as Vector3
	var moving_half_length := moving_wall.size.x * 0.5
	return [
		{
			"target_end": "negative",
			"position": target_negative - target_axis * moving_half_length,
		},
		{
			"target_end": "positive",
			"position": target_positive + target_axis * moving_half_length,
		},
	]

# The normal way to extend a route.  It examines both named physical target
# ends and chooses the legal continuation that requires the least movement;
# the caller never supplies a screenshot-derived boolean or local-axis sign.
func _nearest_wall_continuation(moving_wall: CSGBox3D, target_wall: CSGBox3D) -> Dictionary:
	var candidates := _wall_continuation_candidates(moving_wall, target_wall)
	var selected: Dictionary = candidates[0]
	for candidate in candidates:
		var candidate_position := candidate["position"] as Vector3
		var selected_position := selected["position"] as Vector3
		# Preserve the prior helper's deterministic tie-break: when both exits
		# are equally near, use the named positive continuation.
		if moving_wall.global_position.distance_squared_to(candidate_position) <= moving_wall.global_position.distance_squared_to(selected_position):
			selected = candidate
	var destination := selected["position"] as Vector3
	destination.y = target_wall.global_position.y
	return {
		"position": destination,
		"yaw": moving_wall.rotation.y + PI * 0.5,
		"target_end": selected["target_end"],
	}

# Rotates one wall counterclockwise by exactly 90 degrees, then translates
# it so it continues the named destination wall end-to-end. There are two
# valid non-overlapping continuations (off either end of `target`); choose
# the one requiring the least travel from the moving wall's current centre.
func _rotate_wall_flush(wall: CSGBox3D, target: CSGBox3D, duration := 1.2) -> Tween:
	var t: Dictionary = _nearest_wall_continuation(wall, target)
	return _tween_wall_to_transform_about_hinge(wall, t.position as Vector3, float(t.yaw), duration)

# The finished flush targets above are valid, but a parallel position/yaw
# tween makes a wall cut diagonally through the next hallway while it moves.
# For a non-zero turn there is exactly one hinge in the X/Z plane that takes
# a wall's current center to its target center under a rigid yaw rotation.
# Solve target = pivot + R(current - pivot), then animate around that pivot.
# This works for any wall dimensions and any non-zero yaw change; the two
# sides of a corridor naturally receive different hinges.
func _wall_motion_hinge(start: Vector3, target: Vector3, yaw_delta: float) -> Vector3:
	var c := cos(yaw_delta)
	var s := sin(yaw_delta)
	var rotated_start := Basis(Vector3.UP, yaw_delta) * start
	var rhs := Vector2(target.x - rotated_start.x, target.z - rotated_start.z)
	var determinant := (1.0 - c) * (1.0 - c) + s * s
	if determinant < 0.00001:
		return start
	return Vector3(
		((1.0 - c) * rhs.x + s * rhs.y) / determinant,
		start.y,
		(-s * rhs.x + (1.0 - c) * rhs.y) / determinant
	)

func _tween_wall_to_transform_about_hinge(wall: CSGBox3D, target_position: Vector3, target_yaw: float, duration := 1.2) -> Tween:
	var start_position := wall.global_position
	var start_yaw := wall.rotation.y
	var yaw_delta := wrapf(target_yaw - start_yaw, -PI, PI)
	if absf(yaw_delta) < 0.00001:
		return _tween_wall_to(wall, target_position, target_yaw, duration)
	var hinge := _wall_motion_hinge(start_position, target_position, yaw_delta)
	var start_offset := start_position - hinge
	var tw := create_tween()
	tw.tween_method(
		func(progress: float) -> void:
			var next_position := hinge + Basis(Vector3.UP, yaw_delta * progress) * start_offset
			next_position.y = lerpf(start_position.y, target_position.y, progress)
			wall.global_position = target_position if is_equal_approx(progress, 1.0) else next_position
			wall.rotation.y = target_yaw if is_equal_approx(progress, 1.0) else start_yaw + yaw_delta * progress,
		0.0, 1.0, duration
	)
	return tw

# Straight motion remains useful for a no-turn caller. Hallway motion never
# reaches this fallback: opening and closing both rotate 90 degrees.
func _tween_wall_to(wall: CSGBox3D, position: Vector3, yaw: float, duration := 1.2) -> Tween:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wall, "global_position", position, duration)
	tw.tween_property(wall, "rotation:y", yaw, duration)
	return tw

# Each side reaches a different static anchor, so the hallway is not a
# single rigid door with one shared hinge. `_rotate_wall_flush()` derives a
# target for each wall; `_tween_wall_to_transform_about_hinge()` then derives
# the corresponding hinge for each target and preserves it throughout the
# animation.
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
# WindCorridor3 first (the gap between CSGBox3D6/CSGBox3D7, carrying the
# player north through the newly visible passage), then
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
		_tween_wall_to_transform_about_hinge(wall_a, _hallway_1_2_home_pos_a, _hallway_1_2_home_yaw_a)
		_tween_wall_to_transform_about_hinge(wall_b, _hallway_1_2_home_pos_b, _hallway_1_2_home_yaw_b)
		_rotate_wind_corridor_1_current(false)
		_rotate_wind_corridor_2_current(false)
		_hallway_1_2_swung = false
		$HUD/Controls.text = "Hallway closing..."
		get_tree().create_timer(1.25).timeout.connect(func() -> void:
			if not _hallway_1_2_swung and not _completed:
				$HUD/Controls.text = "Hallway: CLOSED — press H to reopen the route to the relic."
		)
		return
	_hallway_1_2_home_pos_a = wall_a.global_position
	_hallway_1_2_home_yaw_a = wall_a.rotation.y
	_hallway_1_2_home_pos_b = wall_b.global_position
	_hallway_1_2_home_yaw_b = wall_b.rotation.y
	_rotate_wall_flush(wall_a, $CSGBox3D)
	_rotate_wall_flush(wall_b, $CurrentWall3)
	_rotate_wind_corridor_2_current(true)
	_rotate_wind_corridor_1_current(true)
	_hallway_1_2_swung = true
	$HUD/Controls.text = "Hallway opening..."
	get_tree().create_timer(1.25).timeout.connect(func() -> void:
		if _hallway_1_2_swung and not _completed:
			$HUD/Controls.text = "Hallway: OPEN — follow the northbound current to the reward chamber."
	)

# WindCorridor1's current is parked while H opens the hallway, then restored
# on close.  The opened route enters WindCorridor2 from the west and only
# becomes northbound once it reaches WindCorridor3.  Moving this current into
# Corridor2 therefore turns the route's *entrance* into a one-way current:
# the player is bounced or stripped of lateral steering before reaching the
# northbound gap.  Corridor2's own current is the one that moves to
# Corridor3 and carries the diver through the visible CSGBox3D6/7 passage;
# the Corridor1 current must be inactive during that state.
#
# Parking preserves the same current object and restores the authored
# NEGATIVE_Z flow on close, rather than creating a duplicate or relying on a
# generic 90-degree turn to happen to recover the initial puzzle state.
var _hallway_1_parked_current: WaterCurrent

func _rotate_wind_corridor_1_current(open: bool) -> void:
	if open:
		var current: WaterCurrent = _currents_by_corridor.get($WindCorridor1, null)
		if current == null:
			push_warning("_rotate_hallway_1_2: no current is set up at WindCorridor1")
			return
		current.teardown()
		_currents_by_corridor.erase($WindCorridor1)
		_hallway_1_parked_current = current
	else:
		var current := _hallway_1_parked_current
		if current == null:
			push_warning("_rotate_hallway_1_2: no parked current is available for WindCorridor1")
			return
		current.setup($WindCorridor1, WaterCurrent.direction_to_vector(WaterCurrent.Direction.NEGATIVE_Z), current.strength, false)
		_currents_by_corridor[$WindCorridor1] = current
		_hallway_1_parked_current = null

# WindCorridor2's current moves into WindCorridor3 (the gap between
# CSGBox3D6/CSGBox3D7) on open, then returns on close. Its open direction
# is deliberately north/positive-Z: this H state calls the hallway open, so
# the current must help a player traverse the visible opening rather than
# overpower their swim input back into the wall. Closing restores the
# original NEGATIVE_X direction set in _setup_currents().
func _rotate_wind_corridor_2_current(open: bool) -> void:
	if open:
		var current: WaterCurrent = _currents_by_corridor.get($WindCorridor2, null)
		if current == null:
			push_warning("_rotate_hallway_1_2: no current is set up at WindCorridor2")
			return
		current.setup($WindCorridor3, WaterCurrent.direction_to_vector(WaterCurrent.Direction.POSITIVE_Z), current.strength, false)
		_currents_by_corridor.erase($WindCorridor2)
		_currents_by_corridor[$WindCorridor3] = current
	else:
		var current: WaterCurrent = _currents_by_corridor.get($WindCorridor3, null)
		if current == null:
			push_warning("_rotate_hallway_1_2: no current is set up at WindCorridor3")
			return
		current.setup($WindCorridor2, WaterCurrent.direction_to_vector(WaterCurrent.Direction.NEGATIVE_X), current.strength, false)
		_currents_by_corridor.erase($WindCorridor3)
		_currents_by_corridor[$WindCorridor2] = current
		
# Places a wall at an intentionally authored perpendicular exit.  This is for
# fixed scene topology (CurrentWall1's initial attachment), not the usual
# dynamic route extension; call `_nearest_wall_continuation()` for that.
func _attach_wall_to_perpendicular_exit(reference_wall: CSGBox3D, moving_wall: CSGBox3D, reference_exit: int, moving_anchor_end: int) -> void:
	var reference_geometry: Dictionary = _wall_geometry(reference_wall)
	moving_wall.global_position = _perpendicular_exit_position(
		reference_geometry, moving_wall.rotation.y, moving_wall.size,
		reference_exit, moving_anchor_end
	)

# The only caller-facing choices are named `reference_exit` and
# `moving_anchor_end`.  All local-axis math remains here, so a new wall does
# not require examining basis vectors or trial-and-error screenshots.
func _perpendicular_exit_position(reference_geometry: Dictionary, moving_yaw: float, moving_size: Vector3, reference_exit: int, moving_anchor_end: int) -> Vector3:
	var reference_long_axis := reference_geometry["long_axis"] as Vector3
	var reference_side_axis := reference_geometry["side_axis"] as Vector3
	var reference_size := reference_geometry["size"] as Vector3
	var reference_end := _wall_end(reference_geometry, reference_exit)
	var moving_long_axis := Basis(Vector3.UP, moving_yaw).x.normalized()
	var outward_sign := _wall_end_sign(reference_exit)
	var moving_anchor_sign := _wall_end_sign(moving_anchor_end)
	var clearance := reference_long_axis * moving_size.z * 0.5 * outward_sign
	return reference_end + clearance + moving_long_axis * moving_size.x * 0.5 * moving_anchor_sign - reference_side_axis * reference_size.z * 0.5

# Extends a wall out from a *known physical endpoint*.  `outward_long_axis`
# must point away from the source wall at `outward_end`; callers use the
# geometry query above to obtain both names rather than recreate axis signs.
func _position_beyond_wall_end(outward_end: Vector3, outward_long_axis: Vector3, source_thickness: float, moving_yaw: float, moving_size_x: float, moving_size_z: float, moving_anchor_end: int) -> Vector3:
	var moving_long_axis := Basis(Vector3.UP, moving_yaw).x.normalized()
	var source_side_axis := Vector3(-outward_long_axis.z, 0.0, outward_long_axis.x)
	var clearance := outward_long_axis * moving_size_z * 0.5
	return outward_end + clearance + moving_long_axis * moving_size_x * 0.5 * _wall_end_sign(moving_anchor_end) - source_side_axis * source_thickness * 0.5


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

# Set once by _build_floor() below - the Y of the invisible floor's actual
# top surface, not its center. Read by _physics_process() to know where
# the golden orbs should stop falling.
var _floor_top_y := 0.0

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
	# The floor slab is centered on floor_y and _FLOOR_THICKNESS deep, so
	# its actual top SURFACE - what anything falling should stop at - is
	# half a thickness above that center, not floor_y itself (see
	# _physics_process()'s golden-orb fall).
	_floor_top_y = floor_y + _FLOOR_THICKNESS * 0.5

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

# Prototype_V(1922) ("Mech Pilot") specifically - the only diver with no
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

# Slow underwater sink, not real gravity's 9.8 m/s^2 - this is a diver's
# drowned-treasure orb drifting down through water, not something in
# freefall through air. Scaled by dt (seconds/frame) rather than
# subtracted as a flat amount per frame, so the fall rate stays the same
# regardless of framerate.
const GOLDEN_ORB_FALL_SPEED := 1.5

func _physics_process(dt: float) -> void:
	if _diver == null:
		return
	for orb in goldenOrbs:
		if orb.position.y > _floor_top_y:
			orb.position.y = maxf(orb.position.y - GOLDEN_ORB_FALL_SPEED * dt, _floor_top_y)
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
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_E:
		# MazeLevel is a standalone review scene, so World cannot forward its
		# normal ability input here. Keep the final relic interaction on the
		# same player-facing E key used elsewhere in the game.
		_diver.use_ability()
