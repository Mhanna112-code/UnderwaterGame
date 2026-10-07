# Glowing ring that grapple can lock onto; joins the "grapple_anchor" group for _grapple()'s raycast.
class_name GrappleAnchor
extends StaticBody3D

# Optional diver model_name whose locked ability unlocks on a successful grapple here.
@export var unlocks_diver_ability_for: String = ""
@export var ring_color := Color(0.95, 0.85, 0.3)
@export var ring_inner_radius := 0.32
@export var ring_outer_radius := 0.5
@export var show_ring := true
@export var target_radius := 0.8
@export var target_height := 2.5

func _ready() -> void:
	add_to_group("grapple_anchor")

	if show_ring:
		var ring := TorusMesh.new()
		ring.inner_radius = ring_inner_radius
		ring.outer_radius = ring_outer_radius
		var mesh := MeshInstance3D.new()
		mesh.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ring_color
		mat.emission_enabled = true
		mat.emission = ring_color
		mat.emission_energy_multiplier = 1.5
		mesh.material_override = mat
		add_child(mesh)

	# Large and tall so a roughly aimed eye-level ray still hits.
	var shape := CollisionShape3D.new()
	var col := CylinderShape3D.new()
	col.radius = target_radius
	col.height = target_height
	shape.shape = col
	add_child(shape)

# Called by diver.gd's _grapple() on a confirmed hit; finds divers among siblings.
func on_grappled_to() -> void:
	if unlocks_diver_ability_for == "":
		return
	for sibling in get_parent().get_children():
		if sibling is Diver and (sibling as Diver).model_name == unlocks_diver_ability_for:
			(sibling as Diver).unlock_ability()
