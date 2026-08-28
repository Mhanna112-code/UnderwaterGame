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
	# viewport. This used to assert absf(cam.position.x) >= 2.0, which was a
	# fine proxy while the camera was a hand-placed constant. It is not one
	# any more: _frame_stage_camera() now works out the distance from how
	# big the group is and how much height the HUD has left, so the same
	# angle produces a different x for a lone diver than for a full party,
	# and the coordinate says nothing on its own.
	#
	# The invariant it was protecting is unchanged, so measure it directly.
	# The party and the enemies face each other along Z, so a camera on the
	# Z axis is the old directly-behind composition and reads as 0 degrees.
	var flat := Vector2(cam.position.x, cam.position.z)
	if flat.length() < 0.01:
		push_error("BATTLE CAMERA ON TOP OF THE PARTY: %s" % cam.position)
		quit(1)
		return true
	var off_axis: float = rad_to_deg(absf(atan2(flat.x, absf(flat.y))))
	if off_axis < 15.0:
		push_error("BATTLE CAMERA BEHIND PARTY: %.0f deg off the party-to-enemy axis, expected a three-quarter view" % off_axis)
		quit(1)
		return true
	print("battle camera %.0f deg off the party-to-enemy axis, %.1f m out" % [off_axis, cam.position.length()])
	print("BATTLE OK  party_hp=%s enemy_hp=%s" % [
		str((bt.party[0].stats as CombatantStats).hp),
		str(bt.enemies.map(func(e): return (e.stats as CombatantStats).hp)),
	])
	quit(0)
	return true
