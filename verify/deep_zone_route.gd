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

	var active := world.divers[world.active] as Diver
	active.global_position = points.ability_exit
	await physics_frame
	_expect(world.route_state.zone_id == "shallows", "ZONE: ability exit was prematurely classified as deep")
	active.global_position = points.deep_entry
	await physics_frame
	_expect(world.route_state.zone_id == "deep", "ZONE: physically crossing the deep entry did not update RouteState")
	_expect(world.route_state.objective_id == "defeat_bomb_bot", "OBJECTIVE: first deep-zone objective is not the first authored blocker")

	world.queue_free()
	await process_frame
	_finish()

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
