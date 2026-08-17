# A diver you can swim around. The models arrived unrigged, so there is no
# swim cycle to play: all the life in these is procedural, applied to the
# whole model rather than to bones. Bob, bank, kick-pitch and a bubble trail.
#
# Everything about the model's arrival is handled here in one place: the
# GLB stacks all four models on one origin, every mesh node carries a -90
# X rotation and a scale of 100, and the models face +Z while Godot treats
# -Z as forward. Fix it once, here, and the rest of the game can just place
# a Diver and forget the export ever had opinions.

class_name Diver
extends CharacterBody3D

# world.gd listens for this on whichever Diver is currently the player and
# starts a Battle. Emitted for every Diver, including the two drifting NPCs
# (each tracks its own distance independently) - world.gd is what decides
# only the active one counts.
signal encounter_triggered


const SRC := preload("res://art/characters/divers.glb")


# ============================================================
# DIVER SETTINGS
# ============================================================

@export var model_name := "Staff_Diver"
@export var tint := Color(1, 1, 1)

var speed := 5.0
var accel := 6.0
var drag := 2.2


# ============================================================
# COMBAT STATS
# ============================================================

# One spread per playable model, chosen to give TAB an actual reason to
# matter in a fight rather than just changing which mesh is on screen:
# Staff_Diver even, Prototype_1 fast/fragile, Prototype_V slow/sturdy.
# grow_* is how much each stat ticks up per level (see combatant_stats.gd) -
# different per diver so leveling reinforces the spread instead of
# flattening it out.
# dodge/accuracy/barrier_max are identity traits, not leveled (no grow_*
# for them) - Prototype_1 is nimble (high dodge) rather than shielded,
# Prototype_V is the reverse. Keeps the three spreads distinct even after
# several level-ups, instead of every stat converging as they grow.
const BASE_STATS := {
	"Staff_Diver": {
		"hp": 34, "attack": 5, "defense": 3, "speed": 5, "luck": 5,
		"dodge": 0.10, "accuracy": 0.10, "barrier_max": 5,
		"grow_hp": 4, "grow_attack": 1, "grow_defense": 1, "grow_speed": 1, "grow_luck": 1,
	},
	"Prototype_1(1910)": {
		"hp": 26, "attack": 8, "defense": 1, "speed": 7, "luck": 4,
		"dodge": 0.18, "accuracy": 0.15, "barrier_max": 0,
		"grow_hp": 2, "grow_attack": 2, "grow_defense": 0, "grow_speed": 2, "grow_luck": 1,
	},
	"Prototype_V(1922)": {
		"hp": 42, "attack": 3, "defense": 5, "speed": 3, "luck": 6,
		"dodge": 0.04, "accuracy": 0.06, "barrier_max": 10,
		"grow_hp": 6, "grow_attack": 1, "grow_defense": 2, "grow_speed": 0, "grow_luck": 1,
	},
}

# Lives on the Diver node itself, so level/XP survive between encounters for
# as long as this Diver does (the length of one play session - nothing
# persists across a reload yet). game/world.gd hands this to game/battle.gd
# when a fight starts.
var stats: CombatantStats


# ============================================================
# DISTANCE / RANDOM ENCOUNTER SETTINGS
# ============================================================

# Total distance the diver has traveled during this session.
var distance_traveled: float = 0.0

# Distance traveled since the last encounter check.
var distance_since_encounter: float = 0.0

# The game will check for an encounter after a random amount
# of distance between these two values.
@export var min_encounter_distance: float = 20.0
@export var max_encounter_distance: float = 40.0

# Chance of actually triggering an encounter when the distance
# threshold is reached.
#
# 0.25 = 25%
# 0.50 = 50%
# 1.00 = 100%
@export_range(0.0, 1.0) var encounter_chance: float = 0.25

# The randomly selected distance at which the next encounter
# check will happen.
var encounter_distance: float = 0.0


# ============================================================
# MODEL / ANIMATION
# ============================================================

var model: Node3D
var height := 1.9
var radius := 0.4

