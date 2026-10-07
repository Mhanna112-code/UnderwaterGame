class_name DeepZoneEnvironment
extends Node3D

# Environmental composition for the expanded region; no encounter triggers here.
const ROCKS := preload("res://art/deep_zone/Rocks.fbx")
const BROKEN_OFFICE := preload("res://art/deep_zone/Broken_Office.fbx")
const CORRECTED_DOOR := preload("res://art/deep_zone/Corrected_Door.fbx")
const BEACH_ASSETS := preload("res://art/deep_zone/Beach_assets1.fbx")
const Layout := preload("res://content/deep_zone_layout.gd")
const ROCK_VARIANTS := [
	["Rock1"],
	["Rock2"],
	["Rock3"],
	["Rock4"],
	["Rock5"],
	["Rock6"],
	["Rock1", "Rock4"],
	["Rock2", "Rock5"],
	["Rock3", "Rock6"],
	["Rock1", "Rock3", "Rock5"],
	["Rock2", "Rock4", "Rock6"],
]

var _lab_interior: Node3D
var _lab_door: Node3D
var _lab_door_backing: StaticBody3D
var _lab_exit_cover: Array[Node3D] = []

func _ready() -> void:
	_build_entry_threshold()
	_build_route_scenery()
	_build_palm_landmarks()
	_build_lab_landmark()
	_build_maze_landmark()

func _build_entry_threshold() -> void:
	var landmark := _landmark("entry")
	_add_rocks(landmark, Vector3(60.0, 0.0, 1.5), Vector3(2.1, 3.0, 2.1), 0.35, 9)
	_add_rocks(landmark, Vector3(60.0, 0.0, 18.5), Vector3(2.3, 2.7, 2.3), -0.85, 10)
	_add_glow(landmark, Vector3(60.0, 4.8, 3.5), Color("57e5dc"), 8.5)
	_add_glow(landmark, Vector3(60.0, 4.8, 16.5), Color("57e5dc"), 8.5)

func _build_route_scenery() -> void:
	var scenery := Node3D.new()
	scenery.name = "RouteScenery"
	scenery.add_to_group("deep_zone_scenery")
	add_child(scenery)
	# Reef spine framing the lab approach; the center route stays clear.
	var placements := [
		[Vector3(82.0, 0.0, 5.0), Vector3(1.45, 1.35, 1.45), 0.25, 6],
		[Vector3(87.0, 0.0, 27.0), Vector3(1.65, 1.55, 1.55), -0.45, 7],
		[Vector3(106.0, 0.0, 5.0), Vector3(1.55, 1.65, 1.55), 0.8, 8],
		[Vector3(111.0, 0.0, 29.0), Vector3(1.75, 1.7, 1.65), -0.15, 9],
		[Vector3(133.0, 0.0, 5.0), Vector3(1.55, 1.8, 1.55), 0.55, 10],
		[Vector3(139.0, 0.0, 29.5), Vector3(1.7, 1.65, 1.7), -0.65, 6],
		[Vector3(158.0, 0.0, 5.0), Vector3(1.55, 1.85, 1.55), 0.2, 7],
		[Vector3(161.0, 0.0, 29.0), Vector3(1.8, 1.8, 1.75), -0.9, 8],
	]
	for placement_value in placements:
		var placement := placement_value as Array
		_add_rocks(scenery, placement[0] as Vector3, placement[1] as Vector3, float(placement[2]), int(placement[3]))
	_build_lab_approach_reef(scenery)
	_build_route_rubble(scenery)
	# Low guide lights as wreckage power.
	for x in [86.0, 111.0, 136.0, 159.0]:
		_add_glow(scenery, Vector3(x, 0.75, 7.0), Color("4bb9b5"), 5.5, 0.22)

