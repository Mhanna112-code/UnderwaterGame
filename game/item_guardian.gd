# A fixed spot in the dive site that guards a specific item - swim into it
# and world.gd drops you into a battle; win it and the item's yours. Same
# Area3D-on-layer-2 trigger shape as lock_plate.gd/item_orb.gd, but this one
# only ever fires once - world.gd frees both this and its decorative
# Goblin the moment `triggered` fires, so walking through the same empty
# water again does nothing.
#
# Doesn't know what a Battle is, doesn't touch the item itself - just says
# "something guarded is here" and hands back which item_id, the same
# ability-agnostic split cracked_wall.gd/grapple_anchor.gd already use for
# staying out of systems they don't need to know about.
class_name ItemGuardian
extends Area3D

signal triggered(item_id: String)

@export var item_id := ""

const SPOTS := [
	{"item": "current_pearl", "at": Vector3(16.0, 1.2, 12.0), "radius": 25},
	{"item": "reef_plate", "at": Vector3(-16.0, 1.2, -12.0), "radius": 25},
]

func _ready() -> void:
	collision_mask = 2

	# A spiked dark urchin cluster - deliberately not another ring (that
	# shape already means "grapple anchor" or "lock plate" in this game),
	# so a guarded item reads as its own kind of thing at a glance.
	var core := SphereMesh.new()
	core.radius = 0.5
	core.height = 1.0
	var core_mesh := MeshInstance3D.new()
	core_mesh.mesh = core
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.1, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.15, 0.2)
	mat.emission_energy_multiplier = 1.2
	mat.roughness = 0.6
	core_mesh.material_override = mat
	core_mesh.visible = false
	add_child(core_mesh)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(item_id.hash())    # same spikes every run for this guardian, not reshuffled each launch
	for i in range(9):
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.09
		spike.height = 0.55
		var spike_mesh := MeshInstance3D.new()
		spike_mesh.mesh = spike
		spike_mesh.material_override = mat
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
		spike_mesh.position = dir * 0.45
		# look_at() needs to be inside the tree first (it reads global
		# transform) - add_child() before positioning it, not after.
		add_child(spike_mesh)
		spike_mesh.look_at(spike_mesh.global_position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		spike_mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)

	var shape := CollisionShape3D.new()
	var col := SphereShape3D.new()
	col.radius = 1.4
	shape.shape = col
	add_child(shape)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Diver:
		triggered.emit(item_id)
