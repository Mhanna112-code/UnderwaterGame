class_name MazeLevel
extends Node3D

# A wall's physical ends.  These names are intentionally kept at the API
# boundary: callers choose a named authored exit only when the level design
# explicitly requires one; automatic continuations never expose these signs.
enum WallEnd {
	NEGATIVE,
	POSITIVE,
}

# Developer mode: start the divers next to the strong-enemy room's switch
# box with the room's random encounters OFF (and skip the room's first-entry
# popup), for testing the switch minigame. Untick in the Inspector (or set
# false) for the normal start between CSGBox3D and CurrentWall3.
@export var dev_spawn_at_switch := false
# Developer mode: start the party in front of the secret boss room's door
# (Box30/32), for testing the boss rooms. Takes priority over the switch spawn.
@export var dev_spawn_at_boss_rooms := false
# Developer mode: start the party in the passage in front of the sphere
# room's door (wall 16), facing it. Takes priority over the other dev spawns.
@export var dev_spawn_at_sphere_room := true
# Developer mode: start with every key and the switch gate already down. The
# secret room's rocks (and everything else) can still be collected as usual.
# Also on when launched with "-- --dev" on the command line.
@export var dev_all_keys_gate_open := false

var markers: Array[Marker3D] = []

# Every scene-authored CSGBox3D wall, read live by maze_mini_map.gd each
# frame rather than baked into fixed [start, end] segments the way
# World._build_wall() does for _wall_segments - CurrentWall1/CurrentWall2
# actually swing open (see swing_hallway()), so a one-time bake would go
# stale the moment that happens. Keeping the node references and
# recomputing each box's own centerline from its CURRENT global_transform
# every draw call is what keeps the radar honest through that swing.
var wall_boxes: Array[CSGBox3D] = []

# WindCorridor1..8 - whichever of them the scene has (7 and 8 are optional).
@onready var corridors: Array[Area3D] = _collect_corridors()

func _collect_corridors() -> Array[Area3D]:
	var out: Array[Area3D] = []
	for i in range(1, 9):
		var a := get_node_or_null("WindCorridor%d" % i) as Area3D
		if a != null:
			out.append(a)
	var break_rock := get_node_or_null("WindCorridorBreakRock") as Area3D
	if break_rock != null:
		out.append(break_rock)
	return out


func _ready() -> void:
	_embed_shift()
	_clear_dome_site()
	for child in get_children():
		if child is Marker3D:
			markers.append(child)
		elif child is CSGBox3D:
			wall_boxes.append(child)
	_normalize_wall_heights()
	# Before _setup_walls(): wall placement can reposition _diver (see
	# _place_wall_straight_to_reference()), which needs it to exist already.
	_spawn_divers()
	_build_target_selector()
	_setup_walls()
	# After _setup_walls() so it uses both walls' placed positions (and
	# overrides any debug move of the diver during wall placement). Part of
	# the world, the divers are the world's and stay where they are.
	if world == null:
		_place_diver_between($CSGBox3D, $CurrentWall3)
		if dev_spawn_at_sphere_room:
			_dev_spawn_at_sphere_room()
		elif dev_spawn_at_boss_rooms:
			_dev_spawn_at_boss_rooms()
		elif dev_spawn_at_switch:
			_dev_spawn_at_switch()
	_corridor_walls = {
		$WindCorridor3: [$CSGBox3D6, $CSGBox3D7],
		$WindCorridor4: [$CSGBox3D12, $CSGBox3D13],
		$WindCorridor5: [$CSGBox3D8, $CSGBox3D9],
		$WindCorridor6: [$CSGBox3D10, $CSGBox3D11],
	}
	if has_node("WindCorridor7") and has_node("CSGBox3D20") and has_node("CSGBox3D21"):
		_corridor_walls[$WindCorridor7] = [$CSGBox3D20, $CSGBox3D21]
		_corridors_centred_lengthwise.append($WindCorridor7)
	# Corridor8: centred between walls 23 and 20 the same way.
	if has_node("WindCorridor8") and has_node("CSGBox3D23") and has_node("CSGBox3D20"):
		_corridor_walls[$WindCorridor8] = [$CSGBox3D23, $CSGBox3D20]
		_corridors_centred_lengthwise.append($WindCorridor8)
	_align_corridors_to_walls()
	_line_up_c4_and_break_rock()
	_setup_currents()
	_setup_whirlpool()
	_build_rotate_prompt()
	_build_floor()
	_build_perimeter_walls()
	_build_ceiling()
	_build_lever_dome()
	_build_minimap()
	_build_world_hud()
	_build_item_rocks()
	_build_state_barriers()
	_build_area_9_11_13_barrier()
	_build_start_area_barriers()
	_build_progress_gate()
	_build_split_rock()
	_build_wall_10_11_extras()
	_build_hall_gauntlet()
	_build_inventory_menu()
	_build_tutorial_book()
	_build_special_encounters()
	_build_visible_floors()
	_carve_hall_whirlpool_holes()
	_build_secret_wall_entrance()
	_build_save_points()
	_add_wall_skirts()
	if dev_all_keys_gate_open or OS.get_cmdline_user_args().has("--dev"):
		_apply_dev_unlocks()
	$HUD/Controls.text = "Hallway: CLOSED — open the map (L), pick the hallway walls and press E."
	if SceneHandoff.returning_from_secret_wall:
		SceneHandoff.returning_from_secret_wall = false
		_place_divers_at_secret_entrance()
	if world != null:
		_finish_embedding()

# --- Part of the open world ------------------------------------------------------
# World builds the maze into its own scene, east past the blockade exit,
# rather than it being a level of its own. Everything the maze authored is
# shifted by `embed_offset` before anything else is built (so the maze's own
# root stays at the origin and every global position in this file still
# means what it says), its light and environment give way to World's, and it
# runs on World's divers, items and keys. While the active diver is out in
# the open water World is in charge; once they swim inside the maze's bounds
# World hands over (enter_from_world()) and the maze runs everything - its
# camera, HUD, input, battles - until they swim back out (leave_to_world()).
var world: Node = null
var embed_offset := Vector3.ZERO
const EMBED_PASSAGE_HALF_WIDTH := 4.0   # the way in through the west perimeter
var _embed_bounds := Rect2()   # x/z inside the maze's perimeter walls
var maze_active := true

func _embed_shift() -> void:
	if world == null:
		return
	for child in get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			remove_child(child)
			child.queue_free()
		elif child is Node3D:
			(child as Node3D).position += embed_offset

func _finish_embedding() -> void:
	var points := _collect_bounds_points()
	var lo: Vector3 = points[0]
	var hi: Vector3 = points[0]
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	_embed_bounds = Rect2(lo.x - _PERIMETER_MARGIN, lo.z - _PERIMETER_MARGIN, hi.x - lo.x + _PERIMETER_MARGIN * 2.0, hi.z - lo.z + _PERIMETER_MARGIN * 2.0)
	SceneHandoff.embedded_maze = self
	_set_maze_active(false)

# Where the world's way in meets the maze: the open water just west of the
# start corridor, on its line.
func entrance_point() -> Vector3:
	return ($DiverEntry as Node3D).global_position

# The underside of the maze's main invisible ceiling (see _build_ceiling()).
func ceiling_bottom_y() -> float:
	var wall_a := $CurrentWall1 as CSGBox3D
	return wall_a.position.y + wall_a.size.y * 0.5 + _CEILING_CLEARANCE

func contains_point(p: Vector3) -> bool:
	return _embed_bounds.has_point(Vector2(p.x, p.z))

func _set_maze_active(on: bool) -> void:
	maze_active = on
	set_physics_process(on)
	set_process_unhandled_input(on)
	set_process_input(on)
	$HUD.visible = on
	$HUD.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	($Camera3D as Camera3D).current = on

# World -> maze: same diver, same view, same encounter setting.
func enter_from_world(world_active: int, yaw: float, pitch: float, mouse_look: bool, cam_xf: Transform3D, encounters: bool) -> void:
	active = world_active
	_diver = divers[active]
	_yaw = yaw
	_pitch = pitch
	_mouse_look = mouse_look
	($Camera3D as Camera3D).global_transform = cam_xf
	_cam_look = Vector3.ZERO
	_cutscene_return = 0.0
	random_encounters_enabled = encounters
	_set_maze_active(true)

# Maze -> world: hands back what World needs to carry on seamlessly.
func leave_to_world() -> Dictionary:
	if _aiming:
		_cancel_aim()
	if target_selector != null and target_selector.selecting:
		target_selector.cancel_selection()
	var state := {
		"active": active, "yaw": _yaw, "pitch": _pitch, "mouse_look": _mouse_look,
		"cam_xf": ($Camera3D as Camera3D).global_transform,
		"encounters": random_encounters_enabled,
	}
	_set_maze_active(false)
	return state

# Reward rocks scattered through the maze - the same disguised-as-scenery
# CrackedWall world.gd's own _build_breakable_rocks() spawns at a hardcoded
# position list, just placed at whichever Marker3D nodes are tagged
# "ItemRock" in THIS scene instead - adding another one is tagging another
# marker with that group, not editing code.
func _build_item_rocks() -> void:
	_build_secret_item_rocks()
	for node in get_tree().get_nodes_in_group("ItemRock"):
		var marker := node as Node3D
		if marker == null:
			continue
		var rock := CrackedWall.new()
		rock.span = Vector3(1.1, 1.1, 1.1)
		# Round, like every rock in the secret item room.
		rock.disguised_as_scenery_rock = true
		rock.position = marker.global_position
		rock.broken.connect(_on_item_rock_broken.bind(marker.name, marker.global_position))
		add_child(rock)
		_secret_room_rocks.append(rock)

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

# `marker_name`/`spot` are the broken ItemRock's own name and position,
# bound at connect time in _build_item_rocks() - a real drop table would
# vary by which one broke (see world.gd's own Items/ItemOrb pipeline for
# what that looks like for real; this standalone test scene has none of
# that, so every ItemRock just drops the same orb for now).
func _on_item_rock_broken(marker_name: String, spot: Vector3) -> void:
	_note_broken_rock(spot)
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
	if not key_items.has("ancient_relic"):
		key_items.append("ancient_relic")
	# Like every other secret-room find: just the normal orange text.
	_announce("You've acquired the Ancient Relic.")
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
	_build_strong_enemy_room_walls()
	_build_wall_15_to_reward()
	_build_wall_7_to_reward()
	_build_room_switch()
	_build_posters()
	_settle_dome_site()
	_rebuild_wall_17_27()
	_split_wall_16()
	_build_maze_doors()
	_build_sphere_room()
	_build_main_boss_room()
	_build_boss_triggers()
	_build_vortex_chest()
	_build_sonar_vision_pickup()
	_build_path_button()

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
	# Exactly north-south like Box11 (authored -89.771 degrees, a little skew).
	($CSGBox3D10 as CSGBox3D).rotation.y = -PI * 0.5
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


# --- Strong-enemy room ---------------------------------------------------
# Bounded by RewardChamberWestWall (north), CSGBox3D28 (east), and two big
# walls built here: RoomWallA runs south from RewardChamberWestWall's centre,
# RoomWallB runs east from RoomWallA's far end to the top of CSGBox3D11, along
# CSGBox3D14's line. Both match RewardChamberWestWall's height/thickness; their
# lengths are whatever reaches those walls. CSGBox3D14 closes the rest of the
# south side until J / E-on-the-map swings 14 and 15 open (see
# _rotate_walls_14_15()), which is how you get in.
const STRONG_ROOM_WARNING := "Warning: strong enemies detected nearby"
var _room_wall_a: CSGBox3D
var _room_wall_b: CSGBox3D
var _room_warning: Label
var _walls_14_15_open := false
var _walls_14_15_home: Array = []   # [[wall, position, yaw], ...]

func _build_strong_enemy_room_walls() -> void:
	var west_wall := $RewardChamberWestWall as CSGBox3D
	var box14 := $CSGBox3D14 as CSGBox3D
	var box11 := $CSGBox3D11 as CSGBox3D
	var height := west_wall.size.y
	var thickness := west_wall.size.z
	var bottom := west_wall.global_position.y - height * 0.5
	var mid_y := bottom + height * 0.5
	var north_face_z := west_wall.global_position.z - thickness * 0.5
	var line_z := box14.global_position.z
	# A: from RewardChamberWestWall's south face down past Box14's line.
	var a_x := west_wall.global_position.x
	var a_south := line_z - thickness * 0.5
	var a_length := north_face_z - a_south
	_room_wall_a = _spawn_wall("RoomWallA", Vector3(a_x, mid_y, (north_face_z + a_south) * 0.5), PI * 0.5, Vector3(a_length, height, thickness))
	wall_boxes.append(_room_wall_a)
	# B: from A's west face east to Box11's west face, on Box14's line.
	var b_west := a_x - thickness * 0.5
	var b_east := box11.global_position.x - box11.size.z * 0.5
	_room_wall_b = _spawn_wall("RoomWallB", Vector3((b_west + b_east) * 0.5, mid_y, line_z), 0.0, Vector3(b_east - b_west, height, thickness))
	wall_boxes.append(_room_wall_b)

# Swings CSGBox3D14 and CSGBox3D15 a quarter turn about their west ends so
# they point +Z, ending in a straight line with the walls they meet there:
# 14 continues CSGBox3D11's line, 15 continues CSGBox3D10's. That opens the
# strong-enemy room's south side. Toggles back; ignored while still moving.
func _rotate_walls_14_15() -> void:
	if _wall_set_moving("CSGBox3D14/15"):
		return
	var tweens: Array = []
	if _walls_14_15_open:
		for entry in _walls_14_15_home:
			tweens.append(_tween_wall_to_transform_about_hinge(entry[0], entry[1], entry[2]))
		_walls_14_15_open = false
		_track_wall_set_motion("CSGBox3D14/15", tweens, [$CSGBox3D14, $CSGBox3D15])
		$HUD/Controls.text = "Walls 14/15 closing..."
		_update_state_barriers()
		return
	_walls_14_15_home.clear()
	for pair in [[$CSGBox3D14, _wall_11_joint], [$CSGBox3D15, _wall_10_joint]]:
		var w := pair[0] as CSGBox3D
		var joint := pair[1] as Vector3
		_walls_14_15_home.append([w, w.global_position, w.rotation.y])
		# Straight on from wall 11's / 10's north end, running +Z for this
		# wall's own length - end to end with it, no gap.
		var target := Vector3(joint.x, w.global_position.y, joint.z + w.size.x * 0.5)
		tweens.append(_tween_wall_to_transform_about_hinge(w, target, -PI * 0.5))
	_walls_14_15_open = true
	_track_wall_set_motion("CSGBox3D14/15", tweens, [$CSGBox3D14, $CSGBox3D15])
	$HUD/Controls.text = "Walls 14/15 opening..."
	_update_state_barriers()

# A wall continuing CSGBox3D15's line once J swings it open (along
# CSGBox3D10's line, north from where 15's far end lands) up to
# RewardChamberWestWall's line, closing the gap between the two. It stands
# there whether or not 15 is swung. Same height/thickness as 15.
func _build_wall_15_to_reward() -> void:
	var w15 := $CSGBox3D15 as CSGBox3D
	var line_wall := $CSGBox3D10 as CSGBox3D
	var reward := $RewardChamberWestWall as CSGBox3D
	var g15: Dictionary = _wall_geometry(w15)
	var west_end: Vector3 = g15["negative_end"] if (g15["negative_end"] as Vector3).x < (g15["positive_end"] as Vector3).x else g15["positive_end"]
	var start_z := west_end.z + w15.size.x   # where swung 15's far end lands
	var end_z := reward.global_position.z
	var wall := _spawn_wall("Wall15ToReward", Vector3(line_wall.global_position.x, w15.global_position.y, (start_z + end_z) * 0.5), PI * 0.5, Vector3(absf(end_z - start_z), w15.size.y, w15.size.z))
	wall_boxes.append(wall)

# A wall on RewardChamberWestWall's line from CSGBox3D7's east face to
# RewardChamberWestWall's west end, closing the open water between them.
# Same height/thickness as Box7.
func _build_wall_7_to_reward() -> void:
	var w7 := $CSGBox3D7 as CSGBox3D
	var reward := $RewardChamberWestWall as CSGBox3D
	var g: Dictionary = _wall_geometry(reward)
	var west_x := minf((g["negative_end"] as Vector3).x, (g["positive_end"] as Vector3).x)
	var start_x := w7.global_position.x + w7.size.z * 0.5
	var wall := _spawn_wall("Wall7ToReward", Vector3((start_x + west_x) * 0.5, w7.global_position.y, reward.global_position.z), 0.0, Vector3(absf(west_x - start_x), w7.size.y, w7.size.z))
	wall_boxes.append(wall)

# The room's interior on the floor plan, between the facing sides of its
# four walls.
func _strong_room_rect() -> Rect2:
	if _room_wall_a == null:
		return Rect2()
	# East edge: CSGBox3D28 if the scene still has it, otherwise the
	# Box27/Box17 line.
	var east := get_node_or_null("CSGBox3D28") as CSGBox3D
	if east == null:
		east = $CSGBox3D27 as CSGBox3D
	var west_wall := $RewardChamberWestWall as CSGBox3D
	var x0 := _room_wall_a.global_position.x + _room_wall_a.size.z * 0.5
	var x1 := east.global_position.x - east.size.z * 0.5
	var z0 := _room_wall_b.global_position.z + _room_wall_b.size.z * 0.5
	var z1 := west_wall.global_position.z - west_wall.size.z * 0.5
	return Rect2(Vector2(x0, z0), Vector2(x1 - x0, z1 - z0))

# For the maps: the strong encounter zone's floor, once the diver has been
# inside it for the first time. Empty Rect2 = not yet.
func strong_zone_for_map(_revealed_walls: Dictionary) -> Rect2:
	if not _strong_room_seen:
		return Rect2()
	return _strong_room_rect()

func is_diver_in_strong_room() -> bool:
	if _diver == null:
		return false
	return _strong_room_rect().has_point(Vector2(_diver.global_position.x, _diver.global_position.z))

# Orange bottom-centre caption (same style as the whirlpool warning, one line
# above it), shown for as long as the diver is inside the room.
func _update_strong_room_warning() -> void:
	var inside := is_diver_in_strong_room()
	if inside and not _strong_room_seen:
		_strong_room_seen = true
		var popup := get_node_or_null("/root/CharacterAbilityPopup")
		if popup != null:
			var pages: Array[Dictionary] = [{
				"title": "Strong enemy encounters",
				"body": "For certain areas in the game with stronger enemies, random encounters can't be turned off. The stronger encounter zone is flashing in red on the map.",
				"slot": null,
				"media_control": func() -> Control: return StrongZoneDemoClip.new(),
			}]
			popup.call("open", pages)
	_update_encounter_status(inside)
	if _room_warning == null:
		if not inside:
			return
		_room_warning = Label.new()
		_room_warning.text = STRONG_ROOM_WARNING
		_room_warning.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_room_warning.offset_left = -320.0
		_room_warning.offset_right = 320.0
		_room_warning.offset_top = -250.0
		_room_warning.offset_bottom = -212.0
		_room_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_room_warning.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_room_warning.add_theme_font_size_override("font_size", 20)
		_room_warning.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
		_room_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$HUD.add_child(_room_warning)
	# Shown on the way in, then fades - the red zone on the maps stays as the
	# reminder. Each new entry shows it again.
	if inside and not _was_in_strong_room:
		if _room_warning_fade != null:
			_room_warning_fade.kill()
		_room_warning.visible = true
		_room_warning.modulate.a = 1.0
		_room_warning_fade = create_tween()
		_room_warning_fade.tween_interval(2.5)
		_room_warning_fade.tween_property(_room_warning, "modulate:a", 0.0, 1.5)
		_room_warning_fade.tween_callback(func() -> void: _room_warning.visible = false)
	elif not inside:
		_room_warning.visible = false
	_was_in_strong_room = inside

var _was_in_strong_room := false
var _room_warning_fade: Tween

# --- Announcements (World's orange banner) -------------------------------
var _banner: Label
var _banner_timer := 0.0

# Set when E on something brings up orange text: until that text is gone,
# the white "Press E to interact" stays hidden and E interacts with nothing.
var _interact_cooldown := false

func _announce(text: String, seconds := 4.0) -> void:
	if _banner == null:
		_banner = _make_caption(-170.0, -130.0, 20, Color(1.0, 0.6, 0.45))
	_banner.text = text
	_banner.visible = true
	_banner_timer = seconds

func _update_announce(dt: float) -> void:
	if _banner == null or _banner_timer <= 0.0:
		return
	_banner_timer -= dt
	if _banner_timer <= 0.0:
		_banner.visible = false

func _make_caption(top: float, bottom: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -320.0
	label.offset_right = 320.0
	label.offset_top = top
	label.offset_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	$HUD.add_child(label)
	return label

# --- Random encounters (strong-enemy room only) ---------------------------
# Every diver rolls for encounters as it swims (Diver.check_for_encounter());
# here only the active diver's rolls inside the strong-enemy room start a
# battle. In the real game these can't be turned off in that room - the
# room switch (_toggle_room_encounters()) is a developer toggle for testing.
# Enemies are ordinary encounter enemies with each stat except evasion
# boosted by a random 5-15%.
const ENEMY_BOOST_MIN := 1.05
const ENEMY_BOOST_MAX := 1.15
const BOOSTED_STATS := ["hp_max", "strength", "defense", "agility", "accuracy"]
var room_encounters_enabled := true
# R, as in the main game: ordinary random encounters everywhere else in the
# maze. Shared with World's own switch when the maze is part of the world.
var random_encounters_enabled := true
var _strong_room_seen := false
var _battling := false
var _battle: Battle
var _encounter_status: Label

func _on_diver_encounter(d: Diver) -> void:
	if _battling or any_modal_open() or d != _diver:
		return
	if is_diver_in_strong_room():
		if room_encounters_enabled:
			_start_battle()
	elif random_encounters_enabled:
		_start_battle("ordinary")

func _toggle_random_encounters() -> void:
	if is_diver_in_strong_room():
		return   # forced on in the danger zone - the HUD hint is greyed out
	random_encounters_enabled = not random_encounters_enabled
	_announce("Random encounters on." if random_encounters_enabled else "Random encounters off.")

# kind: "strong" (the strong-enemy room's random encounters), "secret_boss"
# or "main_boss".
func _start_battle(kind := "strong") -> void:
	_battling = true
	_battle_kind = kind
	for d in divers:
		d.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	_battle = Battle.new()
	match kind:
		"secret_boss":
			_announce("Tethys turns toward you!")
			_battle.boss_encounter = true
		"main_boss":
			_announce("Tethys rises from the deep!")
			_battle.boss_encounter = true
		"ambush":
			_announce("Something was hiding in the rock!")
		"special":
			pass   # no banner - the combat text says the enemy is carrying an item
		"ordinary":
			pass   # an ordinary encounter, as in the open world - no banner
		_:
			_announce("Strong enemies emerge from the murk!")
	_battle.party_source = divers
	if kind == "special" and _special_spot != null:
		# The world's special encounter: just the chosen diver, against the
		# spot's guardian, playing that diver's special-encounter minigame.
		_battle.party_source = [_special_diver]
		_battle.special_encounter = true
		_battle.guardian_encounter = true
		_battle.guardian_enemy_id = String(_special_spot.get_meta("enemy"))
	_battle.inventory_source = inventory
	_battle.finished.connect(_on_battle_finished)
	add_child(_battle)
	if kind == "strong" or kind == "ambush":
		_boost_enemies(_battle)

func _boost_enemies(battle: Battle, boost_min := ENEMY_BOOST_MIN, boost_max := ENEMY_BOOST_MAX) -> void:
	for entry in battle.enemies:
		var stats := (entry as Dictionary).get("stats") as CombatantStats
		if stats == null:
			continue
		for field in BOOSTED_STATS:
			var base := int(stats.get(field))
			if base <= 0:
				continue
			# Whole numbers, never more than the maximum boost: a small stat
			# with no whole number inside the range (3 can't go up by 5-15%)
			# stays as it is rather than being rounded up past the maximum.
			var hi := maxi(base, floori(base * boost_max))
			var lo := clampi(ceili(base * boost_min), base, hi)
			stats.set(field, clampi(roundi(base * randf_range(boost_min, boost_max)), lo, hi))
		stats.hp = stats.hp_max
	battle._refresh_all_bars()

func _on_battle_finished(result: String) -> void:
	_battle.queue_free()
	_battle = null
	_battling = false
	# Divers knocked out in a fight the party won stay down (0 HP): they sit
	# out later fights until a potion or a revive brings them back.
	var kind := _battle_kind
	_battle_kind = "strong"
	if kind == "special":
		_finish_special_encounter(result)
		return
	if result == "won" and kind == "secret_boss":
		_remove_boss_trigger("secret_boss")
		_gain_key("abyss_key", "Tethys is driven off! You've obtained a key")
		return
	if result == "won" and kind == "main_boss":
		_remove_boss_trigger("main_boss")
		_announce("Tethys is defeated!", 6.0)
		return
	match result:
		"won":
			_announce("The enemies were defeated." if kind == "ordinary" else "The strong enemies were defeated.")
		"fled":
			_announce("You escaped.")
		_:
			# No game-over screen in this standalone level: the party is
			# restored and sent back to the maze entrance.
			for d in divers:
				d.stats.hp = d.stats.hp_max
				d.stats.oxygen = d.stats.oxygen_max
			_place_diver_between($CSGBox3D, $CurrentWall3)
			_announce("The party was overwhelmed and swam back to the entrance.")

func _remove_boss_trigger(kind: String) -> void:
	var trigger: Node = _boss_triggers.get(kind, null)
	if trigger != null and is_instance_valid(trigger):
		trigger.queue_free()
	_boss_triggers.erase(kind)

# Grey line shown while in the room: encounters are forced on there; the
# developer switch is the only way to change that (and says so).
func _update_encounter_status(inside: bool) -> void:
	if _encounter_status == null:
		if not inside:
			return
		_encounter_status = _make_caption(-90.0, -62.0, 15, Color(0.6, 0.62, 0.65))
	_encounter_status.visible = inside
	_encounter_status.text = "Random encounters: ON (can't be turned off here)" if room_encounters_enabled else "Random encounters: OFF (developer switch)"

# --- Room switch (developer toggle) ---------------------------------------
# A black box with a blinking red light at the -X end of CSGBox3D19, on the
# room side. Standing next to it shows "Press E to interact"; E opens the
# switch minigame modal (SwitchMinigameModal), and Shift+E is the developer
# toggle for the room's random encounters.
const SWITCH_REACH := 2.0
var _switch_node: StaticBody3D
var _switch_prompt: Label

func _build_room_switch() -> void:
	var box19 := $CSGBox3D19 as CSGBox3D
	var g: Dictionary = _wall_geometry(box19)
	var west_end: Vector3 = g["negative_end"] if (g["negative_end"] as Vector3).x < (g["positive_end"] as Vector3).x else g["positive_end"]
	var floor_y: float = box19.global_position.y - box19.size.y * 0.5
	var size := Vector3(0.9, 1.2, 0.9)
	_switch_node = StaticBody3D.new()
	_switch_node.name = "RoomSwitch"
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.02)
	mesh.material_override = mat
	_switch_node.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	_switch_node.add_child(shape)
	var light_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	light_mesh.mesh = sphere
	var light_mat := StandardMaterial3D.new()
	light_mat.albedo_color = Color(1.0, 0.1, 0.1)
	light_mat.emission_enabled = true
	light_mat.emission = Color(1.0, 0.1, 0.1)
	light_mat.emission_energy_multiplier = 3.0
	light_mesh.material_override = light_mat
	light_mesh.position = Vector3(0, size.y * 0.5 + 0.12, 0)
	_switch_node.add_child(light_mesh)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.15, 0.15)
	glow.omni_range = 3.0
	glow.light_energy = 1.5
	glow.position = light_mesh.position
	_switch_node.add_child(glow)
	add_child(_switch_node)
	# Just off Box19's west end, against its south (room) face.
	var south := -(g["side_axis"] as Vector3) if (g["side_axis"] as Vector3).z > 0.0 else (g["side_axis"] as Vector3)
	var spot := west_end + Vector3(-size.x * 0.5, 0, 0) + south * (box19.size.z * 0.5 + size.z * 0.5)
	_switch_node.global_position = Vector3(spot.x, floor_y + size.y * 0.5, spot.z)
	var blink := create_tween().set_loops()
	blink.tween_callback(func() -> void:
		light_mesh.visible = not light_mesh.visible
		glow.visible = light_mesh.visible)
	blink.tween_interval(0.5)
	_switch_blink = blink
	_switch_light = [light_mesh, light_mat, glow]

