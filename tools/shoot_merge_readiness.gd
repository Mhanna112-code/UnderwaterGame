# Captures the two player-visible surfaces repaired in PR 54's final audit:
# exclusive defeat UI and real combat identity labels.
# Usage:
# godot --path . --resolution 1280x720 --script tools/shoot_merge_readiness.gd -- defeat.png names.png
extends SceneTree

var defeat_path := "/tmp/pr54-defeat.png"
var names_path := "/tmp/pr54-names.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		defeat_path = String(args[0])
	if args.size() > 1:
		names_path = String(args[1])
	call_deferred("_run")

func _run() -> void:
	var defeat_world := await _active_world()
	defeat_world._show_game_over()
	await _settle(5)
	root.get_texture().get_image().save_png(defeat_path)
	print("defeat evidence  %s" % defeat_path)
	paused = false
	defeat_world.queue_free()
	await process_frame

	var combat_world := await _active_world()
	combat_world._start_battle()
	await _settle(12)
	root.get_texture().get_image().save_png(names_path)
	print("name evidence    %s" % names_path)
	paused = false
	combat_world.queue_free()
	await process_frame
	quit()

func _active_world() -> World:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	current_scene = world
	await _settle(3)
	world.title_screen.close()
	world.get_node("HUD").visible = true
	paused = false
	return world

func _settle(count: int) -> void:
	for _i in range(count):
		await process_frame
