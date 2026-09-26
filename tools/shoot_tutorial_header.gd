# Captures the first player-visible tutorial combat frame at browser size.
#
# This exists specifically to review the encounter header against the party
# cards.  The header is taller when an encounter source wraps, so a static
# scene or a headless 64px viewport cannot demonstrate that the cards remain
# readable beneath it.
#
# Usage:
#   godot --path . --resolution 1280x720 --script tools/shoot_tutorial_header.gd -- /tmp/tutorial-header.png
extends SceneTree

var output_path := "/tmp/tutorial-header.png"
var world: World
var frames := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output_path = String(args[0])
	call_deferred("_start")

func _start() -> void:
	if root.get_visible_rect().size.x < 1000.0:
		push_error("Tutorial header capture needs a browser-sized window, not headless rendering")
		quit(1)
		return
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.new_game_chosen.emit(1)
	# Create the production tutorial encounter directly.  The title/intro
	# sequence is unrelated to the header state and would only delay capture.
	world._first_encounter_started = true
	world._intro_active = false
	world._start_battle("", false, "angler", world.divers, false, true)
	while frames < 12:
		frames += 1
		await process_frame
	var battle := world.battle as Battle
	if battle == null:
		push_error("Tutorial header capture did not create a battle")
		quit(1)
		return
	var queue_bottom := battle._queue_bar.get_global_rect().end.y
	var first_card := (battle.party[0] as Dictionary).get("card") as Control
	if first_card == null or first_card.get_global_rect().position.y < queue_bottom + 8.0:
		push_error("Tutorial header capture found a party card underneath the encounter strip")
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image == null or image.save_png(output_path) != OK:
		push_error("Tutorial header capture could not save %s" % output_path)
		quit(1)
		return
	print("TUTORIAL HEADER capture: header_bottom=%s first_card_top=%s -> %s" % [queue_bottom, first_card.get_global_rect().position.y, output_path])
	world.queue_free()
	quit(0)
