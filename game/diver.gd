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

# Fired by _swap() once a swap actually lands, target being who this diver
# just traded places with. world.gd listens for this to do a confirmation
# camera pan toward the traded-to position - purely a presentation hook,
# the swap itself has already fully happened by the time this fires.
signal swapped_with(target: Diver)


const SRC := preload("res://art/characters/divers.glb")


# ============================================================
# DIVER SETTINGS
# ============================================================

@export var model_name := "Staff_Diver"
@export var tint := Color(1, 1, 1)

var speed := 5.0
var accel := 6.0
var drag := 2.2
var sonar_timer := 0.0
var SONAR_INTERVAL := 0.2

@export var can_be_selected := true

# ============================================================
# COMBAT STATS
# ============================================================

# One spread per playable model, chosen to give TAB an actual reason to
# matter in a fight rather than just changing which mesh is on screen:
# Staff_Diver even, Prototype_1 fast/precise/fragile, Prototype_V
# slow/sturdy. grow_* is how much each stat ticks up per level (see
# combatant_stats.gd) - different per diver so leveling reinforces the
# spread instead of flattening it out.
# evasion/accuracy/barrier_max are identity traits, not leveled (no grow_*
# for them) - Prototype_1 is nimble (high evasion, high accuracy) rather
# than shielded, Prototype_V is the reverse. Keeps the three spreads
# distinct even after several level-ups, instead of every stat converging.
const BASE_STATS := {
	"Staff_Diver": {
		"hp": 34, "strength": 5, "defense": 3, "agility": 5,
		"evasion": 5, "accuracy": 6, "barrier_max": 5,
		"grow_hp": 4, "grow_strength": 1, "grow_defense": 1, "grow_agility": 1,
		"grow_accuracy": 1, "grow_evasion": 1,
		"ability": "swap", "ability_locked": true, "passive": "sonar"
	},
	"Prototype_1(1910)": {
		"hp": 26, "strength": 8, "defense": 1, "agility": 8,
		"evasion": 8, "accuracy": 8, "barrier_max": 0,
		"grow_hp": 2, "grow_strength": 2, "grow_defense": 0, "grow_agility": 2,
		"grow_accuracy": 1, "grow_evasion": 1,
		"ability": "grapple",
	},
	"Prototype_V(1922)": {
		"hp": 42, "strength": 3, "defense": 6, "agility": 3,
		"evasion": 2, "accuracy": 4, "barrier_max": 10,
		"grow_hp": 6, "grow_strength": 1, "grow_defense": 2, "grow_agility": 0,
		"grow_accuracy": 1, "grow_evasion": 1,
		"ability": "shockwave",
	},
}

# Lives on the Diver node itself, so level/XP survive between encounters for
# as long as this Diver does (the length of one play session - nothing
# persists across a reload yet). game/world.gd hands this to game/battle.gd
# when a fight starts.
var stats: CombatantStats
var passive_id := ""
# "" means this diver has no active ability - use_ability() is a no-op for
# an empty id, so nothing needs to special-case "does this diver have one."
var ability_id := ""

# A locked ability exists (ability_id is set) but can't be used yet - it's
# there to be unlocked by something in the world (see unlock_ability(),
# called by grapple_anchor.gd's on_grappled_to()), not earned by leveling.
# Only Staff_Diver's BASE_STATS entry sets this true.
var ability_locked := false

# Spell ids this diver has bought from game/spell_tree.gd, across all three
# branches at once (offense/defense/debuff aren't separate inventories -
# just where a given id happens to live in the tree). See SpellTree.learn().
var known_spells: Array[String] = []

