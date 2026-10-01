# One sliding door panel in front of a single lock plate lane (see
# world.gd's _build_highway) - blocks that lane solid until open() is
# called, which world.gd's _check_gap_puzzle only does once all three
# plates are occupied at once, all three doors together. Doesn't know
# about LockPlate or the puzzle at all, just "solid until told to open" -
# same arm's-length shape as CrackedWall/GrappleAnchor.
class_name Door
extends StaticBody3D

# x = thickness (thin, like a real door), y = height, z = width across
# one lane slice - oriented to block forward travel along +x, the
# corridor's own direction.
@export var span := Vector3(0.4, 6.0, 2.3)

var _shape: CollisionShape3D
var _opened := false

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

	_shape = CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = span
	_shape.shape = col
	add_child(_shape)

# Collision drops the instant this is called - opening is a game-state
# fact, not something that should wait on the slide animation to look
# right before it's actually true. The upward slide on top is purely
# cosmetic.
func open() -> void:
	if _opened:
		return
	_opened = true
	_shape.disabled = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + span.y, 1.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
