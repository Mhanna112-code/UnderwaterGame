# The ordinary enemy's model, sized and floor-aligned once here so nothing else
# has to care about its FBX units. Its gameplay class deliberately remains
# Goblin: combat, balance and saved-game code already depend on that stable
# actor contract. The visible model is Glassgoat's Angler Fish. Display only:
# no collision or world movement. Used by game/battle.gd on the battle stage.
class_name Goblin
extends Node3D

const SRC := preload("res://characters/Angler_Fish.fbx")
const TARGET_HEIGHT := 1.6

# Unlike the retired Goblin and the divers, this rig's visible face is its
# local +Z axis. Battle uses face_toward() instead of assuming all actors have
# the same forward axis.
const COMBAT_FRONT_AXIS := Vector3.FORWARD

# No grow_* here, and no independent base spread either anymore - a grunt's
# stats are derived straight from the party's own current stats in
# make_stats() (battle.gd hands it the party's average CombatantStats), not
# a separate curve that could drift away from what the party can actually
# do. floor_stats is the only thing still fixed here: a bare-minimum shape
# for the extreme edge case of an empty/all-zero reference (shouldn't
# happen in practice - there's always at least one living party member by
# the time a Battle exists - but make_stats() has to return *something*
# sane rather than a grunt with 0 evasion/accuracy/agility).
const FLOOR_STATS := {
	"hp": 12, "strength": 3, "defense": 1, "agility": 3,
	"evasion": 2, "accuracy": 3,
}

# XP a win pays out, before level scaling (see make_stats). Read by
# game/battle.gd's _win() as enemy_actor.xp_reward - a grunt matched to a
# high-level party is worth more than the same fight at level 1, not a flat
# amount regardless of how tough the party it was scaled against actually is.
const BASE_XP := 10
var xp_reward: int = BASE_XP

var anim: AnimationPlayer
var height := 1.6
var radius := 0.4
var _idle_anim := ""
var _swim_anim := ""
var _attack_anim := ""
var _hurt_anim := ""
var _death_anim := ""

func _ready() -> void:
	var model: Node3D = model_source().instantiate()
	model.name = "Model"
	add_child(model)

	var box: AABB = _world_aabb(model)
	var raw_height: float = maxf(box.size.y, 0.05)
	model.scale *= TARGET_HEIGHT / raw_height
	box = _world_aabb(model)
	height = box.size.y
	radius = maxf(0.3, minf(box.size.x, box.size.z) * 0.5)
	model.position.y -= box.position.y

	anim = _find_anim(model)
	if anim != null:
		for a in anim.get_animation_list():
			var lower := String(a).to_lower()
			if "idle" in lower:
				_idle_anim = a
			elif "swimming" in lower and "mid" in lower:
				_swim_anim = a
			elif "damaged" in lower:
				_hurt_anim = a
			elif "death" in lower:
				_death_anim = a
	_attack_anim = _resolve_clip(primary_attack_clip())
	play("idle")

# The existing Goblin class is the stable enemy actor contract used by battle,
# guardian triggers, progression and balance. Subclasses swap only asset-facing
# facts; all of those systems can keep treating the actor as a Goblin.
func model_source() -> PackedScene:
	return SRC

func enemy_catalogue() -> Array:
	return EnemyMoves.angler_catalogue()

func enemy_id() -> String:
	return "angler"

func display_name() -> String:
	return "Angler"

func primary_attack_clip() -> String:
	return "attack)bite"

# Always at least a little stronger than ref on every stat, never weaker
# and never exactly equal - a fight should never quietly be easier than the
# party's own numbers just because the roll happened to land low. _edge()
# is one-sided (always > 1.0), independently rolled per stat rather than
# one shared multiplier for the whole grunt, so a pack of several still
# doesn't read as identical clones - one might land a bit tougher, another
# a bit more accurate, but never a bit weaker.
const MIN_EDGE := 1.08
const MAX_EDGE := 1.35

# Fresh stats for one fight, rolled off ref (the party's average
# CombatantStats - see battle.gd's _build_stage(), which builds that
# average across every living party member before calling this). Enemies
# don't persist between battles, so unlike Diver.stats this isn't built
# once and kept - battle.gd calls this each time it stands a grunt up.
# This one stands its model's feet on its own origin (see _ready()'s
# model.position.y line), which is the opposite of what diver.gd does. Both
# conventions are fine; assuming either one is not. See Diver.head_offset().
func head_offset() -> float:
	return height

func foot_offset() -> float:
	return 0.0

func make_stats(ref: CombatantStats, player_level: int = 1) -> CombatantStats:
	xp_reward = maxi(1, int(round(float(BASE_XP) * (1.0 + float(maxi(player_level - 1, 0)) * 0.12))))

	var s := CombatantStats.new()
	s.hp_max = maxi(1, int(round(maxf(float(FLOOR_STATS.hp), float(ref.hp_max)) * _edge())))
	s.strength = maxi(1, int(round(maxf(float(FLOOR_STATS.strength), float(ref.strength)) * _edge())))
	s.defense = maxi(0, int(round(maxf(float(FLOOR_STATS.defense), float(ref.defense)) * _edge())))
	s.agility = maxi(1, int(round(maxf(float(FLOOR_STATS.agility), float(ref.agility)) * _edge())))
	s.evasion = maxi(0, int(round(maxf(float(FLOOR_STATS.evasion), float(ref.evasion)) * _edge())))
	s.accuracy = maxi(0, int(round(maxf(float(FLOOR_STATS.accuracy), float(ref.accuracy)) * _edge())))
	s.fill()
	return s