# The switch is done once its puzzle is solved: the light stops blinking and
# stays green, and E there no longer opens the puzzle.
var _switch_blink: Tween
var _switch_light: Array = []   # [light mesh, its material, its glow]

func _switch_puzzle_done() -> bool:
	return _gate_lowered

func _mark_switch_done() -> void:
	if _switch_blink != null:
		_switch_blink.kill()
	if _switch_light.size() == 3:
		var green := Color(0.2, 1.0, 0.35)
		(_switch_light[0] as MeshInstance3D).visible = true
		(_switch_light[1] as StandardMaterial3D).albedo_color = green
		(_switch_light[1] as StandardMaterial3D).emission = green
		(_switch_light[2] as OmniLight3D).visible = true
		(_switch_light[2] as OmniLight3D).light_color = green

# Puts the active diver just in front of the switch box (inside its
# "Press E" reach) with the other two either side of it, and turns the
# room's encounters off. See dev_spawn_at_switch.
func _dev_spawn_at_switch() -> void:
	room_encounters_enabled = false
	_strong_room_seen = true
	var front := _switch_node.global_position + Vector3(0, 0, -1.6)
	front.y = $DiverEntry.global_position.y
	var offsets := [0.0, -2.5, 2.5]
	for i in range(divers.size()):
		var slot: int = (i - active + divers.size()) % divers.size()
		divers[i].global_position = front + Vector3(float(offsets[slot]), 0, 0)

func _diver_near_switch() -> bool:
	if _switch_node == null or _diver == null:
		return false
	var a := _switch_node.global_position
	var b := _diver.global_position
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) <= SWITCH_REACH

# White "Press E to interact" just below the banner, while next to it.
func _update_room_switch() -> void:
	var poster := _poster_in_reach()
	if not _poster_beats_switch(poster):
		poster = null
	for p in _posters:
		p.set_highlight(p == poster)
	var near := (_diver_near_switch() and not _switch_puzzle_done()) or poster != null or (_free_lever_in_reach() != null and _lever_held_by(_diver) == null) or _path_button_in_reach() or _vortex_chest_in_reach() or _split_rock_in_reach()
	if _interact_cooldown and (_banner == null or _banner_timer <= 0.0):
		_interact_cooldown = false
	if _interact_cooldown:
		near = false
	if _switch_prompt == null:
		if not near:
			return
		_switch_prompt = _make_caption(-128.0, -96.0, 18, Color(1, 1, 1))
		_switch_prompt.text = "Press E to interact"
	_switch_prompt.visible = near

var _switch_modal: SwitchMinigameModal

# --- Wall posters -----------------------------------------------------------
# A wall caps the north end of the CurrentWall1/2 hallway (between the two
# walls' ends), with a poster on its hallway side; a second poster hangs on
# the west face of CSGBox3DConnector, the wall spawned on Box13's line, on
# the stretch north of Box13. Each shows a different random diver and has a
# different number 1-3 (poster_clues). In reach: "Press E to interact" and
# the poster lights up; E opens it as a PosterModal.
const POSTER_REACH := 2.0
const POSTER_CENTER_HEIGHT := 1.7   # above the diver's swim height
var _posters: Array[MazePoster] = []
var _poster_modal: PosterModal
var poster_clues: Array[Dictionary] = []   # [{"diver": index, "number": n}, ...]

func _build_posters() -> void:
	var end_wall := _build_hallway_1_2_end_wall()
	var divers_order := [0, 1, 2]
	divers_order.shuffle()
	var numbers := [1, 2, 3]
	numbers.shuffle()
	var spots := [
		_poster_spot_on(end_wall, Vector3(0, 0, -1), 0.5),
		_poster_spot_on($CSGBox3DConnector as CSGBox3D, Vector3(-1, 0, 0), _connector_free_stretch_t()),
		_switch_poster_spot(),
	]
	for i in spots.size():
		var poster := MazePoster.new()
		poster.name = "Poster%d" % (i + 1)
		poster.setup(divers_order[i], numbers[i])
		add_child(poster)
		var spot: Array = spots[i]
		poster.global_position = spot[0]
		poster.global_basis = Basis.looking_at(-(spot[1] as Vector3), Vector3.UP)
		_posters.append(poster)
		poster_clues.append({"diver": divers_order[i], "number": numbers[i]})

# The wall across the north end of the CurrentWall1/2 hallway: from
# CurrentWall1's outer face to CurrentWall2's, its south face level with the
# nearer of the two walls' north ends (so it caps both). Same height as them.
func _build_hallway_1_2_end_wall() -> CSGBox3D:
	var w1 := $CurrentWall1 as CSGBox3D
	var w2 := $CurrentWall2 as CSGBox3D
	var g1: Dictionary = _wall_geometry(w1)
	var g2: Dictionary = _wall_geometry(w2)
	var north1 := maxf((g1["negative_end"] as Vector3).z, (g1["positive_end"] as Vector3).z)
	var north2 := maxf((g2["negative_end"] as Vector3).z, (g2["positive_end"] as Vector3).z)
	var thickness := w1.size.z
	var x0 := minf(w1.global_position.x, w2.global_position.x) - thickness * 0.5
	var x1 := maxf(w1.global_position.x, w2.global_position.x) + w2.size.z * 0.5
	var south_z := minf(north1, north2)
	var wall := _spawn_wall("HallwayEndWall", Vector3((x0 + x1) * 0.5, w1.global_position.y, south_z + thickness * 0.5), 0.0, Vector3(x1 - x0, w1.size.y, thickness))
	wall_boxes.append(wall)
	return wall

# How far along CSGBox3DConnector (0 = its negative end, 1 = positive) the
# middle of its stretch beyond Box13 lies - the part with open water on its
# west side.
func _connector_free_stretch_t() -> float:
	var connector := $CSGBox3DConnector as CSGBox3D
	var gc: Dictionary = _wall_geometry(connector)
	var g13: Dictionary = _wall_geometry($CSGBox3D13 as CSGBox3D)
	var neg := gc["negative_end"] as Vector3
	var axis := gc["long_axis"] as Vector3
	var box13_far := maxf(((g13["negative_end"] as Vector3) - neg).dot(axis), ((g13["positive_end"] as Vector3) - neg).dot(axis))
	return (box13_far + connector.size.x) * 0.5 / connector.size.x

# [position, outward normal] for a poster on `wall`'s face pointing toward
# `toward`, `t` of the way along it (0 = negative end, 1 = positive end).
func _poster_spot_on(wall: CSGBox3D, toward: Vector3, t: float) -> Array:
	var g: Dictionary = _wall_geometry(wall)
	var side := g["side_axis"] as Vector3
	var normal := side if side.dot(toward) > 0.0 else -side
	var along := (g["negative_end"] as Vector3).lerp(g["positive_end"] as Vector3, t)
	var pos := along + normal * (wall.size.z * 0.5 + 0.03)
	pos.y = ($DiverEntry as Node3D).global_position.y + POSTER_CENTER_HEIGHT
	return [pos, normal]

# The poster beside the switch is close enough that both can be in reach:
# whichever is nearer to the diver is the one E (and the highlight) goes to.
func _poster_beats_switch(poster: MazePoster) -> bool:
	if poster == null:
		return false
	if not _diver_near_switch() or _switch_puzzle_done():
		return true
	var to_poster := poster.global_position - _diver.global_position
	var to_switch := _switch_node.global_position - _diver.global_position
	to_poster.y = 0.0
	to_switch.y = 0.0
	return to_poster.length() < to_switch.length()

# The poster the active diver is within reach of, in front of it; or null.
func _poster_in_reach() -> MazePoster:
	if _diver == null:
		return null
	for p in _posters:
		var offset := _diver.global_position - p.global_position
		offset.y = 0.0
		if offset.length() <= POSTER_REACH and offset.dot(p.facing()) > 0.0:
			return p
	return null

func poster_modal_open() -> bool:
	return _poster_modal != null and is_instance_valid(_poster_modal)

func any_modal_open() -> bool:
	return (save_point_menu != null and save_point_menu.visible) or (inventory_menu != null and inventory_menu.visible) or switch_modal_open() or poster_modal_open() or (_tethys_prompt != null and is_instance_valid(_tethys_prompt)) or (_draft_prompt != null and is_instance_valid(_draft_prompt))

func _open_poster(poster: MazePoster) -> void:
	if any_modal_open():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	poster.mark_seen()
	_poster_modal = PosterModal.new(poster)
	add_child(_poster_modal)

# Mouse press positions while the modal is open, recorded by _input():
# where the latest press started, and whether it started on the modal.
var modal_press_start := Vector2.ZERO
var modal_press_started_inside := false

# While the switch modal is open the maze freezes like it does in battle:
# divers don't swim, no encounters, and map/maze keys are ignored.
func switch_modal_open() -> bool:
	return _switch_modal != null and is_instance_valid(_switch_modal)

# The first time the switch is used, an explainer (text and a looping demo
# clip) comes up first; the minigame opens once it's closed.
var _switch_explained := false

func _open_switch_minigame() -> void:
	if any_modal_open():
		return
	var popup := get_node_or_null("/root/CharacterAbilityPopup")
	if not _switch_explained and popup != null:
		_switch_explained = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_look = false
		var demo_textures: Array = [null, null, null]
		for p in _posters:
			demo_textures[p.diver_index] = p.portrait
		var pages: Array[Dictionary] = [{
			"title": "Portrait Puzzle",
			"body": "The diver portraits are in the wrong lanes (labeled 1-3 at the bottom of the lanes). Left click to draw lines underneath the falling portraits to move them over to the other lanes where they correctly need to be placed. A portrait only follows a line over if the line was started in the lane it's falling down (the arrow shows which way a line goes). The lines don't have to be perfectly straight - they snap straight across when you let go.",
			"slot": null,
			"media_control": func() -> Control: return PortraitDemoClip.new(demo_textures),
		}]
		popup.closed.connect(_open_switch_minigame, CONNECT_ONE_SHOT)
		popup.call("open", pages)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	_switch_modal = SwitchMinigameModal.new()
	var textures: Array = [null, null, null]
	var clues: Array = []
	for p in _posters:
		textures[p.diver_index] = p.portrait
		if p.seen:
			clues.append({"texture": p.portrait, "number": p.number})
	_switch_modal.portrait_textures = textures
	_switch_modal.clue_entries = clues
	# Every portrait starts in a lane that isn't its own: shift each diver's
	# right lane (poster number - 1) along by 1 or 2, wrapping round.
	var shift := randi_range(1, 2)
	var lanes: Array = [0, 1, 2]
	for p in _posters:
		lanes[p.diver_index] = (p.number - 1 + shift) % 3
	_switch_modal.start_lanes = lanes
	_switch_modal.all_arrived.connect(_on_switch_puzzle_arrived)
	_switch_modal.retry_requested.connect(_retry_switch_minigame)
	add_child(_switch_modal)

# Sees every event before the GUI does. While the switch modal is open, a
# mouse press records its start point and whether that point is within the
# modal's panel, and left-button press / drag / release draw lines on it
# (SwitchMinigameModal.begin_/continue_/finish_lines_drawing()).
func _input(e: InputEvent) -> void:
	if not switch_modal_open():
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			modal_press_start = mb.position
			modal_press_started_inside = _switch_modal.contains_screen_point(mb.position)
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_switch_modal.begin_lines_drawing(mb.position)
		else:
			_switch_modal.finish_lines_drawing()
	elif e is InputEventMouseMotion and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT):
		_switch_modal.continue_lines_drawing((e as InputEventMouseMotion).position)

func _toggle_room_encounters() -> void:
	room_encounters_enabled = not room_encounters_enabled
	_announce("Developer: random encounters in this room %s." % ("ON" if room_encounters_enabled else "OFF"))

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
	# The opening is exactly as tall as the KeyDoor that fills it, so the
	# wall above comes right down to the door's top (rather than leaving a
	# see-through gap up to the maze's invisible ceiling).
	var opening_height := _key_door_height()
	var lintel_height := height - opening_height
	_door30_center = Vector3(door_center.x, bottom, door_center.z)
	door_center.y = bottom + opening_height + lintel_height * 0.5
	_spawn_wall("Box30DoorLintel", door_center, yaw, Vector3(DOOR_OPENING.x, lintel_height, thickness))

# --- Doors (KeyDoor, ported from UnderwaterGame PR #93) ---------------------
# One in wall 16's door gap, one in the opening of the wall spanning Box30
# and Box32 (with a room behind it, away from the corridor that leads to it).
# Each is scaled so its width fills the DOOR_OPENING-wide gap; at that size
# it's about as tall as the maze's normal walls. They need no key: E within
# reach opens them (KeyDoor shows its own "E: Open door" prompt), and their
# collision clears once the opening animation is most of the way through.
# The wheel side faces the way you approach from.
const KEY_DOOR_WIDTH_PER_HEIGHT := 1.809661 / 3.2   # the door model's own width : height
var _door30_center := Vector3.ZERO   # floor-level centre of the 30/32 doorway
var _maze_doors: Array[KeyDoor] = []

func _key_door_height() -> float:
	return DOOR_OPENING.x / KEY_DOOR_WIDTH_PER_HEIGHT

func _build_maze_doors() -> void:
	# Wall 16: the gap between CSGBox3D16 and CSGBox3D16North; approached
	# from the passage on the Box17/27 side.
	var w16 := $CSGBox3D16 as CSGBox3D
	var gn: Dictionary = _wall_geometry($CSGBox3D16North as CSGBox3D)
	var g16: Dictionary = _wall_geometry(w16)
	var z16_top := maxf((g16["negative_end"] as Vector3).z, (g16["positive_end"] as Vector3).z)
	var zn_bottom := minf((gn["negative_end"] as Vector3).z, (gn["positive_end"] as Vector3).z)
	var bottom16 := w16.global_position.y - w16.size.y * 0.5
	var toward_passage := Vector3(-1, 0, 0) if ($CSGBox3D27 as CSGBox3D).global_position.x < w16.global_position.x else Vector3(1, 0, 0)
	_spawn_key_door("MazeDoor16", Vector3(w16.global_position.x, bottom16, (z16_top + zn_bottom) * 0.5), toward_passage, "sphere_room_key")
	# Box30/32: approached from the CSGBox3D29/33 side (where the Box6/Box7
	# corridor comes in); the room goes on the other side.
	if _door30_center != Vector3.ZERO:
		var box30 := $CSGBox3D30 as CSGBox3D
		var room_side := -1.0 if box30.global_position.x < _door30_center.x else 1.0
		_spawn_key_door("MazeDoor30", _door30_center, Vector3(-room_side, 0, 0), "vortex_key")
		_build_secret_boss_room()

# A no-key KeyDoor standing at `floor_point` (its bottom-centre), filling a
# DOOR_OPENING-wide gap in a north-south wall, wheel side toward `approach`.
func _spawn_key_door(door_name: String, floor_point: Vector3, approach: Vector3, key_id := "") -> KeyDoor:
	var door := KeyDoor.new()
	door.name = door_name
	door.door_id = door_name
	door.required_key_id = key_id
	door.key_source = func() -> Array: return key_items
	# Any key opens any door (one key each).
	door.key_count_source = func() -> int: return keys_held
	door.spend_key = func() -> void: keys_held = maxi(keys_held - 1, 0)
	door.visual_height = _key_door_height()
	door.interaction_radius = 3.0
	door.active_diver_source = func() -> Diver: return _diver
	door.announce = _announce
	add_child(door)
	door.global_position = floor_point
	door.rotation.y = atan2(approach.x, approach.z)   # local +Z (wheel side) toward `approach`
	_maze_doors.append(door)
	return door

# E for the doors: the first one in reach that takes it.
func _try_open_door() -> bool:
	for door in _maze_doors:
		if is_instance_valid(door) and door.interact(_diver):
			return true
	return false

# --- Left secret wall entrance --------------------------------------------------
# A flashing panel on CSGBox3D27's passage side (the left wall walking north
# between Box27 and Box16). E within reach takes the active diver into
# left_maze_secret_wall.tscn; leaving that scene puts the party back here.
# The maze is reloaded on the way back, so its walls/currents/levers reset.
const SECRET_WALL_SCENE := "res://game/left_maze_secret_wall.tscn"
const SECRET_ENTRANCE_REACH := 2.5
var _secret_entrance: MeshInstance3D

func _build_secret_wall_entrance() -> void:
	var w27 := $CSGBox3D27 as CSGBox3D
	var g: Dictionary = _wall_geometry(w27)
	var mid := ((g["negative_end"] as Vector3) + (g["positive_end"] as Vector3)) * 0.5
	# The passage side faces Box16.
	var face := 1.0 if ($CSGBox3D16 as CSGBox3D).global_position.x > w27.global_position.x else -1.0
	_secret_entrance = MeshInstance3D.new()
	_secret_entrance.name = "SecretWallEntrance"
	var panel := BoxMesh.new()
	panel.size = Vector3(0.12, 3.6, 3.0)
	_secret_entrance.mesh = panel
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 1.0)
	mat.emission_energy_multiplier = 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	_secret_entrance.material_override = mat
	add_child(_secret_entrance)
	var bottom := w27.global_position.y - w27.size.y * 0.5
	_secret_entrance.global_position = Vector3(w27.global_position.x + face * (w27.size.z * 0.5 + 0.07), bottom + 0.3 + 1.8, mid.z)
	_secret_entrance.set_meta("face", face)
	# No glowing panel any more - just an anchor for where the way in is. What
	# you see is the draft: water streaming in along the floor and away under
	# the wall to the other side.
	_secret_entrance.visible = false
	_build_secret_draft(w27, face, mid.z)

# Pale streaks drawn in toward wall 27 along the floor and out of sight through
# the gap beneath it - a current that plainly goes somewhere.
func _build_secret_draft(w27: CSGBox3D, face: float, z: float) -> void:
	var wall_bottom := w27.global_position.y - w27.size.y * 0.5
	var gap_mid := (_floor_top_y + 0.15 + wall_bottom) * 0.5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.9, maxf(0.1, (wall_bottom - _floor_top_y) * 0.35), 1.4)
	pm.direction = Vector3(-face, 0, 0)
	pm.spread = 4.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3.ZERO
	pm.particle_flag_align_y = true
	var fade := Gradient.new()
	fade.set_color(0, Color(0.75, 0.95, 1.0, 0.0))
	fade.set_color(1, Color(0.75, 0.95, 1.0, 0.0))
	fade.add_point(0.15, Color(0.75, 0.95, 1.0, 0.8))
	fade.add_point(0.8, Color(0.6, 0.85, 1.0, 0.55))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	var streak := BoxMesh.new()
	streak.size = Vector3(0.03, 0.5, 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	streak.material = mat
	var draft := GPUParticles3D.new()
	draft.name = "SecretWallDraft"
	draft.amount = 70
	draft.lifetime = 2.0
	draft.preprocess = 2.0
	draft.process_material = pm
	draft.draw_pass_1 = streak
	draft.visibility_aabb = AABB(Vector3(-8, -2, -4), Vector3(16, 4, 8))
	add_child(draft)
	draft.global_position = Vector3(w27.global_position.x + face * (w27.size.z * 0.5 + 2.2), gap_mid, z)

# Swimming up to the draft asks whether to follow it. Asked once per approach:
# say no and it waits until you've swum away and come back.
const SECRET_DRAFT_PROMPT_TEXT := "A draft leads to the other side of the wall.. would you like to explore further?"
var _draft_prompt: ConfirmPromptModal
var _draft_prompt_latched := false

func _update_secret_draft_prompt() -> void:
	var near := _secret_entrance_in_reach()
	if not near:
		_draft_prompt_latched = false
		return
	if _draft_prompt_latched or _battling or any_modal_open():
		return
	_draft_prompt_latched = true
	_open_secret_draft_prompt()

func _open_secret_draft_prompt() -> void:
	if _draft_prompt != null and is_instance_valid(_draft_prompt):
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	_diver.velocity = Vector3.ZERO
	_draft_prompt = ConfirmPromptModal.new(SECRET_DRAFT_PROMPT_TEXT)
	_draft_prompt.answered.connect(func(yes: bool) -> void:
		_draft_prompt = null
		if yes:
			_enter_secret_wall())
	add_child(_draft_prompt)

func _secret_entrance_in_reach() -> bool:
	if _secret_entrance == null or _diver == null:
		return false
	var offset := _diver.global_position - _secret_entrance.global_position
	offset.y = 0.0
	var face := float(_secret_entrance.get_meta("face"))
	return offset.length() <= SECRET_ENTRANCE_REACH and offset.x * face > 0.0

func _enter_secret_wall() -> void:
	SceneHandoff.diver_model = _diver.model_name
	if world == null:
		get_tree().change_scene_to_file.call_deferred(SECRET_WALL_SCENE)
		return
	# Part of the world: show the secret level over it instead of replacing
	# it, the world (this maze included) paused and hidden underneath, so
	# coming back finds everything as it was left.
	var secret := (load(SECRET_WALL_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(secret)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.visible = false
	($HUD as CanvasLayer).visible = false
	(world.get_node("HUD") as CanvasLayer).visible = false
	for cam in secret.find_children("*", "Camera3D", true, false):
		(cam as Camera3D).make_current()
		break

func _return_from_secret_wall(secret: Node) -> void:
	if is_instance_valid(secret):
		secret.queue_free()
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.visible = true
	($HUD as CanvasLayer).visible = true
	(world.get_node("HUD") as CanvasLayer).visible = true
	($Camera3D as Camera3D).make_current()
	_place_divers_at_secret_entrance()

# Back from the secret scene: the diver who went in is active again, and the
# party stands in the passage in front of the entrance.
func _place_divers_at_secret_entrance() -> void:
	if _secret_entrance == null:
		return
	for i in divers.size():
		if divers[i].model_name == SceneHandoff.diver_model:
			active = i
			_diver = divers[i]
	var face := float(_secret_entrance.get_meta("face"))
	var spot := _secret_entrance.global_position + Vector3(face * 2.0, 0, 0)
	spot.y = ($DiverEntry as Node3D).global_position.y
	var offsets := [0.0, -2.5, 2.5]
	for i in divers.size():
		var slot: int = (i - active + divers.size()) % divers.size()
		divers[i].global_position = spot + Vector3(0, 0, float(offsets[slot]))
		divers[i].velocity = Vector3.ZERO
	_yaw = atan2(-face, 0.0)   # facing the entrance

# --- Sphere room and Sonar Vision ---------------------------------------------
# The room behind wall 16's door is a big room full of hidden spheres
# swirling around its centre (SwirlRoom). They're invisible to the eye; the
# minimap always shows them as red circles. The Sonar Vision item (picked up
# in the room behind the Box30/32 door, toggled with Q) shows them in 3D
# while the active diver is inside the sphere room.
var _swirl_room: SwirlRoom
# Once picked up it's always equipped: it works whenever Maxilani's sonar is
# on - no separate toggle.
var has_sonar_vision := false

func _build_sphere_room() -> void:
	var back := get_node_or_null("Room16Back") as CSGBox3D
	var north := get_node_or_null("Room16North") as CSGBox3D
	var south := get_node_or_null("Room16South") as CSGBox3D
	var w16 := $CSGBox3D16 as CSGBox3D
	if back == null or north == null or south == null:
		return
	var t := w16.size.z
	var x_a := w16.global_position.x + signf(back.global_position.x - w16.global_position.x) * t * 0.5
	var x_b := back.global_position.x - signf(back.global_position.x - w16.global_position.x) * t * 0.5
	var z_a := minf(north.global_position.z, south.global_position.z) + t * 0.5
	var z_b := maxf(north.global_position.z, south.global_position.z) - t * 0.5
	var interior := Rect2(Vector2(minf(x_a, x_b), z_a), Vector2(absf(x_b - x_a), z_b - z_a))
	_sphere_room_interior = interior
	_swirl_room = SwirlRoom.new()
	_swirl_room.name = "SphereRoom"
	# Full swimmable height: the floor and ceiling sit one clearance below and
	# above the normal walls (see _build_floor() / _build_ceiling()).
	var wall_bottom := w16.global_position.y - w16.size.y * 0.5
	var wall_top := w16.global_position.y + w16.size.y * 0.5
	_swirl_room.setup(interior, wall_bottom - _FLOOR_CLEARANCE, wall_top + _CEILING_CLEARANCE)
	add_child(_swirl_room)
	_swirl_room.diver_hit.connect(func(d: Diver) -> void:
		# Only while the rocks are unseen - with sonar on and Sonar Vision
		# equipped the player can see what hit them.
		if d == _diver and not sonar_vision_active():
			_announce("Some hidden items in this room seem to be doing damage...", 2.5))

# The Sonar Vision pickup: a spinning cyan lens in the middle of the room
# behind the Box30/32 door. Swim into it to take it (it's switched on).
func _build_sonar_vision_pickup() -> void:
	if _door30_center == Vector3.ZERO:
		return
	# In the hall between the two boss doors, a little north of their line.
	var box33 := $CSGBox3D33 as CSGBox3D
	var spot := Vector3((_door30_center.x + box33.global_position.x) * 0.5, ($DiverEntry as Node3D).global_position.y + 0.3, _door30_center.z + 6.0)
	var pickup := Area3D.new()
	pickup.name = "SonarVisionPickup"
	pickup.collision_mask = 2   # divers
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3
	shape.shape = sphere
	pickup.add_child(shape)
	var lens := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.6
	lens.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.95, 1.0)
	mat.emission_energy_multiplier = 2.5
	lens.material_override = mat
	lens.rotation.x = PI * 0.5
	pickup.add_child(lens)
	var label := Label3D.new()
	label.text = "Sonar Vision"
	label.font_size = 48
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = Color(0.6, 0.97, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.2, 0)
	pickup.add_child(label)
	add_child(pickup)
	pickup.global_position = spot
	var spin := create_tween().set_loops()
	spin.tween_property(lens, "rotation:y", TAU, 2.0).from(0.0)
	pickup.body_entered.connect(func(body: Node3D) -> void:
		if body is Diver and not has_sonar_vision:
			has_sonar_vision = true
			_announce("Sonar Vision acquired. Switch on Maxilani's sonar (Q) to see invisible objects.", 8.0)
			var popup := get_node_or_null("/root/CharacterAbilityPopup")
			if popup != null:
				var pages: Array[Dictionary] = [{
					"title": "Sonar Vision",
					"body": "A key item that lets you see invisible objects. It works automatically whenever sonar is on: play as Maxilani and switch her sonar on with Q.",
					"slot": null,
				}]
				popup.call("open", pages)
			pickup.queue_free())

# --- Boss rooms ------------------------------------------------------------------
# Secret boss room: the whole space between Box30 and Box32 behind the
# Box30/32 door (which needs the Vortex Key, found in the eye of the sphere
# vortex), closed at its far end by a wall as tall as Box30/32. The maze's
# invisible ceiling closes it over the top. A red sigil in the middle starts
# the secret boss fight: a lone Swordfish Duelist guardian with stats boosted
# 40-60%. Beating it drops the Abyss Key.
#
# Main boss room: across the hall, through a door in Box33 directly opposite
# the Box30/32 door (it needs the Abyss Key), a room east of Box33 between
# Box32's line and just north of Box22. A purple sigil in the middle starts
# the Tethys fight.
const SECRET_BOSS_BOOST := Vector2(1.4, 1.6)
const BOSS_TRIGGER_RADIUS := 3.0
var key_items: Array[String] = []
var _battle_kind := "strong"
var _boss_triggers: Dictionary = {}   # "secret_boss" / "main_boss" -> Area3D
var _main_boss_door_z := 0.0

func _build_secret_boss_room() -> void:
	var box30 := $CSGBox3D30 as CSGBox3D
	var box32 := $CSGBox3D32 as CSGBox3D
	var g30: Dictionary = _wall_geometry(box30)
	var g32: Dictionary = _wall_geometry(box32)
	# The far (west) end: the outer end of Box30/Box32 away from the door.
	var far_x := minf(minf((g30["negative_end"] as Vector3).x, (g30["positive_end"] as Vector3).x), minf((g32["negative_end"] as Vector3).x, (g32["positive_end"] as Vector3).x))
	var z0 := box30.global_position.z
	var z1 := box32.global_position.z
	var t := box30.size.z
	var back := _spawn_wall("SecretBossRoomBack", Vector3(far_x, box30.global_position.y, (z0 + z1) * 0.5), PI * 0.5, Vector3(absf(z1 - z0) + t, box30.size.y, t))
	wall_boxes.append(back)

# Splits CSGBox3D33 around a door gap directly opposite the Box30/32 door,
# with a KeyDoor (Abyss Key) and the wall above the door coming down to it,
# then builds the main boss room east of it.
func _build_main_boss_room() -> void:
	var b33 := $CSGBox3D33 as CSGBox3D
	var b32 := $CSGBox3D32 as CSGBox3D
	var b22 := $CSGBox3D22 as CSGBox3D
	if _door30_center == Vector3.ZERO:
		return
	var g: Dictionary = _wall_geometry(b33)
	var z_lo := minf((g["negative_end"] as Vector3).z, (g["positive_end"] as Vector3).z)
	var z_hi := maxf((g["negative_end"] as Vector3).z, (g["positive_end"] as Vector3).z)
	var door_z := _door30_center.z
	_main_boss_door_z = door_z
	var half_door := DOOR_GAP_WIDTH * 0.5
	var x := b33.global_position.x
	var y := b33.global_position.y
	var t := b33.size.z
	var h := b33.size.y
	var bottom := y - h * 0.5
	wall_boxes.append(_spawn_wall("CSGBox3D33North", Vector3(x, y, (door_z + half_door + z_hi) * 0.5), b33.rotation.y, Vector3(z_hi - door_z - half_door, h, t)))
	_set_wall_span_z(b33, x, z_lo, door_z - half_door)
	# Wall above the door, down to the door's top (kept off the minimap so the doorway shows).
	var opening_h := _key_door_height()
	_spawn_wall("CSGBox3D33Lintel", Vector3(x, bottom + opening_h + (h - opening_h) * 0.5, door_z), PI * 0.5, Vector3(DOOR_GAP_WIDTH, h - opening_h, t))
	_spawn_key_door("MazeDoorMainBoss", Vector3(x, bottom, door_z), Vector3(-1, 0, 0), "abyss_key")
	# The room: north wall on Box32's line, south wall just clear of Box22,
	# east wall far enough out for a real arena.
	var x0 := x + t * 0.5
	var x1 := x0 + 24.0
	var z_north := b32.global_position.z
	var z_south := b22.global_position.z + b22.size.z * 0.5 + 0.5 + t * 0.5
	var mid_z := (z_north + z_south) * 0.5
	for spec in [
		["MainBossRoomNorth", Vector3((x0 + x1) * 0.5, y, z_north), 0.0, Vector3(x1 - x0, h, t)],
		["MainBossRoomSouth", Vector3((x0 + x1) * 0.5, y, z_south), 0.0, Vector3(x1 - x0, h, t)],
		["MainBossRoomEast", Vector3(x1, y, mid_z), PI * 0.5, Vector3(z_north - z_south + t, h, t)],
	]:
		wall_boxes.append(_spawn_wall(spec[0], spec[1], spec[2], spec[3]))

# --- Patrolling Tethys (the secret boss) ---------------------------------------
# Tethys swims a loop around the secret boss room. Between corners it plays
# its swim loop; at each corner it stops and plays one of its other clips
# (idle and its attacks, in turn). Swimming into it asks "A great danger is
# detected here. Are you sure you would like to proceed?" - Yes starts the
# Tethys fight, No pushes the diver back out.
#
# Room for it, measured from its skeleton over every clip at its native
# scale: up to 4.6 above its feet (Double Scratch), 0.76 below them
# (Spinning Death), and up to 4.4 out to the side (Tongue Slayer). So it
# hovers TETHYS_HOVER off the floor, its loop keeps TETHYS_REACH + a margin
# from the walls, and the ceiling over this room is raised to clear its top
# with TETHYS_HEADROOM to spare (see _raised_ceiling_regions()). The room's
# walls are 14 tall, so the raised ceiling stays sealed.
const TETHYS_HOVER := 1.0
const TETHYS_TOP := 4.6
const TETHYS_REACH := 4.4
const TETHYS_HEADROOM := 1.5
const TETHYS_SPEED := 2.2
const TETHYS_PROMPT_RADIUS := 2.8
const TETHYS_SHOWCASE := ["idle", "tail_sweep", "poison_breath", "spinning_death", "double_cratch", "tongue_slayer"]
const TETHYS_PROMPT_TEXT := "A great danger is detected here. Are you sure you would like to proceed?"
var _tethys: TethysBoss
var _tethys_route: Array[Vector3] = []
var _tethys_target := 0
var _tethys_pause := 0.0
var _tethys_showcase_i := 0
var _tethys_prompt: ConfirmPromptModal
var _tethys_prompt_cooldown := 0.0

func _maze_floor_top() -> float:
	var w := $CSGBox3D16 as CSGBox3D
	return w.global_position.y - w.size.y * 0.5 - _FLOOR_CLEARANCE

# The secret boss room on the floor plan: between Box30 and Box32, from the
# back wall to the door wall. `inside` = the open interior; otherwise the
# outer edges of its walls (for the raised ceiling).
func _secret_boss_room_rect(inside: bool) -> Rect2:
	var back := get_node_or_null("SecretBossRoomBack") as CSGBox3D
	if back == null or _door30_center == Vector3.ZERO:
		return Rect2()
	var box30 := $CSGBox3D30 as CSGBox3D
	var box32 := $CSGBox3D32 as CSGBox3D
	var t := back.size.z
	var grow := -1.0 if inside else 1.0
	var x0 := minf(back.global_position.x, _door30_center.x) - grow * t * 0.5
	var x1 := maxf(back.global_position.x, _door30_center.x) + grow * t * 0.5
	var z0 := minf(box30.global_position.z, box32.global_position.z) - grow * t * 0.5
	var z1 := maxf(box30.global_position.z, box32.global_position.z) + grow * t * 0.5
	return Rect2(x0, z0, x1 - x0, z1 - z0)

func _build_tethys_patrol() -> void:
	var room := _secret_boss_room_rect(true)
	if room.size == Vector2.ZERO:
		return
	var inset := TETHYS_REACH + 0.6
	var y := _maze_floor_top() + TETHYS_HOVER
	var a := room.position + Vector2(inset, inset)
	var b := room.end - Vector2(inset, inset)
	_tethys_route = [Vector3(a.x, y, a.y), Vector3(b.x, y, a.y), Vector3(b.x, y, b.y), Vector3(a.x, y, b.y)]
	_tethys = TethysBoss.new()
	_tethys.name = "PatrollingTethys"
	add_child(_tethys)
	_tethys.global_position = _tethys_route[0]
	_tethys_target = 1
	_tethys.play("swim_loop")
	var area := Area3D.new()
	area.collision_mask = 2   # divers
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = TETHYS_PROMPT_RADIUS
	cyl.height = TETHYS_TOP + 2.0
	shape.shape = cyl
	shape.position = Vector3(0, cyl.height * 0.5 - 1.0, 0)
	area.add_child(shape)
	_tethys.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body == _diver and not _battling and not any_modal_open() and _tethys_prompt_cooldown <= 0.0:
			_open_tethys_prompt())
	_boss_triggers["secret_boss"] = _tethys

func _update_tethys_patrol(dt: float) -> void:
	if _tethys == null or not is_instance_valid(_tethys):
		return
	_tethys_prompt_cooldown = maxf(0.0, _tethys_prompt_cooldown - dt)
	if _battling or any_modal_open():
		return
	if _tethys_pause > 0.0:
		_tethys_pause -= dt
		if _tethys_pause <= 0.0:
			_tethys.play("swim_loop")
		return
	var target := _tethys_route[_tethys_target]
	var to := target - _tethys.global_position
	to.y = 0.0
	if to.length() < 0.05:
		# Corner: stop and show off one of its other animations.
		_tethys_target = (_tethys_target + 1) % _tethys_route.size()
		var clip: String = TETHYS_SHOWCASE[_tethys_showcase_i % TETHYS_SHOWCASE.size()]
		_tethys_showcase_i += 1
		_tethys.face_toward(_tethys_route[_tethys_target])
		_tethys_pause = maxf(1.5, _tethys.play(clip))
		return
	_tethys.face_toward(target)
	_tethys.global_position += to.normalized() * minf(TETHYS_SPEED * dt, to.length())

func _open_tethys_prompt() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	_diver.velocity = Vector3.ZERO
	_tethys_prompt = ConfirmPromptModal.new(TETHYS_PROMPT_TEXT)
	_tethys_prompt.answered.connect(func(yes: bool) -> void:
		_tethys_prompt = null
		if yes:
			_start_battle("secret_boss")
			return
		# Back off: out of its reach, and no asking again for a moment.
		var away := _diver.global_position - _tethys.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0)
		var spot := _tethys.global_position + away * (TETHYS_PROMPT_RADIUS + 1.5)
		spot.y = _diver.global_position.y
		_diver.global_position = spot
		_diver.velocity = Vector3.ZERO
		_tethys_prompt_cooldown = 2.0)
	add_child(_tethys_prompt)

