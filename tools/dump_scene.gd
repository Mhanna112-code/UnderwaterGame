# What is in an imported model: meshes, skeletons, materials, animation clips.
# Takes the path as an argument so one script serves every delivery.
# Usage: godot --headless --path . --script tools/dump_scene.gd -- res://Thing.fbx
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := String(args[0]) if args.size() > 0 else "res://art/characters/divers.glb"
	if not ResourceLoader.exists(path):
		print("NOT IMPORTED: %s" % path)
		quit(1)
		return
	var root_node: Node = (load(path) as PackedScene).instantiate()
	var meshes: Array = []
	var skels: Array = []
	var players: Array = []
	_walk(root_node, meshes, skels, players)
	print("%s" % path)
	print("  %d mesh node(s), %d skeleton(s)" % [meshes.size(), skels.size()])
	for m in meshes:
		var mesh: Mesh = (m as MeshInstance3D).mesh
		var v := 0
		if mesh != null:
			for s in range(mesh.get_surface_count()):
				var a: Array = mesh.surface_get_arrays(s)
				if a.size() > Mesh.ARRAY_VERTEX and a[Mesh.ARRAY_VERTEX] != null:
					v += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		print("  mesh     %-26s %d verts%s" % [m.name, v, ", skinned" if (m as MeshInstance3D).skin != null else ""])
	for s in skels:
		print("  skeleton %-26s %d bones" % [s.name, (s as Skeleton3D).get_bone_count()])
	for p in players:
		var list := (p as AnimationPlayer).get_animation_list()
		print("  clips    %d on %s" % [list.size(), p.name])
		for a in list:
			var anim: Animation = (p as AnimationPlayer).get_animation(a)
			print("    %-34s %5.2fs  %d tracks" % [a, anim.length, anim.get_track_count()])
	quit(0)

func _walk(n: Node, meshes: Array, skels: Array, players: Array) -> void:
	if n is MeshInstance3D: meshes.append(n)
	elif n is Skeleton3D: skels.append(n)
	elif n is AnimationPlayer: players.append(n)
	for c in n.get_children():
		_walk(c, meshes, skels, players)
