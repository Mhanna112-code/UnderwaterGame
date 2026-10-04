# Prologue-only presentation adapter for Glassgoat's composite Cordys FBX.
#
# This actor deliberately owns presentation facts only. Campaign progression,
# final boss balance and rewards remain separate from the opening prologue.
class_name PrologueOctopus
extends Node3D

const SOURCE := preload("res://art/deep_zone/Octopus_Boss.fbx")
const FRAMING := preload("res://art/deep_zone/octopus_prologue_frame.tres")
const TARGET_HEIGHT := 4.0
const DISPLAY_NAME := "Cordys"
const SWORDFISH_TINT := Color(0.12, 0.18, 0.22, 1.0)

const CLIP_FRAGMENTS := {
	"reveal": "angry_pose",
	"idle": "idle)(normal",
	"hurt": "damaged)1",
	"finish": "poison_breath",
	"head_bash": "head_bash",
	"poison_breath": "poison_breath",
}

var anim: AnimationPlayer
var height := TARGET_HEIGHT
var radius := 1.0
var _model: Node3D
var _clips: Dictionary = {}
var _presentation_bounds := AABB()
var _presentation_points: Array[Vector3] = []

func _ready() -> void:
	_model = SOURCE.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	anim = _find_animation_player(_model)
	_index_clips()
	play("idle")
	anim.advance(0.0)

	var bounds := _posed_bounds(_model)
	var source_height := maxf(0.01, bounds.size.y)
	_model.scale *= TARGET_HEIGHT / source_height
	bounds = _posed_bounds(_model)
	_model.position.x -= bounds.get_center().x - global_position.x
	_model.position.z -= bounds.get_center().z - global_position.z
	_model.position.y -= bounds.position.y
	bounds = _posed_bounds(_model)
	height = bounds.size.y
	radius = maxf(0.8, maxf(bounds.size.x, bounds.size.z) * 0.5)

	# Imported get_aabb() is the unskinned bind pose, not what the player sees.
	# Normalize from idle, then frame the actual surface envelope of every
	# used clip. Battle uses a fixed authored view, never per-frame zooming.
	_presentation_bounds = bounds
	# Derived offline from this exact skin and the used clips. Scanning every
	# action during _ready() caused a measured three-second first-reveal hitch.
	# The projection gate still samples the live skin independently.
	for point in FRAMING.get_meta("points") as PackedVector3Array:
		_presentation_points.append(point)
	_set_loop("idle")
	_subdue_swordfish_bill()
	play("idle")
	anim.seek(0.0, true)

func display_name() -> String:
	return DISPLAY_NAME

func head_offset() -> float:
	return height

func foot_offset() -> float:
	return 0.0

func visual_bounds() -> AABB:
	return global_transform * _presentation_bounds

func current_pose_bounds() -> AABB:
	return _posed_bounds(_model)

func current_pose_points() -> Array[Vector3]:
	return _posed_points(_model)

func framing_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point in _presentation_points:
		points.append(global_transform * point)
	return points

# The visible composite was authored with its face/front along local +Z.
func face_toward(world_target: Vector3) -> void:
	var target := Vector3(world_target.x, global_position.y, world_target.z)
	if global_position.distance_squared_to(target) > 0.0025:
		look_at(target, Vector3.UP, true)

func play(key: String) -> float:
	if anim == null:
		return 0.0
	var clip := String(_clips.get(key, ""))
	if clip.is_empty():
		return 0.0
	anim.play(clip)
	var animation := anim.get_animation(clip)
	return animation.length if animation != null else 0.0

func has_clip(key: String) -> bool:
	return not String(_clips.get(key, "")).is_empty()

func clip_name(key: String) -> String:
	return String(_clips.get(key, ""))

func swordfish_tint_color() -> Color:
	return SWORDFISH_TINT

func _index_clips() -> void:
	_clips.clear()
	if anim == null:
		return
	for clip_value in anim.get_animation_list():
		var clip := String(clip_value)
		var normalized := _normalized(clip)
		for key_value in CLIP_FRAGMENTS:
			var key := String(key_value)
			if normalized.contains(_normalized(String(CLIP_FRAGMENTS[key]))):
				_clips[key] = clip

func _set_loop(key: String) -> void:
	if anim == null:
		return
	var clip := String(_clips.get(key, ""))
	var animation := anim.get_animation(clip) if not clip.is_empty() else null
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR

# The Swordfish corpse's very pale bill reads as detached white rods in the
# delivered attack poses. Preserve the mesh and its embedded texture, but
# apply a dark underwater tint so the silhouette remains part of the composite
# instead of becoming a screen-spanning artifact.
func _subdue_swordfish_bill() -> void:
	# The dummy rendering server cannot own material overrides and emits a false
	# material-RID error. Structural headless tests assert the public tint
	# contract; real-window and browser captures verify the applied result.
	if DisplayServer.get_name() == "headless":
		return
	for mesh in _meshes(_model):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface)
			if material == null or material.resource_name != "Sword_Fish_Corpse":
				continue
			if material is BaseMaterial3D:
				var tint := material.duplicate() as BaseMaterial3D
				tint.albedo_color = SWORDFISH_TINT
				tint.roughness = 0.82
				mesh.set_surface_override_material(surface, tint)

func _normalized(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("|", "")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _world_bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for mesh in _meshes(node):
		var box := mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out

func _posed_bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for point in _posed_points(node):
		out = AABB(point, Vector3.ZERO) if first else out.expand(point)
		first = false
	return out

func _posed_points(node: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for mesh in _meshes(node):
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if skeleton == null or mesh.skin == null:
			var box := mesh.global_transform * mesh.get_aabb()
			for index in range(8):
				out.append(box.get_endpoint(index))
			continue
		skeleton.force_update_all_bone_transforms()
		var binds: Array[Transform3D] = []
		for index in range(mesh.skin.get_bind_count()):
			var bone := mesh.skin.get_bind_bone(index)
			if bone < 0:
				bone = skeleton.find_bone(mesh.skin.get_bind_name(index))
			binds.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index) if bone >= 0 else Transform3D.IDENTITY)
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences := bones.size() / maxi(1, vertices.size())
			for index in range(vertices.size()):
				var point := Vector3.ZERO
				for influence in range(influences):
					var offset := index * influences + influence
					if weights[offset] > 0.0:
						point += (binds[bones[offset]] * vertices[index]) * weights[offset]
				point = skeleton.global_transform * point
				out.append(point)
	return out
