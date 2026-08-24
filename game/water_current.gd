# A push zone - NOT attached to the Area3D itself. Instead, some other
# script (e.g. maze_level.gd) builds a WaterCurrent, adds it to the tree,
# then calls setup(target_area, flow) to hand it which pre-placed Area3D
# (with its own hand-sized CollisionShape3D/BoxShape3D) it should actually
# control and which direction it blows. Both come from outside - this
# script never guesses either one from its own scene placement.
#
# Any diver inside `area` gets steadily swept along `orientation`, blended
# into Diver.swim() via external_push rather than taking control away
# outright (see swim()'s own comment) - unlike whirlpool.gd's suction, a
# current never locks movement, it just makes swimming with it fast and
# against it slow. Approaching too far off `orientation` gets bounced back
# at the boundary instead of being let in and redirected sideways - see
# _on_entered().
class_name WaterCurrent
extends Node

# The four flat directions a current can blow - direction_to_vector() is
# just a convenience for callers that would rather pick one of these than
# build a raw Vector3 by hand.
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

# The reverse of direction_to_vector() above - reads a Direction back off
# a WaterCurrent's own `orientation`, so a caller rotating an existing
# current (see maze_level.gd's rotate_corridors_left()/_right()) doesn't
# have to separately track "which Direction is this corridor on right
# now" itself. Only meaningful for the four flat directions this class
# actually produces - a Vector3 that isn't one of those four (e.g. still
# Vector3.ZERO, an inert current) falls back to POSITIVE_X.
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

# The two nodes _build_visual()/_build_flow_bubbles() add under `area` -
# tracked here so teardown() (below) can find and free them again when
# this controller moves to a different Area3D, since they're parented to
# `area`, not to this node, and nothing else would ever clean them up.
var _visual_node: MeshInstance3D = null
var _bubbles_node: CPUParticles3D = null

# Area3D entry signals are edge-triggered: after a rejected entry, normal
# swimming can overwrite the one-frame bounce while the diver remains inside,
# and body_entered will not fire again. Reassert the flow for the full overlap
# so current strength and steering constraints remain authoritative.
func _physics_process(_delta: float) -> void:
	if area == null or orientation == Vector3.ZERO:
		return
	for body in area.get_overlapping_bodies():
		if body is Diver:
			_apply_to_diver(body as Diver)

func _apply_to_diver(diver: Diver) -> void:
	diver.external_push = orientation * strength
	diver.current_axis = orientation

# Called right after add_child()-ing this node - wires this controller up
# to whichever Area3D it should actually watch and which way it pushes.
# push_strength defaults to the field above if not given. show_debug_visual
# controls the pulsing translucent slab from _build_visual() below -
# that's the ONLY thing rendered here; Area3D and CollisionShape3D are
# never drawn at runtime on their own (only as an editor-only gizmo, or
# under the engine's "Visible Collision Shapes" debug view), so turning
# this off is what actually makes the current invisible in a real
# playthrough.
#
# flow defaults to Vector3.ZERO - a caller that hasn't picked a direction
# for some Area3D yet can still call setup(area) and get an inert current
# back (no push, no bubbles, no debug visual) instead of needing an
# if-check at every call site to skip the ones without a direction.
#
# Safe to call more than once, on different Area3D nodes each time - see
# teardown() below, called first here so a controller that's already
# watching one corridor can just be handed a new one (see
# rotate_currents.gd's change_corridor()) instead of needing a whole new
# WaterCurrent built from scratch.
func setup(target_area: Area3D, flow: Vector3 = Vector3.ZERO, push_strength: float = strength, show_debug_visual: bool = true) -> void:
	teardown()
	area = target_area
	orientation = flow
	strength = push_strength
	if orientation == Vector3.ZERO:
		return
	area.collision_mask = 2   # divers only, see whirlpool.gd's own note on this - Area3D's default mask only watches layer 1
	area.body_entered.connect(_on_entered)
	area.body_exited.connect(_on_exited)
	if show_debug_visual:
		_build_visual()
	_build_flow_bubbles()

# Disconnects from whatever Area3D this was previously watching (if any)
# and frees its debug visual/bubble stream, so a stale connection to the
# OLD corridor doesn't keep pushing divers there forever once this
# controller's been handed a new one. Also resets orientation to
# Vector3.ZERO so a diver mid-push from the old area gets cleared rather
# than stuck with a stale external_push - see _on_exited() not firing for
# them since they never actually left the Area3D, this node did.
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

# How aligned a diver's own velocity has to be with `orientation` to
# actually be let in - 1.0 would mean "only dead-straight along the
# current," 0.0 would mean "any angle at all." 0.5 means roughly anything
# within ~60 degrees of the flow direction counts as swimming with/against
# it; anything more sideways than that gets treated as trying to cut
# straight across, which a current this strong doesn't allow.
const ENTRY_ALIGNMENT_MIN := 0.5
const REJECT_BOUNCE := 6.0

