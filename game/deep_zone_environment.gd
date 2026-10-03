class_name DeepZoneEnvironment
extends Node3D

# Production composition for the expanded region. These are environmental
# silhouettes, not encounter triggers: ordinary enemies remain random and the
# authored blockers are added by their own lifecycle owner later.
const ROCKS := preload("res://art/deep_zone/Rocks.fbx")
const BROKEN_OFFICE := preload("res://art/deep_zone/Broken_Office.fbx")
const Layout := preload("res://content/deep_zone_layout.gd")

func _ready() -> void:
	_build_entry_threshold()
	_build_route_scenery()
	_build_lab_landmark()
	_build_maze_landmark()

func _build_entry_threshold() -> void:
	var landmark := _landmark("entry")
	_add_asset(landmark, ROCKS, Vector3(60.0, 0.0, 1.5), Vector3(2.1, 3.0, 2.1), 0.35)
	_add_asset(landmark, ROCKS, Vector3(60.0, 0.0, 18.5), Vector3(2.3, 2.7, 2.3), -0.85)
	_add_glow(landmark, Vector3(60.0, 4.8, 3.5), Color("57e5dc"), 8.5)
	_add_glow(landmark, Vector3(60.0, 4.8, 16.5), Color("57e5dc"), 8.5)

func _build_route_scenery() -> void:
	var scenery := Node3D.new()
	scenery.name = "RouteScenery"
	scenery.add_to_group("deep_zone_scenery")
	add_child(scenery)
	# A broad, uneven reef spine frames the laboratory approach while keeping
	# the declared center route clear for three diver-sized bodies.
	var placements := [
		[Vector3(82.0, 0.0, 5.0), Vector3(1.45, 1.35, 1.45), 0.25],
		[Vector3(87.0, 0.0, 27.0), Vector3(1.65, 1.55, 1.55), -0.45],
		[Vector3(106.0, 0.0, 5.0), Vector3(1.55, 1.65, 1.55), 0.8],
		[Vector3(111.0, 0.0, 29.0), Vector3(1.75, 1.7, 1.65), -0.15],
		[Vector3(133.0, 0.0, 5.0), Vector3(1.55, 1.8, 1.55), 0.55],
		[Vector3(139.0, 0.0, 29.5), Vector3(1.7, 1.65, 1.7), -0.65],
		[Vector3(158.0, 0.0, 5.0), Vector3(1.55, 1.85, 1.55), 0.2],
		[Vector3(161.0, 0.0, 29.0), Vector3(1.8, 1.8, 1.75), -0.9],
	]
	for placement_value in placements:
		var placement := placement_value as Array
		_add_asset(scenery, ROCKS, placement[0] as Vector3, placement[1] as Vector3, float(placement[2]))
	# Low guide lights read as authored wreckage power rather than a floating
	# debug ring or an ordinary enemy used as a waypoint.
	for x in [86.0, 111.0, 136.0, 159.0]:
		_add_glow(scenery, Vector3(x, 0.75, 7.0), Color("4bb9b5"), 5.5, 0.22)

func _build_lab_landmark() -> void:
	var landmark := _landmark("lab")
	landmark.name = "LabLandmark"
	# LAB is the encounter threshold in front of the building; the room sits
	# farther east so its facade fills the approach without swallowing the
	# blocker trigger itself.
	_add_asset(landmark, BROKEN_OFFICE, Vector3(182.0, 0.0, 16.0), Vector3(0.8, 0.8, 0.8), 0.0)
	_add_asset(landmark, ROCKS, Vector3(177.0, 0.0, 4.0), Vector3(2.6, 2.8, 2.4), 0.45)
	_add_asset(landmark, ROCKS, Vector3(177.0, 0.0, 28.0), Vector3(2.6, 2.6, 2.4), -0.45)
	_add_crystal(landmark, Vector3(174.5, 2.2, 8.0), Color("ff785c"), 3.6, -0.14)
	_add_crystal(landmark, Vector3(174.5, 2.2, 24.0), Color("ff785c"), 3.6, 0.14)
	_add_glow(landmark, Vector3(176.0, 3.5, 7.0), Color("ff785c"), 9.0)
	_add_glow(landmark, Vector3(176.0, 3.5, 25.0), Color("ff785c"), 9.0)

func _build_maze_landmark() -> void:
	var landmark := _landmark("maze")
	landmark.name = "MazeLandmark"
	var center: Vector3 = Layout.MAZE_TRANSITION
	_add_asset(landmark, ROCKS, center + Vector3(-6.0, 0.0, 0.0), Vector3(1.25, 2.8, 1.25), 0.2)
	_add_asset(landmark, ROCKS, center + Vector3(6.0, 0.0, 0.0), Vector3(1.25, 2.7, 1.25), -0.55)
	_add_asset(landmark, ROCKS, center + Vector3(0.0, 7.0, 2.0), Vector3(1.75, 0.72, 1.0), PI * 0.5, false)
	_add_crystal(landmark, center + Vector3(-4.6, 2.7, -0.5), Color("718cff"), 4.8, -0.18)
	_add_crystal(landmark, center + Vector3(4.6, 2.7, -0.5), Color("718cff"), 4.8, 0.18)
	_add_crystal(landmark, center + Vector3(0.0, 1.7, 2.5), Color("9daeff"), 2.8, 0.0)
	_add_glow(landmark, center + Vector3(-5.0, 3.8, 0.0), Color("718cff"), 9.0)
	_add_glow(landmark, center + Vector3(5.0, 3.8, 0.0), Color("718cff"), 9.0)

func _landmark(id: String) -> Node3D:
	var landmark := Node3D.new()
	landmark.name = "%sLandmark" % id.capitalize()
	landmark.add_to_group("deep_zone_landmark")
	landmark.set_meta("route_landmark_id", id)
	add_child(landmark)
	return landmark

func _add_asset(parent: Node3D, packed: PackedScene, position: Vector3, asset_scale: Vector3, yaw: float, floor_align: bool = true) -> Node3D:
	var wrapper := Node3D.new()
	parent.add_child(wrapper)
	var instance := packed.instantiate() as Node3D
	wrapper.add_child(instance)
	if packed == BROKEN_OFFICE:
		_tint_materials(instance, Color(0.38, 0.48, 0.54, 1.0))
	wrapper.scale = asset_scale
	wrapper.rotation.y = yaw
	wrapper.position = position
	var bounds := _visible_bounds(wrapper)
	if floor_align and bounds.size.length() > 0.01:
		wrapper.position.y -= bounds.position.y
	return wrapper

func _add_glow(parent: Node3D, position: Vector3, color: Color, light_range: float, radius: float = 0.32) -> void:
	var marker := MeshInstance3D.new()
	marker.position = position
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

func _add_crystal(parent: Node3D, position: Vector3, color: Color, height: float, tilt: float) -> void:
	var crystal := MeshInstance3D.new()
	crystal.position = position
	crystal.rotation.z = tilt
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.62
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	crystal.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.18
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.35
	crystal.material_override = material
	parent.add_child(crystal)

func _tint_materials(node: Node, tint: Color) -> void:
	for mesh_value in _meshes(node):
		var mesh := mesh_value as MeshInstance3D
		if mesh.mesh == null:
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
		if mesh.mesh == null:
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