# The two sigils that start the boss fights when the active diver swims onto them.
func _build_boss_triggers() -> void:
	var box30 := $CSGBox3D30 as CSGBox3D
	var box32 := $CSGBox3D32 as CSGBox3D
	_build_tethys_patrol()
	var north := get_node_or_null("MainBossRoomNorth") as CSGBox3D
	var south := get_node_or_null("MainBossRoomSouth") as CSGBox3D
	if north != null and south != null:
		var main_spot := Vector3(north.global_position.x, 0, (north.global_position.z + south.global_position.z) * 0.5)
		_boss_triggers["main_boss"] = _make_boss_sigil(main_spot, Color(0.65, 0.25, 1.0), "Something vast waits in the deep...", "main_boss")

func _make_boss_sigil(spot: Vector3, color: Color, caption: String, kind: String) -> Area3D:
	var area := Area3D.new()
	area.name = "BossSigil_" + kind
	area.collision_mask = 2   # divers
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BOSS_TRIGGER_RADIUS
	cyl.height = 8.0
	shape.shape = cyl
	area.add_child(shape)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = BOSS_TRIGGER_RADIUS
	disc_mesh.bottom_radius = BOSS_TRIGGER_RADIUS
	disc_mesh.height = 0.05
	disc.mesh = disc_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	disc.material_override = mat
	area.add_child(disc)
	var label := Label3D.new()
	label.text = caption
	label.font_size = 56
	label.pixel_size = 0.008
	label.outline_size = 10
	label.modulate = color.lightened(0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.0, 0)
	area.add_child(label)
	add_child(area)
	var floor_y := ($CSGBox3D16 as CSGBox3D).global_position.y - ($CSGBox3D16 as CSGBox3D).size.y * 0.5 - _FLOOR_CLEARANCE
	area.global_position = Vector3(spot.x, floor_y + 0.05, spot.z)
	var pulse := create_tween().set_loops()
	pulse.tween_property(mat, "emission_energy_multiplier", 3.0, 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(mat, "emission_energy_multiplier", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body == _diver and not _battling and not any_modal_open():
			_start_battle(kind))
	return area

# --- Secret item room (the reward chamber) ------------------------------------------
# Rocks on the markers placed in the reward chamber (north of
# RewardChamberWestWall, between Box24 and Box20, up to Box25), broken with
# Bucky's Shockwave. ItemRock is still the maze-completion relic (see
# _build_item_rocks()); the others give what SECRET_ITEM_ROCKS says - the
# Sphere Room Key, or a permanent boost for the whole party. The ceiling over
# the chamber is raised so the high ones can be reached (see
# _raised_ceiling_regions()).
# Item ids from items.gd (the same items the main game's rocks drop) or
# "ambush": hidden enemies burst out (a boosted random encounter).
const SECRET_ITEM_ROCKS := {
	"ItemRock2": "sphere_room_key",
	"ItemRock3": "attack_up",
	"Marker3D2": "ambush",
	"Marker3D4": "spell_shard",
	"Marker3D5": "ambush",
	"Marker3D7": "ambush",
}
const SECRET_ROCK_HEADROOM := 2.6   # raised ceiling this far above the highest rock
# The party's items (same shape as World.inventory: item id -> count). Battles
# here use it for their Items menu (Battle.inventory_source).
var inventory: Dictionary = {}

# For the maps: the real extent of a room drawn as a box, when its walls run
# on past it (RewardChamberWestWall does, into the hall east of the secret
# item room). Empty Rect2 = use the walls' own extent.
func map_room_rect(wall_names: Array) -> Rect2:
	if wall_names.has("RewardChamberWestWall"):
		return _secret_item_room_rect()
	return Rect2()

func _secret_item_room_rect() -> Rect2:
	var south := get_node_or_null("RewardChamberWestWall") as CSGBox3D
	var west := get_node_or_null("CSGBox3D24") as CSGBox3D
	var north := get_node_or_null("CSGBox3D25") as CSGBox3D
	var east := get_node_or_null("CSGBox3D20") as CSGBox3D
	if south == null or west == null or north == null or east == null:
		return Rect2()
	var t := south.size.z
	var x0 := west.global_position.x - t * 0.5
	var x1 := east.global_position.x + t * 0.5
	var z0 := south.global_position.z - t * 0.5
	var z1 := north.global_position.z + t * 0.5
	return Rect2(x0, z0, x1 - x0, z1 - z0)

func _build_secret_item_rocks() -> void:
	for marker_name in SECRET_ITEM_ROCKS:
		var marker := get_node_or_null(String(marker_name)) as Node3D
		if marker == null:
			continue
		var rock := CrackedWall.new()
		rock.span = Vector3(1.1, 1.1, 1.1)
		rock.disguised_as_scenery_rock = true   # round scenery-rock look, like the main game's
		rock.position = marker.global_position
		var reward: String = SECRET_ITEM_ROCKS[marker_name]
		rock.broken.connect(_on_secret_rock_broken.bind(reward, marker.global_position))
		add_child(rock)
		# Fake rocks (enemies hiding in them) look the same but don't show on
		# Maxilani's sonar - only rocks with something real inside do.
		if reward != "ambush":
			_secret_room_rocks.append(rock)

# A broken rock either springs an ambush or leaves a golden item orb (the
# main game's ItemOrb) floating where it was - grapple it in, or swim into it.
func _on_secret_rock_broken(reward: String, spot: Vector3) -> void:
	_note_broken_rock(spot)
	if reward == "ambush":
		if not _battling and not any_modal_open():
			_start_battle("ambush")
		return
	var orb := ItemOrb.new()
	orb.item_id = reward
	orb.golden = true
	orb.grappleable = true
	orb.grapple_only = true
	orb.position = spot
	orb.collected.connect(_on_secret_orb_collected)
	orb.needs_ability.connect(func(_d: Diver) -> void:
		_announce("This item seems to require a special ability to pick it up."))
	add_child(orb)
	if Items.is_key_item(reward):
		key_pickups.append(orb)

# Same as the main game's pickup: into the inventory with "Picked up a ...".
# Key items go to key_items instead.
func _on_secret_orb_collected(item_id: String, _d: Diver) -> void:
	var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
	if Items.is_key_item(item_id):
		_gain_key(item_id)
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	_announce("Picked up a %s." % display)

# A short label that rises and fades over a broken rock.
func _float_reward_label(spot: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.008
	label.outline_size = 10
	label.modulate = Color(1.0, 0.9, 0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.global_position = spot + Vector3(0, 1.0, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "global_position:y", spot.y + 2.6, 2.0)
	tw.tween_property(label, "modulate:a", 0.0, 2.0).set_delay(0.8)
	tw.chain().tween_callback(label.queue_free)

# --- The vortex chest ----------------------------------------------------------------
# A treasure chest on the floor in the eye of the sphere vortex. E within
# reach opens it (lid swings up) and the Vortex Key rises out of it into the
# party's keys - the key to the secret boss room.
const CHEST_REACH := 2.4
var _vortex_chest: Node3D
var _vortex_chest_lid: Node3D
var _vortex_chest_open := false

func _build_vortex_chest() -> void:
	if _swirl_room == null:
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.24, 0.12)
	wood.roughness = 0.8
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.25)
	gold.metallic = 0.8
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.6
	_vortex_chest = Node3D.new()
	_vortex_chest.name = "VortexChest"
	add_child(_vortex_chest)
	_vortex_chest.global_position = Vector3(_swirl_room.center.x, _maze_floor_top(), _swirl_room.center.z)
	var size := Vector3(1.4, 0.8, 0.9)
	var base := _chest_box(Vector3(size.x, size.y, size.z), Vector3(0, size.y * 0.5, 0), wood)
	_vortex_chest.add_child(base)
	for band_x in [-0.5, 0.5]:
		_vortex_chest.add_child(_chest_box(Vector3(0.1, size.y + 0.02, size.z + 0.04), Vector3(band_x, size.y * 0.5, 0), gold))
	# Lid hinged along the back edge.
	_vortex_chest_lid = Node3D.new()
	_vortex_chest_lid.position = Vector3(0, size.y, -size.z * 0.5)
	_vortex_chest.add_child(_vortex_chest_lid)
	_vortex_chest_lid.add_child(_chest_box(Vector3(size.x + 0.04, 0.28, size.z + 0.04), Vector3(0, 0.14, size.z * 0.5), wood))
	_vortex_chest_lid.add_child(_chest_box(Vector3(0.22, 0.22, 0.06), Vector3(0, 0.0, size.z + 0.02), gold))   # lock plate
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.4)
	glow.light_energy = 1.2
	glow.omni_range = 3.5
	glow.position = Vector3(0, 1.6, 0)
	_vortex_chest.add_child(glow)

