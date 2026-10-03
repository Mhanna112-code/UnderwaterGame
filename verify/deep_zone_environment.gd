# Production environment-asset contract.
#
# Usage: godot --headless --path . --script verify/deep_zone_environment.gd
extends SceneTree

const BEACH_PATH := "res://art/deep_zone/Beach_assets1.fbx"
const BEACH_SHA := "a97a80d3465514e55b9c616034fd5504de780d45d0d42b36a4b2d5d8e8838d05"
const ROCK_MESH_NAMES := ["Rock1", "Rock2", "Rock3", "Rock4", "Rock5", "Rock6"]

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_source_import()
	await _test_production_world()
	for finding in findings:
		print("FINDING  " + finding)
	print("DEEP ZONE ENVIRONMENT: clean" if findings.is_empty() else "DEEP ZONE ENVIRONMENT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _test_source_import() -> void:
	if not ResourceLoader.exists(BEACH_PATH):
		findings.append("DZ-ENV-001: approved Beach asset is absent from the runtime")
		return
	_expect(FileAccess.get_sha256(BEACH_PATH) == BEACH_SHA,
		"DZ-ENV-001: runtime Beach asset is not Glassgoat's approved delivery")
	var packed := load(BEACH_PATH) as PackedScene
	_expect(packed != null, "DZ-ENV-001: Beach FBX did not import as a PackedScene")
	if packed == null:
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	var palm := instance.find_child("Palm_Tree_1", true, false) as MeshInstance3D
	_expect(palm != null and palm.mesh != null and palm.get_active_material(0) != null,
		"DZ-ENV-001: approved palm lost its visible textured mesh")
	if palm != null and palm.mesh != null:
		print("beach palm source bounds  position=%s size=%s" % [palm.get_aabb().position, palm.get_aabb().size])
	_expect(instance.find_child("Sand1", true, false) != null and instance.find_child("Water_1", true, false) != null,
		"DZ-ENV-002: Beach source shape changed; production filtering must be re-audited")
	instance.queue_free()

func _test_production_world() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	await physics_frame
	await physics_frame
	var palms := world.get_tree().get_nodes_in_group("deep_zone_tree").filter(func(node: Node) -> bool:
		return world.is_ancestor_of(node)
	)
	var layout := (load("res://content/deep_zone_layout.gd") as Script)
	_expect(palms.size() >= 3 and palms.size() <= 6,
		"DZ-ENV-003: production route does not own a restrained three-to-six palm composition")
	var transforms: Dictionary = {}
	for palm_value in palms:
		var wrapper := palm_value as Node3D
		var bounds := _visible_bounds(wrapper)
		print("production palm %s  position=%s size=%s" % [wrapper.name, bounds.position, bounds.size])
		_expect(bounds.size.y >= 4.0 and bounds.size.y <= 14.0,
			"DZ-ENV-003: palm is not normalized to a readable world scale")
		_expect(absf(bounds.position.y) <= 0.25,
			"DZ-ENV-003: palm is not floor-aligned")
		_expect(_visible_named_mesh(wrapper, "Palm_Tree_1"),
			"DZ-ENV-001: production palm mesh is not visible")
		_expect(not _visible_named_mesh(wrapper, "Sand1") and not _visible_named_mesh(wrapper, "Water_1"),
			"DZ-ENV-002: bundled sand/water test plane is visible in production")
		var xz := Vector2(wrapper.global_position.x, wrapper.global_position.z)
		var near_entry := xz.distance_to(Vector2(layout.DEEP_ENTRY.x, layout.DEEP_ENTRY.z)) <= 32.0
		var near_hub := xz.distance_to(Vector2(layout.DEEP_HUB.x, layout.DEEP_HUB.z)) <= 32.0
		var near_maze := xz.distance_to(Vector2(layout.MAZE_TRANSITION.x, layout.MAZE_TRANSITION.z)) <= 32.0
		_expect(near_entry or near_hub or near_maze,
			"DZ-ENV-003: palm is hidden away from an authored travel landmark")
		var signature := "%0.2f/%0.2f/%0.2f/%0.2f" % [wrapper.global_position.x, wrapper.global_position.z, wrapper.scale.x, wrapper.rotation.y]
		transforms[signature] = true
	_expect(transforms.size() == palms.size(),
		"DZ-ENV-003: palm placements repeat an identical production transform")
	_test_rock_composition(world)
	_test_route_dressing_coverage(world)
	_test_crystal_presentation(world)
	world.queue_free()
	await process_frame

# DZ-24: varying only the transform of the complete source collection repeats
# the same six-rock mountain silhouette all the way down the route. Observe the
# actual rendered mesh selection on every production instance rather than
# pinning wrapper names or call counts.
func _test_rock_composition(world: World) -> void:
	var environment := world.deep_zone_environment
	_expect(environment != null, "DZ-24: production world has no deep-zone environment")
	if environment == null:
		return
	var compositions: Dictionary = {}
	for mesh_value in _meshes(environment):
		var mesh := mesh_value as MeshInstance3D
		if mesh.name not in ROCK_MESH_NAMES:
			continue
		var source_instance := mesh.get_parent()
		var key := source_instance.get_instance_id()
		if not compositions.has(key):
			compositions[key] = PackedStringArray()
		# Inspect the authored local selection rather than a scene-tree path: the
		# production contract is which imported rock surfaces the player sees.
		if mesh.visible:
			var visible_names := compositions[key] as PackedStringArray
			visible_names.append(mesh.name)
			compositions[key] = visible_names
	_expect(compositions.size() >= 24,
		"DZ-24: deep route lost most of its delivered-rock compositions")
	var signatures: Dictionary = {}
	for names_value in compositions.values():
		var names := names_value as PackedStringArray
		names.sort()
		_expect(names.size() >= 1 and names.size() <= 3,
			"DZ-24: a production placement stamps %d visible rocks instead of composing one-to-three" % names.size())
		signatures["/".join(names)] = true
	_expect(signatures.size() >= 5,
		"DZ-24: deep route exposes fewer than five distinct delivered-rock compositions")

# DZ-24: transformed landmarks alone can pass while leaving long stretches of
# featureless floor. Sample the public visible bounds of floor-level rocks and
# pin continuous dressing along the lab corridor plus a distinct maze branch.
func _test_route_dressing_coverage(world: World) -> void:
	var environment := world.deep_zone_environment
	var visited: Dictionary = {}
	var corridor_xs: Array[float] = []
	var maze_pieces := 0
	for mesh_value in _meshes(environment):
		var mesh := mesh_value as MeshInstance3D
		if mesh.name not in ROCK_MESH_NAMES:
			continue
		var source_instance := mesh.get_parent()
		var key := source_instance.get_instance_id()
		if visited.has(key):
			continue
		visited[key] = true
		var wrapper := source_instance.get_parent() as Node3D
		var bounds := _visible_bounds(wrapper)
		if bounds.size.length() <= 0.01 or bounds.position.y > 0.4:
			continue
		_expect(absf(bounds.position.y) <= 0.08,
			"DZ-24: a visible floor-level rock composition floats or sinks relative to the route floor")
		var center := bounds.get_center()
		if center.z >= -2.0 and center.z <= 34.0 and center.x >= 55.0 and center.x <= 198.0:
			corridor_xs.append(center.x)
		elif center.z < -5.0 and center.x >= 95.0 and center.x <= 132.0:
			maze_pieces += 1
	corridor_xs.sort()
	_expect(corridor_xs.size() >= 20,
		"DZ-24: main deep route lacks enough floor-level large/medium/small rock dressing")
	for index in range(1, corridor_xs.size()):
		_expect(corridor_xs[index] - corridor_xs[index - 1] <= 18.0,
			"DZ-24: main route contains an undressed rock gap wider than 18m")
	_expect(maze_pieces >= 6,
		"DZ-24: maze branch lacks a distinct sequence of floor-level rock dressing")

# DZ-24: a tall low-poly cone in warning orange reads as a temporary traffic
# marker. The production landmark may still be procedural, but each shard must
# have a crystal-like prismatic body and short pointed cap rather than a severe
# full-height cone or a flat-ended glowing rod.
func _test_crystal_presentation(world: World) -> void:
	var clusters := world.get_tree().get_nodes_in_group("deep_zone_crystal_cluster").filter(func(node: Node) -> bool:
		return world.is_ancestor_of(node)
	)
	_expect(clusters.size() >= 5,
		"DZ-24: lab and maze routes lost their crystal landmark clusters")
	for cluster_value in clusters:
		var cluster := cluster_value as Node3D
		var shards := cluster.get_children()
		_expect(shards.size() == 3,
			"DZ-24: a crystal landmark is not a restrained three-shard composition")
		for shard_value in shards:
			var shard := shard_value as Node3D
			var pieces := _meshes(shard)
			_expect(pieces.size() == 2,
				"DZ-24: a landmark shard lacks a distinct prismatic body and pointed cap")
			var has_body := false
			var has_point := false
			for piece in pieces:
				var cylinder := piece.mesh as CylinderMesh
				if cylinder == null:
					continue
				if cylinder.top_radius >= cylinder.bottom_radius * 0.8:
					has_body = true
				if cylinder.top_radius <= cylinder.bottom_radius * 0.05:
					has_point = true
			_expect(has_body and has_point,
				"DZ-24: a landmark shard does not read as a prismatic crystal with a short point")

func _visible_named_mesh(node: Node, wanted: String) -> bool:
	for mesh in _meshes(node):
		if mesh.name == wanted and mesh.is_visible_in_tree() and mesh.mesh != null:
			return true
	return false

func _visible_bounds(node: Node3D) -> AABB:
	var combined := AABB()
	var first := true
	for mesh in _meshes(node):
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		combined = box if first else combined.merge(box)
		first = false
	return combined

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
