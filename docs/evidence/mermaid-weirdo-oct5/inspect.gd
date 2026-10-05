extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for name in ["Mermaid_Freak.fbx", "Freak_Mermaid-Weirdo.fbx"]:
		var scene := load("res://" + name) as PackedScene
		if scene == null:
			print("ASSET_IMPORT_FAILED|", name)
			quit(1)
			return
		var actor := scene.instantiate() as Node3D
		root.add_child(actor)
		await process_frame
		var meshes := actor.find_children("*", "MeshInstance3D", true, false)
		var material_rows: Array = []
		var aabb := AABB()
		var first := true
		for node in meshes:
			var mesh := node as MeshInstance3D
			var bounds := mesh.global_transform * mesh.get_aabb()
			aabb = bounds if first else aabb.merge(bounds)
			first = false
			for index in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(index)
				var row := {"mesh": String(mesh.name), "surface": index, "class": material.get_class() if material != null else "null"}
				if material is BaseMaterial3D:
					var base := material as BaseMaterial3D
					row.color = str(base.albedo_color)
					row.albedo_texture = base.albedo_texture.resource_path if base.albedo_texture != null else ""
				material_rows.append(row)
		var rigs: Array = []
		for node in actor.find_children("*", "Skeleton3D", true, false):
			var rig := node as Skeleton3D
			var names: Array[String] = []
			for index in rig.get_bone_count():
				names.append(rig.get_bone_name(index))
			rigs.append({"name": rig.name, "bones": rig.get_bone_count(), "bone_names": names})
		var clips: Array = []
		for node in actor.find_children("*", "AnimationPlayer", true, false):
			var player := node as AnimationPlayer
			for clip in player.get_animation_list():
				var animation := player.get_animation(clip)
				clips.append({"name": clip, "seconds": animation.length, "tracks": animation.get_track_count()})
		print("ASSET_REPORT|", JSON.stringify({"source": name, "root_transform": str(actor.transform), "bounds": str(aabb), "mesh_count": meshes.size(), "materials": material_rows, "rigs": rigs, "clips": clips}))
		actor.queue_free()
		await process_frame
	quit(0)