func _chest_box(box_size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	return m

func _vortex_chest_in_reach() -> bool:
	if _vortex_chest == null or _vortex_chest_open or _diver == null:
		return false
	var offset := _diver.global_position - _vortex_chest.global_position
	offset.y = 0.0
	return offset.length() <= CHEST_REACH

func _open_vortex_chest() -> void:
	_vortex_chest_open = true
	var tw := create_tween()
	tw.tween_property(_vortex_chest_lid, "rotation:x", -deg_to_rad(110.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The key rises out of it and is taken.
	var key := _make_key_mesh()
	_vortex_chest.add_child(key)
	key.position = Vector3(0, 0.6, 0)
	tw.tween_property(key, "position:y", 2.2, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(key, "rotation:y", TAU, 0.9)
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		key.queue_free()
		_gain_key("vortex_key"))

func _make_key_mesh() -> Node3D:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.25)
	gold.metallic = 0.8
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.2)
	gold.emission_energy_multiplier = 1.5
	var key := Node3D.new()
	var bow := MeshInstance3D.new()
	var bow_mesh := TorusMesh.new()
	bow_mesh.inner_radius = 0.16
	bow_mesh.outer_radius = 0.32
	bow.mesh = bow_mesh
	bow.rotation.x = PI * 0.5
	bow.position = Vector3(0, 0.45, 0)
	bow.material_override = gold
	key.add_child(bow)
	key.add_child(_chest_box(Vector3(0.12, 0.8, 0.12), Vector3.ZERO, gold))
	for tooth_y in [-0.3, -0.15]:
		key.add_child(_chest_box(Vector3(0.18, 0.08, 0.06), Vector3(0.12, tooth_y, 0), gold))
	return key

# Developer start: in the passage just in front of the sphere room's door in
# wall 16, facing it.
func _dev_spawn_at_sphere_room() -> void:
	var door := get_node_or_null("MazeDoor16") as KeyDoor
	if door == null:
		return
	var approach := door.global_basis.z   # the door's wheel side faces the passage
	approach.y = 0.0
	approach = approach.normalized()
	var spot := door.global_position + approach * 3.5
	spot.y = ($DiverEntry as Node3D).global_position.y
	var along := Vector3.UP.cross(approach).normalized()
	var offsets := [0.0, -2.5, 2.5]
	for i in range(divers.size()):
		var slot: int = (i - active + divers.size()) % divers.size()
		divers[i].global_position = spot + along * float(offsets[slot])
	_yaw = atan2(-approach.x, -approach.z)   # looking at the door

# Developer start: in the hall just in front of the secret boss room's door,
# facing it.
func _dev_spawn_at_boss_rooms() -> void:
	if _door30_center == Vector3.ZERO:
		return
	var spot := _door30_center + Vector3(3.5, 0, 0)
	spot.y = ($DiverEntry as Node3D).global_position.y
	var offsets := [0.0, -2.5, 2.5]
	for i in range(divers.size()):
		var slot: int = (i - active + divers.size()) % divers.size()
		divers[i].global_position = spot + Vector3(0, 0, float(offsets[slot]))
	_yaw = atan2(-1.0, 0.0)   # facing the door (-X)

# Spheres show in 3D only while the active diver is in their room with
# Sonar Vision on.
func _update_sonar_vision() -> void:
	if _swirl_room == null or _diver == null:
		return
	_swirl_room.set_revealed(sonar_vision_active() and _swirl_room.contains(_diver.global_position))

# Invisible objects show only while all of this holds: Sonar Vision owned and
# equipped, and the diver being played has the sonar passive (Maxilani) with
# her sonar switched on.
func sonar_vision_active() -> bool:
	return has_sonar_vision and _diver != null and _diver.passive_id == "sonar" and _diver.sonar_active

# Hidden things the minimap tracks as red circles.
# The secret item room's rocks that haven't been broken yet, within
# SONAR_ROCK_RADIUS of the diver - shown on the maps while Maxilani's sonar
# is on (Q).
const SONAR_ROCK_RADIUS := 30.0
var _secret_room_rocks: Array[Node3D] = []

func sonar_rock_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	if _diver == null or _diver.passive_id != "sonar" or not _diver.sonar_active:
		return out
	for rock in _secret_room_rocks:
		if is_instance_valid(rock) and not rock.is_queued_for_deletion() and rock.global_position.distance_to(_diver.global_position) <= SONAR_ROCK_RADIUS:
			out.append(rock.global_position)
	return out

# Only while the diver being played has sonar on (Maxilani, Q).
func hidden_marker_positions() -> PackedVector3Array:
	if _swirl_room == null or _diver == null or _diver.passive_id != "sonar" or not _diver.sonar_active:
		return PackedVector3Array()
	return _swirl_room.positions()

# --- Swap target selection (the main game's TargetSelector) --------------------
var target_selector: TargetSelector
var _camera_focus_target: Node3D

func _build_target_selector() -> void:
	target_selector = TargetSelector.new()
	target_selector.world = self
	target_selector.confirmed.connect(func(target: Node3D) -> void:
		_diver.use_ability(Vector3.ZERO, target))
	add_child(target_selector)
	for d in divers:
		target_selector.register_character(d)

# Called by TargetSelector: look at the candidate being chosen, then back.
func focus_camera_on(target: Node3D, _auto_return_after: float = 0.0) -> void:
	_camera_focus_target = target

func return_camera_to_player() -> void:
	_camera_focus_target = null

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
	var box28 := get_node_or_null("CSGBox3D28") as CSGBox3D
	if box28 == null:   # removed from the scene
		return
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
	if _diver != null and world == null:
		_diver.global_position = reference_outer_end + Vector3(10,10,10)
	#wall_to_place.global_position += reference_outward_axis * wall_to_place.size.x * 0.5
	
	var wall_27 := $CSGBox3D27 as CSGBox3D
	var wall_17 := $CSGBox3D17 as CSGBox3D
	var outer_axis: Vector3 = wall_27.global_transform.basis.x.normalized()

	wall_17.rotation.y = wall_17.rotation.y + PI
	var placed_axis: Vector3 = wall_17.global_transform.basis.x.normalized()
	var center_sign := 1.0 if placed_axis.dot(Vector3.LEFT) > 0.0 else -1.0
	# Out of Box27's end (reference_outward_axis), not along Box17's own axis:
	# after the flip above, Box17's basis.x points back INTO Box27, which
	# left it overlapping Box27 instead of a door width beyond it.
	wall_17.global_position = reference_outer_end + reference_outward_axis * wall_17.size.x * 0.5
	const WIDTH := 2.3
	wall_17.global_position += reference_outward_axis * WIDTH

	


# --- Lever dome ------------------------------------------------------------
# Where the CSGBox3D34/35/36 U of walls stood there's a dome instead: a big
# dome on a raised round plinth, with two porch doorways and steps up to
# each - one facing north (+Z, back toward the maze entrance) and one facing
# east (+X), where the path from walls 12/13 arrives (_build_path_button()).
# The plinth top is above the divers' normal swim height, so they have to
# swim up the steps to get in. The ceiling over it is raised to fit (see
# _build_ceiling()). Inside are the two green levers (Lever1 left = walls,
# Lever2 right = currents, as seen coming in the north door), each with a
# red light beside it.
#
# E beside a free lever: that diver takes hold of it (handle thrown, light
# green, orange hint about what it controls) and stays put holding it; Tab
# still switches to another diver (TAB flashes in the top-left controls).
# While only one lever is held, controlling its holder shows the
# LeverHoldPanel ("Press E to release the lever"). With both held (by two
# divers) the wall/current map is up whenever you control either holder (E
# or Esc releases both levers and closes it). Tab to the third diver and the
# map closes; a flashing [L] top-left opens it for that diver, who then can
# only use the map until Esc/L closes it. Either way the map's controls are
# listed beside it. Releasing turns the lights red again and gives the diver
# back normal control.
const DOME_RADIUS := 10.0
const DOME_HEIGHT := 6.0
const DOME_THICKNESS := 0.4
const PLINTH_RADIUS := 11.0
const PLINTH_TOP_Y := 1.0         # above swim height (divers float at y 0)
const DOOR_SIZE := Vector2(3.0, 3.0)
const DOOR_DIRECTIONS := [Vector3(0, 0, 1), Vector3(1, 0, 0)]   # north, east
const STEP_COUNT := 5
const STEP_DEPTH := 1.0
const STEP_WIDTH := 4.2
const LEVER_REACH := 1.8
const LEVER_HINTS := ["This lever seems to control walls nearby", "This lever seems to control water currents nearby"]
var _dome_site := Vector3.ZERO    # plinth centre on the floor plan (y unused)
var _dome_levers: Array[Lever] = []
var _lever_lights: Array[MeshInstance3D] = []
var _lever_glows: Array[OmniLight3D] = []
var _lever_holders: Dictionary = {}   # Lever -> Diver holding it
var _lever_panel: LeverHoldPanel
var _release_levers_label: Label
var _lever_map_open := false
var _free_map_open := false        # the diver not on a lever opened the lever map
var _map_hint: Label               # flashing [L] for that diver
var _lever_map_controls: Label     # controls list beside the map

# Removes the CSGBox3D34/35/36 walls (before wall_boxes is collected) and
# notes roughly where the dome goes: centred between 34 and 36.
# _settle_dome_site() then lines it up with the walls 12/13 path.
func _clear_dome_site() -> void:
	var w34 := get_node_or_null("CSGBox3D34") as CSGBox3D
	var w35 := get_node_or_null("CSGBox3D35") as CSGBox3D
	var w36 := get_node_or_null("CSGBox3D36") as CSGBox3D
	if w34 == null or w35 == null or w36 == null:
		return
	_dome_site = Vector3((w34.global_position.x + w36.global_position.x) * 0.5, 0.0, w35.global_position.z + w35.size.z * 0.5 + PLINTH_RADIUS + 0.8)
	for w in [w34, w35, w36]:
		remove_child(w)
		w.queue_free()

# After the walls are placed: centre the dome (north-south) on the passage
# between CSGBox3D8 and CSGBox3D9, so the path from walls 12/13 runs
# straight into its east door.
func _settle_dome_site() -> void:
	if _dome_site == Vector3.ZERO:
		return
	_dome_site.z = (($CSGBox3D8 as CSGBox3D).global_position.z + ($CSGBox3D9 as CSGBox3D).global_position.z) * 0.5

func _stone(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _build_lever_dome() -> void:
	var dome := CSGCombiner3D.new()
	dome.name = "LeverDome"
	dome.use_collision = true
	add_child(dome)
	dome.global_position = Vector3(_dome_site.x, PLINTH_TOP_Y, _dome_site.z)
	var dome_mat := _stone(Color(0.66, 0.62, 0.52))
	var base_mat := _stone(Color(0.42, 0.41, 0.39))
	var plinth_height := PLINTH_TOP_Y - _floor_top_y

	# Outer shell (an ellipsoid: a sphere squashed to DOME_HEIGHT).
	var outer := CSGSphere3D.new()
	outer.radius = DOME_RADIUS
	outer.radial_segments = 48
	outer.rings = 24
	outer.scale = Vector3(1, DOME_HEIGHT / DOME_RADIUS, 1)
	outer.material = dome_mat
	dome.add_child(outer)
	# A porch sticking out at each door.
	var porch_len := 3.6
	for dir in DOOR_DIRECTIONS:
		var d := dir as Vector3
		var porch := CSGBox3D.new()
		porch.size = Vector3(DOOR_SIZE.x + 1.2, DOOR_SIZE.y + 0.5, porch_len)
		porch.rotation.y = atan2(d.x, d.z)
		porch.position = d * (DOME_RADIUS + 1.0 - porch_len * 0.5) + Vector3(0, porch.size.y * 0.5, 0)
		porch.material = dome_mat
		dome.add_child(porch)
	# Hollow it out.
	var inner_r := DOME_RADIUS - DOME_THICKNESS
	var inner := CSGSphere3D.new()
	inner.operation = CSGShape3D.OPERATION_SUBTRACTION
	inner.radius = inner_r
	inner.radial_segments = 48
	inner.rings = 24
	inner.scale = Vector3(1, (DOME_HEIGHT - DOME_THICKNESS) / inner_r, 1)
	dome.add_child(inner)
	# The doorways, through each porch into the dome.
	for dir in DOOR_DIRECTIONS:
		var d := dir as Vector3
		var door := CSGBox3D.new()
		door.operation = CSGShape3D.OPERATION_SUBTRACTION
		door.size = Vector3(DOOR_SIZE.x, DOOR_SIZE.y, 8.0)
		door.rotation.y = atan2(d.x, d.z)
		door.position = d * (DOME_RADIUS - 1.0) + Vector3(0, DOOR_SIZE.y * 0.5, 0)
		dome.add_child(door)
	# Plinth last, so it also fills the hollow's lower half back in as the
	# dome's floor.
	var plinth := CSGCylinder3D.new()
	plinth.radius = PLINTH_RADIUS
	plinth.height = plinth_height
	plinth.sides = 48
	plinth.position = Vector3(0, -plinth_height * 0.5, 0)
	plinth.material = base_mat
	dome.add_child(plinth)
	# Steps up from the floor to the plinth top, in front of each door.
	var rise := plinth_height / STEP_COUNT
	for dir in DOOR_DIRECTIONS:
		var d := dir as Vector3
		for i in STEP_COUNT:
			var step := CSGBox3D.new()
			var top := _floor_top_y + rise * (i + 1)
			var depth := STEP_DEPTH + (0.5 if i == STEP_COUNT - 1 else 0.0)   # top step tucks under the plinth's curve
			step.size = Vector3(STEP_WIDTH, top - _floor_top_y, depth)
			var near_edge := PLINTH_RADIUS - 0.5 + (STEP_COUNT - 1 - i) * STEP_DEPTH + (0.0 if i == STEP_COUNT - 1 else 0.5)
			step.rotation.y = atan2(d.x, d.z)
			step.position = d * (near_edge + depth * 0.5) + Vector3(0, (top + _floor_top_y) * 0.5 - PLINTH_TOP_Y, 0)
			step.material = base_mat
			dome.add_child(step)

	# Soft light inside so the levers can be seen.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.75, 0.9, 1.0)
	lamp.light_energy = 1.4
	lamp.omni_range = DOME_RADIUS + 1.0
	lamp.position = Vector3(0, DOME_HEIGHT - 1.5, 0)
	dome.add_child(lamp)

	# Levers toward the back (south), facing the north door: left (-X)
	# walls, right (+X) currents.
	for i in 2:
		var lever := Lever.new()
		lever.name = "Lever%d" % (i + 1)
		lever.handles_input = false
		lever.color_by_state = false
		add_child(lever)
		var side := -1.0 if i == 0 else 1.0
		lever.global_position = Vector3(_dome_site.x + side * 2.0, PLINTH_TOP_Y, _dome_site.z - 4.5)
		_dome_levers.append(lever)
		# Red light on a short post just outside the lever.
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.05
		post_mesh.bottom_radius = 0.07
		post_mesh.height = 0.9
		post.mesh = post_mesh
		post.material_override = _stone(Color(0.2, 0.22, 0.24))
		add_child(post)
		post.global_position = lever.global_position + Vector3(side * 0.9, 0.45, 0)
		var light := MeshInstance3D.new()
		var bulb := SphereMesh.new()
		bulb.radius = 0.14
		bulb.height = 0.28
		light.mesh = bulb
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 3.0
		light.material_override = mat
		add_child(light)
		light.global_position = post.global_position + Vector3(0, 0.55, 0)
		var glow := OmniLight3D.new()
		glow.omni_range = 2.0
		glow.light_energy = 1.2
		add_child(glow)
		glow.global_position = light.global_position + Vector3(0, 0, 0.3)
		_lever_lights.append(light)
		_lever_glows.append(glow)
		_set_lever_light(i, false)

func _set_lever_light(i: int, on: bool) -> void:
	var c := Color(0.2, 1.0, 0.35) if on else Color(1.0, 0.1, 0.1)
	var mat := _lever_lights[i].material_override as StandardMaterial3D
	mat.albedo_color = c
	mat.emission = c
	_lever_glows[i].light_color = c

func _lever_held_by(d: Diver) -> Lever:
	for lever in _lever_holders:
		if _lever_holders[lever] == d:
			return lever
	return null

func levers_map_mode() -> bool:
	return _lever_holders.size() == 2

# A lever nobody holds that the active diver is beside, standing on the
# dome's floor; or null.
func _free_lever_in_reach() -> Lever:
	if _diver == null:
		return null
	for lever in _dome_levers:
		if _lever_holders.has(lever):
			continue
		var offset := _diver.global_position - lever.global_position
		if _diver.global_position.y < PLINTH_TOP_Y - 0.6:
			continue
		offset.y = 0.0
		if offset.length() <= LEVER_REACH:
			return lever
	return null

# E for the levers. Returns true if it did something with them.
func _lever_e_pressed() -> bool:
	var held := _lever_held_by(_diver)
	if levers_map_mode() and held != null:
		release_all_levers()
		return true
	if held != null:
		_release_lever(held)
		return true
	var lever := _free_lever_in_reach()
	if lever != null:
		_hold_lever(lever, _diver)
		return true
	return false

func _hold_lever(lever: Lever, d: Diver) -> void:
	_lever_holders[lever] = d
	lever.pull()
	var i := _dome_levers.find(lever)
	_set_lever_light(i, true)
	_announce(LEVER_HINTS[i])

func _release_lever(lever: Lever) -> void:
	if not _lever_holders.has(lever):
		return
	_lever_holders.erase(lever)
	lever.pull()
	_set_lever_light(_dome_levers.find(lever), false)

func release_all_levers() -> void:
	for lever in _lever_holders.keys():
		_release_lever(lever)

# Keys while both levers are held (called by the minimap first). Returns
# true if the key was used up here.
# - Controlling a lever holder: E or Esc release both levers (closing the
#   map); L does nothing. Map keys and Tab work as normal.
# - Controlling the third diver, map closed: L opens the map; anything else
#   plays normally.
# - Third diver, map open: Esc or L close it; only the map's select/rotate
#   keys work, everything else is ignored.
func handle_lever_map_key(keycode: Key) -> bool:
	if not levers_map_mode():
		return false
	if _lever_held_by(_diver) != null:
		if keycode in [KEY_E, KEY_ESCAPE]:
			release_all_levers()
			return true
		return keycode == KEY_L
	if not _free_map_open:
		if keycode == KEY_L:
			_free_map_open = true
			return true
		return false
	if keycode in [KEY_ESCAPE, KEY_L]:
		_free_map_open = false
		return true
	return not keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_LEFT, KEY_RIGHT, KEY_R]

# The map header's close hint while the lever map is up.
func lever_map_close_hint() -> String:
	return "[Esc] / [E] Close" if _lever_held_by(_diver) != null else "[Esc] / [L] Close"

func _keycap_label(text: String, flash: bool) -> Label:
	var cap_label := Label.new()
	cap_label.text = " %s " % text
	cap_label.add_theme_font_size_override("font_size", 20)
	cap_label.add_theme_color_override("font_color", Color(0.05, 0.08, 0.1))
	var cap := StyleBoxFlat.new()
	cap.bg_color = Color(1.0, 0.85, 0.3)
	cap.set_corner_radius_all(5)
	cap.set_content_margin_all(4)
	cap_label.add_theme_stylebox_override("normal", cap)
	cap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_label.visible = false
	if flash:
		var tw := create_tween().set_loops()
		tw.tween_property(cap_label, "modulate:a", 0.25, 0.45)
		tw.tween_property(cap_label, "modulate:a", 1.0, 0.45)
	return cap_label

func _keycap_caption(cap_label: Label, text: String) -> Label:
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.position = Vector2(cap_label.get_minimum_size().x + 12.0, 4)
	caption.text = text
	cap_label.add_child(caption)
	return caption

# Whether the top-left "TAB switch diver" should flash: one lever held, or
# both held (not while the third diver has the map open - only the map works
# then).
func _tab_should_flash() -> bool:
	if _lever_holders.size() == 1:
		return true
	return levers_map_mode() and not _free_map_open

# Per frame: the hold panel, the [L] hint, and the lever map.
func _update_lever_ui() -> void:
	if _dome_levers.is_empty():
		return
	if _lever_panel == null:
		_lever_panel = LeverHoldPanel.new()
		_lever_panel.visible = false
		$HUD.add_child(_lever_panel)
		_map_hint = _keycap_label("L", true)
		$HUD.add_child(_map_hint)
		_keycap_caption(_map_hint, "open the wall / current map")
		_lever_map_controls = Label.new()
		_lever_map_controls.add_theme_font_size_override("font_size", 17)
		_lever_map_controls.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		_lever_map_controls.add_theme_constant_override("line_spacing", 6)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.03, 0.06, 0.08, 0.92)
		box.border_color = Color(0.3, 0.55, 0.95)
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		box.set_content_margin_all(12)
		_lever_map_controls.add_theme_stylebox_override("normal", box)
		_lever_map_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lever_map_controls.visible = false
		$HUD.add_child(_lever_map_controls)
		_release_levers_label = Label.new()
		_release_levers_label.text = "Press E to release levers"
		_release_levers_label.add_theme_font_size_override("font_size", 20)
		_release_levers_label.add_theme_color_override("font_color", Color.WHITE)
		_release_levers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_release_levers_label.position = Vector2(18, 76 + 500 + 6)
		_release_levers_label.size = Vector2(500, 30)
		_release_levers_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_release_levers_label.visible = false
		$HUD.add_child(_release_levers_label)
	var one_held := _lever_holders.size() == 1
	var map_mode := levers_map_mode()
	var on_lever := _lever_held_by(_diver) != null
	if not map_mode:
		_free_map_open = false
	var map_up := map_mode and (on_lever or _free_map_open)
	_lever_panel.visible = one_held and on_lever
	_map_hint.visible = map_mode and not on_lever and not _free_map_open
	_map_hint.position = Vector2(16, 66)
	_release_levers_label.visible = map_up and on_lever
	_lever_map_controls.visible = map_up
	if map_up:
		# Boxed list to the right of the map; "Press E to release levers"
		# sits under the map itself.
		var close_line := "[Esc]  close the map\n          (also releases the levers)" if on_lever else "[Esc] or [L]  close the map"
		_lever_map_controls.text = "WALLS\n  [Left] / [Right]  select\n  [Enter]  rotate\nCURRENTS\n  [Shift] + [Left] / [Right]  select\n  [R]  rotate\n" + close_line
		_lever_map_controls.size = Vector2.ZERO   # shrink to the current text
		_lever_map_controls.position = Vector2(536, 76)
	var minimap := $HUD.get_node_or_null("MazeMiniMap") as MazeMiniMap
	if minimap == null:
		return
	if map_up and not _lever_map_open:
		minimap.main_map.visible = true
		minimap._update_selected_rotatable_set()
		minimap.main_map.queue_redraw()
	elif not map_up and _lever_map_open:
		minimap.main_map.visible = false
	_lever_map_open = map_up

# --- Top-left controls (same as the main game's) ---------------------------
# World's top-left HUD: the active diver's name, then its controls line.
# "TAB switch diver" is its own label so it alone can flash (while a lever
# is held - see _tab_should_flash()). The maze's own status messages
# ($HUD/Controls) move to the bottom-left, above the Goal text.
const WORLD_CONTROLS_BEFORE_TAB := "WASD swim · SPACE up · SHIFT down · mouse or arrows look · "
const WORLD_CONTROLS_TAB := "TAB switch diver"
var _world_hud_name: Label
var _world_hud_tab: Label
var _world_hud_after: Label
var _world_hud_encounters: Label
var _world_hud_tail: Label
var _tab_flash: Tween

func _build_world_hud() -> void:
	var status := $HUD/Controls as Label
	# The bottom-left status line (hallway/current/wall messages) isn't shown:
	# the map and the orange announcements already say what changed.
	status.visible = false
	status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status.offset_left = 16.0
	status.offset_right = 900.0
	status.offset_top = -94.0
	status.offset_bottom = -66.0
	var column := VBoxContainer.new()
	column.position = Vector2(16, 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	$HUD.add_child(column)
	_world_hud_name = Label.new()
	column.add_child(_world_hud_name)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	column.add_child(row)
	var before := Label.new()
	before.text = WORLD_CONTROLS_BEFORE_TAB
	row.add_child(before)
	_world_hud_tab = Label.new()
	_world_hud_tab.text = WORLD_CONTROLS_TAB
	row.add_child(_world_hud_tab)
	_world_hud_after = Label.new()
	row.add_child(_world_hud_after)
	# Its own label so it can be greyed out in the danger zone (see
	# _update_world_hud()).
	_world_hud_encounters = Label.new()
	row.add_child(_world_hud_encounters)
	_world_hud_tail = Label.new()
	row.add_child(_world_hud_tail)
	for l in [_world_hud_name, before, _world_hud_tab, _world_hud_after, _world_hud_encounters, _world_hud_tail]:
		(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_world_hud() -> void:
	if _world_hud_name == null or _diver == null:
		return
	_world_hud_name.text = Cast.display_name(_diver.model_name)
	if target_selector != null and target_selector.selecting:
		var t := target_selector.current_target() as Diver
		_world_hud_name.text = "Swap with %s?   Left/Right: cycle  ·  Enter: confirm  ·  Esc: cancel" % (Cast.display_name(t.model_name) if t != null else "...")
	elif _aiming:
		_world_hud_name.text = "Aiming Grapple   Left click: fire  ·  Right click: cancel"
	var after := ""
	if _diver.ability_id != "":
		after += "  ·  E: %s" % String(_diver.ability_id).capitalize()
	if _diver.passive_id == "sonar":
		after += "  ·  Q: Sonar (%s)" % ("On" if _diver.sonar_active else "Off")
	_world_hud_after.text = after
	# In the danger zone (the strong-enemy room) encounters are forced on, so
	# R does nothing there: the hint greys out, still showing the setting
	# you left it on, and turns white again once you're out.
	_world_hud_encounters.text = "  ·  R: Encounters (%s)" % ("On" if random_encounters_enabled else "Off")
	_world_hud_encounters.modulate = Color(0.55, 0.57, 0.6) if is_diver_in_strong_room() else Color.WHITE
	_world_hud_tail.text = "  ·  L: Map"
	var flash := _tab_should_flash()
	if flash and _tab_flash == null:
		_tab_flash = create_tween().set_loops()
		_tab_flash.tween_property(_world_hud_tab, "modulate:a", 0.15, 0.4)
		_tab_flash.tween_property(_world_hud_tab, "modulate:a", 1.0, 0.4)
	elif not flash and _tab_flash != null:
		_tab_flash.kill()
		_tab_flash = null
		_world_hud_tab.modulate.a = 1.0

# --- Path button: walls 12/13 into line, path to the dome --------------------
# A red button on CSGBox3D8's inner face, near its west end, flashing until
# pressed (E within reach). Pressing it (once - it stays pressed, turns
# green) swings CSGBox3D12 into a straight line with CSGBox3D8 and
# CSGBox3D13 into a straight line with CSGBox3D9, each about its end at that
# corner - extending the Box8/Box9 passage west - and raises two walls that
# carry that passage on to the dome's east door. The passage is closed on
# both sides, so it only leads to the dome (and out its north door back
# toward the maze entrance), not into the open water around it.
# WindCorridor4 (and its whirlpool) stay where they are once 12/13 swing.
const PATH_BUTTON_REACH := 2.5
const PATH_BUTTON_FROM_END := 6.0     # along Box8 from its west end
var _path_button: Node3D
var _path_button_mat: StandardMaterial3D
var _path_button_glow: OmniLight3D
var _path_button_blink: Tween
var _path_opened := false

func _build_path_button() -> void:
	var box8 := $CSGBox3D8 as CSGBox3D
	var box9 := $CSGBox3D9 as CSGBox3D
	var g8: Dictionary = _wall_geometry(box8)
	var west: Vector3 = g8["negative_end"] if (g8["negative_end"] as Vector3).x < (g8["positive_end"] as Vector3).x else g8["positive_end"]
	var normal := Vector3(0, 0, 1) if box9.global_position.z > box8.global_position.z else Vector3(0, 0, -1)
	_path_button = Node3D.new()
	_path_button.name = "PathButton"
	add_child(_path_button)
	_path_button.global_position = Vector3(west.x + PATH_BUTTON_FROM_END, ($DiverEntry as Node3D).global_position.y + 1.0, box8.global_position.z) + normal * (box8.size.z * 0.5 + 0.06)
	_path_button.global_basis = Basis.looking_at(-normal, Vector3.UP)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(1.0, 1.0, 0.14)
	plate.mesh = plate_mesh
	plate.material_override = _stone(Color(0.12, 0.13, 0.15))
	_path_button.add_child(plate)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.3
	cap_mesh.bottom_radius = 0.33
	cap_mesh.height = 0.18
	cap.mesh = cap_mesh
	cap.rotation.x = PI * 0.5   # face out of the wall
	cap.position = Vector3(0, 0, 0.14)
	_path_button_mat = StandardMaterial3D.new()
	_path_button_mat.emission_enabled = true
	_path_button_mat.emission_energy_multiplier = 3.0
	cap.material_override = _path_button_mat
	_path_button.add_child(cap)
	_path_button_glow = OmniLight3D.new()
	_path_button_glow.omni_range = 2.5
	_path_button_glow.light_energy = 1.4
	_path_button_glow.position = Vector3(0, 0, 0.5)
	_path_button.add_child(_path_button_glow)
	_set_path_button_color(Color(1.0, 0.1, 0.1))
	_path_button_blink = create_tween().set_loops()
	_path_button_blink.tween_callback(func() -> void:
		cap.visible = not cap.visible
		_path_button_glow.visible = cap.visible)
	_path_button_blink.tween_interval(0.4)

func _set_path_button_color(c: Color) -> void:
	_path_button_mat.albedo_color = c
	_path_button_mat.emission = c
	_path_button_glow.light_color = c

func _path_button_in_reach() -> bool:
	if _path_button == null or _path_opened or _diver == null:
		return false
	var offset := _diver.global_position - _path_button.global_position
	offset.y = 0.0
	return offset.length() <= PATH_BUTTON_REACH and offset.dot(_path_button.global_basis.z) > 0.0

func _press_path_button() -> void:
	_path_opened = true
	_path_button_blink.kill()
	for c in _path_button.get_children():
		(c as Node3D).visible = true
	_set_path_button_color(Color(0.2, 1.0, 0.35))
	# Corridor4 no longer follows 12/13 once they swing (see above).
	_corridor_walls.erase($WindCorridor4)
	var tweens: Array = [
		_swing_wall_in_line_with($CSGBox3D12 as CSGBox3D, $CSGBox3D8 as CSGBox3D),
		_swing_wall_in_line_with($CSGBox3D13 as CSGBox3D, $CSGBox3D9 as CSGBox3D),
	]
	tweens.append_array(_raise_path_walls())
	_track_wall_set_motion("CSGBox3D12/13", tweens, [$CSGBox3D12, $CSGBox3D13])
	_announce("Walls 12 and 13 swing into line - a path opens toward the dome.")

# Swings `wall` a quarter turn about its end nearest `line_wall`'s west end
# so it ends up continuing line_wall's line westward from that end.
func _swing_wall_in_line_with(wall: CSGBox3D, line_wall: CSGBox3D) -> Tween:
	var gl: Dictionary = _wall_geometry(line_wall)
	var west: Vector3 = gl["negative_end"] if (gl["negative_end"] as Vector3).x < (gl["positive_end"] as Vector3).x else gl["positive_end"]
	var target := Vector3(west.x - wall.size.x * 0.5, wall.global_position.y, line_wall.global_position.z)
	var gw: Dictionary = _wall_geometry(wall)
	var hinge_end: Vector3 = gw["negative_end"] if (gw["negative_end"] as Vector3).distance_to(west) < (gw["positive_end"] as Vector3).distance_to(west) else gw["positive_end"]
	var from_dir := wall.global_position - hinge_end
	from_dir.y = 0.0
	from_dir = from_dir.normalized()
	var to_dir := Vector3(-1, 0, 0)
	var delta := atan2(from_dir.cross(to_dir).y, from_dir.dot(to_dir))
	return _tween_wall_to_transform_about_hinge(wall, target, wall.rotation.y + delta, 1.6)

# The two walls carrying the Box8/Box9 passage on to the dome: on Box9's
# line from where swung Box13 will end, and on Box8's line from where swung
# Box12 will end, each to the dome's plinth edge. They rise out of the floor.
func _raise_path_walls() -> Array:
	var tweens: Array = []
	for pair in [[$CSGBox3D9, $CSGBox3D13, "PathWallNorth"], [$CSGBox3D8, $CSGBox3D12, "PathWallSouth"]]:
		var line_wall := pair[0] as CSGBox3D
		var swung := pair[1] as CSGBox3D
		var gl: Dictionary = _wall_geometry(line_wall)
		var west_x := minf((gl["negative_end"] as Vector3).x, (gl["positive_end"] as Vector3).x)
		var east_x := west_x - swung.size.x
		var z := line_wall.global_position.z
		var dz := z - _dome_site.z
		var plinth_x := _dome_site.x + sqrt(maxf(PLINTH_RADIUS * PLINTH_RADIUS - dz * dz, 0.0)) - 0.4
		var y := line_wall.global_position.y
		var wall := _spawn_wall(String(pair[2]), Vector3((east_x + plinth_x) * 0.5, y - line_wall.size.y - 1.2, z), 0.0, Vector3(east_x - plinth_x, line_wall.size.y, line_wall.size.z))
		wall_boxes.append(wall)
		_add_wall_skirt(wall)
		var tw := create_tween()
		tw.tween_property(wall, "global_position:y", y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tweens.append(tw)
	return tweens

# --- Walls 17/27 -------------------------------------------------------------
# CSGBox3D17 and CSGBox3D27 (and the door gap that was between them) become
# one solid straight wall along their shared line: Box27 is stretched from
# its far end to Box17's far end, and Box17 is removed. (Wall 16 is the one
# with a door and a room behind it - see _split_wall_16().)
const DOOR_GAP_WIDTH := 2.3   # wall 16's door gap

func _rebuild_wall_17_27() -> void:
	var w17 := $CSGBox3D17 as CSGBox3D
	var w27 := $CSGBox3D27 as CSGBox3D
	var g17: Dictionary = _wall_geometry(w17)
	var g27: Dictionary = _wall_geometry(w27)
	var z17 := [(g17["negative_end"] as Vector3).z, (g17["positive_end"] as Vector3).z]
	var z27 := [(g27["negative_end"] as Vector3).z, (g27["positive_end"] as Vector3).z]
	# Each wall's far end is the one away from the other wall.
	var far17: float = z17[0] if absf(z17[0] - w27.global_position.z) > absf(z17[1] - w27.global_position.z) else z17[1]
	var far27: float = z27[0] if absf(z27[0] - w17.global_position.z) > absf(z27[1] - w17.global_position.z) else z27[1]
	_set_wall_span_z(w27, w27.global_position.x, far27, far17)
	wall_boxes.erase(w17)
	remove_child(w17)
	w17.queue_free()

# A small room off a north-south wall at x = line_x, around the door at
# door_z: a back wall `depth` away on the `side` (-1 west, +1 east), and two
# side walls from it back to the line, either side of the door. Height,
# thickness and centre height match `like`.
func _build_room_behind_door(like: CSGBox3D, line_x: float, door_z: float, side: float, depth: float, width: float, prefix: String) -> void:
	var t := like.size.z
	var y := like.global_position.y
	var h := like.size.y
	var back_x := line_x + side * depth
	var half := width * 0.5
	var back := _spawn_wall(prefix + "Back", Vector3(back_x, y, door_z), PI * 0.5, Vector3(width + t, h, t))
	var side_len := depth - t * 0.5
	var side_x := back_x - side * side_len * 0.5
	var north := _spawn_wall(prefix + "North", Vector3(side_x, y, door_z + half), 0.0, Vector3(side_len, h, t))
	var south := _spawn_wall(prefix + "South", Vector3(side_x, y, door_z - half), 0.0, Vector3(side_len, h, t))
	wall_boxes.append_array([back, north, south])

# CSGBox3D16 split in two with a door-width gap right in its middle, and a
# room behind the gap on the outside (east) of it, away from the passage
# between Box16 and Box17/27. CSGBox3D16 keeps the south half; the north
# half is a new wall, CSGBox3D16North.
const ROOM_16_DEPTH := 26.0   # the big sphere room (see _build_sphere_room())
const ROOM_16_WIDTH := 26.0

func _split_wall_16() -> void:
	var w16 := $CSGBox3D16 as CSGBox3D
	var g: Dictionary = _wall_geometry(w16)
	var z_a := (g["negative_end"] as Vector3).z
	var z_b := (g["positive_end"] as Vector3).z
	var z_lo := minf(z_a, z_b)
	var z_hi := maxf(z_a, z_b)
	var door_z := (z_lo + z_hi) * 0.5
	var line_x := w16.global_position.x
	var half_door := DOOR_GAP_WIDTH * 0.5
	var north := _spawn_wall("CSGBox3D16North", Vector3(line_x, w16.global_position.y, (door_z + half_door + z_hi) * 0.5), w16.rotation.y, Vector3(z_hi - door_z - half_door, w16.size.y, w16.size.z))
	wall_boxes.append(north)
	_set_wall_span_z(w16, line_x, z_lo, door_z - half_door)
	# East = away from the Box17/27 passage.
	var side := 1.0 if line_x > ($CSGBox3D27 as CSGBox3D).global_position.x else -1.0
	_build_room_behind_door(w16, line_x, door_z, side, ROOM_16_DEPTH, ROOM_16_WIDTH, "Room16")

# Re-spans a north-south wall along x = line_x between z0 and z1.
func _set_wall_span_z(wall: CSGBox3D, line_x: float, z0: float, z1: float) -> void:
	wall.size.x = absf(z1 - z0)
	wall.global_position = Vector3(line_x, wall.global_position.y, (z0 + z1) * 0.5)

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
	label.name = "GoalLabel"
	label.text = "Goal: open the hallway, follow the northbound channel into the reward chamber, then press E beside the cracked relic.\nWalls and currents only move from the maze map: L opens it; Left/Right picks a wall set and E rotates it; Shift+Left/Right picks a current and R moves it. Tab switches diver; E uses their ability (at the room switch: E interacts, Shift+E toggles room encounters)."
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.offset_left = 16.0
	label.offset_top = -64.0
	label.offset_right = 560.0
	label.offset_bottom = -16.0
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	# Not shown: the controls are in the top-left HUD and the map's help.
	label.visible = false
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
	}, {
		"name": "CSGBox3D14/15",
		"walls": [$CSGBox3D14, $CSGBox3D15],
		"rotate": _rotate_walls_14_15,
	}, {
		"name": "CSGBox3D10/11",
		"walls": [$CSGBox3D10, $CSGBox3D11],
		"rotate": _rotate_walls_10_11,
	}]

# Wall sets currently mid-swing (by name). A rotation request for a set that
# is still moving is ignored, so it can't be sent back the other way before
# it reaches the position it's rotating to.
var _moving_wall_sets: Dictionary = {}

func _wall_set_moving(set_name: String) -> bool:
	return _moving_wall_sets.has(set_name)

# `walls` are the walls the set moves - the camera frames them while they
# move (see _move_camera()), and the divers can't be steered meanwhile.
func _track_wall_set_motion(set_name: String, tweens: Array, walls: Array = []) -> void:
	var pending := tweens.filter(func(t) -> bool: return t is Tween and (t as Tween).is_valid())
	if pending.is_empty():
		return
	if _moving_wall_sets.is_empty():
		# Stop the divers dead as the walls start moving (currents can still
		# push them) - steering is off until they finish.
		for d in divers:
			d.velocity = Vector3.ZERO
	_moving_wall_sets[set_name] = pending.size()
	_moving_wall_nodes[set_name] = walls
	for tw in pending:
		(tw as Tween).finished.connect(func() -> void:
			_moving_wall_sets[set_name] = int(_moving_wall_sets.get(set_name, 1)) - 1
			if int(_moving_wall_sets[set_name]) <= 0:
				_moving_wall_sets.erase(set_name)
				_moving_wall_nodes.erase(set_name))

var _moving_wall_nodes: Dictionary = {}   # set name -> Array of the walls it's moving

# Moving walls are static colliders that a tween repositions every frame, so
# physics never pushes anything out of their way - a long wall swinging about
# one end (Box14's far end covers ~0.5m a frame) just passes through divers.
# Instead, every physics frame, any diver a moving wall now overlaps is
# pushed out of it to the side that wall is moving toward (so the wall drags
# it along), using where that part of the wall was last frame.
const SWEEP_MARGIN := 0.05
var _wall_last_xf: Dictionary = {}   # moving wall -> its transform last physics frame

func _sweep_divers_with_moving_walls() -> void:
	var still_moving: Dictionary = {}
	for set_name in _moving_wall_nodes:
		for w in _moving_wall_nodes[set_name]:
			if not is_instance_valid(w):
				continue
			var wall := w as CSGBox3D
			still_moving[wall] = true
			var xf := wall.global_transform
			var last: Transform3D = _wall_last_xf.get(wall, xf)
			var half := wall.size * 0.5
			for d in divers:
				if _wall_riders.has(d):
					# Already riding a wall: it turns with that wall, holding its
					# place against the face it was on.
					if _wall_riders[d] == wall:
						var carried := xf * (_rider_offsets[d] as Vector3)
						carried.y = d.global_position.y
						d.global_position = carried
					continue
				var r := d.radius + SWEEP_MARGIN
				var local := xf.affine_inverse() * d.global_position
				if absf(local.x) > half.x + r or absf(local.z) > half.z + r or absf(local.y) > half.y + d.height * 0.5:
					continue
				# Which way is this bit of the wall moving across its own
				# thickness? The diver goes on that face; if it isn't moving
				# sideways (e.g. a wall rising), the nearer face.
				var motion := xf * local - last * local
				var across := xf.basis.z.normalized()
				var side := signf(motion.dot(across))
				if absf(motion.dot(across)) < 0.001:
					side = signf(local.z) if local.z != 0.0 else 1.0
				var pushed := Vector3(local.x, local.y, side * (half.z + r))
				var target := xf * pushed
				target.y = d.global_position.y
				# From here on the diver rides this wall - turning with it, held
				# against that face, passing through any other wall, rock or
				# invisible barrier in the way - until it stops.
				_wall_riders[d] = wall
				_rider_offsets[d] = pushed
				d.velocity = Vector3.ZERO
				d.global_position = target
	_wall_last_xf.clear()
	for wall in still_moving:
		_wall_last_xf[wall] = (wall as CSGBox3D).global_transform
	# Riders whose wall has stopped are set down where it left them, or if
	# that's inside something, the nearest clear spot on the same side of the
	# wall that can be reached from there without crossing a wall or barrier.
	for d in _wall_riders.keys():
		if not still_moving.has(_wall_riders[d]):
			var wall := _wall_riders[d] as CSGBox3D
			var side := signf((_rider_offsets[d] as Vector3).z)
			_wall_riders.erase(d)
			_rider_offsets.erase(d)
			if is_instance_valid(d):
				d.global_position = _nearest_clear_spot(d, d.global_position, wall, side)
				d.velocity = Vector3.ZERO

var _wall_riders: Dictionary = {}     # diver -> the moving wall carrying it
var _rider_offsets: Dictionary = {}   # diver -> its spot in that wall's own frame

# `pos`, or the closest spot around it where the diver touches nothing. With
# `wall`, only spots on its `side` (the face the diver rode on) count, and
# only ones reachable from `pos` in a straight line without passing through a
# wall or barrier - so a diver is never set down on the far side of one.
func _nearest_clear_spot(d: Diver, pos: Vector3, wall: CSGBox3D = null, side := 0.0) -> Vector3:
	if not _diver_spot_blocked(d, pos, null):
		return pos
	var space := get_world_3d().direct_space_state
	for ring in range(1, 21):
		var dist := ring * 0.25
		for k in 24:
			var at := pos + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 24.0) * dist
			if wall != null and is_instance_valid(wall) and side != 0.0:
				if signf((wall.global_transform.affine_inverse() * at).z) != side:
					continue
			if _diver_spot_blocked(d, at, null):
				continue
			var ray := PhysicsRayQueryParameters3D.create(pos, at, 1)
			ray.exclude = [d.get_rid()]
			if not space.intersect_ray(ray).is_empty():
				continue
			return at
	return pos

