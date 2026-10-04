# Repeatable production-battle captures for both authored lab blockers.
#
# Usage:
#   godot --path . --resolution 1280x720 --script tools/shoot_deep_zone_blockers.gd -- <outdir>
extends SceneTree

var outdir := "/tmp/deep-zone-blockers"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		outdir = String(args[0])
	DirAccess.make_dir_recursive_absolute(outdir)
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world._first_encounter_done = true
	var diver := world.divers[world.active] as Diver
	var points: Dictionary = world.deep_zone_layout.route_points()

	diver.global_position = points.bomb_bot as Vector3
	world._update_route_zone()
	world._update_deep_zone_blockers()
	await _settle(10)
	_capture("bomb-bot.png")

	world._on_battle_finished("won")
	await _settle(3)
	diver.global_position = points.sword_slayer as Vector3
	world._update_deep_zone_blockers()
	await _settle(10)
	_capture("sword-slayer.png")

	var audio_owner := root.get_node_or_null("GameAudio")
	if audio_owner != null:
		audio_owner.call("release_streams_for_shutdown")
	world.queue_free()
	await _settle(3)
	await create_timer(0.15).timeout
	quit()

func _settle(frames: int) -> void:
	for _i in range(frames):
		await process_frame

func _capture(filename: String) -> void:
	var path := outdir.path_join(filename)
	root.get_texture().get_image().save_png(path)
	print("shot       %s" % path)
