# Does instantiating a Battle (SubViewport stage, Diver + Goblin, UI) crash
# on its own?
#
# Usage: godot --headless --path . --script tools/test_battle.gd
extends SceneTree

var b: CanvasLayer
var frames := 0

func _initialize() -> void:
	print("instantiating Battle...")
	b = Battle.new()
	root.add_child(b)
	print("Battle added to tree")

func _process(_dt: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	print("BATTLE OK  player_hp=%d enemy_hp=%d" % [b.player_stats.hp, b.enemy_stats.hp])
	quit(0)
	return true