# Would a diver at `pos` overlap anything solid other than `except` and the
# walls still moving? Maze walls by their boxes, plus a real physics overlap
# test for everything that isn't one - the split rock, the potion rock, the
# end caps and barriers built in code - so a diver is never shoved into, or
# set down inside, one of those.
func _diver_spot_blocked(d: Diver, pos: Vector3, except: CSGBox3D) -> bool:
	var r := d.radius + SWEEP_MARGIN
	var ignore: Array = [except]
	for set_name in _moving_wall_nodes:
		ignore.append_array(_moving_wall_nodes[set_name])
	for w in wall_boxes:
		if ignore.has(w) or not is_instance_valid(w) or not w.visible:
			continue
		var local := w.global_transform.affine_inverse() * pos
		var half := w.size * 0.5
		if absf(local.x) < half.x + r and absf(local.z) < half.z + r and absf(local.y) < half.y + d.height * 0.5:
			return true
	# The diver's own capsule, its bottom lifted a little so resting on the
	# floor doesn't count as blocked.
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = maxf(d.height - 0.2, r * 2.0 + 0.1)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.1, 0))
	q.collision_mask = 1
	q.exclude = [d.get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var collider: Object = hit.get("collider")
		if collider == null or ignore.has(collider):
			continue
		return true
	return false

func _rotate_hallway_1_2() -> void:
	if _wall_set_moving("CurrentWall1/2"):
		return
	var wall_a: CSGBox3D = $CurrentWall1
	var wall_b: CSGBox3D = $CurrentWall2
	if _hallway_1_2_swung:
		_track_wall_set_motion("CurrentWall1/2", [
			_tween_wall_to_transform_about_hinge(wall_a, _hallway_1_2_home_pos_a, _hallway_1_2_home_yaw_a),
			_tween_wall_to_transform_about_hinge(wall_b, _hallway_1_2_home_pos_b, _hallway_1_2_home_yaw_b),
		], [wall_a, wall_b])
		_hallway_1_2_swung = false
		$HUD/Controls.text = "Hallway closing..."
		_update_state_barriers()
		get_tree().create_timer(1.25).timeout.connect(func() -> void:
			if not _hallway_1_2_swung and not _completed:
				$HUD/Controls.text = "Hallway: CLOSED — open the map (L), pick the hallway walls and press E."
		)
		return
	_hallway_1_2_home_pos_a = wall_a.global_position
	_hallway_1_2_home_yaw_a = wall_a.rotation.y
	_hallway_1_2_home_pos_b = wall_b.global_position
	_hallway_1_2_home_yaw_b = wall_b.rotation.y
	_track_wall_set_motion("CurrentWall1/2", [
		_rotate_wall_flush(wall_a, $CSGBox3D),
		_rotate_wall_flush(wall_b, $CurrentWall3),
	], [wall_a, wall_b])
	_hallway_1_2_swung = true
	$HUD/Controls.text = "Hallway opening..."
	_update_state_barriers()
	get_tree().create_timer(1.25).timeout.connect(func() -> void:
		if _hallway_1_2_swung and not _completed:
			$HUD/Controls.text = "Hallway: OPEN."
	)

# Currents move independently of the walls (H only swings CurrentWall1/2):
#   C - WindCorridor1's current rotates into WindCorridor2, flowing east
#       (+X), and back. WindCorridor2 has no current of its own.
#   V - the current starts in WindCorridor3 pushing -Z (south), which blocks
#       the way forward from Corridor2. V moves it into WindCorridor4, where
#       it pushes -Z (CORRIDOR_4_FLOW) - the only way past the whirlpool at the back of
#       Corridor4 (see _setup_whirlpool()), but it then blocks Corridor3's
#       route the other way until it's moved back. V again returns it.
#   B - WindCorridor5's current (pushing -X) moves into WindCorridor6,
#       pushing -Z, and back to Corridor5 (-X) again.
var _current_1_in_2 := false
var _current_3_in_4 := false
var _current_5_in_6 := false
# Which way the current flows once it's in WindCorridor4. The whirlpool sits
# at that flow's downstream end so the current carries the diver through it.
const CORRIDOR_4_FLOW := WaterCurrent.Direction.NEGATIVE_Z

# Corridor1's current moves to WindCorridorBreakRock, pushing +Z (to
# WindCorridor2, +X, only if the scene has no WindCorridorBreakRock).
func _current_1_destination() -> Area3D:
	var break_rock := get_node_or_null("WindCorridorBreakRock") as Area3D
	return break_rock if break_rock != null else $WindCorridor2

func _toggle_current_1_to_2() -> void:
	var dest := _current_1_destination()
	if _current_1_in_2:
		_move_current(dest, $WindCorridor1, WaterCurrent.Direction.NEGATIVE_Z)
	else:
		_move_current($WindCorridor1, dest, WaterCurrent.Direction.POSITIVE_Z if dest != $WindCorridor2 else WaterCurrent.Direction.POSITIVE_X)
	_current_1_in_2 = not _current_1_in_2
	$HUD/Controls.text = ("Current moved to %s." % dest.name) if _current_1_in_2 else "Current moved back to WindCorridor1."

func _toggle_current_3_to_4() -> void:
	if _current_3_in_4:
		(_currents_by_corridor[$WindCorridor4] as WaterCurrent).carry_all_divers()
		_move_current($WindCorridor4, $WindCorridor3, WaterCurrent.Direction.NEGATIVE_Z)
	else:
		_move_current($WindCorridor3, $WindCorridor4, CORRIDOR_4_FLOW)
		# Carries anyone in Corridor4 (including divers who swim in later)
		# past the whirlpool.
		(_currents_by_corridor[$WindCorridor4] as WaterCurrent).carry_all_divers()
	_current_3_in_4 = not _current_3_in_4
	$HUD/Controls.text = "Current moved to WindCorridor4 - it carries you past the whirlpool." if _current_3_in_4 else "Current moved back to WindCorridor3."

func _toggle_current_5_to_6() -> void:
	if _current_5_in_6:
		_move_current($WindCorridor6, $WindCorridor5, WaterCurrent.Direction.NEGATIVE_X)
	else:
		_move_current($WindCorridor5, $WindCorridor6, WaterCurrent.Direction.NEGATIVE_Z)
	_current_5_in_6 = not _current_5_in_6
	$HUD/Controls.text = "Current moved to WindCorridor6." if _current_5_in_6 else "Current moved back to WindCorridor5."

var _current_7_in_8 := false

func _toggle_current_7_to_8() -> void:
	var c7 := get_node_or_null("WindCorridor7") as Area3D
	var c8 := get_node_or_null("WindCorridor8") as Area3D
	if c7 == null or c8 == null:
		$HUD/Controls.text = "WindCorridor7/8 aren't in the scene."
		return
	if _current_7_in_8:
		_move_current(c8, c7, WaterCurrent.Direction.NEGATIVE_Z)
	else:
		_move_current(c7, c8, WaterCurrent.Direction.POSITIVE_Z)
	_current_7_in_8 = not _current_7_in_8
	$HUD/Controls.text = "Current moved to WindCorridor8 (pushing +Z)." if _current_7_in_8 else "Current moved back to WindCorridor7 (pushing -Z)."

# R on the maze map: rotates whichever current is in `corridor` to its
# paired corridor - Corridor1 <-> 2 (C), Corridor3 <-> 4 (V),
# Corridor5 <-> 6 (B) and Corridor7 <-> 8 (N). Returns the corridor the current ended up in, or null if this
# current has nowhere to rotate to.
func rotate_current_in(corridor: Area3D) -> Area3D:
	if corridor == $WindCorridor1 or corridor == $WindCorridor2 or corridor == get_node_or_null("WindCorridorBreakRock"):
		_toggle_current_1_to_2()
		return _current_1_destination() if _current_1_in_2 else $WindCorridor1
	if corridor == $WindCorridor3 or corridor == $WindCorridor4:
		_toggle_current_3_to_4()
		return $WindCorridor4 if _current_3_in_4 else $WindCorridor3
	if corridor == $WindCorridor5 or corridor == $WindCorridor6:
		_toggle_current_5_to_6()
		return $WindCorridor6 if _current_5_in_6 else $WindCorridor5
	if has_node("WindCorridor7") and has_node("WindCorridor8") and (corridor == get_node("WindCorridor7") or corridor == get_node("WindCorridor8")):
		_toggle_current_7_to_8()
		return get_node("WindCorridor8") if _current_7_in_8 else get_node("WindCorridor7")
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
	_add_current($WindCorridor5, WaterCurrent.Direction.NEGATIVE_X)
	# Corridor7 pushes -Z; N (or R on the map) moves it to Corridor8, +Z.
	if has_node("WindCorridor7"):
		_add_current($WindCorridor7, WaterCurrent.Direction.NEGATIVE_Z)
	
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
	whirlpool.position = Vector3(35.99, -4.12, 71.67) + embed_offset
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
# Corridors in _corridor_walls that are also centred lengthwise between their
# walls (the rest keep their authored spot along the passage).
var _corridors_centred_lengthwise: Array[Area3D] = []
var _corridor_4_whirlpool: Whirlpool

func _align_corridors_to_walls() -> void:
	for corridor in _corridor_walls:
		var walls: Array = _corridor_walls[corridor]
		var shape_node := _corridor_shape(corridor as Area3D)
		if shape_node == null:
			continue
		_turn_corridor_along_walls(shape_node, walls[0])
		# Centred ACROSS the gap only - the corridor keeps its authored spot
		# along the passage (Box6/Box7 run 80 units, so centring lengthwise
		# would drag Corridor3 far from where it sits).
		var centre := _midpoint_between(walls[0], walls[1])
		var side := _wall_geometry(walls[0])["side_axis"] as Vector3
		side.y = 0.0
		var target := shape_node.global_position + side * (centre - shape_node.global_position).dot(side)
		if _corridors_centred_lengthwise.has(corridor):
			# Fully centred: across the gap and along the stretch where the
			# two walls face each other (height kept as authored).
			target = Vector3(centre.x, shape_node.global_position.y, centre.z)
		if not shape_node.global_position.is_equal_approx(target):
			shape_node.global_position = target
	_place_corridor_4_whirlpool()

# Rotates a corridor's collision box about Y so its long axis runs along
# `wall`'s long axis (either way along it), keeping its scale - so a
# corridor follows its walls if they're turned.
func _turn_corridor_along_walls(shape_node: CollisionShape3D, wall: CSGBox3D) -> void:
	var box := shape_node.shape as BoxShape3D
	var shape_basis := shape_node.global_transform.basis
	var long_local := Vector3.RIGHT if box.size.x * shape_basis.x.length() >= box.size.z * shape_basis.z.length() else Vector3.BACK
	var long_world := shape_basis * long_local
	long_world.y = 0.0
	var wall_axis := _wall_geometry(wall)["long_axis"] as Vector3
	wall_axis.y = 0.0
	if long_world.length_squared() < 0.0001 or wall_axis.length_squared() < 0.0001:
		return
	var angle := atan2(long_world.normalized().cross(wall_axis.normalized()).y, long_world.normalized().dot(wall_axis.normalized()))
	# Either direction along the wall is fine - take the smaller turn.
	if angle > PI * 0.5:
		angle -= PI
	elif angle < -PI * 0.5:
		angle += PI
	if absf(angle) < 0.001:
		return
	var xf := shape_node.global_transform
	xf.basis = Basis(Vector3.UP, angle) * xf.basis
	shape_node.global_transform = xf

func _corridor_shape(corridor: Area3D) -> CollisionShape3D:
	for child in corridor.get_children():
		if child is CollisionShape3D:
			return child
	return null

# WindCorridor4 and WindCorridorBreakRock, end to end in one straight line:
# the same size, on the same line (Corridor4's, between walls 12 and 13),
# meeting at the stub wall that joins wall 13 to wall 7 and overlapping
# there a little. Corridor4 runs north from the stub to the far end of wall
# 12, BreakRock the same length south. Their currents (-Z and +Z) then
# point in equal and opposite directions, away from each other.
const C4_BR_OVERLAP := 0.25

func _line_up_c4_and_break_rock() -> void:
	var break_rock := get_node_or_null("WindCorridorBreakRock") as Area3D
	var stub := get_node_or_null("CSGBox3DConnectorStub") as CSGBox3D
	var c4 := _corridor_shape($WindCorridor4 as Area3D)
	if break_rock == null or stub == null or c4 == null:
		return
	var br := _corridor_shape(break_rock)
	if br == null:
		return
	# North: the far end of the longer of its two walls (12, up to wall 8).
	var north := INF
	for w in _corridor_walls[$WindCorridor4]:
		var g: Dictionary = _wall_geometry(w)
		north = minf(north, minf((g["negative_end"] as Vector3).z, (g["positive_end"] as Vector3).z))
	var meet := stub.global_position.z
	var length := meet - north
	var basis := c4.global_basis.orthonormalized()
	var box := (c4.shape as BoxShape3D).duplicate() as BoxShape3D   # Corridor5 shares the original
	# Long side along the line (world Z), whichever local axis that is.
	var long_local_z := absf(basis.z.dot(Vector3(0, 0, 1))) > 0.7
	if long_local_z:
		box.size.z = length + C4_BR_OVERLAP
	else:
		box.size.x = length + C4_BR_OVERLAP
	c4.shape = box
	var x := c4.global_position.x
	var y := c4.global_position.y
	c4.global_transform = Transform3D(basis, Vector3(x, y, north + (length + C4_BR_OVERLAP) * 0.5))
	br.shape = box.duplicate()
	br.global_transform = Transform3D(basis, Vector3(x, y, meet - C4_BR_OVERLAP + (length + C4_BR_OVERLAP) * 0.5))

# A whirlpool across the back of WindCorridor4: the north end of the stretch
# where its two walls face each other (downstream for CORRIDOR_4_FLOW is the
# back). It swallows a diver and returns them to that stretch's south end -
# unless WindCorridor4 holds the current (V / R on the map), which carries
# the diver through it instead. Sized to the gap so it can't be swum around.
func _setup_corridor_4_whirlpool() -> void:
	var corridor := $WindCorridor4 as Area3D
	var walls: Array = _corridor_walls[corridor]
	var whirlpool := Whirlpool.new()
	# Fills the gap and then some, top to bottom, and drags anyone nearby in
	# - you can't just skim past it along a wall or over the top.
	whirlpool.suction_radius = _gap_width_between(walls[0], walls[1]) * 0.5 + 1.2
	whirlpool.suction_height = 12.0
	whirlpool.warning_radius = whirlpool.suction_radius + 5.0
	whirlpool.pull_radius = whirlpool.suction_radius + 4.0
	whirlpool.pull_speed = 4.0
	whirlpool.bypass = func() -> bool: return _currents_by_corridor.has(corridor)
	whirlpool.warned.connect(_on_whirlpool_warned)
	whirlpool.diver_sucked_in.connect(_on_diver_sucked_in)
	add_child(whirlpool)
	_corridor_4_whirlpool = whirlpool
	_place_corridor_4_whirlpool()

func _place_corridor_4_whirlpool() -> void:
	if _corridor_4_whirlpool == null or not _corridor_walls.has($WindCorridor4):
		return
	var walls: Array = _corridor_walls[$WindCorridor4]
	var ends := _overlap_ends_between(walls[0], walls[1])
	# Downstream end for Corridor4's flow is the back; upstream is the start.
	var flow := WaterCurrent.direction_to_vector(CORRIDOR_4_FLOW)
	var back: Vector3 = ends[0] if (ends[0] - ends[1]).dot(flow) > 0.0 else ends[1]
	var start: Vector3 = ends[1] if (ends[0] - ends[1]).dot(flow) > 0.0 else ends[0]
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
	_announce("You were sucked into the whirlpool! (-%d HP)" % amount)

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
			if String(box.name).begins_with("Floor_"):
				continue   # floors sit inside the level; Floor_Base spans its padded bounds
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
	# The lever dome isn't a CSGBox3D: add its plinth's square footprint
	# (and the steps out front) so the floor, ceiling and perimeter still
	# take it in now that CSGBox3D34/35/36 are gone.
	if _dome_site != Vector3.ZERO:
		var steps_out := PLINTH_RADIUS + STEP_COUNT * STEP_DEPTH
		for corner in [Vector3(-PLINTH_RADIUS, 0, -PLINTH_RADIUS), Vector3(steps_out, 0, -PLINTH_RADIUS), Vector3(-PLINTH_RADIUS, 0, steps_out), Vector3(steps_out, 0, steps_out)]:
			points.append(_dome_site + corner)
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
	var west_x := padded_min.x - _PERIMETER_THICKNESS * 0.5
	var z_lo := padded_min.z - _PERIMETER_THICKNESS
	var z_hi := padded_max.z + _PERIMETER_THICKNESS
	if world != null:
		# Part of the world: an opening on the start corridor's line, where
		# the way in from the open water arrives (see World's maze passage).
		var gap_z := ($DiverEntry as Node3D).global_position.z
		var g_lo := gap_z - EMBED_PASSAGE_HALF_WIDTH
		var g_hi := gap_z + EMBED_PASSAGE_HALF_WIDTH
		_build_invisible_wall(Vector3(west_x, wall_y, (z_lo + g_lo) * 0.5), Vector3(_PERIMETER_THICKNESS, _PERIMETER_WALL_HEIGHT, g_lo - z_lo))
		_build_invisible_wall(Vector3(west_x, wall_y, (g_hi + z_hi) * 0.5), Vector3(_PERIMETER_THICKNESS, _PERIMETER_WALL_HEIGHT, z_hi - g_hi))
	else:
		_build_invisible_wall(
			Vector3(west_x, wall_y, center_z),
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

	var regions := _raised_ceiling_regions()
	if regions.is_empty():
		_build_invisible_wall(
			Vector3(center_x, ceiling_y, center_z),
			Vector3(span_x, _CEILING_THICKNESS, span_z))
		return
	# Over some areas the ceiling is raised (the lever dome's tall shell, the
	# secret boss room's Tethys). The main ceiling is built as slabs around
	# those holes, thick enough to reach up to the highest cap, with a higher
	# cap over each hole - so nothing can swim up through a hole and out over
	# the maze. Slabs: split the ceiling into strips along x at every hole
	# edge, then each strip into runs along z that skip the holes over it.
	var bottom := ceiling_y - _CEILING_THICKNESS * 0.5
	var top_cap := bottom
	for region in regions:
		top_cap = maxf(top_cap, float(region[1]))
	var slab_top := top_cap + _CEILING_THICKNESS
	var slab_y := (bottom + slab_top) * 0.5
	var slab_h := slab_top - bottom
	var xs: Array[float] = [padded_min.x, padded_max.x]
	for region in regions:
		var r := region[0] as Rect2
		xs.append(clampf(r.position.x, padded_min.x, padded_max.x))
		xs.append(clampf(r.end.x, padded_min.x, padded_max.x))
	xs.sort()
	for i in xs.size() - 1:
		var xa := xs[i]
		var xb := xs[i + 1]
		if xb - xa < 0.001:
			continue
		var mid_x := (xa + xb) * 0.5
		var holes: Array = []
		for region in regions:
			var r := region[0] as Rect2
			if mid_x > r.position.x and mid_x < r.end.x:
				holes.append([r.position.y, r.end.y])
		holes.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]))
		var z := padded_min.z
		for hole in holes:
			if float(hole[0]) > z:
				_build_invisible_wall(Vector3(mid_x, slab_y, (z + float(hole[0])) * 0.5), Vector3(xb - xa, slab_h, float(hole[0]) - z))
			z = maxf(z, float(hole[1]))
		if padded_max.z > z:
			_build_invisible_wall(Vector3(mid_x, slab_y, (z + padded_max.z) * 0.5), Vector3(xb - xa, slab_h, padded_max.z - z))
	for region in regions:
		var r := region[0] as Rect2
		var cap := float(region[1])
		_build_invisible_wall(Vector3(r.get_center().x, cap + _CEILING_THICKNESS * 0.5, r.get_center().y), Vector3(r.size.x, _CEILING_THICKNESS, r.size.y))
		# Invisible walls around the raised area, from the normal ceiling up
		# to its cap - wherever its own walls are lower (or open), nothing
		# can swim up and out over the rest of the maze.
		var h := cap - bottom
		var y := bottom + h * 0.5
		_build_invisible_wall(Vector3(r.get_center().x, y, r.position.y), Vector3(r.size.x, h, 0.5))
		_build_invisible_wall(Vector3(r.get_center().x, y, r.end.y), Vector3(r.size.x, h, 0.5))
		_build_invisible_wall(Vector3(r.position.x, y, r.get_center().y), Vector3(0.5, h, r.size.y))
		_build_invisible_wall(Vector3(r.end.x, y, r.get_center().y), Vector3(0.5, h, r.size.y))

# Areas where the ceiling sits higher, as [floor-plan Rect2 (x, z), height of
# the raised ceiling's underside].
func _raised_ceiling_regions() -> Array:
	var out: Array = []
	if _dome_site != Vector3.ZERO:
		out.append([Rect2(_dome_site.x - PLINTH_RADIUS, _dome_site.z - PLINTH_RADIUS, PLINTH_RADIUS * 2.0, PLINTH_RADIUS * 2.0), PLINTH_TOP_Y + DOME_HEIGHT + 0.5])
	var room := _secret_boss_room_rect(false)
	if room.size != Vector2.ZERO:
		out.append([room, _maze_floor_top() + TETHYS_HOVER + TETHYS_TOP + TETHYS_HEADROOM])
	var item_room := _secret_item_room_rect()
	if item_room.size != Vector2.ZERO:
		var highest := _maze_floor_top()
		for marker_name in SECRET_ITEM_ROCKS:
			var m := get_node_or_null(String(marker_name)) as Node3D
			if m != null:
				highest = maxf(highest, m.global_position.y)
		var wall := $RewardChamberWestWall as CSGBox3D
		var wall_top := wall.global_position.y + wall.size.y * 0.5
		out.append([item_room, minf(highest + SECRET_ROCK_HEADROOM, wall_top - 0.5)])
	return out

# ============================================================
# A standalone swimmable diver for testing this level in isolation -
# this scene has no World node (that's what normally builds/drives one -
# see world.gd's own CAST loop and _physics_process()), so a minimal
# version of the same controls lives here instead: WASD relative to
# camera look, Space/Shift to rise/sink, click-drag to look around. Not
# meant to replace playing through world.gd for real - just enough to
# walk into WindCorridor1 and feel what it does.
# ============================================================

# The same three divers as World's CAST, in the same order. Tab switches
# which one you control (`active`); `_diver` is always the active one, so
# everything else in this file (camera, minimap, currents, whirlpools) just
# follows whoever is being played. Sonar/key-item reveals reach for a
# `world` and quietly do nothing here (see Diver.update_sonar()).
const MAZE_CAST := ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]
var divers: Array[Diver] = []
var active := 0
var _diver: Diver
var _yaw := 0.0
var _pitch := -0.16
var _cam_dist := 6.5
var _mouse_look := false

# Puts the party midway between two parallel walls (see _midpoint_between()):
# the active diver at the middle, the others a couple of metres either side
# along the passage. Keeps the spawn height from $DiverEntry.
func _place_diver_between(wall_a: CSGBox3D, wall_b: CSGBox3D) -> void:
	if divers.is_empty():
		return
	var spot := _midpoint_between(wall_a, wall_b)
	spot.y = $DiverEntry.global_position.y
	var along := _wall_geometry(wall_a)["long_axis"] as Vector3
	var offsets := [0.0, -2.5, 2.5]
	for i in range(divers.size()):
		var slot: int = (i - active + divers.size()) % divers.size()
		divers[i].global_position = spot + along * float(offsets[slot])

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

