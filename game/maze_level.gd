class_name MazeLevel
extends Node3D

signal campaign_completed
# Emitted when the player confirms a maze boss fight (Cordys's puppets or
# Cordys); World autosaves here, just before the fight starts.
signal cordys_fight_starting

# A wall's physical ends. Callers use a named exit only where level design requires one.
enum WallEnd {
	NEGATIVE,
	POSITIVE,
}

# Dev: start by the strong-enemy room's switch box with its encounters off.
@export var dev_spawn_at_switch := false
# Dev: start at the secret boss room's door (Box30/32). Beats the switch spawn.
@export var dev_spawn_at_boss_rooms := false
# Dev: start facing the sphere room's door (wall 16). Beats the other dev spawns.
@export var dev_spawn_at_sphere_room := false

var markers: Array[Marker3D] = []

var campaign_session: CampaignSession
var campaign_key_items: Array[String] = []
var route_state: RouteState
# World preference; the strong room still forces its encounters.
var random_encounters_enabled := true
# Zero standalone; the embedded owner sets it before construction. Saves carry it.
var coordinate_origin := Vector3.ZERO
var world: World
var maze_active := true
var embedded_bounds := Rect2()
var _entry_physics_frame := -1
const EMBED_PASSAGE_HALF_WIDTH := 4.0
var draft_passages: Node3D
var special_sites: Node3D
var _potion_rock_spot := Vector3.ZERO

# Every CSGBox3D wall, read live by maze_mini_map.gd (CurrentWall1/2 swing, so no baked segments).
var wall_boxes: Array[CSGBox3D] = []

# WindCorridor1..8 (7 and 8 optional).
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
	if world == null:
		campaign_session = SceneHandoff.take_campaign_session()
	else:
		for child in get_children():
			if child is WorldEnvironment or child is DirectionalLight3D:
				remove_child(child)
				child.queue_free()
			elif child is Node3D:
				(child as Node3D).position += coordinate_origin
	if campaign_session != null:
		active = campaign_session.active
		inventory = campaign_session.inventory
		campaign_key_items = campaign_session.campaign_key_items
		route_state = campaign_session.route_state
		random_encounters_enabled = campaign_session.random_encounters_enabled
	_clear_dome_site()
	for child in get_children():
		if child is Marker3D:
			markers.append(child)
		elif child is CSGBox3D:
			wall_boxes.append(child)
	_normalize_wall_heights()
	# Before _setup_walls(): wall placement can reposition _diver.
	_spawn_divers()
	_build_target_selector()
	_setup_walls()
	# After _setup_walls() so it uses the placed wall positions.
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
	# Corridor8: centred between walls 23 and 20.
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
	if world == null:
		_build_secret_wall_entrance()
	_build_wall_10_11_extras()
	draft_passages = preload("res://game/maze_draft_passages.gd").new()
	draft_passages.name = "DraftPassages"
	add_child(draft_passages)
	draft_passages.setup(self)
	_build_hall_gauntlet()
	_build_visible_floors()
	_carve_hall_whirlpool_holes()
	_carve_draft_visual_floor()
	_build_inventory_menu()
	_build_campaign_checkpoint()
	_build_campaign_exit()
	_add_wall_skirts()
	special_sites = preload("res://game/maze_special_sites.gd").new()
	special_sites.name = "SpecialSites"
	add_child(special_sites)
	special_sites.setup(self)
	$HUD/Controls.text = "Navigation map: not acquired."
	if world == null and campaign_session != null and not campaign_session.maze_snapshot.is_empty():
		if not snapshot_matches_runtime(campaign_session.maze_snapshot):
			SceneHandoff.checkpoint_load_error = "Could not load the maze checkpoint. Choose another save or start a new game."
			get_tree().change_scene_to_file.call_deferred("res://game/world.tscn")
			return
		restore_campaign_snapshot(campaign_session.maze_snapshot)
	if SceneHandoff.returning_from_secret_wall:
		SceneHandoff.returning_from_secret_wall = false
		_place_divers_at_secret_entrance()
	if route_state != null and world == null:
		route_state.set_octopus_state("available" if _boss_triggers.has("main_boss") else "defeated")
	if world == null:
		_play_maze_music(&"play_exploration_music")
	else:
		var points := _collect_bounds_points()
		var lo: Vector3 = points[0]
		var hi := lo
		for point in points:
			lo = lo.min(point)
			hi = hi.max(point)
		embedded_bounds = Rect2(lo.x - _PERIMETER_MARGIN, lo.z - _PERIMETER_MARGIN,
			hi.x - lo.x + _PERIMETER_MARGIN * 2.0, hi.z - lo.z + _PERIMETER_MARGIN * 2.0)
		set_maze_active(false)

func entrance_point() -> Vector3:
	return ($DiverEntry as Node3D).global_position

func contains_point(point: Vector3) -> bool:
	return embedded_bounds.has_point(Vector2(point.x, point.z)) \
		and point.y >= _floor_top_y - 1.0 and point.y <= _floor_top_y + 40.0

func set_maze_active(on: bool) -> void:
	if not on:
		_end_ambush_reveal()
		_cancel_aim()
		_cancel_wall_motion()
		Whirlpool.cancel_in(self)
		if special_sites != null:
			special_sites.cancel()
	maze_active = on
	Whirlpool.refresh_in(self)
	# Disables only this script; the shared actors live under World.
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	$HUD.visible = on
	($Camera3D as Camera3D).current = on
	_update_sonar_vision() # Clear stale reveal before going inactive.

func enter_from_world() -> void:
	if route_state != null:
		route_state.set_octopus_state("available" if _boss_triggers.has("main_boss") else "defeated")
	# World already moved the party this frame; skip a second movement step.
	_entry_physics_frame = Engine.get_physics_frames()
	inventory = world.inventory
	campaign_key_items = world.key_items
	active = world.active
	_diver = divers[active]
	_yaw = world.yaw
	_pitch = world.pitch
	_mouse_look = world.mouse_look
	random_encounters_enabled = world.random_encounters_enabled
	($Camera3D as Camera3D).global_transform = world.cam.global_transform
	_cam_look = Vector3.ZERO
	set_maze_active(true)

func leave_to_world() -> void:
	if target_selector != null and target_selector.selecting:
		target_selector.cancel_selection()
	world.active = active
	world.yaw = _yaw
	world.pitch = _pitch
	world.mouse_look = _mouse_look
	world.random_encounters_enabled = random_encounters_enabled
	world.cam.global_transform = ($Camera3D as Camera3D).global_transform
	set_maze_active(false)

func prepare_area_exit() -> bool:
	# Aim doesn't block leaving; drop transient ownership before the stable-state guard.
	_cancel_aim()
	if target_selector != null and target_selector.selecting:
		target_selector.cancel_selection()
	return can_capture_campaign_snapshot()

func _play_maze_music(method: StringName) -> void:
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.call(method)

# Reward rocks at every Marker3D in the "ItemRock" group.
func _build_item_rocks() -> void:
	_build_secret_item_rocks()
	for node in get_tree().get_nodes_in_group("ItemRock"):
		var marker := node as Node3D
		if marker == null:
			continue
		var rock := CrackedWall.new()
		rock.span = Vector3(1.1, 1.1, 1.1)
		rock.sphere_shaped = true   # brown
		var spot := _spread_secret_rock(marker.global_position)
		rock.position = spot
		rock.broken.connect(_on_item_rock_broken.bind(marker.name, spot))
		add_child(rock)
		_secret_room_rocks.append(rock)

# Single-model orb; duplicates at res://golden_energy_orb.glb and res://game/ can be deleted.
const GOLDEN_ENERGY_ORB_SCENE := preload("res://art/characters/golden_energy_orb.glb")
var goldenOrbs: Array = []
# Emitted when the reward relic is broken (the maze is complete).
signal maze_completed(marker_name: String)
var _completed := false

func is_completed() -> bool:
	return _completed

# Every ItemRock drops the same orb for now.
func _on_item_rock_broken(marker_name: String, spot: Vector3) -> void:
	_note_broken_rock(spot)
	var orb := GOLDEN_ENERGY_ORB_SCENE.instantiate()
	# Source orb is boss-scale; shrink it so it doesn't fill the camera.
	orb.scale = Vector3.ONE * 0.35
	orb.position = spot + Vector3(0.0, 1.25, 0.0)
	goldenOrbs.append(orb)
	add_child(orb)
	if _completed:
		return
	_completed = true
	if not key_items.has("ancient_relic"):
		key_items.append("ancient_relic")
	_announce("You've acquired the Ancient Relic.")
	maze_completed.emit(marker_name)

# Puts every wall's base on the same floor height (the lowest base, as _build_floor() uses).
func _normalize_wall_heights() -> void:
	var floor_y := INF
	for box in wall_boxes:
		floor_y = minf(floor_y, box.position.y - box.size.y * 0.5)
	if floor_y == INF:
		return
	for box in wall_boxes:
		box.position.y = floor_y + box.size.y * 0.5

func _setup_walls():
	# Authored perpendicular join: CurrentWall1 starts on CSGBox3D's positive exit.
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
	_build_sonar_vision_pickup()
	_build_boss_triggers()
	_build_vortex_chest()
	_build_map_chest()
	_build_box_8_dome_barrier()

# Places CSGBox3D6 once where CurrentWall1 would end up after the H swing.
func _place_csgbox6_at_hallway_target() -> void:
	var wall_a: CSGBox3D = $CurrentWall1
	var wall_6: CSGBox3D = $CSGBox3D6
	var wall_7: CSGBox3D = $CSGBox3D7

	# Keeps its authored rotation; only position is computed.

	# Attach to CurrentWall1's future far end, in the rotated wall's local axes.
	var wall_orig = $CSGBox3D
	var wall1_target: Dictionary = _nearest_wall_continuation(wall_a, wall_orig)
	var wall1_target_yaw := float(wall1_target.yaw)
	var wall1_target_position := wall1_target.position as Vector3
	var wall1_future: Dictionary = _wall_geometry_at(wall1_target_position, wall1_target_yaw, wall_a.size)
	# The outer end of wall1_future is whichever is farther from the attachment point.
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
	# Use Box6's own long axis, not CurrentWall1's outward axis.
	var wall6_long_axis := Basis(Vector3.UP, wall_6.rotation.y).x.normalized()
	var wall_6_original_position := wall_6.global_position
	wall_6.global_position = _position_beyond_wall_end(
		wall1_outer_end, wall1_outward_axis, wall_a.size.z,
		wall6_long_axis, wall_6.size.x, wall_6.size.z
	)

	# Box7 is the static opposite side of the passage: keep its authored lateral
	# offset from Box6's pre-correction position, aligned on Box6's cross-line.
	var wall_6_geometry: Dictionary = _wall_geometry(wall_6)
	var lane_side := wall_6_geometry["side_axis"] as Vector3
	var authored_offset := wall_7.global_position - wall_6_original_position
	var preserved_lane_offset := lane_side * authored_offset.dot(lane_side)

	var wall7_long_axis := wall_6_geometry["long_axis"] as Vector3
	var wall6_position := wall_6_geometry["negative_end"] as Vector3
	var wall7_flush_position := wall6_position + wall7_long_axis * (wall_7.size.x * 0.5)
	wall_7.global_position = wall7_flush_position + preserved_lane_offset

# Places CSGBox3D12 once where CurrentWall2 would end up after the H swing (mirrors Box6).
func _place_csgbox12_at_hallway_target() -> void:
	var wall_2: CSGBox3D = $CurrentWall2
	var wall_3: CSGBox3D = $CurrentWall3
	var wall_12: CSGBox3D = $CSGBox3D12
	var wall_13: CSGBox3D = $CSGBox3D13

	# Keeps its authored rotation; only position is computed.

	# Attach to CurrentWall2's future far end.
	var wall2_target: Dictionary = _nearest_wall_continuation(wall_2, wall_3)
	var wall2_target_yaw := float(wall2_target.yaw)
	var wall2_target_position := wall2_target.position as Vector3
	var wall2_future: Dictionary = _wall_geometry_at(wall2_target_position, wall2_target_yaw, wall_2.size)
	# The outer end is whichever is farther from the attachment point on CurrentWall3.
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

# Connects CSGBox3D13 to CSGBox3D7: a long wall flush against Box13 plus a short perpendicular stub.
func _place_new_walls_between_box13_and_box7() -> void:
	var wall_13: CSGBox3D = $CSGBox3D13
	var wall_7: CSGBox3D = $CSGBox3D7
	var wall_13_geometry: Dictionary = _wall_geometry(wall_13)
	var wall_7_geometry: Dictionary = _wall_geometry(wall_7)
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

	# Stub runs perpendicular from the connector's positive end to wall7_target_end;
	# the connector stops size.z short so the stub's thickness fills the gap.
	var connector_geometry: Dictionary = _wall_geometry(connector)
	var connector_positive_end := connector_geometry["positive_end"] as Vector3
	var stub_anchor := connector_positive_end + connector_direction * (wall_13.size.z * 0.5)
	var stub_axis := Vector3(-connector_direction.z, 0.0, connector_direction.x)
	var stub_raw_projection := stub_axis.dot(wall7_target_end - stub_anchor)
	var stub_direction := stub_axis if stub_raw_projection >= 0.0 else -stub_axis
	# Yaw from stub_direction directly so geometry and placement share one axis.
	var stub_yaw := atan2(-stub_direction.z, stub_direction.x)

	# Both anchors are centerlines; extend each end by half the target's thickness.
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

# Box8/9 already have the right rotation; snap each to its target's nearer end.
func _place_box8_and_box9_flush() -> void:
	_place_wall_flush_to_reference($CSGBox3D8, $CSGBox3D12)
	_place_wall_flush_to_reference($CSGBox3D9, $CSGBox3D13)

# Continues the chain from Box8/9. Order matters: a wall must be placed before anything attaches to it.
func _place_remaining_perimeter_walls_flush() -> void:
	_place_wall_flush_to_reference($CSGBox3D11, $CSGBox3D9)
	# Square north-south like Box11.
	($CSGBox3D10 as CSGBox3D).rotation.y = -PI * 0.5
	_place_wall_flush_to_reference($CSGBox3D10, $CSGBox3D8)
	_place_wall_flush_to_reference($CSGBox3D15, $CSGBox3D10)
	_place_wall_flush_to_reference($CSGBox3D14, $CSGBox3D11)
	# Exactly perpendicular to Box15, long axis on +Z.
	($CSGBox3D16 as CSGBox3D).rotation.y = ($CSGBox3D15 as CSGBox3D).rotation.y - PI * 0.5
	_place_wall_flush_to_reference($CSGBox3D16, $CSGBox3D15)

	_place_wall_flush_to_reference($CSGBox3D27, $CSGBox3D14)
	_place_wall_flush_to_reference($CSGBox3D22, $CSGBox3D21)
	# Box17 continues Box27 in a straight line, not at a right angle.
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


# --- Strong-enemy room ---
# Bounded by RewardChamberWestWall, CSGBox3D28 and the built RoomWallA/B; CSGBox3D14/15
# swing open (_rotate_walls_14_15()) to let you in.
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
	# A: south from RewardChamberWestWall past Box14's line.
	var a_x := west_wall.global_position.x
	var a_south := line_z - thickness * 0.5
	var a_length := north_face_z - a_south
	_room_wall_a = _spawn_wall("RoomWallA", Vector3(a_x, mid_y, (north_face_z + a_south) * 0.5), PI * 0.5, Vector3(a_length, height, thickness))
	wall_boxes.append(_room_wall_a)
	# B: east from A to Box11, on Box14's line.
	var b_west := a_x - thickness * 0.5
	var b_east := box11.global_position.x - box11.size.z * 0.5
	_room_wall_b = _spawn_wall("RoomWallB", Vector3((b_west + b_east) * 0.5, mid_y, line_z), 0.0, Vector3(b_east - b_west, height, thickness))
	wall_boxes.append(_room_wall_b)

# Swings CSGBox3D14/15 a quarter turn about their west ends to open the room. Toggles; ignored while moving.
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
		# End to end with wall 11's / 10's north end, running +Z.
		var target := Vector3(joint.x, w.global_position.y, joint.z + w.size.x * 0.5)
		tweens.append(_tween_wall_to_transform_about_hinge(w, target, -PI * 0.5))
	_walls_14_15_open = true
	_track_wall_set_motion("CSGBox3D14/15", tweens, [$CSGBox3D14, $CSGBox3D15])
	$HUD/Controls.text = "Walls 14/15 opening..."
	_update_state_barriers()

# Wall from swung 15's far end north to RewardChamberWestWall's line.
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

# Wall from CSGBox3D7 to RewardChamberWestWall's west end.
func _build_wall_7_to_reward() -> void:
	var w7 := $CSGBox3D7 as CSGBox3D
	var reward := $RewardChamberWestWall as CSGBox3D
	var g: Dictionary = _wall_geometry(reward)
	var west_x := minf((g["negative_end"] as Vector3).x, (g["positive_end"] as Vector3).x)
	var start_x := w7.global_position.x + w7.size.z * 0.5
	var wall := _spawn_wall("Wall7ToReward", Vector3((start_x + west_x) * 0.5, w7.global_position.y, reward.global_position.z), 0.0, Vector3(absf(west_x - start_x), w7.size.y, w7.size.z))
	wall_boxes.append(wall)

# The room's interior on the floor plan.
func _strong_room_rect() -> Rect2:
	if _room_wall_a == null:
		return Rect2()
	# East edge: CSGBox3D28 if present, else the Box27/Box17 line.
	var east := get_node_or_null("CSGBox3D28") as CSGBox3D
	if east == null:
		east = $CSGBox3D27 as CSGBox3D
	var west_wall := $RewardChamberWestWall as CSGBox3D
	var x0 := _room_wall_a.global_position.x + _room_wall_a.size.z * 0.5
	var x1 := east.global_position.x - east.size.z * 0.5
	var z0 := _room_wall_b.global_position.z + _room_wall_b.size.z * 0.5
	var z1 := west_wall.global_position.z - west_wall.size.z * 0.5
	return Rect2(Vector2(x0, z0), Vector2(x1 - x0, z1 - z0))

# Strong zone floor for the maps once first entered; empty Rect2 until then.
func strong_zone_for_map(_revealed_walls: Dictionary) -> Rect2:
	if not _strong_room_seen:
		return Rect2()
	return _strong_room_rect()

func is_diver_in_strong_room() -> bool:
	if _diver == null:
		return false
	return _strong_room_rect().has_point(Vector2(_diver.global_position.x, _diver.global_position.z))

# Orange caption shown while the diver is inside the room.
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
			popup.call("open", pages, self)
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
	# Shown on each entry, then fades.
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

# --- Announcements ---
var _banner: Label
var _banner_timer := 0.0
var _announcements := preload("res://game/orange_message_queue.gd").new()
var _announcement_revision := 0

# While orange text is up, "Press E to interact" is hidden and E does nothing.
var _interact_cooldown := false

func _ensure_banner() -> void:
	if _banner == null:
		_banner = _make_caption(-170.0, -130.0, 20, Color(1.0, 0.6, 0.45))
		Whirlpool.register_banner_owner(self)

func _announce(text: String, seconds := 4.0) -> void:
	_ensure_banner()
	_announcements.push(text, seconds)
	_announcement_revision += 1
	_banner.text = _announcements.current_text()
	_banner_timer = _announcements.seconds_left()
	_refresh_announcement_visibility()

# Whirlpool asks this so its warning waits for the banner.
func announcement_banner_showing() -> bool:
	return _banner != null and _banner.is_visible_in_tree()

func _update_announce(dt: float) -> void:
	if _banner == null:
		return
	if _announcement_readable():
		_announcements.advance(dt)
	_banner.text = _announcements.current_text()
	_banner_timer = _announcements.seconds_left()
	_refresh_announcement_visibility()

func _announcement_readable() -> bool:
	# The open nav map sits in the top-right corner, so announcements stay readable;
	# only its first-open lesson (a paused popup) hides them.
	var popup := get_node_or_null("/root/CharacterAbilityPopup")
	var lesson := popup.get_node_or_null("%AbilityExplanationPanel") as Control if popup != null else null
	var lesson_open := lesson != null and lesson.is_visible_in_tree()
	return maze_active and $HUD.visible and not any_modal_open() and not _battling and not lesson_open

func _refresh_announcement_visibility() -> void:
	Whirlpool.refresh_in(self)
	# Hide World's HP/O2 HUD while a maze reading/battle owner is active.
	if world != null and maze_active:
		world.get_node("HUD").visible = not _battling and not any_modal_open()
	var captions_allowed := _announcement_readable()
	var notice_visible := _banner != null and _banner_timer > 0.0 and captions_allowed
	if _banner != null:
		_banner.visible = notice_visible
	# Only one of status/goal and announcement owns the bottom area at a time.
	var controls := get_node_or_null("HUD/Controls") as CanvasItem
	if controls != null:
		controls.visible = false
	var goal := get_node_or_null("HUD/GoalLabel") as CanvasItem
	if goal != null:
		goal.visible = false   # maze shows no objective line

var _responsive_captions: Array[Label] = []

