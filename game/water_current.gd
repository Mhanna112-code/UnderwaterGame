# Push zone controller: setup(area, flow) hands it a pre-placed Area3D and a direction.
# Divers inside are swept along `orientation` via Diver.external_push; off-axis entries bounce back.
class_name WaterCurrent
extends Node

# The four flat directions a current can blow.
enum Direction { POSITIVE_X, NEGATIVE_X, POSITIVE_Z, NEGATIVE_Z }

static func direction_to_vector(dir: Direction) -> Vector3:
	match dir:
		Direction.POSITIVE_X:
			return Vector3(1.0, 0.0, 0.0)
		Direction.NEGATIVE_X:
			return Vector3(-1.0, 0.0, 0.0)
		Direction.POSITIVE_Z:
			return Vector3(0.0, 0.0, 1.0)
		Direction.NEGATIVE_Z:
			return Vector3(0.0, 0.0, -1.0)
	return Vector3.ZERO

# Reverse of direction_to_vector(); non-flat vectors fall back to POSITIVE_X.
static func vector_to_direction(v: Vector3) -> Direction:
	if v.x > 0.5:
		return Direction.POSITIVE_X
	if v.x < -0.5:
		return Direction.NEGATIVE_X
	if v.z > 0.5:
		return Direction.POSITIVE_Z
	if v.z < -0.5:
		return Direction.NEGATIVE_Z
	return Direction.POSITIVE_X

var strength := 10.0
var orientation: Vector3 = Vector3.ZERO
var area: Area3D = null

# Visuals parented under `area`; tracked so teardown() can free them.
var _visual_node: MeshInstance3D = null
var _bubbles_node: CPUParticles3D = null

# body_entered is edge-triggered, so reassert the flow for the whole overlap.
func _physics_process(_delta: float) -> void:
	if area == null or orientation == Vector3.ZERO:
		return
	for body in area.get_overlapping_bodies():
		if body is Diver:
			_apply_to_diver(body as Diver)

func _apply_to_diver(diver: Diver) -> void:
	if _only_present and not _carried.has(diver):
		_repel(diver)
		return
	diver.external_push = orientation * strength + _side_push(diver.global_position)
	diver.current_axis = orientation

# "Carry only present divers": only divers already inside are carried; newcomers are shoved out.
const REPEL_STRENGTH := 1.6   # x strength
var _only_present := false
var _carried: Dictionary = {}   # Diver -> true

func carry_only_present_divers() -> void:
	_only_present = true
	_carried.clear()
	if area == null:
		return
	for body in area.get_overlapping_bodies():
		if body is Diver:
			_carried[body] = true

func carry_all_divers() -> void:
	_only_present = false
	_carried.clear()

func _repel(diver: Diver) -> void:
	var shape_node := _find_box_shape()
	var outward := Vector3.ZERO
	if shape_node != null:
		var xf := shape_node.global_transform
		var half := (shape_node.shape as BoxShape3D).size * 0.5
		var local := xf.affine_inverse() * diver.global_position
		# Push out through the nearest horizontal face (world units; shape may be scaled).
		var gap_x := (half.x - absf(local.x)) * xf.basis.x.length()
		var gap_z := (half.z - absf(local.z)) * xf.basis.z.length()
		var local_out := Vector3(signf(local.x), 0, 0) if gap_x < gap_z else Vector3(0, 0, signf(local.z))
		outward = (xf.basis * local_out)
		outward.y = 0.0
	if outward.length_squared() < 0.0001:
		outward = -orientation
	diver.external_push = outward.normalized() * strength * REPEL_STRENGTH
	diver.current_axis = Vector3.ZERO

# Side band (across the flow) that eases divers outward instead of along the edge.
const SIDE_BAND := 1.5
const SIDE_PUSH := 0.6

func _side_push(at: Vector3) -> Vector3:
	var shape_node := _find_box_shape()
	if shape_node == null:
		return Vector3.ZERO
	var side := orientation.cross(Vector3.UP)
	side.y = 0.0
	if side.length_squared() < 0.0001:
		return Vector3.ZERO
	side = side.normalized()
	var xf := shape_node.global_transform
	var half := (shape_node.shape as BoxShape3D).size * 0.5
	# Half-width across the flow, including any scale on the shape node.
	var half_width := absf(xf.basis.x.dot(side)) * half.x + absf(xf.basis.y.dot(side)) * half.y + absf(xf.basis.z.dot(side)) * half.z
	var offset := (at - xf.origin).dot(side)
	if absf(offset) < half_width - SIDE_BAND:
		return Vector3.ZERO
	return side * signf(offset) * strength * SIDE_PUSH

