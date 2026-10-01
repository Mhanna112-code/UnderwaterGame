# The delivered Door FBX must stay an actual authored opening asset.  This
# is deliberately an import-level check: a visually similar procedural slide
# is not an acceptable replacement for Glassgoat's shape-key door.
#
# Usage: godot --headless --path . --script verify/key_door_art.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	var packed := load("res://game/Door.fbx") as PackedScene
	if packed == null:
		findings.append("DOOR IMPORT: Door.fbx did not load as a PackedScene")
		_finish()
		return
	var door_root := packed.instantiate()
	root.add_child(door_root)
	var frame := _find_mesh_with_shape(door_root, &"Open")
	if frame == null:
		findings.append("DOOR SHAPE KEY: no imported mesh exposes the authored Open blend shape")
	else:
		var mesh := frame.mesh
		var shape_index := _blend_shape_index(mesh, &"Open")
		var bounds := frame.get_aabb()
		if bounds.size.x <= 0.0001 or bounds.size.y <= 0.0001 or bounds.size.z <= 0.0001:
			findings.append("DOOR BOUNDS: imported Open mesh has degenerate bounds %s" % bounds)
		else:
			var root_scale := (door_root as Node3D).basis.get_scale() if door_root is Node3D else Vector3.ZERO
			print("door art                 mesh %s bounds %s; root basis scale %s" % [frame.name, bounds.size, root_scale])
		if shape_index < 0:
			findings.append("DOOR SHAPE KEY: the Open mesh cannot resolve its own blend-shape index")
		elif not is_zero_approx(frame.get_blend_shape_value(shape_index)):
			findings.append("DOOR REST POSE: authored Open blend shape starts non-zero")
		else:
			frame.set_blend_shape_value(shape_index, 1.0)
			if not is_equal_approx(frame.get_blend_shape_value(shape_index), 1.0):
				findings.append("DOOR SHAPE KEY: Open blend shape cannot be driven to its authored open value")
			else:
				print("door art                 imported Open shape key: 0.0 -> 1.0")
	_finish()

func _find_mesh_with_shape(node: Node, shape_name: StringName) -> MeshInstance3D:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null and _blend_shape_index(mesh_node.mesh, shape_name) >= 0:
			return mesh_node
	for child in node.get_children():
		var found := _find_mesh_with_shape(child, shape_name)
		if found != null:
			return found
	return null

func _blend_shape_index(mesh: Mesh, shape_name: StringName) -> int:
	for i in range(mesh.get_blend_shape_count()):
		if mesh.get_blend_shape_name(i) == shape_name:
			return i
	return -1

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("KEY DOOR ART: clean" if findings.is_empty() else "KEY DOOR ART: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
