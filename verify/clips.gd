# What motion does each delivered model actually carry?
#
# Glass_Goat's swim animations exist in Blender and have never been in an
# export. This prints what is really in each file so the next delivery can be
# checked in one command instead of by opening the editor and hoping.
#
# Usage: godot --headless --path . --script verify/clips.gd
extends SceneTree

const FILES := [
	"res://art/characters/Main_Team_Rigging.fbx",
	"res://art/characters/divers.glb",
	"res://GoblinGrunt.fbx",
]
const WANT := ["swim", "idle", "attack", "damage", "walk"]

func _init() -> void:
	for f in FILES:
		if not ResourceLoader.exists(f):
			print("%-46s MISSING" % f)
			continue
		var n: Node = (load(f) as PackedScene).instantiate()
		var ap := _player(n)
		var skels := _count_skeletons(n)
		var names: Array = []
		if ap != null:
			for a in ap.get_animation_list():
				if ap.get_animation(a).length > 0.05:
					names.append(String(a).get_slice("|", 1) if String(a).contains("|") else String(a))
		var uniq: Dictionary = {}
		for nm in names:
			uniq[nm] = true
		print("%-46s %d skeleton(s), %d clip(s)" % [f, skels, uniq.size()])
		for w in WANT:
			var hits: Array = []
			for nm2 in uniq.keys():
				if String(nm2).to_lower().contains(w):
					hits.append(String(nm2))
			print("   %-8s %s" % [w, ", ".join(hits) if not hits.is_empty() else "NONE"])
	quit(0)

func _player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _player(c)
		if r != null:
			return r
	return null

func _count_skeletons(n: Node) -> int:
	var k := 1 if n is Skeleton3D else 0
	for c in n.get_children():
		k += _count_skeletons(c)
	return k
