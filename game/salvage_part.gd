# The thing you came down here for.
#
# Marc's ruling: you take what the creature is guarding, and it is a component
# for the rig on the surface. That makes this object the reason the game
# exists, so it cannot be a gold box. It is built here rather than modelled
# because no art delivery contains one, and a placeholder that reads as a
# placeholder is what made the enemies feel like they had no meaning.
#
# A pressure regulator: brass housing, a valve wheel you could actually turn,
# bolted flanges, and a lit gauge. The gauge is the point of the whole design.
# It is the only warm light on a cold seabed, so it pulls the eye from far
# enough away that the player swims to it without being told to.
class_name SalvagePart
extends Node3D

const BRASS := Color(0.80, 0.60, 0.24)      # fittings, wheel, flanges
const IRON := Color(0.24, 0.26, 0.27)       # the housing itself
const DARK := Color(0.16, 0.16, 0.17)       # collars and bolts
const VERDIGRIS := Color(0.30, 0.52, 0.44)  # what the sea has done to it
const GAUGE := Color(1.0, 0.74, 0.30)

var _spin := 0.0
var wheel: Node3D

func _ready() -> void:
	# Brass everywhere read as one moulded lump. The housing is iron and the
	# fittings are brass, which is both how the thing would be built and the
	# only reason its shapes separate at a distance.
	var body := _mat(BRASS, 0.9, 0.28)
	var iron := _mat(IRON, 0.75, 0.62)
	var dark := _mat(DARK, 0.6, 0.7)
	var green := _mat(VERDIGRIS, 0.2, 0.85)

	# main housing, a stout barrel lying on its side
	_cyl(Vector3(0, 0, 0), 0.30, 0.62, iron, Vector3(0, 0, PI * 0.5))
	# rivets down the belly of the housing
	for r in range(10):
		var ra := TAU * float(r) / 10.0
		_sphere(Vector3(0.0, cos(ra) * 0.30, sin(ra) * 0.30), 0.028, dark)
	# the collar rings that make it read as machined rather than as a tube
	_torus(Vector3(0.26, 0, 0), 0.28, 0.33, dark, Vector3(0, 0, PI * 0.5))
	_torus(Vector3(-0.26, 0, 0), 0.28, 0.33, dark, Vector3(0, 0, PI * 0.5))

	# pipe stubs out of each end, capped with bolted flanges
	for s in [-1.0, 1.0]:
		_cyl(Vector3(0.45 * s, 0, 0), 0.13, 0.34, iron, Vector3(0, 0, PI * 0.5))
		_torus(Vector3(0.60 * s, 0, 0), 0.15, 0.23, body, Vector3(0, 0, PI * 0.5))
		for b in range(6):
			var a := TAU * float(b) / 6.0
			_cyl(Vector3(0.62 * s, cos(a) * 0.19, sin(a) * 0.19), 0.022, 0.05, dark, Vector3(0, 0, PI * 0.5))

	# a crust of growth on the underside: it has been down here a while
	_sphere(Vector3(-0.10, -0.26, 0.14), 0.10, green)
	_sphere(Vector3(0.17, -0.24, -0.10), 0.08, green)
	_sphere(Vector3(0.02, -0.28, -0.17), 0.06, green)
	_sphere(Vector3(-0.22, 0.16, -0.22), 0.07, green)
	_sphere(Vector3(0.21, 0.20, 0.16), 0.05, green)

	# the valve wheel, on top, turning slowly
	wheel = Node3D.new()
	wheel.position = Vector3(0, 0.34, 0)
	add_child(wheel)
	_torus(Vector3.ZERO, 0.17, 0.22, body, Vector3.ZERO, wheel)
	for i in range(4):
		var a2 := TAU * float(i) / 4.0
		var spoke := _cyl(Vector3(cos(a2) * 0.10, 0, sin(a2) * 0.10), 0.022, 0.21, body, Vector3(0, 0, PI * 0.5), wheel)
		spoke.rotation = Vector3(0, -a2, PI * 0.5)
	_cyl(Vector3(0, -0.06, 0), 0.05, 0.14, dark, Vector3.ZERO, wheel)

	# the gauge: the one warm thing on the seabed
	# the gauge, dimmer than the first pass: at 2.4 energy it blew to flat
	# white and swallowed its own needle, which is the one detail on it
	var face := _cyl(Vector3(0, 0.06, 0.30), 0.13, 0.06, _emissive(GAUGE, 0.9), Vector3(PI * 0.5, 0, 0))
	face.name = "Gauge"
	_torus(Vector3(0, 0.06, 0.31), 0.125, 0.175, body, Vector3(PI * 0.5, 0, 0))
	# the needle, sitting at a pressure nobody has read in years
	var needle := _box(Vector3(0.03, 0.09, 0.336), Vector3(0.016, 0.10, 0.016), _mat(Color(0.05, 0.04, 0.04), 0.1, 0.5))
	needle.rotation = Vector3(0, 0, deg_to_rad(-38.0))
	_cyl(Vector3(0.0, 0.06, 0.338), 0.022, 0.02, dark, Vector3(PI * 0.5, 0, 0))

	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.84, 0.5)
	glow.light_energy = 3.0
	glow.omni_range = 9.0
	glow.position = Vector3(0, 0.1, 0.42)
	add_child(glow)

func _process(dt: float) -> void:
	_spin += dt
	if wheel != null:
		wheel.rotation.y = _spin * 0.35
	position.y += sin(_spin * 0.9) * dt * 0.06     # it stirs in the current

func _mat(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m

func _emissive(c: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _cyl(at: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = 20
	return _put(mesh, at, mat, rot, parent)

func _torus(at: Vector3, inner: float, outer: float, mat: Material, rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 20
	mesh.ring_segments = 10
	return _put(mesh, at, mat, rot, parent)

func _sphere(at: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 1.6
	mesh.radial_segments = 10
	mesh.rings = 6
	return _put(mesh, at, mat)

func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _put(mesh, at, mat)

func _put(mesh: Mesh, at: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	(parent if parent != null else self).add_child(mi)
	return mi