func _make_caption(top: float, bottom: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -320.0
	label.offset_right = 320.0
	_resize_caption(label)
	_responsive_captions.append(label)
	if not get_viewport().size_changed.is_connected(_resize_captions):
		get_viewport().size_changed.connect(_resize_captions)
	# Designed offsets; _resize_caption() lifts them above the diver bars.
	label.set_meta("caption_top", top)
	label.set_meta("caption_bottom", bottom)
	label.offset_top = top - _caption_lift
	label.offset_bottom = bottom - _caption_lift
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	$HUD.add_child(label)
	return label

func _resize_captions() -> void:
	for label in _responsive_captions:
		if is_instance_valid(label):
			_resize_caption(label)

func _resize_caption(label: Label) -> void:
	var half_width := minf(320.0, maxf(1.0, (get_viewport().get_visible_rect().size.x - 32.0) * 0.5))
	label.offset_left = -half_width
	label.offset_right = half_width
	if label.has_meta("caption_top"):
		label.offset_top = float(label.get_meta("caption_top")) - _caption_lift
		label.offset_bottom = float(label.get_meta("caption_bottom")) - _caption_lift

# The bottom-centre captions (orange notices, "Press E", encounter status) were
# laid out for an empty bottom edge, but World's active-diver O2/HP bars sit
# there. Lift the whole stack so its lowest line (designed bottom -62) ends 8px
# above those bars. Updated each frame; captions only move when it changes.
var _caption_lift := 0.0
const CAPTION_STACK_BOTTOM := -62.0

func _update_caption_lift() -> void:
	var lift := 0.0
	var world_hud := world.get_node_or_null("HUD") as CanvasLayer if world != null else null
	if world_hud != null and world_hud.visible and world.get("hp_bar") != null:
		var top := INF
		for bar in [world.hp_bar, world.oxygen_bar]:
			var wrap := (bar as Control).get_parent() as Control if bar != null else null
			if wrap != null and wrap.is_visible_in_tree():
				top = minf(top, wrap.get_global_rect().position.y)
		if top < INF:
			var bars_offset := top - 8.0 - get_viewport().get_visible_rect().size.y
			lift = maxf(0.0, CAPTION_STACK_BOTTOM - bars_offset)
	if not is_equal_approx(lift, _caption_lift):
		_caption_lift = lift
		_resize_captions()

# --- Random encounters (strong-enemy room only) ---
# Only the active diver's rolls inside the room start a battle. Enemy stats
# (except evasion) are boosted 5-15%.
const ENEMY_BOOST_MIN := 1.05
const ENEMY_BOOST_MAX := 1.15
const BOOSTED_STATS := ["hp_max", "strength", "defense", "agility", "accuracy"]
var room_encounters_enabled := true
var _strong_room_seen := false
var _battling := false
var _battle: Battle
var _encounter_status: Label

func _on_diver_encounter(d: Diver) -> void:
	if _battling or any_modal_open() or _chest_reward_pending or d != _diver:
		return
	# The strong room keeps its forced, boosted fights (R doesn't apply there).
	if is_diver_in_strong_room():
		if room_encounters_enabled:
			_start_battle()
		return
	# Everywhere else in the maze: ordinary random fights, like the overworld,
	# switched by R.
	if random_encounters_enabled:
		_start_battle("random")

# Ambush rock: the hidden enemies swim into view (the overworld's random
# encounter reveal) with the banner up, then the boosted fight starts.
const AMBUSH_TEXT := "Something was hiding in the rock!"
var _ambush_reveal: RandomEncounterReveal

func _begin_ambush_reveal() -> void:
	if not maze_active or _battling or _chest_reward_pending or any_modal_open() or is_instance_valid(_ambush_reveal):
		return
	var selected := Battle.select_ordinary_enemies((divers[0] as Diver).stats.level)
	_cancel_aim()
	for d in divers:
		d.velocity = Vector3.ZERO
	# Shown immediately; queued announcements only tick during exploration.
	_ensure_banner()
	_banner.text = AMBUSH_TEXT
	_banner.visible = true
	var reveal := RandomEncounterReveal.new()
	reveal.enemy_ids = selected
	reveal.camera = $Camera3D as Camera3D
	_ambush_reveal = reveal
	# Freeze exploration while the enemies appear (the reveal runs while paused).
	get_tree().paused = true
	reveal.finished.connect(func() -> void:
		if _ambush_reveal != reveal:
			return
		_end_ambush_reveal()
		_start_battle("ambush", selected)
	, CONNECT_ONE_SHOT)
	add_child(reveal)

func _end_ambush_reveal() -> void:
	if not is_instance_valid(_ambush_reveal):
		return
	_ambush_reveal.set_process(false)
	_ambush_reveal.restore_camera()
	_ambush_reveal.queue_free()
	_ambush_reveal = null
	get_tree().paused = false
	if _banner != null:
		_banner.text = _announcements.current_text()
	_refresh_announcement_visibility()

# kind: "strong", "secret_boss" or "main_boss". revealed_enemy_ids: the
# roster an ambush reveal already showed.
func _start_battle(kind := "strong", revealed_enemy_ids: Array[String] = []) -> void:
	if not maze_active or _battling or _chest_reward_pending:
		return
	_cancel_aim()
	_battling = true
	Whirlpool.refresh_in(self)
	_battle_kind = kind
	_play_maze_music(&"play_cordys_music" if kind == "main_boss" else &"play_battle_music")
	for d in divers:
		d.velocity = Vector3.ZERO
		d.exploration_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	_battle = Battle.new()
	_battle.dev_mode = world != null and world.dev_mode
	match kind:
		"secret_boss":
			_battle.encounter_source = "maze_puppets"
			if route_state != null:
				route_state.set_encounter_source("maze_puppets")
			_battle.encounter_intro_override = "These enemies are guarding a nearby entity..."
			_battle.encounter_intro_hold = 4.0
		"main_boss":
			_announce("Cordys waits for you.")
			_battle.encounter_source = "maze_cordys"
			if route_state != null:
				route_state.set_octopus_state("in_progress")
				route_state.set_encounter_source("maze_cordys")
		"ambush":
			pass   # the reveal already showed "Something was hiding in the rock!"
		"special":
			_announce("A guarded item challenge begins.")
		"random":
			pass   # ordinary fight: no banner, no boost (the battle intro says it)
		_:
			_announce("Strong enemies emerge from the murk!")
	_battle.party_source = divers
	_battle.ordinary_enemy_ids = revealed_enemy_ids.duplicate()
	if kind == "special":
		special_sites.configure_battle(_battle)
		if route_state != null:
			route_state.set_encounter_source("maze_special")
	_battle.inventory_source = inventory
	_battle.campaign_key_items_source = campaign_key_items
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
			# Whole numbers, never above the maximum boost.
			var hi := maxi(base, floori(base * boost_max))
			var lo := clampi(ceili(base * boost_min), base, hi)
			stats.set(field, clampi(roundi(base * randf_range(boost_min, boost_max)), lo, hi))
		stats.hp = stats.hp_max
	battle._refresh_all_bars()

func _on_battle_finished(result: String) -> void:
	for diver in divers:
		diver.exploration_paused = false
		diver.reset_passives_after_battle()
	_battle.queue_free()
	_battle = null
	_battling = false
	# Divers KO'd in a won fight stay at 0 HP until revived.
	var kind := _battle_kind
	_battle_kind = "strong"
	if kind == "special":
		special_sites.finish(result)
		_play_maze_music(&"play_exploration_music")
		if route_state != null:
			route_state.set_encounter_source("random")
		return
	if kind == "main_boss" and route_state != null:
		route_state.set_octopus_state("defeated" if result == "won" else "available")
	if result in ["won", "fled", "skipped"]:
		_play_maze_music(&"play_exploration_music")
	if result == "won" and kind == "secret_boss":
		_remove_boss_trigger("secret_boss")
		_gain_key("abyss_key", "")   # silent: the Cordys reveal follows
		get_tree().create_timer(1.5).timeout.connect(_reveal_cordys)
		return
	if result == "won" and kind == "main_boss":
		_remove_boss_trigger("main_boss")
		_announce("Cordys is defeated. You have overcome the creature that broke you.", 8.0)
		campaign_completed.emit()
		return
	match result:
		"won":
			_announce("The enemy backs off into the dark." if kind == "random" else "The strong enemies were defeated.")
		"fled":
			_announce("You escaped.")
		_:
			_show_campaign_game_over()

func _remove_boss_trigger(kind: String) -> void:
	var trigger: Node = _boss_triggers.get(kind, null)
	if trigger != null and is_instance_valid(trigger):
		trigger.queue_free()
	_boss_triggers.erase(kind)

# Grey line shown in the room: encounters are forced on there.
func _update_encounter_status(inside: bool) -> void:
	if _encounter_status == null:
		if not inside:
			return
		_encounter_status = _make_caption(-90.0, -62.0, 15, Color(0.6, 0.62, 0.65))
	_encounter_status.visible = inside
	_encounter_status.text = "Random encounters: ON (can't be turned off here)" if room_encounters_enabled else "Random encounters: OFF (developer switch)"

# --- Room switch ---
# Box at the -X end of CSGBox3D19. E opens the switch minigame; Shift+E toggles encounters (dev).
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
	# Just off Box19's west end, on its room side.
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

# Once solved, the light stays green and E no longer opens the puzzle.
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

# Dev spawn: party at the switch box with the room's encounters off.
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

# True while "Press E to interact/open" would show: something E acts on is in
# reach. The open nav map checks this so E interacts before it rotates walls.
func interact_available() -> bool:
	if _interact_cooldown or _diver == null:
		return false
	var poster := _poster_in_reach()
	if not _poster_beats_switch(poster):
		poster = null
	return (_diver_near_switch() and not _switch_puzzle_done()) or poster != null \
		or (_free_lever_in_reach() != null and _lever_held_by(_diver) == null) \
		or _secret_entrance_in_reach() or _vortex_chest_in_reach() or _map_chest_in_reach() \
		or _split_rock_in_reach()

# "Press E to interact" while next to the switch.
func _update_room_switch() -> void:
	var poster := _poster_in_reach()
	if not _poster_beats_switch(poster):
		poster = null
	for p in _posters:
		p.set_highlight(p == poster)
	var at_chest := _vortex_chest_in_reach() or _map_chest_in_reach()
	if _interact_cooldown and (_banner == null or _banner_timer <= 0.0):
		_interact_cooldown = false
	var near := interact_available()
	if _switch_prompt == null:
		if not near:
			return
		_switch_prompt = _make_caption(-128.0, -96.0, 18, Color(1, 1, 1))
	_switch_prompt.text = "Press E to open" if at_chest else "Press E to interact"
	_switch_prompt.visible = near

var _switch_modal: SwitchMinigameModal

# --- Wall posters ---
# One on a wall capping the CurrentWall1/2 hallway, one on CSGBox3DConnector north of Box13.
# Each shows a random diver and a number 1-3 (poster_clues); E opens a PosterModal.
const POSTER_REACH := 2.0
const POSTER_CENTER_HEIGHT := 1.7   # above swim height
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

# Wall capping the north end of the CurrentWall1/2 hallway.
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

# Fraction along CSGBox3DConnector of the middle of its open-water stretch beyond Box13.
func _connector_free_stretch_t() -> float:
	var connector := $CSGBox3DConnector as CSGBox3D
	var gc: Dictionary = _wall_geometry(connector)
	var g13: Dictionary = _wall_geometry($CSGBox3D13 as CSGBox3D)
	var neg := gc["negative_end"] as Vector3
	var axis := gc["long_axis"] as Vector3
	var box13_far := maxf(((g13["negative_end"] as Vector3) - neg).dot(axis), ((g13["positive_end"] as Vector3) - neg).dot(axis))
	return (box13_far + connector.size.x) * 0.5 / connector.size.x

# [position, outward normal] for a poster on `wall`'s face toward `toward`, `t` along it.
func _poster_spot_on(wall: CSGBox3D, toward: Vector3, t: float) -> Array:
	var g: Dictionary = _wall_geometry(wall)
	var side := g["side_axis"] as Vector3
	var normal := side if side.dot(toward) > 0.0 else -side
	var along := (g["negative_end"] as Vector3).lerp(g["positive_end"] as Vector3, t)
	var pos := along + normal * (wall.size.z * 0.5 + 0.03)
	pos.y = ($DiverEntry as Node3D).global_position.y + POSTER_CENTER_HEIGHT
	return [pos, normal]

# When both are in reach, the nearer of poster and switch gets E.
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

# The poster in reach in front of the active diver, or null.
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

func whirlpool_activity() -> int:
	if not maze_active or _battling:
		return Whirlpool.Activity.INACTIVE
	if not _announcement_readable() or _chest_reward_pending or _gate_cutscene or _cordys_reveal:
		return Whirlpool.Activity.SUSPENDED
	return Whirlpool.Activity.EXPLORING

# A real menu/prompt that shouldn't stack on the open nav map. Unlike
# any_modal_open(), wall rotation (_wall_riders) doesn't count: rotating walls
# is done from the map itself.
func _menu_over_map() -> bool:
	return (_save_menu != null and _save_menu.visible) or _checkpoint_saving \
		or (inventory_menu != null and inventory_menu.visible) or switch_modal_open() or poster_modal_open() \
		or (_puppet_prompt != null and is_instance_valid(_puppet_prompt)) \
		or (_cordys_prompt != null and is_instance_valid(_cordys_prompt)) \
		or (draft_passages != null and draft_passages.modal_open()) \
		or (special_sites != null and special_sites.modal_open())

# Green cone over the active diver, as in the overworld (World owns the mesh and
# hides it on entering the maze). Hidden while choosing a swap target, aiming,
# battling or in a menu.
func _update_active_cursor() -> void:
	if world == null or world.get("_active_cursor") == null:
		return
	var cursor := world._active_cursor as MeshInstance3D
	var selecting := target_selector != null and target_selector.selecting
	var show := maze_active and _diver != null and not _battling and not aiming \
		and not selecting and not any_modal_open()
	cursor.visible = show
	if show:
		cursor.global_position = _diver.global_position + Vector3.UP * (_diver.height * 0.5 + 0.45)

func any_modal_open() -> bool:
	return _wall_riders.busy() or _menu_over_map()

func _open_poster(poster: MazePoster) -> void:
	if any_modal_open():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	poster.mark_seen()
	_poster_modal = PosterModal.new(poster)
	add_child(_poster_modal)

# Latest mouse press start while the modal is open, and whether it was on the modal.
var modal_press_start := Vector2.ZERO
var modal_press_started_inside := false

# The switch modal freezes the maze like a battle.
func switch_modal_open() -> bool:
	return _switch_modal != null and is_instance_valid(_switch_modal)

# First use shows an explainer before the minigame.
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
			"body": "The diver portraits are in the wrong lanes (labeled 1-3 at the bottom of the lanes). " + Slot._badge("Left click") + " to draw lines underneath the falling portraits to move them over to the other lanes where they correctly need to be placed. A portrait only follows a line over if the line was started in the lane it's falling down (the arrow shows which way a line goes). The lines don't have to be perfectly straight - they snap straight across when you let go.",
			"slot": null,
			"media_control": func() -> Control: return PortraitDemoClip.new(demo_textures),
		}]
		popup.closed.connect(_open_switch_minigame, CONNECT_ONE_SHOT)
		popup.call("open", pages, self)
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
	# Start every portrait in a wrong lane (shift by 1 or 2, wrapping).
	var shift := randi_range(1, 2)
	var lanes: Array = [0, 1, 2]
	for p in _posters:
		lanes[p.diver_index] = (p.number - 1 + shift) % 3
	_switch_modal.start_lanes = lanes
	_switch_modal.all_arrived.connect(_on_switch_puzzle_arrived)
	_switch_modal.retry_requested.connect(_retry_switch_minigame)
	add_child(_switch_modal)

# While the switch modal is open, mouse presses/drags draw lines on it.
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

# Door gap: width x height (Door's default span).
const DOOR_OPENING := Vector2(2.3, 6.0)

# Wall from Box30's positive end to Box32 with a DOOR_OPENING gap and lintel. Run after flush placement.
func _build_door_frame_between_box30_and_box32() -> void:
	var box30 := $CSGBox3D30 as CSGBox3D
	var box32 := $CSGBox3D32 as CSGBox3D
	var g30: Dictionary = _wall_geometry(box30)
	var g32: Dictionary = _wall_geometry(box32)

	var side30 := g30["side_axis"] as Vector3
	var toward := side30 if ((g32["center"] as Vector3) - (g30["center"] as Vector3)).dot(side30) > 0.0 else -side30
	var outward := g30["long_axis"] as Vector3
	var end30 := g30["positive_end"] as Vector3
	var thickness := box30.size.z
	var line_origin := end30 + outward * thickness * 0.5

	# From Box30's far face to Box32's near face.
	var start := line_origin - toward * box30.size.z * 0.5
	var length := ((g32["center"] as Vector3) - start).dot(toward) - box32.size.z * 0.5
	var piece_length := (length - DOOR_OPENING.x) * 0.5
	if piece_length <= 0.0:
		push_warning("_build_door_frame_between_box30_and_box32: walls are too close for the door opening")
		return

	var height := box30.size.y
	var bottom := box30.global_position.y - height * 0.5
	var yaw := atan2(-toward.z, toward.x)   # long axis along `toward`

	var piece_a := start + toward * piece_length * 0.5
	var piece_b := start + toward * (length - piece_length * 0.5)
	var door_center := start + toward * (piece_length + DOOR_OPENING.x * 0.5)
	piece_a.y = bottom + height * 0.5
	piece_b.y = bottom + height * 0.5
	wall_boxes.append(_spawn_wall("Box30DoorWallA", piece_a, yaw, Vector3(piece_length, height, thickness)))
	wall_boxes.append(_spawn_wall("Box30DoorWallB", piece_b, yaw, Vector3(piece_length, height, thickness)))

	# Not in wall_boxes so the minimap shows the doorway open; lintel meets the door's top.
	var opening_height := _key_door_height()
	var lintel_height := height - opening_height
	_door30_center = Vector3(door_center.x, bottom, door_center.z)
	door_center.y = bottom + opening_height + lintel_height * 0.5
	_spawn_wall("Box30DoorLintel", door_center, yaw, Vector3(DOOR_OPENING.x, lintel_height, thickness))

# --- Doors (KeyDoor) ---
# Wall 16's gap and the Box30/32 opening. Scaled to fill DOOR_OPENING; wheel side faces the approach.
const KEY_DOOR_WIDTH_PER_HEIGHT := 1.809661 / 3.2   # model width : height
var _door30_center := Vector3.ZERO   # floor-level centre of the 30/32 doorway
var _maze_doors: Array[KeyDoor] = []

func _key_door_height() -> float:
	return DOOR_OPENING.x / KEY_DOOR_WIDTH_PER_HEIGHT

func _build_maze_doors() -> void:
	# Wall 16 gap, approached from the Box17/27 side.
	var w16 := $CSGBox3D16 as CSGBox3D
	var gn: Dictionary = _wall_geometry($CSGBox3D16North as CSGBox3D)
	var g16: Dictionary = _wall_geometry(w16)
	var z16_top := maxf((g16["negative_end"] as Vector3).z, (g16["positive_end"] as Vector3).z)
	var zn_bottom := minf((gn["negative_end"] as Vector3).z, (gn["positive_end"] as Vector3).z)
	var bottom16 := w16.global_position.y - w16.size.y * 0.5
	var toward_passage := Vector3(-1, 0, 0) if ($CSGBox3D27 as CSGBox3D).global_position.x < w16.global_position.x else Vector3(1, 0, 0)
	_spawn_key_door("MazeDoor16", Vector3(w16.global_position.x, bottom16, (z16_top + zn_bottom) * 0.5), toward_passage, "sphere_room_key")
	# Box30/32, approached from the Box29/33 side.
	if _door30_center != Vector3.ZERO:
		var box30 := $CSGBox3D30 as CSGBox3D
		var room_side := -1.0 if box30.global_position.x < _door30_center.x else 1.0
		_spawn_key_door("MazeDoor30", _door30_center, Vector3(-room_side, 0, 0), "vortex_key")
		_build_secret_boss_room()

# KeyDoor with bottom-centre at `floor_point`, wheel side toward `approach`.
func _spawn_key_door(door_name: String, floor_point: Vector3, approach: Vector3, key_id := "") -> KeyDoor:
	var door := KeyDoor.new()
	door.name = door_name
	door.door_id = door_name
	door.required_key_id = key_id
	door.key_source = func() -> Array: return key_items
	# Any key opens any door.
	door.key_count_source = func() -> int: return keys_held
	door.spend_key = func() -> void: keys_held = maxi(keys_held - 1, 0)
	door.visual_height = _key_door_height()
	door.interaction_radius = 3.0
	door.active_diver_source = func() -> Diver: return _diver
	door.announce = _announce
	add_child(door)
	door.global_position = floor_point
	door.rotation.y = atan2(approach.x, approach.z)   # wheel side toward `approach`
	_maze_doors.append(door)
	return door

# A door the active diver could unlock with E now.
func door_ready_to_unlock() -> bool:
	for door in _maze_doors:
		if is_instance_valid(door) and door.can_unlock(_diver):
			return true
	return false

# E for doors: the first one in reach that takes it.
func _try_open_door(ready_only := false) -> bool:
	for door in _maze_doors:
		# Must use the same eligible door the map found.
		if ready_only and (not is_instance_valid(door) or not door.can_unlock(_diver)):
			continue
		if is_instance_valid(door) and door.interact(_diver):
			return true
	return false

# --- Left secret wall entrance ---
# Flashing panel on CSGBox3D27's passage side; E enters left_maze_secret_wall.tscn.
const SECRET_WALL_SCENE := "res://game/left_maze_secret_wall.tscn"
const SECRET_ENTRANCE_REACH := 2.5
var _secret_entrance: MeshInstance3D
var _secret_transition_pending := false

