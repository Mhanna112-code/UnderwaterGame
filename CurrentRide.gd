extends Path3D
# This script sits on the CurrentPath node itself, so "the path" is self.
@onready var path: Path3D = self
# StartTrigger is a sibling of this path (both under the scene root), not a
# child, so its node path goes up one level first.
@onready var start_trigger: Area3D = $"../StartTrigger"

# The rider: Maxilani ("Staff_Diver" - Diver.BASE_STATS has her as the swap
# + sonar diver). Spawned by _spawn_maxilani() at the start of _ready().
var diver: Diver

# Makes Maxilani, adds her to the scene (next to this path, not under it, so
# she doesn't move if the path node is moved) at the path's first point.
func _spawn_maxilani() -> void:
	diver = Diver.new()
	diver.model_name = "Staff_Diver"
	get_parent().add_child.call_deferred(diver)
	await diver.ready
	diver.global_position = to_global(curve.get_point_position(0))
var minigame_start: bool
func _ready() -> void:
	minigame_start = true
	await _spawn_maxilani()
	var curve := path.curve

	var local := path.to_local(diver.global_position)
	var offset := curve.get_closest_offset(local)           # distance along the spline
	var center := path.to_global(curve.sample_baked(offset))
	var ahead  := path.to_global(curve.sample_baked(offset + 0.5))
	var flow_dir := (ahead - center).normalized()           # direction the current flows here
	var from_center := diver.global_position - center      # how far off the centreline
	const TUBE_RADIUS := 2.0
	const FLOW_SPEED := 9.0
	const WALL_PULL := 6.0
	start_trigger.global_position = path.to_global(curve.get_point_position(0))

	var push := flow_dir * FLOW_SPEED
	var dist := from_center.length()
	if dist > TUBE_RADIUS * 0.7:          # near the edge: pull back toward the middle, gently at first
		var t := (dist - TUBE_RADIUS * 0.7) / (TUBE_RADIUS * 0.3)
		push -= from_center.normalized() * WALL_PULL * t
	diver.external_push = push

	start_trigger.body_entered.connect(_on_start_trigger_entered)

func _on_start_trigger_entered(_body: Node3D) -> void:
	while minigame_start:
		var local := path.to_local(diver.global_position)
		var offset := curve.get_closest_offset(local)           # distance along the spline
		var ahead := path.to_global(curve.sample_baked(offset + 0.5))    # 0.5 m along the curve
		start_trigger.look_at(ahead, Vector3.UP) 

# --- Rock bars to dodge ---------------------------------------------------------
# Every SPAWN_EVERY seconds a new rock bar is built SPAWN_AHEAD metres further
# along the spline than the sphere. It's a twisted prism: a polygon of 4-8
# corners, squashed into a long thin shape and laid across the middle of the
# view at a random angle (left-right, up-down or diagonal) - BAR_LENGTH from
# its middle to each end, so it spans the whole sphere and you have to swim
# to one side of it. Instead of being extruded in a straight line, the
# polygon is swept along the spline itself for DODGE_SECONDS worth of travel
# (so it follows the path's bends), turning by up to 45 degrees along the
# way, so you have to keep moving to stay clear. Each bar's shape comes from
# its own seed. Bars are removed once the sphere is well past them.
const SPAWN_EVERY := 4.0        # seconds between bars
const SPAWN_AHEAD := 20.0       # how far ahead along the path a new bar starts
const DODGE_SECONDS := 2.0      # how long a bar lasts as you pass through it
const BAR_LENGTH := 7.5         # middle to each end - past the sphere's edge (SHELL_RADIUS 6)
const BAR_THICKNESS := 0.3      # how thin the bar is, as a fraction of BAR_LENGTH
const RING_STEP := 1.0          # metres between cross-sections along the path
const HIT_COOLDOWN := 1.0       # seconds between hits
const HIT_DAMAGE := 2
const OBSTACLE_LAYER := 1 << 4  # its own layer: hits are checked, not bumped into

@export var cliff_seed := 0     # 0 = different bars every run
var _bar_rng: RandomNumberGenerator
var _spawn_timer := 2.0
var _bars: Array[Dictionary] = []   # {"node": StaticBody3D, "end": distance along the path}
var _hit_cooldown := 0.0

