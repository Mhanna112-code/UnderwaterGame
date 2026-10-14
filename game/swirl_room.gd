class_name SwirlRoom
extends Node3D

# Room of invisible rocks orbiting its centre in concentric rings per grid layer, aligned in columns.
# Touching one damages (never below 1 HP), flashes and knocks back the diver; MazeLevel calls hit_divers() each frame.
# Rocks render only while set_revealed(true) (Maxilani's sonar in the room); positions() feeds the minimap.

const ROCK_RADIUS := 0.45       # for hits; the rocks themselves vary 0.8x-1.2x
const BOB_HEIGHT := 0.3
const CLEAR_RADIUS := 4.0        # open space around the centre (the key)
const ORBIT_SPEED := 2.5         # along the ring, units per second
const WALL_MARGIN := 0.8         # outermost ring stays this far inside the walls
const LAYER_SPACING := 1.25      # height between layers of spheres
const RING_SPACING := 4.0        # between neighbouring rock columns; room to weave through
const HIT_DAMAGE := 2
const HIT_COOLDOWN := 1.0
const KNOCKBACK_SPEED := 14.0
const KNOCKBACK_DECAY := 4.0     # per second, exponential (travel ~ SPEED / DECAY = 3.5 units)
const HIT_TINT_TIME := 0.65

signal diver_hit(diver: Diver)

# --- Grid (same shape as FlowField's) -------------------------------------------
var cell_radius := 1.5
var cell_diameter := cell_radius * 2.0

var cells := []          # [{"cellPos": Vector3, "cell_index": int}]
var cols := 0            # across the room (x)
var layers := 0          # floor to ceiling (y)
var rows := 0            # along the room (z)
var grid_origin := Vector3.ZERO   # outer corner of cell (0, 0, 0)

var room_min := Vector3.ZERO     # the room's inside, corner to corner
var room_max := Vector3.ZERO
var center := Vector3.ZERO       # on the room's vertical centre line

# --- Rings and spheres -------------------------------------------------------------
var ring_radii: Array[float] = []
var _radius := PackedFloat32Array()   # each sphere's ring radius
var _angle := PackedFloat32Array()    # its current angle around the centre
var _height := PackedFloat32Array()   # its layer height
var _phase := PackedFloat32Array()    # bob offset
var _rock_basis: Array[Basis] = []   # each rock's own turn and size
var _time := 0.0
var _mm: MultiMeshInstance3D
var _knockback: Dictionary = {}   # Diver -> remaining knockback velocity
var _cooldown: Dictionary = {}    # Diver -> seconds until it can be hit again
var _hit_tint: StandardMaterial3D

# `interior` is the room's inside on the floor plan (x across, y = world z);
# y_min..y_max is its floor-to-ceiling height.
func setup(interior: Rect2, y_min: float, y_max: float) -> void:
	room_min = Vector3(interior.position.x, y_min, interior.position.y)
	room_max = Vector3(interior.end.x, y_max, interior.end.y)
	center = (room_min + room_max) * 0.5

func _ready() -> void:
	init_maze_grid()
	_build_rings()
	_build_multimesh()

func init_cell(world_pos: Vector3, grid_index: int) -> void:
	cells.append({"cellPos": world_pos, "cell_index": grid_index})

# Equal cubes of cell_diameter, centred so leftover space splits evenly.
func init_maze_grid() -> void:
	cells.clear()
	var extent := room_max - room_min
	cols = maxi(1, int(extent.x / cell_diameter))
	layers = maxi(1, int(extent.y / LAYER_SPACING))
	rows = maxi(1, int(extent.z / cell_diameter))
	var step := Vector3(cell_diameter, LAYER_SPACING, cell_diameter)
	var used := Vector3(cols, layers, rows) * step
	grid_origin = room_min + (extent - used) * 0.5
	for k in rows:
		for j in layers:
			for i in cols:
				var world_pos := grid_origin + Vector3(i + 0.5, j + 0.5, k + 0.5) * step
				init_cell(world_pos, cell_index(i, j, k))

func cell_index(i: int, j: int, k: int) -> int:
	return (k * layers + j) * cols + i

# Rings every cell_diameter from CLEAR_RADIUS out; same angles per layer, each ring offset to avoid spokes.
func _build_rings() -> void:
	var max_radius := minf(room_max.x - center.x, room_max.z - center.z) - WALL_MARGIN - ROCK_RADIUS
	ring_radii.clear()
	var r := CLEAR_RADIUS
	while r <= max_radius:
		ring_radii.append(r)
		r += cell_diameter
	var column_phase: Dictionary = {}   # "ring:n" -> bob phase shared by the whole column
	for j in layers:
		var layer_y: float = (cells[cell_index(0, j, 0)]["cellPos"] as Vector3).y
		for ring_i in ring_radii.size():
			var radius := ring_radii[ring_i]
			var count := maxi(3, int(TAU * radius / RING_SPACING))
			var offset := float(ring_i) * 0.5
			for n in count:
				var column := "%d:%d" % [ring_i, n]
				if not column_phase.has(column):
					column_phase[column] = randf() * TAU
				_radius.append(radius)
				_angle.append(offset + TAU * n / count)
				_height.append(layer_y)
				_phase.append(float(column_phase[column]))
				_rock_basis.append(Basis(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized(), randf() * TAU).scaled(Vector3.ONE * randf_range(0.8, 1.2)))

