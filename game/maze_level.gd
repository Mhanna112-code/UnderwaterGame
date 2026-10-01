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
	_normalize_wall_heights()
	# Before _setup_walls(): wall placement can reposition _diver (see
	# _place_wall_straight_to_reference()), which needs it to exist already.
	_spawn_test_diver()
	_setup_walls()
	# After _setup_walls() so it uses both walls' placed positions (and
	# overrides any debug move of the diver during wall placement).
	_place_diver_between($CSGBox3D, $CurrentWall3)
	_corridor_walls = {
		$WindCorridor3: [$CSGBox3D6, $CSGBox3D7],
		$WindCorridor4: [$CSGBox3D12, $CSGBox3D13],
	}
	_align_corridors_to_walls()
	_setup_currents()
	_setup_whirlpool()
	_build_levers()
	_build_rotate_prompt()
	_build_floor()
	_build_perimeter_walls()
	_build_ceiling()
	_build_minimap()
	_build_item_rocks()
	_build_completion_ui()
	_spawn_debug_door()
	$HUD/Controls.text = "Hallway: CLOSED — press H to open the route to the relic."

# TEMPORARY - just here to get door.fbx's raw mesh size printed to the
# Output panel (see Door._ready()'s own print(mesh_instance.get_aabb().size)).
# Remove this call once that's no longer needed; Door is a real gameplay
# class used elsewhere (world.gd's lock-plate puzzle), not something the
# maze level normally spawns on its own.
func _spawn_debug_door() -> void:
	var door := Door.new()
	add_child(door)

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

# Every wall was authored at a slightly different Y (1.44 here, 1.71 there,
# 1.52881 elsewhere, plus genuinely different structures like the reward
# chamber at 6.5) - individually negligible, but it leaves small vertical
# seams wherever two walls meet (exactly what showed up between the new
# connector/stub and CSGBox3D7). What actually needs to match across every
# wall, regardless of its own height (size.y), is where its BASE sits - they
# should all stand on the same floor, not share the same center. _build_floor()
# already derives the floor's own height from whichever wall currently has
# the lowest base (position.y - size.y*0.5); reusing that same value here
# means every wall's base ends up exactly on that floor, and _build_floor()
# needs no changes at all - it'll naturally compute the same value again
# once every wall's base already sits there.
func _normalize_wall_heights() -> void:
	var floor_y := INF
	for box in wall_boxes:
		floor_y = minf(floor_y, box.position.y - box.size.y * 0.5)
	if floor_y == INF:
		return
	for box in wall_boxes:
		box.position.y = floor_y + box.size.y * 0.5

func _setup_walls():
	# This is an authored, intentional perpendicular join: CurrentWall1 starts
	# on CSGBox3D's positive exit with its own positive end as the anchor.  It
	# is therefore named here instead of being encoded as `_set_...(true, true)`.
	_attach_wall_to_perpendicular_exit(
		$CSGBox3D, $CurrentWall1, WallEnd.POSITIVE, WallEnd.POSITIVE
	)
	_place_csgbox6_at_hallway_target()
	_place_csgbox12_at_hallway_target()
	_place_new_walls_between_box13_and_box7()
	_place_box8_and_box9_flush()
	_place_remaining_perimeter_walls_flush()
	_place_box28_flush_to_box14()
	_build_door_frame_between_box30_and_box32()

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

	# CSGBox3D6's rotation is its own original authored orientation from the
	# scene - not derived from CurrentWall1 at all. Only its position is
	# computed here.

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
	# Which of wall1_future's own two ends is the free/outer one (as opposed
	# to the one CurrentWall1 pivots/touches at) isn't reliably "positive" or
	# "negative" - it flips depending on both walls' actual authored
	# rotations (confirmed: Box6 and Box12 resolve oppositely). Derived by
	# checking which end sits farther from the real attachment point on
	# wall_orig, rather than assumed.
	var wall_orig_geometry: Dictionary = _wall_geometry(wall_orig)
	var wall1_attach_point: Vector3 = _wall_end(wall_orig_geometry,
		WallEnd.POSITIVE if String(wall1_target.target_end) == "positive" else WallEnd.NEGATIVE)
	var wall1_negative_end := wall1_future["negative_end"] as Vector3
	var wall1_positive_end := wall1_future["positive_end"] as Vector3
	var wall1_outer_end: Vector3
	var wall1_outward_axis: Vector3
	if wall1_negative_end.distance_squared_to(wall1_attach_point) > wall1_positive_end.distance_squared_to(wall1_attach_point):
		wall1_outer_end = wall1_negative_end
		wall1_outward_axis = -(wall1_future["long_axis"] as Vector3)
	else:
		wall1_outer_end = wall1_positive_end
		wall1_outward_axis = wall1_future["long_axis"] as Vector3
	# CSGBox3D6's own long axis, from its own actual rotation - not derived
	# from CurrentWall1's outward axis, since that derivation only
	# coincidentally matches a target wall's own axis for some wall pairs
	# and not others (confirmed opposite-signed for Box6 vs Box12).
	var wall6_long_axis := Basis(Vector3.UP, wall_6.rotation.y).x.normalized()
	var wall_6_original_position := wall_6.global_position
	wall_6.global_position = _position_beyond_wall_end(
		wall1_outer_end, wall1_outward_axis, wall_a.size.z,
		wall6_long_axis, wall_6.size.x, wall_6.size.z
	)

	# CSGBox3D7 is the opposite *static* boundary of the northbound passage,
	# not another part of CurrentWall1's moving assembly. It must begin on the
	# same cross-line as CSGBox3D6, but remain laterally separated to form the
	# passage. Project the ORIGINAL authored offset (from Box6's
	# pre-correction position, not its corrected one) onto Box6's side axis:
	# this preserves the authored lane width while discarding only the
	# forward/vertical offset. Using Box6's corrected position instead would
	# contaminate this with however much Box6's own correction itself moved
	# sideways - not necessarily zero, since Box6 attaches by one end
	# perpendicular to the corridor rather than continuing it in a straight
	# line. Box7 never moves during H, so it cannot sweep into CurrentWall1's
	# opened position.
	var wall_6_geometry: Dictionary = _wall_geometry(wall_6)
	var lane_side := wall_6_geometry["side_axis"] as Vector3
	var authored_offset := wall_7.global_position - wall_6_original_position
	var preserved_lane_offset := lane_side * authored_offset.dot(lane_side)

	var wall7_long_axis := wall_6_geometry["long_axis"] as Vector3
	var wall6_position := wall_6_geometry["negative_end"] as Vector3
	var wall7_flush_position := wall6_position + wall7_long_axis * (wall_7.size.x * 0.5)
	wall_7.global_position = wall7_flush_position + preserved_lane_offset

