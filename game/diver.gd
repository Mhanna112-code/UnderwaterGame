# A diver you can swim around. The models arrived unrigged, so there is no
# swim cycle to play: all the life in these is procedural, applied to the
# whole model rather than to bones. Bob, bank, kick-pitch and a bubble trail.
#
# Everything about the model's arrival is handled here in one place: the
# FBX stacks all four models on one origin, every mesh node carries a -90
# X rotation and a scale of 100, and the models face +Z while Godot treats
# -Z as forward. Fix it once, here, and the rest of the game can just place
# a Diver and forget the export ever had opinions.
# Named Swimmer, not Diver: sim/combat.gd carries its own inner Diver class
# for the turn-based fight, and two globals with one name fails the project
# at parse time.
class_name Swimmer
extends CharacterBody3D

const SRC := preload("res://art/characters/divers.glb")

@export var model_name := "Staff_Diver"
@export var tint := Color(1, 1, 1)

var speed := 5.0
var accel := 6.0
var drag := 2.2

var model: Node3D             # holds the mesh; all cosmetic motion lives here
var height := 1.9
var radius := 0.4
var _bob := 0.0
var _kick := 0.0
var _lean := 0.0
var bubbles: CPUParticles3D

# If the delivered model carries real swim clips, play them. If it does not,
# fall back to the procedural bob and pitch below. Glass_Goat's swim
# animations exist in Blender and have never been in an export; this is here
# so the day one arrives, wiring it is nothing.
var anim: AnimationPlayer = null
var clip_prefix := ""
var swim_clip := ""
var idle_clip := ""
var _playing := ""

# any clip whose name contains one of these is taken to be that motion
const SWIM_WORDS := ["swim", "tread", "paddle", "float", "kick_cycle"]
const IDLE_WORDS := ["idle"]

func _ready() -> void:
	var src: Node3D = SRC.instantiate()
	var mesh: MeshInstance3D = _find(src, model_name)
	if mesh == null:
		push_error("NO SUCH MODEL '%s' in the FBX" % model_name)
		return

	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	# the models face +Z and Godot's forward is -Z. That flip lives on its own
	# node so posture maths below can assume a plain -Z-forward body: folding
	# it into the same node made every pitch sign a coin toss.
	var flip := Node3D.new()
	flip.name = "Flip"
	flip.rotation.y = PI
	model.add_child(flip)

	# keep the mesh's own transform: the -90 X rotation IS what stands it up
	var keep: Transform3D = mesh.transform
	mesh.owner = null            # else reparenting warns about a stale owner
	mesh.get_parent().remove_child(mesh)
	flip.add_child(mesh)
	mesh.transform = keep

	# measure where the model actually sits, then drop its feet to the
	# body's floor. The FBX centres each model on its own origin, which is
	# not the same as standing on the ground.
	var box: AABB = _world_aabb(mesh)
	height = box.size.y
	radius = maxf(0.25, minf(box.size.x, box.size.z) * 0.5)
	mesh.position.y -= box.position.y + height * 0.5

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = maxf(height, radius * 2.0 + 0.1)
	cap.radius = radius
	shape.shape = cap
	add_child(shape)

	_find_clips(src)
	_bob = randf() * TAU
	_add_bubbles()
	src.queue_free()

func _find_clips(src: Node) -> void:
	anim = _first_player(model)
	if anim == null:
		return
	for name in anim.get_animation_list():
		var bare := String(name)
		var bar := bare.rfind("|")
		var stem := bare.substr(bar + 1).to_lower() if bar >= 0 else bare.to_lower()
		if bar >= 0 and clip_prefix == "":
			clip_prefix = bare.substr(0, bar + 1)
		if anim.get_animation(bare).length <= 0.05:
			continue                       # a zero length take is a pose
		for w in SWIM_WORDS:
			if stem.contains(w) and swim_clip == "":
				swim_clip = bare
		for w2 in IDLE_WORDS:
			if stem.contains(w2) and idle_clip == "":
				idle_clip = bare

func _first_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _first_player(c)
		if r != null:
			return r
	return null

