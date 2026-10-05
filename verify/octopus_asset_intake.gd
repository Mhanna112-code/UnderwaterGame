# Canonical visible Octopus FBX intake contract.
#
# Usage: godot --headless --path . --script verify/octopus_asset_intake.gd
extends SceneTree

const PATH := "res://art/deep_zone/Octopus_Boss.fbx"
const EXPECTED_SHA := "e51ac165292525291714505341661067dc56022b20dc52d7aa29ccdf2d491792"
const REQUIRED_CLIPS := [
	# Glassgoat's delivered clips spell Electric as "Eletric"; the future
	# actor must map logical move names deliberately rather than hiding it.
	"angrypose", "eletricshine", "eletricshooting", "headbash",
	"octostab", "poisonbreath", "slamming", "sonictrust",
	"spinningslay", "damaged1", "idlenormal", "idleweak",
	"swimmingend", "swimmingloop", "swimmingstart",
]

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(PATH):
		findings.append("OCTO-INTAKE-001: canonical visible Octopus FBX is missing")
		_finish()
		return
	_expect(FileAccess.get_sha256(PATH) == EXPECTED_SHA,
		"OCTO-INTAKE-001: canonical FBX digest is not Glassgoat's visible V2 delivery")
	_expect(not FileAccess.file_exists("res://art/deep_zone/Octopus_Boss_V2.fbx")
		and not FileAccess.file_exists("res://art/deep_zone/Octopus_Boss_updatedvs.fbx"),
		"OCTO-INTAKE-001: duplicate Octopus runtime filenames were committed")

	var packed := load(PATH) as PackedScene
	_expect(packed != null, "OCTO-INTAKE-001: Godot did not import the FBX as a PackedScene")
	if packed == null:
		_finish()
		return
	var actor := packed.instantiate()
	root.add_child(actor)
	await process_frame
	await process_frame
	var meshes := _meshes(actor)
	var bounds := _combined_bounds(meshes)
	_expect(not meshes.is_empty() and bounds.size.length() > 0.01,
		"OCTO-INTAKE-001: imported Octopus has no visible mesh bounds")
	_expect(_material_count(meshes) >= 6,
		"OCTO-INTAKE-001: embedded Octopus/corpse materials did not survive Godot import")
	var player := _animation_player(actor)
	_expect(player != null, "OCTO-INTAKE-001: imported Octopus has no AnimationPlayer")
	if player != null:
		var clips: Array[String] = []
		for clip in player.get_animation_list():
			clips.append(_normalized(String(clip)))
		_expect(clips.size() == 15,
			"OCTO-INTAKE-001: expected 15 authored clips, observed %d" % clips.size())
		for required in REQUIRED_CLIPS:
			_expect(clips.any(func(value: String) -> bool: return value.contains(required)),
				"OCTO-INTAKE-001: missing authored clip fragment %s" % required)
		var skeleton := _skeleton(actor)
		_expect(skeleton != null and skeleton.get_bone_count() > 0,
			"OCTO-INTAKE-002: imported Octopus has no usable skeleton")
		if skeleton != null and skeleton.get_bone_count() > 0:
			var before := skeleton.get_bone_global_pose(mini(5, skeleton.get_bone_count() - 1))
			var attack := _clip_for(player, "headbash")
			_expect(not attack.is_empty(), "OCTO-INTAKE-002: Head Bash does not resolve")
			if not attack.is_empty():
				player.play(attack)
				player.advance(0.55)
				var after := skeleton.get_bone_global_pose(mini(5, skeleton.get_bone_count() - 1))
				_expect(not before.is_equal_approx(after),
					"OCTO-INTAKE-002: Head Bash exists by name but does not move the rig")
	actor.queue_free()
	await process_frame
	_finish()

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _combined_bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var combined := AABB()
	var first := true
	for mesh in meshes:
		var box := mesh.global_transform * mesh.get_aabb()
		combined = box if first else combined.merge(box)
		first = false
	return combined

func _material_count(meshes: Array[MeshInstance3D]) -> int:
	var total := 0
	for mesh in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			if mesh.get_active_material(surface) != null:
				total += 1
	return total

func _animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _animation_player(child)
		if found != null:
			return found
	return null

func _skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _skeleton(child)
		if found != null:
			return found
	return null

func _clip_for(player: AnimationPlayer, fragment: String) -> StringName:
	for clip in player.get_animation_list():
		if _normalized(String(clip)).contains(fragment):
			return clip
	return &""

func _normalized(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("_", "").replace("-", "").replace("(", "").replace(")", "").replace("|", "")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OCTOPUS ASSET INTAKE: clean" if findings.is_empty() else "OCTOPUS ASSET INTAKE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