# CSGBox3D12/13 mirror CSGBox3D6/7's own relationship to CurrentWall1/CSGBox3D
# one hallway pair over - see that function's own reasoning above, which
# applies here unchanged. CSGBox3D12 does not rotate or move at runtime
# either; it's placed exactly ONCE, here, at the position/rotation
# CurrentWall2 WOULD end up at if the H-key hallway swing were triggered
# right now. CurrentWall2 never has to actually swing for this to be correct.
func _place_csgbox12_at_hallway_target() -> void:
	var wall_2: CSGBox3D = $CurrentWall2
	var wall_3: CSGBox3D = $CurrentWall3
	var wall_12: CSGBox3D = $CSGBox3D12
	var wall_13: CSGBox3D = $CSGBox3D13

	# CSGBox3D12's rotation is its own original authored orientation from the
	# scene - not derived from CurrentWall2 at all, same as CSGBox3D6 above.
	# Only its position is computed here.

	# CSGBox3D12 attaches to CurrentWall2's FUTURE far end, not to
	# CurrentWall3 directly with a static reference frame - same reasoning as
	# CSGBox3D6's own placement above.
	var wall2_target: Dictionary = _nearest_wall_continuation(wall_2, wall_3)
	var wall2_target_yaw := float(wall2_target.yaw)
	var wall2_target_position := wall2_target.position as Vector3
	var wall2_future: Dictionary = _wall_geometry_at(wall2_target_position, wall2_target_yaw, wall_2.size)
	# Same as CSGBox3D6's own placement above: which of wall2_future's own
	# two ends is the free/outer one isn't reliably "positive" or "negative"
	# - derived by checking which end sits farther from the real attachment
	# point on CurrentWall3, rather than assumed.
	var wall_3_geometry: Dictionary = _wall_geometry(wall_3)
	var wall2_attach_point: Vector3 = _wall_end(wall_3_geometry,
		WallEnd.POSITIVE if String(wall2_target.target_end) == "positive" else WallEnd.NEGATIVE)
	var wall2_negative_end := wall2_future["negative_end"] as Vector3
	var wall2_positive_end := wall2_future["positive_end"] as Vector3
	var wall2_outer_end: Vector3
	var wall2_outward_axis: Vector3
	if wall2_negative_end.distance_squared_to(wall2_attach_point) > wall2_positive_end.distance_squared_to(wall2_attach_point):
		wall2_outer_end = wall2_negative_end
		wall2_outward_axis = -(wall2_future["long_axis"] as Vector3)
	else:
		wall2_outer_end = wall2_positive_end
		wall2_outward_axis = wall2_future["long_axis"] as Vector3
	# CSGBox3D12's own long axis, from its own actual rotation - same
	# reasoning as CSGBox3D6 above.
	var wall12_long_axis := Basis(Vector3.UP, wall_12.rotation.y).x.normalized()
	var wall_12_original_position := wall_12.global_position
	wall_12.global_position = _position_beyond_wall_end(
		wall2_outer_end, wall2_outward_axis, wall_2.size.z,
		wall12_long_axis, wall_12.size.x, wall_12.size.z
	)

	var wall_12_geometry: Dictionary = _wall_geometry(wall_12)
	var lane_side := wall_12_geometry["side_axis"] as Vector3
	var authored_offset := wall_12.global_position - wall_12_original_position
	var preserved_lane_offset := lane_side * authored_offset.dot(lane_side)
	var wall13_long_axis := wall_12_geometry["long_axis"] as Vector3
	var wall12_position := wall_12_geometry["negative_end"] as Vector3
	var wall13_flush_position := wall12_position + wall13_long_axis * (wall_13.size.x * 0.5)
	wall_13.global_position = wall13_flush_position + preserved_lane_offset
	