var _bob := 0.0
var _kick := 0.0
var _lean := 0.0

var bubbles: CPUParticles3D


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	_build_stats()

	# Choose the distance required before the first encounter check.
	encounter_distance = randf_range(
		min_encounter_distance,
		max_encounter_distance
	)

	var src: Node3D = SRC.instantiate()

	var mesh: MeshInstance3D = _find(src, model_name)

	if mesh == null:
		push_error("NO SUCH MODEL '%s' in the GLB" % model_name)
		src.queue_free()
		return


	# ========================================================
	# CREATE MODEL CONTAINER
	# ========================================================

	model = Node3D.new()
	model.name = "Model"
	add_child(model)


	# The models face +Z while Godot's forward is -Z.
	# Keep the correction on its own node.
	var flip := Node3D.new()
	flip.name = "Flip"
	flip.rotation.y = PI
	model.add_child(flip)


	# Keep the mesh's original transform.
	var keep: Transform3D = mesh.transform

	mesh.owner = null

	mesh.get_parent().remove_child(mesh)

	flip.add_child(mesh)

	mesh.transform = keep


	# ========================================================
	# CALCULATE MODEL SIZE
	# ========================================================

	var box: AABB = _world_aabb(mesh)

	height = box.size.y

	radius = maxf(
		0.25,
		minf(box.size.x, box.size.z) * 0.5
	)

	# Move the model so its feet sit on the body's floor.
	mesh.position.y -= box.position.y + height * 0.5


	# ========================================================
	# CREATE COLLISION
	# ========================================================

	var shape := CollisionShape3D.new()

	var cap := CapsuleShape3D.new()

	cap.height = maxf(
		height,
		radius * 2.0 + 0.1
	)

	cap.radius = radius

	shape.shape = cap

	add_child(shape)


	# ========================================================
	# INITIAL ANIMATION STATE
	# ========================================================

	_bob = randf() * TAU

	_add_bubbles()


	# We no longer need the temporary source scene.
	src.queue_free()


# ============================================================
# COMBAT STATS SETUP
# ============================================================

func _build_stats() -> void:

	var base: Dictionary = BASE_STATS.get(
		model_name,
		BASE_STATS["Staff_Diver"]
	)

	stats = CombatantStats.new()
	stats.hp_max = int(base.hp)
	stats.attack = int(base.attack)
	stats.defense = int(base.defense)
	stats.speed = int(base.speed)
	stats.luck = int(base.luck)
	stats.dodge = float(base.dodge)
	stats.accuracy = float(base.accuracy)
	stats.barrier_max = int(base.barrier_max)
	stats.grow_hp = int(base.grow_hp)
	stats.grow_attack = int(base.grow_attack)
	stats.grow_defense = int(base.grow_defense)
	stats.grow_speed = int(base.grow_speed)
	stats.grow_luck = int(base.grow_luck)
	stats.fill()


# ============================================================
# BUBBLES
# ============================================================

func _add_bubbles() -> void:

	# CPU particles are used so this also works with the
	# compatibility renderer / web export.

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


	# Bubble mesh.
	var sphere := SphereMesh.new()

	sphere.radius = 0.5

	sphere.height = 1.0

	sphere.radial_segments = 6

	sphere.rings = 3

	bubbles.mesh = sphere


	# Bubble material.
	var m := StandardMaterial3D.new()

	m.albedo_color = Color(0.75, 0.92, 1.0, 0.55)

	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	bubbles.mesh.surface_set_material(0, m)


	bubbles.position = Vector3(
		0,
		height * 0.35,
		0
	)

	add_child(bubbles)


# ============================================================
# SWIMMING
# ============================================================

# dir:
# Desired horizontal direction in world space.
#
# rise:
# -1 = swim down
#  0 = horizontal
# +1 = swim up
#
# dt:
# Frame delta.