func _build_lab_approach_reef(parent: Node3D) -> void:
	# Physical corridor matching the visible rock clusters (no invisible gaps); the maze branch stays outside.
	var clusters := [
		[Vector3(98.0, 0.0, 3.0), Vector3(2.4, 3.2, 2.2), 0.22, 9],
		[Vector3(120.0, 0.0, 3.0), Vector3(2.65, 3.5, 2.35), -0.48, 10],
		[Vector3(144.0, 0.0, 3.0), Vector3(2.45, 3.25, 2.45), 0.72, 6],
		[Vector3(168.0, 0.0, 3.0), Vector3(2.8, 3.7, 2.5), -0.18, 8],
		[Vector3(98.0, 0.0, 29.0), Vector3(2.5, 3.25, 2.35), -0.35, 7],
		[Vector3(121.0, 0.0, 29.0), Vector3(2.75, 3.55, 2.3), 0.58, 8],
		[Vector3(145.0, 0.0, 29.0), Vector3(2.4, 3.3, 2.5), -0.82, 9],
		[Vector3(169.0, 0.0, 29.0), Vector3(2.85, 3.65, 2.55), 0.28, 10],
	]
	for cluster_value in clusters:
		var cluster := cluster_value as Array
		_add_rocks(parent, cluster[0] as Vector3, cluster[1] as Vector3, float(cluster[2]), int(cluster[3]))
	# Overhead clusters form a cave throat; visible canopy matches the physical roof.
	_add_rocks(parent, Vector3(116.0, 13.6, 16.0), Vector3(3.4, 2.4, 3.5), 1.08, 10, false)
	_add_rocks(parent, Vector3(142.0, 14.2, 16.0), Vector3(3.7, 2.5, 3.6), -0.72, 9, false)
	_add_rocks(parent, Vector3(168.0, 13.8, 16.0), Vector3(3.5, 2.45, 3.7), 0.54, 8, false)
	# Starts at x=104 to keep the maze route clear; the east end meets the lab shell at x=181.
	_add_reef_wall_body(parent, "NorthApproachReef", Vector3(142.5, 12.0, 3.0), Vector3(77.0, 24.0, 6.0))
	_add_reef_wall_body(parent, "SouthApproachReef", Vector3(142.5, 12.0, 29.0), Vector3(77.0, 24.0, 6.0))
	_add_reef_wall_body(parent, "LabApproachRoof", Vector3(142.5, 19.0, 16.0), Vector3(77.0, 10.0, 20.0))

func _add_reef_wall_body(parent: Node3D, body_name: String, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	body.add_to_group("lab_approach_reef")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)

# Small visual formations between reef walls, kept outside travel bands. No collision.
func _build_route_rubble(parent: Node3D) -> void:
	var rubble := [
		[Vector3(72.0, 0.0, 5.0), Vector3(0.52, 0.38, 0.48), 0.18, 0],
		[Vector3(77.0, 0.0, 24.5), Vector3(0.40, 0.32, 0.46), -0.52, 4],
		[Vector3(91.0, 0.0, 7.0), Vector3(0.58, 0.42, 0.54), 0.76, 2],
		[Vector3(101.0, 0.0, 25.5), Vector3(0.50, 0.36, 0.62), -0.24, 5],
		[Vector3(113.0, 0.0, 7.2), Vector3(0.62, 0.46, 0.52), 1.12, 7],
		[Vector3(127.0, 0.0, 25.2), Vector3(0.48, 0.34, 0.58), -0.88, 1],
		[Vector3(137.0, 0.0, 7.0), Vector3(0.56, 0.38, 0.50), 0.46, 3],
		[Vector3(151.0, 0.0, 25.5), Vector3(0.44, 0.36, 0.55), -0.38, 6],
		[Vector3(163.0, 0.0, 7.0), Vector3(0.58, 0.42, 0.50), 0.92, 5],
		[Vector3(173.0, 0.0, 25.0), Vector3(0.46, 0.32, 0.58), -0.72, 2],
		[Vector3(101.5, 0.0, -8.0), Vector3(0.52, 0.36, 0.48), 0.32, 0],
		[Vector3(107.0, 0.0, -20.0), Vector3(0.62, 0.42, 0.54), -0.48, 4],
		[Vector3(114.5, 0.0, -31.0), Vector3(0.48, 0.34, 0.62), 0.86, 1],
		[Vector3(121.0, 0.0, -43.5), Vector3(0.56, 0.40, 0.52), -0.18, 3],
	]
	for rubble_value in rubble:
		var piece := rubble_value as Array
		_add_rocks(parent, piece[0] as Vector3, piece[1] as Vector3, float(piece[2]), int(piece[3]))

