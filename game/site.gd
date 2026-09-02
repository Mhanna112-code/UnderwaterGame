# One place on the seabed, built so that arriving somewhere feels like it.
#
# A site is a bowl: a low berm ring you cross, broken columns round the rim,
# and a plinth at the middle. The enclosure is not decoration. It narrows the
# volume, which is the only thing that makes an encounter inside it mean
# anything in three dimensions, where anything in open water can be swum
# around.
class_name Site
extends Node3D

const STONE := Color(0.15, 0.20, 0.21)
const BERM := Color(0.19, 0.25, 0.25)

var data: Dictionary = {}
var cleared := false
var _t := 0.0
var lamp: OmniLight3D
var lamp_mesh: MeshInstance3D

func build(d: Dictionary) -> void:
	data = d
	position = d.at as Vector3
	position.y = 0.0
	var r: float = float(d.radius)

	# the berm: a low ring you cross to get in, so the edge of the place is
	# a thing you physically pass rather than a coordinate
	var berm := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.9
	torus.outer_radius = r + 0.9
	torus.rings = 32
	torus.ring_segments = 6
	berm.mesh = torus
	berm.material_override = _mat(BERM, 1.0)
	berm.position.y = -0.35
	add_child(berm)

	# broken columns round the rim, thinning towards the entrance so the way
	# in reads without anybody drawing an arrow on it
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(d.id))
	var count: int = 9 if String(d.kind) == "combat" else 5
	for i in range(count):
		var a := TAU * float(i) / float(count) + rng.randf_range(-0.12, 0.12)
		var h := rng.randf_range(1.6, 3.4)
		var col := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = rng.randf_range(0.28, 0.42)
		cyl.bottom_radius = cyl.top_radius + 0.12
		cyl.height = h
		cyl.radial_segments = 8
		col.mesh = cyl
		col.material_override = _mat(STONE, 1.0)
		col.position = Vector3(cos(a) * (r - 0.4), h * 0.5 - 0.2, sin(a) * (r - 0.4))
		col.rotation = Vector3(rng.randf_range(-0.11, 0.11), rng.randf(), rng.randf_range(-0.11, 0.11))
		add_child(col)

	if String(d.kind) == "anchor":
		_descent_line()
	else:
		_plinth()

	_beacon()

# Where the descent chain stands, relative to the site's middle.
#
# NOT the middle, which is where it used to be and where the party spawns.
# Glass_Goat opened the build and reported "this time I started impaled":
# the chain is a 34 m pole running from the seabed to the surface through
# x=0, z=0, and Staff_Diver spawns at exactly that point.
#
# Offset diagonally rather than straight back: the other two divers stand at
# negative Z and the start camera looks along it, so a chain directly behind
# the party is both crowded and pointed at the lens. From here it is 5.1 m
# from the nearest spawn and off to one side of the opening shot.
const DESCENT_AT := Vector3(3.6, 0.0, 3.6)

# Where this site puts something solid enough to stand inside. Used by
# verify/sites.gd to check nobody spawns in it.
func furniture_points() -> Array:
	if String(data.get("kind", "")) == "anchor":
		return [global_position + DESCENT_AT]
	return [global_position]

# where you came down. It is the only thing on the map that points at the
# surface, and it is what an ending would eventually bookend.
func _descent_line() -> void:
	var chain := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.09
	cyl.height = 34.0
	cyl.radial_segments = 6
	chain.mesh = cyl
	chain.material_override = _mat(Color(0.34, 0.30, 0.24), 0.85)
	chain.position = DESCENT_AT + Vector3(0.0, 17.0, 0.0)
	add_child(chain)
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.7, 1.5)
	block.mesh = box
	block.material_override = _mat(Color(0.22, 0.22, 0.24), 0.9)
	block.position = DESCENT_AT + Vector3(0.0, 0.35, 0.0)
	add_child(block)

# what the salvage stands on, so the thing you came for is presented rather
# than dropped on the floor
func _plinth() -> void:
	var p := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.15
	cyl.bottom_radius = 1.45
	cyl.height = 0.7
	cyl.radial_segments = 12
	p.mesh = cyl
	p.material_override = _mat(STONE, 0.95)
	p.position.y = 0.35
	p.name = "Plinth"
	add_child(p)

# The site's own light is an A/B-testable point-of-interest cue: amber while
# the place is unvisited, green after the party has reached it. Route beacons
# never reveal whether this site contains an item; Mermaid's sonar still does
# that job.
func _beacon() -> void:
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.18
	cyl.height = 2.6
	cyl.radial_segments = 8
	post.mesh = cyl
	post.material_override = _mat(Color(0.20, 0.22, 0.23), 0.9)
	post.position = Vector3(float(data.radius) - 1.2, 1.3, 0.0)
	add_child(post)

	lamp_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.32
	s.height = 0.64
	s.radial_segments = 10
	s.rings = 6
	lamp_mesh.mesh = s
	lamp_mesh.position = post.position + Vector3(0, 1.5, 0)
	add_child(lamp_mesh)

	lamp = OmniLight3D.new()
	lamp.omni_range = 16.0
	lamp.position = lamp_mesh.position
	add_child(lamp)
	_tint(Color(1.0, 0.76, 0.36))

func _process(dt: float) -> void:
	_t += dt
	if lamp == null:
		return
	if cleared:
		lamp.light_energy = 1.4
	else:
		lamp.light_energy = 3.0 + sin(_t * 2.2) * 1.2

func set_cleared(v: bool) -> void:
	cleared = v
	_tint(Color(0.45, 0.95, 0.62) if v else Color(1.0, 0.76, 0.36))

func _tint(c: Color) -> void:
	if lamp != null:
		lamp.light_color = c
	if lamp_mesh != null:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.2
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lamp_mesh.material_override = m

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