func swim(dir: Vector3, rise: float, dt: float) -> void:

	var want := dir * speed

	want.y = rise * speed * 0.7


	# ========================================================
	# ACCELERATION / DRAG
	# ========================================================

	if dir == Vector3.ZERO and is_zero_approx(rise):

		velocity = velocity.lerp(
			Vector3.ZERO,
			clampf(
				drag * dt,
				0.0,
				1.0
			)
		)

	else:

		velocity = velocity.lerp(
			want,
			clampf(
				accel * dt,
				0.0,
				1.0
			)
		)


	# ========================================================
	# TRACK MOVEMENT DISTANCE
	# ========================================================

	# Remember where the diver was before movement.
	var old_position := global_position


	# Actually move the diver.
	move_and_slide()


	# Calculate how far the diver actually moved.
	var distance_moved := old_position.distance_to(
		global_position
	)


	# Add that movement to our counters.
	distance_traveled += distance_moved

	distance_since_encounter += distance_moved


	# ========================================================
	# RANDOM ENCOUNTER CHECK
	# ========================================================

	if distance_since_encounter >= encounter_distance:

		check_for_encounter()


	# ========================================================
	# ANIMATION
	# ========================================================

	_animate(dir, dt)


# ============================================================
# RANDOM ENCOUNTER
# ============================================================

func check_for_encounter() -> void:

	# Reset the distance counter.
	distance_since_encounter = 0.0


	# Pick a new random distance for the next encounter check.
	encounter_distance = randf_range(
		min_encounter_distance,
		max_encounter_distance
	)


	# Roll for an encounter.
	if randf() <= encounter_chance:

		start_random_encounter()


# ============================================================
# START RANDOM ENCOUNTER
# ============================================================

func start_random_encounter() -> void:
	encounter_triggered.emit()


# ============================================================
# ANIMATION
# ============================================================

func _animate(dir: Vector3, dt: float) -> void:

	if model == null:
		return


	var moving := velocity.length() > 0.4


	# Animation timers.
	_bob += dt * (3.4 if moving else 1.1)

	_kick += dt * (6.0 if moving else 0.0)


	# ========================================================
	# FACE SWIMMING DIRECTION
	# ========================================================

	if dir.length() > 0.05:

		var target := atan2(
			-dir.x,
			-dir.z
		)

		var cur := rotation.y

		rotation.y = cur + wrapf(
			target - cur,
			-PI,
			PI
		) * clampf(
			dt * 6.0,
			0.0,
			1.0
		)


	# ========================================================
	# SWIM POSTURE
	# ========================================================

	var flat := Vector2(
		velocity.x,
		velocity.z
	).length()


	var want_pitch: float = (
		-1.15
		* clampf(
			flat / speed,
			0.0,
			1.0
		)
		- clampf(
			velocity.y * 0.12,
			-0.3,
			0.3
		)
	)


	_lean = lerpf(
		_lean,
		want_pitch,
		clampf(
			dt * 3.0,
			0.0,
			1.0
		)
	)


	# ========================================================
	# BODY BOB / KICK
	# ========================================================

	model.position.y = sin(_bob) * (
		0.09 if moving else 0.05
	)


	model.rotation.x = (
		_lean
		+ sin(_kick)
		* (0.09 if moving else 0.0)
	)


	model.rotation.z = (
		sin(_kick * 0.5)
		* (0.08 if moving else 0.02)
	)


	# ========================================================
	# BUBBLES
	# ========================================================

	if bubbles != null:

		bubbles.emitting = true


# ============================================================
# FIND MODEL
# ============================================================

func _find(n: Node, nm: String) -> MeshInstance3D:

	if n is MeshInstance3D and String(n.name) == nm:

		return n


	for c in n.get_children():

		var r := _find(c, nm)

		if r != null:

			return r


	return null


# ============================================================
# WORLD AABB
# ============================================================

func _world_aabb(m: MeshInstance3D) -> AABB:

	var a: AABB = m.get_aabb()

	var t: Transform3D = m.transform

	var out := AABB(
		t * a.get_endpoint(0),
		Vector3.ZERO
	)


	for i in range(8):

		out = out.expand(
			t * a.get_endpoint(i)
		)


	return out