func _build_palm_landmarks() -> void:
	var palms := Node3D.new()
	palms.name = "SunkenPalmLandmarks"
	palms.add_to_group("deep_zone_scenery")
	add_child(palms)
	# Palm silhouette pairs, kept clear of corridors and the lab.
	_add_palm(palms, "EntryPalmNorth", Vector3(72.0, 0.0, 0.0), 0.38, 0.18)
	_add_palm(palms, "EntryPalmSouth", Vector3(82.0, 0.0, 27.0), 0.44, -0.62)
	_add_palm(palms, "HubPalmNorth", Vector3(92.0, 0.0, -4.0), 0.31, 0.72)
	_add_palm(palms, "HubPalmSouth", Vector3(99.0, 0.0, 34.0), 0.34, -0.94)
	_add_palm(palms, "MazePalmOuter", Vector3(101.0, 0.0, -17.0), 0.35, 1.08)
	_add_palm(palms, "MazePalmGate", Vector3(119.0, 0.0, -48.0), 0.41, -0.34)

func _build_lab_landmark() -> void:
	var landmark := _landmark("lab")
	landmark.name = "LabLandmark"
	# Exterior is a door in a rock face; Broken Office stays hidden as the interior staging set.
	var interior := _add_asset(
		landmark, BROKEN_OFFICE, Vector3(194.0, 0.0, 16.0),
		Vector3(0.58, 0.58, 0.58), 0.0
	)
	interior.name = "BrokenOfficeInterior"
	interior.add_to_group("lab_interior")
	interior.visible = false
	_lab_interior = interior

	var door := _add_asset(
		landmark, CORRECTED_DOOR, Vector3(179.0, 0.0, 16.0),
		Vector3.ONE * 1.1, -PI * 0.5
	)
	door.name = "CorrectedLabDoor"
	door.add_to_group("lab_exterior_door")
	_lab_door = door

	# Asymmetric mountain silhouette around the hidden room.
	_add_rocks(landmark, Vector3(184.0, 0.0, 5.5), Vector3(4.4, 4.6, 2.5), 0.32, 9)
	_add_rocks(landmark, Vector3(184.0, 0.0, 26.5), Vector3(4.7, 4.3, 2.6), -0.48, 10)
	_lab_exit_cover.append(_add_rocks(landmark, Vector3(187.0, 7.0, 16.0), Vector3(4.6, 2.5, 3.1), 0.12, 8, false))
	_lab_exit_cover.append(_add_rocks(landmark, Vector3(194.0, 0.0, 16.0), Vector3(5.2, 4.7, 4.5), -0.2, 6))

	# Physical shell: center slab behind the door, side slabs block swimming around.
	_lab_door_backing = _add_lab_shell_body(landmark, "DoorBacking", Vector3(180.5, 4.0, 16.0), Vector3(2.0, 8.0, 6.0))
	_add_lab_shell_body(landmark, "NorthRockMass", Vector3(184.0, 5.0, 7.5), Vector3(8.0, 10.0, 11.0))
	_add_lab_shell_body(landmark, "SouthRockMass", Vector3(184.0, 5.0, 24.5), Vector3(8.0, 10.0, 11.0))

	_add_crystal_cluster(landmark, Vector3(176.5, 0.0, 9.0), Color("a86cff"), 2.3, -0.14)
	_add_crystal_cluster(landmark, Vector3(176.5, 0.0, 23.0), Color("a86cff"), 2.3, 0.14)
	_add_glow(landmark, Vector3(178.0, 3.5, 9.0), Color("8d70ff"), 9.0, 0.32, false)
	_add_glow(landmark, Vector3(178.0, 3.5, 23.0), Color("8d70ff"), 9.0, 0.32, false)