func _build_secret_wall_entrance() -> void:
	var w27 := $CSGBox3D27 as CSGBox3D
	var g: Dictionary = _wall_geometry(w27)
	var mid := ((g["negative_end"] as Vector3) + (g["positive_end"] as Vector3)) * 0.5
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
	var pulse := create_tween().set_loops()
	pulse.tween_property(mat, "emission_energy_multiplier", 3.0, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(mat, "emission_energy_multiplier", 0.4, 0.5).set_trans(Tween.TRANS_SINE)
	_secret_entrance.set_meta("face", face)

func _secret_entrance_in_reach() -> bool:
	if _secret_entrance == null or _diver == null:
		return false
	var offset := _diver.global_position - _secret_entrance.global_position
	offset.y = 0.0
	var face := float(_secret_entrance.get_meta("face"))
	return offset.length() <= SECRET_ENTRANCE_REACH and offset.x * face > 0.0

func _enter_secret_wall() -> void:
	if _secret_transition_pending:
		return
	if not can_capture_campaign_snapshot():
		_announce("Wait for the puzzle movement to finish.")
		return
	if campaign_session == null:
		campaign_session = CampaignSession.new()
		campaign_session.route_state = RouteState.new()
	campaign_session.capture_party(divers, active)
	campaign_session.inventory = inventory
	campaign_session.maze_snapshot = campaign_snapshot()
	SceneHandoff.campaign_session = campaign_session
	SceneHandoff.diver_model = _diver.model_name
	_secret_transition_pending = true
	_change_to_secret_wall.call_deferred()

func _change_to_secret_wall() -> void:
	var error := get_tree().change_scene_to_file(SECRET_WALL_SCENE)
	if error != OK:
		SceneHandoff.campaign_session = null
		_secret_transition_pending = false
		_announce("Could not enter the secret passage. Try again.")

# Returning from the secret scene: party in front of the entrance.
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
		if _lever_held_by(divers[i]) != null:
			continue
		var slot: int = (i - active + divers.size()) % divers.size()
		divers[i].global_position = spot + Vector3(0, 0, float(offsets[slot]))
		divers[i].velocity = Vector3.ZERO
	_yaw = atan2(-face, 0.0)   # facing the entrance

# --- Sphere room and Sonar Vision ---
# Invisible spheres swirl in the room behind wall 16's door; sonar shows them on the minimap,
# Maxilani's Q in 3D.
var _swirl_room: SwirlRoom
# Legacy save field; vision is always part of Q now.
var has_sonar_vision := true
var sonar_vision_equipped := true

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
	_swirl_room = SwirlRoom.new()
	_swirl_room.name = "SphereRoom"
	# Full swimmable height (floor/ceiling one clearance beyond the walls).
	var wall_bottom := w16.global_position.y - w16.size.y * 0.5
	var wall_top := w16.global_position.y + w16.size.y * 0.5
	_sphere_room_interior = interior
	_swirl_room.setup(interior, wall_bottom - _FLOOR_CLEARANCE, wall_top + _CEILING_CLEARANCE)
	add_child(_swirl_room)
	_swirl_room.diver_hit.connect(func(d: Diver) -> void:
		if d == _diver and not sonar_vision_active():
			_announce("Some hidden items in this room seem to be doing damage...", 2.5))

# --- Boss rooms ---
# Secret: between Box30 and Box32 behind the Vortex Key door; two puppet waves drop the Abyss Key.
# Main: through the Abyss Key door in Box33 opposite; Cordys waits inside for the rematch.
const SECRET_BOSS_BOOST := Vector2(1.4, 1.6)
var key_items: Array[String] = []
var _battle_kind := "strong"
var _boss_triggers: Dictionary = {}   # boss id -> staged Node3D
var _main_boss_door_z := 0.0
const BOSS_DANGER_PROMPT := "A great danger is detected here. Are you sure you would like to proceed?"
const CORDYS_PROMPT_RADIUS := 6.0
var _cordys_prompt: ConfirmPromptModal
var _cordys_prompt_armed := true
var _cordys_touch_radius := 1.0
# Diver-to-Cordys gap (beyond touching) that still counts as bumping into him.
const CORDYS_TOUCH_MARGIN := 0.35

func _build_secret_boss_room() -> void:
	var box30 := $CSGBox3D30 as CSGBox3D
	var box32 := $CSGBox3D32 as CSGBox3D
	var g30: Dictionary = _wall_geometry(box30)
	var g32: Dictionary = _wall_geometry(box32)
	# Far (west) end of Box30/Box32.
	var far_x := minf(minf((g30["negative_end"] as Vector3).x, (g30["positive_end"] as Vector3).x), minf((g32["negative_end"] as Vector3).x, (g32["positive_end"] as Vector3).x))
	var z0 := box30.global_position.z
	var z1 := box32.global_position.z
	var t := box30.size.z
	var back := _spawn_wall("SecretBossRoomBack", Vector3(far_x, box30.global_position.y, (z0 + z1) * 0.5), PI * 0.5, Vector3(absf(z1 - z0) + t, box30.size.y, t))
	wall_boxes.append(back)

# Splits CSGBox3D33 around a door opposite the Box30/32 door, then builds the main boss room.
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
	# Lintel down to the door's top (off the minimap).
	var opening_h := _key_door_height()
	_spawn_wall("CSGBox3D33Lintel", Vector3(x, bottom + opening_h + (h - opening_h) * 0.5, door_z), PI * 0.5, Vector3(DOOR_GAP_WIDTH, h - opening_h, t))
	_spawn_key_door("MazeDoorMainBoss", Vector3(x, bottom, door_z), Vector3(-1, 0, 0), "abyss_key")
	# North wall on Box32's line, south wall clear of Box22.
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

# --- Cordys's patrolling puppets ---
const PUPPET_HOVER := 1.0
const PUPPET_TOP := 4.6
const PUPPET_REACH := 4.4
const PUPPET_HEADROOM := 1.5
const PUPPET_SPEED := 2.2
const PUPPET_PROMPT_RADIUS := 3.8
# Solid box around the three puppets (they sit at x = -2, 0, 2), plus the
# touch margin that triggers the prompt.
const PUPPET_BODY_SIZE := Vector3(5.8, 2.8, 2.8)
const PUPPET_BODY_CENTER := Vector3(0, 0.9, 0.5)
const PUPPET_TOUCH_MARGIN := 0.35
const PUPPET_PROMPT_TEXT := BOSS_DANGER_PROMPT
var _puppet_patrol: Node3D
var _puppet_guard_actors: Array[Goblin] = []
var _puppet_route: Array[Vector3] = []
var _puppet_target := 0
var _puppet_pause := 0.0
var _puppet_prompt: ConfirmPromptModal
var _puppet_prompt_cooldown := 0.0

func _maze_floor_top() -> float:
	var w := $CSGBox3D16 as CSGBox3D
	return w.global_position.y - w.size.y * 0.5 - _FLOOR_CLEARANCE

# Secret boss room rect: interior if `inside`, else outer wall edges.
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

func _build_puppet_patrol() -> void:
	var room := _secret_boss_room_rect(true)
	if room.size == Vector2.ZERO:
		return
	var inset := PUPPET_REACH + 0.6
	var y := _maze_floor_top() + PUPPET_HOVER
	var a := room.position + Vector2(inset, inset)
	var b := room.end - Vector2(inset, inset)
	_puppet_route = [Vector3(a.x, y, a.y), Vector3(b.x, y, a.y), Vector3(b.x, y, b.y), Vector3(a.x, y, b.y)]
	_puppet_patrol = Node3D.new()
	_puppet_patrol.name = "PatrollingPuppets"
	add_child(_puppet_patrol)
	_puppet_patrol.global_position = _puppet_route[0]
	_puppet_target = 1
	for index in range(Battle.PUPPET_WAVES[0].size()):
		var actor := Battle.actor_for_enemy_id(String(Battle.PUPPET_WAVES[0][index]))
		_puppet_patrol.add_child(actor)
		actor.position = Vector3(float(index - 1) * 2.0, 0.0, float(index % 2))
		actor.play("swim")
		_puppet_guard_actors.append(actor)
	var label := Label3D.new()
	label.text = "Cordys's puppets"
	label.font_size = 32
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.6
	_puppet_patrol.add_child(label)
	# Solid: the party bumps into the puppets instead of swimming through them.
	# AnimatableBody so the moving patrol pushes rather than overlaps.
	var solid := AnimatableBody3D.new()
	var solid_shape := CollisionShape3D.new()
	var solid_box := BoxShape3D.new()
	solid_box.size = PUPPET_BODY_SIZE
	solid_shape.shape = solid_box
	solid_shape.position = PUPPET_BODY_CENTER
	solid.add_child(solid_shape)
	_puppet_patrol.add_child(solid)
	# Touching them (a thin shell around the body) asks the danger question.
	var area := Area3D.new()
	area.collision_mask = 2   # divers
	var shape := CollisionShape3D.new()
	var touch_box := BoxShape3D.new()
	touch_box.size = PUPPET_BODY_SIZE + Vector3.ONE * PUPPET_TOUCH_MARGIN * 2.0
	shape.shape = touch_box
	shape.position = PUPPET_BODY_CENTER
	area.add_child(shape)
	_puppet_patrol.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if maze_active and body == _diver and not _battling and not any_modal_open() and _puppet_prompt_cooldown <= 0.0:
			_open_puppet_prompt())
	_boss_triggers["secret_boss"] = _puppet_patrol

func _update_puppet_patrol(dt: float) -> void:
	if _puppet_patrol == null or not is_instance_valid(_puppet_patrol):
		return
	_puppet_prompt_cooldown = maxf(0.0, _puppet_prompt_cooldown - dt)
	if _battling or any_modal_open():
		return
	if _puppet_pause > 0.0:
		_puppet_pause -= dt
		if _puppet_pause <= 0.0:
			for actor in _puppet_guard_actors:
				actor.play("swim")
		return
	var target := _puppet_route[_puppet_target]
	var to := target - _puppet_patrol.global_position
	to.y = 0.0
	if to.length() < 0.05:
		_puppet_target = (_puppet_target + 1) % _puppet_route.size()
		for actor in _puppet_guard_actors:
			actor.face_toward(_puppet_route[_puppet_target])
			actor.play("idle")
		_puppet_pause = 1.5
		return
	for actor in _puppet_guard_actors:
		actor.face_toward(target)
	_puppet_patrol.global_position += to.normalized() * minf(PUPPET_SPEED * dt, to.length())

func _open_puppet_prompt() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	_diver.velocity = Vector3.ZERO
	_puppet_prompt = ConfirmPromptModal.new(PUPPET_PROMPT_TEXT)
	_puppet_prompt.answered.connect(func(yes: bool) -> void:
		_puppet_prompt = null
		if yes:
			cordys_fight_starting.emit()   # autosave right before the puppet fight
			_start_battle("secret_boss")
			return
		# Push out of reach and briefly stop asking.
		var away := _diver.global_position - _puppet_patrol.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0)
		var spot := _puppet_patrol.global_position + away * (PUPPET_PROMPT_RADIUS + 1.5)
		spot.y = _diver.global_position.y
		_diver.global_position = spot
		_diver.velocity = Vector3.ZERO
		_puppet_prompt_cooldown = 2.0)
	add_child(_puppet_prompt)

# Completion IDs must stay stable for old checkpoints.
func _build_boss_triggers() -> void:
	_build_puppet_patrol()
	var north := get_node_or_null("MainBossRoomNorth") as CSGBox3D
	var south := get_node_or_null("MainBossRoomSouth") as CSGBox3D
	if north != null and south != null:
		var station := Node3D.new()
		station.name = "StationedCordys"
		add_child(station)
		var actor := PrologueOctopus.new()
		actor.name = "Cordys"
		station.add_child(actor)
		# Normalize the skin at the origin (like Battle), then move it into the room.
		station.global_position = Vector3(north.global_position.x, _maze_floor_top() + 0.3,
			clampf(_main_boss_door_z, _main_boss_room_rect().position.y + actor.radius + 0.5,
				_main_boss_room_rect().end.y - actor.radius - 0.5))
		actor.face_toward(Vector3(($CSGBox3D33 as Node3D).global_position.x, station.global_position.y, _main_boss_door_z))
		var label := Label3D.new()
		label.text = "Cordys"
		label.font_size = 40
		label.pixel_size = 0.012
		label.outline_size = 5
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, actor.height + 0.7, 0)
		station.add_child(label)
		_boss_triggers["main_boss"] = station
		# Solid body; AnimatableBody so it can move with him out of the cave.
		var solid := AnimatableBody3D.new()
		solid.name = "CordysBody"
		var solid_shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = actor.radius
		cyl.height = actor.height
		solid_shape.shape = cyl
		solid_shape.position = Vector3(0, actor.height * 0.5, 0)
		solid.add_child(solid_shape)
		station.add_child(solid)
		_cordys_touch_radius = actor.radius
		_build_cordys_cave(station, actor)
		_set_cordys_out(not _boss_triggers.has("secret_boss"))

func _update_cordys_station() -> void:
	var station := _boss_triggers.get("main_boss") as Node3D
	if not is_instance_valid(station) or station.is_queued_for_deletion() or not _cordys_out:
		return
	# Asks only when the diver bumps into him (horizontal contact with his body).
	var distance := Vector2(_diver.global_position.x - station.global_position.x,
		_diver.global_position.z - station.global_position.z).length()
	var touch := _cordys_touch_radius + _diver.radius + CORDYS_TOUCH_MARGIN
	# After declining, the player must back away before being asked again.
	if distance > touch + 1.5:
		_cordys_prompt_armed = true
		return
	if not _cordys_prompt_armed or distance > touch \
		or not can_capture_campaign_snapshot() or not _announcement_readable():
		return
	if not _main_boss_room_rect().has_point(Vector2(_diver.global_position.x, _diver.global_position.z)):
		return # Never ask through a wall.
	_cancel_aim()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_look = false
	_diver.velocity = Vector3.ZERO
	_cordys_prompt_armed = false
	_cordys_prompt = ConfirmPromptModal.new(BOSS_DANGER_PROMPT)
	_cordys_prompt.answered.connect(func(yes: bool) -> void:
		_cordys_prompt = null
		if yes and _boss_triggers.has("main_boss"):
			cordys_fight_starting.emit()
			_start_battle("main_boss"))
	add_child(_cordys_prompt)

# --- Cordys's cave: he hides at the east end of the main boss room until his
# puppets are beaten, then a camera pan shows him coming out. ---
const CAVE_DEPTH := 4.0
var _cordys_cave: Node3D
var _cordys_out := false
var _cordys_hide_pos := Vector3.ZERO
var _cordys_out_pos := Vector3.ZERO
var _cordys_reveal := false          # camera cutscene running
var _cordys_view_spot := Vector3.ZERO

func _build_cordys_cave(station: Node3D, actor: Node3D) -> void:
	var rect := _main_boss_room_rect()
	if rect.size == Vector2.ZERO:
		return
	var floor_y := _maze_floor_top()
	var cordys_radius := float(actor.get("radius"))
	var cordys_height := float(actor.get("height"))
	var z := station.global_position.z
	var mouth_x := rect.end.x - CAVE_DEPTH
	var mouth_h := cordys_height + 1.2
	var half_w := cordys_radius + 1.0
	_cordys_out_pos = station.global_position
	_cordys_hide_pos = Vector3(mouth_x + CAVE_DEPTH * 0.5, station.global_position.y, z)
	_cordys_view_spot = Vector3(lerpf(rect.position.x, mouth_x, 0.25), floor_y + 5.0,
		clampf(z + 3.0, rect.position.y + 1.0, rect.end.y - 1.0))

	_cordys_cave = Node3D.new()
	_cordys_cave.name = "CordysCave"
	add_child(_cordys_cave)
	# Dark interior: an opaque block that hides him until he swims out of it.
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.01, 0.02, 0.03)
	var hole := MeshInstance3D.new()
	var hole_box := BoxMesh.new()
	hole_box.size = Vector3(CAVE_DEPTH, mouth_h, half_w * 2.0)
	hole.mesh = hole_box
	hole.material_override = dark
	_cordys_cave.add_child(hole)
	hole.global_position = Vector3(mouth_x + CAVE_DEPTH * 0.5, floor_y + mouth_h * 0.5, z)
	# Faceted rocks: an arch around the mouth, then a mound over and around it.
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	stone.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var rocks: Array[Array] = []   # [position, radius]
	for i in 11:
		var a := PI * float(i) / 10.0
		rocks.append([Vector3(mouth_x, floor_y + sin(a) * mouth_h, z + cos(a) * (half_w + 0.5)), rng.randf_range(0.9, 1.4)])
	for i in 14:
		rocks.append([Vector3(rng.randf_range(mouth_x + 0.5, rect.end.x - 0.5), floor_y + mouth_h + rng.randf_range(-0.6, 0.9),
			z + rng.randf_range(-half_w - 1.5, half_w + 1.5)), rng.randf_range(1.2, 2.0)])
	for side in [-1.0, 1.0]:
		for i in 3:
			rocks.append([Vector3(rng.randf_range(mouth_x + 0.6, rect.end.x - 0.6), floor_y + rng.randf_range(0.4, mouth_h),
				z + side * (half_w + rng.randf_range(1.0, 1.8))), rng.randf_range(1.2, 1.8)])
	for spec in rocks:
		var rock := MeshInstance3D.new()
		rock.mesh = _broken_half_mesh(float(spec[1]), rng)
		rock.material_override = stone
		rock.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		_cordys_cave.add_child(rock)
		rock.global_position = spec[0]
	# Solid: the party can't swim into the cave.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CAVE_DEPTH, mouth_h + 2.0, half_w * 2.0 + 3.0)
	shape.shape = box
	body.add_child(shape)
	_cordys_cave.add_child(body)
	body.global_position = Vector3(mouth_x + CAVE_DEPTH * 0.5, floor_y + (mouth_h + 2.0) * 0.5, z)

# Instantly in the cave (hidden, no prompt) or out in the room.
func _set_cordys_out(out: bool) -> void:
	var station := _boss_triggers.get("main_boss") as Node3D
	if not is_instance_valid(station) or _cordys_cave == null:
		return
	_cordys_out = out
	station.global_position = _cordys_out_pos if out else _cordys_hide_pos
	for child in station.get_children():
		(child as Node3D).visible = out
	var body := station.get_node_or_null("CordysBody")
	if body != null:
		for shape in body.get_children():
			(shape as CollisionShape3D).set_deferred("disabled", not out)

# After the puppets fall: pan to the cave and watch Cordys swim out.
func _reveal_cordys() -> void:
	var station := _boss_triggers.get("main_boss") as Node3D
	if not is_instance_valid(station) or _cordys_out or _cordys_cave == null:
		return
	var autosave_text := ""
	if world != null:
		autosave_text = await world.autosave_after_boss()
	_cordys_reveal = true
	_cancel_aim()
	_diver.velocity = Vector3.ZERO
	var actor := station.get_node_or_null("Cordys") as PrologueOctopus
	var tw := create_tween()
	tw.tween_interval(1.8)   # camera travel
	tw.tween_callback(func() -> void:
		for child in station.get_children():
			(child as Node3D).visible = true
		if actor != null:
			actor.play("idle"))
	tw.tween_property(station, "global_position", _cordys_out_pos, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_set_cordys_out(true)
		if actor != null:
			actor.play("reveal"))
	tw.tween_interval(2.0)
	tw.tween_callback(func() -> void:
		if actor != null:
			actor.play("idle")
		_cordys_reveal = false
		if autosave_text != "":
			_announce(autosave_text)
		_announce("Cordys has left his cave. He waits for you beyond the Abyss Key door.", 5.0))

# --- Secret item room (the reward chamber) ---
# Rocks broken with Bucky's Shockwave. ItemRock is the completion relic; others give
# SECRET_ITEM_ROCKS rewards (item ids from items.gd, or "ambush").
const SECRET_ITEM_ROCKS := {
	"ItemRock2": "sphere_room_key",
	"ItemRock3": "attack_up",
	"Marker3D2": "defense_up",
	"Marker3D4": "defense_up",
	"Marker3D5": "ambush",
	"Marker3D7": "ambush",
}
const SECRET_ROCK_HEADROOM := 2.6   # raised ceiling above the highest rock
# Party items (item id -> count), used by battles' Items menu.
var inventory: Dictionary = {}

# Real extent of a room whose walls run past it; empty Rect2 = use the walls' extent.
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
		rock.sphere_shaped = true   # brown
		var spot := _spread_secret_rock(marker.global_position)
		rock.position = spot
		var reward: String = SECRET_ITEM_ROCKS[marker_name]
		rock.set_meta("reward", reward)   # "ambush" rocks get no red circle
		rock.broken.connect(_on_secret_rock_broken.bind(reward, spot))
		add_child(rock)
		_secret_room_rocks.append(rock)

# Pushes a rock marker away from the rocks' middle (XZ) so they sit further apart.
# A push that would cross a wall or end within SECRET_ROCK_CLEARANCE of one is
# shortened back toward the marker until it's clear.
const SECRET_ROCK_SPREAD := 1.4
const SECRET_ROCK_CLEARANCE := 0.9   # rock radius 0.5 plus visible air
func _spread_secret_rock(spot: Vector3) -> Vector3:
	var markers_xz := Vector2.ZERO
	var count := 0
	for node in get_tree().get_nodes_in_group("ItemRock"):
		markers_xz += Vector2((node as Node3D).global_position.x, (node as Node3D).global_position.z)
		count += 1
	for marker_name in SECRET_ITEM_ROCKS:
		var m := get_node_or_null(String(marker_name)) as Node3D
		if m != null:
			markers_xz += Vector2(m.global_position.x, m.global_position.z)
			count += 1
	if count < 2:
		return spot
	var mid := markers_xz / count
	var boxes: Array[CSGBox3D] = []
	for node in find_children("*", "CSGBox3D", true, false):
		var box := node as CSGBox3D
		if box.use_collision and box.is_visible_in_tree():
			boxes.append(box)
	var to := Vector3(mid.x + (spot.x - mid.x) * SECRET_ROCK_SPREAD, spot.y, mid.y + (spot.z - mid.y) * SECRET_ROCK_SPREAD)
	# Stop short of the first wall in the way, then step off any wall face it's near.
	var at := spot
	var samples := maxi(1, ceili(spot.distance_to(to) / 0.25))
	for s in range(1, samples + 1):
		var next := spot.lerp(to, float(s) / samples)
		if _rock_clearance_push(next, boxes, 0.0) != Vector3.ZERO:
			break
		at = next
	for i in 4:
		var push := _rock_clearance_push(at, boxes, SECRET_ROCK_CLEARANCE)
		if push == Vector3.ZERO:
			break
		at += push
	return at

# Horizontal push that moves `at` `clearance` off the nearest face of the first
# box it's within `clearance` of (ZERO when clear). Floors and ceilings only
# count if the 0.7-tall rock would touch them, and never push.
func _rock_clearance_push(at: Vector3, boxes: Array[CSGBox3D], clearance: float) -> Vector3:
	for box in boxes:
		var xf := box.global_transform
		var local := xf.affine_inverse() * at
		var half := box.size * 0.5
		var gap := local.abs() - half
		if gap.y >= 0.35 or gap.x >= clearance or gap.z >= clearance:
			continue
		# Out through the local X or Z face, whichever is closer.
		var target := local
		if gap.x > gap.z:
			target.x = signf(local.x if local.x != 0.0 else 1.0) * (half.x + clearance)
		else:
			target.z = signf(local.z if local.z != 0.0 else 1.0) * (half.z + clearance)
		var push := xf * target - at
		push.y = 0.0
		return push if push.length() > 0.001 else Vector3(0.001, 0, 0)
	return Vector3.ZERO

# A broken rock springs an ambush or leaves an ItemOrb.
func _on_secret_rock_broken(reward: String, spot: Vector3) -> void:
	_note_broken_rock(spot)
	if reward == "ambush":
		_begin_ambush_reveal()
		return
	_spawn_secret_reward_orb(reward, spot)

func _spawn_secret_reward_orb(reward: String, spot: Vector3, golden := true, grappleable := true, grapple_only := true) -> ItemOrb:
	var orb := ItemOrb.new()
	orb.item_id = reward
	orb.golden = golden
	orb.grappleable = grappleable
	orb.grapple_only = grapple_only
	orb.position = spot
	orb.collected.connect(_on_secret_orb_collected)
	orb.needs_ability.connect(func(_d: Diver) -> void:
		_announce("This item seems to require a special ability to pick it up."))
	add_child(orb)
	if Items.is_key_item(reward):
		key_pickups.append(orb)
	return orb

# Into the inventory (key items to key_items).
func _on_secret_orb_collected(item_id: String, _d: Diver, announce := true) -> void:
	var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
	if Items.is_key_item(item_id):
		_gain_key(item_id)
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	if announce:
		_announce("Picked up a %s." % display)

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

# --- The vortex chest ---
# In the eye of the sphere vortex; E opens it and the Vortex Key rises into the party's keys.
const CHEST_REACH := 2.4
var _vortex_chest: Node3D
var _vortex_chest_lid: Node3D
var _vortex_chest_open := false
var _chest_reward_pending := false
var _chest_tween: Tween

func _begin_chest_cutscene() -> Tween:
	_cancel_aim()
	_chest_reward_pending = true
	if target_selector != null and target_selector.selecting:
		target_selector.cancel_selection()
	for diver in divers:
		diver.velocity = Vector3.ZERO
	_chest_tween = create_tween()
	return _chest_tween

func _update_chest_pause() -> void:
	# Pause the reward animation too while Inventory pauses exploration.
	if not _chest_reward_pending or _chest_tween == null or not _chest_tween.is_valid():
		return
	if inventory_menu != null and inventory_menu.visible:
		_chest_tween.pause()
	elif not _chest_tween.is_running():
		_chest_tween.play()

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
	_add_chest_collision(_vortex_chest, size + Vector3(0.04, 0.3, 0.04))
	for band_x in [-0.5, 0.5]:
		_vortex_chest.add_child(_chest_box(Vector3(0.1, size.y + 0.02, size.z + 0.04), Vector3(band_x, size.y * 0.5, 0), gold))
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

