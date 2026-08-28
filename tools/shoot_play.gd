# Screenshot the game as it is actually played, not as it sits on the title
# screen. Starts a new game, swims forward for a while, and shoots.
#
# The plain scene screenshot (tools/shoot_scene.gd) stopped being useful once
# _ready() started ending on a paused title screen: every shot was the same
# menu. This one presses New Game the way a player does.
#
# Usage:
#   godot --path . --script tools/shoot_play.gd -- <out.png> [frames] [camera]
#
# camera is optional and moves the camera somewhere useful for looking at the
# models rather than playing:
#   follow  the normal chase camera (default)
#   face    close in front of the active diver
#   side    close beside the active diver
#   battle  start an encounter and shoot the fight screen
#   guardian  look at the first item guardian, the one landmark to swim to
#
# rise is optional too: 1 climbs while swimming, -1 dives.
extends SceneTree

var out_png := "/tmp/play.png"
var settle := 90
var mode := "follow"
var rise := 0.0
var frames := 0
var world: Node3D

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_png = String(a[0])
	if a.size() > 1:
		settle = int(a[1])
	if a.size() > 2:
		mode = String(a[2])
	if a.size() > 3:
		rise = float(a[3])
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)

func _process(_d: float) -> bool:
	frames += 1
	# _ready() has not run yet during _initialize(), so the title screen only
	# exists from here on.
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames == 2:
		# Stand off from the first item guardian and look at it, which is
		# the one landmark in the dive site worth swimming to and the
		# hardest thing to check without opening the editor.
		if mode == "guardian":
			var spot: Vector3 = ItemGuardian.SPOTS[0].at as Vector3
			# Stand off along the line back to the party's start, so the
			# shot is the view a player gets on the approach, and face the
			# guardian. world.gd's forward is -(sin(yaw), 0, cos(yaw)),
			# so the yaw that looks along d is atan2(-d.x, -d.z).
			var back: Vector3 = Vector3(spot.x, 0.0, spot.z).normalized()
			world.divers[world.active].position = spot - back * 9.0 + Vector3(0.0, 0.4, 0.0)
			world.yaw = atan2(-back.x, -back.z)
			world.scripted = true
			world.scripted_dir = Vector3.ZERO
			return false
		if mode == "battle":
			world._start_battle()
			return false
		world.scripted = true
		world.scripted_dir = Vector3(0, 0, -1)
		world.scripted_rise = rise
		return false
	if frames < settle:
		return false

	if mode != "follow" and mode != "battle" and mode != "guardian":
		_park_camera()
		# one more frame so the camera move lands before the shot
		if frames == settle:
			return false

	root.get_texture().get_image().save_png(out_png)
	print("shot       %s" % out_png)
	if mode == "battle":
		for e in (world.battle as Battle).party:
			var a := e.actor as Diver
			print("%-20s playing %s" % [String(e.model_name),
				a.anim.current_animation if a != null and a.anim != null else "NOTHING"])
		return true
	var d: Diver = world.divers[world.active]
	print("active     %s at %s, playing %s" % [
		d.model_name, d.global_position,
		d.anim.current_animation if d.anim != null else "NOTHING"])
	return true

func _park_camera() -> void:
	var d: Diver = world.divers[world.active]
	var cam: Camera3D = world.get_node("Camera3D")
	var eye: Vector3 = d.global_position + Vector3(0, 0.3, 0)
	if mode == "face":
		# The models face +Z, so standing in front of one means standing at
		# +Z from it, not at -Z.
		cam.global_position = eye + d.global_transform.basis.z * -3.2
	else:
		cam.global_position = eye + d.global_transform.basis.x * 3.2
	cam.look_at(eye, Vector3.UP)
