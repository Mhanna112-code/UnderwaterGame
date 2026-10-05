# Offline mesh/animation derivative: runtime camera fitting must not rescan
# thousands of skinned vertices when the player first selects a spell.
extends SceneTree
const OUTPUT := "res://art/characters/spell_animations/frames.res"
const SAMPLES := 41

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var frames := {}
	var sources := {}
	for model_name in Cast.ALL:
		var actor := Diver.new()
		actor.model_name = model_name
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		var library := Cast.spell_animations(model_name)
		var by_clip := {}
		for clip_name in library.get_animation_list():
			var points := PackedVector3Array()
			var duration := actor.play_clip(clip_name)
			for sample in range(SAMPLES):
				actor.anim.seek(duration * sample / float(SAMPLES - 1), true)
				var pose := _skin_points(actor)
				for x in [-1.0, 0.0, 1.0]:
					for y in [-1.0, 0.0, 1.0]:
						for z in [-1.0, 0.0, 1.0]:
							var direction := Vector3(x, y, z)
							if direction.is_zero_approx():
								continue
							var extreme := pose[0]
							var largest := -INF
							for point in pose:
								var projected := point.dot(direction)
								if projected > largest:
									largest = projected
									extreme = point
							points.append(actor.to_local(extreme))
			by_clip["spells/" + clip_name] = points
			print("SPELL FRAME|", model_name, "|", clip_name, "|", points.size())
		frames[model_name] = by_clip
		sources[model_name] = {
			"rig": FileAccess.get_sha256(Cast.file(model_name)),
			"library": FileAccess.get_sha256(Cast.ALL[model_name].spell_animations),
		}
		actor.queue_free()
		await process_frame
	var resource := Resource.new()
	resource.set_meta("frames", frames)
	resource.set_meta("sources", sources)
	resource.set_meta("samples", SAMPLES)
	var error := ResourceSaver.save(resource, OUTPUT)
	print("SPELL FRAMES: ", error)
	quit(0 if error == OK else 1)

func _skin_points(node: Node) -> PackedVector3Array:
	var result := PackedVector3Array()
	if node is MeshInstance3D and node.is_visible_in_tree() and node.skin != null:
		var mesh := node as MeshInstance3D
		var skeleton := mesh.get_node(mesh.skeleton) as Skeleton3D
		skeleton.force_update_all_bone_transforms()
		var bindings: Array[Transform3D] = []
		for index in range(mesh.skin.get_bind_count()):
			var bone := mesh.skin.get_bind_bone(index)
			if bone < 0:
				bone = skeleton.find_bone(mesh.skin.get_bind_name(index))
			bindings.append(skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences := bones.size() / vertices.size()
			for index in range(vertices.size()):
				var point := Vector3.ZERO
				for influence in range(influences):
					var offset := index * influences + influence
					point += (bindings[bones[offset]] * vertices[index]) * weights[offset]
				result.append(skeleton.global_transform * point)
	for child in node.get_children():
		result.append_array(_skin_points(child))
	return result