# play a clip if the model has one for this state, and report whether it did
func _drive_clip(moving: bool) -> bool:
	if anim == null:
		return false
	var want := swim_clip if moving else idle_clip
	if want == "":
		want = idle_clip if idle_clip != "" else swim_clip
	if want == "":
		return false
	if want != _playing:
		var a: Animation = anim.get_animation(want)
		a.loop_mode = Animation.LOOP_LINEAR
		anim.play(want)
		_playing = want
	return true

func _add_bubbles() -> void:
	# CPU particles, not GPU: this has to survive the web export's
	# compatibility renderer, and a trail that only exists on desktop is
	# not a trail we can show Marc.
	bubbles = CPUParticles3D.new()
	bubbles.amount = 14
	bubbles.lifetime = 2.2
	bubbles.emitting = false
	bubbles.direction = Vector3(0, 1, 0)
	bubbles.spread = 20.0
	bubbles.initial_velocity_min = 0.6
	bubbles.initial_velocity_max = 1.3
	bubbles.gravity = Vector3(0, 1.2, 0)
	bubbles.scale_amount_min = 0.04
	bubbles.scale_amount_max = 0.11
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 6
	sphere.rings = 3
	bubbles.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.92, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubbles.mesh.surface_set_material(0, m)
	bubbles.position = Vector3(0, height * 0.35, 0)
	add_child(bubbles)

# dir: desired direction in world space, already normalised or zero.
# rise: -1..1 for down/up.
func swim(dir: Vector3, rise: float, dt: float) -> void:
	var want := dir * speed
	want.y = rise * speed * 0.7
	if dir == Vector3.ZERO and is_zero_approx(rise):
		velocity = velocity.lerp(Vector3.ZERO, clampf(drag * dt, 0.0, 1.0))
	else:
		velocity = velocity.lerp(want, clampf(accel * dt, 0.0, 1.0))
	move_and_slide()
	_animate(dir, dt)

func _animate(dir: Vector3, dt: float) -> void:
	if model == null:
		return
	var moving := velocity.length() > 0.4
	# A real swim cycle beats anything procedural. When one exists, the whole
	# model stops being pitched and bobbed by hand and just plays.
	var clipped := _drive_clip(moving)
	_bob += dt * (3.4 if moving else 1.1)
	_kick += dt * (6.0 if moving else 0.0)

	# face the way we are swimming, and lean into the turn
	if dir.length() > 0.05:
		var target := atan2(-dir.x, -dir.z)
		var cur := rotation.y
		rotation.y = cur + wrapf(target - cur, -PI, PI) * clampf(dt * 6.0, 0.0, 1.0)

	# Swim posture. Without a rig there is no stroke to play, so the whole
	# body pitches over into a glide when it gets moving and stands back up
	# when it stops. Upright divers sliding across the seabed read as statues
	# being dragged; this is the single change that makes them look alive.
	var flat := Vector2(velocity.x, velocity.z).length()
	var want_pitch: float = -1.15 * clampf(flat / speed, 0.0, 1.0) - clampf(velocity.y * 0.12, -0.3, 0.3)
	_lean = lerpf(_lean, want_pitch, clampf(dt * 3.0, 0.0, 1.0))

	if clipped:
		# the clip owns the body; keep only the lean into a dive or a climb
		model.position.y = 0.0
		model.rotation.x = clampf(-velocity.y * 0.16, -0.4, 0.4)
		model.rotation.z = 0.0
		return
	model.position.y = sin(_bob) * (0.09 if moving else 0.05)
	model.rotation.x = _lean + sin(_kick) * (0.09 if moving else 0.0)
	model.rotation.z = sin(_kick * 0.5) * (0.08 if moving else 0.02)
	if bubbles != null:
		bubbles.emitting = true

func _find(n: Node, nm: String) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name) == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r != null:
			return r
	return null

func _world_aabb(m: MeshInstance3D) -> AABB:
	var a: AABB = m.get_aabb()
	var t: Transform3D = m.transform
	var out := AABB(t * a.get_endpoint(0), Vector3.ZERO)
	for i in range(8):
		out = out.expand(t * a.get_endpoint(i))
	return out