func _build_maze_landmark() -> void:
	var landmark := _landmark("maze")
	landmark.name = "MazeLandmark"
	var center: Vector3 = Layout.MAZE_TRANSITION
	# Flank the east/west approach instead of obstructing the swim lane.
	_add_rocks(landmark, center + Vector3(0.0, 0.0, -6.0), Vector3(1.25, 2.8, 1.25), 0.2, 7)
	_add_rocks(landmark, center + Vector3(0.0, 0.0, 6.0), Vector3(1.25, 2.7, 1.25), -0.55, 8)
	_add_rocks(landmark, center + Vector3(0.0, 7.0, 0.0), Vector3(1.75, 0.72, 1.0), 0.0, 9, false)
	_add_crystal_cluster(landmark, center + Vector3(0.0, 0.0, -4.6), Color("718cff"), 2.6, -0.18)
	_add_crystal_cluster(landmark, center + Vector3(0.0, 0.0, 4.6), Color("718cff"), 2.6, 0.18)
	_add_glow(landmark, center + Vector3(0.0, 3.8, -5.0), Color("718cff"), 9.0, 0.32, false)
	_add_glow(landmark, center + Vector3(0.0, 3.8, 5.0), Color("718cff"), 9.0, 0.32, false)

func _landmark(id: String) -> Node3D:
	var landmark := Node3D.new()
	landmark.name = "%sLandmark" % id.capitalize()
	landmark.add_to_group("deep_zone_landmark")
	landmark.set_meta("route_landmark_id", id)
	add_child(landmark)
	return landmark

func _add_rocks(parent: Node3D, position: Vector3, asset_scale: Vector3, yaw: float, variant: int, floor_align: bool = true) -> Node3D:
	var names := ROCK_VARIANTS[wrapi(variant, 0, ROCK_VARIANTS.size())] as Array
	return _add_asset(parent, ROCKS, position, asset_scale, yaw, floor_align, names)

func _add_asset(parent: Node3D, packed: PackedScene, position: Vector3, asset_scale: Vector3, yaw: float, floor_align: bool = true, visible_mesh_names: Array = []) -> Node3D:
	var wrapper := Node3D.new()
	parent.add_child(wrapper)
	var instance := packed.instantiate() as Node3D
	wrapper.add_child(instance)
	if not visible_mesh_names.is_empty():
		for mesh_value in _meshes(instance):
			var selected_mesh := mesh_value as MeshInstance3D
			selected_mesh.visible = selected_mesh.name in visible_mesh_names
	if packed == BROKEN_OFFICE:
		_tint_materials(instance, Color(0.38, 0.48, 0.54, 1.0))
	wrapper.scale = asset_scale
	wrapper.rotation.y = yaw
	wrapper.position = position
	var bounds := _visible_bounds(wrapper)
	if floor_align and bounds.size.length() > 0.01:
		wrapper.position.y -= bounds.position.y
	return wrapper

func _add_lab_shell_body(parent: Node3D, body_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	body.add_to_group("lab_rock_shell")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)
	return body

# Exterior stays opaque; during the scene and battle only the door and its backing collider open.
func set_lab_phase(phase: String) -> void:
	var opened := phase in ["cutscene", "boss", "cleared"]
	# Exit-covering visual clusters are removed only after victory.
	for cover in _lab_exit_cover:
		cover.visible = phase != "cleared"
	if is_instance_valid(_lab_door):
		_lab_door.visible = not opened
	if is_instance_valid(_lab_interior):
		_lab_interior.visible = phase in ["boss", "cleared"]
	if is_instance_valid(_lab_door_backing):
		_lab_door_backing.process_mode = Node.PROCESS_MODE_DISABLED if opened else Node.PROCESS_MODE_INHERIT
		for child in _lab_door_backing.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred("disabled", opened)

