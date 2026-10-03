# Canonical Corrected Door intake contract.
#
# Usage: godot --headless --path . --script verify/lab_door_asset.gd
extends SceneTree

const PATH := "res://art/deep_zone/Corrected_Door.fbx"
const EXPECTED_SHA := "e3fa86956ecb42373eb07d3ec592034391d2e260bb8d01897dcfdba0796d6260"

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(PATH):
		findings.append("LAB-EXT-002: canonical Corrected Door is missing")
		_finish()
		return
	_expect(FileAccess.get_sha256(PATH) == EXPECTED_SHA,
		"LAB-EXT-002: runtime door is not Glassgoat's Corrected Door delivery")
	_expect(not FileAccess.file_exists("res://art/deep_zone/Door.fbx"),
		"LAB-EXT-002: obsolete Door.fbx was committed beside the corrected model")
	var packed := load(PATH) as PackedScene
	_expect(packed != null, "LAB-EXT-002: Corrected Door did not import as a PackedScene")
	if packed == null:
		_finish()
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	var meshes := _meshes(instance)
	var materials := 0
	var bounds := AABB()
	var first := true
	for mesh in meshes:
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in range(mesh.mesh.get_surface_count()):
			if mesh.get_active_material(surface) != null:
				materials += 1
	_expect(meshes.size() == 2 and bounds.size.length() > 0.01,
		"LAB-EXT-002: Corrected Door lost one of its two visible meshes")
	_expect(materials >= 2,
		"LAB-EXT-002: Corrected Door material/embedded texture did not survive import")
	instance.queue_free()
	await process_frame
	_finish()

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("LAB DOOR ASSET: clean" if findings.is_empty() else "LAB DOOR ASSET: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
