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

# No grow_* here - the grunt doesn't level on its own timeline the way a
# diver does. Instead make_stats() scales this base spread up against
# whatever level the player is at when the fight starts (SCALE_PER_LEVEL
# below), so it stays a real fight instead of free XP once you've leveled a
# few times. When a second enemy type shows up, it gets its own script with
# its own BASE_STATS/SCALE_PER_LEVEL instead of this one growing extra cases.
const BASE_STATS := {
	"hp": 20, "strength": 4, "defense": 2, "agility": 4,
	"evasion": 3, "accuracy": 5, "barrier_max": 0,
}

# +12% to every stat per player level above 1. Multiplicative, not additive,
# so the ratio between strength/defense/agility/evasion/accuracy stays the
# grunt's own shape at any level - it just gets uniformly tougher, not
# lopsided.
const SCALE_PER_LEVEL := 0.12

# XP a win pays out, before scaling (see make_stats). Read by
# game/battle.gd's _win() as enemy_actor.xp_reward - a grunt scaled up to
# match a high-level player is worth more than the same grunt at level 1,
# not a flat amount regardless of how hard the fight actually was.
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

# Fresh, level-scaled stats for one fight. Enemies don't persist between
# battles, so unlike Diver.stats this isn't built once and kept - battle.gd
# calls this each time it stands a grunt up, passing the player's current
# level so the grunt scales to match instead of always fighting at level 1.
#
# jitter_pct applies an independent random multiplier per stat (not one
# shared multiplier for the whole grunt) so a pack of several doesn't read
# as identical clones - one might land a bit tougher, another a bit more
# accurate, purely by chance. 0 (the default) means no jitter at all, the
# exact scaled BASE_STATS - what a lone grunt still gets.
func make_stats(player_level: int = 1, jitter_pct: float = 0.0) -> CombatantStats:
	var scale: float = 1.0 + float(maxi(player_level - 1, 0)) * SCALE_PER_LEVEL
	xp_reward = maxi(1, int(round(float(BASE_XP) * scale)))

	var s := CombatantStats.new()
	s.hp_max = maxi(1, int(round(float(BASE_STATS.hp) * scale * _jit(jitter_pct))))
	s.strength = maxi(1, int(round(float(BASE_STATS.strength) * scale * _jit(jitter_pct))))
	s.defense = maxi(0, int(round(float(BASE_STATS.defense) * scale * _jit(jitter_pct))))
	s.agility = maxi(1, int(round(float(BASE_STATS.agility) * scale * _jit(jitter_pct))))
	s.evasion = maxi(0, int(round(float(BASE_STATS.evasion) * scale * _jit(jitter_pct))))
	s.accuracy = maxi(0, int(round(float(BASE_STATS.accuracy) * scale * _jit(jitter_pct))))
	s.barrier_max = maxi(0, int(round(float(BASE_STATS.barrier_max) * scale * _jit(jitter_pct))))
	s.fill()
	return s

func _jit(pct: float) -> float:
	return 1.0 if pct <= 0.0 else randf_range(1.0 - pct, 1.0 + pct)

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