func _spawn_divers() -> void:
	if world != null:
		# Part of the world: its divers, and its items and keys (the same
		# dictionary/array, so whatever the maze adds or uses is the world's).
		for d in world.divers:
			divers.append(d as Diver)
			(d as Diver).encounter_triggered.connect(_on_diver_encounter.bind(d))
		inventory = world.inventory
		key_items = world.key_items
		active = int(world.active)
		_diver = divers[active]
		return
	for model in MAZE_CAST:
		var d := Diver.new()
		d.model_name = String(model)
		d.position = $DiverEntry.position
		add_child(d)
		d.encounter_triggered.connect(_on_diver_encounter.bind(d))
		divers.append(d)
	_diver = divers[active]

# Tab: control the next diver (World's same cycle order).
func _switch_diver() -> void:
	if target_selector != null and target_selector.selecting:
		target_selector.cancel_selection()
	active = (active + 1) % divers.size()
	_diver = divers[active]
	if world != null:
		world.active = active
	_announce("Now playing %s." % Cast.display_name(_diver.model_name))

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
	_update_strong_room_warning()
	if _diver == null:
		return
	for orb in goldenOrbs:
		if orb.position.y > _floor_top_y:
			orb.position.y = maxf(orb.position.y - GOLDEN_ORB_FALL_SPEED * dt, _floor_top_y)
	_sweep_divers_with_moving_walls()
	if _swirl_room != null and not _battling and not any_modal_open():
		_swirl_room.hit_divers(divers, dt)
	if not _battling and not any_modal_open():
		for d in divers:
			# Being carried by a moving wall (see _sweep_divers_with_moving_
			# walls()): no physics of its own, so other walls don't stop it.
			if _wall_riders.has(d):
				continue
			# Inactive divers still run swim() with no input, so currents and
			# drag keep acting on them (World does the same).
			# No steering while any walls are mid-rotation (_moving_wall_sets).
			if d == _diver and _lever_held_by(d) == null and not _free_map_open and _moving_wall_sets.is_empty() and not _gate_cutscene:
				d.swim(_player_dir(), _player_rise(), dt)
			else:
				d.swim(Vector3.ZERO, 0.0, dt)
	_update_room_switch()
	_update_lever_ui()
	_update_world_hud()
	_update_sonar_vision()
	_update_tethys_patrol(dt)
	_update_special_reveal()
	_update_save_point_prompt()
	_update_announce(dt)
	_check_split_rock()
	_update_secret_draft_prompt()
	if _aiming and (_battling or any_modal_open() or _gate_cutscene or not _moving_wall_sets.is_empty() or _free_map_open):
		_cancel_aim()
	_move_camera(dt)
	_update_aim_marker()

# Wall-rotation "cutscene": while any walls are rotating the camera pans up
# and over to look down on them, and frames them until they stop, then eases
# back behind the diver.
const CUTSCENE_PAN_RATE := 3.5      # camera position lerp rate while panning
const CUTSCENE_RETURN_TIME := 1.0   # seconds of easing back afterwards
var _cutscene_dir := Vector3.ZERO   # fixed horizontal viewing direction for this cutscene
var _cutscene_return := 0.0
var _cam_look := Vector3.ZERO

# [centre, span] of every wall currently rotating, or [] if none are.
func _rotating_walls_frame() -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var any := false
	for set_name in _moving_wall_nodes:
		for w in _moving_wall_nodes[set_name]:
			if not is_instance_valid(w):
				continue
			var g: Dictionary = _wall_geometry(w as CSGBox3D)
			for e in [g["negative_end"], g["positive_end"]]:
				lo = lo.min(e as Vector3)
				hi = hi.max(e as Vector3)
			any = true
	if not any:
		return []
	return [(lo + hi) * 0.5, maxf(hi.x - lo.x, hi.z - lo.z)]

# Overhead: the ceiling is invisible collision only, so the camera can rise
# well above the maze and look down at the walls at a steep angle - from the
# side it was already on, so the pan reads as continuous.
func _cutscene_camera(cam: Camera3D, frame: Array, dt: float) -> void:
	var focus := frame[0] as Vector3
	var span := float(frame[1])
	if _cutscene_dir == Vector3.ZERO:
		var away := cam.global_position - focus
		away.y = 0.0
		_cutscene_dir = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
	var height := clampf(span * 0.5 + 8.0, 10.0, 18.0)
	var want := focus + _cutscene_dir * height * 0.6 + Vector3(0, height, 0)
	cam.global_position = cam.global_position.lerp(want, clampf(dt * CUTSCENE_PAN_RATE, 0.0, 1.0))
	_cam_look = _cam_look.lerp(focus, clampf(dt * 3.0, 0.0, 1.0))
	cam.look_at(_cam_look, Vector3.UP)

func _move_camera(dt: float) -> void:
	var cam: Camera3D = $Camera3D
	if _gate_cutscene and _gate != null:
		if _cam_look == Vector3.ZERO:
			_cam_look = _diver.global_position
		var look := Vector3(_gate.global_position.x, _floor_top_y + 1.6, _gate.global_position.z)
		cam.global_position = cam.global_position.lerp(_gate_view_spot, clampf(dt * 2.5, 0.0, 1.0))
		_cam_look = _cam_look.lerp(look, clampf(dt * 3.0, 0.0, 1.0))
		cam.look_at(_cam_look, Vector3.UP)
		_cutscene_return = CUTSCENE_RETURN_TIME
		return
	var frame := _rotating_walls_frame()
	if not frame.is_empty():
		if _cam_look == Vector3.ZERO:
			_cam_look = _diver.global_position
		_cutscene_camera(cam, frame, dt)
		_cutscene_return = CUTSCENE_RETURN_TIME
		return
	_cutscene_dir = Vector3.ZERO
	var dir := _aim_dir()
	if _aiming:
		# The diver's own eye line - the height _grapple() fires from - so
		# what you see is what the raycast checks.
		var eye: Vector3 = _diver.global_position + Vector3(0, _diver.height * 0.4, 0)
		cam.global_position = cam.global_position.lerp(eye, clampf(dt * 14.0, 0.0, 1.0))
		_cam_look = eye + dir * 10.0
		cam.look_at(_cam_look, Vector3.UP)
		return
	var returning := _cutscene_return > 0.0
	_cutscene_return = maxf(_cutscene_return - dt, 0.0)
	var subject: Diver = _diver
	if _camera_focus_target is Diver and is_instance_valid(_camera_focus_target):
		subject = _camera_focus_target as Diver
	var focus: Vector3 = subject.global_position + Vector3(0, subject.height * 0.35, 0)
	var want: Vector3 = focus - dir * _cam_dist
	want.y = maxf(want.y, 0.6)
	# Don't let a wall (or the lever dome's shell) come between the camera
	# and the diver: pull the camera in to just short of whatever the line
	# back from the diver hits, at once rather than easing through it.
	var ray := PhysicsRayQueryParameters3D.create(focus, want, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		want = focus + (hit.position - focus) * 0.85
		if not returning and cam.global_position.distance_to(focus) > want.distance_to(focus):
			cam.global_position = want
	cam.global_position = cam.global_position.lerp(want, clampf(dt * (4.0 if returning else 8.0), 0.0, 1.0))
	# The look point eases back to the diver after a cutscene; otherwise it
	# just follows the diver.
	_cam_look = _cam_look.lerp(focus, clampf(dt * 5.0, 0.0, 1.0)) if returning else focus
	cam.look_at(_cam_look, Vector3.UP)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var key := (e as InputEventKey).keycode
		if save_point_menu != null and save_point_menu.visible and key in [KEY_P, KEY_ESCAPE]:
			save_point_menu.close()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_P and not _battling and not any_modal_open():
			_toggle_save_menu()
			get_viewport().set_input_as_handled()
			return
	# Esc opens / closes the inventory (as in the main game).
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_ESCAPE:
		if _aiming:
			_cancel_aim()
			get_viewport().set_input_as_handled()
			return
		if inventory_menu != null and inventory_menu.visible:
			inventory_menu.close()
			get_viewport().set_input_as_handled()
			return
		if not _battling and not any_modal_open() and inventory_menu != null and not (target_selector != null and target_selector.selecting):
			inventory_menu.open()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_mouse_look = false
			get_viewport().set_input_as_handled()
			return
	if _battling or any_modal_open():
		return
	# Grapple aim: left click fires, right click backs out. Tab and E wait
	# until the aim is fired or cancelled.
	if _aiming:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			match (e as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					_fire_aim()
					get_viewport().set_input_as_handled()
					return
				MOUSE_BUTTON_RIGHT:
					_cancel_aim()
					get_viewport().set_input_as_handled()
					return
		elif e is InputEventKey and (e as InputEventKey).keycode in [KEY_TAB, KEY_E]:
			get_viewport().set_input_as_handled()
			return
	# While choosing a swap target (the main game's TargetSelector): Left/
	# Right cycle, Enter confirms, Esc cancels.
	if target_selector != null and target_selector.selecting and e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		match (e as InputEventKey).keycode:
			KEY_RIGHT:
				target_selector.select_next()
				get_viewport().set_input_as_handled()
				return
			KEY_LEFT:
				target_selector.select_previous()
				get_viewport().set_input_as_handled()
				return
			KEY_ENTER, KEY_KP_ENTER:
				target_selector.confirm_selection()
				get_viewport().set_input_as_handled()
				return
			KEY_ESCAPE:
				target_selector.cancel_selection()
				get_viewport().set_input_as_handled()
				return
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
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_Q:
		# Maxilani's sonar, like the main game's Q.
		if _diver.passive_id == "sonar":
			_announce("Sonar %s." % ("on" if _diver.toggle_sonar() else "off"))
		else:
			_announce("Only Maxilani has sonar.")
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_R:
		# On the open map R moves the picked current instead (the map's own).
		var map := get_node_or_null("HUD/MazeMiniMap") as MazeMiniMap
		if map == null or not map.main_map.visible:
			_toggle_random_encounters()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_F1:
		if tutorial_book != null:
			tutorial_book.open(TutorialContent.GENERAL_PAGES)
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_TAB:
		_switch_diver()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_E:
		# While orange text from the last E interaction is up, E is on
		# cooldown (see _interact_cooldown).
		if _interact_cooldown:
			return
		var banner_text := _banner.text if _banner != null else ""
		var banner_time := _banner_timer
		_handle_e(e as InputEventKey)
		# This press put up (or renewed) orange text: cool down until it's gone.
		if _banner != null and _banner_timer > 0.0 and (_banner.text != banner_text or _banner_timer > banner_time):
			_interact_cooldown = true

# What E does where the diver is: the nearest thing to interact with, or
# else the active diver's ability.
func _handle_e(e: InputEventKey) -> void:
	if _lever_e_pressed():
		pass
	elif _path_button_in_reach():
		_press_path_button()
	elif _try_open_door():
		pass
	elif _vortex_chest_in_reach():
		_open_vortex_chest()
	elif _secret_entrance_in_reach():
		_open_secret_draft_prompt()
	elif _split_rock_in_reach():
		_announce("This rock looks broken in half. I wonder if something could split it open...", 5.0)
	elif _diver_near_switch() and (e as InputEventKey).shift_pressed:
		_toggle_room_encounters()
	elif _diver_near_switch() and not _switch_puzzle_done() and not _poster_beats_switch(_poster_in_reach()):
		_open_switch_minigame()
	elif _poster_in_reach() != null:
		_open_poster(_poster_in_reach())
	else:
		_use_active_ability()

# E away from the switch: the active diver's own ability, the same three
# World offers. Shockwave fires in place (and is how the relic is broken);
# grapple aims where the camera faces; swap trades places with the nearest
# other diver (World picks the target with TargetSelector instead).
func _use_active_ability() -> void:
	match _diver.ability_id:
		"grapple":
			# Like the main game: E goes into first-person aim, left click
			# fires, right click / Esc backs out (see _start_aim()).
			if _diver.can_use_ability():
				_start_aim()
		"swap":
			# Same as the main game: pick who to swap with first.
			if not target_selector.selecting and _diver.can_use_ability():
				target_selector.start_selection(_diver)
		_:
			_diver.use_ability()

# --- Grapple aim (World's first-person aim mode) ------------------------------
# E with the grapple diver cuts the camera to their eye line and hides their
# model (it would fill the view); a ring shows where the shot would land,
# green on a grapple anchor. Left click fires, right click / Esc cancels.
var _aiming := false
var _aiming_diver: Diver
var _aim_marker: MeshInstance3D
var _aim_marker_mat: StandardMaterial3D

# Where the camera looks, from yaw/pitch - also where the grapple fires.
func _aim_dir() -> Vector3:
	return Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch))

func _start_aim() -> void:
	_aiming = true
	_aiming_diver = _diver
	_aiming_diver.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_look = true

func _fire_aim() -> void:
	var d := _aiming_diver
	_cancel_aim()
	if d != null and is_instance_valid(d):
		d.use_ability(_aim_dir())

func _cancel_aim() -> void:
	_aiming = false
	if _aiming_diver != null and is_instance_valid(_aiming_diver):
		_aiming_diver.visible = true
	_aiming_diver = null

# The same raycast the grapple will fire, every frame while aiming - a
# preview of where the shot lands, not a hitbox.
func _update_aim_marker() -> void:
	if not _aiming:
		if _aim_marker != null:
			_aim_marker.visible = false
		return
	if _aim_marker == null:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.22
		ring.outer_radius = 0.32
		_aim_marker = MeshInstance3D.new()
		_aim_marker.mesh = ring
		_aim_marker_mat = StandardMaterial3D.new()
		_aim_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_aim_marker_mat.emission_enabled = true
		_aim_marker.material_override = _aim_marker_mat
		add_child(_aim_marker)
	var from: Vector3 = _diver.global_position + Vector3(0, _diver.height * 0.4, 0)
	var to: Vector3 = from + _aim_dir() * Diver.GRAPPLE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_diver.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = to if result.is_empty() else (result.position as Vector3)
	var on_target: bool = not result.is_empty() and (result.collider as Node).is_in_group("grapple_anchor")
	_aim_marker.visible = true
	_aim_marker.global_position = point
	_aim_marker.look_at(from, Vector3.UP)
	var c: Color = Color(0.35, 0.95, 0.4) if on_target else Color(0.75, 0.78, 0.8)
	_aim_marker_mat.albedo_color = c
	_aim_marker_mat.emission = c
	_aim_marker_mat.emission_energy_multiplier = 1.6 if on_target else 0.7

# --- Keys ---------------------------------------------------------------------
# Keys aren't tied to doors: each key opens any one door (KeyDoor spends it),
# and there are as many to find as there are doors.
var keys_held := 0

func _gain_key(id := "", text := "You've obtained a key") -> void:
	keys_held += 1
	if id != "" and not key_items.has(id):
		key_items.append(id)
	_announce(text, 4.0)

# --- State barriers -----------------------------------------------------------
# Invisible walls standing where a rotating wall set *would* be in its other
# position, so the open water it leaves can't be swum out into:
#  - CurrentWall1/2 closed (home): barriers along their swung lines, beside
#    CSGBox3D6 (not across the hallway itself).
#  - CSGBox3D14/15 swung toward the switch: barriers along their home lines,
#    east of wall 10's line (not across the new corridor between them).
const BARRIER_HEIGHT := 9.0
var _hallway_barriers: Array[CollisionShape3D] = []
var _walls_14_15_barriers: Array[CollisionShape3D] = []
var _wall_11_joint := Vector3.ZERO   # north end of wall 11 - where 14 meets it
var _wall_10_joint := Vector3.ZERO   # north end of wall 10 - where 15 meets it
var _walls_14_15_rest: Array = []    # [[wall, position, yaw]] at start

func _north_end(w: CSGBox3D) -> Vector3:
	var g: Dictionary = _wall_geometry(w)
	return g["negative_end"] if (g["negative_end"] as Vector3).z > (g["positive_end"] as Vector3).z else g["positive_end"]

func _build_state_barriers() -> void:
	_wall_11_joint = _north_end($CSGBox3D11)
	_wall_10_joint = _north_end($CSGBox3D10)
	for w in [$CSGBox3D14, $CSGBox3D15]:
		_walls_14_15_rest.append([w, (w as CSGBox3D).global_position, (w as CSGBox3D).rotation.y])
	var w1 := $CurrentWall1 as CSGBox3D
	var w2 := $CurrentWall2 as CSGBox3D
	var t := w1.size.z * 0.5
	var hall_lo := minf(w1.global_position.x, w2.global_position.x) - t
	var hall_hi := maxf(w1.global_position.x, w2.global_position.x) + t
	for pair in [[w1, $CSGBox3D], [w2, $CurrentWall3]]:
		var c: Dictionary = _nearest_wall_continuation(pair[0], pair[1])
		_hallway_barriers.append_array(_barrier_pieces("HallwayBarrier", c.position as Vector3, float(c.yaw), (pair[0] as CSGBox3D).size, hall_lo, hall_hi))
	var lane_lo := minf(_wall_11_joint.x, _wall_10_joint.x) - t
	var lane_hi := maxf(_wall_11_joint.x, _wall_10_joint.x) + t
	for w in [$CSGBox3D14, $CSGBox3D15]:
		var b := w as CSGBox3D
		_walls_14_15_barriers.append_array(_barrier_pieces("Walls1415Barrier", b.global_position, b.rotation.y, b.size, lane_lo, lane_hi))
	_update_state_barriers()

# Invisible boxes covering an east-west wall footprint (centre/yaw/size),
# minus the stretch between x = skip_lo and skip_hi.
func _barrier_pieces(base_name: String, center: Vector3, yaw: float, wall_size: Vector3, skip_lo: float, skip_hi: float) -> Array[CollisionShape3D]:
	var axis := Basis(Vector3.UP, yaw).x
	var a := center - axis * wall_size.x * 0.5
	var b := center + axis * wall_size.x * 0.5
	var lo := minf(a.x, b.x)
	var hi := maxf(a.x, b.x)
	var out: Array[CollisionShape3D] = []
	for span in [[lo, minf(hi, skip_lo)], [maxf(lo, skip_hi), hi]]:
		var x0: float = span[0]
		var x1: float = span[1]
		if x1 - x0 < 0.5:
			continue
		var body := StaticBody3D.new()
		body.name = "%s%d" % [base_name, get_child_count()]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(x1 - x0, BARRIER_HEIGHT, wall_size.z)
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		body.global_position = Vector3((x0 + x1) * 0.5, _floor_top_y + BARRIER_HEIGHT * 0.5, center.z)
		out.append(shape)
	return out

# Invisible wall carrying the generated CSGBox3DConnectorStub's line (the
# wall reaching over to Box7) on from its east end to wall 11's west face
# (where 11 starts), closing off the open area between walls 9, 11 and 13.
func _build_area_9_11_13_barrier() -> void:
	var stub := get_node_or_null("CSGBox3DConnectorStub") as CSGBox3D
	if stub == null:
		return
	var g: Dictionary = _wall_geometry(stub)
	var east_x := maxf((g["negative_end"] as Vector3).x, (g["positive_end"] as Vector3).x)
	var w11 := $CSGBox3D11 as CSGBox3D
	var end_x := _wall_11_joint.x - w11.size.z * 0.5
	if end_x - east_x < 0.5:
		return
	var body := StaticBody3D.new()
	body.name = "Area91113Barrier"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(end_x - east_x, BARRIER_HEIGHT, stub.size.z)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = Vector3((east_x + end_x) * 0.5, _floor_top_y + BARRIER_HEIGHT * 0.5, stub.global_position.z)

# Two fences on the open water around the start, leaving the way west to
# the lever dome open:
#  - beside CSGBox3D12: closes the pocket west of 12 between CurrentWall3's
#    line and wall 9's line (north of that is the path to the dome).
#  - behind the poster wall (HallwayEndWall): straight south from the start
#    wall's (CSGBox3D's) west end to the edge of the level, so the water
#    behind the CurrentWall1/2 hallway can't be swum round into.
func _build_start_area_barriers() -> void:
	var w3 := _wall_geometry($CurrentWall3 as CSGBox3D)
	var w3_west: Vector3 = w3["negative_end"] if (w3["negative_end"] as Vector3).x < (w3["positive_end"] as Vector3).x else w3["positive_end"]
	var b12 := $CSGBox3D12 as CSGBox3D
	var b12_x := b12.global_position.x - b12.size.z * 0.5
	var line9_z := ($CSGBox3D9 as CSGBox3D).global_position.z
	var t := 1.0
	# North side: wall 9's line from CurrentWall3's west end over to 12.
	_spawn_barrier("StartBarrierNorth", Vector3((w3_west.x + b12_x) * 0.5, 0, line9_z), Vector3(b12_x - w3_west.x + t, 0, t))
	# West side: down from there to CurrentWall3's west end.
	_spawn_barrier("StartBarrierWest", Vector3(w3_west.x - t * 0.5, 0, (line9_z + w3_west.z) * 0.5), Vector3(t, 0, absf(w3_west.z - line9_z) + t))
	# South of the start: from the start wall's west end to the level's edge.
	var start := _wall_geometry($CSGBox3D as CSGBox3D)
	var start_west: Vector3 = start["negative_end"] if (start["negative_end"] as Vector3).x < (start["positive_end"] as Vector3).x else start["positive_end"]
	var far_z := start_west.z
	for p in _collect_bounds_points():
		far_z = maxf(far_z, p.z)
	far_z += _PERIMETER_MARGIN
	_spawn_barrier("StartBarrierSouth", Vector3(start_west.x - t * 0.5, 0, (start_west.z + far_z) * 0.5), Vector3(t, 0, far_z - start_west.z))

# An invisible wall (floor to well above the walls) centred at `center`'s
# x/z, `footprint` x/z in size.
func _spawn_barrier(barrier_name: String, center: Vector3, footprint: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = barrier_name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(footprint.x, BARRIER_HEIGHT, footprint.z)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = Vector3(center.x, _floor_top_y + BARRIER_HEIGHT * 0.5, center.z)
	return body

func _update_state_barriers() -> void:
	for s in _hallway_barriers:
		s.set_deferred("disabled", _hallway_1_2_swung)
	for s in _walls_14_15_barriers:
		s.set_deferred("disabled", not _walls_14_15_open)

# --- Walls 10/11 ---------------------------------------------------------------
# The L map's third wall set. Each swings a quarter turn about its north end
# (where it meets 14 / 15) to run west, dead in line with 14's / 15's home
# line and flush against its end. Two more walls close off where their far
# ends land when swung - one down from swung 11's end to 10's line, one
# along that line to swung 10's end - and stay up either way. A potion rock
# sits in the corner they make.
var _walls_10_11_swung := false
var _walls_10_11_home: Array = []   # [[wall, position, yaw]]
var _wall_10_11_extras: Array[CSGBox3D] = []

func _walls_10_11_targets() -> Array:
	var out := []
	for pair in [[$CSGBox3D11, 0], [$CSGBox3D10, 1]]:
		var w := pair[0] as CSGBox3D
		var rest: Array = _walls_14_15_rest[pair[1]]
		var line_wall := rest[0] as CSGBox3D
		var line_pos := rest[1] as Vector3
		var west_x := line_pos.x - line_wall.size.x * 0.5
		out.append([w, Vector3(west_x - w.size.x * 0.5, w.global_position.y, line_pos.z), 0.0])
	return out

func _rotate_walls_10_11() -> void:
	if _wall_set_moving("CSGBox3D10/11"):
		return
	var tweens: Array = []
	if _walls_10_11_swung:
		for entry in _walls_10_11_home:
			tweens.append(_tween_wall_to_transform_about_hinge(entry[0], entry[1], entry[2]))
		_walls_10_11_swung = false
		$HUD/Controls.text = "Walls 10/11 swinging back..."
	else:
		_walls_10_11_home.clear()
		for w in [$CSGBox3D11, $CSGBox3D10]:
			_walls_10_11_home.append([w, (w as CSGBox3D).global_position, (w as CSGBox3D).rotation.y])
		for target in _walls_10_11_targets():
			tweens.append(_tween_wall_to_transform_about_hinge(target[0], target[1], target[2]))
		_walls_10_11_swung = true
		$HUD/Controls.text = "Walls 10/11 swinging..."
	_track_wall_set_motion("CSGBox3D10/11", tweens, [$CSGBox3D10, $CSGBox3D11])

func _build_wall_10_11_extras() -> void:
	var targets := _walls_10_11_targets()
	var w11 := $CSGBox3D11 as CSGBox3D
	var t := w11.size.z
	var end11_x := (targets[0][1] as Vector3).x - w11.size.x * 0.5   # swung 11's west end
	var line10_z := (targets[1][1] as Vector3).z
	var line11_z := (targets[0][1] as Vector3).z
	var end10_x := (targets[1][1] as Vector3).x - ($CSGBox3D10 as CSGBox3D).size.x * 0.5
	var y := w11.global_position.y
	# Down from swung 11's end to 10's line (capping both).
	var a_x := end11_x - t * 0.5
	var a_len := absf(line11_z - line10_z) + t
	var wall_a := _spawn_wall("Wall11EndCap", Vector3(a_x, y, (line11_z + line10_z) * 0.5), PI * 0.5, Vector3(a_len, w11.size.y, t))
	# Along 10's line from that wall to swung 10's end.
	var b_x0 := a_x - t * 0.5
	var wall_b := _spawn_wall("Wall10Closer", Vector3((b_x0 + end10_x) * 0.5, y, line10_z), 0.0, Vector3(absf(end10_x - b_x0), w11.size.y, t))
	# Always standing, whichever way walls 10/11 face.
	for wall in [wall_a, wall_b]:
		_wall_10_11_extras.append(wall)
		wall_boxes.append(wall)
	# The potion rock, in the inside corner of the two.
	var r := 0.55
	var inward_z := signf(line11_z - line10_z)
	var spot := Vector3(a_x + t * 0.5 + r + 0.25, _floor_top_y + r, line10_z + inward_z * (t * 0.5 + r + 0.25))
	var rock := CrackedWall.new()
	rock.span = Vector3(1.1, 1.1, 1.1)
	rock.disguised_as_scenery_rock = true
	rock.position = spot
	rock.broken.connect(_on_secret_rock_broken.bind("potion", spot + Vector3(0, 0.6, 0)))
	add_child(rock)

# --- Progress gate (switch puzzle) --------------------------------------------
# Bars across the passage between CSGBox3D20 and CSGBox3D21, halfway along
# where they face each other. Solving the portrait puzzle at the room switch
# lowers it into the floor.
var _gate: StaticBody3D
var _gate_lowered := false
var _gate_cutscene := false
var _gate_view_spot := Vector3.ZERO   # where the cutscene camera watches it from

func _build_progress_gate() -> void:
	var b20 := get_node_or_null("CSGBox3D20") as CSGBox3D
	var b21 := get_node_or_null("CSGBox3D21") as CSGBox3D
	if b20 == null or b21 == null:
		return
	var centre := _midpoint_between(b20, b21)
	var across := _wall_geometry(b20)["side_axis"] as Vector3
	across.y = 0.0
	across = across.normalized()
	var width := _gap_width_between(b20, b21) + 1.0
	var height := 6.4
	var thickness := 0.5
	_gate = StaticBody3D.new()
	_gate.name = "ProgressGate"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, thickness)
	shape.shape = box
	_gate.add_child(shape)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.22, 0.25)
	metal.metallic = 0.85
	metal.roughness = 0.35
	var bars := int(width / 0.55)
	for i in bars + 1:
		var bar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.07
		cyl.height = height
		bar.mesh = cyl
		bar.material_override = metal
		bar.position = Vector3(-width * 0.5 + width * float(i) / float(bars), 0, 0)
		_gate.add_child(bar)
	for y in [-height * 0.5 + 0.3, 0.0, height * 0.5 - 0.3]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(width, 0.18, 0.22)
		rail.mesh = rail_mesh
		rail.material_override = metal
		rail.position = Vector3(0, y, 0)
		_gate.add_child(rail)
	add_child(_gate)
	_gate.global_basis = Basis(across, Vector3.UP, across.cross(Vector3.UP))
	_gate.global_position = Vector3(centre.x, _floor_top_y + height * 0.5, centre.z)
	var toward_switch := Vector3(0, 0, -1)
	if _switch_node != null:
		toward_switch = _switch_node.global_position - _gate.global_position
		toward_switch.y = 0.0
		toward_switch = toward_switch.normalized()
	var along := across.cross(Vector3.UP).normalized()
	if along.dot(toward_switch) < 0.0:
		along = -along
	_gate_view_spot = Vector3(centre.x, _floor_top_y + 3.2, centre.z) + along * 9.0

const DEV_KEYS := ["sphere_room_key", "vortex_key", "split_rock_key", "abyss_key"]

