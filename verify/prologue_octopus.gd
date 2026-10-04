# OPEN-012: Cordys must be a usable production actor, not merely a valid FBX.
# Usage: godot --headless --path . --script verify/prologue_octopus.gd
extends SceneTree

const ACTOR_PATH := "res://game/prologue_octopus.gd"

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script := load(ACTOR_PATH)
	if script == null:
		findings.append("OPEN-012: prologue Cordys actor does not exist")
		_finish()
		return
	var actor := script.new() as Node3D
	root.add_child(actor)
	await process_frame
	await process_frame

	_expect(actor.has_method("visual_bounds"), "OPEN-012: actor exposes no visible-bounds contract")
	_expect(actor.has_method("face_toward"), "OPEN-012: actor exposes no authored-front contract")
	_expect(actor.has_method("play"), "OPEN-012: actor exposes no semantic animation contract")
	if actor.has_method("visual_bounds"):
		actor.call("play", "idle")
		(actor.anim as AnimationPlayer).seek(0.0, true)
		var bounds := actor.call("current_pose_bounds") as AABB
		_expect(bounds.size.y >= 3.8 and bounds.size.y <= 4.2,
			"OPEN-012: Cordys is not normalized to the intended 4m presentation height: %s" % bounds)
		_expect(bounds.position.y >= -0.02 and bounds.position.y <= 0.02,
			"OPEN-012: Cordys is not floor aligned: %s" % bounds)

	var line_surfaces := 0
	var swordfish_material_is_subdued := actor.has_method("swordfish_tint_color") \
		and (actor.call("swordfish_tint_color") as Color).get_luminance() <= 0.32
	for mesh in _meshes(actor):
		for surface in range(mesh.mesh.get_surface_count()):
			if mesh.mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_LINES:
				line_surfaces += 1
	_expect(line_surfaces == 0, "OPEN-012: imported Cordys still exposes a line-primitive surface")
	_expect(swordfish_material_is_subdued,
		"OPEN-012: the bright Swordfish bill artifact has no actor-owned subdued material")

	for key in ["reveal", "idle", "hurt", "finish"]:
		var duration := float(actor.call("play", key)) if actor.has_method("play") else 0.0
		_expect(duration > 0.0, "OPEN-012: semantic %s clip is missing or static" % key)
		if duration > 0.0:
			(actor.anim as AnimationPlayer).seek(0.0, true)
			var before: Array[Vector3] = actor.current_pose_points()
			(actor.anim as AnimationPlayer).seek(duration * 0.45, true)
			var after: Array[Vector3] = actor.current_pose_points()
			if key != "reveal": # Angry Pose is an authored held reveal.
				var low := Vector3(INF, INF, INF)
				var high := Vector3(-INF, -INF, -INF)
				for index in range(mini(before.size(), after.size())):
					var displacement := after[index] - before[index]
					low = low.min(displacement)
					high = high.max(displacement)
				_expect((high - low).length() > 0.02,
					"OPEN-012: %s is a rigid/static mesh rather than a visibly deforming skin" % key)

	# A fast first reveal relies on the prepared hull belonging to the exact
	# admitted model/clip set, not a stale bound from a different FBX.
	var hull := load("res://art/deep_zone/octopus_prologue_frame.tres") as Resource
	_expect(hull.get_meta("source_sha256") == FileAccess.get_sha256("res://art/deep_zone/Octopus_Boss.fbx"),
		"OPEN-020: prepared frame belongs to a different Octopus delivery")
	var selected := hull.get_meta("clips") as Dictionary
	for key in ["idle", "reveal", "hurt", "finish"]:
		_expect(selected.get(key) == actor.clip_name(key),
			"OPEN-020: prepared frame omits the currently selected %s animation" % key)

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

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("PROLOGUE OCTOPUS: clean" if findings.is_empty() else "PROLOGUE OCTOPUS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