# SCAFFOLDING - position/rotation math not filled in yet. Connects CSGBox3D13
# to CSGBox3D7 with two new walls: a long one flush against CSGBox3D13, and a
# short perpendicular one filling the gap it leaves at the CSGBox3D7 end.
func _place_new_walls_between_box13_and_box7() -> void:
	var wall_13: CSGBox3D = $CSGBox3D13
	var wall_7: CSGBox3D = $CSGBox3D7
	var wall_13_geometry: Dictionary = _wall_geometry(wall_13)
	var wall_7_geometry: Dictionary = _wall_geometry(wall_7)
	# Target end = the first end reached moving from center in the +long_axis
	# direction, i.e. each wall's own positive_end.
	var wall13_target_end := wall_13_geometry["negative_end"] as Vector3
	var wall7_target_end := wall_7_geometry["negative_end"] as Vector3

	var wall13_long_axis := wall_13_geometry["long_axis"] as Vector3
	var raw_projection := wall13_long_axis.dot(wall7_target_end - wall13_target_end)
	var connector_direction := wall13_long_axis if raw_projection >= 0.0 else -wall13_long_axis
	var connector_length := absf(raw_projection) - wall_13.size.z
	var connector_yaw := wall_13.rotation.y if raw_projection >= 0.0 else wall_13.rotation.y + PI

	var connector := CSGBox3D.new()
	connector.name = "CSGBox3DConnector"
	connector.use_collision = true
	connector.size = Vector3(connector_length, wall_13.size.y, wall_13.size.z)
	add_child(connector)
	connector.rotation.y = connector_yaw
	connector.global_position = wall13_target_end + connector_direction * (connector_length * 0.5)

	# The stub turns perpendicular to the connector and picks up right where
	# the connector fell short (its own positive_end), closing the remaining
	# distance to wall7_target_end - same projection approach as the
	# connector itself, just off a perpendicular axis and a different anchor
	# point. stub_anchor adds the same clearance the connector itself needed
	# (see _position_beyond_wall_end's own clearance term): the connector's
	# positive_end sits size.z short of wall_7's own axis, on purpose, so the
	# stub's own thickness can fill exactly that gap rather than floating
	# short of it.
	var connector_geometry: Dictionary = _wall_geometry(connector)
	var connector_positive_end := connector_geometry["positive_end"] as Vector3
	var stub_anchor := connector_positive_end + connector_direction * (wall_13.size.z * 0.5)
	var stub_axis := Vector3(-connector_direction.z, 0.0, connector_direction.x)
	var stub_raw_projection := stub_axis.dot(wall7_target_end - stub_anchor)
	var stub_direction := stub_axis if stub_raw_projection >= 0.0 else -stub_axis
	# Derive yaw directly from stub_direction rather than conditionally
	# picking connector_yaw +/- PI*0.5 separately - those two do not
	# necessarily agree in sign, which left the stub's own geometry using a
	# different axis than the one it was actually positioned along.
	var stub_yaw := atan2(-stub_direction.z, stub_direction.x)

	# stub_anchor and wall7_target_end are both centerlines (of the
	# connector's own thickness, and of wall_7's own thickness,
	# respectively), not their near faces - without correction the stub's
	# own two ends only touch a single line through each target's thickness
	# band, leaving half of each target's own width sticking out past the
	# stub with no material behind it. Extend both ends by half the
	# relevant thickness to actually reach each target's near face.
	var stub_near_end := stub_anchor - stub_direction * (connector.size.z * 0.5)
	var stub_far_end := wall7_target_end + stub_direction * (wall_7.size.z * 0.5)
	var stub_length := stub_near_end.distance_to(stub_far_end)

	var stub := CSGBox3D.new()
	stub.name = "CSGBox3DConnectorStub"
	stub.use_collision = true
	stub.size = Vector3(stub_length, wall_13.size.y, wall_13.size.z)
	add_child(stub)
	stub.rotation.y = stub_yaw
	stub.global_position = stub_near_end + stub_direction * (stub_length * 0.5)

# CSGBox3D8/9 already sit at yaw=0, perpendicular to CSGBox3D12/13's own
# (roughly +/-90 degree) rotation - like CSGBox3D6/12 above, only their
# position needs correcting, not their rotation. Each attaches to whichever
# of its own target's two ends its current (pre-correction) position sits
# closer to, same distance-based derivation as everywhere else in this file,
# rather than assuming a fixed end.
func _place_box8_and_box9_flush() -> void:
	_place_wall_flush_to_reference($CSGBox3D8, $CSGBox3D12)
	_place_wall_flush_to_reference($CSGBox3D9, $CSGBox3D13)

