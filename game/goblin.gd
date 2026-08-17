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
	"hp": 20, "attack": 4, "defense": 2, "speed": 4, "luck": 3,
	"dodge": 0.05, "accuracy": 0.05, "barrier_max": 0,
}

# +12% to every stat per player level above 1. Multiplicative, not additive,
# so the ratio between hp/attack/defense/speed/luck stays the grunt's own
# shape at any level - it just gets uniformly tougher, not lopsided.
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
func make_stats(player_level: int = 1) -> CombatantStats:
	var scale: float = 1.0 + float(maxi(player_level - 1, 0)) * SCALE_PER_LEVEL
	xp_reward = maxi(1, int(round(float(BASE_XP) * scale)))

	var s := CombatantStats.new()
	s.hp_max = maxi(1, int(round(float(BASE_STATS.hp) * scale)))
	s.attack = maxi(1, int(round(float(BASE_STATS.attack) * scale)))
	s.defense = maxi(0, int(round(float(BASE_STATS.defense) * scale)))
	s.speed = maxi(1, int(round(float(BASE_STATS.speed) * scale)))
	s.luck = maxi(0, int(round(float(BASE_STATS.luck) * scale)))
	s.dodge = clampf(float(BASE_STATS.dodge) * scale, 0.0, 0.95)
	s.accuracy = clampf(float(BASE_STATS.accuracy) * scale, 0.0, 0.95)
	s.barrier_max = maxi(0, int(round(float(BASE_STATS.barrier_max) * scale)))
	s.fill()
	return s

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
