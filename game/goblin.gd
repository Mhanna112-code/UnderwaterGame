# The grunt's model, sized and floor-aligned once here so nothing else has to
# care that this FBX's own units were never hand-measured (no editor was open
# to run tools/measure_fbx.gd against it, so it's rescaled to a target height
# and dropped onto the seabed from whatever box it actually measures at
# runtime, instead of a guessed constant). Display only: no collision, no
# movement. Used by game/battle.gd to put the enemy on the battle stage.
class_name Goblin
extends Node3D

const SRC := preload("res://characters/GoblinGrunt.fbx")
const TARGET_HEIGHT := 1.6

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
	"evasion": 2, "accuracy": 3, "barrier_max": 0,
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
var _walk_anim := ""
var _idle_anim := ""

func _ready() -> void:
	var model: Node3D = SRC.instantiate()
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
			if "walk" in lower:
				_walk_anim = a
			elif "idle" in lower:
				_idle_anim = a
	play("idle")

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
# barrier_max is halved before the edge is applied - matching the party's
# barrier outright would make every grunt as shielded as a Prototype_V
# (1922) that's been stacking barrier spells, which reads as a
# tank-specialist trait borrowed wholesale rather than "a grunt that
# happens to be roughly your size, just a bit tougher."
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
	s.barrier_max = maxi(0, int(round(float(ref.barrier_max) * 0.5 * _edge())))
	s.fill()
	return s

func _edge() -> float:
	return randf_range(MIN_EDGE, MAX_EDGE)

# substr: "idle" or "walk", matched loosely against the FBX's own take names
# ("rig|Idle", "rig|Walking", ...) so exact capitalisation doesn't matter.
func play(substr: String) -> void:
	if anim == null:
		return
	var want := _walk_anim if substr == "walk" else _idle_anim
	if want == "" and not anim.get_animation_list().is_empty():
		want = anim.get_animation_list()[0]
	if want != "" and anim.current_animation != want:
		anim.play(want)

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
	play("idle")
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