# Continues the same chain outward from Box8/9 - each wall here attaches to
# whichever of the previous wall's own ends it sits closer to, same as
# above, so this must run after _place_box8_and_box9_flush() and each call
# below must stay in dependency order: a wall has to already be placed
# before anything attaches to it.
func _place_remaining_perimeter_walls_flush() -> void:
	_place_wall_flush_to_reference($CSGBox3D11, $CSGBox3D9)
	_place_wall_flush_to_reference($CSGBox3D10, $CSGBox3D8)
	_place_wall_flush_to_reference($CSGBox3D15, $CSGBox3D10)
	_place_wall_flush_to_reference($CSGBox3D14, $CSGBox3D11)
	# Exactly perpendicular to Box15, running +Z: the scene's authored yaw was
	# -89.771 degrees, which drifted Box16's far end ~0.16m off square.
	# Box15's yaw minus 90 degrees puts Box16's long axis (basis.x) on +Z.
	($CSGBox3D16 as CSGBox3D).rotation.y = ($CSGBox3D15 as CSGBox3D).rotation.y - PI * 0.5
	_place_wall_flush_to_reference($CSGBox3D16, $CSGBox3D15)
	
	_place_wall_flush_to_reference($CSGBox3D27, $CSGBox3D14)
	_place_wall_flush_to_reference($CSGBox3D22, $CSGBox3D21)
	# Box17 continues Box27 in a straight line (opposite yaw), not at a
	# right angle - the flush helper's perpendicular offsets sank Box17
	# almost entirely inside Box27.
	_place_wall_straight_to_reference($CSGBox3D17, $CSGBox3D27)
	_place_wall_flush_to_reference($CSGBox3D19, $CSGBox3D17, true)
	_place_wall_flush_to_reference($CSGBox3D18, $CSGBox3D16, true)
	_place_wall_flush_to_reference($CSGBox3D21, $CSGBox3D18)
	_place_wall_flush_to_reference($CSGBox3D20, $CSGBox3D19)
	_place_wall_flush_to_reference($CSGBox3D22, $CSGBox3D21, true)
	_place_wall_flush_to_reference($CSGBox3D23, $CSGBox3D22)
	_place_wall_flush_to_reference($CSGBox3D25, $CSGBox3D23, true)
	_place_wall_flush_to_reference($CSGBox3D24, $CSGBox3D25)
	_place_wall_flush_to_reference($RewardChamberWestWall, $CSGBox3D24)
	_place_wall_flush_to_reference($CSGBox3D30, $CSGBox3D6, true)
	_place_wall_flush_to_reference($CSGBox3D29, $CSGBox3D7)
	_place_wall_flush_to_reference($CSGBox3D33, $CSGBox3D29, true)
	_place_wall_flush_to_reference($CSGBox3D32, $CSGBox3D33, true)


# Opening left between the two door-frame walls below: width x height,
# matching Door's own default span (z = width across, y = height).
const DOOR_OPENING := Vector2(2.3, 6.0)

# Closes the gap between CSGBox3D30 and CSGBox3D32 (parallel walls) with a
# wall running from Box30's positive end across to Box32's near face, split
# into two pieces with a DOOR_OPENING-wide gap in the middle, plus a lintel
# over the gap that reaches the top of the walls. Everything is derived from
# both walls' placed geometry, so this must run after their flush placement.
func _build_door_frame_between_box30_and_box32() -> void:
	var box30 := $CSGBox3D30 as CSGBox3D
	var box32 := $CSGBox3D32 as CSGBox3D
	var g30: Dictionary = _wall_geometry(box30)
	var g32: Dictionary = _wall_geometry(box32)

	# Across from Box30 toward Box32 (Box30's own side axis, signed), and
	# out past Box30's positive end so the new wall sits flush against it.
	var side30 := g30["side_axis"] as Vector3
	var toward := side30 if ((g32["center"] as Vector3) - (g30["center"] as Vector3)).dot(side30) > 0.0 else -side30
	var outward := g30["long_axis"] as Vector3
	var end30 := g30["positive_end"] as Vector3
	var thickness := box30.size.z
	var line_origin := end30 + outward * thickness * 0.5

	# Starts at Box30's far face (filling the corner, same as the flush
	# helper does) and stops at Box32's near face.
	var start := line_origin - toward * box30.size.z * 0.5
	var length := ((g32["center"] as Vector3) - start).dot(toward) - box32.size.z * 0.5
	var piece_length := (length - DOOR_OPENING.x) * 0.5
	if piece_length <= 0.0:
		push_warning("_build_door_frame_between_box30_and_box32: walls are too close for the door opening")
		return

	var height := box30.size.y
	var bottom := box30.global_position.y - height * 0.5
	var yaw := atan2(-toward.z, toward.x)   # long axis (basis.x) along `toward`

	var piece_a := start + toward * piece_length * 0.5
	var piece_b := start + toward * (length - piece_length * 0.5)
	var door_center := start + toward * (piece_length + DOOR_OPENING.x * 0.5)
	piece_a.y = bottom + height * 0.5
	piece_b.y = bottom + height * 0.5
	wall_boxes.append(_spawn_wall("Box30DoorWallA", piece_a, yaw, Vector3(piece_length, height, thickness)))
	wall_boxes.append(_spawn_wall("Box30DoorWallB", piece_b, yaw, Vector3(piece_length, height, thickness)))

	# Kept out of wall_boxes so the minimap still shows the doorway as open.
	var lintel_height := height - DOOR_OPENING.y
	door_center.y = bottom + DOOR_OPENING.y + lintel_height * 0.5
	_spawn_wall("Box30DoorLintel", door_center, yaw, Vector3(DOOR_OPENING.x, lintel_height, thickness))