func _apply_dev_unlocks() -> void:
	for id in DEV_KEYS:
		if not key_items.has(id):
			key_items.append(id)
	keys_held = DEV_KEYS.size()
	# The gate, down with no cutscene.
	if _gate != null and not _gate_lowered:
		_gate_lowered = true
		_mark_switch_done()
		_gate.visible = false
		for c in _gate.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
	print("DEV MODE: all keys, gate open")

func _lower_gate() -> void:
	if _gate == null or _gate_lowered:
		return
	_gate_lowered = true
	_mark_switch_done()
	# Cutscene: the camera swings over to the gate (divers can't be steered
	# meanwhile), watches it sink into the floor, then eases back.
	_gate_cutscene = true
	var tw := create_tween()
	tw.tween_interval(1.2)   # the camera getting there
	tw.tween_property(_gate, "global_position:y", _gate.global_position.y - 6.6, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_gate.visible = false
		for c in _gate.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true)
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void: _gate_cutscene = false)

# E in the minigame: close it and start a fresh one.
func _retry_switch_minigame() -> void:
	if switch_modal_open():
		_switch_modal.close()
	await get_tree().process_frame
	_open_switch_minigame()

# After a wrong answer: every poster gets a new number (a different order
# from before), so the next try has to follow the posters again. The
# posters (and the Clues list in the puzzle) show the new numbers.
func _reshuffle_poster_numbers() -> void:
	var old: Array = _posters.map(func(p: MazePoster) -> int: return p.number)
	var numbers: Array = old.duplicate()
	while numbers == old:
		numbers.shuffle()
	for i in _posters.size():
		_posters[i].number = int(numbers[i])
	for clue in poster_clues:
		for p in _posters:
			if p.diver_index == int(clue["diver"]):
				clue["number"] = p.number

# Every portrait settled on its own line: right if each diver's portrait
# landed on the number its poster shows.
func _on_switch_puzzle_arrived() -> void:
	if not switch_modal_open():
		return
	var correct := true
	var placed: Array = [false, false, false]   # per portrait (= diver)
	for p in _posters:
		placed[p.diver_index] = _switch_modal.lane[p.diver_index] + 1 == p.number
		if not placed[p.diver_index]:
			correct = false
	_switch_modal.show_result(correct, placed)
	if not correct:
		_reshuffle_poster_numbers()
		_switch_modal.set_result_text("Not quite... The portraits' numbers have changed! (E to try again, Esc to close)")
		return
	var modal := _switch_modal
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(modal):
			modal.close()
		_lower_gate())

# Third poster: on wall 19's room face, a little east of the switch box.
# On the same wall the switch stands against (RewardChamberWestWall, whose
# face is the one you see there - it overlaps wall 19's start), on the open
# stretch just beside the switch.
func _switch_poster_spot() -> Array:
	var wall := $RewardChamberWestWall as CSGBox3D
	var g: Dictionary = _wall_geometry(wall)
	var neg := g["negative_end"] as Vector3
	var pos := g["positive_end"] as Vector3
	var x := _switch_node.global_position.x + 2.4
	var t := clampf((x - neg.x) / (pos.x - neg.x), 0.05, 0.95)
	var toward := _switch_node.global_position - wall.global_position
	toward.y = 0.0
	return _poster_spot_on(wall, Vector3(0, 0, signf(toward.z)), t)

# --- The split rock -------------------------------------------------------------
# A big rock cracked clean in half at the start of wall 10 (its wall-8 end).
# E beside it just wonders about it. It splits once two opposite currents
# are running at the same time: WindCorridor4's (-Z) and
# WindCorridorBreakRock's (+Z, Corridor1's current moved there with R) - a
# short cutscene with the world paused: the halves wrench apart and crumble,
# and a shining key hops out and bounces to a stop, there to be picked up.
const SPLIT_ROCK_RADIUS := 1.5
const SPLIT_ROCK_REACH := 2.6
var _split_rock: Node3D
var _split_halves: Array[Node3D] = []   # each half's pivot (at the bottom of the split)
var _rock_split := false

func _build_split_rock() -> void:
	var b10 := $CSGBox3D10 as CSGBox3D
	var b8 := $CSGBox3D8 as CSGBox3D
	var start := _wall_geometry(b10)["negative_end"] as Vector3
	var other := _wall_geometry(b10)["positive_end"] as Vector3
	if other.distance_to(b8.global_position) < start.distance_to(b8.global_position):
		start = other
	var into_x := signf($CSGBox3D11.global_position.x - b10.global_position.x)
	var into_z := signf(b10.global_position.z - start.z)
	var offset := b10.size.z * 0.5 + SPLIT_ROCK_RADIUS + 0.2
	_split_rock = Node3D.new()
	_split_rock.name = "SplitRock"
	add_child(_split_rock)
	_split_rock.global_position = Vector3(start.x + into_x * offset, _floor_top_y + SPLIT_ROCK_RADIUS * 0.8, start.z + into_z * offset)
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true   # weathered outside, raw broken faces
	stone.roughness = 1.0
	# Fission-split look: two lumpy, faceted halves cleaved apart in a V
	# (touching at the bottom, open at the top) with rough, jagged broken
	# faces, rubble at the foot, and a hot glowing fissure between them with
	# light spilling out.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.6, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.45, 0.1)
	glow.emission_energy_multiplier = 4.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for side in [1.0, -1.0]:
		# Pivot at the bottom of the split, so the half leans out from there.
		var pivot := Node3D.new()
		pivot.position = Vector3(0, -SPLIT_ROCK_RADIUS * 0.75, side * 0.12)
		pivot.rotation.x = side * 0.2
		_split_rock.add_child(pivot)
		var half := MeshInstance3D.new()
		half.mesh = _broken_half_mesh(SPLIT_ROCK_RADIUS, rng)
		half.material_override = stone
		half.rotation.x = side * PI * 0.5        # domes face +Z / -Z, broken faces toward each other
		half.rotation.y = 0.12 * side
		half.scale = Vector3(1.12, 0.92, 0.95)   # less of a ball
		half.position = Vector3(0, SPLIT_ROCK_RADIUS * 0.75, 0)
		pivot.add_child(half)
		_split_halves.append(pivot)
	var crack := Node3D.new()
	crack.name = "Crack"
	_split_rock.add_child(crack)
	# The glowing fissure: a zigzag of hot shards up the middle, a thin hot
	# sheet behind them, and the light leaking out.
	var sheet := MeshInstance3D.new()
	var sheet_mesh := CylinderMesh.new()
	sheet_mesh.top_radius = SPLIT_ROCK_RADIUS * 0.8
	sheet_mesh.bottom_radius = SPLIT_ROCK_RADIUS * 0.8
	sheet_mesh.height = 0.06
	sheet.mesh = sheet_mesh
	sheet.rotation.x = PI * 0.5   # a disc in the split
	var sheet_mat := glow.duplicate() as StandardMaterial3D
	sheet_mat.emission_energy_multiplier = 2.0
	sheet.material_override = sheet_mat
	sheet.position = Vector3(0, -SPLIT_ROCK_RADIUS * 0.05, 0)
	crack.add_child(sheet)
	var y := -SPLIT_ROCK_RADIUS * 0.7
	var x := 0.0
	while y < SPLIT_ROCK_RADIUS * 0.6:
		var step := rng.randf_range(0.22, 0.38)
		var nx := clampf(x + rng.randf_range(-0.45, 0.45), -SPLIT_ROCK_RADIUS * 0.6, SPLIT_ROCK_RADIUS * 0.6)
		var a := Vector3(x, y, 0)
		var b := Vector3(nx, y + step, 0)
		var bolt := MeshInstance3D.new()
		var bolt_mesh := BoxMesh.new()
		bolt_mesh.size = Vector3(0.09, a.distance_to(b) + 0.06, 0.32)
		bolt.mesh = bolt_mesh
		bolt.material_override = glow
		bolt.position = (a + b) * 0.5
		bolt.rotation.z = atan2(-(b.x - a.x), b.y - a.y)
		crack.add_child(bolt)
		x = nx
		y += step
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.5
	light.omni_range = 5.0
	light.position = Vector3(0, 0.6, 0)
	crack.add_child(light)
	var pulse := light.create_tween().set_loops()
	pulse.tween_property(light, "light_energy", 4.0, 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(light, "light_energy", 1.8, 0.7).set_trans(Tween.TRANS_SINE)
	var sheet_pulse := sheet.create_tween().set_loops()
	sheet_pulse.tween_property(sheet_mat, "emission_energy_multiplier", 3.5, 0.7).set_trans(Tween.TRANS_SINE)
	sheet_pulse.tween_property(sheet_mat, "emission_energy_multiplier", 1.5, 0.7).set_trans(Tween.TRANS_SINE)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SPLIT_ROCK_RADIUS
	shape.shape = sphere
	body.add_child(shape)
	body.name = "Body"
	_split_rock.add_child(body)
	# Rubble knocked off around its foot.
	for i in 7:
		var chunk := MeshInstance3D.new()
		chunk.mesh = _broken_half_mesh(rng.randf_range(0.14, 0.3), rng)
		chunk.material_override = stone
		var a := rng.randf() * TAU
		var r := SPLIT_ROCK_RADIUS * rng.randf_range(1.0, 1.5)
		chunk.position = Vector3(cos(a) * r, -SPLIT_ROCK_RADIUS * 0.8 + 0.05, sin(a) * r)
		chunk.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		_split_rock.add_child(chunk)
	# It belongs to wall 10: when 10/11 swing on the map, it swings along.
	_split_rock.reparent(b10, true)

func _split_rock_in_reach() -> bool:
	if _split_rock == null or _rock_split or _diver == null:
		return false
	var a := _split_rock.global_position
	var b := _diver.global_position
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) <= SPLIT_ROCK_RADIUS + SPLIT_ROCK_REACH

func _check_split_rock() -> void:
	_update_rock_pull_stream()
	if _rock_split or _split_rock == null or _battling or any_modal_open():
		return
	var break_rock := get_node_or_null("WindCorridorBreakRock") as Area3D
	if break_rock == null:
		return
	# Only once the rock's hallway (walls 10/11) has swung over and come to
	# rest on the line where the two currents meet - not while it's still
	# away at home, however the currents are set.
	if not _rock_over_currents():
		return
	var a: WaterCurrent = _currents_by_corridor.get($WindCorridor4, null)
	var b: WaterCurrent = _currents_by_corridor.get(break_rock, null)
	if a == null or b == null or a.orientation.dot(b.orientation) > -0.9:
		return
	_play_split_rock_cutscene()

func _rock_over_currents() -> bool:
	return _walls_10_11_swung and not _wall_set_moving("CSGBox3D10/11")

# While the rock sits over the currents' line and C4 holds a current, C4's
# pull is drawn reaching all the way to the rock - dense, bright streaks from
# the rock off along C4's flow - so it reads from the far side of the wall too.
var _rock_pull_stream: GPUParticles3D

func _update_rock_pull_stream() -> void:
	var c4_current: WaterCurrent = _currents_by_corridor.get($WindCorridor4, null)
	var show := not _rock_split and _split_rock != null and c4_current != null and _rock_over_currents()
	if not show:
		if _rock_pull_stream != null:
			_rock_pull_stream.emitting = false
		return
	if _rock_pull_stream == null:
		_rock_pull_stream = _build_rock_pull_stream()
	_rock_pull_stream.global_position = _split_rock.global_position + Vector3(0, 0.4, 0)
	var pm := _rock_pull_stream.process_material as ParticleProcessMaterial
	var flow := c4_current.orientation
	flow.y = 0.0
	pm.direction = flow.normalized() if flow.length() > 0.01 else Vector3.FORWARD
	_rock_pull_stream.emitting = true

func _build_rock_pull_stream() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.2, 1.4, 1.2)
	pm.spread = 6.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3.ZERO
	pm.particle_flag_align_y = true
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.97, 1.0, 0.0))
	fade.set_color(1, Color(0.8, 0.97, 1.0, 0.0))
	fade.add_point(0.1, Color(0.85, 0.98, 1.0, 0.95))
	fade.add_point(0.85, Color(0.65, 0.9, 1.0, 0.6))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	var streak := BoxMesh.new()
	streak.size = Vector3(0.05, 0.8, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	streak.material = mat
	var stream := GPUParticles3D.new()
	stream.name = "RockPullStream"
	stream.amount = 140
	stream.lifetime = 2.4
	stream.process_material = pm
	stream.draw_pass_1 = streak
	stream.visibility_aabb = AABB(Vector3(-20, -3, -20), Vector3(40, 6, 40))
	add_child(stream)
	return stream

func _play_split_rock_cutscene() -> void:
	_rock_split = true
	var minimap := get_node_or_null("HUD/MazeMiniMap")
	if minimap != null and minimap.get("main_map") != null:
		(minimap.main_map as Control).visible = false
	get_tree().paused = true
	var director := Node.new()
	director.name = "SplitRockCutscene"
	director.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(director)
	_split_rock.process_mode = Node.PROCESS_MODE_ALWAYS
	if _banner != null:
		_banner.visible = false
	if _switch_prompt != null:
		_switch_prompt.visible = false
	var cam := $Camera3D as Camera3D
	var rock := _split_rock.global_position
	# Viewed from the corridor side - turned along with wall 10 if it's swung.
	var view_dir := _split_rock.global_basis * Vector3(-0.35, 0, 1.0)
	view_dir.y = 0.0
	view_dir = view_dir.normalized()
	var cam_to := rock + view_dir * 7.5 + Vector3(0, 3.2, 0)
	var cam_from := cam.global_position
	var look_from := _cam_look if _cam_look != Vector3.ZERO else rock
	var land := rock + view_dir * 3.6
	land.y = _floor_top_y + 0.7
	var tw := director.create_tween()
	# Camera swoops over to the rock.
	tw.tween_method(func(f: float) -> void:
		cam.global_position = cam_from.lerp(cam_to, f)
		cam.look_at(look_from.lerp(rock, f), Vector3.UP), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Rumble.
	tw.tween_method(func(f: float) -> void:
		var shake := sin(f * 70.0) * 0.07 * (0.4 + f)
		_split_rock.global_position = rock + Vector3(shake, 0, -shake * 0.6)
		cam.global_position = cam_to + Vector3(0, sin(f * 55.0) * 0.05, 0)
		cam.look_at(rock, Vector3.UP), 0.0, 1.0, 1.1)
	# Wrench apart - each half flung along its current, tumbling.
	tw.tween_callback(func() -> void:
		_split_rock.global_position = rock
		var crack := _split_rock.get_node_or_null("Crack")
		if crack != null:
			crack.queue_free()
		var body := _split_rock.get_node_or_null("Body")
		if body != null:
			body.queue_free()
		_burst(rock))
	var rest: Array = []
	for h in _split_halves:
		rest.append([h.position, h.rotation])
	tw.tween_method(func(f: float) -> void:
		for i in _split_halves.size():
			var side := 1.0 if i == 0 else -1.0
			var h := _split_halves[i]
			h.position = (rest[i][0] as Vector3) + Vector3(side * 0.6 * f, sin(f * PI) * 1.2, side * 3.2 * f)
			h.rotation = (rest[i][1] as Vector3) + Vector3(side * 1.3 * f, side * 0.8 * f, side * 0.9 * f)
		cam.look_at(rock, Vector3.UP), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Crumble away.
	tw.tween_method(func(f: float) -> void:
		for h in _split_halves:
			h.scale = Vector3.ONE * (1.0 - f)
		, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		for h in _split_halves:
			h.visible = false)
	# The key pops out, hops in an arc toward the camera, bounces twice.
	var key := _make_key_mesh()
	key.process_mode = Node.PROCESS_MODE_ALWAYS
	var start := rock + Vector3(0, 0.3, 0)
	tw.tween_callback(func() -> void:
		add_child(key)
		key.global_position = start
		key.scale = Vector3.ONE * 0.01
		_add_key_shine(key))
	tw.tween_property(key, "scale", Vector3.ONE * 1.4, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var peak := start.lerp(land, 0.5) + Vector3(0, 3.0, 0)
	tw.tween_method(func(f: float) -> void:
		# Quadratic Bezier start -> peak -> land.
		var p := start.lerp(peak, f).lerp(peak.lerp(land, f), f)
		key.global_position = p
		key.rotation.y = f * TAU * 1.5
		cam.look_at(rock.lerp(land, f), Vector3.UP), 0.0, 1.0, 0.85)
	for bounce in [[0.9, 0.42], [0.3, 0.26]]:
		var hop: float = bounce[0]
		var t: float = bounce[1]
		tw.tween_method(func(f: float) -> void:
			key.global_position = land + Vector3(0, 4.0 * hop * f * (1.0 - f), 0)
			key.rotation.y = TAU * 1.5 + f * PI, 0.0, 1.0, t)
	tw.tween_interval(0.7)
	tw.tween_callback(func() -> void:
		get_tree().paused = false
		_split_rock.queue_free()
		_split_rock = null
		director.queue_free()
		_cam_look = land
		_cutscene_return = CUTSCENE_RETURN_TIME
		_spawn_key_pickup(key))

# A puff of grit and a flash where the rock tears apart.
func _burst(at: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.process_mode = Node.PROCESS_MODE_ALWAYS
	dust.one_shot = true
	dust.explosiveness = 0.95
	dust.amount = 60
	dust.lifetime = 1.4
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.8
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 5.0
	dust.gravity = Vector3(0, -1.5, 0)
	dust.damping_min = 2.0
	dust.damping_max = 3.0
	var bit := BoxMesh.new()
	bit.size = Vector3(0.12, 0.12, 0.12)
	var bit_mat := StandardMaterial3D.new()
	bit_mat.albedo_color = Color(0.4, 0.37, 0.33)
	bit.material = bit_mat
	dust.mesh = bit
	add_child(dust)
	dust.global_position = at
	dust.emitting = true
	var flash := OmniLight3D.new()
	flash.process_mode = Node.PROCESS_MODE_ALWAYS
	flash.light_color = Color(1.0, 0.85, 0.5)
	flash.omni_range = 9.0
	flash.light_energy = 6.0
	add_child(flash)
	flash.global_position = at + Vector3(0, 1, 0)
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.6)
	tw.tween_callback(flash.queue_free)
	get_tree().create_timer(2.0, true).timeout.connect(dust.queue_free)

func _add_key_shine(key: Node3D) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.35)
	light.omni_range = 4.0
	light.light_energy = 2.2
	key.add_child(light)
	var sparkles := CPUParticles3D.new()
	sparkles.amount = 24
	sparkles.lifetime = 1.0
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 0.5
	sparkles.gravity = Vector3(0, 0.5, 0)
	sparkles.initial_velocity_min = 0.1
	sparkles.initial_velocity_max = 0.4
	var spark := SphereMesh.new()
	spark.radius = 0.05
	spark.height = 0.1
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.92, 0.55)
	spark.material = spark_mat
	sparkles.mesh = spark
	key.add_child(sparkles)

# The landed key: bobs and spins until a diver swims into it.
func _spawn_key_pickup(key: Node3D) -> void:
	key.process_mode = Node.PROCESS_MODE_INHERIT
	key_pickups.append(key)
	var area := Area3D.new()
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1
	shape.shape = sphere
	area.add_child(shape)
	key.add_child(area)
	var base_y := key.global_position.y
	var bob := key.create_tween().set_loops()
	bob.tween_property(key, "global_position:y", base_y + 0.25, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(key, "global_position:y", base_y, 0.8).set_trans(Tween.TRANS_SINE)
	var spin := key.create_tween().set_loops()
	spin.tween_property(key, "rotation:y", key.rotation.y + TAU, 2.5).from(key.rotation.y)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Diver and is_instance_valid(key) and not key.is_queued_for_deletion():
			key.queue_free()
			_gain_key("split_rock_key"))

# --- Map points of interest -----------------------------------------------------
# What the maps can mark once the diver has been near it (MazeMiniMap tracks
# which ones have been found): {"id", "kind", "pos", "radius", optional
# "rect" (Rect2 on x/z - found by entering it), "label", "done"}.
# Kinds: poster, chest, switch, rock, room_label.
func map_points_of_interest() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in _posters:
		out.append({"id": String(p.name), "kind": "poster", "pos": p.global_position, "radius": 7.0, "done": p.seen, "texture": p.portrait})
	for k in key_pickups:
		if is_instance_valid(k) and not k.is_queued_for_deletion():
			out.append({"id": "key_%d" % k.get_instance_id(), "kind": "key", "pos": k.global_position, "radius": 9.0})
	for i in broken_rock_spots.size():
		out.append({"id": "broken_rock_%d" % i, "kind": "broken_rock", "pos": broken_rock_spots[i], "radius": INF})
	if _vortex_chest != null and is_instance_valid(_vortex_chest):
		out.append({"id": "vortex_chest", "kind": "chest", "pos": _vortex_chest.global_position, "radius": 9.0, "done": _vortex_chest_open})
	if _switch_node != null:
		out.append({"id": "room_switch", "kind": "switch", "pos": _switch_node.global_position, "radius": 7.0, "done": _gate_lowered})
	if _split_rock != null and is_instance_valid(_split_rock):
		out.append({"id": "split_rock", "kind": "rock", "pos": _split_rock.global_position, "radius": 8.0, "done": false})
	var item_room := _secret_item_room_rect()
	if item_room.size != Vector2.ZERO:
		var c := item_room.get_center()
		out.append({"id": "secret_item_room", "kind": "room_label", "pos": Vector3(c.x, 0, c.y), "radius": 0.0, "rect": item_room, "label": "Secret\nItem Room"})
	return out

# One half of a broken rock: a lumpy, faceted dome (+Y) over a rough,
# jagged fracture face (around y = 0, facing -Y). Dome faces are weathered
# grey-brown, the fracture face lighter raw stone. Flat-shaded triangles.
func _broken_half_mesh(radius: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var segs := 9
	var rings := 4
	var weathered := Color(0.33, 0.31, 0.28)
	var raw := Color(0.55, 0.49, 0.42)
	var rows: Array = []   # rows[r][s] - r = 0 is the broken rim
	for r in rings:
		var phi := float(r) / float(rings) * PI * 0.5
		var row: Array[Vector3] = []
		for s in segs:
			var theta := (float(s) + rng.randf_range(-0.25, 0.25)) / float(segs) * TAU
			var rr := radius * rng.randf_range(0.8, 1.12)
			var p := Vector3(cos(theta) * cos(phi), sin(phi), sin(theta) * cos(phi)) * rr
			if r == 0:
				p.y = radius * rng.randf_range(-0.12, 0.14)   # jagged break line
			row.append(p)
		rows.append(row)
	var pole := Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.8, 1.0), rng.randf_range(-0.15, 0.15)) * radius
	# The fracture face: a jagged ring halfway in and an off-centre peak.
	var mid: Array[Vector3] = []
	for s in segs:
		var rim := rows[0][s] as Vector3
		mid.append(Vector3(rim.x * rng.randf_range(0.4, 0.6), radius * rng.randf_range(-0.2, 0.12), rim.z * rng.randf_range(0.4, 0.6)))
	var core := Vector3(rng.randf_range(-0.2, 0.2) * radius, radius * rng.randf_range(-0.25, 0.05), rng.randf_range(-0.2, 0.2) * radius)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, col: Color) -> void:
		var n := (b - a).cross(c - a)
		if n.dot(outward) > 0.0:   # Godot's front faces wind clockwise
			var t := b
			b = c
			c = t
			n = -n
		var normal := -n.normalized()
		var shade := col * rng.randf_range(0.9, 1.1)
		shade.a = 1.0
		for v in [a, b, c]:
			st.set_color(shade)
			st.set_normal(normal)
			st.add_vertex(v)
	for r in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a := rows[r][s] as Vector3
			var b := rows[r][s2] as Vector3
			if r + 1 < rings:
				var c := rows[r + 1][s] as Vector3
				var d := rows[r + 1][s2] as Vector3
				tri.call(a, b, d, (a + b + d) / 3.0, weathered)
				tri.call(a, d, c, (a + d + c) / 3.0, weathered)
			else:
				tri.call(a, b, pole, (a + b + pole) / 3.0, weathered)
	for s in segs:
		var s2 := (s + 1) % segs
		var a := rows[0][s] as Vector3
		var b := rows[0][s2] as Vector3
		tri.call(a, b, mid[s2], Vector3(0, -1, 0), raw)
		tri.call(a, mid[s2], mid[s], Vector3(0, -1, 0), raw)
		tri.call(mid[s], mid[s2], core, Vector3(0, -1, 0), raw)
	return st.commit()

# --- Wall skirts ------------------------------------------------------------------
# The floor sits _FLOOR_CLEARANCE below the walls' bottoms, which left a gap
# under every wall a diver could wedge into. Each wall standing at the
# normal base gets a solid skirt filling that gap down to the floor - a
# child of the wall, so it swings, sinks and rises with it.
func _add_wall_skirts() -> void:
	var base := _floor_top_y + _FLOOR_CLEARANCE
	for child in get_children():
		var wall := child as CSGBox3D
		if wall == null:
			continue
		var bottom := wall.global_position.y - wall.size.y * 0.5
		if absf(bottom - base) < 0.05 or _wall_10_11_extras.has(wall):
			_add_wall_skirt(wall)

func _add_wall_skirt(wall: CSGBox3D) -> void:
	if wall.has_node("Skirt"):
		return
	var depth := _FLOOR_CLEARANCE + 0.05
	var skirt := StaticBody3D.new()
	skirt.name = "Skirt"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(wall.size.x, depth, wall.size.z)
	shape.shape = box
	skirt.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh.mesh = box_mesh
	if wall.material != null:
		mesh.material_override = wall.material
	skirt.add_child(mesh)
	skirt.position = Vector3(0, -wall.size.y * 0.5 - depth * 0.5 + 0.02, 0)
	wall.add_child(skirt)
	# A sunk / hidden wall's skirt goes with it.
	wall.visibility_changed.connect(func() -> void:
		shape.set_deferred("disabled", not wall.visible))
	shape.disabled = not wall.visible

# --- Broken rocks and loose keys (for the maps) ----------------------------------
var broken_rock_spots: Array[Vector3] = []   # rocks broken in the secret item room
var key_pickups: Array[Node3D] = []          # keys lying about, not yet picked up

func _note_broken_rock(spot: Vector3) -> void:
	var room := _secret_item_room_rect()
	if room.size != Vector2.ZERO and room.has_point(Vector2(spot.x, spot.z)):
		broken_rock_spots.append(spot)

# --- The hall between the boss rooms ----------------------------------------------
# Between the secret boss room's door and the main boss room's: 8 evenly
# spaced rows of tall rock columns across the hall, alternating two columns
# (a gap in the middle) and one (in the middle), so the way through weaves.
# In the gaps between rows, rocks (tucked behind a column - half potions,
# half fakes with enemies in them) and small whirlpools take turns -
# a whirlpool drags you in, spins you down, hurts, and drops you back at the
# hall's entrance: "You were sucked to the ocean deep..".
const HALL_ROWS := 8
const HALL_COLUMN_RADIUS := 1.25
var _hall_whirlpools: Array[Whirlpool] = []

func _hall_rect() -> Rect2:
	var west := get_node_or_null("Box30DoorWallA") as CSGBox3D
	var east := get_node_or_null("CSGBox3D33") as CSGBox3D
	var north := get_node_or_null("CSGBox3D29") as CSGBox3D
	var south := get_node_or_null("CSGBox3D32") as CSGBox3D
	if west == null or east == null or north == null or south == null:
		return Rect2()
	var t := west.size.z * 0.5
	var x0 := west.global_position.x + t
	var x1 := east.global_position.x - t
	var z0 := minf(north.global_position.z, south.global_position.z) + t
	var z1 := maxf(north.global_position.z, south.global_position.z) - t
	return Rect2(x0, z0, x1 - x0, z1 - z0)

