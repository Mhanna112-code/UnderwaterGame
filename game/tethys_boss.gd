# Glassgoat's Mermaid Freak is Tethys, the final boss. It is deliberately a
# separate combatant from Goblin: the meeting clarified that normal grunts
# will eventually be replaced by fish, while this four-armed creature is the
# massive authored boss. Godot does not expose usable surface materials from
# this FBX import, so _apply_validation_materials() preserves the saturated-red
# intent Glassgoat confirmed for the playable review build. That engine-side
# fallback is not a request for Glassgoat to reauthor the ready asset.
class_name TethysBoss
extends Node3D

const SRC := preload("res://characters/Mermaid_Freak.fbx")

const DISPLAY_NAME := "Tethys"
const BASE_XP := 75

# The encounter cycles through all six authored attack clips before
# repeating. The first three mechanics come directly from Glassgoat's
# meeting explanation: Double Scratch pressures evasion through two hits,
# Tail Sweep attacks the whole party through armour, and Poison Breath
# poisons the whole party. The other clips are playable provisional roles so
# none of the delivered animation work is hidden from the review build.
const MOVES := [
	{
		"id": "double_scratch", "name": "Double Scratch",
		"clip": "double_cratch", "target": "single", "hits": 2,
		"power": 4, "acc_mod": 1,
		"intent": "Two attacks drain and then pressure the target's evasion pool",
	},
	{
		"id": "tail_sweep", "name": "Tail Sweep",
		"clip": "tail_sweep", "target": "all", "hits": 1,
		"power": 7, "acc_mod": 2, "ignore_defense": true,
		"intent": "Party-wide armour counter",
	},
	{
		"id": "poison_breath", "name": "Poison Breath",
		"clip": "poison_breath", "target": "all", "hits": 1,
		"power": 3, "acc_mod": 4, "poison": 2, "poison_turns": 3,
		"intent": "Party-wide pressure that continues for three turns",
	},
	{
		"id": "tail_slam", "name": "Tail Slam",
		"clip": "tail_slam", "target": "single", "hits": 1,
		"power": 10, "acc_mod": 0, "quick_time_bool": true,
		"intent": "Provisional telegraphed single-target heavy",
	},
	{
		"id": "tongue_slayer", "name": "Tongue Slayer",
		"clip": "tongue_slayer", "target": "single", "hits": 1,
		"power": 7, "acc_mod": 6,
		"intent": "Provisional high-accuracy single-target strike",
	},
	{
		"id": "spinning_death", "name": "Spinning Death",
		"clip": "spinning_death", "target": "all", "hits": 1,
		"power": 9, "acc_mod": 1,
		"intent": "Provisional late-cycle party-wide finisher",
	},
]

const CLIP_FRAGMENTS := {
	"base_pose": "base_pose",
	"idle": "idle)(loop",
	"swim_start": "swimming)(start",
	"swim_loop": "swimming)(loop",
	"swim_end": "swimming)(end",
	"poison_breath": "poison_breath",
	"spinning_death": "spinning_death",
	# The source file itself misspells Scratch as "cratch".
	"double_cratch": "double_cratch",
	"tail_slam": "tail_slam",
	"tail_sweep": "tail_sweep",
	"strong_hit": "strong_hit",
	"weak_hit": "weak_hit",
	"death": "tethys(death",
	"tongue_slayer": "tongue_slayer",
}

var anim: AnimationPlayer
var height := 4.0
var radius := 1.0
var xp_reward := BASE_XP
var _clips: Dictionary = {}
var _move_index := 0

func _ready() -> void:
	var model: Node3D = SRC.instantiate()
	model.name = "Model"
	add_child(model)

	var box := _world_aabb(model)
	height = maxf(0.1, box.size.y)
	radius = maxf(0.6, maxf(box.size.x, box.size.z) * 0.5)
	# Preserve the artist's scale. Only move the imported root enough to put
	# the model's measured feet on the stage floor.
	model.position.y -= box.position.y
	_apply_validation_materials(model)

	anim = _find_anim(model)
	_index_clips()
	_set_loop("idle")
	_set_loop("swim_loop")
	play("idle")

func head_offset() -> float:
	return height

func foot_offset() -> float:
	return 0.0

# Mermaid_Freak was authored with its visible front along local +Z. Godot's
# default Node3D look_at convention points -Z, so use_model_front must remain
# true whenever combat turns this actor toward somebody.
func face_toward(world_target: Vector3) -> void:
	var level_target := Vector3(world_target.x, global_position.y, world_target.z)
	if global_position.distance_squared_to(level_target) > 0.0025:
		look_at(level_target, Vector3.UP, true)