func _add_chest_collision(chest: Node3D, size: Vector3) -> void:
	# Solid, so divers can't hide inside.
	var body := StaticBody3D.new()
	body.name = "ChestBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	chest.add_child(body)

# The Control Room chest grants the map item; owning it restores the open lid.
const MAP_ITEM := "maze_nav_map"
var _map_chest: Node3D
var _map_chest_lid: Node3D
var _map_chest_open := false

func _build_map_chest() -> void:
	if _dome_site == Vector3.ZERO:
		return
	var wood := _stone(Color(0.42, 0.24, 0.12))
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.25)
	gold.metallic = 0.8
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.6
	_map_chest = Node3D.new()
	_map_chest.name = "MapChest"
	add_child(_map_chest)
	_map_chest.global_position = Vector3(_dome_site.x, PLINTH_TOP_Y, _dome_site.z - 3.0)
	var size := Vector3(1.4, 0.8, 0.9)
	_map_chest.add_child(_chest_box(size, Vector3(0, size.y * 0.5, 0), wood))
	_add_chest_collision(_map_chest, size + Vector3(0.04, 0.3, 0.04))
	for band_x in [-0.5, 0.5]:
		_map_chest.add_child(_chest_box(Vector3(0.1, size.y + 0.02, size.z + 0.04), Vector3(band_x, size.y * 0.5, 0), gold))
	_map_chest_lid = Node3D.new()
	_map_chest_lid.position = Vector3(0, size.y, -size.z * 0.5)
	_map_chest.add_child(_map_chest_lid)
	_map_chest_lid.add_child(_chest_box(Vector3(size.x + 0.04, 0.28, size.z + 0.04), Vector3(0, 0.14, size.z * 0.5), wood))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.4)
	glow.light_energy = 1.2
	glow.omni_range = 3.5
	glow.position = Vector3(0, 1.6, 0)
	_map_chest.add_child(glow)
	var room_label := Label3D.new()
	room_label.name = "ControlRoomLabel"
	room_label.text = "Control Room"
	room_label.font_size = 38
	room_label.pixel_size = 0.012
	room_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	room_label.position = Vector3(0, 3.4, DOME_RADIUS + 3.3)
	add_child(room_label)
	room_label.global_position = _dome_site + room_label.position
	_restore_map_chest_ownership()

func _restore_map_chest_ownership() -> void:
	_map_chest_open = key_items.has(MAP_ITEM)
	if _map_chest_lid != null:
		_map_chest_lid.rotation.x = -deg_to_rad(110.0) if _map_chest_open else 0.0

func _map_chest_in_reach() -> bool:
	if _map_chest == null or _map_chest_open or _diver == null:
		return false
	# Can't open it from under the plinth.
	return _diver.global_position.distance_to(_map_chest.global_position + Vector3(0, 0.6, 0)) <= CHEST_REACH

func _open_map_chest() -> void:
	_map_chest_open = true
	var tw := _begin_chest_cutscene()
	tw.tween_property(_map_chest_lid, "rotation:x", -deg_to_rad(110.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var scroll := MeshInstance3D.new()
	var roll := CylinderMesh.new()
	roll.top_radius = 0.12
	roll.bottom_radius = 0.12
	roll.height = 0.9
	scroll.mesh = roll
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.93, 0.87, 0.7)
	paper.emission_enabled = true
	paper.emission = Color(1.0, 0.9, 0.6)
	paper.emission_energy_multiplier = 0.6
	scroll.material_override = paper
	scroll.rotation.z = PI * 0.5
	_map_chest.add_child(scroll)
	scroll.position = Vector3(0, 0.6, 0)
	tw.tween_property(scroll, "position:y", 2.2, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(scroll, "rotation:y", TAU, 0.9)
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		scroll.queue_free()
		if not key_items.has(MAP_ITEM):
			key_items.append(MAP_ITEM)
		_chest_reward_pending = false
		$HUD/Controls.text = "Hallway: OPEN" if _hallway_1_2_swung else "Hallway: CLOSED. Open the map (L), pick the hallway walls and press E."
		var popup := get_node_or_null("/root/CharacterAbilityPopup")
		if popup != null:
			var pages: Array[Dictionary] = [{"title": "Key Item Acquired", "body":
				"While you're within the maze, press %s to open the Maze Navigation Map as any diver. On it you can control the geometry of the nearby maze." % Slot._badge("L"),
				"slot": null}]
			popup.call("open", pages, self)
		else:
			_announce("Maze Navigation Map acquired. Press L within the maze.", 6.0))

func nav_map_area() -> Rect2:
	var b32 := get_node_or_null("CSGBox3D32") as CSGBox3D
	var back := get_node_or_null("Room16Back") as CSGBox3D
	if _dome_site == Vector3.ZERO or b32 == null or back == null:
		return Rect2()
	var x0 := _dome_site.x - PLINTH_RADIUS - 1.0
	var x1 := back.global_position.x + back.size.z * 0.5 + 1.0
	var z0 := _dome_site.z - PLINTH_RADIUS - 1.0
	var z1 := b32.global_position.z + b32.size.z * 0.5
	return Rect2(x0, z0, x1 - x0, z1 - z0)

func can_open_nav_map() -> bool:
	return key_items.has(MAP_ITEM) and _diver != null \
		and nav_map_area().has_point(Vector2(_diver.global_position.x, _diver.global_position.z))

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
	var tw := _begin_chest_cutscene()
	tw.tween_property(_vortex_chest_lid, "rotation:x", -deg_to_rad(110.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var key := _make_key_mesh()
	_vortex_chest.add_child(key)
	key.position = Vector3(0, 0.6, 0)
	tw.tween_property(key, "position:y", 2.2, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(key, "rotation:y", TAU, 0.9)
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		key.queue_free()
		_gain_key("vortex_key")
		_chest_reward_pending = false)

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

# Dev start: facing the sphere room's door in wall 16.
func _dev_spawn_at_sphere_room() -> void:
	var door := get_node_or_null("MazeDoor16") as KeyDoor
	if door == null:
		return
	var approach := door.global_basis.z   # wheel side faces the passage
	approach.y = 0.0
	approach = approach.normalized()
	var spot := door.global_position + approach * 3.5
	spot.y = ($DiverEntry as Node3D).global_position.y
	var along := Vector3.UP.cross(approach).normalized()
	var offsets := [0.0, -2.5, 2.5]
	for i in range(divers.size()):
		var slot: int = (i - active + divers.size()) % divers.size()
		divers[i].global_position = spot + along * float(offsets[slot])
	_yaw = atan2(-approach.x, -approach.z)

# Dev start: facing the secret boss room's door.
func _dev_spawn_at_boss_rooms() -> void:
	if _door30_center == Vector3.ZERO:
		return
	var spot := _door30_center + Vector3(3.5, 0, 0)
	spot.y = ($DiverEntry as Node3D).global_position.y
	var offsets := [0.0, -2.5, 2.5]
	for i in range(divers.size()):
		var slot: int = (i - active + divers.size()) % divers.size()
		divers[i].global_position = spot + Vector3(0, 0, float(offsets[slot]))
	_yaw = atan2(-1.0, 0.0)   # facing -X

# Sonar Vision pickup in the hall between the boss doors; required for the 3D reveal.
var _sonar_vision_pickup: Area3D

func _build_sonar_vision_pickup() -> void:
	if _door30_center == Vector3.ZERO:
		return
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
	# Bind the spin to the pickup so it ends when the pickup is freed.
	var spin := pickup.create_tween().set_loops()
	spin.tween_property(lens, "rotation:y", TAU, 2.0).from(0.0)
	pickup.body_entered.connect(_on_sonar_vision_pickup)
	_sonar_vision_pickup = pickup

func _on_sonar_vision_pickup(body: Node3D) -> void:
	if not body is Diver or inventory.has("sonar_vision"):
		return
	inventory["sonar_vision"] = 1
	_announce("You gained the item: Sonar Vision.")
	_announce("Sonar Vision can be used with Sonar to show hidden items around you.", 6.0)
	if is_instance_valid(_sonar_vision_pickup):
		_sonar_vision_pickup.queue_free()
	_sonar_vision_pickup = null

func _update_sonar_vision() -> void:
	# Already owned (e.g. after a Load).
	if is_instance_valid(_sonar_vision_pickup) and inventory.has("sonar_vision"):
		_sonar_vision_pickup.queue_free()
		_sonar_vision_pickup = null
	if _swirl_room == null or _diver == null:
		return
	_swirl_room.set_revealed(sonar_vision_active() and _swirl_room.contains(_diver.global_position))

# Maxilani's sonar is on (Q); drives the minimap's red markers.
func sonar_on_in_maze() -> bool:
	return maze_active and _diver != null and _diver.passive_id == "sonar" and _diver.sonar_active

# Seeing spheres in 3D also needs the Sonar Vision item.
func sonar_vision_active() -> bool:
	return sonar_on_in_maze() and inventory.has("sonar_vision")

# Unbroken secret rocks within this radius show on the maps while sonar is on.
const SONAR_ROCK_RADIUS := 30.0
var _secret_room_rocks: Array[Node3D] = []

func sonar_rock_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	if not sonar_on_in_maze():
		return out
	for rock in _secret_room_rocks:
		# Ambush rocks get no red circle.
		if is_instance_valid(rock) and String(rock.get_meta("reward", "")) == "ambush":
			continue
		if is_instance_valid(rock) and not rock.is_queued_for_deletion() and rock.global_position.distance_to(_diver.global_position) <= SONAR_ROCK_RADIUS 				and MiniMap.within_marker_height(_diver.global_position.y, rock.global_position.y):
			out.append(rock.global_position)
	return out

# Only while the active diver has sonar on.
func hidden_marker_positions() -> PackedVector3Array:
	if _swirl_room == null or not sonar_on_in_maze():
		return PackedVector3Array()
	var out := PackedVector3Array()
	for p in _swirl_room.positions():
		if MiniMap.within_marker_height(_diver.global_position.y, p.y):
			out.append(p)
	return out

# --- Swap target selection ---
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

# Called by TargetSelector: look at the candidate, then back.
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

# Box28 keeps its authored rotation; snap it flush to Box14's +X end. Run after the perimeter pass.
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

# Wrapper with clearer names: _position_beyond_wall_end() calls the anchor "moving_wall".
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

# Line up wall bottoms (ends sit at the reference's centre height, which sinks taller walls).
func _match_wall_bottom(wall_to_place: CSGBox3D, reference_wall: CSGBox3D) -> void:
	var reference_bottom := reference_wall.global_position.y - reference_wall.size.y * 0.5
	wall_to_place.global_position.y = reference_bottom + wall_to_place.size.y * 0.5

# Places wall_to_place straight off reference_wall's nearer end. Assumes opposite rotation.
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


	# Push out by half its length so the ends meet instead of overlapping.
	wall_to_place.global_position = reference_outer_end
	if _diver != null and world == null:
		_diver.global_position = reference_outer_end + Vector3(10,10,10)

	var wall_27 := $CSGBox3D27 as CSGBox3D
	var wall_17 := $CSGBox3D17 as CSGBox3D
	var outer_axis: Vector3 = wall_27.global_transform.basis.x.normalized()

	wall_17.rotation.y = wall_17.rotation.y + PI
	var placed_axis: Vector3 = wall_17.global_transform.basis.x.normalized()
	var center_sign := 1.0 if placed_axis.dot(Vector3.LEFT) > 0.0 else -1.0
	# Along Box27's outward axis; Box17's basis.x points back into Box27 after the flip.
	wall_17.global_position = reference_outer_end + reference_outward_axis * wall_17.size.x * 0.5
	const WIDTH := 2.3
	wall_17.global_position += reference_outward_axis * WIDTH




# --- Lever dome ---
# Dome on a raised plinth with north and east doorways; holds Lever1 (walls) and Lever2 (currents).
# E grabs a free lever and the diver stays holding it. With both held, the wall/current map is up
# for either holder; the third diver can open it with [L]. E/Esc releases.
const DOME_RADIUS := 10.0
const DOME_HEIGHT := 6.0
const DOME_THICKNESS := 0.4
const PLINTH_RADIUS := 11.0
const PLINTH_TOP_Y := 1.0         # above swim height (divers at y 0)
const DOOR_SIZE := Vector2(3.0, 3.0)
const DOOR_DIRECTIONS := [Vector3(0, 0, 1), Vector3(1, 0, 0)]   # north, east
const STEP_COUNT := 5
const STEP_DEPTH := 1.0
const STEP_WIDTH := 4.2
const LEVER_REACH := 1.8
const LEVER_HINTS := ["This lever seems to control walls nearby", "This lever seems to control water currents nearby"]
var _dome_site := Vector3.ZERO    # plinth centre on the floor plan
var _dome_levers: Array[Lever] = []
var _lever_lights: Array[MeshInstance3D] = []
var _lever_glows: Array[OmniLight3D] = []
var _lever_holders: Dictionary = {}   # Lever -> Diver
var _lever_panel: LeverHoldPanel
var _release_levers_label: Label
var _lever_map_open := false
var _free_map_open := false        # the free diver opened the lever map
var _map_hint: Label               # flashing [L]
var _lever_map_controls: Label     # controls beside the map

# Removes the CSGBox3D34/35/36 walls (before wall_boxes is collected) and notes the dome site.
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

# Centres the dome on the Box8/Box9 passage, aligned with the Box12 draft waterway.
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

	# Outer shell: a sphere squashed to DOME_HEIGHT.
	var outer := CSGSphere3D.new()
	outer.radius = DOME_RADIUS
	outer.radial_segments = 48
	outer.rings = 24
	outer.scale = Vector3(1, DOME_HEIGHT / DOME_RADIUS, 1)
	outer.material = dome_mat
	dome.add_child(outer)
	var porch_len := 3.6
	for dir in DOOR_DIRECTIONS:
		var d := dir as Vector3
		var porch := CSGBox3D.new()
		porch.size = Vector3(DOOR_SIZE.x + 1.2, DOOR_SIZE.y + 0.5, porch_len)
		porch.rotation.y = atan2(d.x, d.z)
		porch.position = d * (DOME_RADIUS + 1.0 - porch_len * 0.5) + Vector3(0, porch.size.y * 0.5, 0)
		porch.material = dome_mat
		dome.add_child(porch)
	var inner_r := DOME_RADIUS - DOME_THICKNESS
	var inner := CSGSphere3D.new()
	inner.operation = CSGShape3D.OPERATION_SUBTRACTION
	inner.radius = inner_r
	inner.radial_segments = 48
	inner.rings = 24
	inner.scale = Vector3(1, (DOME_HEIGHT - DOME_THICKNESS) / inner_r, 1)
	dome.add_child(inner)
	for dir in DOOR_DIRECTIONS:
		var d := dir as Vector3
		var door := CSGBox3D.new()
		door.operation = CSGShape3D.OPERATION_SUBTRACTION
		door.size = Vector3(DOOR_SIZE.x, DOOR_SIZE.y, 8.0)
		door.rotation.y = atan2(d.x, d.z)
		door.position = d * (DOME_RADIUS - 1.0) + Vector3(0, DOOR_SIZE.y * 0.5, 0)
		dome.add_child(door)
	# Plinth last so it also fills the hollow's lower half as the floor.
	var plinth := CSGCylinder3D.new()
	plinth.radius = PLINTH_RADIUS
	plinth.height = plinth_height
	plinth.sides = 48
	plinth.position = Vector3(0, -plinth_height * 0.5, 0)
	plinth.material = base_mat
	dome.add_child(plinth)
	var rise := plinth_height / STEP_COUNT
	for dir in DOOR_DIRECTIONS:
		var d := dir as Vector3
		for i in STEP_COUNT:
			var step := CSGBox3D.new()
			var top := _floor_top_y + rise * (i + 1)
			var depth := STEP_DEPTH + (0.5 if i == STEP_COUNT - 1 else 0.0)   # top step tucks under the plinth
			step.size = Vector3(STEP_WIDTH, top - _floor_top_y, depth)
			var near_edge := PLINTH_RADIUS - 0.5 + (STEP_COUNT - 1 - i) * STEP_DEPTH + (0.0 if i == STEP_COUNT - 1 else 0.5)
			step.rotation.y = atan2(d.x, d.z)
			step.position = d * (near_edge + depth * 0.5) + Vector3(0, (top + _floor_top_y) * 0.5 - PLINTH_TOP_Y, 0)
			step.material = base_mat
			dome.add_child(step)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.75, 0.9, 1.0)
	lamp.light_energy = 1.4
	lamp.omni_range = DOME_RADIUS + 1.0
	lamp.position = Vector3(0, DOME_HEIGHT - 1.5, 0)
	dome.add_child(lamp)

	# Levers removed: navigation comes from the map chest instead.

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

# A free lever the active diver is beside on the dome floor, or null.
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

# E for the levers; true if handled.
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

# Keys while both levers are held; true if consumed.
# Holder: E/Esc release both. Third diver: L opens the map; while open only Esc/L and map keys work.
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
	return not keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_LEFT, KEY_RIGHT, KEY_E, KEY_R]

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

# Flash "TAB switch diver" while a lever is held (not while the third diver has the map open).
func _tab_should_flash() -> bool:
	if _lever_holders.size() == 1:
		return true
	return levers_map_mode() and not _free_map_open

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
		var close_line := "[Esc]  close the map\n          (also releases the levers)" if on_lever else "[Esc] or [L]  close the map"
		_lever_map_controls.text = "WALLS\n  [Left] / [Right]  select\n  [Enter]  rotate\nCURRENTS\n  [Ctrl] + [Left] / [Right]  select\n  [Ctrl] + [E]  rotate\n" + close_line
		_lever_map_controls.size = Vector2.ZERO   # shrink to the text
		# Left of the top-right map.
		var nav := $HUD.get_node_or_null("MazeMiniMap") as MazeMiniMap
		var map_left := nav.main_map.position.x if nav != null else get_viewport().get_visible_rect().size.x
		_lever_map_controls.position = Vector2(map_left - _lever_map_controls.get_combined_minimum_size().x - 12.0, 76)
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

# --- Top-left controls ---
# Active diver's name, then its controls; "TAB switch diver" is separate so it can flash.
const WORLD_CONTROLS_BEFORE_TAB := "WASD swim · SPACE up · SHIFT down · mouse or arrows look · "
const WORLD_CONTROLS_TAB := "TAB switch diver"
var _world_hud_name: Label
var _world_hud_tab: Label
var _world_hud_after: Label
var _world_hud_map: Label
var _map_flash: Tween
var _tab_flash: Tween

func _build_world_hud() -> void:
	var status := $HUD/Controls as Label
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_left = 16.0
	status.offset_right = -16.0
	status.offset_top = -158.0
	status.offset_bottom = -106.0
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var column := VBoxContainer.new()
	column.name = "MazeExplorationControls"
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	column.offset_left = 16.0
	column.offset_top = 10.0
	column.offset_right = -180.0 # leave room for the minimap
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	$HUD.add_child(column)
	_world_hud_name = Label.new()
	# Wrap so long aim/swap text can't force the column past a narrow viewport.
	_world_hud_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_world_hud_name)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 0)
	column.add_child(row)
	for text in ["WASD swim", "SPACE/SHIFT depth", "mouse/arrows look"]:
		var hint := Label.new()
		hint.text = text
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hint)
	_world_hud_tab = Label.new()
	_world_hud_tab.text = WORLD_CONTROLS_TAB
	row.add_child(_world_hud_tab)
	_world_hud_after = Label.new()
	_world_hud_after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_world_hud_after)
	_world_hud_map = Label.new()
	_world_hud_map.name = "MazeMapAvailability"
	_world_hud_map.text = "L: Map"
	column.add_child(_world_hud_map)
	_world_hud_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in [_world_hud_name, _world_hud_tab, _world_hud_after]:
		(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE

# Keeps "Q: Sonar (On/Off)" current when sonar turns itself off.
func _on_sonar_changed() -> void:
	if maze_active and is_inside_tree():
		_update_world_hud()

func _update_world_hud() -> void:
	if _world_hud_name == null or _diver == null:
		return
	_world_hud_name.text = Cast.display_name(_diver.model_name)
	_refresh_announcement_visibility()
	(_world_hud_tab.get_parent() as Control).visible = not aiming
	if target_selector != null and target_selector.selecting:
		var t := target_selector.current_target() as Diver
		_world_hud_name.text = "Swap with %s?   Left/Right: cycle  ·  Enter: confirm  ·  Esc: cancel" % (Cast.display_name(t.model_name) if t != null else "...")
	elif aiming:
		_world_hud_name.text = "Grapple aim"
	var after := ""
	if aiming:
		after = "Left click: fire\nRight click / Esc: cancel\nWASD swim  ·  Space/Shift depth  ·  Mouse aim"
	elif _diver.ability_id != "":
		after += "  ·  F: %s" % String(_diver.ability_id).capitalize()
	if _diver.passive_id == "sonar":
		after += "  ·  Q: Sonar (%s)" % ("On" if _diver.sonar_active else "Off")
	if not aiming:
		after += "  ·  R: Random Encounters (%s)" % ("On" if random_encounters_enabled else "Off")
	_world_hud_after.text = after
	var map_ok := can_open_nav_map()
	_world_hud_map.visible = map_ok and not aiming
	# No objective text in the maze: the bottom-left goal line stays empty.
	var goal := get_node_or_null("HUD/GoalLabel") as Label
	if goal != null:
		goal.text = ""
	if map_ok and _map_flash == null:
		_map_flash = create_tween().set_loops()
		_map_flash.tween_property(_world_hud_map, "modulate:a", 0.25, 0.45)
		_map_flash.tween_property(_world_hud_map, "modulate:a", 1.0, 0.45)
	elif not map_ok and _map_flash != null:
		_map_flash.kill()
		_map_flash = null
		_world_hud_map.modulate.a = 1.0
	var flash := _tab_should_flash()
	if flash and _tab_flash == null:
		_tab_flash = create_tween().set_loops()
		_tab_flash.tween_property(_world_hud_tab, "modulate:a", 0.15, 0.4)
		_tab_flash.tween_property(_world_hud_tab, "modulate:a", 1.0, 0.4)
	elif not flash and _tab_flash != null:
		_tab_flash.kill()
		_tab_flash = null
		_world_hud_tab.modulate.a = 1.0

func _layout_destination_label(goal: Label) -> void:
	# Reserve World's HP/O2 band so the goal text doesn't overlap it.
	var host := get_parent() as World
	var viewport_size := get_viewport().get_visible_rect().size
	var bottom := -16.0
	if host != null:
		for bar in [host.hp_bar, host.oxygen_bar]:
			if bar != null and bar.is_visible_in_tree():
				bottom = minf(bottom, (bar.get_parent() as Control).get_global_rect().position.y - viewport_size.y - 12.0)
	goal.offset_left = 16.0
	goal.offset_right = -16.0
	goal.offset_bottom = bottom
	goal.offset_top = bottom - 92.0
	# On short landscape screens, use the column beside the party rows if wide enough.
	if host != null and host._party_bars_box != null and host._party_bars_box.is_visible_in_tree():
		# Reserve only the painted rows, not the hidden member's slot.
		var party_bounds := Rect2()
		for row in host._party_bars_box.get_children():
			if row is Control and row.is_visible_in_tree():
				party_bounds = row.get_global_rect() if party_bounds.size == Vector2.ZERO else party_bounds.merge(row.get_global_rect())
		var bounds := Rect2(16.0, viewport_size.y + goal.offset_top, viewport_size.x - 32.0, 92.0)
		var left := party_bounds.end.x + 12.0
		if bounds.intersects(party_bounds) and viewport_size.x - left - 16.0 >= 300.0:
			goal.offset_left = left
	# Size from the label's wrapped minimum rather than a fixed block.
	goal.offset_top = bottom - maxf(24.0, goal.get_minimum_size().y)

# Legacy save flag; no longer used.
var _path_opened := false
var _control_route_homes: Dictionary = {}

# Fences Box8's line to the Control Room rim.
func _build_box_8_dome_barrier() -> void:
	for wall in [$CSGBox3D12, $CSGBox3D13]:
		_control_route_homes[String(wall.name)] = {"position": wall.position, "rotation": wall.rotation, "size": wall.size}
	var box := $CSGBox3D8 as CSGBox3D
	var ends := _wall_geometry(box)
	var west := minf(ends.negative_end.x, ends.positive_end.x)
	var z := box.global_position.z
	var dz := z - _dome_site.z
	var rim := _dome_site.x + sqrt(maxf(PLINTH_RADIUS * PLINTH_RADIUS - dz * dz, 0.0)) - 0.4
	if west - rim > 0.5:
		_spawn_barrier("Box8DomeBarrier", Vector3((west + rim) * 0.5, 0, z), Vector3(west - rim, 0, box.size.z))

# --- Walls 17/27 ---
# Box27 is stretched to Box17's far end and Box17 removed: one solid wall.
const DOOR_GAP_WIDTH := 2.3   # wall 16's door gap

func _rebuild_wall_17_27() -> void:
	var w17 := $CSGBox3D17 as CSGBox3D
	var w27 := $CSGBox3D27 as CSGBox3D
	var g17: Dictionary = _wall_geometry(w17)
	var g27: Dictionary = _wall_geometry(w27)
	var z17 := [(g17["negative_end"] as Vector3).z, (g17["positive_end"] as Vector3).z]
	var z27 := [(g27["negative_end"] as Vector3).z, (g27["positive_end"] as Vector3).z]
	# Far end = the one away from the other wall.
	var far17: float = z17[0] if absf(z17[0] - w27.global_position.z) > absf(z17[1] - w27.global_position.z) else z17[1]
	var far27: float = z27[0] if absf(z27[0] - w17.global_position.z) > absf(z27[1] - w17.global_position.z) else z27[1]
	_set_wall_span_z(w27, w27.global_position.x, far27, far17)
	wall_boxes.erase(w17)
	remove_child(w17)
	w17.queue_free()

# Room behind a north-south wall at x = line_x around door_z; side -1 west, +1 east. Matches `like`.
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

# CSGBox3D16 split around a central door gap (north half = CSGBox3D16North), room to the east.
const ROOM_16_DEPTH := 26.0   # the sphere room
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

func _set_wall_span_z(wall: CSGBox3D, line_x: float, z0: float, z1: float) -> void:
	wall.size.x = absf(z1 - z0)
	wall.global_position = Vector3(line_x, wall.global_position.y, (z0 + z1) * 0.5)

# Top-right minimap, as in World.
func _build_minimap() -> void:
	var minimap := MazeMiniMap.new()
	# verify/maze_minimap.gd looks it up at HUD/MazeMiniMap.
	minimap.name = "MazeMiniMap"
	minimap.maze_level = self
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -166.0
	minimap.offset_top = 10.0
	minimap.offset_right = -10.0
	minimap.offset_bottom = 166.0
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(minimap)
	# L's first-open lesson pauses the tree, so captions must be released synchronously.
	minimap.main_map.visibility_changed.connect(_refresh_announcement_visibility)

# Persistent rotate hint, separate from $HUD/Controls (which whirlpool messages overwrite).
func _build_rotate_prompt() -> void:
	var label := Label.new()
	label.name = "GoalLabel"
	label.text = "E: interact  ·  F: ability."
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 16.0
	label.offset_top = -100.0
	label.offset_right = -16.0
	label.offset_bottom = -16.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	$HUD.add_child(label)

# Wall geometry in world space; keeps basis.x handling out of callers.
func _wall_geometry(wall: CSGBox3D) -> Dictionary:
	return _wall_geometry_at(wall.global_position, wall.rotation.y, wall.size)

# For a wall's future transform, without moving the node.
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

# The two valid end-to-end continuations of `target`.
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

# Picks the continuation needing the least movement.
func _nearest_wall_continuation(moving_wall: CSGBox3D, target_wall: CSGBox3D) -> Dictionary:
	var candidates := _wall_continuation_candidates(moving_wall, target_wall)
	var selected: Dictionary = candidates[0]
	for candidate in candidates:
		var candidate_position := candidate["position"] as Vector3
		var selected_position := selected["position"] as Vector3
		# Ties go to the positive continuation.
		if moving_wall.global_position.distance_squared_to(candidate_position) <= moving_wall.global_position.distance_squared_to(selected_position):
			selected = candidate
	var destination := selected["position"] as Vector3
	destination.y = target_wall.global_position.y
	return {
		"position": destination,
		"yaw": moving_wall.rotation.y + PI * 0.5,
		"target_end": selected["target_end"],
	}

# Rotates a wall 90 degrees CCW and moves it to continue `target` end-to-end (nearest valid end).
func _rotate_wall_flush(wall: CSGBox3D, target: CSGBox3D, duration := 1.2) -> Tween:
	var t: Dictionary = _nearest_wall_continuation(wall, target)
	return _tween_wall_to_transform_about_hinge(wall, t.position as Vector3, float(t.yaw), duration)

# The unique yaw hinge taking start to target (target = pivot + R(start - pivot)),
# so a swinging wall doesn't cut diagonally through the next hallway.
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
	_wall_motion_targets[wall] = wall.get_parent().global_transform.affine_inverse() * Transform3D(Basis(Vector3.UP, target_yaw), target_position)
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

# Straight-line fallback for zero-turn moves.
func _tween_wall_to(wall: CSGBox3D, position: Vector3, yaw: float, duration := 1.2) -> Tween:
	_wall_motion_targets[wall] = wall.get_parent().global_transform.affine_inverse() * Transform3D(Basis(Vector3.UP, yaw), position)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wall, "global_position", position, duration)
	tw.tween_property(wall, "rotation:y", yaw, duration)
	return tw

