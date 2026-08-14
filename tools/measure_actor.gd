# How big is each character once it is standing on the stage, and does it
# have textures? A clay bake and a textured model look identical in a file
# listing and nothing alike on screen.
extends SceneTree
var frames := 0
var subject: Node3D
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	subject = (load(String(a[0])) as PackedScene).instantiate()
	root.add_child(subject)
func _process(_d: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	for m in _meshes(subject):
		var mi := m as MeshInstance3D
		var box: AABB = _aabb(mi)
		var tex := "no texture"
		var mesh: Mesh = mi.mesh
		if mesh != null and mesh.get_surface_count() > 0:
			var mat: Material = mi.get_active_material(0)
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
				tex = "textured"
		print("%-22s %.2f x %.2f x %.2f m   %s" % [mi.name, box.size.x, box.size.y, box.size.z, tex])
	return true
func _meshes(n: Node) -> Array:
	var o: Array = []
	if n is MeshInstance3D: o.append(n)
	for c in n.get_children(): o.append_array(_meshes(c))
	return o
func _aabb(m: MeshInstance3D) -> AABB:
	var a: AABB = m.get_aabb()
	var t: Transform3D = m.global_transform
	var out := AABB(t * a.get_endpoint(0), Vector3.ZERO)
	for i in range(8): out = out.expand(t * a.get_endpoint(i))
	return out
