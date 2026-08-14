# What is actually inside the rig Glass_Goat handed us?
#
# Loads the imported FBX scene and prints the tree: meshes with their
# surface/vertex counts, skeletons with their bone counts, materials, and
# every animation the file carries. Run headless so the answer is a
# measurement, not a look at the editor's import dock.
#
# Usage: godot --headless --path ~/underwatergame --script tools/dump_fbx.gd
extends SceneTree

const PATH := "res://art/characters/divers.glb"

var meshes := 0
var skeletons := 0
var bones := 0
var mats: Dictionary = {}

func _init() -> void:
	if not ResourceLoader.exists(PATH):
		print("NOT IMPORTED: %s has no imported resource" % PATH)
		quit(1)
		return
	var packed: PackedScene = load(PATH)
	if packed == null:
		print("LOAD FAILED: %s" % PATH)
		quit(1)
		return
	var root: Node = packed.instantiate()
	print("root       %s (%s)" % [root.name, root.get_class()])
	_walk(root, 0)
	print("")
	print("totals     %d mesh node(s), %d skeleton(s), %d bone(s), %d material(s)" % [
		meshes, skeletons, bones, mats.size()])
	for m in mats.keys():
		print("  material %s" % m)
	var players: Array = []
	_find_players(root, players)
	for p in players:
		var lib_names := (p as AnimationPlayer).get_animation_list()
		print("animation  %s carries %d clip(s)" % [p.name, lib_names.size()])
		for a in lib_names:
			var anim: Animation = (p as AnimationPlayer).get_animation(a)
			print("  %-28s %.2fs, %d track(s)" % [a, anim.length, anim.get_track_count()])
	if players.is_empty():
		print("animation  no AnimationPlayer: the file carries a rig but no clips")
	quit(0)

func _walk(n: Node, depth: int) -> void:
	var pad := ""
	for i in range(depth):
		pad += "  "
	var extra := ""
	if n is MeshInstance3D:
		meshes += 1
		var mesh: Mesh = (n as MeshInstance3D).mesh
		if mesh != null:
			var verts := 0
			for s in range(mesh.get_surface_count()):
				var arrs: Array = mesh.surface_get_arrays(s)
				if arrs.size() > Mesh.ARRAY_VERTEX and arrs[Mesh.ARRAY_VERTEX] != null:
					verts += (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var mat: Material = mesh.surface_get_material(s)
				if mat != null:
					mats[String(mat.resource_name) if String(mat.resource_name) != "" else "(unnamed)"] = true
			var aabb: AABB = mesh.get_aabb()
			extra = "  %d surface(s), %d verts, size %.2f x %.2f x %.2f" % [
				mesh.get_surface_count(), verts, aabb.size.x, aabb.size.y, aabb.size.z]
			if (n as MeshInstance3D).skin != null:
				extra += ", skinned"
	elif n is Skeleton3D:
		skeletons += 1
		var sk := n as Skeleton3D
		bones += sk.get_bone_count()
		extra = "  %d bones, root '%s'" % [sk.get_bone_count(), sk.get_bone_name(0) if sk.get_bone_count() > 0 else "-"]
	print("%s- %s (%s)%s" % [pad, n.name, n.get_class(), extra])
	for c in n.get_children():
		_walk(c, depth + 1)

func _find_players(n: Node, out: Array) -> void:
	if n is AnimationPlayer:
		out.append(n)
	for c in n.get_children():
		_find_players(c, out)
