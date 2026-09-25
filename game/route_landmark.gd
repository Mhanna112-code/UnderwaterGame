# A route destination needs to look like the thing its objective names.
#
# Beacons say *where next*; this node says *what that place is*.  These are
# deliberately mesh-only landmarks: a route landmark is allowed to frame a
# fight, never to create an unexplained navigation wall.  The live route
# trigger owns combat, while this class owns the readable environmental story.
class_name RouteLandmark
extends Node3D

const KIND_NONE := ""
const KIND_REEF_PASSAGE := "reef_passage"
const REEF_OPENING_WIDTH := 8.0

var kind := KIND_NONE

func build_for(objective_id: String, at: Vector3) -> bool:
	position = Vector3(at.x, 0.0, at.z)
	if objective_id != "shallow_capstone":
		return false
	kind = KIND_REEF_PASSAGE
	name = "ReefPassageLandmark"
	_build_reef_passage()
	return true

# Stable review seam: callers can verify the named destination exists and
# remains safe to traverse without coupling to individual mesh node names.
func presentation() -> Dictionary:
	return {
		"kind": kind,
		"opening_width": REEF_OPENING_WIDTH if kind == KIND_REEF_PASSAGE else 0.0,
		"collision_free": _contains_no_collision(self),
	}

func _build_reef_passage() -> void:
	# Two living reef buttresses and a broken coral arch leave a deliberately
	# broad central opening.  The capstone happens *at* a passage to deeper
	# water, instead of at another anonymous lamp in empty water.
	for side in [-1.0, 1.0]:
		_build_buttress(side)

	# The roof is deliberately built out of large, overlapping reef shelves,
	# not a thin procedural ring. From the player's normal water-level camera
	# it reads as a place they can swim *through*: a heavy coral-and-stone
	# gateway over two anchored sides. Its visual span is wider than the public
	# 8 m opening contract, and it remains mesh-only so what the eye calls a
	# passage cannot secretly be a wall.
	_build_coral_arch()
	_add_glow(Vector3(-4.1, 3.6, 0.15), Color(0.12, 0.85, 0.60), 1.3, 7.0)
	_add_glow(Vector3(4.1, 3.6, 0.15), Color(0.98, 0.40, 0.22), 1.15, 7.0)
	_add_glow(Vector3(0.0, 4.6, 1.2), Color(0.20, 0.72, 0.66), 1.4, 10.0)

	# An invisible semantic marker makes the portal's intended center easy for
	# map/review consumers to identify without ever becoming a physics body.
	var opening := Node3D.new()
	opening.name = "ReefPassageOpening"
	opening.set_meta("clear_width", REEF_OPENING_WIDTH)
	add_child(opening)

func _build_buttress(side: float) -> void:
	var base_x := side * (REEF_OPENING_WIDTH * 0.5 + 1.25)
	_add_rock("ReefBase", Vector3(base_x, 0.58, 0.0), Vector3(2.6, 1.25, 2.15),
		Color(0.10, 0.24, 0.25))
	_add_rock("ReefShelf", Vector3(base_x - side * 0.48, 1.45, -0.42), Vector3(1.72, 1.45, 1.34),
		Color(0.12, 0.32, 0.30))
	_add_rock("ReefBoulder", Vector3(base_x + side * 0.72, 0.76, 1.18), Vector3(1.42, 1.42, 1.25),
		Color(0.09, 0.28, 0.29))
	_add_rock("ReefBoulder", Vector3(base_x - side * 0.98, 0.52, -1.16), Vector3(1.24, 1.02, 1.08),
		Color(0.13, 0.34, 0.32))
	_add_cylinder("ReefSpire", Vector3(base_x, 2.72, 0.05), 0.40, 0.72, 3.9,
		Color(0.16, 0.48, 0.39), Vector3(side * 0.10, 0.0, side * 0.08))
	# Coral tubes make this read as a reef rather than another stone corridor.
	var palette := [Color(0.12, 0.78, 0.57), Color(0.94, 0.38, 0.20), Color(0.56, 0.30, 0.75)]
	for i in range(6):
		var row := float(i / 3)
		var col := float((i % 3) - 1)
		var height := 1.25 + float(i % 3) * 0.38
		var p := Vector3(base_x - side * (0.55 + row * 0.42), height * 0.5 + 0.5, col * 0.46 + row * 0.24)
		_add_cylinder("CoralTube", p, 0.10, 0.20, height, palette[i % palette.size()],
			Vector3(side * (0.14 + row * 0.08), 0.0, col * 0.10))
	# Flat branching fans behind the opening add silhouette without narrowing it.
	for i in range(3):
		var fan := MeshInstance3D.new()
		fan.name = "CoralFan"
		var sphere := SphereMesh.new()
		sphere.radius = 0.64
		sphere.height = 1.28
		sphere.radial_segments = 8
		sphere.rings = 4
		fan.mesh = sphere
		fan.scale = Vector3(0.22, 1.0, 1.0)
		fan.position = Vector3(base_x + side * 0.68, 1.34 + float(i) * 0.36, -0.88 + float(i) * 0.66)
		fan.rotation = Vector3(0.0, side * 0.54, side * 0.24)
		fan.material_override = _material(palette[(i + 1) % palette.size()], 0.42)
		add_child(fan)

