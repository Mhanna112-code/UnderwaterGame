# A short-lived visual language for the first-run route.  Text can say the
# name of a power, but a player should be able to learn the match by cycling
# divers and comparing the colour/shapes in the world: cyan pulse =
# Shockwave, gold ring = Grapple, purple linked rings = Swap, and the three
# coloured plate halos mean all three divers have a place in the final gate.
class_name TutorialCue
extends Node3D

enum Kind { SHOCKWAVE, GRAPPLE, SWAP, DOOR, COMBAT }

const SHOCKWAVE_COLOR := Color(0.32, 0.84, 1.0)
const GRAPPLE_COLOR := Color(0.96, 0.78, 0.22)
const SWAP_COLOR := Color(0.78, 0.42, 1.0)
const DOOR_COLOR := Color(0.38, 0.96, 0.55)
const COMBAT_COLOR := Color(1.0, 0.28, 0.24)

var kind: Kind = Kind.SHOCKWAVE
var cue_color := SHOCKWAVE_COLOR

static func color_for_ability(ability_id: String) -> Color:
	match ability_id:
		"shockwave":
			return SHOCKWAVE_COLOR
		"grapple":
			return GRAPPLE_COLOR
		"swap":
			return SWAP_COLOR
	return DOOR_COLOR

func configure(next_kind: Kind) -> void:
	kind = next_kind
	match kind:
		Kind.SHOCKWAVE:
			cue_color = SHOCKWAVE_COLOR
		Kind.GRAPPLE:
			cue_color = GRAPPLE_COLOR
		Kind.SWAP:
			cue_color = SWAP_COLOR
		Kind.DOOR:
			cue_color = DOOR_COLOR
		Kind.COMBAT:
			cue_color = COMBAT_COLOR

func _ready() -> void:
	# A small coloured light is deliberately paired with the emissive meshes:
	# the route has fog, and a cue which only shows up in the inspector is not a
	# cue a first-time player can use.
	var glow := OmniLight3D.new()
	glow.light_color = cue_color
	glow.light_energy = 2.5
	glow.omni_range = 10.0
	add_child(glow)

	match kind:
		Kind.SHOCKWAVE:
			_build_shockwave()
		Kind.GRAPPLE:
			_build_grapple()
		Kind.SWAP:
			_build_swap()
		Kind.DOOR:
			_build_door()
		Kind.COMBAT:
			_build_combat()

func _material_for(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _material(alpha := 1.0) -> StandardMaterial3D:
	return _material_for(cue_color, alpha)

func _ring(radius: float, local_position: Vector3, vertical := false, alpha := 1.0) -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.78
	ring.outer_radius = radius
	var mesh := MeshInstance3D.new()
	mesh.mesh = ring
	mesh.material_override = _material(alpha)
	mesh.position = local_position
	if vertical:
		mesh.rotation_degrees.x = 90.0
	add_child(mesh)
	return mesh

func _pulse(mesh: Node3D, min_scale: float, max_scale: float, duration: float) -> void:
	mesh.scale = Vector3.ONE * min_scale
	var tw := create_tween().set_loops()
	tw.tween_property(mesh, "scale", Vector3.ONE * max_scale, duration)
	tw.tween_property(mesh, "scale", Vector3.ONE * min_scale, duration)

func _build_shockwave() -> void:
	# Three expanding vertical wavefronts point at the rock wall rather than
	# looking like another generic destination marker.
	for i in range(3):
		var wave := _ring(0.45 + float(i) * 0.28, Vector3(0.0, 1.6, 0.0), true, 0.9 - float(i) * 0.18)
		_pulse(wave, 0.8 + float(i) * 0.08, 1.22 + float(i) * 0.08, 0.75)
	# In fog a line-on-line torus can disappear edge-on.  The floating cyan
	# pulse cores keep the same wave meaning legible from the chase camera,
	# rather than leaving the visual match technically present but invisible.
	for y in [0.7, 1.55, 2.4]:
		var core := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		core.mesh = sphere
		core.material_override = _material()
		core.position = Vector3(0.0, float(y), 0.0)
		add_child(core)
		_pulse(core, 0.75, 1.5, 0.55)

func _build_grapple() -> void:
	# A tall hoop above the target is visible from the staging side of the
	# whirlpool and shares the gold colour of the actual grapple anchor.
	var hoop := _ring(0.9, Vector3(0.0, 1.8, 0.0), true)
	_pulse(hoop, 0.9, 1.15, 0.7)
	var beacon := _ring(0.38, Vector3(0.0, 3.1, 0.0))
	_pulse(beacon, 0.8, 1.25, 0.65)

func _build_swap() -> void:
	# Two linked rings communicate "exchange two positions" before any text is
	# read.  The same purple then appears over a selected ally.
	var left := _ring(0.72, Vector3(-0.8, 1.3, 0.0), true)
	var right := _ring(0.72, Vector3(0.8, 1.3, 0.0), true)
	_pulse(left, 0.85, 1.16, 0.65)
	_pulse(right, 1.16, 0.85, 0.65)
	var bridge := MeshInstance3D.new()
	var bar := CylinderMesh.new()
	bar.height = 1.35
	bar.top_radius = 0.07
	bar.bottom_radius = 0.07
	bridge.mesh = bar
	bridge.material_override = _material(0.8)
	bridge.position = Vector3(0.0, 1.3, 0.0)
	bridge.rotation_degrees.z = 90.0
	add_child(bridge)

func _build_door() -> void:
	# Three tall coloured beacons sit directly above the three lock plates.
	# Ground rings alone get hidden by the party/camera, and a horizontal crown
	# looked like an arbitrary destination.  These form the same cyan/gold/
	# purple pattern as the party halos and remain legible while approaching
	# down the corridor.
	var colors := [SHOCKWAVE_COLOR, GRAPPLE_COLOR, SWAP_COLOR]
	var lanes := [-2.5, 0.0, 2.5]
	for i in range(colors.size()):
		var color: Color = colors[i]
		var z := float(lanes[i])
		var pillar := MeshInstance3D.new()
		var beam := CylinderMesh.new()
		beam.top_radius = 0.09
		beam.bottom_radius = 0.09
		beam.height = 3.4
		pillar.mesh = beam
		pillar.material_override = _material_for(color, 0.82)
		pillar.position = Vector3(0.0, 2.35, z)
		add_child(pillar)
		var crown := MeshInstance3D.new()
		var orb := SphereMesh.new()
		orb.radius = 0.3
		orb.height = 0.6
		crown.mesh = orb
		crown.material_override = _material_for(color)
		crown.position = Vector3(0.0, 4.15, z)
		add_child(crown)
		_pulse(crown, 0.78, 1.3, 0.62 + float(i) * 0.1)

func _build_combat() -> void:
	# Red target reticle: combat is intentionally the first thing beyond the
	# door, and should read as danger rather than another treasure waypoint.
	var outer := _ring(1.1, Vector3(0.0, 1.8, 0.0), true)
	var inner := _ring(0.48, Vector3(0.0, 1.8, 0.0), true)
	_pulse(outer, 0.9, 1.14, 0.55)
	_pulse(inner, 1.12, 0.86, 0.55)
	# Reticles can be edge-on from the chase camera.  The red pulse at their
	# centre makes the intended first combat readable at a glance.
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	core.mesh = sphere
	core.material_override = _material()
	core.position = Vector3(0.0, 1.8, 0.0)
	add_child(core)
	_pulse(core, 0.8, 1.4, 0.45)
