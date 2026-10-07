# Visual-only trail marker: a thin pillar along the way, a wide ring (`is_goal`) at the destination.
class_name Waypoint
extends Node3D

@export var is_goal := false

var _base_y := 0.0

func _ready() -> void:
	_base_y = position.y

	var mat := StandardMaterial3D.new()
	var mesh := MeshInstance3D.new()

	if is_goal:
		mat.albedo_color = Color(0.35, 0.9, 0.55)
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.9, 0.55)
		mat.emission_energy_multiplier = 1.8
		var ring := TorusMesh.new()
		ring.inner_radius = 3.0
		ring.outer_radius = 3.7
		mesh.mesh = ring
		mesh.rotation_degrees.x = 90.0
	else:
		mat.albedo_color = Color(0.9, 0.75, 0.25)
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.75, 0.25)
		mat.emission_energy_multiplier = 1.5
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.15
		cyl.height = 2.5
		mesh.mesh = cyl
		mesh.position.y = 1.25

	mesh.material_override = mat
	add_child(mesh)

	# Slow bob so markers don't read as scenery.
	var tw := create_tween().set_loops()
	tw.tween_property(self, "position:y", _base_y + 0.3, 1.2)
	tw.tween_property(self, "position:y", _base_y - 0.3, 1.2)