func _build_hall_gauntlet() -> void:
	var hall := _hall_rect()
	if hall.size == Vector2.ZERO:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 30
	var margin := HALL_COLUMN_RADIUS + 1.2
	var xs: Array[float] = []
	for i in HALL_ROWS:
		xs.append(lerpf(hall.position.x + margin, hall.end.x - margin, float(i) / float(HALL_ROWS - 1)))
	var z_mid := hall.get_center().y
	var quarter := hall.size.y * 0.25
	var row_zs: Array = []
	for i in HALL_ROWS:
		var zs: Array = [z_mid - quarter, z_mid + quarter] if i % 2 == 0 else [z_mid]
		row_zs.append(zs)
		for z in zs:
			_build_rock_column(Vector3(xs[i], 0, float(z)), rng)
	# The hall's way in, at its north-west corner - where a whirlpool drops you.
	var entrance := Vector3(hall.position.x + 1.8, ($DiverEntry as Node3D).global_position.y, hall.position.y + 1.6)
	for g in HALL_ROWS - 1:
		var x := (xs[g] + xs[g + 1]) * 0.5
		# Off to one side or the other, out of the columns' way.
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var z := z_mid + side * hall.size.y * rng.randf_range(0.3, 0.4)
		if g % 2 == 0:
			# Tucked in right behind one of this row's columns, on the side
			# away from the hall's entrance (west): coming in, the column hides
			# it - you have to swing the camera round to spot it.
			var col_zs: Array = row_zs[g]
			var col_z := float(col_zs[rng.randi() % col_zs.size()])
			var spot := Vector3(xs[g] + HALL_COLUMN_RADIUS * 1.3 + 0.55, _floor_top_y + 0.55, col_z)
			var rock := CrackedWall.new()
			rock.span = Vector3(1.1, 1.1, 1.1)
			rock.disguised_as_scenery_rock = true
			rock.position = spot
			# Every other one is a fake: enemies hiding in it, not a potion.
			var reward := "ambush" if g % 4 == 2 else "potion"
			rock.broken.connect(_on_secret_rock_broken.bind(reward, spot + Vector3(0, 0.6, 0)))
			add_child(rock)
		else:
			var w := Whirlpool.new()
			w.suction_radius = 0.9
			w.suction_height = 12.0
			w.warning_radius = 3.6
			w.pull_radius = 3.4
			w.pull_speed = 3.2
			w.damage_min = 3
			w.damage_max = 6
			w.reset_to = entrance
			# Down into the deep: an open shaft under it, no floor, with the
			# current pouring down it (_carve_hall_whirlpool_holes() cuts the
			# floor once it's built).
			w.deep_hole_radius = w.suction_radius + 0.1
			w.diver_sucked_in.connect(_on_deep_whirlpool)
			add_child(w)
			w.global_position = Vector3(x, _floor_top_y + FLOOR_THICKNESS_VISUAL + 0.01, z)
			_hall_whirlpools.append(w)

# A round hole through the hall's visible floor under each deep whirlpool
# (the invisible slab stays - the whirlpool catches anyone that close first).
func _carve_hall_whirlpool_holes() -> void:
	for floor_name in ["Floor_BossHall", "Floor_Base"]:
		var floor_box := get_node_or_null(floor_name) as CSGBox3D
		if floor_box == null:
			continue
		for w in _hall_whirlpools:
			var hole := CSGCylinder3D.new()
			hole.operation = CSGShape3D.OPERATION_SUBTRACTION
			hole.radius = w.deep_hole_radius
			hole.height = FLOOR_THICKNESS_VISUAL * 4.0
			hole.sides = 24
			floor_box.add_child(hole)
			hole.global_position = Vector3(w.global_position.x, floor_box.global_position.y, w.global_position.z)

func _on_deep_whirlpool(_d: Diver, amount: int) -> void:
	_announce("You were sucked to the ocean deep.. (-%d HP)" % amount)

# A column of big lumpy boulders stacked floor to ceiling, solid.
func _build_rock_column(at: Vector3, rng: RandomNumberGenerator) -> void:
	var column := StaticBody3D.new()
	column.name = "HallRockColumn"
	add_child(column)
	column.global_position = Vector3(at.x, _floor_top_y, at.z)
	var top := _floor_top_y + _FLOOR_CLEARANCE + ($CSGBox3D as CSGBox3D).size.y + _CEILING_CLEARANCE
	var height := top - _floor_top_y
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = HALL_COLUMN_RADIUS
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height * 0.5
	column.add_child(shape)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.34, 0.32, 0.29)
	stone.roughness = 1.0
	var y := HALL_COLUMN_RADIUS * 0.6
	while y < height:
		var boulder := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var r := HALL_COLUMN_RADIUS * rng.randf_range(1.0, 1.25)
		mesh.radius = r
		mesh.height = r * rng.randf_range(1.2, 1.5)
		mesh.radial_segments = 8
		mesh.rings = 5
		boulder.mesh = mesh
		boulder.material_override = stone
		boulder.position = Vector3(rng.randf_range(-0.2, 0.2), y, rng.randf_range(-0.2, 0.2))
		boulder.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		column.add_child(boulder)
		y += mesh.height * 0.8

# --- Tutorial guide (F1, as in the main game) -----------------------------------
var tutorial_book: TutorialBook

func _build_tutorial_book() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 96
	layer.process_mode = Node.PROCESS_MODE_ALWAYS   # it pauses the game while open
	add_child(layer)
	tutorial_book = TutorialBook.new()
	layer.add_child(tutorial_book)

# --- Inventory (ported from the main game) -------------------------------------
# Esc opens main's InventoryMenu: Items (use on whoever you're steering),
# Party Spells (inventory-tagged heal/revive moves) and Combat Help. These
# are the World functions it calls, done the same way here.
var inventory_menu: InventoryMenu

func _build_inventory_menu() -> void:
	inventory_menu = InventoryMenu.new()
	inventory_menu.world = self
	# Always in front - over the maze map (z 4) and its controls too, which
	# stay open but paused behind it (the map ignores keys while it's up).
	inventory_menu.z_index = 100
	$HUD.add_child(inventory_menu)

func use_inventory_item(item_id: String) -> void:
	var count: int = int(inventory.get(item_id, 0))
	if count <= 0 or divers.is_empty():
		return
	var diver: Diver = divers[active]
	if bool(Items.ITEMS.get(item_id, {}).get("battle_only", false)):
		_announce("This item can only be used during a battle.")
		return
	if not Items.would_help(item_id, diver.stats):
		var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
		_announce("%s wouldn't do anything right now." % display)
		return
	var msg := Items.grant(item_id, diver.stats)
	if msg != "":
		_announce(msg)
	inventory[item_id] = count - 1
	if inventory[item_id] <= 0:
		inventory.erase(item_id)

func _inventory_spells_for(d: Diver) -> Array:
	var out: Array = []
	for mv in Battle.BASE_MOVES.get(d.model_name, []):
		if bool((mv as Dictionary).get("inventory", false)):
			out.append(mv)
	for spell_id in d.known_spells:
		var def: Dictionary = SpellTree.find_def(d.model_name, spell_id)
		if bool(def.get("inventory", false)):
			out.append(def)
	return out

func _party_spell_label(spell: Dictionary) -> String:
	return String(spell.get("display", spell.get("name", "")))

func can_afford_party_spell(spell: Dictionary, caster: Diver) -> bool:
	return caster.stats.oxygen >= float(spell.get("oxygen_cost", 0.0))

func use_party_spell(spell: Dictionary, caster: Diver, target: Diver) -> void:
	if not can_afford_party_spell(spell, caster):
		return
	caster.stats.oxygen -= float(spell.get("oxygen_cost", 0.0))
	var s := target.stats
	var amount := int(spell.get("amount", 0))
	var label := _party_spell_label(spell)
	match String(spell.get("effect", "")):
		"heal":
			var before := s.hp
			s.hp = mini(s.hp_max, s.hp + amount)
			var changed := s.hp - before
			if changed > 0:
				_announce("%s - %s recovers %d HP." % [label, _display_name(target.model_name), changed])
			else:
				_announce("%s - %s is already at full health." % [label, _display_name(target.model_name)])
		"revive":
			if s.hp > 0:
				_announce("%s isn't down." % _display_name(target.model_name))
				return
			s.hp = mini(s.hp_max, amount)
			_announce("%s - %s is back up!" % [label, _display_name(target.model_name)])

func _display_name(model_name: String) -> String:
	return Cast.display_name(model_name)

# --- Special encounters (the world's guarded items) ------------------------------
# The same thing the dive site has: a guarded item (MazeItemGuardian) with its
# guardian standing beside it, hidden until Maxilani's sonar finds it.
# Swimming into it brings up "choose who goes" (SpecialEncounterPrompt); the
# chosen diver alone fights the guardian in a special-encounter battle (their
# ability's minigame and all). Win: the item, and that diver is restored to
# full; lose: they're put back as they were, and the guardian stays for
# another try. One is in the secret item room; three are in the open water
# between RewardChamberWestWall and wall 9 (reached once walls 10/11 swing):
# about 20 m east of the BreakRock current's line, give or take, and 10-20 m
# apart from wall 9's side towards RewardChamberWestWall - each one checked
# clear of walls and invisible barriers, and picked again if not.
const SPECIAL_SPOTS := [
	{"at": Vector3(64.0, 0, 52.0), "item": "spell_shard", "enemy": "swordfish_duelist", "look": "salvage"},
	{"at": null, "item": "attack_up", "enemy": "angler", "look": "urchin"},
	{"at": null, "item": "defense_up", "enemy": "swordfish_duelist", "look": "salvage"},
	{"at": null, "item": "oxygen_cell", "enemy": "angler", "look": "urchin"},
]
const SPECIAL_EAST_OF_BREAK_ROCK := 20.0
const SPECIAL_SPACING := Vector2(10.0, 20.0)
const SPECIAL_CLEARANCE := 2.2   # room kept around a spot (guardian + its guard)
const SPECIAL_SONAR_RADIUS := 14.0

var special_encounter_prompt: SpecialEncounterPrompt
var _special_spots: Array[MazeItemGuardian] = []
var _special_spot: MazeItemGuardian
var _special_diver: Diver
var _special_pre_hp := 0
var _special_pre_oxygen := 0.0

func _build_special_encounters() -> void:
	special_encounter_prompt = SpecialEncounterPrompt.new()
	special_encounter_prompt.diver_chosen.connect(_on_special_diver_chosen)
	special_encounter_prompt.cancelled.connect(_on_special_cancelled)
	var layer := CanvasLayer.new()
	layer.layer = 95
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	layer.add_child(special_encounter_prompt)
	# The walls' collision (CSG) only exists after a physics frame or two -
	# the spots are checked against it, so wait for it.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var between := _special_spots_between()
	for entry in SPECIAL_SPOTS:
		if entry["at"] == null:
			if between.is_empty():
				continue
			entry = entry.duplicate()
			entry["at"] = between.pop_front()
		else:
			# An authored spot: shifted with the rest of the maze.
			entry = entry.duplicate()
			entry["at"] = (entry["at"] as Vector3) + embed_offset
		var guardian := MazeItemGuardian.new()
		guardian.item_id = String(entry["item"])
		guardian.look = String(entry["look"])
		add_child(guardian)
		var at: Vector3 = entry["at"]
		guardian.global_position = Vector3(at.x, _floor_top_y + float(MazeItemGuardian.LIFT.get(guardian.look, 0.9)), at.z)
		var decoy: Node3D = SwordDuelist.new() if String(entry["enemy"]) == "swordfish_duelist" else Goblin.new()
		add_child(decoy)
		decoy.global_position = Vector3(at.x - 1.8, _floor_top_y, at.z + 0.6)   # west side, clear of the strong room's wall
		guardian.set_meta("enemy", String(entry["enemy"]))
		guardian.set_meta("decoy", decoy)
		guardian.triggered.connect(_on_special_triggered.bind(guardian))
		_set_special_revealed(guardian, false)
		_special_spots.append(guardian)

# Spots for the three between RewardChamberWestWall and wall 9.
func _special_spots_between() -> Array:
	var out: Array = []
	var break_rock := get_node_or_null("WindCorridorBreakRock") as Area3D
	var reward := get_node_or_null("RewardChamberWestWall") as CSGBox3D
	var stub := get_node_or_null("CSGBox3DConnectorStub") as CSGBox3D
	if break_rock == null or reward == null or stub == null:
		return out
	var line_x := _corridor_shape(break_rock).global_position.x
	var z_min := stub.global_position.z + 1.5 + SPECIAL_CLEARANCE    # past the barrier on the stub's line
	var z_max := reward.global_position.z - 0.5 - SPECIAL_CLEARANCE  # short of RewardChamberWestWall
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for attempt in 40:
		out.clear()
		var z := z_min + rng.randf_range(0.0, 3.0)
		for i in 3:
			var x := line_x + SPECIAL_EAST_OF_BREAK_ROCK + rng.randf_range(-6.0, 0.0)
			var p := Vector3(x, 0.0, z)
			if z > z_max or not _special_spot_clear(p):
				break
			out.append(p)
			z += rng.randf_range(SPECIAL_SPACING.x, SPECIAL_SPACING.y)
		if out.size() == 3:
			return out
	return out

# Nothing solid (walls, invisible barriers, rocks) within SPECIAL_CLEARANCE.
func _special_spot_clear(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = SPECIAL_CLEARANCE
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, _floor_top_y + SPECIAL_CLEARANCE + 0.1, p.z))
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _set_special_revealed(guardian: MazeItemGuardian, on: bool) -> void:
	guardian.visible = on
	guardian.set_deferred("monitoring", on)
	var decoy: Node3D = guardian.get_meta("decoy")
	if is_instance_valid(decoy):
		decoy.visible = on
	guardian.set_meta("revealed", on)

# Sonar on, near enough: the spot shows (and stays shown).
func _update_special_reveal() -> void:
	if _diver == null or _diver.passive_id != "sonar" or not _diver.sonar_active:
		return
	for g in _special_spots:
		if is_instance_valid(g) and not bool(g.get_meta("revealed", false)) and g.global_position.distance_to(_diver.global_position) <= SPECIAL_SONAR_RADIUS:
			_set_special_revealed(g, true)
			_announce("Sonar found something guarded nearby.")

func _on_special_triggered(_item_id: String, guardian: MazeItemGuardian) -> void:
	if _battling or any_modal_open() or not bool(guardian.get_meta("revealed", false)):
		return
	_special_spot = guardian
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	get_tree().paused = true
	special_encounter_prompt.open()

func _on_special_diver_chosen(model_name: String) -> void:
	special_encounter_prompt.close()
	get_tree().paused = false
	_special_diver = null
	for d in divers:
		if d.model_name == model_name:
			_special_diver = d
	if _special_diver == null or _special_spot == null:
		_on_special_cancelled()
		return
	_special_pre_hp = _special_diver.stats.hp
	_special_pre_oxygen = _special_diver.stats.oxygen
	_start_battle("special")

func _on_special_cancelled() -> void:
	special_encounter_prompt.close()
	get_tree().paused = false
	_special_spot = null

func _finish_special_encounter(result: String) -> void:
	var spot := _special_spot
	var diver := _special_diver
	_special_spot = null
	_special_diver = null
	if diver == null or spot == null:
		return
	if result == "won":
		diver.stats.hp = diver.stats.hp_max
		diver.stats.oxygen = diver.stats.oxygen_max
		var item_id := spot.item_id
		var decoy: Node3D = spot.get_meta("decoy")
		if is_instance_valid(decoy):
			decoy.queue_free()
		_special_spots.erase(spot)
		spot.queue_free()
		_on_secret_orb_collected(item_id, diver)   # "Picked up a ..."
	else:
		diver.stats.hp = _special_pre_hp
		diver.stats.oxygen = _special_pre_oxygen
		_announce("The guardian holds its ground. Come back and try again.")

# --- Visible floors ------------------------------------------------------------
# The floor that stops divers is an invisible slab; these are what you see.
# A CSGBox strip under every hallway - as wide as the gap between its two
# walls, as long as they run side by side - and one bigger box under each
# room. Halls whose walls rotate get a strip under both of their positions.
# Visual only (no collision): they sit just on top of the invisible slab.
const HALLWAY_PAIRS := [
	["CSGBox3D", "CurrentWall3"],
	["CSGBox3D6", "CSGBox3D7"],
	["CSGBox3D12", "CSGBox3D13"],
	["CSGBox3D8", "CSGBox3D9"],
	["CSGBox3D18", "CSGBox3D19"],
	["CSGBox3D20", "CSGBox3D21"],
	["CSGBox3D23", "CSGBox3D20"],
	["CSGBox3D16", "CSGBox3D27"],
]
const FLOOR_THICKNESS_VISUAL := 0.12
var _sphere_room_interior := Rect2()

func _build_visible_floors() -> void:
	var n := 0
	# One seafloor under the whole level first, so nowhere between the
	# hallway/room floors below (e.g. the corner of walls 15/16, or round the
	# sphere room's door) is left with no floor. A little lower than those,
	# so where they overlap they don't flicker against it.
	var points := _collect_bounds_points()
	if not points.is_empty():
		var lo: Vector3 = points[0]
		var hi: Vector3 = points[0]
		for p in points:
			lo = lo.min(p)
			hi = hi.max(p)
		lo -= Vector3(_PERIMETER_MARGIN, 0, _PERIMETER_MARGIN)
		hi += Vector3(_PERIMETER_MARGIN, 0, _PERIMETER_MARGIN)
		_floor_box("Floor_Base", Vector3((lo.x + hi.x) * 0.5, 0, (lo.z + hi.z) * 0.5), 0.0, Vector2(hi.x - lo.x, hi.z - lo.z), -0.05)
	# Hallways between walls that stay put.
	for pair in HALLWAY_PAIRS:
		var a := get_node_or_null(String(pair[0])) as CSGBox3D
		var b := get_node_or_null(String(pair[1])) as CSGBox3D
		if a != null and b != null:
			n += int(_hallway_floor("Floor_%s_%s" % [pair[0], pair[1]], _footprint(a), _footprint(b)))
	# Rotating halls: where their walls start, and where they swing to.
	var w1 := $CurrentWall1 as CSGBox3D
	var w2 := $CurrentWall2 as CSGBox3D
	n += int(_hallway_floor("Floor_Hallway12", _footprint(w1), _footprint(w2)))
	var c1: Dictionary = _nearest_wall_continuation(w1, $CSGBox3D)
	var c2: Dictionary = _nearest_wall_continuation(w2, $CurrentWall3)
	n += int(_hallway_floor("Floor_Hallway12Swung", {"centre": c1.position, "yaw": float(c1.yaw), "length": w1.size.x}, {"centre": c2.position, "yaw": float(c2.yaw), "length": w2.size.x}))
	var w10 := $CSGBox3D10 as CSGBox3D
	var w11 := $CSGBox3D11 as CSGBox3D
	n += int(_hallway_floor("Floor_10_11", _footprint(w10), _footprint(w11)))
	var t1011 := _walls_10_11_targets()
	n += int(_hallway_floor("Floor_10_11Swung", {"centre": t1011[0][1], "yaw": float(t1011[0][2]), "length": w11.size.x}, {"centre": t1011[1][1], "yaw": float(t1011[1][2]), "length": w10.size.x}))
	if _walls_14_15_rest.size() == 2:
		var w14 := _walls_14_15_rest[0][0] as CSGBox3D
		var w15 := _walls_14_15_rest[1][0] as CSGBox3D
		n += int(_hallway_floor("Floor_14_15", {"centre": _walls_14_15_rest[0][1], "yaw": float(_walls_14_15_rest[0][2]), "length": w14.size.x}, {"centre": _walls_14_15_rest[1][1], "yaw": float(_walls_14_15_rest[1][2]), "length": w15.size.x}))
		n += int(_hallway_floor("Floor_14_15Swung", {"centre": Vector3(_wall_11_joint.x, 0, _wall_11_joint.z + w14.size.x * 0.5), "yaw": -PI * 0.5, "length": w14.size.x}, {"centre": Vector3(_wall_10_joint.x, 0, _wall_10_joint.z + w15.size.x * 0.5), "yaw": -PI * 0.5, "length": w15.size.x}))
	# Rooms: one box each.
	var main_boss := Rect2()
	var mn := get_node_or_null("MainBossRoomNorth") as CSGBox3D
	var ms := get_node_or_null("MainBossRoomSouth") as CSGBox3D
	var me := get_node_or_null("MainBossRoomEast") as CSGBox3D
	if mn != null and ms != null and me != null:
		var x0 := mn.global_position.x - mn.size.x * 0.5
		main_boss = Rect2(x0, ms.global_position.z, me.global_position.x - x0, mn.global_position.z - ms.global_position.z)
	for room in [
		["Floor_SecretItemRoom", _secret_item_room_rect()],
		["Floor_StrongRoom", _strong_room_rect()],
		["Floor_SecretBossRoom", _secret_boss_room_rect(false)],
		["Floor_BossHall", _hall_rect()],
		["Floor_MainBossRoom", main_boss],
		["Floor_SphereRoom", _sphere_room_interior],
	]:
		var r: Rect2 = room[1]
		if r.size.x > 0.5 and r.size.y > 0.5:
			_floor_box(String(room[0]), Vector3(r.get_center().x, 0, r.get_center().y), 0.0, Vector2(r.size.x + 1.0, r.size.y + 1.0))
			n += 1

# A wall's footprint: centre, yaw and length.
func _footprint(w: CSGBox3D) -> Dictionary:
	return {"centre": w.global_position, "yaw": w.rotation.y, "length": w.size.x}

# The strip between two parallel wall footprints, where they overlap.
# false if they don't overlap enough (or aren't side by side).
func _hallway_floor(floor_name: String, a: Dictionary, b: Dictionary) -> bool:
	var axis := Basis(Vector3.UP, float(a["yaw"])).x
	axis.y = 0.0
	axis = axis.normalized()
	var side := Vector3(-axis.z, 0, axis.x)
	var ca: Vector3 = a["centre"]
	var cb: Vector3 = b["centre"]
	var ha := float(a["length"]) * 0.5
	var hb := float(b["length"]) * 0.5
	var b_along := (cb - ca).dot(axis)
	var lo := maxf(-ha, b_along - hb)
	var hi := minf(ha, b_along + hb)
	if hi - lo < 1.0:
		return false
	var gap := (cb - ca).dot(side)
	if absf(gap) < 1.5:
		return false
	var centre := ca + axis * (lo + hi) * 0.5 + side * gap * 0.5
	# As wide as the gap, reaching under both walls (1 m thick).
	_floor_box(floor_name, centre, atan2(-axis.z, axis.x), Vector2(hi - lo, absf(gap) + 1.0))
	return true

func _floor_box(floor_name: String, centre: Vector3, yaw: float, footprint: Vector2, lift := 0.0) -> void:
	var box := CSGBox3D.new()
	box.name = floor_name
	box.size = Vector3(footprint.x, FLOOR_THICKNESS_VISUAL, footprint.y)
	# No material: the same default look as the maze's walls.
	box.use_collision = false
	add_child(box)
	box.rotation.y = yaw
	box.global_position = Vector3(centre.x, _floor_top_y + FLOOR_THICKNESS_VISUAL * 0.5 + 0.01 + lift, centre.z)

# --- Save points (as in the main game) -------------------------------------------
# The world's SavePoint crystal and SavePointMenu: standing on one shows
# "Save/Update Spells - Press P"; P opens the menu - Save restores the whole
# party and writes the run (party, items, keys) to MAZE_SAVE_PATH, Update
# Spells learns / equips spells. Three of them: just outside the maze's
# entrance, in the corner where walls 11 and 14 meet, and just inside the way
# into the block with the secret boss room.
const MAZE_SAVE_PATH := "user://maze_save.json"
var save_point_menu: SavePointMenu
var _save_points: Array[SavePoint] = []
var _showing_save_prompt := false

func _build_save_points() -> void:
	save_point_menu = SavePointMenu.new()
	save_point_menu.save_requested.connect(_on_save_requested)
	$HUD.add_child(save_point_menu)
	var spots: Array[Vector3] = []
	# 1. In front of the maze, by its entrance: just out past the start
	#    corridor's open west end.
	var start := _wall_geometry($CSGBox3D as CSGBox3D)
	var start_west: Vector3 = start["negative_end"] if (start["negative_end"] as Vector3).x < (start["positive_end"] as Vector3).x else start["positive_end"]
	var w3 := $CurrentWall3 as CSGBox3D
	spots.append(Vector3(start_west.x - 3.0, 0, (start_west.z + w3.global_position.z) * 0.5))
	# 2. The inside corner where wall 11 meets wall 14.
	var w11 := $CSGBox3D11 as CSGBox3D
	var w10 := $CSGBox3D10 as CSGBox3D
	var into := signf(w10.global_position.x - w11.global_position.x)
	spots.append(Vector3(_wall_11_joint.x + into * 2.4, 0, _wall_11_joint.z - 2.2))
	# 3. Just inside the way into the boss block (its north-west corner).
	var hall := _hall_rect()
	if hall.size != Vector2.ZERO:
		spots.append(Vector3(hall.position.x + 2.0, 0, hall.position.y + 2.2))
	for p in spots:
		var sp := SavePoint.new()
		add_child(sp)
		# No visible floor here (e.g. out in front of the entrance): give it a
		# pad of its own to stand on.
		if _visible_floor_top_at(p) <= _floor_top_y:
			_floor_box("Floor_SavePoint%d" % _save_points.size(), p, 0.0, Vector2(4.0, 4.0))
		sp.global_position = Vector3(p.x, _visible_floor_top_at(p), p.z)
		_save_points.append(sp)

# The top of the visible floor box under `p` (see _build_visible_floors()),
# or the invisible slab's top where there isn't one - so a save point stands
# on the floor you can see instead of sinking into it.
func _visible_floor_top_at(p: Vector3) -> float:
	var top := _floor_top_y
	for child in get_children():
		var box := child as CSGBox3D
		if box == null or not String(box.name).begins_with("Floor_"):
			continue
		var local := box.global_transform.affine_inverse() * Vector3(p.x, box.global_position.y, p.z)
		if absf(local.x) <= box.size.x * 0.5 and absf(local.z) <= box.size.z * 0.5:
			top = maxf(top, box.global_position.y + box.size.y * 0.5)
	return top

func _diver_on_save_point(d: Diver) -> bool:
	for sp in _save_points:
		if sp.has_diver(d):
			return true
	return false

func _toggle_save_menu() -> void:
	if save_point_menu.visible:
		save_point_menu.close()
		return
	if not _diver_on_save_point(_diver):
		_announce("No save point nearby.")
		return
	save_point_menu.open_for(_diver)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false

# The prompt stays up exactly while standing on one (not on the usual
# timer), and only ever clears its own text, never a real announcement.
func _update_save_point_prompt() -> void:
	if _diver == null or save_point_menu == null:
		return
	if _banner == null:
		_announce("")
	var on_point := _diver_on_save_point(_diver) and not save_point_menu.visible
	# Waits for any orange message (e.g. "Progress saved.") to finish first.
	if on_point and not _showing_save_prompt and _banner_timer <= 0.0:
		_banner.text = "Save/Update Spells - Press P"
		_banner.visible = true
		_banner_timer = 0.0
		_showing_save_prompt = true
	elif not on_point and _showing_save_prompt:
		if _banner.text == "Save/Update Spells - Press P":
			_banner.visible = false
		_showing_save_prompt = false

func _on_save_requested(_d: Diver, _slot: int = 0) -> void:
	if world != null:
		# Part of the world: one save, the world's (party, items, keys, slot).
		world._on_save_requested(_d, _slot)
		save_point_menu.close()
		_showing_save_prompt = false
		_announce("Progress saved.")
		return
	for other in divers:
		other.stats.hp = other.stats.hp_max
		other.stats.oxygen = other.stats.oxygen_max
	_write_maze_save()
	save_point_menu.close()
	_showing_save_prompt = false
	_announce("Progress saved.")

# The run as it stands: each diver's stats and spells, the items, the keys.
func _write_maze_save() -> void:
	var party := []
	for d in divers:
		party.append({
			"model": d.model_name,
			"hp": d.stats.hp, "hp_max": d.stats.hp_max,
			"oxygen": d.stats.oxygen, "oxygen_max": d.stats.oxygen_max,
			"known_spells": d.known_spells, "equipped_spells": d.equipped_spells,
		})
	var data := {
		"party": party,
		"inventory": inventory,
		"key_items": key_items,
		"keys_held": keys_held,
		"saved_at": [_diver.global_position.x, _diver.global_position.y, _diver.global_position.z],
	}
	var f := FileAccess.open(MAZE_SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))

# --- First look at the maze map ---------------------------------------------------
var _map_intro_shown := false

func show_map_intro_once() -> void:
	if _map_intro_shown:
		return
	var popup := get_node_or_null("/root/CharacterAbilityPopup")
	if popup == null:
		return
	_map_intro_shown = true
	var pages: Array[Dictionary] = [{
		"title": "Maze Navigation",
		"body": "The Maze Navigation map allows you to select hallways and currents in the maze next to the Map Control room and rotate hallways with E to other halls and currents with R to new areas and halls. Previously visited locations are marked on the map.",
		"slot": null,
	}]
	popup.call("open", pages)
