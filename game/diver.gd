# Swimmable diver. Corrects the export's facing (+Z vs Godot's -Z) and origin
# so the rest of the game can place a Diver directly. Clip names live in content/cast.gd.

class_name Diver
extends CharacterBody3D

# Emitted by every Diver; world.gd only acts on the active one.
signal encounter_triggered
signal sonar_changed

# Pauses exploration clocks (Sonar billing) during battle without losing state.
var exploration_paused := false

# Emitted after a swap lands; world.gd uses it for a camera pan.
signal swapped_with(target: Diver)




# ============================================================
# DIVER SETTINGS
# ============================================================

@export var model_name := "Staff_Diver"
@export var tint := Color(1, 1, 1)

# Set by world.gd after add_child(); update_sonar() reads its key-item state.
var world: World

var speed := 5.0
var accel := 6.0
var drag := 2.2
var sonar_timer := 0.0
var SONAR_INTERVAL := 0.2

@export var can_be_selected := true

# ============================================================
# COMBAT STATS
# ============================================================

# Every diver has 10 HP; roles differ through the other stats.
const BASE_STATS := {
	"Staff_Diver": {
		"hp": 10, "strength": 1, "defense": 0, "agility": 3,
		"evasion": 3, "accuracy": 3,
		"ability": "swap", "passive": "sonar"
	},
	"Prototype_1(1910)": {
		"hp": 10, "strength": 2, "defense": 2, "agility": 2,
		"evasion": 2, "accuracy": 2,
		"ability": "grapple",
	},
	"Prototype_V(1922)": {
		"hp": 10, "strength": 4, "defense": 4, "agility": 1,
		"evasion": 0, "accuracy": 1,
		"ability": "shockwave",
	},
}

# Level/XP persist for this node's lifetime (one session); handed to battle.gd.
var stats: CombatantStats
var passive_id := ""
# "" means no active ability; use_ability() is then a no-op.
var ability_id := ""

# Ability exists but is unusable until unlock_ability(). Nothing sets this today.
var ability_locked := false

# Spell ids bought from SpellTree, across all branches.
var known_spells: Array[String] = []

# Spells active in battle. SpellTree.learn() equips on learn, so this mirrors known_spells.
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
@export var min_encounter_distance: float = 8.0
@export var max_encounter_distance: float = 16.0

# Chance an encounter triggers when the distance threshold is reached.
# Keep verify/encounters.gd in sync when tuning these three values.
@export_range(0.0, 1.0) var encounter_chance: float = 0.7

# The randomly selected distance at which the next encounter
# check will happen.
var encounter_distance: float = 0.0


# ============================================================
# MODEL / ANIMATION
# ============================================================

var model: Node3D
var height := 1.9
var radius := 0.4

# The rigged file's own AnimationPlayer, left in place (see _ready()).
var anim: AnimationPlayer
# Only Battle uses the measured spell framing envelope.
const SPELL_FRAMES := preload("res://art/characters/spell_animations/frames.res")
var framing_clip := ""

func framing_points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var frames: Dictionary = SPELL_FRAMES.get_meta("frames", {}).get(model_name, {})
	for point in frames.get(framing_clip, PackedVector3Array()):
		result.append(global_transform * (point as Vector3))
	return result