# H toggles the hallway: each wall swings about its own hinge to its flush target, and back.
# Currents move with it (Corridor2 -> 3, then 1 -> 2; reversed on close), tracked via _currents_by_corridor.
var _hallway_1_2_swung := false
var _hallway_1_2_home_pos_a: Vector3
var _hallway_1_2_home_yaw_a: float
var _hallway_1_2_home_pos_b: Vector3
var _hallway_1_2_home_yaw_b: float

# Wall sets the L map can select and rotate (E). Add an entry per new set.
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

# Sets mid-swing; rotate requests for them are ignored.
var _moving_wall_sets: Dictionary = {}
var _wall_motion_tweens: Dictionary = {}
var _wall_motion_targets: Dictionary = {}
var _wall_motion_collision: Dictionary = {}
var _wall_riders = preload("res://game/maze_wall_riders.gd").new(self)

func _wall_set_moving(set_name: String) -> bool:
	return _moving_wall_sets.has(set_name)

# `walls` are framed by the camera while moving; divers can't steer meanwhile.
func _track_wall_set_motion(set_name: String, tweens: Array, walls: Array = []) -> void:
	var pending := tweens.filter(func(t) -> bool: return t is Tween and (t as Tween).is_valid())
	if pending.is_empty():
		return
	if _moving_wall_sets.is_empty():
		# Stop the divers; steering is off until the walls finish.
		for d in divers:
			d.velocity = Vector3.ZERO
	_moving_wall_sets[set_name] = pending.size()
	_moving_wall_nodes[set_name] = walls
	_wall_motion_tweens[set_name] = pending.duplicate()
	for tw in pending:
		(tw as Tween).finished.connect(func() -> void:
			# A checkpoint restore may have cancelled this set.
			if not _moving_wall_sets.has(set_name):
				return
			(_wall_motion_tweens[set_name] as Array).erase(tw)
			_moving_wall_sets[set_name] = int(_moving_wall_sets[set_name]) - 1
			if int(_moving_wall_sets[set_name]) <= 0:
				_finish_wall_motion(set_name))

func _finish_wall_motion(set_name: String, interrupted := false) -> void:
	if interrupted:
		for tw in _wall_motion_tweens.get(set_name, []):
			if tw is Tween and (tw as Tween).is_valid():
				(tw as Tween).kill()
	for wall in _moving_wall_nodes.get(set_name, []):
		if not is_instance_valid(wall):
			continue
		# On interruption, settle at the destination rather than mid-rotation.
		if interrupted and _wall_motion_targets.has(wall):
			(wall as CSGBox3D).transform = _wall_motion_targets[wall]
		_wall_riders.finish(wall)
		_restore_motion_collision(wall)
		_wall_motion_targets.erase(wall)
		_wall_last_xf.erase(wall)
	_moving_wall_sets.erase(set_name)
	_moving_wall_nodes.erase(set_name)
	_wall_motion_tweens.erase(set_name)

func _cancel_wall_motion(preserve_rider_positions := false) -> void:
	# Before removing target transforms used for clearance queries.
	_wall_riders.cancel(preserve_rider_positions)
	for set_name in _moving_wall_sets.keys():
		_finish_wall_motion(String(set_name), true)
	for wall in _wall_motion_collision.keys():
		_restore_motion_collision(wall)
	_wall_motion_targets.clear()
	_wall_last_xf.clear()

func _suspend_motion_collision(wall: CSGBox3D) -> void:
	if _wall_motion_collision.has(wall):
		return
	var saved := {"wall": wall.collision_layer, "bodies": {}}
	# Child colliders (e.g. the split rock on wall10) are suspended too.
	for child in wall.find_children("*", "CollisionObject3D", true, false):
		var body := child as CollisionObject3D
		saved.bodies[body] = body.collision_layer
		body.collision_layer = 0
	_wall_motion_collision[wall] = saved
	wall.collision_layer = 0

func _restore_motion_collision(wall: Variant) -> void:
	if not _wall_motion_collision.has(wall):
		return
	var saved: Dictionary = _wall_motion_collision[wall]
	if is_instance_valid(wall):
		wall.collision_layer = int(saved.wall)
	for body in saved.bodies:
		if is_instance_valid(body):
			(body as CollisionObject3D).collision_layer = int(saved.bodies[body])
	_wall_motion_collision.erase(wall)

var _moving_wall_nodes: Dictionary = {}   # set name -> walls

# Tweened static walls don't push divers; intercepted divers ride the moving face
# as passengers. C5 occupants are exempt from walls 10/11.
const SWEEP_MARGIN := 0.05
var _wall_last_xf: Dictionary = {}   # wall -> last physics frame transform

func _sweep_divers_with_moving_walls() -> void:
	# Tween.kill() doesn't emit finished; detect interrupted sets here.
	for set_name in _wall_motion_tweens.keys():
		if (_wall_motion_tweens[set_name] as Array).any(func(t: Tween) -> bool: return not t.is_valid()):
			_finish_wall_motion(String(set_name), true)
	_wall_riders.update()
	var still_moving: Dictionary = {}
	for set_name in _moving_wall_nodes:
		# Centre of the set's walls: a wall's inner face is the one facing it
		# (into the corridor between a hall's two walls).
		var set_center := Vector3.ZERO
		var set_count := 0
		for other in _moving_wall_nodes[set_name]:
			if is_instance_valid(other):
				set_center += (other as Node3D).global_position
				set_count += 1
		if set_count > 0:
			set_center /= float(set_count)
		for w in _moving_wall_nodes[set_name]:
			if not is_instance_valid(w):
				continue
			var wall := w as CSGBox3D
			still_moving[wall] = true
			var xf := wall.global_transform
			var last: Transform3D = _wall_last_xf.get(wall, xf)
			var half := wall.size * 0.5
			for d in divers:
				if not is_instance_valid(d):
					continue
				# C5 occupants aren't passengers on walls 10/11.
				if set_name == "CSGBox3D10/11" and _c5_zone().has_point(Vector2(d.global_position.x, d.global_position.z)):
					_wall_riders.detach_in_place(d, wall)
					continue
				if _wall_riders.owns(d):
					_wall_riders.carry(d, wall)
					continue
				var r := d.radius + SWEEP_MARGIN
				var local := xf.affine_inverse() * d.global_position
				if absf(local.x) > half.x + r or absf(local.z) > half.z + r or absf(local.y) > half.y + d.height * 0.5:
					continue
				# Which face the diver is on, and which way that face is moving.
				var motion := xf * local - last * local
				var across := xf.basis.z.normalized()
				var diver_side := signf(local.z) if local.z != 0.0 else 1.0
				var moving_side := signf(motion.dot(across))
				if absf(motion.dot(across)) >= 0.001 and moving_side != diver_side:
					continue   # the wall is moving away from this diver: leave them be
				var side := diver_side
				var pushed := Vector3(local.x, local.y, side * (half.z + r))
				var target := xf * pushed
				# Only the inner face (towards the set's centre / the corridor
				# between the walls) carries divers. On the outer face, a wall
				# moving into a diver just pushes them clear, without riding.
				var inner_local := xf.affine_inverse() * set_center
				var inner_side := signf(inner_local.z) if set_count > 1 and absf(inner_local.z) > 0.01 else 0.0
				if inner_side != 0.0 and side != inner_side:
					d.global_position = Vector3(target.x, d.global_position.y, target.z)
					continue
				if _wall_riders.capture(d, wall, pushed,
					wall.get_parent().global_transform * (_wall_motion_targets[wall] as Transform3D)):
					d.global_position = Vector3(target.x, d.global_position.y, target.z)
	_wall_last_xf.clear()
	for wall in still_moving:
		_wall_last_xf[wall] = (wall as CSGBox3D).global_transform

func _c5_zone() -> Rect2:
	var cs := _corridor_shape($WindCorridor5)
	if cs == null or not cs.shape is BoxShape3D:
		return Rect2()
	var half := (cs.shape as BoxShape3D).size * 0.5
	var west := INF
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			west = minf(west, (cs.global_transform * Vector3(half.x * sx, 0, half.z * sz)).x)
	var b8 := $CSGBox3D8 as CSGBox3D
	var b9 := $CSGBox3D9 as CSGBox3D
	var t := b9.size.z * 0.5
	var east := maxf(_wall_11_joint.x, _wall_10_joint.x) + t
	var z0 := minf(b8.global_position.z, b9.global_position.z) - t
	var z1 := maxf(b8.global_position.z, b9.global_position.z) + t
	return Rect2(west, z0, east - west, z1 - z0)

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
				$HUD/Controls.text = "Hallway: CLOSED. Open the map (L), pick the hallway walls and press E."
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

# Current toggles (independent of the walls):
#   C - Corridor1 <-> Corridor2. V - Corridor3 <-> Corridor4 (the only way past the whirlpool).
#   B - Corridor5 <-> Corridor6.
var _current_1_in_2 := false
var _current_3_in_4 := false
var _current_5_in_6 := false
# Flow in Corridor4; the whirlpool sits downstream so the current carries divers through.
const CORRIDOR_4_FLOW := WaterCurrent.Direction.NEGATIVE_Z

# Corridor1's current goes to WindCorridorBreakRock (+Z), else WindCorridor2 (+X).
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
		# Carries anyone in Corridor4 past the whirlpool.
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

# Ctrl+E on the map: moves `corridor`'s current to its pair (1<->2, 3<->4, 5<->6, 7<->8).
# Returns the new corridor, or null.
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

# Moves a WaterCurrent to another corridor, keeping _currents_by_corridor keyed by location.
func _move_current(from_area: Area3D, to_area: Area3D, dir: WaterCurrent.Direction) -> void:
	var current: WaterCurrent = _currents_by_corridor.get(from_area, null)
	if current == null:
		push_warning("_move_current: no current at %s" % from_area.name)
		return
	current.setup(to_area, WaterCurrent.direction_to_vector(dir), current.strength, false)
	_currents_by_corridor.erase(from_area)
	_currents_by_corridor[to_area] = current

# Fixed authored perpendicular joins only; use _nearest_wall_continuation() for routes.
func _attach_wall_to_perpendicular_exit(reference_wall: CSGBox3D, moving_wall: CSGBox3D, reference_exit: int, moving_anchor_end: int) -> void:
	var reference_geometry: Dictionary = _wall_geometry(reference_wall)
	moving_wall.global_position = _perpendicular_exit_position(
		reference_geometry, moving_wall.rotation.y, moving_wall.size,
		reference_exit, moving_anchor_end
	)

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

# Places target_wall beyond a known endpoint. Offsets stacked on the outer end: half
# target thickness outward, half target length along its axis, minus half moving thickness.
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


# One WaterCurrent controller per starting corridor, configured here.
func _setup_currents() -> void:
	_add_current($WindCorridor1, WaterCurrent.Direction.NEGATIVE_Z)
	_add_current($WindCorridor3, WaterCurrent.Direction.NEGATIVE_Z)
	_add_current($WindCorridor5, WaterCurrent.Direction.NEGATIVE_X)
	# Corridor7 pushes -Z; Ctrl+E moves it to Corridor8 (+Z).
	if has_node("WindCorridor7"):
		_add_current($WindCorridor7, WaterCurrent.Direction.NEGATIVE_Z)

# Slides the two-current window along the 1-2-3 chain toward lower corridors;
# vacate the destination slot first.
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

# Corridor -> its WaterCurrent.
var _currents_by_corridor: Dictionary = {}

func _add_current(target_area: Area3D, dir: WaterCurrent.Direction) -> void:
	var current := WaterCurrent.new()
	add_child(current)
	# Strength must exceed the 5.0 swim speed to block traversal.
	current.setup(target_area, WaterCurrent.direction_to_vector(dir), 7.0, false)
	_currents_by_corridor[target_area] = current

# Moves origArea's current to newArea, turning its flow 90 degrees, and re-files it under newArea.
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

# Reverse of _rotate_right().
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

# Whirlpool (whirlpool.gd): warned approach, then inescapable suction that costs HP and resets the diver.
func _setup_whirlpool() -> void:
	var whirlpool := Whirlpool.new()
	whirlpool.position = Vector3(35.99, -4.12, 71.67) + coordinate_origin
	whirlpool.reset_to = $DiverEntry.position
	whirlpool.warned.connect(_on_whirlpool_warned)
	whirlpool.diver_sucked_in.connect(_on_diver_sucked_in)
	add_child(whirlpool)
	_setup_corridor_4_whirlpool()

# Corridor -> its two walls. Corridors (with their currents and whirlpool) are kept
# centred between their pair every physics frame.
var _corridor_walls: Dictionary = {}
# Corridors also centred lengthwise; the rest keep their authored spot along the passage.
var _corridors_centred_lengthwise: Array[Area3D] = []
var _corridor_4_whirlpool: Whirlpool

func _align_corridors_to_walls() -> void:
	for corridor in _corridor_walls:
		var walls: Array = _corridor_walls[corridor]
		var shape_node := _corridor_shape(corridor as Area3D)
		if shape_node == null:
			continue
		_turn_corridor_along_walls(shape_node, walls[0])
		# Centred across the gap only.
		var centre := _midpoint_between(walls[0], walls[1])
		var side := _wall_geometry(walls[0])["side_axis"] as Vector3
		side.y = 0.0
		var target := shape_node.global_position + side * (centre - shape_node.global_position).dot(side)
		if _corridors_centred_lengthwise.has(corridor):
			# Fully centred (height kept as authored).
			target = Vector3(centre.x, shape_node.global_position.y, centre.z)
		if not shape_node.global_position.is_equal_approx(target):
			shape_node.global_position = target
	_place_corridor_4_whirlpool()

# Turns a corridor's box about Y so its long axis follows `wall`'s.
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
	# Either direction along the wall is fine; take the smaller turn.
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

# WindCorridor4 and WindCorridorBreakRock: same size, end to end on one line, meeting
# at the stub wall with opposite currents.
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
	# North: the far end of wall 12.
	var north := INF
	for w in _corridor_walls[$WindCorridor4]:
		var g: Dictionary = _wall_geometry(w)
		north = minf(north, minf((g["negative_end"] as Vector3).z, (g["positive_end"] as Vector3).z))
	var meet := stub.global_position.z
	var length := meet - north
	var basis := c4.global_basis.orthonormalized()
	var box := (c4.shape as BoxShape3D).duplicate() as BoxShape3D   # Corridor5 shares the original
	# Long side along world Z, whichever local axis that is.
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

# Whirlpool across the back of WindCorridor4, sized to the gap; the Corridor4 current carries divers through it.
func _setup_corridor_4_whirlpool() -> void:
	var corridor := $WindCorridor4 as Area3D
	var walls: Array = _corridor_walls[corridor]
	var whirlpool := Whirlpool.new()
	# Fills the gap so it can't be skimmed past.
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
	var flow := WaterCurrent.direction_to_vector(CORRIDOR_4_FLOW)
	var back: Vector3 = ends[0] if (ends[0] - ends[1]).dot(flow) > 0.0 else ends[1]
	var start: Vector3 = ends[1] if (ends[0] - ends[1]).dot(flow) > 0.0 else ends[0]
	var into := (start - back).normalized()
	var floor_y: float = ($DiverEntry as Node3D).global_position.y
	var spot := back + into * (_corridor_4_whirlpool.suction_radius + 0.5)
	_corridor_4_whirlpool.global_position = Vector3(spot.x, floor_y, spot.z)
	var reset := start - into * 1.5
	# Return point is outside the pull zone for every party capsule.
	var largest_radius := 0.0
	for actor in divers:
		largest_radius = maxf(largest_radius, actor.radius)
	var safe_distance := maxf(_corridor_4_whirlpool.suction_radius, _corridor_4_whirlpool.pull_radius) + largest_radius + 0.75
	if (reset - spot).dot(into) < safe_distance:
		reset = spot + into * safe_distance
	_corridor_4_whirlpool.reset_to = Vector3(reset.x, floor_y, reset.z)

func _on_whirlpool_warned() -> void:
	# The whirlpool shows its own warning caption.
	pass

func _on_diver_sucked_in(_d: Diver, amount: int) -> void:
	_announce("You were sucked into the whirlpool! (-%d HP)" % amount)

# Invisible floor under the walls across the whole level, so divers can't swim under them.
# The whirlpool sets position directly, so it can still pull below this.
const _FLOOR_CLEARANCE := 1.0
const _FLOOR_THICKNESS := 2.0

# Top surface Y of the floor; golden orbs stop falling here.
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
	_floor_top_y = floor_y + _FLOOR_THICKNESS * 0.5

	var floor_body := StaticBody3D.new()
	floor_body.name = "MazeFloorCollision"
	floor_body.position = Vector3(center_x, floor_y, center_z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span_x, _FLOOR_THICKNESS, span_z)
	shape.shape = box
	floor_body.add_child(shape)
	add_child(floor_body)

