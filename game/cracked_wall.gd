# Rock barrier cleared only by shockwave: joins "shockwave_breakable" and reacts to on_shockwave().
# `span` sizes the collision/blast box; the mesh is a box or (optionally) a sphere.
class_name CrackedWall
extends StaticBody3D

# Emitted right before queue_free(); world.gd uses it for reward rocks.
signal broken

# HP healed onto the breaking diver by world.gd; 0 = plain barrier.
@export var reward_hp := 0

@export var span := Vector3(2.0, 2.0, 2.0)

# Invisible extra collision height so divers can't swim over; 0 = visible height.
@export var collision_height := 0.0

# Invisible extra collision width so divers can't swim around; 0 = visible width.
@export var collision_width := 0.0

# Looks exactly like an ambient scenery rock (hidden until shockwaved).
@export var disguised_as_scenery_rock := false

# Rounded-rock silhouette, coloured brown so it reads as breakable.
@export var sphere_shaped := false

var _mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("shockwave_breakable")

	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if disguised_as_scenery_rock or sphere_shaped:
		var rock := SphereMesh.new()
		rock.radius = 0.5
		rock.height = 0.7
		rock.radial_segments = 7
		rock.rings = 4
		_mesh.mesh = rock
		if disguised_as_scenery_rock:
			# Must match _build_site()'s ambient rock material.
			mat.albedo_color = Color(0.13, 0.19, 0.21)
			mat.roughness = 1.0
		else:
			mat.albedo_color = Color(0.42, 0.22, 0.14)
			mat.roughness = 0.9
	else:
		var box := BoxMesh.new()
		box.size = span
		_mesh.mesh = box
		mat.albedo_color = Color(0.42, 0.22, 0.14)
		mat.roughness = 0.9
	_mesh.material_override = mat
	add_child(_mesh)

	var col_size: Vector3 = span
	if collision_height > span.y:
		col_size.y = collision_height
	if collision_width > span.z:
		col_size.z = collision_width

	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = col_size
	shape.shape = col
	# Extra height extends upward only; the Z extension is centred.
	shape.position.y = (col_size.y - span.y) * 0.5
	add_child(shape)

# Measures distance to the visible box, not the taller collision box.
func on_shockwave(from_position: Vector3, radius: float) -> void:
	var half: Vector3 = span * 0.5
	var local_from: Vector3 = to_local(from_position)
	var closest := Vector3(
		clampf(local_from.x, -half.x, half.x),
		clampf(local_from.y, -half.y, half.y),
		clampf(local_from.z, -half.z, half.z)
	)
	if local_from.distance_to(closest) <= radius:
		broken.emit()
		queue_free()
