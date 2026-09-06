# Diagnostic-only capture of the special encounter confirm popup, to see
# its actual on-screen layout rather than guessing from the CenterContainer
# code alone. Not part of the regular verify/ suite.
# Usage: godot --headless --path . --script tools/shoot_special_encounter.gd -- <out.png>
extends SceneTree

var out_png := "/tmp/special-encounter.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_png = String(args[0])
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	await process_frame
	await process_frame
	# Bypass the title screen entirely - it's on its own CanvasLayer (layer
	# 20, always on top) and $HUD (parent of special_encounter_prompt) starts
	# hidden until New/Load Game runs, so without this the prompt would be
	# built and "visible" but invisible underneath a hidden HUD.
	world.title_screen.close()
	world.get_node("HUD").visible = true
	await process_frame
	world.special_encounter_prompt.open()
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_png)
	print("shot %s" % out_png)
	quit()