# Armature prefix used by this delivery ("rig", "rig_001", ...), learned from the file.
var _prefix := ""
# A one-shot clip owns the body until this time, then movement takes over.
var _busy_until := 0.0
var _clock := 0.0
var _motion := ""
# Loop to return to after a one-shot ("" = follow movement); holds faint/win poses.
var _hold := ""
# Previous frame's swim state, for Start/End transition clips.
var _was_moving := false

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

	# Instantiate the whole rigged file so animation track paths resolve; other
	# characters' meshes in it are hidden below.
	var file := Cast.file(model_name)

	var src: Node3D = (load(file) as PackedScene).instantiate()


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

	flip.add_child(src)


	# ========================================================
	# PICK THIS CHARACTER OUT OF THE SHARED RIG
	# ========================================================

	var carried: Array = Cast.carries(model_name)

	var mesh: MeshInstance3D = null

	for m in _all_meshes(src):

		var mi := m as MeshInstance3D

		var mine: bool = String(mi.name) == model_name

		# Carried items (e.g. the staff) are skinned to the rig, so keep them visible.
		mi.visible = mine or carried.has(String(mi.name))

		if mine:
			mesh = mi

	if mesh == null:
		push_error("NO SUCH MODEL '%s' in %s" % [model_name, file])
		src.queue_free()
		return


	# ========================================================
	# ANIMATION
	# ========================================================

	anim = _find_anim(src)

	if anim == null:
		push_error("NO AnimationPlayer in %s" % file)
	else:
		# Merge partial spell FBX animations into the existing rig's clips.
		anim.add_animation_library("spells", Cast.spell_animations(model_name))
		# Animate while the tree is paused (title screen) so divers don't sit in bind pose.
		anim.process_mode = Node.PROCESS_MODE_ALWAYS
		# Learn the armature prefix from a clip guaranteed to exist.
		_learn_prefix(Cast.motion(model_name, "idle"))
		play_motion("idle")


	# ========================================================
	# CALCULATE MODEL SIZE
	# ========================================================

	var box: AABB = _world_aabb(mesh, src)

	height = box.size.y

	radius = maxf(
		0.25,
		minf(box.size.x, box.size.z) * 0.5
	)

	# Centre the model on the body. Move the whole tree, not the mesh, or the mesh
	# detaches from its skeleton.
	src.position.y -= box.position.y + height * 0.5


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

	# Layer 2, masked to the environment only: divers colliding after a swap launched
	# them. Ray queries still check all layers.
	collision_layer = 2
	collision_mask = 1


	# ========================================================
	# BUBBLES
	# ========================================================

	_add_bubbles()


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
	stats.fill()

	# Ability lives on the Diver, not CombatantStats; not every entry has one.
	ability_id = String(base.get("ability", ""))
	passive_id = String(base.get("passive", ""))
	ability_locked = bool(base.get("ability_locked", false))


# ============================================================
# ABILITIES
# ============================================================

const SHOCKWAVE_RADIUS := 3.0
const GRAPPLE_RANGE := 14.0
const GRAPPLE_PULL_DURATION := 0.4
# Environment plus item targets on layer 5; shared by aim preview and fire.
const GRAPPLE_COLLISION_MASK := 1 | (1 << 4)

# Shockwave can't miss, so it has the longest cooldown; grapple misses are free.
const SHOCKWAVE_COOLDOWN := 2.5
# Grapple and Swap are free. Save points and Oxygen Cells refill the tank.
const SHOCKWAVE_OXYGEN_COST := 12.0
const GRAPPLE_COOLDOWN := 1.2
const SWAP_COOLDOWN := 2.0

# Grapple/Swap never cost Oxygen so progression can't be blocked. Sonar is
# billed in lump sums every SONAR_DRAIN_INTERVAL.
const SONAR_OXYGEN_PER_TICK := 3.0

# Sonar billing cadence; independent of SONAR_INTERVAL (ping rate).
const SONAR_DRAIN_INTERVAL := 3.0
var _sonar_drain_timer := 0.0

var _ability_cooldown := 0.0
var _is_grappling := false

# Toggled with Q; passive_id says who can use it. Changes emit sonar_changed for the HUD.
var sonar_active := false:
	set(value):
		if value == sonar_active:
			return
		sonar_active = value
		sonar_changed.emit()

# Sonar on: a cyan ring pulses out from the diver and fades, once a second.
const SONAR_FX_INTERVAL := 1.0
const SONAR_FX_DURATION := 1.4
const SONAR_FX_RADIUS := 4.5
const SONAR_FX_COLOR := Color(0.35, 0.9, 1.0)
var _sonar_fx_timer := 0.0

