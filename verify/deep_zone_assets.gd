# Raw intake proof for the selected deep-zone assets.
#
# Usage: godot --headless --path . --script verify/deep_zone_assets.gd
extends SceneTree

const ASSETS := [
	{
		"id": "bomb_bot",
		"path": "res://art/deep_zone/Bomb_Bot.fbx",
		# The delivered FBX misspells Lightning as "Lighting". The future
		# actor maps the logical Lightning Blast move to this source fragment.
		"clips": ["lightingblast", "slingpunch", "sonic_bump"],
		"materials": false,
	},
	{
		"id": "sword_slayer",
		"path": "res://art/deep_zone/Sword_Slayer.fbx",
		"clips": ["greatslash", "stabbing", "spinning_drill"],
		"materials": false,
	},
	{
		"id": "broken_office",
		"path": "res://art/deep_zone/Broken_Office.fbx",
		"clips": [],
		"materials": true,
	},
]

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for definition_value in ASSETS:
		var definition := definition_value as Dictionary
		await _verify_asset(definition)
	for finding in findings:
		print("FINDING  " + finding)
	print("DEEP ZONE ASSETS: clean" if findings.is_empty() else "DEEP ZONE ASSETS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _verify_asset(definition: Dictionary) -> void:
	var asset_id := String(definition.id)
	var path := String(definition.path)
	if not ResourceLoader.exists(path):
		findings.append("%s: missing canonical runtime file %s" % [asset_id, path])
		return
	var packed := load(path) as PackedScene
	if packed == null:
		findings.append("%s: Godot did not import the FBX as a PackedScene" % asset_id)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame

	var meshes := _meshes(instance)
	var bounds := _combined_bounds(meshes)
	if meshes.is_empty() or bounds.size.length() <= 0.01:
		findings.append("%s: imported scene has no visible mesh bounds" % asset_id)

	var material_count := 0
	for mesh_value in meshes:
		var mesh := mesh_value as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			if mesh.get_active_material(surface) != null:
				material_count += 1
	if bool(definition.materials) and material_count == 0:
		findings.append("%s: imported geometry has no active surface material" % asset_id)

	var normalized_clips: Array[String] = []
	for animation_player in _animation_players(instance):
		for clip_value in (animation_player as AnimationPlayer).get_animation_list():
			normalized_clips.append(_normalized(String(clip_value)))
	for required_value in definition.clips as Array:
		var required := String(required_value)
		if not normalized_clips.any(func(clip: String) -> bool: return clip.contains(required)):
			findings.append("%s: missing authored clip fragment %s (observed %s)" % [asset_id, required, normalized_clips])

	print("%-14s meshes=%d materials=%d bounds=%s clips=%d" % [asset_id, meshes.size(), material_count, bounds.size, normalized_clips.size()])
	instance.queue_free()
	await process_frame

func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _animation_players(node: Node) -> Array:
	var out: Array = []
	if node is AnimationPlayer:
		out.append(node)
	for child in node.get_children():
		out.append_array(_animation_players(child))
	return out

func _combined_bounds(meshes: Array) -> AABB:
	var combined := AABB()
	var first := true
	for mesh_value in meshes:
		var mesh := mesh_value as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		combined = box if first else combined.merge(box)
		first = false
	return combined

func _normalized(value: String) -> String:
	return value.to_lower().replace(" ", "").replace("-", "").replace("|", "").replace("(", "").replace(")", "")
