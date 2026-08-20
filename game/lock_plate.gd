# One of the three lit positions past the gap. Tracks its own occupant -
# doesn't know about the other two plates or what "solved" means, that's
# world.gd's job (it polls is_occupied() on all three each frame). Lights
# up while occupied so standing on the right spot is visually obvious.
class_name LockPlate
extends Area3D

var occupant: Diver = null
var _mat: StandardMaterial3D

func _ready() -> void:
	# Divers sit on collision layer 2 (see diver.gd - they don't collide
	# with each other, only the environment on layer 1). An Area3D's
	# default collision_mask only watches layer 1, so without this a
	# plate would never notice a diver standing on it.
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.2
	var mesh := MeshInstance3D.new()
	mesh.mesh = ring
	mesh.rotation_degrees.x = 90.0
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
