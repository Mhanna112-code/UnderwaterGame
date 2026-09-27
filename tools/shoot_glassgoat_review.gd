# Captures the two reviewer-facing scenes that cannot be proved by a textual
# test report alone: route guidance must not look like active-party selection,
# and the delivered Frilled Shark must be visibly present in an ordinary fight.
#
# Usage (run windowed):
#   godot --path . --resolution 1280x720 --script tools/shoot_glassgoat_review.gd -- <guidance|frilled> <out.png>
extends SceneTree

var mode := "guidance"
var out_png := "/tmp/glassgoat-review.png"
var frame := 0
var world: World

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		mode = String(args[0])
	if args.size() > 1:
		out_png = String(args[1])
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		world.title_screen.new_game_chosen.emit(97)
		return false
	if frame == 2:
		world._intro_active = false
		if mode == "frilled":
			world._start_battle("", false, "angler", [], false, false, ["frilled_shark"])
			return false
		world._begin_core_route_after_tutorial()
		world.route_transition_card.dismiss()
		var diver := world.divers[world.active] as Diver
		var beacon := world.route.active_position()
		# Stand short of the actual trigger, like a human approaching the first
		# route objective. This is a camera arrangement for visual evidence, not
		# a reachability shortcut; the route traversal gate owns collision proof.
		diver.global_position = beacon + Vector3(0.0, 0.0, 10.0)
		var camera := world.get_node("Camera3D") as Camera3D
		camera.global_position = diver.global_position + Vector3(0.0, 3.0, 8.0)
		camera.look_at(beacon + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		world._update_active_cursor()
		world._update_route_direction_indicator()
	if frame < 90:
		return false
	var image := root.get_texture().get_image()
	if image == null or image.save_png(out_png) != OK:
		push_error("could not capture Glassgoat review image: %s" % out_png)
		quit(1)
		return false
	print("Glassgoat review evidence: %s (%s)" % [out_png, mode])
	quit(0)
	return false
