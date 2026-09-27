# Captures the production route's capstone handoff and loss recovery surfaces.
#
# It does not invent a parallel UI: the route state reaches the real World
# battle-finished callback, which writes the capstone checkpoint, opens the
# Deep counter card, and then exercises the same save/load state the defeat
# screen promises.  Slot 98 is reserved only for this tool and is removed on
# success; the run aborts rather than overwrite an existing save there.
#
# Usage:
#   godot --path . --resolution 1280x720 --script tools/shoot_route_checkpoint.gd -- deep.png loss.png restored.png
extends SceneTree

const TEST_SLOT := 98
var deep_path := "/tmp/deep-transition.png"
var loss_path := "/tmp/checkpoint-loss.png"
var restored_path := "/tmp/checkpoint-restored.png"
var world: World

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		deep_path = String(args[0])
	if args.size() > 1:
		loss_path = String(args[1])
	if args.size() > 2:
		restored_path = String(args[2])
	call_deferred("_run")

func _run() -> void:
	if root.get_visible_rect().size.x < 1000.0:
		_fail("route checkpoint capture needs a browser-sized window, not headless rendering")
		return
	if FileAccess.file_exists(SaveManager.slot_path(TEST_SLOT)):
		_fail("refusing to overwrite existing evidence save slot %d" % TEST_SLOT)
		return
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(TEST_SLOT)
	await process_frame
	world._intro_active = false
	world._first_encounter_started = true
	world._first_encounter_done = true
	world._begin_core_route_after_tutorial()
	world.route_transition_card.dismiss()
	await process_frame

	# Resolve the two shallow solo beats through RouteProgression, then enter
	# the capstone. Its production victory callback is what writes/announces
	# the route checkpoint and presents the Deep-water counter card.
	for _i in 2:
		world.route.begin_active_encounter()
		world.route.resolve_active_encounter("won")
	var capstone := world.route.begin_active_encounter()
	if String(capstone.get("id", "")) != "shallow_capstone":
		_fail("expected shallow_capstone, got %s" % capstone)
		return
	world._route_battle_id = "shallow_capstone"
	world.battling = true
	world.battle = Battle.new()
	world._on_battle_finished("won")
	for _i in 6:
		await process_frame
	if not (world.route_transition_card.visible and world.route.objective_id == "deep_swordfish" and world.route.checkpoint_id == "shallows_capstone"):
		_fail("capstone callback did not expose the Deep transition/checkpoint")
		return
	_capture(deep_path)

	world.route_transition_card.dismiss()
	await process_frame
	world._show_game_over()
	for _i in 3:
		await process_frame
	if not world.game_over_screen.visible:
		_fail("capstone loss surface did not open")
		return
	_capture(loss_path)

	# Model a player pressing Restart after a loss. The actual restart reloads
	# the scene; `_load_save()` is the same state application boundary, used
	# here so both before/after surfaces can be captured in one short tool run.
	world.game_over_screen.close()
	paused = false
	for diver_value in world.divers:
		var stats := (diver_value as Diver).stats
		stats.hp = 1
		stats.oxygen = 0.0
	world._load_save()
	(world.get_node("HUD") as CanvasLayer).visible = true
	world._update_hp_bar()
	world._update_oxygen_bar()
	for _i in 4:
		await process_frame
	if world.route.objective_id != "deep_swordfish" or world.route.checkpoint_id != "shallows_capstone":
		_fail("checkpoint load did not restore Deep Swordfish after shallow capstone")
		return
	for diver_value in world.divers:
		var s := (diver_value as Diver).stats
		if s.hp != s.hp_max or not is_equal_approx(s.oxygen, s.oxygen_max):
			_fail("checkpoint load did not restore full HP/O2")
			return
	_capture(restored_path)
	_cleanup()
	print("route checkpoint captures: %s | %s | %s" % [deep_path, loss_path, restored_path])
	quit(0)

func _capture(path: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		_fail("no render texture; run windowed")
		return
	if image.save_png(path) != OK:
		_fail("could not write %s" % path)

func _cleanup() -> void:
	if is_instance_valid(world):
		world.queue_free()
	var path := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(SaveManager.slot_path(TEST_SLOT)):
		DirAccess.remove_absolute(path)

func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)
