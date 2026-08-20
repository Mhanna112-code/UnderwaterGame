# A small glowing pickup: what a shockwaved rock actually leaves behind now
# (see cracked_wall.gd's `broken` signal and world.gd's break handler)
# instead of the old instant-heal-on-break. Same trigger shape as
# lock_plate.gd - an Area3D on collision layer 2 (divers), body_entered
# does the whole job.
#
# Doesn't apply its own item - that's Items.grant()'s job, called by
# whoever's listening to `collected` (world.gd). This just represents "an
# item is sitting here" and disappears the instant something picks it up.
class_name ItemOrb
extends Area3D

signal collected(item_id: String, diver: Diver)

@export var item_id := ""

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _bob_t := 0.0

func _ready() -> void:
	collision_mask = 2

	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	# Key items never drop from a rock (see Items.RANDOM_DROP_TABLE) - orbs
	# only ever carry a consumable, so there's no "key item" color case to
	# handle here at all, unlike Items.grant()'s match.
	var c := Color(0.95, 0.85, 0.3) if item_id == "potion" else Color(0.4, 0.85, 0.95)
	_mat.albedo_color = c
	_mat.emission = c
	_mat.emission_energy_multiplier = 1.4
	_mesh.material_override = _mat
	add_child(_mesh)

	var shape := CollisionShape3D.new()
	var col := SphereShape3D.new()
	col.radius = 0.5
	shape.shape = col
	add_child(shape)

	body_entered.connect(_on_body_entered)

# Bob and spin in place so a pop of orbs scattered across the seabed reads
# as "things you can grab," not just more scenery - same "make the
# interactive object visually distinct" instinct cracked_wall.gd's header
# comment already calls out for the rocks themselves.
func _process(dt: float) -> void:
	_bob_t += dt
	_mesh.position.y = sin(_bob_t * 2.4) * 0.12
	_mesh.rotate_y(dt * 1.6)

func _on_body_entered(body: Node3D) -> void:
	if body is Diver:
		collected.emit(item_id, body)
		queue_free()
