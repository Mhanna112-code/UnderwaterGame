# Throwaway probe: opens the real intro crawl and feeds it a real
# InputEventMouseButton straight through _unhandled_input(), the same path
# a genuine mouse click takes, to check whether left-click-to-skip actually
# fires _finish() - and whether get_tree().paused (true for the whole
# intro, see world.gd's _on_title_new_game()) has any bearing on it.
# Usage: godot --headless --path . --script verify/intro_crawl_click_skip_probe.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	print("tree paused before New Game: %s" % paused)
	world.title_screen.new_game_chosen.emit(1)
	await process_frame
	await process_frame
	await process_frame

	print("intro_crawl visible: %s" % world.intro_crawl.visible)
	print("tree paused during intro: %s" % paused)
	print("intro_crawl mouse_filter: %s (IGNORE=%s)" % [world.intro_crawl.mouse_filter, Control.MOUSE_FILTER_IGNORE])

	var finished := false
	world.intro_crawl.finished.connect(func(): finished = true)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 360)
	root.push_input(click)
	await process_frame
	await process_frame

	print("intro finished after left click: %s" % finished)
	print("intro_crawl visible after click: %s" % world.intro_crawl.visible)

	quit(0)
