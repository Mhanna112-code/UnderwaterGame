# A target-like asset for Diver.use_ability()'s "grapple" case: a glowing
# ring a diver with the grapple ability can lock onto from a distance and
# get pulled toward. Doesn't know about Diver or abilities at all - it just
# joins the "grapple_anchor" group so _grapple()'s raycast can recognize it,
# the same group-tag pattern game/cracked_wall.gd uses for shockwave.
class_name GrappleAnchor
extends StaticBody3D

# Optional: a diver model_name whose locked ability this anchor unlocks the
# moment something successfully grapples to it. "" means it's just a plain
# traversal target with no side effect - only the gap sequence's anchor
# sets this (to "Staff_Diver").
@export var unlocks_diver_ability_for: String = ""

func _ready() -> void:
	add_to_group("grapple_anchor")

	var ring := TorusMesh.new()
	ring.inner_radius = 0.32
	ring.outer_radius = 0.5
	var mesh := MeshInstance3D.new()
	mesh.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.85, 0.3)
	mat.emission_energy_multiplier = 1.5
	mesh.material_override = mat
	add_child(mesh)

	# Generous relative to the ring's own size - a raycast is a single line,
	# so a collision shape this size is what keeps "roughly facing it" close
	# enough to register as a hit instead of demanding pixel-perfect aim.
	# Tall on purpose: the ray fires from the diver's eye level (see
	# diver.gd's _grapple(), height * 0.4 above its own origin), which won't
	# line up with the anchor's exact placement Y to the centimeter - a
	# short collision shape made that miss even when clearly "aimed at."
	var shape := CollisionShape3D.new()
	var col := CylinderShape3D.new()
	col.radius = 0.8
	col.height = 2.5
	shape.shape = col
	add_child(shape)

# Called by diver.gd's _grapple() the instant a pull actually lands on
# this specific anchor - not on every grapple attempt, only a confirmed
# hit on this one. Searches siblings rather than holding a direct
# reference, since this anchor is built long before it knows which Diver
# instances will exist alongside it in the scene.
func on_grappled_to() -> void:
	if unlocks_diver_ability_for == "":
		return
	for sibling in get_parent().get_children():
		if sibling is Diver and (sibling as Diver).model_name == unlocks_diver_ability_for:
			(sibling as Diver).unlock_ability()