# Returns false (and builds nothing) if there isn't room for a whole bar
# before the path's end - the caller just tries again next frame.
func spawn_and_extrude_cliffs() -> bool:
	var length := curve.get_baked_length()
	var bar_length := TRIGGER_SPEED * DODGE_SECONDS
	var start := trigger_progress + SPAWN_AHEAD
	if start + bar_length > length:
		return false   # not enough path left before it loops
	if _bar_rng == null:
		_bar_rng = RandomNumberGenerator.new()
		_bar_rng.seed = cliff_seed if cliff_seed != 0 else randi()
	var shape_rng := RandomNumberGenerator.new()
	shape_rng.seed = _bar_rng.randi()   # this bar's own seed
	var sides := shape_rng.randi_range(4, 8)
	var twist := deg_to_rad(shape_rng.randf_range(-45.0, 45.0))
	var lay_angle := shape_rng.randf() * PI   # across the view, any direction
	# The cross-section: a lumpy polygon, stretched along the bar.
	var outline: Array[Vector2] = []
	for i in sides:
		var a := TAU * i / sides
		var r := shape_rng.randf_range(0.85, 1.15)
		outline.append(Vector2(cos(a) * r * BAR_LENGTH, sin(a) * r * BAR_LENGTH * BAR_THICKNESS))
	# One ring of points per RING_STEP along the path, each turned a little
	# more, placed across the path at that spot.
	var rings: Array = []
	var steps := maxi(int(bar_length / RING_STEP), 1)
	for k in steps + 1:
		var f := float(k) / float(steps)
		var d := start + bar_length * f
		var centre := to_global(curve.sample_baked(d))
		var fwd := (to_global(curve.sample_baked(minf(d + 2.0, length))) - to_global(curve.sample_baked(maxf(d - 2.0, 0.0)))).normalized()
		var up_hint := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.BACK
		var frame := Basis.looking_at(fwd, up_hint)
		var turn := lay_angle + twist * f
		var ring: Array[Vector3] = []
		for p in outline:
			var q := p.rotated(turn)
			ring.append(centre + frame.x * q.x + frame.y * q.y)
		rings.append(ring)
	var mesh := _sweep_mesh(rings)
	var body := StaticBody3D.new()
	body.name = "RockBar"
	body.collision_layer = OBSTACLE_LAYER
	body.collision_mask = 0
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.38, 0.34, 0.3)
	stone.roughness = 1.0
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED   # winding can't hide a face
	mesh_instance.material_override = stone
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	get_parent().add_child(body)
	body.global_transform = Transform3D.IDENTITY   # the points are already in world space
	_bars.append({"node": body, "end": start + bar_length})
	return true