# Which known spells are actually active for battle - "known" and
# "equipped" are deliberately separate lists (see SpellTree.equip()) so
# buying a spell doesn't force it into the loadout, and the loadout stays
# capped even as known_spells grows without bound.
const MAX_EQUIPPED_SPELLS := 4
var equipped_spells: Array[String] = []


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

	# Divers don't collide with each other - layer 2, masked to only see
	# layer 1 (the environment: floor, walls, rocks). Nothing in this game
	# needs two divers to physically block one another, and letting them
	# collide caused a real bug: swap() exchanges two divers' positions
	# outright (not a gradual move), and for a frame or two afterward
	# their capsules could register as overlapping and push against each
	# other, kicking off a runaway velocity that sent a diver rocketing
	# off in a semi-random direction with no way to tell it had happened
	# short of watching it occur. Physics ray queries (grapple, swap
	# targeting) are unaffected - PhysicsRayQueryParameters3D defaults to
	# checking all collision layers unless a query explicitly restricts
	# its own mask, which none of this project's raycasts do.
	collision_layer = 2
	collision_mask = 1


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
	stats.strength = int(base.strength)
	stats.defense = int(base.defense)
	stats.agility = int(base.agility)
	stats.evasion = int(base.evasion)
	stats.accuracy = int(base.accuracy)
	stats.barrier_max = int(base.barrier_max)
	stats.grow_hp = int(base.grow_hp)
	stats.grow_strength = int(base.grow_strength)
	stats.grow_defense = int(base.grow_defense)
	stats.grow_agility = int(base.grow_agility)
	stats.grow_accuracy = int(base.get("grow_accuracy", 0))
	stats.grow_evasion = int(base.get("grow_evasion", 0))
	stats.fill()

	# Not a CombatantStats field - an ability isn't part of the damage
	# formula, it lives on the Diver itself. .get() with a default since
	# not every entry in BASE_STATS has an "ability" key yet.
	ability_id = String(base.get("ability", ""))
	passive_id = String(base.get("passive", ""))
	ability_locked = bool(base.get("ability_locked", false))


# ============================================================
# ABILITIES
# ============================================================

# match on ability_id, not on model_name - use_ability() shouldn't need to
# know which diver it's on, only what that diver's BASE_STATS entry said
# its ability was. Adding a third ability later means one more match branch
# here, not a new system.
const SHOCKWAVE_RADIUS := 3.0
const GRAPPLE_RANGE := 14.0
const GRAPPLE_PULL_DURATION := 0.4

# Different cooldowns on purpose, not just one shared constant: shockwave
# always does something the instant it's used (no aim, nothing to whiff),
# so it needs real downtime or it'd be free to spam. Grapple is the
# traversal tool - a whiff already costs nothing (see _grapple() below),
# so a successful pull shouldn't feel sluggish on top of that. Swap is
# aimed like grapple (a whiff costs nothing) but a hit is a bigger, more
# game-changing move than a simple pull, so it sits between the two.
const SHOCKWAVE_COOLDOWN := 2.5
const GRAPPLE_COOLDOWN := 1.2
const SWAP_COOLDOWN := 2.0

# Swap costs less than the other two - it's a reposition, not a combat move
# (see the cooldown comment above for the same distinction). Keyed by
# ability_id rather than three separate consts so _ability_oxygen_cost()
# stays a one-line lookup no matter how many abilities this ever grows to.
const ABILITY_OXYGEN_COST := {"shockwave": 20.0, "grapple": 20.0, "swap": 15.0}

# No passive regen at all - a save point (world.gd's _on_save_requested())
# is the only way oxygen comes back, so every ability use and every second
# of sonar is spending down a tank that stays spent until you actually go
# find one. Lower than the old always-on-passive drain used to need, since
# there's no regen fighting it anymore - this is the whole cost, not a net
# rate against something clawing it back.
const SONAR_OXYGEN_DRAIN_PER_SEC := 3.0

var _ability_cooldown := 0.0
var _is_grappling := false

# Sonar is proc'd on/off (see toggle_sonar(), bound to Q in world.gd), not
# always-on just because this diver's model has the passive - passive_id
# says *which* diver can use it, sonar_active says whether it's currently
# running. Only meaningful when passive_id == "sonar"; harmless (never
# read) on a diver that doesn't have the passive at all.
var sonar_active := false

