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
# Maze options: `golden` gives it a gold shimmer (pulsing glow, sparkles, a
# little light) so it reads as "grab this"; `grappleable` lets Musashi's
# grapple hit it - the diver stays put and the orb is reeled in to them,
# then collected (handy for orbs left floating out of reach).
@export var golden := false
@export var grappleable := false
# Only a grapple picks this one up; swimming into it just says so (the
# `needs_ability` signal - MazeLevel shows the message).
@export var grapple_only := false
signal needs_ability(diver: Diver)

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
	if golden:
		c = Color(1.0, 0.78, 0.25)
	_mat.albedo_color = c
	_mat.emission = c
	_mat.emission_energy_multiplier = 1.4
	_mesh.material_override = _mat
	add_child(_mesh)
	if golden:
		_add_golden_shimmer()
	if grappleable:
		var target := GrappleTarget.new()
		target.orb = self
		add_child(target)

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
		if grapple_only:
			needs_ability.emit(body as Diver)
			return
		_collect(body as Diver)

func _collect(diver: Diver) -> void:
	if is_queued_for_deletion():
		return
	collected.emit(item_id, diver)
	queue_free()

# Pulsing glow, gold sparkles drifting up, and a soft gold light.
func _add_golden_shimmer() -> void:
	_mesh.scale = Vector3.ONE * 1.5
	# Lit and metallic, so the pulsing glow and highlights actually show.
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mat.emission = Color(0.95, 0.68, 0.12)
	_mat.emission_energy_multiplier = 0.5
	_mat.metallic = 1.0
	_mat.roughness = 0.2
	_mat.rim_enabled = true
	_mat.rim = 1.0
	_mat.rim_tint = 0.2
	var breathe := create_tween().set_loops()
	breathe.tween_property(_mesh, "scale", Vector3.ONE * 1.7, 0.45).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_mesh, "scale", Vector3.ONE * 1.4, 0.45).set_trans(Tween.TRANS_SINE)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_mat, "emission_energy_multiplier", 1.1, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_mat, "emission_energy_multiplier", 0.25, 0.45).set_trans(Tween.TRANS_SINE)
	var sparkles := CPUParticles3D.new()
	sparkles.amount = 28
	sparkles.lifetime = 1.2
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 0.45
	sparkles.direction = Vector3.UP
	sparkles.spread = 25.0
	sparkles.gravity = Vector3(0, 0.6, 0)
	sparkles.initial_velocity_min = 0.2
	sparkles.initial_velocity_max = 0.5
	sparkles.scale_amount_min = 0.5
	sparkles.scale_amount_max = 1.0
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.06
	spark_mesh.height = 0.12
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.9, 0.5)
	spark_mesh.material = spark_mat
	sparkles.mesh = spark_mesh
	add_child(sparkles)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.35)
	light.light_energy = 2.0
	light.omni_range = 3.0
	add_child(light)

# What the grapple's ray actually hits: a small body on its own collision
# layer (5), so divers (which only collide with layer 1) never bump into it
# and the camera's wall check ignores it, but the grapple's ray (all
# layers) does. Grappled: the orb flies to the diver who fired (following
# them if they move), shrinking as it arrives, and is collected there.
class GrappleTarget extends StaticBody3D:
	var orb: ItemOrb

	func _ready() -> void:
		collision_layer = 1 << 4
		collision_mask = 0
		add_to_group("grapple_anchor")
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.6
		shape.shape = sphere
		add_child(shape)

	func reel_in_to(diver: Diver) -> void:
		if orb == null or not is_instance_valid(orb) or orb.get_meta("reeling", false):
			return
		orb.set_meta("reeling", true)
		# No longer a target mid-flight.
		collision_layer = 0
		var start := orb.global_position
		var tw := orb.create_tween()
		tw.tween_method(func(t: float) -> void:
			if not is_instance_valid(orb) or not is_instance_valid(diver):
				return
			var chest := diver.global_position + Vector3(0, diver.height * 0.5, 0)
			orb.global_position = start.lerp(chest, t)
			orb.scale = Vector3.ONE * lerpf(1.0, 0.35, maxf(0.0, (t - 0.7) / 0.3)),
			0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			if is_instance_valid(orb) and is_instance_valid(diver):
				orb._collect(diver))
