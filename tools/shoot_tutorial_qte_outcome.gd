# Captures the real resolved tutorial QTE at browser resolution.
#
# This is intentionally a windowed evidence tool, not a headless verifier:
# it drives the production Battle widget through either a correctly timed X
# press or the natural timeout, then captures the visible result/Continue
# state before acknowledging it.  It catches the old blank-stage/unseen
# Enter regression in an image a reviewer can inspect.
#
# Usage:
#   godot --path . --resolution 1280x720 --script tools/shoot_tutorial_qte_outcome.gd -- success.png success
#   godot --path . --resolution 1280x720 --script tools/shoot_tutorial_qte_outcome.gd -- miss.png miss
extends SceneTree

const TIMEOUT_MS := 18000

var output_path := "/tmp/tutorial-qte.png"
var outcome := "success"
var world: World
var battle: Battle
var frames := 0
var qte_seen := false
var qte_explanation_acked := false
var x_sent := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		output_path = String(args[0])
	if args.size() > 1:
		outcome = String(args[1]).to_lower()
	if outcome not in ["success", "miss"]:
		push_error("QTE capture outcome must be success or miss, got %s" % outcome)
		quit(1)
		return
	call_deferred("_start")

func _start() -> void:
	if root.get_visible_rect().size.x < 1000.0:
		push_error("QTE capture needs a browser-sized window, not headless rendering")
		quit(1)
		return
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(11)
	world._first_encounter_started = true
	world._intro_active = false
	world._transitioning_to_encounter = false
	if is_instance_valid(world._intro_arrow):
		world._intro_arrow.visible = false
	world.set_process(false)
	world.set_physics_process(false)
	for diver_value in world.divers:
		(diver_value as Diver).stats.agility = 0
	battle = Battle.new()
	battle.party_source = world.divers
	battle.world = world
	battle.tutorial_encounter = true
	battle._tutorial_step = battle._TUTORIAL_SCRIPT.size()
	battle._tutorial_enemy_turns = 0
	world.battle = battle
	world.battling = true
	battle.finished.connect(world._on_battle_finished)
	world.add_child(battle)
	await _drive_to_resolved_qte()
	await _capture_handoff()

func _drive_to_resolved_qte() -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if battle._tutorial_awaiting_enter and battle._tutorial_qte_detail.visible and not qte_explanation_acked:
			battle.tutorial_continue_btn.emit_signal("pressed")
			qte_explanation_acked = true
		if battle._qte_active:
			qte_seen = true
			if outcome == "success" and not x_sent and battle.qte_indicator.position.x > 0.0:
				var zone_center := battle.qte_zone.position.x + battle.qte_zone.size.x * 0.5
				battle.qte_indicator.position.x = zone_center - battle.qte_indicator.size.x * 0.5
				battle._unhandled_input(_x_event())
				x_sent = true
		elif qte_seen:
			return
		await process_frame
	push_error("QTE capture timed out before %s outcome resolved" % outcome)
	quit(1)

func _capture_handoff() -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline and not (battle._tutorial_finale_shown and battle._tutorial_awaiting_enter):
		await process_frame
	if not (battle._tutorial_finale_shown and battle._tutorial_awaiting_enter):
		push_error("QTE capture never reached the visible post-QTE handoff")
		quit(1)
		return
	# Wait for deferred fit/Container layout so the capture represents the same
	# fully laid-out state asserted by verify/tutorial_qte_handoff_layout.gd.
	for _i in 4:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("QTE capture has no render texture; run windowed, not headless")
		quit(1)
		return
	var result := image.save_png(output_path)
	if result != OK:
		push_error("QTE capture could not write %s" % output_path)
		quit(1)
		return
	var button_rect := battle.tutorial_continue_btn.get_global_rect()
	print("QTE %s capture: qte_seen=%s success=%s stage=%s continue=%s -> %s" % [
		outcome, qte_seen, battle._qte_success, battle._stage_container.get_global_rect(), button_rect, output_path,
	])
	world.queue_free()
	quit(0)

func _x_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_X
	return event