func _process(dt: float) -> void:
	_ability_cooldown = maxf(0.0, _ability_cooldown - dt)

func _ability_oxygen_cost() -> float:
	return float(ABILITY_OXYGEN_COST.get(ability_id, 0.0))

# Read-only check world.gd can make before deciding whether to enter aim
# mode or fire immediately - mirrors use_ability()'s own guard exactly, so
# there's one place that knows what "ready to use" means instead of
# world.gd guessing at Diver's private cooldown/grapple-in-progress state.
func can_use_ability() -> bool:
	return (ability_id != "" and not ability_locked and _ability_cooldown <= 0.0
		and not _is_grappling and stats.oxygen >= _ability_oxygen_cost())

# Called by whatever is meant to unlock a locked ability - right now just
# grapple_anchor.gd's on_grappled_to(), for the one anchor whose
# unlocks_diver_ability_for names this diver's model. Harmless to call on
# a diver that was never locked in the first place.
func unlock_ability() -> void:
	ability_locked = false

# So whirlpool.gd (and anything else outside this script) can check whether
# a pull is in progress without reaching into the private _is_grappling
# field directly.
func is_grappling() -> bool:
	return _is_grappling

# Same shape as _is_grappling, for the same reason: whirlpool.gd drives
# global_position directly (a tween pulling the diver into the whirlpool's
# center) for the duration of the pull, and swim()'s own move_and_slide()
# would fight it every physics frame otherwise. A grappling diver is
# already exempt from suction entirely (see whirlpool.gd) - this is for
# the pull itself, once it's started.
var _suction_locked := false

func set_suction_locked(v: bool) -> void:
	_suction_locked = v

func is_suction_locked() -> bool:
	return _suction_locked

# Which abilities need a deliberate aim step (first-person raycast, click
# to fire) vs firing the instant E is pressed. Shockwave is omnidirectional,
# nothing to aim. Swap used to be raycast-aimed too, but now goes through
# TargetSelector's cycle-through-candidates flow instead (see world.gd),
# so it's no longer in this list - world.gd checks ability_id == "swap"
# directly to route it to start_selection() rather than first-person aim.
func ability_needs_aim() -> bool:
	return ability_id == "grapple"

# aim_dir: world-space direction to fire an aimed ability in (grapple).
# Zero vector (the default) falls back to the diver's own body facing -
# used by shockwave (omnidirectional) and by anything that calls
# use_ability() without a camera to aim from.
# target: explicit target for abilities that don't aim at all but still
# need to know who (swap) - comes from TargetSelector.confirmed, not a
# raycast.
func use_ability(aim_dir: Vector3 = Vector3.ZERO, target: Node3D = null) -> void:
	if not can_use_ability():
		return
	stats.oxygen -= _ability_oxygen_cost()
	match ability_id:
		"shockwave":
			_shockwave()
		"grapple":
			_grapple(aim_dir)
		"swap":
			_swap(target as Diver)


func _shockwave() -> void:
	_ability_cooldown = SHOCKWAVE_COOLDOWN
	get_tree().call_group("shockwave_breakable", "on_shockwave", global_position, SHOCKWAVE_RADIUS)
	_shockwave_vfx()

# Throwaway visual: an expanding, fading sphere centered on the diver.
# Nothing here is a hitbox - the actual break check is on_shockwave() over
# on whatever's listening in the "shockwave_breakable" group, this is only
# so the pulse reads as something happening.
func _shockwave_vfx() -> void:
	var vfx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	vfx.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vfx.material_override = mat
	vfx.position = Vector3(0, height * 0.4, 0)
	add_child(vfx)
	var tw := create_tween()
	tw.tween_property(vfx, "scale", Vector3.ONE * (SHOCKWAVE_RADIUS / 0.3), 0.35)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(vfx.queue_free)
	
