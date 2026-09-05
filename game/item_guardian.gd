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

# What is actually standing on the plinth. The trigger, the signal and the
# fight are the same either way; this is only what you see from the rim.
#
# There were two of these on the map and both were the same red urchin,
# which reads as one fetch quest done twice. "salvage" is the pressure
# regulator from the first combat PR: brass housing, a valve wheel that
# turns, and a lit gauge, which is the only warm light on a cold seabed.
@export var look := "urchin"

# How far above the plinth top this look wants to sit, since a spiked ball
# and a barrel lying on its side do not balance at the same height.
const LIFT := {"urchin": 0.9, "salvage": 0.55}

# Where the two guarded items are: on the plinth at the middle of a combat
# site. One list, in content/sites.gd, read by the site builder, by this, by
# sonar (diver.gd) and by the minimap (mini_map.gd), so none of them can
# disagree about where a thing is.
#
# This used to be a hand-written pair of coordinates here, and they sat
# inside the level geometry that got built around them later: a shape query
# at the first one came back with three environment overlaps, so the guardian
# was inside a rock. Sites are checked for a site-sized clearing and a clear
# approach before they are allowed on the map (see content/sites.gd and
# verify/sites.gd), and putting the guarded item where the site is means it
# inherits that check instead of needing its own.
static func spots() -> Array:
	return Sites.guarded()

func _ready() -> void:
	collision_mask = 2

	if look == "salvage":
		_build_salvage()
	else:
		_build_urchin()

	var shape := CollisionShape3D.new()
	var col := SphereShape3D.new()
	col.radius = 1.9
	shape.shape = col
	add_child(shape)

	body_entered.connect(_on_body_entered)

# The pressure regulator from the first combat PR. It brings its own warm
# gauge light, so this adds none: two lights on one object is how you get a
# flat white blob instead of a shape.
func _build_salvage() -> void:
	var part := SalvagePart.new()
	add_child(part)

# A spiked urchin cluster - deliberately not another ring (that shape
# already means "grapple anchor" or "lock plate" in this game), so a guarded
# item reads as its own kind of thing at a glance.
#
# Sized to be seen rather than to be accurate. At the original 0.5 m radius
# with the core hidden it was a handful of dark red slivers about fifteen
# pixels across from seven metres out, in fog, which is not a landmark, it
# is a thing you find by swimming into it.
func _build_urchin() -> void:
	var core := SphereMesh.new()
	core.radius = 0.9
	core.height = 1.8
	var core_mesh := MeshInstance3D.new()
	core_mesh.mesh = core
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.1, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.15, 0.2)
	mat.emission_energy_multiplier = 1.2
	mat.roughness = 0.6
	core_mesh.material_override = mat
	add_child(core_mesh)

	# It also has to be visible in the murk, not just large. The dive site
	# runs fog at 0.035 density and everything else down here is the same
	# blue-grey, so the light is what makes this findable from a distance.
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.3, 0.25)
	glow.light_energy = 3.2
	glow.omni_range = 12.0
	add_child(glow)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(item_id.hash())    # same spikes every run for this guardian
	for i in range(13):
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.16
		spike.height = 1.0
		var spike_mesh := MeshInstance3D.new()
		spike_mesh.mesh = spike
		spike_mesh.material_override = mat
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
		spike_mesh.position = dir * 0.8
		# look_at() reads global transform, so it has to be in the tree first
		add_child(spike_mesh)
		spike_mesh.look_at(spike_mesh.global_position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		spike_mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func _on_body_entered(body: Node3D) -> void:
	if body is Diver:
		triggered.emit(item_id)