func _spawn_wall(wall_name: String, center: Vector3, yaw: float, wall_size: Vector3) -> CSGBox3D:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.size = wall_size
	wall.use_collision = true
	wall.add_to_group("Wall")
	add_child(wall)
	wall.rotation.y = yaw
	wall.global_position = center
	return wall

# CSGBox3D28 stays at its own authored rotation (already perpendicular to
# CSGBox3D14 - 90 degrees vs Box14's 0). Walking the Box11->Box14->Box27
# corridor south to north, Box14 runs east-west and Box27 continues north
# from Box14's east (+X, its own positive_end) side, so "flush to the right
# side of Box14" (facing north) means flush against that same +X end - which
# is also just Box14's own long axis direction. Runs after
# _place_remaining_perimeter_walls_flush() since it depends on Box14's own
# final corrected position.
func _place_box28_flush_to_box14() -> void:
	var box14 := $CSGBox3D14 as CSGBox3D
	var box28 := $CSGBox3D28 as CSGBox3D
	var box14_geometry: Dictionary = _wall_geometry(box14)
	var box14_long_axis := box14_geometry["long_axis"] as Vector3
	var box14_bottom := box14.position.y - box14.size.y * 0.5

	box28.global_position = box14.global_position
	box28.rotation.y = box14.rotation.y - PI * 0.5
	box28.position.y = box14_bottom + box28.size.y * 0.5
	
	var push_direction := Basis(Vector3.UP, box28.rotation.y).x.normalized()
	box28.global_position += push_direction * (box28.size.x * 0.5)
	var side_direction := Vector3(-push_direction.z, 0.0, push_direction.x)
	box28.global_position += side_direction * (box28.size.z * 0.5 + box14.size.z * 0.5)
	box28.position.y = box14_bottom + box28.size.y * 0.5

# Named from wall_to_place/reference_wall's own point of view, not
# _position_beyond_wall_end()'s (that function calls the fixed anchor
# "moving_wall" and the wall being positioned "target_wall" - opposite of
# what those words would suggest here - so this wrapper uses its own,
# unambiguous names and maps them onto that call explicitly).
func _place_wall_flush_to_reference(wall_to_place: CSGBox3D, reference_wall: CSGBox3D, use_positive: bool = false) -> void:
	var reference_geometry: Dictionary = _wall_geometry(reference_wall)
	var reference_negative_end := reference_geometry["negative_end"] as Vector3
	var reference_positive_end := reference_geometry["positive_end"] as Vector3
	var reference_outer_end: Vector3
	var reference_outward_axis: Vector3
	if wall_to_place.global_position.distance_squared_to(reference_negative_end) < wall_to_place.global_position.distance_squared_to(reference_positive_end):
		reference_outer_end = reference_negative_end
		reference_outward_axis = -(reference_geometry["long_axis"] as Vector3)
	else:
		reference_outer_end = reference_positive_end
		reference_outward_axis = reference_geometry["long_axis"] as Vector3
	var wall_to_place_long_axis := Basis(Vector3.UP, wall_to_place.rotation.y).x.normalized()
	wall_to_place.global_position = _position_beyond_wall_end(
		reference_outer_end, reference_outward_axis, reference_wall.size.z,
		wall_to_place_long_axis, wall_to_place.size.x, wall_to_place.size.z, use_positive
	)
	_match_wall_bottom(wall_to_place, reference_wall)

# The ends from _wall_geometry() sit at the reference wall's centre height,
# so placing off them copies that centre y. For walls of different heights
# (Box25/24/RewardChamberWestWall are 14 tall, the rest ~4) that sank the
# taller wall's bottom below the floor. Line the bottoms up instead.
func _match_wall_bottom(wall_to_place: CSGBox3D, reference_wall: CSGBox3D) -> void:
	var reference_bottom := reference_wall.global_position.y - reference_wall.size.y * 0.5
	wall_to_place.global_position.y = reference_bottom + wall_to_place.size.y * 0.5