# toggle_sonar() is the only thing that ever sets sonar_active true - once
# oxygen actually runs out it also turns itself back off (rather than
# leaving it "on" but silently inert), so a player checking sonar_active
# always gets an honest answer about whether pings are still happening.
func toggle_sonar() -> bool:
	if passive_id != "sonar":
		return false
	sonar_active = not sonar_active and stats.oxygen > 0.0
	return sonar_active

func _physics_process(delta: float) -> void:
	if passive_id == "sonar" and sonar_active:
		stats.oxygen = maxf(0.0, stats.oxygen - SONAR_OXYGEN_DRAIN_PER_SEC * delta)
		if stats.oxygen <= 0.0:
			sonar_active = false
		sonar_timer -= delta
		if sonar_timer <= 0.0:
			sonar_timer = SONAR_INTERVAL
			update_sonar()

# TODO: not implemented yet - sonar toggle currently ticks pings while on
# but they have no effect.
func update_sonar() -> void:
	pass

# Aimed - the one ability that isn't omnidirectional. `aim_dir` comes from
# world.gd's camera yaw/pitch (where the player is actually looking, via
# mouse-look), not the diver's own body facing, which lags behind real
# aim (it only lerps toward the last swim direction - see _animate()).
# Falls back to body facing only if nothing supplied a real aim direction.
#
# The beam always fires and is always visible, hit or miss - shooting and
# seeing nothing happen reads as broken, not "you missed." Only a
# confirmed hit on something in the "grapple_anchor" group spends the
# cooldown or starts the pull; a clean miss can be retried immediately.
func _grapple(aim_dir: Vector3) -> void:
	var dir: Vector3 = aim_dir.normalized() if aim_dir.length() > 0.01 else -global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0, height * 0.4, 0)
	var to: Vector3 = from + dir * GRAPPLE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space.intersect_ray(query)

	# Beam end is wherever the ray actually stopped - the max range if it
	# hit nothing at all, or whatever it struck (anchor or not).
	var beam_end: Vector3 = to if result.is_empty() else (result.position as Vector3)
	_grapple_beam_vfx(from, beam_end)

	if result.is_empty() or not (result.collider as Node).is_in_group("grapple_anchor"):
		return

	_ability_cooldown = GRAPPLE_COOLDOWN
	_is_grappling = true
	var target: Vector3 = (result.collider as Node3D).global_position

	# The anchor gets a chance to react to being reached, independent of
	# the pull itself - grapple_anchor.gd's on_grappled_to() is what
	# unlocks Staff_Diver's signal ability for the gap sequence. Diver
	# doesn't know or care what the anchor does with this; it just offers.
	if (result.collider as Node).has_method("on_grappled_to"):
		(result.collider as Node).call("on_grappled_to")

	velocity = Vector3.ZERO
	var tw := create_tween()
	# Stop a short step short of the anchor's own center, not on top of it.
	var stop_at: Vector3 = target - dir * 1.0
	tw.tween_property(self, "global_position", stop_at, GRAPPLE_PULL_DURATION)
	tw.tween_callback(func() -> void: _is_grappling = false)

# Throwaway visual: a thin beam from where the diver fired to wherever the
# shot actually ended (hit or not), fading out over the pull's own
# duration regardless of whether a pull happens. Fixed in place once
# spawned (doesn't track the diver mid-pull) - "you fired a line" reads
# fine without the beam continuously updating.
func _grapple_beam_vfx(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.01:
		return
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = dist
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.85, 0.3, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = mat

	get_parent().add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI / 2.0)   # CylinderMesh's long axis is local Y, look_at faces -Z

	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, GRAPPLE_PULL_DURATION)
	tw.tween_callback(beam.queue_free)