# Joins each ring to the next (the sides) and closes both ends with the
# polygon itself (the caps) - the twisted prism, swept along the path.
func _sweep_mesh(rings: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # flat, faceted rock
	var n: int = (rings[0] as Array).size()
	for k in rings.size() - 1:
		var a: Array = rings[k]
		var b: Array = rings[k + 1]
		for i in n:
			var j := (i + 1) % n
			_tri(st, a[i], b[i], a[j])
			_tri(st, a[j], b[i], b[j])
	var first: Array = rings[0]
	var last: Array = rings[rings.size() - 1]
	for i in range(1, n - 1):
		_tri(st, first[0], first[i + 1], first[i])
		_tri(st, last[0], last[i], last[i + 1])
	st.generate_normals()
	return st.commit()

# Spawning on a timer, clearing bars that are behind, and checking whether
# the diver is touching one (her capsule against the bars' layer).
func _update_bars(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and spawn_and_extrude_cliffs():
		_spawn_timer = SPAWN_EVERY
	for i in range(_bars.size() - 1, -1, -1):
		var bar: Dictionary = _bars[i]
		var end := float(bar["end"])
		# Passed it - or the ride looped back to the start.
		if end < trigger_progress - 10.0 or end - trigger_progress > SPAWN_AHEAD + TRIGGER_SPEED * DODGE_SECONDS + 5.0:
			(bar["node"] as Node).queue_free()
			_bars.remove_at(i)
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	if diver == null or not diver.is_inside_tree() or _hit_cooldown > 0.0 or _bars.is_empty():
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = DIVER_RADIUS
	capsule.height = 1.9
	query.shape = capsule
	query.transform = diver.global_transform
	query.collision_mask = OBSTACLE_LAYER
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		_hit_cooldown = HIT_COOLDOWN
		on_hit_rock_bar()

# Maxilani touched a rock bar: she flashes and loses a little HP.
func on_hit_rock_bar() -> void:
	diver.flash_damage()
	if diver.stats != null:
		diver.stats.hp = maxi(1, diver.stats.hp - HIT_DAMAGE)
	var label := get_node_or_null("../HUD/Controls") as Label
	if label != null:
		label.text = "Hit by the rocks! (-%d HP)" % HIT_DAMAGE

func make_twisted_prism(shape_seed: int, radius := 2.0, height := 3.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	var sides := rng.randi_range(4, 8)
	var twist := deg_to_rad(rng.randf_range(-45.0, 45.0))

	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides
		var r := radius * rng.randf_range(0.85, 1.15)          # optional roughness
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		bottom.append(p)
		top.append(p.rotated(Vector3.UP, twist) + Vector3.UP * height)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)              # flat, faceted shading
	# Sides: each original edge joined to its rotated partner.
	for i in sides:
		var j := (i + 1) % sides
		_tri(st, bottom[i], top[i], bottom[j])
		_tri(st, bottom[j], top[i], top[j])
	# Caps: the original face at the bottom, the flipped one on top.
	for i in range(1, sides - 1):
		_tri(st, bottom[0], bottom[i + 1], bottom[i])   # facing down
		_tri(st, top[0], top[i], top[i + 1])            # facing up (reversed order)
	st.generate_normals()
	return st.commit()

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
# --- StartTrigger travelling the spline, Star Fox style camera --------------
# Every physics frame the trigger moves TRIGGER_SPEED metres further along the
# curve (wrapping back to the start at the end) and turns to face the way the
# curve goes - climbs and dips too. The camera is locked to the trigger at a
# fixed spot behind and above it, with no easing or lag, so on screen the
# trigger never moves: the world scrolls and turns around it instead, like a
# rail shooter.
#
# The facing is aimed at a point LOOK_AHEAD metres further along and eased,
# because this curve's points have no handles - it has sharp corners, and the
# exact direction at a corner jumps. Easing it is what makes the view swing
# smoothly round a bend instead of snapping.
const TRIGGER_SPEED := 6.0      # metres per second along the curve
const FOLLOW_DISTANCE := 12.0   # how far behind the trigger the camera sits
const FOLLOW_HEIGHT := 4.0      # how far above it
const LOOK_AHEAD := 4.0         # metres ahead used to work out "forward"
const TURN_EASE := 3.0          # higher = the view turns more quickly at bends

@onready var camera: Camera3D = $"../StartTrigger/Camera3D"
var trigger_progress := 0.0     # how far along the curve the trigger is (metres)
var _forward := Vector3.ZERO

func _physics_process(delta: float) -> void:
	var length := curve.get_baked_length()
	if length <= 0.0:
		return
	# 1. Move the trigger along the spline.
	trigger_progress = fmod(trigger_progress + TRIGGER_SPEED * delta, length)
	var here := to_global(curve.sample_baked(trigger_progress))
	var ahead := to_global(curve.sample_baked(minf(trigger_progress + LOOK_AHEAD, length)))
	if trigger_progress + LOOK_AHEAD > length:
		# Near the end: keep pointing the way the last stretch goes.
		ahead = here + (here - to_global(curve.sample_baked(maxf(trigger_progress - LOOK_AHEAD, 0.0))))
	var want_forward := (ahead - here).normalized()
	if _forward == Vector3.ZERO:
		_forward = want_forward
	_forward = _forward.slerp(want_forward, clampf(delta * TURN_EASE, 0.0, 1.0)).normalized()
	# 2. Face along the curve. The camera rides along as the trigger's child,
	# so this alone moves and turns it.
	var up := Vector3.UP if absf(_forward.dot(Vector3.UP)) < 0.98 else Vector3.BACK
	start_trigger.global_transform = Transform3D(Basis.looking_at(_forward, up), here)
	# 3. Keep the camera locked behind and above (the trigger faces -Z, so
	# "behind" is +Z), looking at the trigger's middle.
	if camera != null:
		camera.position = Vector3(0.0, FOLLOW_HEIGHT, FOLLOW_DISTANCE)
		camera.basis = Basis.looking_at(-camera.position, Vector3.UP)
	# 4. Carry Maxilani along inside the sphere, and notice her hitting its wall.
	_ride_diver(here, delta)
	# 5. Rock bars: spawn ahead, clear behind, check for hits.
	_update_bars(delta)

# --- The sphere: bounds the diver can't leave -------------------------------
# A hollow, solid sphere of SHELL_RADIUS around the StartTrigger, riding along
# as its child. It's an AnimatableBody3D (not a StaticBody3D) because it moves
# every frame: an AnimatableBody pushes the diver along properly instead of
# teleporting through her. Its shape is the sphere's own triangles with
# backface collision on, so the INSIDE of the shell is solid - the diver
# (a CharacterBody3D using move_and_slide) slides along it.
#
# The StartTrigger also gets a matching Area3D sphere, if it has no shape of
# its own yet, so body_entered can fire.
const SHELL_RADIUS := 6.0       # about the size of the camera's view at the trigger
const DIVER_STEER := 1.0        # 1 = the diver's own full swim speed when steering

var shell_body: AnimatableBody3D
var _last_here := Vector3.ZERO
var _was_touching := false

func _build_shell() -> void:
	shell_body = AnimatableBody3D.new()
	shell_body.name = "Shell"
	shell_body.collision_layer = 1      # the diver collides with layer 1
	shell_body.collision_mask = 0
	# It just moves with the trigger. With physics syncing on, a moving
	# AnimatableBody hands its own motion to characters near it as "platform
	# velocity" - which kicked the diver about inside it.
	shell_body.sync_to_physics = false
	var sphere := SphereMesh.new()
	sphere.radius = SHELL_RADIUS
	sphere.height = SHELL_RADIUS * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var hollow := ConcavePolygonShape3D.new()
	hollow.set_faces(sphere.get_faces())
	hollow.backface_collision = true    # inner faces count as solid too
	var shape := CollisionShape3D.new()
	shape.shape = hollow
	shell_body.add_child(shape)
	start_trigger.add_child(shell_body)
	var has_shape := false
	for c in start_trigger.get_children():
		if c is CollisionShape3D:
			has_shape = true
	if not has_shape:
		var area_shape := CollisionShape3D.new()
		var ball := SphereShape3D.new()
		ball.radius = SHELL_RADIUS
		area_shape.shape = ball
		start_trigger.add_child(area_shape)
	start_trigger.collision_mask = 2    # divers are on layer 2

# Every physics frame (after the trigger has moved): carry Maxilani along
# with the sphere - she keeps her spot inside it, moved and turned exactly as
# the sphere moved and turned this frame - then let the player steer her
# around inside it (A/D left/right, W/S or Space/Shift up/down, relative to
# the camera), move her, and check whether that ran her into the sphere's
# inner wall.
#
# Carrying her directly (rather than pushing her with a current and leaving
# the moving shell to shove her) is what keeps her inside: a solid shape that
# is repositioned every frame doesn't push a character along, it passes
# through her. The shell only has to stop her own steering, which it does.
func _ride_diver(here: Vector3, delta: float) -> void:
	var basis_now := start_trigger.global_basis
	if shell_body == null:
		_build_shell()
		_last_here = here
		_last_basis = basis_now
	if diver == null or not diver.is_inside_tree():
		_last_here = here
		_last_basis = basis_now
		return
	if not _was_placed:
		diver.global_position = here    # start in the middle of the sphere
		# She's carried by this script, so she mustn't also pick up the
		# moving shell's motion as if it were a platform she touched.
		diver.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
		diver.platform_floor_layers = 0
		diver.platform_wall_layers = 0
		_was_placed = true
	# Carry: same offset from the centre, turned by however the sphere turned.
	var turned := basis_now * _last_basis.inverse()
	diver.global_position = here + turned * (diver.global_position - _last_here)
	_last_here = here
	_last_basis = basis_now
	diver.external_push = Vector3.ZERO
	# Steering in the screen's plane.
	var side := 0.0
	var rise := 0.0
	if Input.is_key_pressed(KEY_D):
		side += 1.0
	if Input.is_key_pressed(KEY_A):
		side -= 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE):
		rise += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SHIFT):
		rise -= 1.0
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	diver.swim(right * side * DIVER_STEER, rise, delta)   # applies external_push, then move_and_slide()
	# Did that move hit the inside of the sphere? (Only filled in after
	# move_and_slide, which swim() just ran.)
	var touching := false
	for i in diver.get_slide_collision_count():
		var hit := diver.get_slide_collision(i)
		if hit.get_collider() == shell_body:
			# get_normal() points away from the wall it hit - on the inside
			# of a sphere, that's in towards the centre.
			touching = true
			if not _was_touching:
				on_hit_inner_wall(hit.get_position(), hit.get_normal())
	_was_touching = touching
	# Backstop: if she ever ends up outside the sphere anyway (a very sharp
	# turn), put her back just inside its edge.
	var from_centre := diver.global_position - here
	var limit := SHELL_RADIUS - DIVER_RADIUS - 0.05
	if from_centre.length() > limit:
		diver.global_position = here + from_centre.normalized() * limit

var _was_placed := false
var _last_basis := Basis.IDENTITY
const DIVER_RADIUS := 0.4      # the diver capsule's radius

# The moment Maxilani first touches the sphere's wall (not every frame she's
# against it). The wall itself already stops her dead and lets her slide
# along it, like an invisible wall - nothing extra happens here. Add a sound,
# bubbles, damage... if you want any.
func on_hit_inner_wall(_at: Vector3, _normal: Vector3) -> void:
	pass
