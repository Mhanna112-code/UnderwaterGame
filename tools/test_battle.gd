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
	var cam := bt._stage_vp.get_camera_3d()
	if cam == null:
		push_error("BATTLE CAMERA MISSING")
		quit(1)
		return true
	# The authored attacks read from the side, but only inside Battle's own
	# viewport. x=0 is the old directly-behind composition.
	if absf(cam.position.x) < 2.0:
		push_error("BATTLE CAMERA BEHIND PARTY: x=%.2f, expected three-quarter view" % cam.position.x)
		quit(1)
		return true
	print("BATTLE OK  party_hp=%s enemy_hp=%s" % [
		str((bt.party[0].stats as CombatantStats).hp),
		str(bt.enemies.map(func(e): return (e.stats as CombatantStats).hp)),
	])
	quit(0)
	return true
