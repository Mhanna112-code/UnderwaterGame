# One-shot intake diagnostic for Glassgoat's composite Cordys FBX.
# Usage: godot --headless --path . --script tools/inspect_octopus_structure.gd
extends SceneTree

const SOURCE := "res://art/deep_zone/Octopus_Boss.fbx"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(SOURCE) as PackedScene
	if packed == null:
		push_error("Could not load %s" % SOURCE)
		quit(1)
		return
	var actor := packed.instantiate()
	root.add_child(actor)
	await process_frame
	_print_tree(actor, actor)
	actor.queue_free()
	await process_frame
	quit()

func _print_tree(node: Node, root_node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		print("MESH %s aabb=%s surfaces=%d skeleton=%s" % [
			root_node.get_path_to(node), mesh_instance.get_aabb(), mesh.get_surface_count(),
			mesh_instance.skeleton])
		for surface in range(mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface)
			var arrays := mesh.surface_get_arrays(surface)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var surface_bounds := _bounds(vertices)
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			print("  SURFACE %d primitive=%s arrays=%s material=%s" % [surface,
				mesh.surface_get_primitive_type(surface),
				mesh.surface_get_array_len(surface),
				material.resource_name if material != null else "none"])
			print("    bounds=%s vertices=%d indices=%d longest_edges=%s" % [
				surface_bounds, vertices.size(), indices.size(), _longest_edges(vertices, indices)])
	for child in node.get_children():
		_print_tree(child, root_node)

func _bounds(vertices: PackedVector3Array) -> AABB:
	if vertices.is_empty():
		return AABB()
	var out := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices:
		out = out.expand(vertex)
	return out

func _longest_edges(vertices: PackedVector3Array, indices: PackedInt32Array) -> Array[float]:
	var lengths: Array[float] = []
	if indices.is_empty():
		for index in range(0, vertices.size() - 2, 3):
			_append_triangle_edges(lengths, vertices[index], vertices[index + 1], vertices[index + 2])
	else:
		for index in range(0, indices.size() - 2, 3):
			_append_triangle_edges(lengths, vertices[indices[index]], vertices[indices[index + 1]], vertices[indices[index + 2]])
	lengths.sort()
	var out: Array[float] = []
	for index in range(maxi(0, lengths.size() - 8), lengths.size()):
		out.append(lengths[index])
	return out

func _append_triangle_edges(out: Array[float], a: Vector3, b: Vector3, c: Vector3) -> void:
	out.append(a.distance_to(b))
	out.append(b.distance_to(c))
	out.append(c.distance_to(a))
