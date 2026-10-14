# One seabed site: broken columns round the rim, plus a berm ring unless it guards an item.
# No centre plinth, so guarded item locations aren't signposted before sonar discovery.
class_name Site
extends Node3D

const STONE := Color(0.15, 0.20, 0.21)
const BERM := Color(0.19, 0.25, 0.25)

var data: Dictionary = {}
func build(d: Dictionary) -> void:
	data = d
	position = d.at as Vector3
	position.y = 0.0
	var r: float = float(d.radius)

	# Berm ring; item sites omit it so they aren't signposted.
	if String(d.get("item", "")) == "":
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

	# Columns thin toward the entrance so the way in reads.
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

# Descent chain offset from the centre (the spawn point) and off to the side of the opening camera.
const DESCENT_AT := Vector3(3.6, 0.0, 3.6)

# Solid-ish points to keep spawns off; verify/sites.gd checks them. The centre stays reserved.
func furniture_points() -> Array:
	if String(data.get("kind", "")) == "anchor":
		return [global_position + DESCENT_AT]
	return [global_position]

# The descent chain: the only marker pointing to the surface.
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

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
