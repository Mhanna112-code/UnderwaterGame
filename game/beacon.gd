# One waypoint on a route.
#
# A post with a lamp, planted on the seabed between two sites. Spacing is set
# in content/sites.gd to stay inside what the fog lets you see, so from any
# beacon you can see the next one or two and following them is the whole of
# navigation. No compass, no arrow on the HUD, no words.
#
# The colour is the only legend there is: amber and breathing means this is
# the way onward, dim green means a road already walked.
class_name Beacon
extends Node3D

enum State { ONWARD, DONE, IDLE }

const ONWARD_COL := Color(1.0, 0.74, 0.34)
const DONE_COL := Color(0.42, 0.86, 0.58)
const IDLE_COL := Color(0.36, 0.48, 0.54)

var state: int = State.IDLE
var _t := 0.0
var lamp: OmniLight3D
var glass: MeshInstance3D
var phase := 0.0          # so a line of them ripples outward instead of blinking as one

func build(at: Vector3, order: int) -> void:
	position = Vector3(at.x, 0.0, at.z)
	phase = float(order) * 0.55

	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.13
	cyl.height = 1.9
	cyl.radial_segments = 6
	post.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.19, 0.21, 0.22)
	pm.roughness = 0.95
	post.material_override = pm
	post.position.y = 0.95
	add_child(post)

	glass = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	s.radial_segments = 8
	s.rings = 5
	glass.mesh = s
	glass.position.y = 2.05
	add_child(glass)

	lamp = OmniLight3D.new()
	lamp.omni_range = 11.0
	lamp.position.y = 2.05
	add_child(lamp)
	set_state(State.IDLE)

func set_state(v: int) -> void:
	state = v
	var c: Color = ONWARD_COL if v == State.ONWARD else (DONE_COL if v == State.DONE else IDLE_COL)
	if lamp != null:
		lamp.light_color = c
	if glass != null:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.6 if v == State.ONWARD else 1.2
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.material_override = m

func _process(dt: float) -> void:
	_t += dt
	if lamp == null:
		return
	match state:
		State.ONWARD:
			# the pulse travels down the line, which reads as direction
			lamp.light_energy = 2.6 + sin(_t * 2.4 - phase) * 1.4
		State.DONE:
			lamp.light_energy = 0.9
		_:
			lamp.light_energy = 0.5