# Area3D has no real collision response of its own (it only detects
# overlap, it can't physically stop a CharacterBody3D the way a
# StaticBody3D would), so a true hard block isn't available here - this
# reacts instead: if the diver's own velocity at the moment of entry isn't
# reasonably aligned with the flow, immediately bounce them back out the
# way they came rather than letting the push ever apply, which reads as
# "hit an invisible wall" rather than "got shoved."
func _on_entered(body: Node3D) -> void:
	if not (body is Diver) or orientation == Vector3.ZERO:
		return
	var d := body as Diver
	_apply_to_diver(d)
	var vel_flat := Vector3(d.velocity.x, 0.0, d.velocity.z)
	if vel_flat.length() > 0.05 and absf(vel_flat.normalized().dot(orientation)) < ENTRY_ALIGNMENT_MIN:
		d.velocity = -vel_flat.normalized() * REJECT_BOUNCE
		return
	# external_push alone only ever made swimming
	# upstream a losing fight - it did nothing about swimming SIDEWAYS
	# out of the current, since that's a direction external_push doesn't
	# oppose at all. current_axis is what Diver.swim() actually uses to
	# strip lateral steering input once inside (see its own comment) -
	# without setting it here, entering "correctly" still left the door
	# open to just strafing out through where a wall should be.

func _on_exited(body: Node3D) -> void:
	if body is Diver:
		(body as Diver).external_push = Vector3.ZERO
		(body as Diver).current_axis = Vector3.ZERO

# Both the debug box and the real bubble effect need `area`'s own
# CollisionShape3D/BoxShape3D - shared here rather than each re-scanning
# area's children separately.
func _find_box_shape() -> CollisionShape3D:
	for child in area.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			return child as CollisionShape3D
	return null

# A translucent, slowly-pulsing slab sized to `area`'s own
# CollisionShape3D/BoxShape3D exactly as placed - parented under `area`
# with that shape's own local transform (not this node's own, since this
# node isn't even necessarily anywhere near `area` in the tree), so the
# glow lines up with the actual push zone regardless of where the shape
# is offset to.
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

	# create_tween() on `area`, not on self - self may not even be
	# anywhere near `area` in the tree, but area is guaranteed to already
	# be there (it's the pre-placed node setup() was handed).
	#
	# MODIFIED: was orientation.abs() directly - mesh_inst.scale is in
	# THIS mesh's own local space, which now carries whatever rotation
	# shape_node.transform has (several of these boxes are rotated ~90
	# degrees relative to their own Area3D parent). Using the raw
	# world-space orientation as a local scale delta pulsed the wrong
	# axis on any rotated corridor. Converted into the mesh's own local
	# space first instead, same fix as _build_flow_bubbles()' lifetime
	# math below.
	var local_pulse: Vector3 = (mesh_inst.global_transform.basis.inverse() * orientation).abs()
	var tw := area.create_tween().set_loops()
	tw.tween_property(mesh_inst, "scale", Vector3.ONE + local_pulse * 0.12, 0.7)
	tw.tween_property(mesh_inst, "scale", Vector3.ONE, 0.7)

# The actual in-game visual for the current, not a dev aid - a stream of
# small bubbles spawning throughout the whole box (emission_shape/
# emission_box_extents) and drifting along `orientation`, continuously,
# whether or not a diver's anywhere near it. Same bubble look as the
# diver's own personal trail (Diver._add_bubbles()) for a consistent
# visual language, but no upward gravity - this isn't buoyancy, it's a
# straight current push, so bubbles should travel in a straight line
# along the flow instead of curving upward the way the diver's own
# trail does.
func _build_flow_bubbles() -> void:
	var shape_node := _find_box_shape()
	if shape_node == null or orientation == Vector3.ZERO:
		return
	var box := shape_node.shape as BoxShape3D

	var bubbles := CPUParticles3D.new()
	bubbles.amount = 24
	bubbles.emitting = true
	# local_coords = false - orientation is already a world-space
	# direction (computed once by whoever called setup()), so bubbles
	# should drift along it regardless of any rotation on `area` itself,
	# rather than being reinterpreted relative to this emitter's own
	# local axes (CPUParticles3D's default).
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

	# Lifetime tuned so a bubble roughly crosses the box once at this
	# speed, instead of a fixed number that could pop it out mid-corridor
	# or leave it drifting long past the far end. local_orientation
	# converts the world-space `orientation` back into the box's own
	# local space, since box.size is measured in that local space, not
	# world space.
	#
	# MODIFIED: was area.global_transform.basis - several of these boxes
	# carry their own rotation on the CollisionShape3D child itself
	# (relative to an unrotated Area3D parent), not on `area`. Using
	# area's basis there was effectively a no-op for those corridors
	# (identity inverse), so travel_extent picked up whatever box.size
	# component happened to line up with world space, not the box's
	# actual long axis - shape_node's own basis (which the shape's
	# rotation actually lives on) is the correct one to invert.
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