# Invisible perimeter around the level's computed bounds (walls, corridors, markers), tall enough not to rise over.
const _PERIMETER_MARGIN := 10.0
const _PERIMETER_WALL_HEIGHT := 80.0
const _PERIMETER_THICKNESS := 4.0

func _collect_bounds_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for child in get_children():
		if child is CSGBox3D:
			var box := child as CSGBox3D
			if String(box.name).begins_with("Floor_"):
				continue # Decorative coverage must not expand the bounds.
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
	# Include the lever dome's plinth and steps footprint.
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
	if world == null:
		_build_invisible_wall(
			Vector3(padded_min.x - _PERIMETER_THICKNESS * 0.5, wall_y, center_z),
			Vector3(_PERIMETER_THICKNESS, _PERIMETER_WALL_HEIGHT, span_z + _PERIMETER_THICKNESS * 2.0))
	else:
		var z_lo := padded_min.z - _PERIMETER_THICKNESS
		var z_hi := padded_max.z + _PERIMETER_THICKNESS
		var gap := entrance_point().z
		for span in [[z_lo, gap - EMBED_PASSAGE_HALF_WIDTH], [gap + EMBED_PASSAGE_HALF_WIDTH, z_hi]]:
			_build_invisible_wall(Vector3(padded_min.x - _PERIMETER_THICKNESS * 0.5,
				wall_y, (float(span[0]) + float(span[1])) * 0.5),
				Vector3(_PERIMETER_THICKNESS, _PERIMETER_WALL_HEIGHT, float(span[1]) - float(span[0])))
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

# Invisible ceiling just above CurrentWall1's top (not the taller walls), over the perimeter footprint.
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
	# Raised areas get holes with higher caps; slabs are built around the holes
	# (strips along x, runs along z) thick enough to reach the highest cap.
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
		# Invisible walls around the raised area up to its cap.
		var h := cap - bottom
		var y := bottom + h * 0.5
		_build_invisible_wall(Vector3(r.get_center().x, y, r.position.y), Vector3(r.size.x, h, 0.5))
		_build_invisible_wall(Vector3(r.get_center().x, y, r.end.y), Vector3(r.size.x, h, 0.5))
		_build_invisible_wall(Vector3(r.position.x, y, r.get_center().y), Vector3(0.5, h, r.size.y))
		_build_invisible_wall(Vector3(r.end.x, y, r.get_center().y), Vector3(0.5, h, r.size.y))

# Raised ceiling areas: [floor-plan Rect2 (x, z), underside height].
func _raised_ceiling_regions() -> Array:
	var out: Array = []
	if _dome_site != Vector3.ZERO:
		out.append([Rect2(_dome_site.x - PLINTH_RADIUS, _dome_site.z - PLINTH_RADIUS, PLINTH_RADIUS * 2.0, PLINTH_RADIUS * 2.0), PLINTH_TOP_Y + DOME_HEIGHT + 0.5])
	var room := _secret_boss_room_rect(false)
	if room.size != Vector2.ZERO:
		out.append([room, _maze_floor_top() + PUPPET_HOVER + PUPPET_TOP + PUPPET_HEADROOM])
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
# Divers (this scene drives its own party; World is optional)
# ============================================================

# World's CAST, same order. Tab switches `active`; `_diver` is always the active one.
const MAZE_CAST := ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]
var divers: Array[Diver] = []
var active := 0
var _diver: Diver
var _yaw := 0.0
var _pitch := -0.16
var _cam_dist := 6.5
var _mouse_look := false

# Party midway between two parallel walls, spread along the passage; height from $DiverEntry.
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

# Midway between two parallel walls, centred on their overlap. y = wall_a's centre.
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

# Ends of the centreline along the walls' overlap. y = wall_a's centre.
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

func _gap_width_between(wall_a: CSGBox3D, wall_b: CSGBox3D) -> float:
	var side := _wall_geometry(wall_a)["side_axis"] as Vector3
	var separation := absf((wall_b.global_position - wall_a.global_position).dot(side))
	return separation - (wall_a.size.z + wall_b.size.z) * 0.5

func _spawn_divers() -> void:
	if world != null:
		divers.assign(world.divers)
		inventory = world.inventory
		campaign_key_items = world.key_items
		active = world.active
		_diver = divers[active]
		for diver in divers:
			diver.encounter_triggered.connect(_on_diver_encounter.bind(diver))
			diver.sonar_changed.connect(_on_sonar_changed, CONNECT_DEFERRED)
		return
	for model in MAZE_CAST:
		var d := Diver.new()
		d.model_name = String(model)
		d.position = $DiverEntry.position
		add_child(d)
		d.encounter_triggered.connect(_on_diver_encounter.bind(d))
		d.sonar_changed.connect(_on_sonar_changed, CONNECT_DEFERRED)
		divers.append(d)
	if campaign_session != null:
		campaign_session.restore_party(divers)
	_diver = divers[active]

# Tab: control the next diver.
func _switch_diver() -> void:
	_cancel_aim()
	if target_selector != null and target_selector.selecting:
		target_selector.cancel_selection()
	active = (active + 1) % divers.size()
	_diver = divers[active]
	_announce("Now playing %s." % Cast.display_name(_diver.model_name))
	if world != null:
		world.active = active

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
	if Input.is_key_pressed(KEY_SHIFT):
		r -= 1.0
	return r

# Slow underwater sink rate (per second).
const GOLDEN_ORB_FALL_SPEED := 1.5

func _physics_process(dt: float) -> void:
	if not maze_active or Engine.get_physics_frames() == _entry_physics_frame:
		return
	# A World battle (Combat Help replay from the maze menu) owns the screen and keys.
	if world != null and world.battling:
		return
	_update_chest_pause()
	_align_corridors_to_walls()
	_update_strong_room_warning()
	_update_campaign_checkpoint()
	if _diver == null:
		return
	if aiming and _aim_blocked():
		_cancel_aim()
	for orb in goldenOrbs:
		if orb.position.y > _floor_top_y:
			orb.position.y = maxf(orb.position.y - GOLDEN_ORB_FALL_SPEED * dt, _floor_top_y)
	_sweep_divers_with_moving_walls()
	if _swirl_room != null and not _battling and not any_modal_open() and not _chest_reward_pending:
		_swirl_room.hit_divers(divers, dt)
	if not _battling and not any_modal_open() and not _chest_reward_pending:
		for d in divers:
			if world != null and not contains_point(d.global_position):
				continue
			# Inactive divers still swim() with no input so currents act on them.
			# No steering while walls are moving.
			if d == _diver and _lever_held_by(d) == null and not _free_map_open and _moving_wall_sets.is_empty() and not _wall_riders.busy() and not _gate_cutscene and not _cordys_reveal:
				d.swim(_player_dir(), _player_rise(), dt)
			else:
				d.swim(Vector3.ZERO, 0.0, dt)
	_update_caption_lift()
	_update_room_switch()
	_update_lever_ui()
	_update_world_hud()
	var nav := get_node_or_null("HUD/MazeMiniMap") as MazeMiniMap
	# Close the map when its diver leaves the map area, or when a menu (P save,
	# Esc inventory...) opens: those now reach normal play with the map up.
	if nav != null and nav.main_map.visible and (not can_open_nav_map() or _menu_over_map()):
		nav.main_map.visible = false
	_update_active_cursor()
	_update_sonar_vision()
	_update_puppet_patrol(dt)
	_update_cordys_station()
	_update_announce(dt)
	_check_split_rock()
	draft_passages.update()
	special_sites.update()
	_move_camera(dt)
	_update_aim_marker()

# Wall-rotation cutscene: camera pans overhead to frame moving walls, then eases back.
const CUTSCENE_PAN_RATE := 3.5
const CUTSCENE_RETURN_TIME := 1.0   # seconds
var _cutscene_dir := Vector3.ZERO   # fixed horizontal view direction
var _cutscene_return := 0.0
var _cam_look := Vector3.ZERO

# [centre, span] of all rotating walls, or [].
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

# Steep overhead view from the camera's current side.
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
	if draft_passages != null and draft_passages.busy:
		_cutscene_camera(cam, draft_passages.camera_frame(), dt)
		_cutscene_return = CUTSCENE_RETURN_TIME
		return
	if aiming:
		var eye := _diver.global_position + Vector3(0, _diver.height * 0.4, 0)
		cam.global_position = eye
		_cam_look = eye + _aim_dir() * 10.0
		cam.look_at(_cam_look, Vector3.UP)
		return
	if _gate_cutscene and _gate != null:
		if _cam_look == Vector3.ZERO:
			_cam_look = _diver.global_position
		var look := Vector3(_gate.global_position.x, _floor_top_y + 1.6, _gate.global_position.z)
		cam.global_position = cam.global_position.lerp(_gate_view_spot, clampf(dt * 2.5, 0.0, 1.0))
		_cam_look = _cam_look.lerp(look, clampf(dt * 3.0, 0.0, 1.0))
		cam.look_at(_cam_look, Vector3.UP)
		_cutscene_return = CUTSCENE_RETURN_TIME
		return
	if _cordys_reveal:
		if _cam_look == Vector3.ZERO:
			_cam_look = _diver.global_position
		var station := _boss_triggers.get("main_boss") as Node3D
		var look := station.global_position + Vector3(0, 2.0, 0) if is_instance_valid(station) else _cordys_view_spot
		cam.global_position = cam.global_position.lerp(_cordys_view_spot, clampf(dt * 1.6, 0.0, 1.0))
		_cam_look = _cam_look.lerp(look, clampf(dt * 2.5, 0.0, 1.0))
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
	var returning := _cutscene_return > 0.0
	_cutscene_return = maxf(_cutscene_return - dt, 0.0)
	var dir := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch))
	var subject: Diver = _diver
	if _camera_focus_target is Diver and is_instance_valid(_camera_focus_target):
		subject = _camera_focus_target as Diver
	var focus: Vector3 = subject.global_position + Vector3(0, subject.height * 0.35, 0)
	var want: Vector3 = focus - dir * _cam_dist
	want.y = maxf(want.y, 0.6)
	# Pull the camera in front of any wall between it and the diver.
	var ray := PhysicsRayQueryParameters3D.create(focus, want, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		want = focus + (hit.position - focus) * 0.85
		if not returning and cam.global_position.distance_to(focus) > want.distance_to(focus):
			cam.global_position = want
	cam.global_position = cam.global_position.lerp(want, clampf(dt * (4.0 if returning else 8.0), 0.0, 1.0))
	_cam_look = _cam_look.lerp(focus, clampf(dt * 5.0, 0.0, 1.0)) if returning else focus
	cam.look_at(_cam_look, Vector3.UP)

func _unhandled_input(e: InputEvent) -> void:
	if world != null and world.battling:
		return   # a World battle (Combat Help replay) owns input
	# Aim owns fire/cancel and look exclusively.
	if aiming:
		if _aim_blocked():
			_cancel_aim()
			return
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				_fire_aim()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_aim()
			get_viewport().set_input_as_handled()
			return
		if e is InputEventKey:
			if e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
				_cancel_aim()
			get_viewport().set_input_as_handled()
			return
		if e is InputEventMouseMotion:
			_yaw -= e.relative.x * 0.004
			_pitch = clampf(_pitch - e.relative.y * 0.003, -1.1, 0.7)
			get_viewport().set_input_as_handled()
			return
	# Only Escape passes while the chest reward is pending.
	if _chest_reward_pending and not (e is InputEventKey and e.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		return
	# R: encounter preference (never overrides the strong room).
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_R:
		if not _battling and not any_modal_open() and not (target_selector != null and target_selector.selecting):
			if is_diver_in_strong_room():
				get_viewport().set_input_as_handled()
				return
			random_encounters_enabled = not random_encounters_enabled
			if world != null:
				world.random_encounters_enabled = random_encounters_enabled
			if campaign_session != null:
				campaign_session.random_encounters_enabled = random_encounters_enabled
			_announce("Random encounters %s." % ("on" if random_encounters_enabled else "off"))
			get_viewport().set_input_as_handled()
		return
	# The open map only fills the top-right corner. MazeMiniMap consumes its own
	# keys (L, E/Enter, arrows, Ctrl+E) first; Esc closes it here, and everything
	# else (mouse look, sonar, swap, Tab, aim...) falls through to normal play.
	var map := get_node_or_null("HUD/MazeMiniMap") as MazeMiniMap
	# (Not while choosing a swap target: Esc cancels that first.)
	if map != null and map.main_map != null and map.main_map.visible \
			and not (target_selector != null and target_selector.selecting):
		if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo \
				and (e as InputEventKey).keycode == KEY_ESCAPE:
			map.main_map.visible = false
			get_viewport().set_input_as_handled()
			return
	# A swap choice is an exclusive owner too.
	if target_selector != null and target_selector.selecting and not _battling and not any_modal_open():
		if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
			match (e as InputEventKey).keycode:
				KEY_RIGHT:
					target_selector.select_next()
				KEY_LEFT:
					target_selector.select_previous()
				KEY_ENTER, KEY_KP_ENTER:
					target_selector.confirm_selection()
				KEY_ESCAPE:
					target_selector.cancel_selection()
			get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		if _save_menu != null and _save_menu.visible and (e as InputEventKey).keycode in [KEY_P, KEY_ESCAPE]:
			_save_menu.close()
			get_viewport().set_input_as_handled()
			return
		if (e as InputEventKey).keycode == KEY_P and not _battling and not any_modal_open() \
			and _contacted_campaign_checkpoint() != null:
			_save_menu.open_for(_diver)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_mouse_look = false
			get_viewport().set_input_as_handled()
			return
	# Esc toggles the inventory.
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_ESCAPE:
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
	if _battling or any_modal_open() or _chest_reward_pending:
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
		# Maxilani's sonar.
		if _diver.passive_id == "sonar":
			_announce("Sonar %s." % ("on" if _diver.toggle_sonar() else "off"))
		else:
			_announce("Only Maxilani has sonar.")
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_TAB:
		_switch_diver()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_F:
		_use_active_ability()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo and (e as InputEventKey).keycode == KEY_E:
		# E is on cooldown while the last interaction's text is up.
		if _interact_cooldown:
			return
		var notice_before := _announcement_revision
		_handle_e(e as InputEventKey)
		# Keep the cooldown for accepted interaction feedback.
		if _announcement_revision != notice_before:
			_interact_cooldown = true

# E: nearby context interactions only; never falls back to an ability.
func _handle_e(e: InputEventKey) -> void:
	if _campaign_exit_in_reach():
		_return_to_campaign_world()
	elif _lever_e_pressed():
		pass
	elif _try_open_door():
		pass
	elif _vortex_chest_in_reach():
		_open_vortex_chest()
	elif _map_chest_in_reach():
		_open_map_chest()
	elif _secret_entrance_in_reach():
		_enter_secret_wall()
	elif draft_passages != null and draft_passages.outgoing_in_reach():
		draft_passages.open_outgoing_prompt()
	elif _split_rock_in_reach():
		_announce("This rock looks broken in half. I wonder if something could split it open...", 5.0)
	elif _diver_near_switch() and (e as InputEventKey).shift_pressed:
		_toggle_room_encounters()
	elif _diver_near_switch() and not _switch_puzzle_done() and not _poster_beats_switch(_poster_in_reach()):
		_open_switch_minigame()
	elif _poster_in_reach() != null:
		_open_poster(_poster_in_reach())

# F: the active diver's ability (shockwave, grapple, or swap).
func _use_active_ability() -> void:
	match _diver.ability_id:
		"grapple":
			if _diver.can_use_ability() and not _aim_blocked():
				_start_aim()
		"swap":
			# Pick the swap target first.
			if not target_selector.selecting and _diver.can_use_ability():
				target_selector.start_selection(_diver)
		_:
			if _diver.shockwave_needs_oxygen():
				_announce("Not enough Oxygen for Shockwave (needs %d)." % int(Diver.SHOCKWAVE_OXYGEN_COST))
				return
			_diver.use_ability()

# Scene-owned aim; shared Divers outlive the embedded maze.
var aiming := false
var _aiming_diver: Diver
var _aim_model_was_visible := true
var _aim_marker: MeshInstance3D
var _aim_marker_mat: StandardMaterial3D

func _aim_dir() -> Vector3:
	return Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch))

func _aim_blocked() -> bool:
	# The open nav map doesn't block aiming: it only fills the top-right corner.
	return not maze_active or _battling or any_modal_open() or _chest_reward_pending \
		or _gate_cutscene or _cordys_reveal or not _moving_wall_sets.is_empty() or _free_map_open

func _start_aim() -> void:
	aiming = true
	_aiming_diver = _diver
	_aim_model_was_visible = _diver.model.visible
	_diver.set_model_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_look = true
	_move_camera(0.0)
	_update_world_hud()

func _fire_aim() -> void:
	if not is_instance_valid(_aiming_diver):
		_cancel_aim()
		return
	var shooter := _aiming_diver
	var direction := _aim_dir()
	_cancel_aim()
	if is_instance_valid(shooter):
		shooter.use_ability(direction)

func _cancel_aim() -> void:
	aiming = false
	if is_instance_valid(_aiming_diver):
		_aiming_diver.set_model_visible(_aim_model_was_visible)
	_aiming_diver = null
	if is_instance_valid(_aim_marker):
		_aim_marker.visible = false

func _update_aim_marker() -> void:
	if not aiming:
		return
	if _aim_marker == null:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.22
		ring.outer_radius = 0.32
		_aim_marker = MeshInstance3D.new()
		_aim_marker.name = "GrappleAimReticle"
		_aim_marker.mesh = ring
		_aim_marker_mat = StandardMaterial3D.new()
		_aim_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_aim_marker_mat.emission_enabled = true
		_aim_marker.material_override = _aim_marker_mat
		add_child(_aim_marker)
	var from := _diver.global_position + Vector3(0, _diver.height * 0.4, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + _aim_dir() * Diver.GRAPPLE_RANGE, Diver.GRAPPLE_COLLISION_MASK)
	query.exclude = [_diver.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = query.to if hit.is_empty() else hit.position
	var on_target: bool = not hit.is_empty() and (hit.collider as Node).is_in_group("grapple_anchor")
	_aim_marker.visible = true
	_aim_marker.global_position = point
	# Scale with distance so it doesn't fill the screen up close.
	_aim_marker.scale = Vector3.ONE * clampf(from.distance_to(point) / 3.0, 0.04, 1.0)
	_aim_marker.look_at(from, Vector3.UP)
	# TorusMesh's normal is local Y; turn it to face the eye.
	_aim_marker.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var color := Color(0.35, 0.95, 0.4) if on_target else Color(0.75, 0.78, 0.8)
	_aim_marker_mat.albedo_color = color
	_aim_marker_mat.emission = color
	_aim_marker_mat.emission_energy_multiplier = 1.6 if on_target else 0.7

func _exit_tree() -> void:
	_cancel_aim()
	_cancel_wall_motion()

# --- Keys ---
# Each key opens any one door.
var keys_held := 0

# `text` "" = no banner.
func _gain_key(id := "", text := "You've obtained a key") -> void:
	keys_held += 1
	if id != "" and not key_items.has(id):
		key_items.append(id)
	if text != "":
		_announce(text, 4.0)

# --- State barriers ---
# Invisible walls where a rotating wall set would be in its other position,
# so the water it leaves can't be swum into.
const BARRIER_HEIGHT := 9.0
var _hallway_barriers: Array[CollisionShape3D] = []
var _walls_14_15_barriers: Array[CollisionShape3D] = []
var _walls_10_11_home_barriers: Array[CollisionShape3D] = []
var _wall_11_joint := Vector3.ZERO   # north end of wall 11
var _wall_10_joint := Vector3.ZERO   # north end of wall 10
var _walls_14_15_rest: Array = []    # [[wall, position, yaw]]

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

# Barrier boxes over an east-west wall footprint, skipping x in [skip_lo, skip_hi].
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

# Continues CSGBox3DConnectorStub's line east to wall 11, closing the 9/11/13 area.
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

# Fences along the poster wall's line (behind the hallway), leaving the way to
# the dome open. The old StartBarrierNorth/West (between the dome exit and the
# wall nearest the dome) and StartBarrierSouth (across the area beside the
# poster wall) were removed; Box8DomeBarrier still keeps the dome side closed.
func _build_start_area_barriers() -> void:
	var t := 1.0
	# Stays south of the lab-side entry gap; don't fence the whole west side.
	var end_wall := get_node_or_null("HallwayEndWall") as CSGBox3D
	if end_wall != null:
		var g: Dictionary = _wall_geometry(end_wall)
		var a := g["negative_end"] as Vector3
		var b := g["positive_end"] as Vector3
		var west_end := a if a.x < b.x else b
		var east_end := b if a.x < b.x else a
		var line_z := end_wall.global_position.z
		var b6 := $CSGBox3D6 as CSGBox3D
		var b6_face := b6.global_position.x - b6.size.z * 0.5
		if b6_face >= east_end.x:
			_spawn_barrier("PosterWallBarrierEast", Vector3((east_end.x + b6_face) * 0.5, 0, line_z), Vector3(b6_face - east_end.x + t, 0, t))
		var edge_x := west_end.x
		for p in _collect_bounds_points():
			edge_x = minf(edge_x, p.x)
		edge_x -= _PERIMETER_MARGIN
		_spawn_barrier("PosterWallBarrierWest", Vector3((edge_x + west_end.x) * 0.5, 0, line_z), Vector3(west_end.x - edge_x + t, 0, t))

# Invisible floor-to-above-walls barrier at `center` with `footprint` x/z.
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
	for s in _walls_10_11_home_barriers:
		s.set_deferred("disabled", _walls_10_11_swung)

# --- Walls 10/11 ---
# The L map's third wall set. The Break Room endcap/closers stay put in either state.
var _walls_10_11_swung := false
var _walls_10_11_home: Array = []   # [[wall, position, yaw]]
var _wall_10_11_extras: Array[CSGBox3D] = []

func _walls_10_11_targets() -> Array:
	var w10 := $CSGBox3D10 as CSGBox3D
	var w11 := $CSGBox3D11 as CSGBox3D
	var rest15: Array = _walls_14_15_rest[1]
	var rest14: Array = _walls_14_15_rest[0]
	var west15 := (rest15[1] as Vector3).x - (rest15[0] as CSGBox3D).size.x * 0.5
	var west10 := west15 - w10.size.x
	return [[w11, Vector3(west10 + w11.size.x * 0.5, w11.global_position.y, (rest14[1] as Vector3).z), 0.0],
		[w10, Vector3(west15 - w10.size.x * 0.5, w10.global_position.y, (rest15[1] as Vector3).z), 0.0]]

func _draft_wall_line_x() -> float:
	var rest14: Array = _walls_14_15_rest[0]
	return (rest14[1] as Vector3).x - (rest14[0] as CSGBox3D).size.x * 0.5 - ($CSGBox3D11 as CSGBox3D).size.x

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
	_update_state_barriers()
	for wall in [$CSGBox3D10, $CSGBox3D11]:
		_suspend_motion_collision(wall)
	_track_wall_set_motion("CSGBox3D10/11", tweens, [$CSGBox3D10, $CSGBox3D11])
	if not tweens.is_empty():
		(tweens[-1] as Tween).finished.connect(func() -> void:
			$HUD/Controls.text = "Walls 10/11: OPEN." if _walls_10_11_swung else "Walls 10/11: CLOSED.")

func _build_wall_10_11_extras() -> void:
	var targets := _walls_10_11_targets()
	var w11 := $CSGBox3D11 as CSGBox3D
	var t := w11.size.z
	var end11_x := _draft_wall_line_x()
	var line10_z := (targets[1][1] as Vector3).z
	var line11_z := (targets[0][1] as Vector3).z
	var end10_x := (targets[1][1] as Vector3).x - ($CSGBox3D10 as CSGBox3D).size.x * 0.5
	var y := w11.global_position.y
	# From swung 11's end down to 10's line.
	var a_x := end11_x - t * 0.5
	var a_len := absf(line11_z - line10_z) + t
	var wall_a := _spawn_wall("Wall11EndCap", Vector3(a_x, y, (line11_z + line10_z) * 0.5), PI * 0.5, Vector3(a_len, w11.size.y, t))
	# Along 10's line to swung 10's end.
	var b_x0 := a_x - t * 0.5
	var wall_b := _spawn_wall("Wall10Closer", Vector3((b_x0 + end10_x) * 0.5, y, line10_z), 0.0, Vector3(absf(end10_x - b_x0), w11.size.y, t))
	var end11_swung_x := (targets[0][1] as Vector3).x - w11.size.x * 0.5
	var wall_c := _spawn_wall("Wall11Closer", Vector3((b_x0 + end11_swung_x) * 0.5, y, line11_z), 0.0, Vector3(absf(end11_swung_x - b_x0), w11.size.y, t))
	for wall in [wall_a, wall_b, wall_c]:
		_wall_10_11_extras.append(wall)
		wall_boxes.append(wall)
	# Potion rock in the inside corner.
	var r := 0.55
	var inward_z := signf(line11_z - line10_z)
	var spot := Vector3(a_x + t * 0.5 + r + 0.25, _floor_top_y + r, line10_z + inward_z * (t * 0.5 + r + 0.25))
	_potion_rock_spot = spot
	var rock := CrackedWall.new()
	rock.span = Vector3(1.1, 1.1, 1.1)
	rock.disguised_as_scenery_rock = true
	rock.position = spot
	rock.broken.connect(_on_secret_rock_broken.bind("potion", spot + Vector3(0, 0.6, 0)))
	add_child(rock)
	# No Wall10LineBarrier: that invisible fence along wall 10's line blocked
	# crossing over to the BreakRock (BR) current.
	_update_state_barriers()

# --- Progress gate (switch puzzle) ---
# Bars between CSGBox3D20 and CSGBox3D21; solving the switch puzzle lowers them.
var _gate: StaticBody3D
var _gate_lowered := false
var _gate_cutscene := false
var _gate_view_spot := Vector3.ZERO   # cutscene camera position

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

func _lower_gate() -> void:
	if _gate == null or _gate_lowered:
		return
	_gate_lowered = true
	_mark_switch_done()
	# Cutscene: camera watches the gate sink, then eases back (no steering meanwhile).
	_gate_cutscene = true
	var tw := create_tween()
	tw.tween_interval(1.2)   # camera travel
	tw.tween_property(_gate, "global_position:y", _gate.global_position.y - 6.6, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_gate.visible = false
		for c in _gate.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true)
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void: _gate_cutscene = false)