# Places wall_to_place in a straight line off whichever end of reference_wall
# it sits closer to. Assumes wall_to_place is rotated in the direction
# opposite from reference_wall.
func _place_wall_straight_to_reference(wall_to_place: CSGBox3D, reference_wall: CSGBox3D) -> void:
	var reference_geometry: Dictionary = _wall_geometry(reference_wall)
	var reference_negative_end := reference_geometry["negative_end"] as Vector3
	var reference_positive_end := reference_geometry["positive_end"] as Vector3
	var reference_outer_end: Vector3
	var reference_outward_axis: Vector3
	if wall_to_place.global_position.distance_squared_to(reference_negative_end) < wall_to_place.global_position.distance_squared_to(reference_positive_end):
		reference_outer_end = reference_negative_end
		reference_outward_axis = -(reference_geometry["long_axis"] as Vector3)
	else:
		reference_outer_end = reference_positive_end
		reference_outward_axis = reference_geometry["long_axis"] as Vector3


	# Centre on the chosen end, then push out along that end's outward axis
	# by half wall_to_place's length so its near end meets the reference
	# wall's end instead of straddling it.
	wall_to_place.global_position = reference_outer_end
	if _diver != null:
		_diver.global_position = reference_outer_end + Vector3(10,10,10)
	#wall_to_place.global_position += reference_outward_axis * wall_to_place.size.x * 0.5
	
	var wall_27 := $CSGBox3D27 as CSGBox3D
	var wall_17 := $CSGBox3D17 as CSGBox3D
	var outer_axis: Vector3 = wall_27.global_transform.basis.x.normalized()

	wall_17.rotation.y = wall_17.rotation.y + PI
	var placed_axis: Vector3 = wall_17.global_transform.basis.x.normalized()
	var center_sign := 1.0 if placed_axis.dot(Vector3.LEFT) > 0.0 else -1.0
	wall_17.global_position = reference_outer_end + placed_axis * wall_17.size.x * 0.5
	const WIDTH := 2.3
	wall_17.global_position += outer_axis * WIDTH

	


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
	# Named so verify/maze_minimap.gd can find it at HUD/MazeMiniMap.
	minimap.name = "MazeMiniMap"
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
	label.text = "Goal: press H, follow the northbound channel into the reward chamber, then press E beside the cracked relic.\nL opens the maze map (Left/Right: walls, Shift+Left/Right: currents); H swings CurrentWall1/2; C moves Corridor1's current to Corridor2; V moves Corridor3's current to Corridor4 (past the whirlpool) and back."
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

# Wall sets the L maze map can select and rotate: the nearest revealed set
# blinks (walls plus the current running between them) and E rotates it.
# "rotate" swings the set to its other position and back. Only
# CurrentWall1/2 rotate so far - add an entry here for each new set.
func rotatable_wall_sets() -> Array[Dictionary]:
	return [{
		"name": "CurrentWall1/2",
		"walls": [$CurrentWall1, $CurrentWall2],
		"rotate": _rotate_hallway_1_2,
	}]

func _rotate_hallway_1_2() -> void:
	var wall_a: CSGBox3D = $CurrentWall1
	var wall_b: CSGBox3D = $CurrentWall2
	if _hallway_1_2_swung:
		_tween_wall_to_transform_about_hinge(wall_a, _hallway_1_2_home_pos_a, _hallway_1_2_home_yaw_a)
		_tween_wall_to_transform_about_hinge(wall_b, _hallway_1_2_home_pos_b, _hallway_1_2_home_yaw_b)
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
	_hallway_1_2_swung = true
	$HUD/Controls.text = "Hallway opening..."
	get_tree().create_timer(1.25).timeout.connect(func() -> void:
		if _hallway_1_2_swung and not _completed:
			$HUD/Controls.text = "Hallway: OPEN."
	)

# Currents move independently of the walls (H only swings CurrentWall1/2):
#   C - WindCorridor1's current rotates into WindCorridor2, flowing east
#       (+X), and back. WindCorridor2 has no current of its own.
#   V - the current starts in WindCorridor3 pushing -Z (south), which blocks
#       the way forward from Corridor2. V moves it into WindCorridor4, where
#       it pushes +Z (north) - the only way past the whirlpool at the back of
#       Corridor4 (see _setup_whirlpool()), but it then blocks Corridor3's
#       route the other way until it's moved back. V again returns it.
var _current_1_in_2 := false
var _current_3_in_4 := false

func _toggle_current_1_to_2() -> void:
	if _current_1_in_2:
		_move_current($WindCorridor2, $WindCorridor1, WaterCurrent.Direction.NEGATIVE_Z)
	else:
		_move_current($WindCorridor1, $WindCorridor2, WaterCurrent.Direction.POSITIVE_X)
	_current_1_in_2 = not _current_1_in_2
	$HUD/Controls.text = "Current moved to WindCorridor2." if _current_1_in_2 else "Current moved back to WindCorridor1."

func _toggle_current_3_to_4() -> void:
	if _current_3_in_4:
		_move_current($WindCorridor4, $WindCorridor3, WaterCurrent.Direction.NEGATIVE_Z)
	else:
		_move_current($WindCorridor3, $WindCorridor4, WaterCurrent.Direction.POSITIVE_Z)
	_current_3_in_4 = not _current_3_in_4
	$HUD/Controls.text = "Current moved to WindCorridor4 - it can carry you past the whirlpool." if _current_3_in_4 else "Current moved back to WindCorridor3."

# R on the maze map: rotates whichever current is in `corridor` to its
# paired corridor - Corridor1 <-> 2 (same as C) and Corridor3 <-> 4 (same
# as V). Returns the corridor the current ended up in, or null if this
# current has nowhere to rotate to.
func rotate_current_in(corridor: Area3D) -> Area3D:
	if corridor == $WindCorridor1 or corridor == $WindCorridor2:
		_toggle_current_1_to_2()
		return $WindCorridor2 if _current_1_in_2 else $WindCorridor1
	if corridor == $WindCorridor3 or corridor == $WindCorridor4:
		_toggle_current_3_to_4()
		return $WindCorridor4 if _current_3_in_4 else $WindCorridor3
	$HUD/Controls.text = "That current can't be rotated."
	return null