func _process(dt: float) -> void:
	_ability_cooldown = maxf(0.0, _ability_cooldown - dt)
	if sonar_active and visible and not exploration_paused:
		_sonar_fx_timer -= dt
		if _sonar_fx_timer <= 0.0:
			_sonar_fx_timer = SONAR_FX_INTERVAL
			_sonar_pulse_fx()
	else:
		_sonar_fx_timer = 0.0

	# Timed off a clock, not an AnimationPlayer signal, since the diver may be freed mid-clip.
	if _busy_until > 0.0:
		_clock += dt
		if _clock >= _busy_until:
			_busy_until = 0.0
			_motion = ""
			# Nothing drives _animate() in battle, so return to the held/idle loop here.
			play_motion(_hold if _hold != "" else "idle")

func _sonar_pulse_fx() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.965
	torus.outer_radius = 1.0
	torus.rings = 48
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(SONAR_FX_COLOR, 0.75)
	mat.emission_enabled = true
	mat.emission = SONAR_FX_COLOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.position = Vector3.ZERO   # body centre (origin is mid-capsule)
	ring.scale = Vector3.ONE * 0.3
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * SONAR_FX_RADIUS, SONAR_FX_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mat, "albedo_color:a", 0.0, SONAR_FX_DURATION).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)

# Mirrors use_ability()'s guard; world.gd checks this before aiming.
func can_use_ability() -> bool:
	return (ability_id != "" and not ability_locked and _ability_cooldown <= 0.0
		and not _is_grappling and not shockwave_needs_oxygen())

# True only when this is Shockwave and the tank can't pay for it.
func shockwave_needs_oxygen() -> bool:
	return ability_id == "shockwave" and stats.oxygen < SHOCKWAVE_OXYGEN_COST

# Called by grapple_anchor.gd's on_grappled_to(). Safe on unlocked divers.
func unlock_ability() -> void:
	ability_locked = false

func is_grappling() -> bool:
	return _is_grappling

# Set by whirlpool.gd while its tween drives global_position; swim() yields.
var _suction_locked := false

func set_suction_locked(v: bool) -> void:
	_suction_locked = v

func is_suction_locked() -> bool:
	return _suction_locked

# Written by WaterCurrent while overlapping; current_axis limits steering to the flow.
var external_push := Vector3.ZERO
var current_axis := Vector3.ZERO

# Only grapple uses first-person aim; swap goes through TargetSelector.
func ability_needs_aim() -> bool:
	return ability_id == "grapple"

# aim_dir: world-space grapple aim; zero falls back to body facing.
# target: swap target preselected by TargetSelector.
func use_ability(aim_dir: Vector3 = Vector3.ZERO, target: Node3D = null) -> void:
	if not can_use_ability():
		return
	match ability_id:
		"shockwave":
			_shockwave()
		"grapple":
			_grapple(aim_dir)
		"swap":
			_swap(target as Diver)


func _shockwave() -> void:
	_ability_cooldown = SHOCKWAVE_COOLDOWN
	stats.oxygen = maxf(0.0, stats.oxygen - SHOCKWAVE_OXYGEN_COST)
	get_tree().call_group("shockwave_breakable", "on_shockwave", global_position, SHOCKWAVE_RADIUS)
	_shockwave_vfx()

# Visual only; breaking is handled by the shockwave_breakable group.
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

# Battles end with passives off; the player re-enables Sonar deliberately.
func reset_passives_after_battle() -> void:
	sonar_active = false

func toggle_sonar() -> bool:
	if passive_id != "sonar":
		return false
	sonar_active = not sonar_active and stats.oxygen > 0.0
	if sonar_active:
		# A fresh toggle-on gets a full interval before the first charge.
		_sonar_drain_timer = SONAR_DRAIN_INTERVAL
	return sonar_active

# Carries combat-consumed state and the Sonar billing clock across scene handoffs.
func campaign_member_state() -> Dictionary:
	return {"model": model_name, "stats": stats,
		"known_spells": known_spells.duplicate(), "equipped_spells": equipped_spells.duplicate(),
		"sonar_active": sonar_active, "sonar_drain_timer": _sonar_drain_timer,
		"sonar_timer": sonar_timer, "ability_locked": ability_locked}

