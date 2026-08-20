# Does instantiating a Goblin (loads characters/GoblinGrunt.fbx) crash on
# its own, isolated from the rest of the game? verify/swim.gd never triggers
# a battle, so it never exercises this path.
#
# Usage: godot --headless --path . --script tools/test_goblin.gd
extends SceneTree

var g: Node3D
var frames := 0

func _initialize() -> void:
	print("instantiating Goblin...")
	g = Goblin.new()
	root.add_child(g)
	print("Goblin added to tree")

func _process(_dt: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	print("GOBLIN OK  height=%.2f radius=%.2f anim=%s" % [g.height, g.radius, g.anim])
	quit(0)
	return true