func _build_multimesh() -> void:
	# Same lumpy low-poly rock as the maze's scenery rocks (cracked_wall.gd).
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 0.7
	rock.radial_segments = 7
	rock.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.33, 0.3)
	mat.roughness = 1.0
	# Faint cyan outline: these are being seen through sonar.
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.rim_tint = 0.0
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.55, 0.65)
	mat.emission_energy_multiplier = 0.35
	# Fade rocks near the camera so they don't hide the diver; gameplay still uses every rock.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 4.0
	mat.distance_fade_max_distance = 7.0
	rock.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock
	mm.instance_count = _radius.size()
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.visible = false
	add_child(_mm)

func _physics_process(delta: float) -> void:
	_time += delta
	for k in _radius.size():
		# Constant linear speed, so inner rings turn faster.
		_angle[k] = wrapf(_angle[k] + ORBIT_SPEED / _radius[k] * delta, 0.0, TAU)
	if _mm.visible:
		var mm := _mm.multimesh
		for k in _radius.size():
			mm.set_instance_transform(k, Transform3D(_rock_basis[k], _sphere_world(k)))

func _sphere_world(k: int) -> Vector3:
	var r := _radius[k]
	var a := _angle[k]
	return Vector3(center.x + cos(a) * r, _height[k] + sin(_time * 1.6 + _phase[k]) * BOB_HEIGHT, center.z + sin(a) * r)

# Hits and knockback for `divers` (MazeLevel calls this each physics frame).
func hit_divers(divers: Array, delta: float) -> void:
	for d in divers:
		var diver := d as Diver
		if _knockback.has(diver):
			var v: Vector3 = _knockback[diver]
			diver.move_and_collide(v * delta)
			v *= exp(-KNOCKBACK_DECAY * delta)
			if v.length() < 0.2:
				_knockback.erase(diver)
			else:
				_knockback[diver] = v
		if _cooldown.has(diver):
			_cooldown[diver] = float(_cooldown[diver]) - delta
			if float(_cooldown[diver]) <= 0.0:
				_cooldown.erase(diver)
			continue
		if not contains(diver.global_position):
			continue
		for k in _radius.size():
			var p := _sphere_world(k)
			if _touches(diver, p):
				_hit(diver, k, p)
				break

# Sphere vs the diver's capsule (a segment through its body, plus its radius).
func _touches(diver: Diver, p: Vector3) -> bool:
	var half := maxf(0.0, diver.height * 0.5 - diver.radius)
	var c := diver.global_position
	var closest := Vector3(c.x, clampf(p.y, c.y - half, c.y + half), c.z)
	return closest.distance_to(p) <= diver.radius + ROCK_RADIUS

func _hit(diver: Diver, k: int, p: Vector3) -> void:
	diver.stats.hp = maxi(1, diver.stats.hp - HIT_DAMAGE)
	_cooldown[diver] = HIT_COOLDOWN
	var away := diver.global_position - p
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0)
	var along := Vector3(-sin(_angle[k]), 0.0, cos(_angle[k]))   # the sphere's direction of travel
	_knockback[diver] = (away * 0.65 + along * 0.35).normalized() * KNOCKBACK_SPEED
	diver.velocity = Vector3.ZERO
	diver.flash_damage()
	_tint_red(diver)
	diver_hit.emit(diver)

# Red tint over the diver's model while it flickers.
func _tint_red(diver: Diver) -> void:
	if diver.model == null:
		return
	if _hit_tint == null:
		_hit_tint = StandardMaterial3D.new()
		_hit_tint.albedo_color = Color(1.0, 0.1, 0.1, 0.55)
		_hit_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hit_tint.emission_enabled = true
		_hit_tint.emission = Color(1.0, 0.1, 0.1)
		_hit_tint.emission_energy_multiplier = 1.5
		_hit_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var meshes := diver.model.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		(m as MeshInstance3D).material_overlay = _hit_tint
	get_tree().create_timer(HIT_TINT_TIME).timeout.connect(func() -> void:
		for m in meshes:
			if is_instance_valid(m) and (m as MeshInstance3D).material_overlay == _hit_tint:
				(m as MeshInstance3D).material_overlay = null)

# Where every sphere is right now (with its bob) - for the minimap.
func positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(_radius.size())
	for k in _radius.size():
		out[k] = _sphere_world(k)
	return out

func contains(world: Vector3) -> bool:
	return world.x >= room_min.x and world.x <= room_max.x and world.z >= room_min.z and world.z <= room_max.z

func set_revealed(on: bool) -> void:
	if _mm != null:
		_mm.visible = on
