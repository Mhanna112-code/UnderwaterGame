# Sliding door panel blocking one lock-plate lane until open() is called.
class_name Door
extends StaticBody3D

# x = thickness, y = height, z = lane width; blocks travel along +x.
@export var span := Vector3(0.4, 6.0, 2.3)

var _shape: CollisionShape3D
var _opened := false
func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := find_mesh_instance(child)
		if found:
			return found
	return null

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = span
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.4, 0.46)
	mat.metallic = 0.6
	mat.roughness = 0.3
	mesh.material_override = mat
	add_child(mesh)
	var door_scene := preload("res://game/Door.fbx")
	var door_instance := door_scene.instantiate()
	add_child(door_instance)
	var mesh_instance := find_mesh_instance(door_instance)
	print(mesh_instance.get_aabb().size)
	_shape = CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = span
	_shape.shape = col
	add_child(_shape)

# Collision drops immediately; the slide is cosmetic.
func open() -> void:
	if _opened:
		return
	_opened = true
	_shape.disabled = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + span.y, 1.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