# E in the minigame: restart it.
func _retry_switch_minigame() -> void:
	if switch_modal_open():
		_switch_modal.close()
	await get_tree().process_frame
	_open_switch_minigame()

# After a wrong answer, posters get a new number order.
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

# Correct if every portrait landed on its poster's number.
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

# Third poster: on RewardChamberWestWall's face just east of the switch.
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

# --- The split rock ---
# At wall 10's wall-8 end. Splits (cutscene) when WindCorridor4 (-Z) and
# WindCorridorBreakRock (+Z) currents run together, dropping a key.
const SPLIT_ROCK_RADIUS := 1.5
const SPLIT_ROCK_REACH := 2.6
var _split_rock: Node3D
var _split_halves: Array[Node3D] = []   # pivots at the bottom of the split
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
	stone.vertex_color_use_as_albedo = true
	stone.roughness = 1.0
	# Two faceted halves in a V with a glowing fissure between them.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.6, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.45, 0.1)
	glow.emission_energy_multiplier = 4.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for side in [1.0, -1.0]:
		# Pivot at the bottom of the split.
		var pivot := Node3D.new()
		pivot.position = Vector3(0, -SPLIT_ROCK_RADIUS * 0.75, side * 0.12)
		pivot.rotation.x = side * 0.2
		_split_rock.add_child(pivot)
		var half := MeshInstance3D.new()
		half.mesh = _broken_half_mesh(SPLIT_ROCK_RADIUS, rng)
		half.material_override = stone
		half.rotation.x = side * PI * 0.5        # broken faces toward each other
		half.rotation.y = 0.12 * side
		half.scale = Vector3(1.12, 0.92, 0.95)
		half.position = Vector3(0, SPLIT_ROCK_RADIUS * 0.75, 0)
		pivot.add_child(half)
		_split_halves.append(pivot)
	var crack := Node3D.new()
	crack.name = "Crack"
	_split_rock.add_child(crack)
	var sheet := MeshInstance3D.new()
	var sheet_mesh := CylinderMesh.new()
	sheet_mesh.top_radius = SPLIT_ROCK_RADIUS * 0.8
	sheet_mesh.bottom_radius = SPLIT_ROCK_RADIUS * 0.8
	sheet_mesh.height = 0.06
	sheet.mesh = sheet_mesh
	sheet.rotation.x = PI * 0.5
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
	for i in 7:
		var chunk := MeshInstance3D.new()
		chunk.mesh = _broken_half_mesh(rng.randf_range(0.14, 0.3), rng)
		chunk.material_override = stone
		var a := rng.randf() * TAU
		var r := SPLIT_ROCK_RADIUS * rng.randf_range(1.0, 1.5)
		chunk.position = Vector3(cos(a) * r, -SPLIT_ROCK_RADIUS * 0.8 + 0.05, sin(a) * r)
		chunk.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		_split_rock.add_child(chunk)
	# Swings with wall 10.
	_split_rock.reparent(b10, true)

func _split_rock_in_reach() -> bool:
	if _split_rock == null or _rock_split or _diver == null:
		return false
	var a := _split_rock.global_position
	var b := _diver.global_position
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) <= SPLIT_ROCK_RADIUS + SPLIT_ROCK_REACH

# Also requires the wall set to have stopped, so it can't split mid-swing.
func _rock_over_currents() -> bool:
	return _walls_10_11_swung and not _wall_set_moving("CSGBox3D10/11")

func _check_split_rock() -> void:
	if _rock_split or _split_rock == null or _battling or any_modal_open():
		return
	var break_rock := get_node_or_null("WindCorridorBreakRock") as Area3D
	if break_rock == null:
		return
	# Only once walls 10/11 rest on the line where the currents meet.
	if not _rock_over_currents():
		return
	var a: WaterCurrent = _currents_by_corridor.get($WindCorridor4, null)
	var b: WaterCurrent = _currents_by_corridor.get(break_rock, null)
	if a == null or b == null or a.orientation.dot(b.orientation) > -0.9:
		return
	_play_split_rock_cutscene()

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
	# Viewed from the corridor side, turned with wall 10.
	var view_dir := _split_rock.global_basis * Vector3(-0.35, 0, 1.0)
	view_dir.y = 0.0
	view_dir = view_dir.normalized()
	var cam_to := rock + view_dir * 7.5 + Vector3(0, 3.2, 0)
	var cam_from := cam.global_position
	var look_from := _cam_look if _cam_look != Vector3.ZERO else rock
	var land := rock + view_dir * 3.6
	land.y = _floor_top_y + 0.7
	var tw := director.create_tween()
	tw.tween_method(func(f: float) -> void:
		cam.global_position = cam_from.lerp(cam_to, f)
		cam.look_at(look_from.lerp(rock, f), Vector3.UP), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(f: float) -> void:
		var shake := sin(f * 70.0) * 0.07 * (0.4 + f)
		_split_rock.global_position = rock + Vector3(shake, 0, -shake * 0.6)
		cam.global_position = cam_to + Vector3(0, sin(f * 55.0) * 0.05, 0)
		cam.look_at(rock, Vector3.UP), 0.0, 1.0, 1.1)
	# Each half flung along its current.
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
	tw.tween_method(func(f: float) -> void:
		for h in _split_halves:
			h.scale = Vector3.ONE * (1.0 - f)
		, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		for h in _split_halves:
			h.visible = false)
	# Key hops toward the camera and bounces twice.
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
		# Quadratic Bezier.
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

# Landed key bobs and spins until a diver swims into it.
func _spawn_key_pickup(key: Node3D) -> void:
	key.process_mode = Node.PROCESS_MODE_INHERIT
	key.set_meta("campaign_pickup_id", "split_rock_key")
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
		if maze_active and body is Diver and is_instance_valid(key) and not key.is_queued_for_deletion():
			key.queue_free()
			_gain_key("split_rock_key"))

# --- Map points of interest ---
# {"id", "kind", "pos", "radius", optional "rect", "label", "done"}; kinds: poster, chest, switch, rock, room_label.
func map_points_of_interest() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if special_sites != null:
		for site in special_sites.points_of_interest():
			if _diver == null or special_sites.within_site_height(_diver.global_position.y, (site.pos as Vector3).y):
				out.append(site)
	for p in _posters:
		out.append({"id": String(p.name), "kind": "poster", "pos": p.global_position, "radius": 7.0, "done": p.seen, "texture": p.portrait})
	for k in key_pickups:
		if is_instance_valid(k) and not k.is_queued_for_deletion():
			out.append({"id": "key_%s" % String(k.get_meta("campaign_pickup_id", "%.3f_%.3f_%.3f" % [k.global_position.x, k.global_position.y, k.global_position.z])), "kind": "key", "pos": k.global_position, "radius": 9.0})
	for i in broken_rock_spots.size():
		out.append({"id": "broken_rock_%d" % i, "kind": "broken_rock", "pos": broken_rock_spots[i], "radius": INF})
	if _vortex_chest != null and is_instance_valid(_vortex_chest):
		out.append({"id": "vortex_chest", "kind": "chest", "pos": _vortex_chest.global_position, "radius": 9.0, "done": _vortex_chest_open})
	if _map_chest != null and is_instance_valid(_map_chest):
		out.append({"id": "map_chest", "kind": "chest", "pos": _map_chest.global_position, "radius": 9.0, "done": _map_chest_open})
	# Bosses are discovered only by entering their room.
	for boss_room in [{"id": "boss_secret", "rect": _secret_boss_room_rect(true)}, {"id": "boss_main", "rect": _main_boss_room_rect()}]:
		var rect: Rect2 = boss_room.rect
		if rect.size != Vector2.ZERO:
			var center := rect.get_center()
			out.append({"id": boss_room.id, "kind": "boss", "pos": Vector3(center.x, 0, center.y), "radius": 0.0, "rect": rect})
	if _switch_node != null:
		out.append({"id": "room_switch", "kind": "switch", "pos": _switch_node.global_position, "radius": 7.0, "done": _gate_lowered})
	if _split_rock != null and is_instance_valid(_split_rock):
		out.append({"id": "split_rock", "kind": "rock", "pos": _split_rock.global_position, "radius": 8.0, "done": false})
	var item_room := _secret_item_room_rect()
	if item_room.size != Vector2.ZERO:
		var c := item_room.get_center()
		out.append({"id": "secret_item_room", "kind": "room_label", "pos": Vector3(c.x, 0, c.y), "radius": 0.0, "rect": item_room, "label": "Secret\nItem Room"})
	if _dome_site != Vector3.ZERO:
		# Don't extend the box east into the entrance walls.
		var depth := PLINTH_RADIUS * 2 + STEP_COUNT * STEP_DEPTH * 0.6
		var dome := Rect2(_dome_site.x - PLINTH_RADIUS, _dome_site.z - PLINTH_RADIUS, PLINTH_RADIUS * 2, depth)
		out.append({"id": "control_room", "kind": "room_label", "pos": Vector3(_dome_site.x, 0, _dome_site.z + PLINTH_RADIUS * 0.7), "radius": 0.0, "rect": dome, "label": "Control\nRoom"})
	return out

func _main_boss_room_rect() -> Rect2:
	var north := get_node_or_null("MainBossRoomNorth") as CSGBox3D
	var south := get_node_or_null("MainBossRoomSouth") as CSGBox3D
	var east := get_node_or_null("MainBossRoomEast") as CSGBox3D
	if north == null or south == null or east == null:
		return Rect2()
	var x0 := north.global_position.x - north.size.x * 0.5
	var x1 := east.global_position.x - east.size.z * 0.5
	var z0 := minf(north.global_position.z, south.global_position.z) + north.size.z * 0.5
	var z1 := maxf(north.global_position.z, south.global_position.z) - south.size.z * 0.5
	return Rect2(x0, z0, x1 - x0, z1 - z0)

# Half a broken rock: faceted dome (+Y) over a jagged fracture face (-Y). Flat-shaded.
func _broken_half_mesh(radius: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var segs := 9
	var rings := 4
	var weathered := Color(0.33, 0.31, 0.28)
	var raw := Color(0.55, 0.49, 0.42)
	var rows: Array = []   # rows[r][s], r = 0 is the broken rim
	for r in rings:
		var phi := float(r) / float(rings) * PI * 0.5
		var row: Array[Vector3] = []
		for s in segs:
			var theta := (float(s) + rng.randf_range(-0.25, 0.25)) / float(segs) * TAU
			var rr := radius * rng.randf_range(0.8, 1.12)
			var p := Vector3(cos(theta) * cos(phi), sin(phi), sin(theta) * cos(phi)) * rr
			if r == 0:
				p.y = radius * rng.randf_range(-0.12, 0.14)
			row.append(p)
		rows.append(row)
	var pole := Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.8, 1.0), rng.randf_range(-0.15, 0.15)) * radius
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

# --- Wall skirts ---
# Fills the gap between each wall's bottom and the floor; child of the wall so it moves with it.
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
	wall.visibility_changed.connect(func() -> void:
		shape.set_deferred("disabled", not wall.visible))
	shape.disabled = not wall.visible

# --- Broken rocks and loose keys (for the maps) ---
var broken_rock_spots: Array[Vector3] = []
var key_pickups: Array[Node3D] = []          # not yet picked up

func _note_broken_rock(spot: Vector3) -> void:
	var room := _secret_item_room_rect()
	if room.size != Vector2.ZERO and room.has_point(Vector2(spot.x, spot.z)):
		broken_rock_spots.append(spot)

# --- The hall between the boss rooms ---
# 8 rows of rock columns (alternating two and one) so the way weaves; gaps hold rocks
# and small whirlpools that return you to the hall's entrance.
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
	# Hall entrance (north-west corner), where whirlpools drop you.
	var entrance := Vector3(hall.position.x + 1.8, ($DiverEntry as Node3D).global_position.y, hall.position.y + 1.6)
	# Whirlpool lanes as fractions of hall width from the middle, between the columns.
	var whirl_spread := [-0.42, 0.13, 0.42, -0.13]
	var whirl_n := 0
	var gap_half := (xs[1] - xs[0]) * 0.5 if xs.size() > 1 else 2.0
	for g in HALL_ROWS - 1:
		var x := (xs[g] + xs[g + 1]) * 0.5
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var z := z_mid + side * hall.size.y * rng.randf_range(0.3, 0.4)
		if g % 2 == 0:
			# Hidden behind a column on the side away from the entrance.
			var col_zs: Array = row_zs[g]
			var col_i := rng.randi() % col_zs.size()
			var col_z := float(col_zs[col_i])
			var spot := Vector3(xs[g] + HALL_COLUMN_RADIUS * 1.3 + 0.55, _floor_top_y + 0.55, col_z)
			var rock := CrackedWall.new()
			rock.span = Vector3(1.1, 1.1, 1.1)
			rock.sphere_shaped = true
			rock.position = spot
			var reward := "ambush" if g % 4 == 2 else "potion"
			rock.broken.connect(_on_secret_rock_broken.bind(reward, spot + Vector3(0, 0.6, 0)))
			add_child(rock)
			# Oxygen Cell behind the other column. No rng calls, so the layout is unchanged.
			if reward == "potion" and col_zs.size() > 1:
				var cell_spot := Vector3(spot.x, spot.y, float(col_zs[(col_i + 1) % col_zs.size()]))
				var cell_rock := CrackedWall.new()
				cell_rock.span = Vector3(1.1, 1.1, 1.1)
				cell_rock.sphere_shaped = true
				cell_rock.position = cell_spot
				cell_rock.broken.connect(_on_secret_rock_broken.bind("oxygen_cell", cell_spot + Vector3(0, 0.6, 0)))
				add_child(cell_rock)
		else:
			var w := Whirlpool.new()
			w.suction_radius = 0.9
			w.suction_height = 12.0
			# Pulls only right at the hole's edge.
			w.warning_radius = 2.6
			w.pull_radius = 1.6
			w.pull_speed = 2.4
			w.damage_min = 1
			w.damage_max = 1
			w.reset_to = entrance
			# Open shaft below; _carve_hall_whirlpool_holes() cuts the floor.
			w.deep_hole_radius = w.suction_radius + 0.1
			w.diver_sucked_in.connect(_on_deep_whirlpool)
			add_child(w)
			var frac: float = whirl_spread[whirl_n % whirl_spread.size()]
			whirl_n += 1
			var wz := z_mid + frac * hall.size.y
			var wx := x + rng.randf_range(-1.0, 1.0) * maxf(0.0, gap_half - HALL_COLUMN_RADIUS - w.pull_radius - 0.3)
			w.global_position = Vector3(wx, _floor_top_y + FLOOR_THICKNESS_VISUAL + 0.01, wz)
			_hall_whirlpools.append(w)

# Hole in the visible floor under each deep whirlpool (the invisible slab stays).
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

# Solid column of boulders, floor to ceiling.
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

# --- Inventory ---
# World functions called by InventoryMenu, implemented here.
var inventory_menu: InventoryMenu

func _build_inventory_menu() -> void:
	inventory_menu = InventoryMenu.new()
	inventory_menu.world = self
	$HUD.add_child(inventory_menu)
	inventory_menu.visibility_changed.connect(_refresh_announcement_visibility)

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
	if String(spell.get("target", "")) == "all_allies":
		# Party-wide heal (Healing Current): every living, hurt diver.
		var hurt := divers.filter(func(d: Diver) -> bool: return d.stats.hp > 0 and d.stats.hp < d.stats.hp_max)
		if hurt.is_empty():
			_announce("Everyone is already at full health.")
			return
		caster.stats.oxygen -= float(spell.get("oxygen_cost", 0.0))
		var parts: Array[String] = []
		for d in hurt:
			var before: int = d.stats.hp
			d.stats.hp = mini(d.stats.hp_max, d.stats.hp + int(spell.get("amount", 0)))
			parts.append("%s +%d" % [_display_name(d.model_name), d.stats.hp - before])
		_announce("%s - %s HP." % [_party_spell_label(spell), ", ".join(parts)])
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

# Campaign saves hold plain data and only stable state (no in-flight rewards).
const CAMPAIGN_FLAGS := ["_completed", "_hallway_1_2_swung", "_walls_14_15_open",
	"_walls_10_11_swung", "_path_opened", "_current_1_in_2", "_current_3_in_4",
	"_current_5_in_6", "_current_7_in_8", "_gate_lowered", "_rock_split",
	"_vortex_chest_open", "has_sonar_vision", "sonar_vision_equipped",
	"room_encounters_enabled", "_strong_room_seen", "_switch_explained"]

func can_capture_campaign_snapshot() -> bool:
	return _moving_wall_sets.is_empty() and not _wall_riders.busy() and not Whirlpool.busy_in(self) and not _gate_cutscene and not _cordys_reveal and not _chest_reward_pending \
		and not _battling and not aiming and not get_tree().paused and not any_modal_open() \
		and special_sites != null and special_sites.initialized

var _checkpoint: SavePoint
var _campaign_save_points: Array[SavePoint] = []
var _checkpoint_contact_point: SavePoint
var _save_menu: SavePointMenu
var _checkpoint_contact := false
var _checkpoint_saving := false
var _game_over: GameOverScreen
var _campaign_exit: Node3D
var _campaign_exit_prompt: Label3D
var _campaign_exit_pending := false

func _build_campaign_exit() -> void:
	if world != null:
		return # Swim back through the opening; no E portal.
	if campaign_session == null or campaign_session.outer_world_checkpoint.is_empty():
		return
	_campaign_exit = Node3D.new()
	_campaign_exit.name = "CampaignExit"
	_campaign_exit.position = _midpoint_between($CSGBox3D, $CurrentWall3)
	_campaign_exit.position.y = _floor_top_y
	add_child(_campaign_exit)
	var label := Label3D.new()
	label.text = "Open Water\nE: Leave maze"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 38
	label.pixel_size = 0.002
	label.position = Vector3(0, 3.2, 0)
	_campaign_exit.add_child(label)
	_campaign_exit_prompt = label

func _campaign_exit_in_reach() -> bool:
	if _campaign_exit == null or _diver == null:
		return false
	return _diver.global_position.distance_to(_campaign_exit.global_position) <= 3.0

func _landmark_caption_clear(label: Label3D) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(label.global_position):
		return false
	# Hide labels near the edges or under the minimap/top controls instead of clipping.
	var area := Rect2(camera.unproject_position(label.global_position) - Vector2(80, 24), Vector2(160, 48))
	var viewport := Rect2(Vector2(8, 8), get_viewport().get_visible_rect().size - Vector2(16, 16))
	if not viewport.encloses(area):
		return false
	var radar := get_node_or_null("HUD/MazeMiniMap") as Control
	if radar != null and area.intersects(radar.get_global_rect()):
		return false
	if _world_hud_name != null and area.intersects((_world_hud_name.get_parent() as Control).get_global_rect()):
		return false
	return true

func _return_to_campaign_world() -> void:
	if _campaign_exit_pending or not can_capture_campaign_snapshot() \
		or (target_selector != null and target_selector.selecting):
		return
	# Leaving the maze closes the nav map rather than being blocked by it.
	var minimap := get_node("HUD/MazeMiniMap") as MazeMiniMap
	minimap.main_map.visible = false
	campaign_session.capture_party(divers, active)
	campaign_session.inventory = inventory
	campaign_session.maze_snapshot = campaign_snapshot()
	_campaign_exit_pending = true
	SceneHandoff.campaign_session = campaign_session
	SceneHandoff.returning_to_world = true
	var error := get_tree().change_scene_to_file("res://game/world.tscn")
	if error != OK:
		SceneHandoff.campaign_session = null
		SceneHandoff.returning_to_world = false
		_campaign_exit_pending = false
		_announce("Open water could not load. Please retry.")

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
	# A base seafloor slightly below the hallway/room floors, so there are no gaps.
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
	for pair in HALLWAY_PAIRS:
		var a := get_node_or_null(String(pair[0])) as CSGBox3D
		var b := get_node_or_null(String(pair[1])) as CSGBox3D
		if a != null and b != null:
			n += int(_hallway_floor("Floor_%s_%s" % [pair[0], pair[1]], _footprint(a), _footprint(b)))
	# Rotating halls: both start and swung positions.
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