func _build_coral_arch() -> void:
	# A broad three-piece reef lintel is much more legible than a thin ring at
	# gameplay distance. The slight vertical stagger makes it organic while
	# still leaving a clean, unmistakable central passage below.
	_add_rock("ReefArchLeft", Vector3(-2.85, 4.72, 0.0), Vector3(3.35, 1.25, 1.72),
		Color(0.19, 0.53, 0.45), 0.30)
	_add_rock("ReefArchCenter", Vector3(0.0, 5.12, -0.06), Vector3(3.80, 1.50, 1.94),
		Color(0.22, 0.60, 0.50), 0.34)
	_add_rock("ReefArchRight", Vector3(2.85, 4.72, 0.0), Vector3(3.35, 1.25, 1.72),
		Color(0.18, 0.49, 0.43), 0.30)
	# Uneven coral growth brings the route accent colours over the *gateway*,
	# not just the flanking rocks.
	var palette := [Color(0.12, 0.82, 0.58), Color(0.95, 0.40, 0.21), Color(0.61, 0.34, 0.78)]
	for i in range(11):
		var knot := MeshInstance3D.new()
		knot.name = "ArchCoralGrowth"
		var mesh := SphereMesh.new()
		mesh.radius = 0.34 + float(i % 2) * 0.09
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 7
		mesh.rings = 4
		knot.mesh = mesh
		var x := -3.55 + float(i) * 0.71
		var y := 4.24 + (0.54 if i % 2 == 0 else 0.15)
		knot.position = Vector3(x, y, 0.76 + float(i % 3) * 0.16)
		knot.scale = Vector3(1.18, 1.08, 0.76)
		knot.material_override = _material(palette[i % palette.size()], 0.48)
		add_child(knot)

func _add_rock(node_name: String, at: Vector3, scale_by: Vector3, color: Color,
		emission_energy := 0.0) -> void:
	var rock := MeshInstance3D.new()
	rock.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	rock.mesh = mesh
	rock.position = at
	rock.scale = scale_by
	rock.material_override = _material(color, emission_energy)
	add_child(rock)

func _add_cylinder(node_name: String, at: Vector3, top_radius: float, bottom_radius: float,
		height: float, color: Color, lean: Vector3) -> void:
	var coral := MeshInstance3D.new()
	coral.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 7
	coral.mesh = mesh
	coral.position = at
	coral.rotation = lean
	coral.material_override = _material(color, 0.38)
	add_child(coral)

func _add_glow(at: Vector3, color: Color, energy: float, range_size: float) -> void:
	var glow := OmniLight3D.new()
	glow.name = "ReefBioluminescence"
	glow.position = at
	glow.light_color = color
	glow.light_energy = energy
	glow.omni_range = range_size
	add_child(glow)

func _material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material

func _contains_no_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return false
	for child in node.get_children():
		if not _contains_no_collision(child):
			return false
	return true
