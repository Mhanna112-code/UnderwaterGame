# Run against an isolated Godot import project containing these six FBXs.
# Supply -- --output-dir=/absolute/repository/art/characters/spell_animations.
# Outputs compact animation-only libraries; never replaces working meshes.
extends SceneTree

const DELIVERIES := [
	{
		"source": "Max", "target": "Scuba_Rigged", "output": "maxilani.res",
		"sha": "cee7fc9b79ad35531e9a78b0d2372b2dba9c53d0e09fe2e83f6839a974a5a977",
		"clips": ["Scuba_(Attack) Swift Slash", "Scuba_(Attack) Riptide Slash"],
	},
	{
		"source": "Musashi", "target": "Prototype1_Rigged", "output": "musashi.res",
		"sha": "f78fb38418032c421b4a826f874f9573e8d05c1d4f010f21bed695f21de887b7",
		"clips": ["Proto1_(Attack)Blinding)Silt", "Proto1_(Attack)Blinding)Exploit_Opening", "Proto1_(Attack)Precise_Jab"],
	},
	{
		"source": "Buxky", "target": "PrototypeV_Rigged", "output": "bucky.res",
		"sha": "deadfbc96217f1fd5ae03cde371f9a39145d28cbb5fbda7ae84fb53623ce1afb",
		"clips": ["Proto5_Guard_Break", "Proto5_Heavy_Slam", "Proto5_Mending Current", "Proto5_Tidal_Revival"],
	},
]
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="):
			output_dir = arg.trim_prefix("--output-dir=")
	if not output_dir.is_absolute_path():
		push_error("Supply an absolute --output-dir")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	for delivery in DELIVERIES:
		var source_file := "res://%s.fbx" % delivery.source
		var target_file := "res://%s.fbx" % delivery.target
		if FileAccess.get_sha256(source_file) != delivery.sha:
			findings.append("Unexpected delivery hash: " + source_file)
			continue
		var source := (load(source_file) as PackedScene).instantiate()
		var target := (load(target_file) as PackedScene).instantiate()
		root.add_child(source)
		root.add_child(target)
		var source_ap := _find(source, "AnimationPlayer") as AnimationPlayer
		var target_ap := _find(target, "AnimationPlayer") as AnimationPlayer
		var source_skeleton := _find(source, "Skeleton3D") as Skeleton3D
		var target_skeleton := _find(target, "Skeleton3D") as Skeleton3D
		var library := AnimationLibrary.new()
		var omissions := {}
		for stem in delivery.clips:
			var full_name := ""
			for name in source_ap.get_animation_list():
				if String(name).ends_with("|" + stem):
					full_name = name
			if full_name.is_empty():
				findings.append("Missing delivered clip: " + stem)
				continue
			var animation := source_ap.get_animation(full_name).duplicate(true) as Animation
			var omitted: Array[String] = []
			# The new Max rig adds Staff and c_hand_ik.r controls that the old
			# skin does not bind. Preserve its working hand-skinned lantern;
			# discard only tracks addressing absent controls/blend shapes.
			for index in range(animation.get_track_count() - 1, -1, -1):
				var path := animation.track_get_path(index)
				var node := target_ap.get_node(target_ap.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))
				if node == null:
					findings.append("Unresolved animation node: " + String(path))
					continue
				if node is Skeleton3D and path.get_subname_count() == 1:
					var bone := String(path.get_subname(0))
					var target_index := target_skeleton.find_bone(bone)
					if target_index < 0:
						if delivery.source == "Max" and bone in ["Staff", "c_hand_ik.r"]:
							omitted.append(String(path))
							animation.remove_track(index)
						else:
							findings.append("Unmapped skeleton bone: " + bone)
					elif bone != "c_pos" and not target_skeleton.get_bone_rest(target_index).is_equal_approx(source_skeleton.get_bone_rest(source_skeleton.find_bone(bone))):
						findings.append("Unexpected rest-pose mismatch: " + bone)
				elif animation.track_get_type(index) == Animation.TYPE_BLEND_SHAPE:
					var mesh := node as MeshInstance3D
					if mesh == null or mesh.find_blend_shape_by_name(path.get_subname(0)) < 0:
						omitted.append(String(path))
						animation.remove_track(index)
			# c_pos is explicitly keyed in both position and rotation. It is
			# an absolute local pose: don't "correct" the export's different
			# rest rotation and introduce a second unintended body rotation.
			for type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
				var keyed := false
				for index in range(animation.get_track_count()):
					if animation.track_get_type(index) == type and String(animation.track_get_path(index)).ends_with("Skeleton3D:c_pos"):
						keyed = animation.track_get_key_count(index) > 0
				if not keyed:
					findings.append("Different c_pos rest requires explicit pose keys: " + stem)
			animation.loop_mode = Animation.LOOP_NONE
			library.add_animation(stem, animation)
			omissions[stem] = omitted
			print("DERIVED SPELL|%s|%.3fs|tracks=%d|omitted=%s" % [stem, animation.length, animation.get_track_count(), omitted])
		library.set_meta("source_file", String(delivery.source) + ".fbx")
		library.set_meta("source_sha256", delivery.sha)
		library.set_meta("target_sha256", FileAccess.get_sha256(target_file))
		library.set_meta("omitted_tracks", omissions)
		if findings.is_empty():
			var result := ResourceSaver.save(library, output_dir.path_join(delivery.output), ResourceSaver.FLAG_COMPRESS)
			if result != OK:
				findings.append("Failed to save " + delivery.output)
		source.queue_free()
		target.queue_free()
		await process_frame
	for finding in findings:
		push_error(finding)
	quit(0 if findings.is_empty() else 1)

func _find(node: Node, kind: String) -> Node:
	if node.is_class(kind):
		return node
	for child in node.get_children():
		var found := _find(child, kind)
		if found != null:
			return found
	return null
