# A rest spot: standing on one is what makes SavePointMenu reachable at
# all (see world.gd's _update_save_point_prompt/_toggle_save_menu) - spell
# learning/equipping isn't available anywhere else, on purpose. Tracks
# occupants as a list rather than one like LockPlate does, since divers
# don't collide with each other (layer 2, see diver.gd) and could in
# principle overlap here - has_diver() just needs to answer "is this
# particular diver currently in range," not "who got here first."
class_name SavePoint
extends Area3D

var occupants: Array[Diver] = []
var _mat: StandardMaterial3D

func _ready() -> void:
	# Same reason every other Area3D in this project sets this - divers
	# are on collision layer 2, and Area3D's default mask only watches
	# layer 1 (see lock_plate.gd/whirlpool.gd for the identical fix).
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.9, 2.0, 0.9)
	var mesh := MeshInstance3D.new()
	mesh.mesh = crystal
	mesh.position.y = 1.0
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.3, 0.75, 0.95)
	_mat.emission_enabled = true
	_mat.emission = Color(0.3, 0.75, 0.95)
	_mat.emission_energy_multiplier = 1.4
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = _mat
	add_child(mesh)

	var ring := TorusMesh.new()
	ring.inner_radius = 1.1
	ring.outer_radius = 1.4
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.mesh = ring
	ring_mesh.rotation_degrees.x = 90.0
	ring_mesh.position.y = 0.05
	ring_mesh.material_override = _mat
	add_child(ring_mesh)

	var shape := CollisionShape3D.new()
	var col := CylinderShape3D.new()
	col.radius = 1.6
	col.height = 3.0
	shape.shape = col
	add_child(shape)

	var tw := create_tween().set_loops()
	tw.tween_property(mesh, "rotation:y", TAU, 6.0).from(0.0)

func _on_body_entered(body: Node3D) -> void:
	if body is Diver and not occupants.has(body):
		occupants.append(body)

func _on_body_exited(body: Node3D) -> void:
	occupants.erase(body)

func has_diver(d: Diver) -> bool:
	return occupants.has(d)