func restore_campaign_member(data: Dictionary) -> void:
	assert(String(data.model) == model_name, "Campaign diver identity mismatch")
	stats = data.stats as CombatantStats
	known_spells.assign(data.known_spells)
	equipped_spells.assign(data.equipped_spells)
	sonar_active = bool(data.sonar_active)
	_sonar_drain_timer = float(data.sonar_drain_timer)
	sonar_timer = float(data.sonar_timer)
	ability_locked = bool(data.ability_locked)

func _physics_process(delta: float) -> void:
	if exploration_paused:
		return
	if passive_id == "sonar" and sonar_active:
		_sonar_drain_timer -= delta
		while _sonar_drain_timer <= 0.0 and sonar_active:
			# Keep overshoot so billing is frame-rate independent.
			_sonar_drain_timer += SONAR_DRAIN_INTERVAL
			stats.oxygen = maxf(0.0, stats.oxygen - SONAR_OXYGEN_PER_TICK)
			if stats.oxygen <= 0.0:
				sonar_active = false
		sonar_timer -= delta
		if sonar_timer <= 0.0:
			sonar_timer = SONAR_INTERVAL
			update_sonar()

# Reveals unclaimed key items within minimap range of the active diver.
# Reveals are permanent for the run.
func update_sonar() -> void:
	if world == null:
		return
	if world.embedded_maze != null and world.embedded_maze.maze_active:
		return # MazeMiniMap owns Sonar in an active maze.
	var s_items := []
	for item in ItemGuardian.spots():
		if world.key_items.has(String(item.item)):
			continue
		s_items.append(item)
	for entry in s_items:
		var item_id := String(entry.item)
		if world.revealed_key_items.has(item_id):
			continue
		# Same radius as the minimap's dot display, measured from the active diver.
		var scan_pos: Vector3 = (world.divers[world.active] as Diver).position
		if scan_pos.distance_to(entry.at as Vector3) <= world.minimap.view_radius:
			world.revealed_key_items.append(item_id)


# Fires along aim_dir (camera), else body facing. The beam always shows; only a
# grapple_anchor hit spends the cooldown, so misses can retry immediately.
func _grapple(aim_dir: Vector3) -> void:
	var dir: Vector3 = aim_dir.normalized() if aim_dir.length() > 0.01 else -global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var from: Vector3 = global_position + Vector3(0, height * 0.4, 0)
	var to: Vector3 = from + dir * GRAPPLE_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	# Keep the live ray aligned with the aim preview and ignore party bodies.
	query.exclude = [get_rid()]
	query.collision_mask = GRAPPLE_COLLISION_MASK
	var result := space.intersect_ray(query)

	# Beam ends where the ray stopped, or at max range.
	var beam_end: Vector3 = to if result.is_empty() else (result.position as Vector3)
	_grapple_beam_vfx(from, beam_end)

	if result.is_empty() or not (result.collider as Node).is_in_group("grapple_anchor"):
		return

	_ability_cooldown = GRAPPLE_COOLDOWN
	# Reel-in targets reward the shooter directly.
	if (result.collider as Node).has_method("reel_in_to"):
		(result.collider as Node).call("reel_in_to", self)
		return
	_is_grappling = true
	var target: Vector3 = (result.collider as Node3D).global_position

	# Let the anchor react to being reached.
	if (result.collider as Node).has_method("on_grappled_to"):
		(result.collider as Node).call("on_grappled_to")

	velocity = Vector3.ZERO
	var tw := create_tween()
	# Stop a short step short of the anchor's own center, not on top of it.
	var stop_at: Vector3 = target - dir * 1.0
	tw.tween_property(self, "global_position", stop_at, GRAPPLE_PULL_DURATION)
	tw.tween_callback(func() -> void: _is_grappling = false)

# Visual only: a fixed beam that fades over the pull duration.
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

# Instantly trade places with a TargetSelector-chosen ally. An invalid target
# is a no-op and costs no cooldown.
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