# Not aimed at all - the target comes pre-selected from TargetSelector's
# cycle-through-candidates flow (world.gd routes E through
# target_selector.start_selection() for "swap" instead of first-person
# aim; see ability_needs_aim()). Swaps this diver's position with
# `target` outright: instant, not a tween like grapple's pull - "switch
# places" reads as a snap, not travel. A null/invalid target is a no-op
# and spends no cooldown, same "a clean non-hit costs nothing" policy
# grapple's whiff has, just reached through selection instead of a raycast
# miss.
#
# Doesn't touch the gap's bridge - that used to be a side effect of this
# ability (back when it was called "signal"), but raising a bridge has
# nothing to do with trading places with an ally, so it's now triggered by
# reaching the far grapple anchor instead (see grapple_anchor.gd's
# raises_bridge).
func _swap(target: Diver) -> void:
	if target == null or not is_instance_valid(target) or not target.can_be_selected:
		return

	_ability_cooldown = SWAP_COOLDOWN

	var my_pos: Vector3 = global_position
	var their_pos: Vector3 = target.global_position
	_swap_vfx(my_pos, their_pos)

	velocity = Vector3.ZERO
	target.velocity = Vector3.ZERO
	global_position = their_pos
	target.global_position = my_pos

	swapped_with.emit(target)

# Throwaway visual: a matching flash at both the old and new spot, so the
# swap reads as "these two places traded occupants" rather than just one
# diver silently teleporting.
func _swap_vfx(pos_a: Vector3, pos_b: Vector3) -> void:
	_swap_flash(pos_a)
	_swap_flash(pos_b)

func _swap_flash(at: Vector3) -> void:
	var vfx := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.5
	vfx.mesh = ring
	vfx.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.4, 0.95, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vfx.material_override = mat
	get_parent().add_child(vfx)
	vfx.global_position = at
	var tw := create_tween()
	tw.tween_property(vfx, "scale", Vector3.ONE * 3.0, 0.4)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(vfx.queue_free)

# Called by gap_pit.gd when this diver blunders into an unresolved gap.
# Flickers the model a few times - the model swap trick, not a shader
# effect, since nothing about these models supports a flash material
# (unrigged, no vertex colors to hijack) and this needed to work with
# whatever's already on them.
func flash_damage() -> void:
	if model == null:
		return
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(model, "visible", false, 0.08)
		tw.tween_property(model, "visible", true, 0.08)

# Called by whirlpool.gd to make a diver vanish while caught (pulled to
# the center, gone, then reappears at the reset point) - a plain
# visibility toggle, same mechanism flash_damage() already uses, just
# held rather than flickered.
func set_model_visible(v: bool) -> void:
	if model != null:
		model.visible = v

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

	# A grapple or whirlpool-suction tween owns global_position for its
	# duration - move_and_slide() below would fight it every physics frame
	# otherwise, since it also writes global_position off of `velocity`.
	if _is_grappling or _suction_locked:
		return

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


# Called by battle.gd the instant a hit brings this diver (the throwaway
# battle-stage actor, not the real world.gd Diver - see _build_stage()'s
# comment on why the actor is a separate instance from the party's real
# stats) down to 0 HP. Same fade-while-sinking-and-shrinking treatment
# goblin.gd's play_death_fade() gives a defeated grunt, mirrored here so
# both sides of a fight disappear the same way rather than only enemies
# visibly dying. Materials get duplicated before fading for the same
# reason goblin.gd's version does - the imported GLB's materials can be a
# shared resource across every Diver instance of the same model_name, and
# mutating one in place would fade every other diver wearing that model
# too, including the real party member's own battle-stage neighbors.
func play_death_fade() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	for m in _all_meshes(model):
		var mesh_instance := m as MeshInstance3D
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var mat := mesh_instance.get_active_material(surface)
			if mat == null or not (mat is BaseMaterial3D):
				continue
			var mat_copy := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			mat_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_instance.set_surface_override_material(surface, mat_copy)
			tw.tween_property(mat_copy, "albedo_color:a", 0.0, 0.9)
	tw.tween_property(self, "position:y", position.y - 0.6, 0.9)
	tw.tween_property(self, "scale", scale * 0.7, 0.9)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)

func _all_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out

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
