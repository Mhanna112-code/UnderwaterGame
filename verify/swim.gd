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
	# World._ready() has not run yet in _initialize() - a node added to the
	# root before the loop starts gets its _ready on the first iteration -
	# so the title screen only exists from here on.
	if frames == 1:
		# _ready() ends on the title screen, which sets get_tree().paused
		# and freezes every diver. Without this the gate measured a game
		# nobody had started yet and reported that nothing moved, which was
		# true and useless. Going through the signal rather than poking
		# `paused` keeps the gate on the path a player actually takes.
		world.title_screen.new_game_chosen.emit(1)
		return false
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

		# A rigged diver that is not playing anything is the failure the
		# old procedural code could not have: the clips resolve, the body
		# stands still, and it looks like a frozen game rather than a
		# missing animation.
		if d.anim == null:
			findings.append("NO RIG: %s has no AnimationPlayer" % who)
			continue
		var playing := String(d.anim.current_animation)
		print("%-20s playing %s" % ["", playing if playing != "" else "NOTHING"])
		if playing == "":
			findings.append("NOT ANIMATING: %s is playing no clip at all" % who)
			continue
		var want_motion := "swim" if is_active else "idle"
		var want := d.resolve(Cast.motion(who, want_motion))
		if playing != want:
			findings.append("WRONG CLIP: %s is playing '%s', expected the %s clip '%s'" % [
				who, playing, want_motion, want])
		# Every file carries all three characters' clips, so playing SOME
		# idle is not the same as playing YOUR idle. This is the check that
		# catches the scuba diver standing in the brass suit's stance.
		var fam := Cast.family(who)
		if not playing.contains(fam + "_"):
			findings.append("WRONG CHARACTER'S CLIP: %s (%s) is playing '%s'" % [who, fam, playing])

	# The body's swimming posture comes out of the clip now, so there is no
	# pitch to assert while swimming level - that check used to be here and
	# it belongs to the unrigged code it was written for. What is still
	# code's job, because no clip can know it, is angling the body when the
	# diver is heading up or down. This gate has been climbing since frame
	# 70, so the nose should be up by now.
	var player: Diver = world.divers[world.active]
	if player.model.rotation.x < 0.05:
		findings.append("NOT CLIMBING: the player has been swimming upward and is pitched %.2f rad, expected nose up" % player.model.rotation.x)
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
