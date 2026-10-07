# One of three lit plates past the gap; tracks its occupant and lights up while occupied.
class_name LockPlate
extends Area3D

var occupant: Diver = null
var _mat: StandardMaterial3D

func _ready() -> void:
	# Divers are on layer 2; the default mask only watches layer 1.
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.2
	var mesh := MeshInstance3D.new()
	mesh.name = "PlateSurface"
	mesh.mesh = ring
	# Keep the ring flat on the floor, centered under the trigger.
	mesh.position.y = -1.92
	_mat = StandardMaterial3D.new()
	_mat.emission_enabled = true
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = _mat
	add_child(mesh)
	_refresh_color()

	var shape := CollisionShape3D.new()
	var col := CylinderShape3D.new()
	col.radius = 1.2
	col.height = 2.5
	shape.shape = col
	add_child(shape)

func _on_body_entered(body: Node3D) -> void:
	if body is Diver and occupant == null:
		occupant = body
		_refresh_color()

func _on_body_exited(body: Node3D) -> void:
	if body == occupant:
		occupant = null
		_refresh_color()

func is_occupied() -> bool:
	return occupant != null

func _refresh_color() -> void:
	var c: Color = Color(0.35, 0.95, 0.5) if is_occupied() else Color(0.85, 0.75, 0.2)
	_mat.albedo_color = c
	_mat.emission = c
	_mat.emission_energy_multiplier = 1.5 if is_occupied() else 0.9