# Flash at both spots so it reads as a trade, not a teleport.
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

# Called by gap_pit.gd: hit recoil plus a visibility flicker that reads through fog.
func flash_damage() -> void:
	if model == null:
		return
	play_hit_reaction(false)
	var tw := create_tween()
	for i in range(4):
		tw.tween_property(model, "visible", false, 0.08)
		tw.tween_property(model, "visible", true, 0.08)

# Used by whirlpool.gd to hide the diver while caught.
func set_model_visible(v: bool) -> void:
	if model != null:
		model.visible = v


# Model extent relative to origin. Diver models are centred (goblin.gd's stand on
# their feet), so head markers must ask rather than add `height`.
func head_offset() -> float:
	return height * 0.5

func foot_offset() -> float:
	return -height * 0.5


# ============================================================
# PLAYING CLIPS
# ============================================================

# Armature prefixes differ per delivery; learn it once from a known clip.
func _learn_prefix(known_stem: String) -> void:
	_prefix = ""
	if anim == null or known_stem == "":
		return
	for a in anim.get_animation_list():
		var nm := String(a)
		var bar := nm.rfind("|")
		if bar >= 0 and nm.substr(bar + 1) == known_stem:
			_prefix = nm.substr(0, bar + 1)
			return

# Stem to full clip name. Match after the bar only; a prefix match can return
# another character's clip.
func resolve(stem: String) -> String:
	if anim == null or stem == "":
		return ""
	if _prefix != "" and anim.has_animation(_prefix + stem):
		return _prefix + stem
	if anim.has_animation(stem):
		return stem
	if anim.has_animation("spells/" + stem):
		return "spells/" + stem
	for a in anim.get_animation_list():
		var nm := String(a)
		var bar := nm.rfind("|")
		if (nm.substr(bar + 1) if bar >= 0 else nm) == stem:
			return nm
	return ""

# Looping state. Cheap per frame; no-op if already playing or a one-shot is running.
func play_motion(name: String) -> void:
	if anim == null or _busy_until > 0.0 or _motion == name:
		return
	var full := resolve(Cast.motion(model_name, name))
	if full == "":
		return
	_motion = name
	# Animations are shared across instances; never use one clip as both loop and one-shot.
	var a: Animation = anim.get_animation(full)
	a.loop_mode = Animation.LOOP_LINEAR
	anim.play(full)

# Swim/idle with Start/End transitions. A running one-shot takes priority.
func _update_motion(moving: bool) -> void:
	if moving == _was_moving:
		play_motion("swim" if moving else "idle")
		return

	_was_moving = moving
	if _busy_until > 0.0:
		# Mid one-shot: skip the transition; _process() returns to _hold afterwards.
		_hold = "swim" if moving else "idle"
		return

	_hold = "swim" if moving else "idle"
	if play_clip(Cast.motion(model_name, "swim_start" if moving else "swim_end")) <= 0.0:
		play_motion(_hold)

# One-shot clip by stem. Returns its length so callers can wait exactly that long.
func play_clip(stem: String) -> float:
	if anim == null:
		return 0.0
	var full := resolve(stem)
	if full == "":
		push_error("NO CLIP '%s' for %s" % [stem, model_name])
		return 0.0
	var a: Animation = anim.get_animation(full)
	a.loop_mode = Animation.LOOP_NONE
	anim.play(full)
	_motion = ""
	_clock = 0.0
	_busy_until = a.length
	return a.length

# Hit reaction chosen by severity.
func play_hit_reaction(heavy: bool) -> float:
	return play_clip(Cast.motion(model_name, "hurt_bad" if heavy else "hurt"))

# Won the fight. Loops, because the victory screen sits there for a while.
func play_win() -> void:
	_busy_until = 0.0
	_motion = ""
	_hold = "win"
	play_motion("win")

# Faint: Start plays once, then the Mid loop holds the pose.
func play_down() -> void:
	# Set _hold first so there's no one-frame neutral float after Start.
	_hold = "down"
	play_clip(Cast.motion(model_name, "down_start"))

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null

