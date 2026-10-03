# Concealed laboratory exterior contract.
#
# Usage: godot --headless --path . --script verify/lab_exterior.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var layout_script := load("res://content/deep_zone_layout.gd")
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	await physics_frame
	await physics_frame

	var lab_position: Vector3 = layout_script.LAB
	var doors := _owned_group(world, "lab_exterior_door")
	var shells := _owned_group(world, "lab_rock_shell")
	var interiors := _owned_group(world, "lab_interior")
	_expect(doors.size() == 1,
		"LAB-EXT-002: production exterior does not own exactly one corrected lab door")
	_expect(shells.size() >= 3,
		"LAB-EXT-001: production exterior has no enclosing rock shell")
	_expect(interiors.size() == 1 and not (interiors[0] as Node3D).visible,
		"LAB-EXT-001: Broken Office interior remains rendered from the exterior world")
	if doors.size() == 1:
		var door := doors[0] as Node3D
		var door_bounds := _visible_bounds(door)
		print("lab door bounds  position=%s size=%s" % [door_bounds.position, door_bounds.size])
		_expect(door_bounds.size.y >= 5.0 and door_bounds.size.y <= 11.0
			and door_bounds.size.z >= 3.0 and door_bounds.size.z <= 9.0,
			"LAB-EXT-005: corrected door is not normalized to a readable diver-scale entrance")
		_expect(Vector2(door.global_position.x, door.global_position.z).distance_to(Vector2(lab_position.x, lab_position.z)) <= 6.0,
			"LAB-EXT-004: corrected door is not at the reachable lab objective")

	var approach := lab_position + Vector3(-16.0, 2.5, 0.0)
	for offset in [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.8, -6.5), Vector3(0.0, 1.8, 6.5)]:
		var target: Vector3 = lab_position + Vector3(18.0, 2.5, 0.0) + offset
		var query := PhysicsRayQueryParameters3D.create(approach + offset, target)
		query.collide_with_areas = false
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		_expect(not hit.is_empty() and (hit.collider as Node).is_in_group("lab_rock_shell"),
			"LAB-EXT-003: exterior sight/travel ray bypassed the physical door-and-rock shell at offset %s" % offset)

	# A diver-sized player must still reach the declared interaction point in
	# front of the door. The shell begins beyond this point.
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	for x in range(int(lab_position.x - 12.0), int(lab_position.x) + 1):
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY, Vector3(float(x), 2.0, lab_position.z))
		query.collide_with_areas = false
		var hits := world.get_world_3d().direct_space_state.intersect_shape(query, 8)
		var blocked := hits.any(func(hit: Dictionary) -> bool:
			var collider := hit.get("collider") as Node
			return collider != null and collider.is_in_group("lab_rock_shell")
		)
		_expect(not blocked,
			"LAB-EXT-004: rock shell blocks the normal route before the lab interaction point near x=%d" % x)

	world.queue_free()
	await process_frame
	_finish()

func _owned_group(world: World, group: String) -> Array[Node]:
	return world.get_tree().get_nodes_in_group(group).filter(func(node: Node) -> bool:
		return world.is_ancestor_of(node)
	)

func _visible_bounds(node: Node3D) -> AABB:
	var combined := AABB()
	var first := true
	for mesh in _meshes(node):
		if not mesh.visible or mesh.mesh == null:
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

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("LAB EXTERIOR: clean" if findings.is_empty() else "LAB EXTERIOR: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
