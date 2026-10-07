# Particle column inside a Whirlpool's suction Area3D. A bottom "head" bounces
# around the area's bounds; each upper layer replays the head's path a little
# later, so the column trails up from the bottom. With x = height above the
# bottom / full height: scale = 1 + (1 - x) (2 at the bottom, 1 at the top).
extends Node3D

const LAYERS := 16
const HISTORY_SECONDS := 4.0   # keep at least as long as the largest delay
const PARTICLE_RADIUS := 0.14

var radius := 3.0              # horizontal bound, from the suction shape
var height := 4.0              # bottom-to-top distance, from the suction shape
var max_delay := 1.5           # seconds the top layer lags behind the bottom

var _head := Vector2.ZERO           # bottom particle x/z (local)
var _head_velocity := Vector2.ZERO  # x/z units per second
var _history: Array = []            # [time, Vector2], oldest first
var _time := 0.0
var _multimesh: MultiMesh

# Size the column to the Area3D's shape (centred on the area's origin).
func setup(shape: Shape3D) -> void:
	if shape is CylinderShape3D:
		radius = (shape as CylinderShape3D).radius
		height = (shape as CylinderShape3D).height
	elif shape is SphereShape3D:
		radius = (shape as SphereShape3D).radius
		height = radius * 2.0
	elif shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		radius = minf(size.x, size.z) * 0.5
		height = size.y

func _ready() -> void:
	# The parent Whirlpool processes while paused; the column shouldn't.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var dot := SphereMesh.new()
	dot.radius = PARTICLE_RADIUS
	dot.height = PARTICLE_RADIUS * 2.0
	dot.radial_segments = 8
	dot.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.93, 1.0, 0.7)
	dot.material = mat
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = dot
	_multimesh.instance_count = LAYERS
	_multimesh.visible_instance_count = 0   # layers appear one by one
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = _multimesh
	inst.custom_aabb = AABB(Vector3(-radius - 1.0, -height * 0.5 - 1.0, -radius - 1.0),
		Vector3(radius * 2.0 + 2.0, height + 2.0, radius * 2.0 + 2.0))
	add_child(inst)
	_start_head()

func _process(dt: float) -> void:
	_time += dt
	_bounce_step(dt)
	_history.append([_time, _head])
	while _history.size() > 2 and _time - float(_history[0][0]) > HISTORY_SECONDS:
		_history.pop_front()

	var shown := 0
	for i in LAYERS:
		var x := float(i) / float(LAYERS - 1)   # 0 at the bottom, 1 at the top
		var delay := _delay_for(x)
		if _time < delay:
			break   # the trail hasn't reached this layer yet
		var xz := _head_at(_time - delay)
		var s := 1.0 + (1.0 - x)
		var at := Vector3(xz.x, -height * 0.5 + x * height, xz.y)
		_multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), at))
		shown = i + 1
	_multimesh.visible_instance_count = shown

# Head position at an earlier time, interpolated from the recorded path.
func _head_at(t: float) -> Vector2:
	if _history.is_empty():
		return _head
	if t <= float(_history[0][0]):
		return _history[0][1]
	for i in range(_history.size() - 1, 0, -1):
		var t0 := float(_history[i - 1][0])
		if t0 <= t:
			var t1 := float(_history[i][0])
			var f := 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
			return (_history[i - 1][1] as Vector2).lerp(_history[i][1], f)
	return _head

# Initial head position and velocity.
func _start_head() -> void:
	_head = Vector2.ZERO
	_head_velocity = Vector2.RIGHT.rotated(randf() * TAU) * 1.5

# Head wanders at a steady speed and bounces off the area's circular bound.
func _bounce_step(dt: float) -> void:
	var speed := _head_velocity.length()
	# Small random turn each frame so the path never repeats.
	_head_velocity = _head_velocity.rotated(randf_range(-1.5, 1.5) * dt)
	_head += _head_velocity * dt
	var limit := maxf(radius - PARTICLE_RADIUS, 0.01)
	if _head.length() > limit:
		var inward := -_head.normalized()
		_head = -inward * limit   # back onto the bound
		if _head_velocity.dot(inward) < 0.0:   # only while still heading out
			# Reflect, then knock the angle a little so bounces aren't mirror-perfect.
			_head_velocity = _head_velocity.bounce(inward).rotated(randf_range(-0.6, 0.6))
			if _head_velocity.dot(inward) <= 0.0:
				_head_velocity = inward * speed   # the random knock pointed it outward
	_head_velocity = _head_velocity.normalized() * speed

# ---------------------------------------------------------------------------
# YOUR PART 2: delay for upper layers.
# Return how many seconds behind the bottom head the layer at height ratio x
# runs (x = 0 bottom, 1 top). Use x to scale it up to max_delay. Delays must
# increase with x, or the layers won't appear progressively from the bottom.
# ---------------------------------------------------------------------------
func _delay_for(x: float) -> float:
	return 0.0