# Wires this controller to an Area3D and flow. flow = ZERO gives an inert current.
# Safe to call again on a different area (teardown() runs first).
func setup(target_area: Area3D, flow: Vector3 = Vector3.ZERO, push_strength: float = strength, show_debug_visual: bool = true) -> void:
	teardown()
	area = target_area
	orientation = flow
	strength = push_strength
	if orientation == Vector3.ZERO:
		return
	area.collision_mask = 2  # divers only
	area.body_entered.connect(_on_entered)
	area.body_exited.connect(_on_exited)
	if show_debug_visual:
		_build_visual()
	_build_flow_bubbles()

# Disconnects from the previous area, frees visuals and resets orientation so no stale push remains.
func teardown() -> void:
	if area != null:
		if area.body_entered.is_connected(_on_entered):
			area.body_entered.disconnect(_on_entered)
		if area.body_exited.is_connected(_on_exited):
			area.body_exited.disconnect(_on_exited)
		for body in area.get_overlapping_bodies():
			if body is Diver:
				(body as Diver).external_push = Vector3.ZERO
				(body as Diver).current_axis = Vector3.ZERO
	if _visual_node != null and is_instance_valid(_visual_node):
		_visual_node.queue_free()
	_visual_node = null
	if _bubbles_node != null and is_instance_valid(_bubbles_node):
		_bubbles_node.queue_free()
	_bubbles_node = null
	area = null
	orientation = Vector3.ZERO

# Min alignment of diver velocity with the flow to be let in (0.5 ~ 60 degrees).
const ENTRY_ALIGNMENT_MIN := 0.5
const REJECT_BOUNCE := 6.0

# Area3D can't physically block, so misaligned entries are bounced back out instead.
func _on_entered(body: Node3D) -> void:
	if not (body is Diver) or orientation == Vector3.ZERO:
		return
	var d := body as Diver
	if _only_present and not _carried.has(d):
		_repel(d)
		return
	_apply_to_diver(d)
	var vel_flat := Vector3(d.velocity.x, 0.0, d.velocity.z)
	if vel_flat.length() > 0.05 and absf(vel_flat.normalized().dot(orientation)) < ENTRY_ALIGNMENT_MIN:
		d.velocity = -vel_flat.normalized() * REJECT_BOUNCE
		return
	# current_axis lets Diver.swim() strip lateral steering so divers can't strafe out.

func _on_exited(body: Node3D) -> void:
	if body is Diver:
		_carried.erase(body)
		(body as Diver).external_push = Vector3.ZERO
		(body as Diver).current_axis = Vector3.ZERO

func _find_box_shape() -> CollisionShape3D:
	for child in area.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return child as CollisionShape3D
	return null

# Translucent pulsing slab matching the area's collision box (debug only).
func _build_visual() -> void:
	var shape_node := _find_box_shape()
	if shape_node == null:
		return
	var box := shape_node.shape as BoxShape3D

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	mesh_inst.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.75, 0.95, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	mesh_inst.transform = shape_node.transform
	area.add_child(mesh_inst)
	_visual_node = mesh_inst

	# Tween on `area` (self may be elsewhere in the tree); scale delta is in the mesh's local space.
	var local_pulse: Vector3 = (mesh_inst.global_transform.basis.inverse() * orientation).abs()
	var tw := area.create_tween().set_loops()
	tw.tween_property(mesh_inst, "scale", Vector3.ONE + local_pulse * 0.12, 0.7)
	tw.tween_property(mesh_inst, "scale", Vector3.ONE, 0.7)

# In-game current visual: bubbles spawn throughout the box and drift straight along `orientation`.
func _build_flow_bubbles() -> void:
	var shape_node := _find_box_shape()
	if shape_node == null or orientation == Vector3.ZERO:
		return
	var box := shape_node.shape as BoxShape3D

	var bubbles := CPUParticles3D.new()
	bubbles.amount = 24
	bubbles.emitting = true
	# World-space coords: orientation is already a world direction.
	bubbles.local_coords = false
	bubbles.direction = orientation
	bubbles.spread = 8.0
	bubbles.gravity = Vector3.ZERO
	bubbles.initial_velocity_min = strength * 0.6
	bubbles.initial_velocity_max = strength * 1.0
	bubbles.scale_amount_min = 0.05
	bubbles.scale_amount_max = 0.14

	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = box.size * 0.5

	# Lifetime ~ one crossing of the box; uses shape_node's basis since box.size is in its local space.
	var local_orientation: Vector3 = shape_node.global_transform.basis.inverse() * orientation
	var travel_extent: float = absf(local_orientation.x) * box.size.x \
		+ absf(local_orientation.y) * box.size.y \
		+ absf(local_orientation.z) * box.size.z
	var avg_speed: float = (bubbles.initial_velocity_min + bubbles.initial_velocity_max) * 0.5
	bubbles.lifetime = maxf(0.6, travel_extent / maxf(avg_speed, 0.1))

	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	sphere.radial_segments = 6
	sphere.rings = 3
	bubbles.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.92, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubbles.mesh.surface_set_material(0, mat)

	bubbles.transform = shape_node.transform
	area.add_child(bubbles)
	_bubbles_node = bubbles
