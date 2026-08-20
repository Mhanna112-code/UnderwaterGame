# Do the divers actually move, and does anything fall through the world?
#
# A screenshot proves the scene renders. It does not prove the thing the ask
# was about: that you can swim these models around. This drives the real
# world scene through a short piece of play and measures.
#
# It runs in two acts, because the interesting failures are in different
# places. While swimming: is the right diver moving, is anyone drifting who
# should not be, is the camera still with us, and is each diver playing its
# OWN clip rather than one of the other two characters' off the shared rig.
# After letting go: did the whole sequence of clips happen, transitions
# included.
#
# Usage: godot --headless --path . --script verify/swim.gd
extends SceneTree

# Frame numbers are idle frames, not physics steps, and headless Godot runs
# them as fast as it can. They are generous on purpose: the point of the
# later ones is "long enough to have finished", not a measurement.
const TURN_AT := 70
const MEASURE_AT := 130
const LET_GO_AT := 135
const MOUSE_LOOK_AT := 45
const MOUSE_LOOK_CHECK_AT := 60
# After letting go the gate waits on the clips rather than on a frame count.
# A headless iteration takes about a millisecond and the End clip is a second
# long, so "a few hundred frames" is nowhere near enough real time for it to
# finish, and a frame budget generous enough to cover it would be a number
# nobody could justify. Wait for the sequence, give up on the clock.
const PATIENCE_SECONDS := 20.0

var world: Node3D
var frames := 0
var started_ms := 0
var start: Array = []
var findings: Array = []
var camera_before_mouse := Vector3.ZERO
var yaw_before_mouse := 0.0

# Every clip the player's diver plays, in order, with consecutive repeats
# collapsed. The swim clips ship as Start / Mid (Loop) / End, and playing
# only the loop is a diver who snaps from standing to a full stroke and back.
# Glass_Goat animated those transitions deliberately and spotted that they
# were missing within a minute of opening the first build.
var timeline: Array = []

func _initialize() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	started_ms = Time.get_ticks_msec()

func _elapsed() -> float:
	return float(Time.get_ticks_msec() - started_ms) / 1000.0

func _process(_dt: float) -> bool:
	frames += 1
	_record()

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

	# Glass_Goat's corrected direction is explicit: the side-on composition
	# belongs to battle, while swimming must retain free mouse-look. Drive the
	# same input branch a real mouse uses and prove both yaw and camera position
	# respond; a hard-coded overworld angle fails here.
	if frames == MOUSE_LOOK_AT:
		var cam: Camera3D = world.get_node("Camera3D")
		camera_before_mouse = cam.global_position - (world.divers[world.active] as Diver).global_position
		yaw_before_mouse = world.yaw
		world.mouse_look = true
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-150.0, 0.0)
		Input.parse_input_event(motion)
		return false

	if frames == MOUSE_LOOK_CHECK_AT:
		_check_mouse_look()
		return false

	if frames == TURN_AT:
		world.scripted_dir = Vector3(1, 0, 0)      # and then turn
		world.scripted_rise = 1.0
		return false

	if frames == MEASURE_AT:
		_measure_while_swimming()
		return false

	if frames == LET_GO_AT:
		# Let go of everything. Coming to a stop has its own clip and
		# nothing else here would ever trigger it.
		world.scripted_dir = Vector3.ZERO
		world.scripted_rise = 0.0
		return false

	if frames <= LET_GO_AT:
		return false
	if _timeline_missing() != "" and _elapsed() < PATIENCE_SECONDS:
		return false

	_check_timeline()
	for f in findings:
		print("FINDING  " + f)
	print("SWIM: clean" if findings.is_empty() else "SWIM: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true

func _measure_while_swimming() -> void:
	# Only the active diver is steered - the other two hold position once
	# you're not controlling them (world.gd stopped drifting them on
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
	# it belonged to the unrigged code it was written for. What is still
	# code's job, because no clip can know it, is angling the body when the
	# diver is heading up or down. This gate has been climbing since TURN_AT.
	var player: Diver = world.divers[world.active]
	if player.model.rotation.x < 0.05:
		findings.append("NOT CLIMBING: the player has been swimming upward and is pitched %.2f rad, expected nose up" % player.model.rotation.x)

	var cam: Camera3D = world.get_node("Camera3D")
	var gap: float = cam.global_position.distance_to(player.global_position)
	print("camera               %.2f m from the player" % gap)
	if gap > 14.0 or gap < 1.0:
		findings.append("CAMERA LOST: %.2f m from the diver it should be following" % gap)

func _check_mouse_look() -> void:
	world.mouse_look = false
	var cam: Camera3D = world.get_node("Camera3D")
	var yaw_change: float = absf(world.yaw - yaw_before_mouse)
	var relative_now: Vector3 = cam.global_position - (world.divers[world.active] as Diver).global_position
	var camera_change: float = Vector2(
		relative_now.x - camera_before_mouse.x,
		relative_now.z - camera_before_mouse.z
	).length()
	print("mouse look           yaw changed %.2f rad, camera orbited %.2f m" % [yaw_change, camera_change])
	if yaw_change < 0.4:
		findings.append("MOUSE LOOK IGNORED: a 150 px mouse move changed yaw only %.2f rad" % yaw_change)
	if camera_change < 1.0:
		findings.append("CAMERA HARD-CODED: mouse-look changed yaw but camera moved only %.2f m" % camera_change)


func _record() -> void:
	if world == null or world.divers.is_empty():
		return
	var d: Diver = world.divers[world.active]
	if d == null or d.anim == null:
		return
	var playing := String(d.anim.current_animation)
	if playing == "":
		return
	var bar := playing.rfind("|")
	var stem := playing.substr(bar + 1) if bar >= 0 else playing
	if timeline.is_empty() or String(timeline[timeline.size() - 1]) != stem:
		timeline.append(stem)

# The player started still, swam, turned, climbed, then let go. The clips
# that implies, in order, are: idle, the swim Start, the swim loop, the swim
# End, and idle again. Checked as a subsequence, so an extra clip in between
# is fine and a missing one is not.
func _wanted() -> Array:
	var who := String((world.divers[world.active] as Diver).model_name)
	return [
		["idle", Cast.motion(who, "idle")],
		["swim start", Cast.motion(who, "swim_start")],
		["swim loop", Cast.motion(who, "swim")],
		["swim end", Cast.motion(who, "swim_end")],
		["idle again", Cast.motion(who, "idle")],
	]

# The first step of the sequence the timeline has not reached yet, or "" if
# it has reached them all. Checked as a subsequence, so an extra clip in
# between is fine and a missing one is not.
func _timeline_missing() -> String:
	if world == null or world.divers.is_empty():
		return "not started"
	var at := 0
	for step in _wanted():
		var found := -1
		for i in range(at, timeline.size()):
			if String(timeline[i]) == String(step[1]):
				found = i
				break
		if found < 0:
			return "%s clip '%s'" % [step[0], step[1]]
		at = found + 1
	return ""

func _check_timeline() -> void:
	print("clips played, in order:")
	for c in timeline:
		print("   %s" % c)
	var missing := _timeline_missing()
	if missing != "":
		findings.append("MISSING TRANSITION: never reached the %s, after %.0fs of waiting" % [missing, _elapsed()])

func _short(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
