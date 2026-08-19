# Do the divers actually move, and does anything fall through the world?
#
# A screenshot proves the scene renders. It does not prove the thing the ask
# was about: that you can swim these models around. This drives the real
# world scene for two seconds of simulated play and measures.
#
# Usage: godot --headless --path ~/underwatergame --script verify/swim.gd
extends SceneTree

var world: Node3D
var frames := 0
var start: Array = []
var findings: Array = []

func _initialize() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)

func _process(_dt: float) -> bool:
	frames += 1
	if frames == 2:
		if world.divers.size() != 3:
			findings.append("CAST SHORT: %d divers spawned, expected 3" % world.divers.size())
		for d in world.divers:
			start.append((d as Node3D).global_position)
		world.scripted = true
		world.scripted_dir = Vector3(0, 0, -1)     # swim forward
		return false
	if frames < 130:
		if frames == 70:
			world.scripted_dir = Vector3(1, 0, 0)  # and then turn
			world.scripted_rise = 1.0
		return false

	# Only the active diver is steered - the other two now hold position
	# once you're not controlling them (world.gd stopped drifting them on
	# purpose, so a diver parked on a gap-sequence lock plate stays put),
	# so "did it move" only means something for whichever one is active.
	for i in range(world.divers.size()):
		var d: Diver = world.divers[i]
		var moved: float = (d.global_position - (start[i] as Vector3)).length()
		var who := String(d.model_name)
		var is_active: bool = (i == world.active)
		print("%-20s moved %5.2f m, now at %s, pitch %+.2f rad%s" % [
			who, moved, _short(d.global_position), d.model.rotation.x,
			"  (active)" if is_active else "  (should hold still)",
		])
		if is_active and moved < 0.5:
			findings.append("STILL: %s (active) moved only %.2f m in ~2s of swimming" % [who, moved])
		elif not is_active and moved > 0.1:
			findings.append("DRIFTED: %s moved %.2f m while not being steered" % [who, moved])
		if d.global_position.y < -0.5:
			findings.append("THROUGH THE FLOOR: %s is at y=%.2f" % [who, d.global_position.y])
		if not is_finite(d.global_position.length()):
			findings.append("NOT A NUMBER: %s has a non-finite position" % who)

	var player: Diver = world.divers[world.active]
	if absf(player.model.rotation.x) < 0.3:
		findings.append("NO SWIM POSTURE: the player is still upright (pitch %.2f) after swimming" % player.model.rotation.x)
	var cam: Camera3D = world.get_node("Camera3D")
	var gap: float = cam.global_position.distance_to(player.global_position)
	print("camera               %.2f m behind the player" % gap)
	if gap > 14.0 or gap < 1.0:
		findings.append("CAMERA LOST: %.2f m from the diver it should be following" % gap)

	for f in findings:
		print("FINDING  " + f)
	print("SWIM: clean" if findings.is_empty() else "SWIM: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true

func _short(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
