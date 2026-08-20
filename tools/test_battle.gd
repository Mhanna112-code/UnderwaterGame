# Does instantiating a Battle (SubViewport stage, party + N goblins, UI)
# crash on its own?
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
	var bt := b as Battle
	print("BATTLE OK  party_hp=%s enemy_hp=%s" % [
		str((bt.party[0].stats as CombatantStats).hp),
		str(bt.enemies.map(func(e): return (e.stats as CombatantStats).hp)),
	])
	quit(0)
	return true