func make_stats(ref: CombatantStats, player_level: int = 1) -> CombatantStats:
	xp_reward = BASE_XP + maxi(0, player_level - 1) * 12
	var s := CombatantStats.new()
	# One boss is fighting a party of three. These values make the validation
	# encounter long enough to expose its full six-move animation cycle while
	# remaining beatable with the existing level-one kits. They are explicitly
	# playtest tuning, not a claim that Glassgoat supplied final numbers.
	s.hp_max = maxi(180, int(round(float(ref.hp_max) * 6.0)))
	s.strength = maxi(6, int(round(float(ref.strength) * 1.15)))
	s.defense = maxi(3, int(round(float(ref.defense) * 1.1)))
	s.agility = maxi(4, ref.agility)
	s.evasion = maxi(2, int(round(float(ref.evasion) * 0.75)))
	s.accuracy = maxi(6, int(round(float(ref.accuracy) * 1.1)))
	s.barrier_max = 0
	s.fill()
	return s

func next_move() -> Dictionary:
	var move := (MOVES[_move_index % MOVES.size()] as Dictionary).duplicate(true)
	_move_index += 1
	return move

func play(key: String) -> float:
	if anim == null:
		return 0.0
	var clip := String(_clips.get(key, ""))
	if clip == "":
		return 0.0
	anim.play(clip)
	var animation := anim.get_animation(clip)
	return animation.length if animation != null else 0.0

func play_attack(move: Dictionary) -> float:
	return play(String(move.get("clip", "idle")))

func play_hit_reaction(heavy: bool) -> void:
	play("strong_hit" if heavy else "weak_hit")

func play_death() -> void:
	var length := play("death")
	get_tree().create_timer(maxf(0.7, length)).timeout.connect(_fade_after_death)

func _fade_after_death() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	for mesh_value in _meshes(self):
		var mesh := mesh_value as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface)
			if material == null or not (material is BaseMaterial3D):
				continue
			var copy := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
			copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.set_surface_override_material(surface, copy)
			tween.tween_property(copy, "albedo_color:a", 0.0, 0.8)
	tween.tween_property(self, "position:y", position.y - 0.8, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

# The delivered transition clips are exercised in their intended order
# before the first turn: Start -> Loop -> End -> Idle, instead of jumping
# directly from idle into the loop and back.
func play_swim_intro() -> void:
	for key in ["swim_start", "swim_loop", "swim_end"]:
		var length := play(key)
		if length > 0.0:
			await get_tree().create_timer(length).timeout
	play("idle")

func has_clip(key: String) -> bool:
	return String(_clips.get(key, "")) != ""

func clip_name(key: String) -> String:
	return String(_clips.get(key, ""))

func _index_clips() -> void:
	_clips.clear()
	if anim == null:
		return
	for clip_value in anim.get_animation_list():
		var clip := String(clip_value)
		var lower := clip.to_lower().replace(" ", "")
		for key_value in CLIP_FRAGMENTS.keys():
			var key := String(key_value)
			if lower.contains(String(CLIP_FRAGMENTS[key]).replace(" ", "")):
				_clips[key] = clip

func _set_loop(key: String) -> void:
	if anim == null:
		return
	var clip := String(_clips.get(key, ""))
	if clip == "":
		return
	var animation := anim.get_animation(clip)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR

func _apply_validation_materials(root: Node) -> void:
	var surface_index := 0
	for mesh_value in _meshes(root):
		var mesh := mesh_value as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var material := StandardMaterial3D.new()
			# Two related reds retain separation between the body and face surfaces
			# while preserving the saturated-red intent confirmed by Glassgoat. The
			# eventual dark boss arena supplies the intended presentation context.
			material.albedo_color = Color("9f2435") if surface_index % 2 == 0 else Color("c24a50")
			material.roughness = 0.72
			material.metallic = 0.05
			mesh.set_surface_override_material(surface, material)
			surface_index += 1

func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim(child)
		if found != null:
			return found
	return null

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _world_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for mesh_value in _meshes(node):
		var mesh := mesh_value as MeshInstance3D
		var local := mesh.get_aabb()
		var transform := mesh.global_transform
		for i in range(8):
			var point := transform * local.get_endpoint(i)
			if first:
				out = AABB(point, Vector3.ZERO)
				first = false
			else:
				out = out.expand(point)
	return out