# ============================================================
# BUBBLES
# ============================================================

func _add_bubbles() -> void:

	# CPU particles for the compatibility renderer / web export.

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


	bubbles.position = Vector3(
		0,
		height * 0.35,
		0
	)

	add_child(bubbles)


# ============================================================
# SWIMMING
# ============================================================

# dir: desired world-space horizontal direction. rise: -1 down, 0 level, +1 up.

func swim(dir: Vector3, rise: float, dt: float) -> void:

	# Grapple/suction tweens own global_position; move_and_slide() would fight them.
	if _is_grappling or _suction_locked:
		return

	var steer := dir
	if current_axis != Vector3.ZERO:
		steer = current_axis * dir.dot(current_axis)
	var want := steer * speed

	want.y = rise * speed * 0.7
	want += external_push


	# ========================================================
	# ACCELERATION / DRAG
	# ========================================================

	if want == Vector3.ZERO:

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

	var old_position := global_position


	move_and_slide()


	var distance_moved := old_position.distance_to(
		global_position
	)


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

	distance_since_encounter = 0.0


	encounter_distance = randf_range(
		min_encounter_distance,
		max_encounter_distance
	)


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


	# Hysteresis so drift speed doesn't keep restarting transition clips.
	var speed_now := velocity.length()
	var moving := _was_moving
	if speed_now > 0.6:
		moving = true
	elif speed_now < 0.25:
		moving = false

	_update_motion(moving)

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

	# The swim clip is already horizontal; only add a small climb/dive pitch.
	var want_pitch: float = clampf(
		velocity.y * 0.12,
		-0.35,
		0.35
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
	# NOSE UP TO CLIMB, NOSE DOWN TO DIVE
	# ========================================================

	model.rotation.x = _lean


	# ========================================================
	# BUBBLES
	# ========================================================

	if bubbles != null:

		bubbles.emitting = true


# Battle-stage actor at 0 HP: faint, then fade, sink and shrink like goblin.gd.
# Materials are duplicated because they're shared across instances.
func play_death_fade() -> void:
	play_down()
	var tw := create_tween()
	tw.set_parallel(true)
	for m in _all_meshes(model):
		var mesh_instance := m as MeshInstance3D
		# Skip the hidden other-character meshes (see _ready()).
		if not mesh_instance.is_visible_in_tree():
			continue
		if mesh_instance.mesh == null:
			continue
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
	# Not freed: a revive spell needs the actor to un-fade (play_revive()).

# Reverses play_death_fade() on revive, then clears the override materials.
func play_revive() -> void:
	var overrides: Array = []
	var tw := create_tween()
	tw.set_parallel(true)
	for m in _all_meshes(model):
		var mesh_instance := m as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var mat := mesh_instance.get_surface_override_material(surface)
			if mat == null or not (mat is BaseMaterial3D):
				continue
			overrides.append([mesh_instance, surface])
			tw.tween_property(mat, "albedo_color:a", 1.0, 0.6)
	tw.tween_property(self, "position:y", position.y + 0.6, 0.6)
	tw.tween_property(self, "scale", scale / 0.7, 0.6)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		for pair in overrides:
			(pair[0] as MeshInstance3D).set_surface_override_material(int(pair[1]), null)
		_hold = ""
		play_motion("idle")
	)

func _all_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out

# ============================================================
# WORLD AABB
# ============================================================

# Mesh AABB in `root`'s space, walking intermediate transforms (e.g. Skeleton3D scale).
func _world_aabb(m: MeshInstance3D, root: Node) -> AABB:

	var a: AABB = m.get_aabb()

	var t: Transform3D = m.transform

	var p: Node = m.get_parent()

	while p != null and p is Node3D and p != root:

		t = (p as Node3D).transform * t

		p = p.get_parent()


	var out := AABB(
		t * a.get_endpoint(0),
		Vector3.ZERO
	)


	for i in range(8):

		out = out.expand(
			t * a.get_endpoint(i)
		)


	return out
