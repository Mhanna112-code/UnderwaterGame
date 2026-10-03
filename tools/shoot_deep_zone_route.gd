# Capture the production World from a declared deep-zone route point. This is
# review evidence only: it does not add a query-string entry or bypass to the
# shipped game, and it uses the same camera, HUD, floor, lighting, and props a
# normal player sees after physically crossing the ability corridor.
#
# Usage:
#   godot --path . --resolution 1280x720 \
#     --script tools/shoot_deep_zone_route.gd -- <out.png> [entry|bomb|sword|lab|lab_close|maze]
extends SceneTree

const VIEWS := {
	"entry": {
		"at": Vector3(68.0, 2.0, 10.0),
		"look": Vector3(90.0, 2.0, 10.0),
	},
	"bomb": {
		"at": Vector3(108.0, 2.0, 16.0),
		"look": Vector3(120.0, 2.0, 16.0),
	},
	"sword": {
		"at": Vector3(133.0, 2.0, 16.0),
		"look": Vector3(145.0, 2.0, 16.0),
	},
	"lab": {
		"at": Vector3(146.0, 2.0, 16.0),
		"look": Vector3(175.0, 2.0, 16.0),
	},
	"lab_close": {
		"at": Vector3(168.0, 2.0, 16.0),
		"look": Vector3(182.0, 4.0, 16.0),
	},
	"maze": {
		"at": Vector3(112.0, 2.0, -18.0),
		"look": Vector3(125.0, 2.0, -34.0),
	},
}

var out_png := "/tmp/deep-zone-route.png"
var view_id := "entry"
var world: World
var frame := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_png = String(args[0])
	if args.size() > 1 and VIEWS.has(String(args[1])):
		view_id = String(args[1])
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frame == 3:
		# Skip-tutorial review mode correctly opens the normal world onboarding;
		# dismiss it here so the evidence captures the route rather than a modal.
		root.get_node("CharacterAbilityPopup").call("_close")
		var definition: Dictionary = VIEWS[view_id]
		if view_id == "sword":
			world.route_state.set_blocker_state("bomb_bot", "defeated")
			world.route_state.set_objective("defeat_sword_slayer")
			world._sync_deep_zone_blocker_staging()
		elif view_id in ["lab", "lab_close"]:
			world.route_state.set_blocker_state("bomb_bot", "defeated")
			world.route_state.set_blocker_state("sword_slayer", "defeated")
			world.route_state.set_lab_state("available")
			world.route_state.set_objective("enter_lab")
			world._sync_deep_zone_blocker_staging()
		var active := world.divers[world.active] as Diver
		active.global_position = definition.at as Vector3
		var direction: Vector3 = ((definition.look as Vector3) - active.global_position).normalized()
		var right := direction.cross(Vector3.UP).normalized()
		# Keep the rest of the party in the actual follow formation rather than
		# leaving two divers behind in the Shallows screenshot. A shallow V sits
		# behind the active diver so the party never obscures the landmark being
		# reviewed.
		var follower := 0
		for index in range(world.divers.size()):
			if index == world.active:
				continue
			var side := -1.0 if follower == 0 else 1.0
			(world.divers[index] as Diver).global_position = active.global_position - direction * (1.7 + follower * 0.55) + right * side * 1.35
			follower += 1
		world.yaw = atan2(direction.x, direction.z)
		world.pitch = -0.14
		world.scripted = true
		world.scripted_dir = Vector3.ZERO
		# Snap once to the same chase-camera solution World converges toward.
		# Without this, evidence taken after a long route teleport can still be
		# halfway through a camera lerp and falsely make the party look tiny.
		var focus := active.global_position + Vector3(0.0, active.height * 0.35, 0.0)
		world.cam.global_position = focus - direction * world.cam_dist
		world.cam.global_position.y = maxf(world.cam.global_position.y, 0.6)
		world.cam.look_at(focus, Vector3.UP)
		return false
	if frame < 45:
		return false
	if frame == 45:
		root.get_texture().get_image().save_png(out_png)
		print("deep route shot  %s  view=%s" % [out_png, view_id])
		var audio_owner := root.get_node_or_null("GameAudio")
		if audio_owner != null:
			audio_owner.call("release_streams_for_shutdown")
		return false
	# Compressed playback objects are retired by the audio thread rather than
	# synchronously by stop(). Give that handoff a few rendered frames so the
	# capture harness itself exits without hiding ObjectDB/resource leaks.
	return frame >= 55