func _add_palm(parent: Node3D, palm_name: String, position: Vector3, palm_scale: float, yaw: float) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.name = palm_name
	wrapper.add_to_group("deep_zone_tree")
	parent.add_child(wrapper)
	var instance := BEACH_ASSETS.instantiate() as Node3D
	wrapper.add_child(instance)
	# Use only the approved tree, not the delivery's sand/water planes.
	for mesh_value in _meshes(instance):
		var mesh := mesh_value as MeshInstance3D
		mesh.visible = mesh.name == "Palm_Tree_1"
	wrapper.scale = Vector3.ONE * palm_scale
	wrapper.rotation.y = yaw
	wrapper.position = position
	wrapper.force_update_transform()
	var bounds := _visible_bounds(wrapper)
	if bounds.size.length() > 0.01:
		wrapper.position.y -= bounds.position.y
		wrapper.force_update_transform()
	return wrapper

func _add_glow(parent: Node3D, position: Vector3, color: Color, light_range: float, radius: float = 0.32, show_marker: bool = true) -> void:
	var marker := MeshInstance3D.new()
	marker.position = position
	marker.visible = show_marker
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	marker.material_override = material
	parent.add_child(marker)
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = light_range
	light.shadow_enabled = false
	parent.add_child(light)

func _add_crystal_cluster(parent: Node3D, position: Vector3, color: Color, height: float, tilt: float) -> void:
	var cluster := Node3D.new()
	cluster.name = "CrystalCluster"
	cluster.position = position
	cluster.rotation.y = tilt * 2.0
	cluster.add_to_group("deep_zone_crystal_cluster")
	parent.add_child(cluster)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.18
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.85
	var shards := [
		[Vector3(0.0, 0.0, 0.0), height * 0.92, 0.24, tilt],
		[Vector3(-0.42, 0.0, 0.12), height * 0.64, 0.18, tilt - 0.22],
		[Vector3(0.38, 0.0, -0.16), height * 0.54, 0.16, tilt + 0.26],
	]
	for shard_value in shards:
		var shard := shard_value as Array
		var shard_root := Node3D.new()
		shard_root.name = "CrystalShard"
		shard_root.position = shard[0] as Vector3
		shard_root.rotation.z = float(shard[3])
		cluster.add_child(shard_root)
		var shard_height := float(shard[1])
		var radius := float(shard[2])
		var body_height := shard_height * 0.68
		var cap_height := shard_height - body_height
		var body := MeshInstance3D.new()
		body.name = "PrismaticBody"
		body.position.y = body_height * 0.5
		var body_mesh := CylinderMesh.new()
		body_mesh.top_radius = radius * 0.92
		body_mesh.bottom_radius = radius
		body_mesh.height = body_height
		body_mesh.radial_segments = 6
		body_mesh.rings = 1
		body.mesh = body_mesh
		body.material_override = material
		shard_root.add_child(body)
		var cap := MeshInstance3D.new()
		cap.name = "PointedCap"
		cap.position.y = body_height + cap_height * 0.5
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.0
		cap_mesh.bottom_radius = radius * 0.92
		cap_mesh.height = cap_height
		cap_mesh.radial_segments = 6
		cap_mesh.rings = 1
		cap.mesh = cap_mesh
		cap.material_override = material
		shard_root.add_child(cap)

func _tint_materials(node: Node, tint: Color) -> void:
	for mesh_value in _meshes(node):
		var mesh := mesh_value as MeshInstance3D
		if mesh.mesh == null or not mesh.visible:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.albedo_color *= tint
			mesh.set_surface_override_material(surface, material)

func _visible_bounds(node: Node) -> AABB:
	var combined := AABB()
	var first := true
	for mesh_value in _meshes(node):
		var mesh := mesh_value as MeshInstance3D
		if mesh.mesh == null or not mesh.visible:
			continue
		var bounds := mesh.global_transform * mesh.get_aabb()
		combined = bounds if first else combined.merge(bounds)
		first = false
	return combined

func _meshes(node: Node) -> Array:
	var found: Array = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found