func _edge() -> float:
	return randf_range(MIN_EDGE, MAX_EDGE)

# Keys are semantic rather than raw FBX paths. Glassgoat's non-humanoid rig
# names its moves differently from the retired Goblin: swim loop, Bite,
# Damaged, and Death. Keeping that translation here lets battle.gd ask for
# the same readable actions regardless of importer naming.
func play(substr: String) -> void:
	if anim == null:
		return
	var want := _idle_anim
	match substr:
		"swim", "walk":
			want = _swim_anim
		"attack":
			want = _attack_anim
		"hurt":
			want = _hurt_anim
		"death":
			want = _death_anim
	if want == "" and not anim.get_animation_list().is_empty():
		want = anim.get_animation_list()[0]
	if want != "" and anim.current_animation != want:
		anim.play(want)

# A fresh deep copy makes it safe for Battle/UI code to attach per-turn data
# without mutating the next encounter's artist-facing catalogue.
func available_moves() -> Array:
	var available: Array = []
	for move_value in enemy_catalogue():
		var move := move_value as Dictionary
		if bool(move.get("enabled", false)):
			available.append(move)
	return available

func has_clip_fragment(fragment: String) -> bool:
	return _resolve_clip(fragment) != ""

func play_move(move: Dictionary) -> float:
	if anim == null or not bool(move.get("enabled", false)):
		return 0.0
	var clip := _resolve_clip(String(move.get("clip", "")))
	if clip == "":
		return 0.0
	anim.play(clip)
	var animation := anim.get_animation(clip)
	return animation.length if animation != null else 0.0

# Select by authored data, not a conditional tied to a particular animation.
# `finisher_below_hp` is optional; any enabled move with it makes the target
# low-health state use every move's finisher_weight instead of normal weight.
func choose_move(target: CombatantStats) -> Dictionary:
	var moves := available_moves()
	if moves.is_empty():
		return {}
	# Keep a deliberate roll order in content data. This preserves deterministic
	# balance seeds while allowing the catalogue to stay human-readable.
	moves.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("roll_order", 0)) < int(right.get("roll_order", 0)))
	var finisher := false
	for move_value in moves:
		var move := move_value as Dictionary
		var threshold := float(move.get("finisher_below_hp", 0.0))
		if threshold > 0.0 and float(target.hp) <= float(target.hp_max) * threshold:
			finisher = true
			break
	var total := 0.0
	for move_value in moves:
		var move := move_value as Dictionary
		total += maxf(0.0, float(move.get("finisher_weight", 0.0) if finisher else move.get("weight", 0.0)))
	if total <= 0.0:
		return {}
	var roll := randf() * total
	for move_value in moves:
		var move := move_value as Dictionary
		roll -= maxf(0.0, float(move.get("finisher_weight", 0.0) if finisher else move.get("weight", 0.0)))
		if roll <= 0.0:
			return move.duplicate(true)
	return (moves.back() as Dictionary).duplicate(true)

func face_toward(world_target: Vector3) -> void:
	var to := world_target - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	# For a local +Z front, yaw 0 faces world +Z. This is intentionally the
	# opposite sign from the divers'/-Z helper in Battle._step_toward().
	rotation.y = atan2(to.x, to.z)

func _resolve_clip(fragment: String) -> String:
	if anim == null or fragment.strip_edges().is_empty():
		return ""
	var wanted := fragment.to_lower().replace(" ", "")
	for clip_value in anim.get_animation_list():
		var clip := String(clip_value)
		if clip.to_lower().replace(" ", "").contains(wanted):
			return clip
	return ""

# Called by battle.gd the instant a hit actually brings this grunt to 0 HP.
# Fades every mesh surface to transparent while the whole model sinks and
# shrinks slightly - reads as "dying and disappearing," not just "the model
# popped out of existence." Fire-and-forget: nothing awaits this, it just
# queue_free()s itself once the tween's done, same pattern diver.gd's own
# throwaway VFX (_shockwave_vfx(), _swap_flash()) already use.
#
# Duplicates each surface's material before touching it rather than editing
# in place - the imported FBX's materials may be shared resources (Godot
# caches imported materials across instances of the same asset), so
# mutating one in place could fade every other living grunt on the stage
# along with this one.
func play_death_fade() -> void:
	play("death")
	var tw := create_tween()
	tw.set_parallel(true)
	for m in _meshes(self):
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

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null

func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

func _world_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in _meshes(n):
		var mi := m as MeshInstance3D
		var a: AABB = mi.get_aabb()
		var t: Transform3D = mi.global_transform
		for i in range(8):
			var p: Vector3 = t * a.get_endpoint(i)
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out