# Re-targets the same WaterCurrent object from one corridor to another with
# a new flow direction, keeping _currents_by_corridor keyed by where it is.
func _move_current(from_area: Area3D, to_area: Area3D, dir: WaterCurrent.Direction) -> void:
	var current: WaterCurrent = _currents_by_corridor.get(from_area, null)
	if current == null:
		push_warning("_move_current: no current at %s" % from_area.name)
		return
	current.setup(to_area, WaterCurrent.direction_to_vector(dir), current.strength, false)
	_currents_by_corridor.erase(from_area)
	_currents_by_corridor[to_area] = current

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
# moving_wall_outer_end must be moving_wall's free/outer end (looking down
# its own long axis after rotation - not the end it pivots/touches at) with
# moving_wall_outward_axis pointing away from moving_wall's body at that end;
# callers derive both by checking which end sits farther from the real
# attachment point, rather than assuming a fixed positive/negative mapping.
#
# target_wall_long_axis is target_wall's own long axis, from its own actual
# rotation - passed in directly rather than derived from moving_wall's
# outward axis, since that derivation only coincidentally matches for some
# wall pairs and not others.
#
# Three steps stack on top of moving_wall_outer_end:
#   - target_wall_size_z * 0.5, along moving_wall_outward_axis: target_wall's
#     own thickness, pushed out so its face (not its center) lands on the
#     endpoint instead of straddling back across it.
#   - target_wall_size_x * 0.5, along target_wall_long_axis's own (original,
#     unflipped) direction: the half-length step from that touching point to
#     target_wall's actual center.
#   - moving_wall_size_z * 0.5, along target_wall_long_axis's OPPOSITE
#     direction: corrects for moving_wall's own thickness - moving_wall_outer_end
#     sits on moving_wall's centerline, not its physical face, so this nudges
#     target_wall onto one actual face of moving_wall's footprint instead.
func _position_beyond_wall_end(reference_wall_outer_end: Vector3, reference_wall_outward_axis: Vector3, reference_wall_size_z: float, target_wall_long_axis: Vector3, target_wall_size_x: float, target_wall_size_z: float, use_positive: bool = false) -> Vector3:
	if use_positive:
		return reference_wall_outer_end \
			+ reference_wall_outward_axis * target_wall_size_z * 0.5 \
			- target_wall_long_axis * target_wall_size_x * 0.5 \
			- target_wall_long_axis * reference_wall_size_z * 0.5 \
			+ target_wall_long_axis * reference_wall_size_z
	return reference_wall_outer_end \
		+ reference_wall_outward_axis * target_wall_size_z * 0.5 \
		+ target_wall_long_axis * target_wall_size_x * 0.5 \
		- target_wall_long_axis * reference_wall_size_z * 0.5


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
	_add_current($WindCorridor3, WaterCurrent.Direction.NEGATIVE_Z)
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
	_setup_corridor_4_whirlpool()

# Corridor -> the two walls it sits between. Each corridor's collision box
# (its current's push zone) is kept centred between its pair: once after
# _setup_walls() (before _setup_currents(), so currents start in place) and
# then every physics frame, so if either wall is repositioned the corridor,
# the current in it, and Corridor4's whirlpool all move with it.
# WindCorridor3 is the passage between Box6 and Box7 (where the current
# starts, pushing -Z); WindCorridor4 is between Box12 and Box13 (+Z once the
# current is moved there).
var _corridor_walls: Dictionary = {}
var _corridor_4_whirlpool: Whirlpool

func _align_corridors_to_walls() -> void:
	for corridor in _corridor_walls:
		var walls: Array = _corridor_walls[corridor]
		var shape_node := _corridor_shape(corridor as Area3D)
		if shape_node == null:
			continue
		# Centred ACROSS the gap only - the corridor keeps its authored spot
		# along the passage (Box6/Box7 run 80 units, so centring lengthwise
		# would drag Corridor3 far from where it sits).
		var centre := _midpoint_between(walls[0], walls[1])
		var side := _wall_geometry(walls[0])["side_axis"] as Vector3
		side.y = 0.0
		var target := shape_node.global_position + side * (centre - shape_node.global_position).dot(side)
		if not shape_node.global_position.is_equal_approx(target):
			shape_node.global_position = target
	_place_corridor_4_whirlpool()

func _corridor_shape(corridor: Area3D) -> CollisionShape3D:
	for child in corridor.get_children():
		if child is CollisionShape3D:
			return child
	return null

# A whirlpool across the back of WindCorridor4: the north end of the stretch
# where its two walls face each other (Corridor4 pushes +Z, so north is the
# back). It swallows a diver and returns them to that stretch's south end -
# unless WindCorridor4 holds the current (V / R on the map), which carries
# the diver through it instead. Sized to the gap so it can't be swum around.
func _setup_corridor_4_whirlpool() -> void:
	var corridor := $WindCorridor4 as Area3D
	var walls: Array = _corridor_walls[corridor]
	var whirlpool := Whirlpool.new()
	whirlpool.suction_radius = _gap_width_between(walls[0], walls[1]) * 0.5 + 0.4
	whirlpool.warning_radius = whirlpool.suction_radius + 5.0
	whirlpool.bypass = func() -> bool: return _currents_by_corridor.has(corridor)
	whirlpool.warned.connect(_on_whirlpool_warned)
	whirlpool.diver_sucked_in.connect(_on_diver_sucked_in)
	add_child(whirlpool)
	_corridor_4_whirlpool = whirlpool
	_place_corridor_4_whirlpool()

