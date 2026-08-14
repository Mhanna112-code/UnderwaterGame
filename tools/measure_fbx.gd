# How big is each model once it is actually in the world, and which way is up?
#
# The tree dump's local AABBs are mesh-space and lie about both: these nodes
# carry a scale of 100 and a rotation, so "2cm tall" was neither the size nor
# the axis a designer would place against. This measures the world box.
#
# Usage: godot --headless --path ~/underwatergame --script tools/measure_fbx.gd
extends SceneTree

const PATH := "res://art/characters/Main_Team_Rigging_2.fbx"

var subject: Node3D
var frames := 0

# _initialize + a frame of settle, not _init: global_transform is only valid
# once the node is actually in the tree, and reading it early returns identity
# with an error rather than the transform the importer gave it.
func _initialize() -> void:
	subject = (load(PATH) as PackedScene).instantiate()
	root.add_child(subject)

func _process(_dt: float) -> bool:
	frames += 1
	if frames < 2:
		return false
	var root_node: Node3D = subject
	print("%-22s %-26s %-22s %s" % ["node", "world size (m)", "rotation (deg)", "floor y"])
	for m in _meshes(root_node):
		var box: AABB = _world_aabb(m)
		var rot: Vector3 = (m as Node3D).global_transform.basis.get_euler() * 180.0 / PI
		print("%-22s %-26s %-22s %.3f" % [
			m.name,
			"%.2f x %.2f x %.2f" % [box.size.x, box.size.y, box.size.z],
			"%.0f, %.0f, %.0f" % [rot.x, rot.y, rot.z],
			box.position.y])
	return true

func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

func _world_aabb(m: MeshInstance3D) -> AABB:
	var a: AABB = m.get_aabb()
	var t: Transform3D = m.global_transform
	var out := AABB(t * a.get_endpoint(0), Vector3.ZERO)
	for i in range(8):
		out = out.expand(t * a.get_endpoint(i))
	return out
