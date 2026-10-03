# Physical deep-zone shell and public zone-state contract.
#
# Usage: godot --headless --path . --script verify/deep_zone_route.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var layout_script := load("res://content/deep_zone_layout.gd")
	if layout_script == null:
		findings.append("LAYOUT: content/deep_zone_layout.gd does not exist")
		_finish()
		return
	var layout = layout_script.new()
	var points: Dictionary = layout.route_points()
	for id in ["ability_exit", "deep_entry", "bomb_bot", "sword_slayer", "lab", "maze_transition"]:
		if not points.has(id):
			findings.append("LAYOUT: missing route point %s" % id)
	if not findings.is_empty():
		_finish()
		return

	_expect((points.bomb_bot as Vector3).distance_to(points.sword_slayer as Vector3) >= 16.0, "SPACING: blocker fights are compressed together")
	_expect((points.sword_slayer as Vector3).distance_to(points.lab as Vector3) >= 16.0, "SPACING: Sword Slayer and lab are compressed together")
	_expect(absf((points.maze_transition as Vector3).z - (points.lab as Vector3).z) >= 28.0, "BRANCHING: maze transition is not spatially separate from the lab route")
	if not layout.has_method("allows_random_encounter"):
		findings.append("ENCOUNTER POLICY: shared deep-zone layout has no random/protected-area decision")
	else:
		for protected_id in ["ability_exit", "deep_entry", "bomb_bot", "sword_slayer", "lab", "maze_transition"]:
			_expect(not bool(layout.allows_random_encounter(points[protected_id] as Vector3)), "ENCOUNTER POLICY: %s allows a random fight" % protected_id)
		_expect(bool(layout.allows_random_encounter(Vector3(98.0, 2.0, 45.0))), "ENCOUNTER POLICY: open deep water suppresses ordinary random fights")

	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	await physics_frame
	await physics_frame

	var shallow_floor := world.get_node_or_null("ShallowsFloorBody/ShallowsFloor") as MeshInstance3D
	var deep_floor := world.get_node_or_null("DeepZoneFloorBody/DeepZoneFloor") as MeshInstance3D
	if shallow_floor == null or deep_floor == null:
		findings.append("SURFACE: named shallow/deep production floors are absent")
	else:
		var shallow_material := shallow_floor.material_override as StandardMaterial3D
		var deep_material := deep_floor.material_override as StandardMaterial3D
		if shallow_material == null or deep_material == null:
			findings.append("SURFACE: shallow/deep material comparison is unavailable")
		else:
			_expect(deep_material.albedo_color.get_luminance() < shallow_material.albedo_color.get_luminance() * 0.72, "TREATMENT: deep floor is not materially darker than the shallows")

	var exclude: Array[RID] = []
	for diver_value in world.divers:
		exclude.append((diver_value as CollisionObject3D).get_rid())
	for id in points:
		_expect(_has_floor(world, points[id] as Vector3, exclude), "FLOOR: %s has no physical floor support" % id)

	await _expect_path_clear(world, layout.lab_route(), exclude, "LAB ROUTE")
	await _expect_path_clear(world, layout.maze_route(), exclude, "MAZE ROUTE")
	_expect_landmarks(world)

	var active := world.divers[world.active] as Diver
	active.global_position = points.ability_exit
	await physics_frame
	_expect(world.route_state.zone_id == "shallows", "ZONE: ability exit was prematurely classified as deep")
	active.global_position = points.deep_entry
	await physics_frame
	_expect(world.route_state.zone_id == "deep", "ZONE: physically crossing the deep entry did not update RouteState")
	_expect(world.route_state.objective_id == "defeat_bomb_bot", "OBJECTIVE: first deep-zone objective is not the first authored blocker")
	var objective_labels := world.get_tree().get_nodes_in_group("route_objective_hud")
	if objective_labels.size() != 1:
		findings.append("OBJECTIVE HUD: deep objective has no single player-visible owner")
	else:
		var objective_label := objective_labels[0] as Label
		_expect(objective_label != null and objective_label.visible and objective_label.text.contains("Bomb Bot"), "OBJECTIVE HUD: entering Deep does not visibly name the next blocker")
	if layout.has_method("allows_random_encounter"):
		active.global_position = points.bomb_bot
		world._on_encounter_triggered(active)
		await process_frame
		_expect(not world.battling, "ENCOUNTER POLICY: production World started a random fight on Bomb Bot's authored site")
		active.global_position = Vector3(98.0, 2.0, 45.0)
		world._on_encounter_triggered(active)
		await process_frame
		_expect(world.battling, "ENCOUNTER POLICY: production World cannot start a random fight in open deep water")

	world.queue_free()
	await process_frame
	_finish()

func _expect_landmarks(world: World) -> void:
	var observed: Dictionary = {}
	for node_value in world.get_tree().get_nodes_in_group("deep_zone_landmark"):
		var node := node_value as Node3D
		if node == null or not world.is_ancestor_of(node):
			continue
		var landmark_id := String(node.get_meta("route_landmark_id", ""))
		if landmark_id != "":
			observed[landmark_id] = _visible_bounds(node)
	for required in ["entry", "lab", "maze"]:
		if not observed.has(required):
			findings.append("LANDMARK: production World has no visible %s landmark" % required)
			continue
		var bounds := observed[required] as AABB
		_expect(bounds.size.length() > 1.0, "LANDMARK: %s has no renderable bounds" % required)
	if observed.has("lab"):
		var lab_bounds := observed.lab as AABB
		_expect(lab_bounds.size.x >= 10.0 and lab_bounds.size.y >= 6.0, "LANDMARK: laboratory silhouette is too small to read from its approach")
	if observed.has("maze"):
		_expect((observed.maze as AABB).size.y >= 4.0, "LANDMARK: maze transition has no readable vertical silhouette")

func _visible_bounds(node: Node3D) -> AABB:
	var combined := AABB()
	var first := true
	for mesh_value in _meshes(node):
		var mesh := mesh_value as MeshInstance3D
		if not mesh.visible or mesh.mesh == null:
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

func _has_floor(world: World, point: Vector3, exclude: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8.0, point + Vector3.DOWN * 4.0)
	query.exclude = exclude
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and float((hit.position as Vector3).y) <= 0.5

func _expect_path_clear(world: World, route: PackedVector3Array, exclude: Array[RID], label: String) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	for index in range(route.size() - 1):
		var a := route[index]
		var b := route[index + 1]
		var count := maxi(1, int(ceil(a.distance_to(b) / 1.5)))
		for step in range(count + 1):
			var point := a.lerp(b, float(step) / float(count))
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform = Transform3D(Basis.IDENTITY, point)
			query.exclude = exclude
			query.collide_with_areas = false
			var hits := world.get_world_3d().direct_space_state.intersect_shape(query, 8)
			if not hits.is_empty():
				findings.append("%s: diver-sized path blocked near %s" % [label, point])
				return
		await physics_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("DEEP ZONE ROUTE: clean" if findings.is_empty() else "DEEP ZONE ROUTE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