func _place_corridor_4_whirlpool() -> void:
	if _corridor_4_whirlpool == null:
		return
	var walls: Array = _corridor_walls[$WindCorridor4]
	var ends := _overlap_ends_between(walls[0], walls[1])
	var back: Vector3 = ends[0] if ends[0].z > ends[1].z else ends[1]
	var start: Vector3 = ends[1] if ends[0].z > ends[1].z else ends[0]
	var into := (start - back).normalized()
	var floor_y: float = ($DiverEntry as Node3D).global_position.y
	var spot := back + into * (_corridor_4_whirlpool.suction_radius + 0.5)
	_corridor_4_whirlpool.global_position = Vector3(spot.x, floor_y, spot.z)
	var reset := start - into * 1.5
	_corridor_4_whirlpool.reset_to = Vector3(reset.x, floor_y, reset.z)

func _on_whirlpool_warned() -> void:
	# The whirlpool shows its own "Danger: Whirlpool ahead" caption while
	# the diver is within its warning radius (see whirlpool.gd).
	pass

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

# Puts the diver midway between two parallel walls (see _midpoint_between()).
# Keeps the diver's spawn height from $DiverEntry.
func _place_diver_between(wall_a: CSGBox3D, wall_b: CSGBox3D) -> void:
	if _diver == null:
		return
	var spot := _midpoint_between(wall_a, wall_b)
	spot.y = $DiverEntry.global_position.y
	_diver.global_position = spot

# The point midway between two parallel walls: halfway across the gap, and
# centred on the stretch where the two walls overlap lengthwise. y is
# wall_a's centre height.
func _midpoint_between(wall_a: CSGBox3D, wall_b: CSGBox3D) -> Vector3:
	var g_a: Dictionary = _wall_geometry(wall_a)
	var g_b: Dictionary = _wall_geometry(wall_b)
	var axis := g_a["long_axis"] as Vector3
	var origin := g_a["center"] as Vector3
	var a_lo := minf(((g_a["negative_end"] as Vector3) - origin).dot(axis), ((g_a["positive_end"] as Vector3) - origin).dot(axis))
	var a_hi := maxf(((g_a["negative_end"] as Vector3) - origin).dot(axis), ((g_a["positive_end"] as Vector3) - origin).dot(axis))
	var b_lo := minf(((g_b["negative_end"] as Vector3) - origin).dot(axis), ((g_b["positive_end"] as Vector3) - origin).dot(axis))
	var b_hi := maxf(((g_b["negative_end"] as Vector3) - origin).dot(axis), ((g_b["positive_end"] as Vector3) - origin).dot(axis))
	var along := (maxf(a_lo, b_lo) + minf(a_hi, b_hi)) * 0.5
	var side := g_a["side_axis"] as Vector3
	var across := ((g_b["center"] as Vector3) - origin).dot(side) * 0.5
	return origin + axis * along + side * across

# The two ends of the centreline running between two parallel walls, along
# the stretch where they overlap lengthwise (where they actually face each
# other). y is wall_a's centre height.
func _overlap_ends_between(wall_a: CSGBox3D, wall_b: CSGBox3D) -> Array[Vector3]:
	var g_a: Dictionary = _wall_geometry(wall_a)
	var g_b: Dictionary = _wall_geometry(wall_b)
	var axis := g_a["long_axis"] as Vector3
	var origin := g_a["center"] as Vector3
	var a1 := ((g_a["negative_end"] as Vector3) - origin).dot(axis)
	var a2 := ((g_a["positive_end"] as Vector3) - origin).dot(axis)
	var b1 := ((g_b["negative_end"] as Vector3) - origin).dot(axis)
	var b2 := ((g_b["positive_end"] as Vector3) - origin).dot(axis)
	var lo := maxf(minf(a1, a2), minf(b1, b2))
	var hi := minf(maxf(a1, a2), maxf(b1, b2))
	var side := g_a["side_axis"] as Vector3
	var across := ((g_b["center"] as Vector3) - origin).dot(side) * 0.5
	return [origin + axis * lo + side * across, origin + axis * hi + side * across]

# Open width between two parallel walls' facing surfaces.
func _gap_width_between(wall_a: CSGBox3D, wall_b: CSGBox3D) -> float:
	var side := _wall_geometry(wall_a)["side_axis"] as Vector3
	var separation := absf((wall_b.global_position - wall_a.global_position).dot(side))
	return separation - (wall_a.size.z + wall_b.size.z) * 0.5

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
	_align_corridors_to_walls()
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
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_H:
		_rotate_hallway_1_2()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_C:
		_toggle_current_1_to_2()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_V:
		_toggle_current_3_to_4()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_E:
		# MazeLevel is a standalone review scene, so World cannot forward its
		# normal ability input here. Keep the final relic interaction on the
		# same player-facing E key used elsewhere in the game.
		_diver.use_ability()
