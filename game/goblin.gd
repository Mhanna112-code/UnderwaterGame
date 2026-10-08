# Ordinary enemy actor (class stays Goblin for combat/save compatibility); shows the Angler Fish.
# Display only: sized and floor-aligned here, no collision or movement.
class_name Goblin
extends Node3D

const SRC := preload("res://characters/Angler_Fish.fbx")
const TARGET_HEIGHT := 1.6

# This rig faces local +Z; battle uses face_toward() rather than assuming a forward axis.
const COMBAT_FRONT_AXIS := Vector3.FORWARD

# Authored species base stats; a 5-10% encounter roll is applied to non-Evasion stats.
const BASE_STATS := {
	"hp": 5, "strength": 2, "defense": 0, "agility": 2,
	"evasion": 1, "accuracy": 3,
}

# Dev-only switch (--flag/?query=1) restoring the legacy floor+random-edge formula for comparison.
static func legacy_scaling_requested() -> bool:
	if OS.get_cmdline_user_args().has("--legacy-enemy-scaling"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return String(search).contains("legacy_enemy_scaling=1")
	return false

# Legacy floor/edge formula, used only by legacy_scaling_requested().
const LEGACY_FLOOR_STATS := {
	"hp": 15, "strength": 3, "defense": 1, "agility": 3,
	"evasion": 2, "accuracy": 3,
}
const LEGACY_MIN_EDGE := 1.08
const LEGACY_MAX_EDGE := 1.35

func _legacy_edge() -> float:
	return randf_range(LEGACY_MIN_EDGE, LEGACY_MAX_EDGE)

func _legacy_stats_from(ref: CombatantStats) -> CombatantStats:
	var s := CombatantStats.new()
	s.hp_max = maxi(1, int(round(maxf(float(LEGACY_FLOOR_STATS.hp), float(ref.hp_max)) * _legacy_edge())))
	s.strength = maxi(1, int(round(maxf(float(LEGACY_FLOOR_STATS.strength), float(ref.strength)) * _legacy_edge())))
	s.defense = maxi(0, int(round(maxf(float(LEGACY_FLOOR_STATS.defense), float(ref.defense)) * _legacy_edge())))
	s.agility = maxi(1, int(round(maxf(float(LEGACY_FLOOR_STATS.agility), float(ref.agility)) * _legacy_edge())))
	# Marc's no-Evasion-boost rule also applies to the optional legacy route.
	s.evasion = maxi(0, maxi(int(LEGACY_FLOOR_STATS.evasion), ref.evasion))
	s.accuracy = maxi(0, int(round(maxf(float(LEGACY_FLOOR_STATS.accuracy), float(ref.accuracy)) * _legacy_edge())))
	s.fill()
	return s

# XP a win pays out before level scaling; read by battle.gd's _win().
const BASE_XP := 20
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
	# Long rigs can declare a presentation cap so height normalization doesn't make them too wide.
	var horizontal_span := maxf(box.size.x, box.size.z)
	var horizontal_cap := max_visual_horizontal_span()
	if horizontal_cap < INF and horizontal_span > horizontal_cap:
		model.scale *= horizontal_cap / horizontal_span
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
				var idle_animation := anim.get_animation(a)
				if idle_animation != null:
					idle_animation.loop_mode = Animation.LOOP_LINEAR
			elif "swimming" in lower and "mid" in lower:
				_swim_anim = a
			elif "damaged" in lower:
				_hurt_anim = a
			elif "death" in lower:
				_death_anim = a
	_attack_anim = _resolve_clip(primary_attack_clip())
	play("idle")

# Subclasses swap only asset-facing facts; systems still treat the actor as a Goblin.
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

# Long-bodied subclasses can override to cap their horizontal span.
func max_visual_horizontal_span() -> float:
	return INF

# World-space mesh bounds for battle framing.
func visual_bounds() -> AABB:
	return _world_aabb(self)

# Feet sit on the origin (opposite of diver.gd); see Diver.head_offset().
func head_offset() -> float:
	return height

func foot_offset() -> float:
	return 0.0

# `ref` is only used by the legacy route; kept so the signature matches SwordDuelist.make_stats().
func make_stats(ref: CombatantStats, player_level: int = 1) -> CombatantStats:
	xp_reward = maxi(1, int(round(float(BASE_XP) * (1.0 + float(maxi(player_level - 1, 0)) * 0.12))))
	if legacy_scaling_requested():
		return _legacy_stats_from(ref)
	return _stats_from(BASE_STATS)

# Independent 5-10% boost per stat on top of `base`.
const BOOST_MIN := 1.05
const BOOST_MAX := 1.10
func _boost() -> float:
	return randf_range(BOOST_MIN, BOOST_MAX)

# Shared with SwordDuelist. stat_floor is the unboosted base, so debuffs can't go below it.
func _stats_from(base: Dictionary) -> CombatantStats:
	var s := CombatantStats.new()
	s.hp_max = int(round(float(base.hp) * _boost()))
	s.strength = int(round(float(base.strength) * _boost()))
	s.defense = int(round(float(base.defense) * _boost()))
	s.agility = int(round(float(base.agility) * _boost()))
	# Evasion stays authored, independently of the other encounter rolls.
	s.evasion = int(base.evasion)
	s.accuracy = int(round(float(base.accuracy) * _boost()))
	s.fill()
	s.stat_floor = {
		"strength": int(base.strength), "defense": int(base.defense),
		"agility": int(base.agility), "evasion": int(base.evasion),
		"accuracy": int(base.accuracy),
	}
	return s

# Semantic keys mapped to this rig's animation names so battle.gd can ask for readable actions.
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
	if want != "" and (anim.current_animation != want or not anim.is_playing()):
		anim.play(want)

# Deep copy so per-turn data doesn't mutate the catalogue.
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

# Select by authored data. Any enabled `finisher_below_hp` move switches to finisher_weight at low target HP.
func choose_move(target: CombatantStats) -> Dictionary:
	var moves := available_moves()
	if moves.is_empty():
		return {}
	# Deliberate roll order keeps balance seeds deterministic.
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

# Angler policy: below half HP, 37.5% Headbutt on the top damage dealer; otherwise random Bite,
# with one Flash Blast when misses catch up to hits.
const LOW_HP_FRACTION := 0.5
const STUN_PRIORITY_CHANCE := 0.375
var _damage_taken_by: Dictionary = {}
var _bite_hits := 0
var _bite_misses := 0
var _use_flash_blast_next := false

func record_damage_taken(from_actor: Node, amount: int) -> void:
	if enemy_id() != "angler" or amount <= 0 or not is_instance_valid(from_actor):
		return
	_damage_taken_by[from_actor] = int(_damage_taken_by.get(from_actor, 0)) + amount

func record_bite_result(hit: bool) -> void:
	if enemy_id() != "angler":
		return
	if hit:
		_bite_hits += 1
	else:
		_bite_misses += 1
	_use_flash_blast_next = _bite_misses >= _bite_hits

func _find_move(id: String) -> Dictionary:
	for move_value in available_moves():
		var move := move_value as Dictionary
		if String(move.get("id", "")) == id:
			return move
	return {}

func _highest_damage_target(alive_party: Array, fallback: Dictionary) -> Dictionary:
	var best_amount := 0
	var best_entries: Array = []
	for entry_value in alive_party:
		var entry := entry_value as Dictionary
		var dealt := int(_damage_taken_by.get(entry.get("actor"), 0))
		if dealt > best_amount:
			best_amount = dealt
			best_entries = [entry]
		elif dealt == best_amount and dealt > 0:
			best_entries.append(entry)
	return fallback if best_entries.is_empty() else best_entries[randi() % best_entries.size()] as Dictionary

func choose_move_and_target(self_stats: CombatantStats, alive_party: Array, default_target: Dictionary, forced: bool) -> Dictionary:
	# Base contract must stay safe for subtypes; choreographed targets must match the lesson.
	if enemy_id() != "angler" or forced or alive_party.is_empty():
		return {"move": choose_move(default_target.stats as CombatantStats), "target": default_target}
	if float(self_stats.hp) < float(self_stats.hp_max) * LOW_HP_FRACTION:
		var headbutt := _find_move("headbutt")
		if not headbutt.is_empty() and randf() < STUN_PRIORITY_CHANCE:
			return {"move": headbutt, "target": _highest_damage_target(alive_party, default_target)}
	if _use_flash_blast_next:
		var flash := _find_move("flash_blast")
		if not flash.is_empty():
			_bite_hits = 0
			_bite_misses = 0
			_use_flash_blast_next = false
			return {"move": flash, "target": default_target}
	var bite := _find_move("bite")
	if bite.is_empty():
		return {"move": choose_move(default_target.stats as CombatantStats), "target": default_target}
	return {"move": bite, "target": alive_party[randi() % alive_party.size()] as Dictionary}

func face_toward(world_target: Vector3) -> void:
	var to := world_target - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	# +Z front: yaw 0 faces world +Z (opposite sign from Battle._step_toward()).
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

# Death fade: sinks, shrinks and fades, then frees itself. Materials are duplicated first
# because imported materials are shared between instances.
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