func _footprint(w: CSGBox3D) -> Dictionary:
	return {"centre": w.global_position, "yaw": w.rotation.y, "length": w.size.x}

# Floor strip between two parallel footprints where they overlap; false if they don't.
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
	# Gap width plus reach under both walls.
	_floor_box(floor_name, centre, atan2(-axis.z, axis.x), Vector2(hi - lo, absf(gap) + 1.0))
	return true

func _floor_box(floor_name: String, centre: Vector3, yaw: float, footprint: Vector2, lift := 0.0) -> void:
	var box := CSGBox3D.new()
	box.name = floor_name
	box.size = Vector3(footprint.x, FLOOR_THICKNESS_VISUAL, footprint.y)
	# No material: same default look as the walls.
	box.use_collision = false
	add_child(box)
	box.rotation.y = yaw
	box.global_position = Vector3(centre.x, _floor_top_y + FLOOR_THICKNESS_VISUAL * 0.5 + 0.01 + lift, centre.z)

func _carve_draft_visual_floor() -> void:
	# Visual-only holes over DraftPassages' slots.
	var slots: Array = [draft_passages.outgoing_slot, draft_passages.return_visuals[0], draft_passages.box12_slot]
	for child in get_children():
		if not child is CSGBox3D or not String(child.name).begins_with("Floor_"):
			continue
		for slot in slots:
			var hole := CSGBox3D.new()
			hole.operation = CSGShape3D.OPERATION_SUBTRACTION
			hole.size = (slot.mesh as BoxMesh).size
			child.add_child(hole)
			hole.global_position = Vector3(slot.global_position.x, child.global_position.y, slot.global_position.z)

func _build_campaign_checkpoint() -> void:
	_checkpoint = SavePoint.new()
	_checkpoint.name = "MazeCheckpoint"
	var spot := _midpoint_between($CSGBox3D, $CurrentWall3)
	spot.y = _floor_top_y
	_checkpoint.position = spot
	# Offset so entering isn't checkpoint contact.
	_checkpoint.position += _wall_geometry($CSGBox3D)["long_axis"] * 3.5
	add_child(_checkpoint)
	# No extra white caption: the save point's own sign is enough.
	_campaign_save_points.append(_checkpoint)
	# Two interior save points.
	var into := signf(($CSGBox3D10 as CSGBox3D).global_position.x - ($CSGBox3D11 as CSGBox3D).global_position.x)
	var interior: Array[Vector3] = [Vector3(_wall_11_joint.x + into * 2.4, _floor_top_y, _wall_11_joint.z - 2.2)]
	# Inside Cordys's room, beside its door.
	var boss_room := _main_boss_room_rect()
	if boss_room.size != Vector2.ZERO:
		interior.append(Vector3(boss_room.position.x + 2.0, _floor_top_y,
			clampf(_main_boss_door_z + DOOR_GAP_WIDTH * 0.5 + 2.0, boss_room.position.y + 1.5, boss_room.end.y - 1.5)))
	for place in interior:
		var point := SavePoint.new()
		point.name = "MazeCheckpoint%d" % _campaign_save_points.size()
		add_child(point)
		point.global_position = place
		point.global_position.y = _visible_floor_top_at(place)
		_campaign_save_points.append(point)
	_save_menu = SavePointMenu.new()
	_save_menu.save_requested.connect(_on_campaign_save_requested)
	$HUD.add_child(_save_menu)
	_save_menu.visibility_changed.connect(_refresh_announcement_visibility)
	var layer := CanvasLayer.new()
	layer.name = "MazeRecoveryLayer"
	layer.layer = 20
	add_child(layer)
	_game_over = GameOverScreen.new()
	_game_over.restart_chosen.connect(_restart_campaign_checkpoint)
	_game_over.continue_chosen.connect(_continue_campaign_checkpoint)
	_game_over.title_chosen.connect(_return_campaign_title)
	layer.add_child(_game_over)

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

func _contacted_campaign_checkpoint() -> SavePoint:
	for point in _campaign_save_points:
		if point.has_diver(_diver):
			return point
	return null

func _update_campaign_checkpoint() -> void:
	if _checkpoint == null or _diver == null or _battling:
		return
	var point := _contacted_campaign_checkpoint()
	var contact := point != null
	if _campaign_exit_prompt != null:
		_campaign_exit_prompt.visible = not any_modal_open() and not _battling and _landmark_caption_clear(_campaign_exit_prompt)
	if contact and point != _checkpoint_contact_point:
		for diver in divers:
			diver.stats.hp = diver.stats.hp_max
			diver.stats.oxygen = diver.stats.oxygen_max
		_announce("Save your progress.")
	_checkpoint_contact = contact
	_checkpoint_contact_point = point

func _on_campaign_save_requested(_actor: Diver, slot: int) -> void:
	if _checkpoint_saving:
		return
	# Close the Save menu first so it doesn't block its own request.
	_save_menu.close()
	if not can_capture_campaign_snapshot():
		_announce("Wait for the puzzle movement to finish, then save.")
		return
	if campaign_session == null:
		campaign_session = CampaignSession.new()
		campaign_session.route_state = RouteState.new()
		campaign_session.route_state.prologue_complete = true
		campaign_session.route_state.opening_video_seen = true
		campaign_session.route_state.set_zone("maze")
		campaign_session.campaign_key_items.assign(campaign_key_items)
		campaign_session.random_encounters_enabled = random_encounters_enabled
	for diver in divers:
		diver.stats.hp = diver.stats.hp_max
		diver.stats.oxygen = diver.stats.oxygen_max
	campaign_session.capture_party(divers, active)
	campaign_session.inventory = inventory
	campaign_session.maze_snapshot = campaign_snapshot()
	if world != null:
		campaign_session.outer_world_checkpoint = world._serialize_world_state()
		campaign_session.random_encounters_enabled = random_encounters_enabled
	_checkpoint_saving = true
	var existed := SaveManager.slot_exists(slot)
	var previous := FileAccess.get_file_as_bytes(SaveManager.slot_path(slot)) if existed else PackedByteArray()
	var error := SaveManager.write_slot(slot, CampaignCheckpoint.encode(campaign_session))
	var candidate_written := error == OK
	if error == OK:
		error = await BrowserCheckpoint.confirm_slot(slot)
	_checkpoint_saving = false
	if error != OK:
		# On sync failure, restore the previous slot bytes.
		if candidate_written and SaveManager.rollback_slot(slot, existed, previous) != OK:
			_announce("Saving failed and recovery could not be confirmed. Please retry before leaving.")
			return
		_announce("Could not save. Your last checkpoint is unchanged. Please retry.")
		return
	campaign_session.selected_slot = slot
	if world != null:
		world._current_slot = slot
	_announce("Progress saved to Slot %d." % (slot + 1))

func _show_campaign_game_over() -> void:
	$HUD.visible = false
	get_tree().paused = true
	_mouse_look = false
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		audio.call("play_game_over_music")
	_game_over.open(world.autosave_tooltip() if world != null else "")

func _restart_campaign_checkpoint() -> void:
	_reload_campaign_checkpoint(false)

func _continue_campaign_checkpoint() -> void:
	_reload_campaign_checkpoint(true)

func _reload_campaign_checkpoint(latest: bool) -> void:
	World._restart_slot = campaign_session.selected_slot if campaign_session != null else -1
	World._restart_latest = latest
	if World._restart_slot < 0:
		SceneHandoff.checkpoint_load_error = "No checkpoint exists yet. Choose a saved game or start a new game."
	get_tree().paused = false
	get_tree().change_scene_to_file("res://game/world.tscn")

func _return_campaign_title() -> void:
	World._restart_slot = -1
	World._restart_latest = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://game/world.tscn")

func campaign_snapshot() -> Dictionary:
	var data := {"version": 1, "coordinate_origin": CampaignSession.vector_data(coordinate_origin),
		"flags": {}, "walls": {}, "currents": [],
		"doors": [], "rocks": [], "orbs": [], "loose_keys": [], "posters": [],
		"positions": [], "levers": [], "broken_rocks": [], "keys_held": keys_held,
		"key_items": key_items.duplicate(), "boss_triggers": _boss_triggers.keys(),
		"yaw": _yaw, "pitch": _pitch}
	for flag in CAMPAIGN_FLAGS:
		data.flags[flag] = bool(get(flag))
	data.rotation_homes = {"hallway_a": CampaignSession.vector_data(_hallway_1_2_home_pos_a),
		"hallway_b": CampaignSession.vector_data(_hallway_1_2_home_pos_b),
		"hallway_yaw_a": _hallway_1_2_home_yaw_a, "hallway_yaw_b": _hallway_1_2_home_yaw_b,
		"walls_14_15": _wall_home_data(_walls_14_15_home), "walls_10_11": _wall_home_data(_walls_10_11_home)}
	for child in get_children():
		if child is CSGBox3D:
			var wall := child as CSGBox3D
			data.walls[String(wall.name)] = {"position": CampaignSession.vector_data(wall.position),
				"rotation": CampaignSession.vector_data(wall.rotation), "size": CampaignSession.vector_data(wall.size),
				"visible": wall.visible, "collision": wall.use_collision}
		elif child is CrackedWall and not child.is_queued_for_deletion():
			data.rocks.append(CampaignSession.vector_data((child as Node3D).global_position))
		elif child is ItemOrb and not child.is_queued_for_deletion():
			var orb := child as ItemOrb
			data.orbs.append({"item": orb.item_id, "position": CampaignSession.vector_data(orb.position),
				"golden": orb.golden, "grappleable": orb.grappleable, "grapple_only": orb.grapple_only})
	for area in _currents_by_corridor:
		var current := _currents_by_corridor[area] as WaterCurrent
		data.currents.append({"area": String((area as Node).name),
			"orientation": CampaignSession.vector_data(current.orientation), "strength": current.strength})
	for door in _maze_doors:
		if is_instance_valid(door) and door.is_open():
			data.doors.append(door.door_id)
	for key in key_pickups:
		if is_instance_valid(key) and not key.is_queued_for_deletion() and not key is ItemOrb:
			data.loose_keys.append({"position": CampaignSession.vector_data(key.global_position)})
	for poster in _posters:
		data.posters.append({"diver": poster.diver_index, "number": poster.number, "seen": poster.seen,
			"portrait": poster.portrait.resource_path, "seed": poster.scribble_seed})
	for diver in divers:
		data.positions.append(CampaignSession.vector_data(diver.position))
	for lever in _lever_holders:
		data.levers.append({"lever": _dome_levers.find(lever), "diver": divers.find(_lever_holders[lever])})
	for spot in broken_rock_spots:
		data.broken_rocks.append(CampaignSession.vector_data(spot))
	var map := get_node("HUD/MazeMiniMap") as MazeMiniMap
	data.map = map.campaign_discovery()
	if special_sites != null and special_sites.initialized:
		data.special_sites = special_sites.snapshot()
	return data

func _wall_home_data(homes: Array) -> Array:
	var out: Array = []
	for entry in homes:
		out.append({"wall": String((entry[0] as Node).name),
			"position": CampaignSession.vector_data(entry[1]), "yaw": entry[2]})
	return out

func _restore_wall_homes(homes: Array) -> Array:
	var out: Array = []
	for entry in homes:
		out.append([get_node(String(entry.wall)), CampaignSession.vector_from(entry.position), float(entry.yaw)])
	return out

func restore_campaign_snapshot(data: Dictionary, restore_positions := true) -> void:
	_cancel_aim()
	if draft_passages != null:
		draft_passages.cancel()
	# Rebase every spatial field into this frame (identity standalone).
	data = MazeCoordinateFrame.rebase(data, coordinate_origin)
	if data.is_empty():
		return
	# Cancel after preflight so old Tweens can't move walls after restore.
	_cancel_wall_motion(true)
	Whirlpool.cancel_in(self, not restore_positions)
	for flag in CAMPAIGN_FLAGS:
		set(flag, bool(data.flags.get(flag, false)))
	keys_held = int(data.keys_held)
	key_items.assign(data.key_items)
	_yaw = float(data.yaw)
	_pitch = float(data.pitch)
	var homes: Dictionary = data.rotation_homes
	_hallway_1_2_home_pos_a = CampaignSession.vector_from(homes.hallway_a)
	_hallway_1_2_home_pos_b = CampaignSession.vector_from(homes.hallway_b)
	_hallway_1_2_home_yaw_a = float(homes.hallway_yaw_a)
	_hallway_1_2_home_yaw_b = float(homes.hallway_yaw_b)
	_walls_14_15_home = _restore_wall_homes(homes.walls_14_15)
	_walls_10_11_home = _restore_wall_homes(homes.walls_10_11)
	# Old opened-path saves: drop the retired route, keep other walls.
	var retired_route: bool = _path_opened or data.walls.has("PathWallNorth") or data.walls.has("PathWallSouth")
	for wall_name in data.walls:
		if wall_name in ["PathWallNorth", "PathWallSouth"] or (retired_route and _control_route_homes.has(wall_name)):
			continue
		var spec: Dictionary = data.walls[wall_name]
		var wall := get_node_or_null(String(wall_name)) as CSGBox3D
		if wall != null:
			wall.position = CampaignSession.vector_from(spec.position)
			wall.rotation = CampaignSession.vector_from(spec.rotation)
			wall.size = CampaignSession.vector_from(spec.size)
			wall.visible = bool(spec.visible)
			wall.use_collision = bool(spec.collision)
	if retired_route:
		for name_value in _control_route_homes:
			var wall := get_node(String(name_value)) as CSGBox3D
			var home: Dictionary = _control_route_homes[name_value]
			wall.position = home.position
			wall.rotation = home.rotation
			wall.size = home.size
			wall.visible = true
			wall.use_collision = true
	var draft_layout_migrated := _reconcile_legacy_draft_walls()
	for current in _currents_by_corridor.values():
		(current as WaterCurrent).teardown()
		(current as WaterCurrent).queue_free()
	_currents_by_corridor.clear()
	for spec in data.currents:
		var area := get_node(String(spec.area)) as Area3D
		var current := WaterCurrent.new()
		add_child(current)
		current.setup(area, CampaignSession.vector_from(spec.orientation), float(spec.strength), false)
		_currents_by_corridor[area] = current
	for door in _maze_doors:
		if data.doors.has(door.door_id):
			door.restore_open_state()
	for child in get_children():
		if child is CrackedWall:
			var still_present := false
			for spot in data.rocks:
				still_present = still_present or (child as Node3D).global_position.distance_to(CampaignSession.vector_from(spot)) < 0.01
			if not still_present:
				child.queue_free()
	# Replace pending drops so repeated restores don't duplicate rewards.
	# Queue deletion before detaching so late callbacks are inert.
	for child in get_children():
		if child is ItemOrb:
			child.queue_free()
			remove_child(child)
	for key in key_pickups:
		if is_instance_valid(key) and not key is ItemOrb and not key.is_queued_for_deletion():
			key.queue_free()
			if key.get_parent() != null:
				key.get_parent().remove_child(key)
	key_pickups.clear()
	for spec in data.orbs:
		_spawn_secret_reward_orb(String(spec.item), CampaignSession.vector_from(spec.position),
			bool(spec.golden), bool(spec.grappleable), bool(spec.grapple_only))
	for spec in data.loose_keys:
		var key := _make_key_mesh()
		add_child(key)
		key.global_position = CampaignSession.vector_from(spec.position)
		key.scale = Vector3.ONE * 1.4
		_add_key_shine(key)
		_spawn_key_pickup(key)
	broken_rock_spots.clear()
	for spot in data.broken_rocks:
		broken_rock_spots.append(CampaignSession.vector_from(spot))
	poster_clues.clear()
	for i in range(_posters.size()):
		var poster := _posters[i]
		var spec: Dictionary = data.posters[i]
		poster.diver_index = int(spec.diver)
		poster.number = int(spec.number)
		poster.portrait = load(String(spec.portrait)) as Texture2D
		poster.scribble_seed = int(spec.seed)
		for child in poster.get_children():
			if child is SubViewport:
				for old_art in child.get_children():
					old_art.queue_free()
				child.add_child(MazePoster.build_art(Vector2(MazePoster.ART_PIXELS), poster.portrait, poster.scribble_seed))
				(child as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		if bool(spec.seen):
			poster.mark_seen()
		poster_clues.append({"diver": poster.diver_index, "number": poster.number})
	if restore_positions:
		for i in range(divers.size()):
			divers[i].position = CampaignSession.vector_from(data.positions[i])
	if draft_layout_migrated:
		_clear_party_from_migrated_draft_wall()
	if retired_route:
		_clear_party_from_retired_control_route()
	for holder in data.levers:
		var index := int(holder.lever)
		# Old saves may reference removed dome levers.
		if index >= _dome_levers.size():
			continue
		var lever := _dome_levers[index]
		_lever_holders[lever] = divers[int(holder.diver)]
		lever.pull()
		_set_lever_light(index, true)
	if _gate_lowered:
		_mark_switch_done()
		_gate.visible = false
		for child in _gate.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred("disabled", true)
	if _vortex_chest_open:
		_vortex_chest_lid.rotation.x = -deg_to_rad(110.0)
	_restore_map_chest_ownership()
	if _rock_split and is_instance_valid(_split_rock):
		_split_rock.queue_free()
		_split_rock = null
	for kind in _boss_triggers.keys():
		if not data.boss_triggers.has(kind):
			_remove_boss_trigger(String(kind))
	_set_cordys_out(not _boss_triggers.has("secret_boss"))
	if route_state != null:
		route_state.set_octopus_state("available" if _boss_triggers.has("main_boss") else "defeated")
	_update_state_barriers()
	if data.has("special_sites"):
		special_sites.restore(data.special_sites)
	else:
		special_sites.restore_legacy()
	(get_node("HUD/MazeMiniMap") as MazeMiniMap).restore_campaign_discovery(data.map)
	$HUD/Controls.text = ("Hallway: OPEN" if _hallway_1_2_swung else "Hallway: CLOSED. Open the map (L).") \
		if key_items.has(MAP_ITEM) else "Navigation map: not acquired."

func _clear_party_from_retired_control_route() -> void:
	# Move only divers overlapping a restored wall, to a validated nearby spot.
	for diver in divers:
		for name_value in _control_route_homes:
			var wall := get_node(String(name_value)) as CSGBox3D
			var local: Vector3 = wall.global_transform.affine_inverse() * diver.global_position
			var half := wall.size * 0.5
			var segment := maxf(diver.height * 0.5 - diver.radius, 0.0)
			var gap := Vector3(maxf(absf(local.x) - half.x, 0.0),
				maxf(absf(local.y) - half.y - segment, 0.0), maxf(absf(local.z) - half.z, 0.0))
			if gap.length_squared() >= diver.radius * diver.radius:
				continue
			var side := signf(diver.global_position.x - wall.global_position.x)
			if side == 0.0:
				side = signf(_dome_site.x - wall.global_position.x)
			for direction in [side, -side]:
				var preferred := diver.global_position
				preferred.x = wall.global_position.x + direction * (wall.size.z * 0.5 + diver.radius + 0.15)
				var clear: Variant = draft_passages._clear_exit(diver, preferred, wall, Vector3(direction, 0, 0), true)
				if clear != null:
					diver.global_position = clear
					diver.velocity = Vector3.ZERO
					break

func _reconcile_legacy_draft_walls() -> bool:
	# Migrate the exact obsolete swung-11 transform from pre-draft saves (after rebasing).
	if not _walls_10_11_swung:
		return false
	var wall11 := $CSGBox3D11 as CSGBox3D
	var rest14: Array = _walls_14_15_rest[0]
	var old := Vector3((rest14[1] as Vector3).x - (rest14[0] as CSGBox3D).size.x * 0.5 - wall11.size.x * 0.5,
		wall11.global_position.y, (rest14[1] as Vector3).z)
	if wall11.global_position.distance_to(old) < 0.02 and absf(wall11.rotation.y) < 0.01:
		var latest: Array = _walls_10_11_targets()[0]
		wall11.global_position = latest[1]
		wall11.rotation.y = float(latest[2])
		return true
	return false

func _clear_party_from_migrated_draft_wall() -> void:
	# Move divers buried in relocated wall 11 to the nearest hall side.
	var wall := $CSGBox3D11 as CSGBox3D
	var half := wall.size * 0.5
	for diver in divers:
		var local: Vector3 = wall.global_transform.affine_inverse() * diver.global_position
		var segment_half: float = maxf(diver.height * 0.5 - diver.radius, 0.0)
		var gap := Vector3(maxf(absf(local.x) - half.x, 0.0),
			maxf(absf(local.y) - half.y - segment_half, 0.0), maxf(absf(local.z) - half.z, 0.0))
		if gap.length_squared() >= diver.radius * diver.radius:
			continue
		var side := signf(local.z)
		if side == 0.0:
			side = signf(($CSGBox3D10 as CSGBox3D).global_position.z - wall.global_position.z)
		local.z = side * (half.z + diver.radius + 0.12)
		diver.global_position = wall.global_transform * local
		diver.velocity = Vector3.ZERO

# Validates all names before applying anything, so corrupt saves can't fail mid-restore.
func snapshot_matches_runtime(data: Dictionary) -> bool:
	# Must also accept the rebased frame.
	if MazeCoordinateFrame.rebase(data, coordinate_origin).is_empty():
		return false
	for wall_name in data.walls:
		if wall_name not in ["PathWallNorth", "PathWallSouth"] and not get_node_or_null(String(wall_name)) is CSGBox3D:
			return false
	for current in data.currents:
		if not get_node_or_null(String(current.area)) is Area3D:
			return false
	var door_ids: Array = []
	for door in _maze_doors:
		door_ids.append(door.door_id)
	for id in data.doors:
		if not door_ids.has(id):
			return false
	for kind in data.boss_triggers:
		if kind not in ["main_boss", "secret_boss"]:
			return false
	for field in ["walls_14_15", "walls_10_11"]:
		for home in data.rotation_homes[field]:
			if not get_node_or_null(String(home.wall)) is CSGBox3D:
				return false
	var map: Dictionary = data.map
	for wall_name in map.walls:
		if not data.walls.has(wall_name):
			return false
	for corridor_name in map.corridors:
		if not get_node_or_null(String(corridor_name)) is Area3D:
			return false
	for hall in map.halls:
		for wall_name in hall.walls:
			if not data.walls.has(wall_name):
				return false
		if not String(hall.corridor).is_empty() and not get_node_or_null(String(hall.corridor)) is Area3D:
			return false
	return true
