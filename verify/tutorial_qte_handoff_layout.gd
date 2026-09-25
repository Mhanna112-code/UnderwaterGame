# `playtest repair: a resolved tutorial QTE keeps a visible stage and a visible
# Continue control at browser resolution — guards against the blank post-QTE
# screen and unseen Enter acknowledgement reported in the hosted run`.
#
# Run windowed at each review size, not headless:
#   godot --path . --resolution 1280x720 --script verify/tutorial_qte_handoff_layout.gd
#   godot --path . --resolution 1920x1080 --script verify/tutorial_qte_handoff_layout.gd
#
# This intentionally drives the real QTE widget and its X handler. It does
# NOT inject Enter after either the success or timeout outcome: the assertion
# is that the production Continue control remains visible and usable first.
extends SceneTree

const TIMEOUT_MS := 18000
const MIN_STAGE_HEIGHT := 160.0

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event

func _run() -> void:
	var viewport := Vector2(root.get_visible_rect().size)
	if viewport.x < 1000.0 or viewport.y < 600.0:
		findings.append("TUTORIAL LAYOUT HARNESS: requires a real browser-sized window, got %s; do not substitute a 64px headless viewport" % viewport)
	else:
		await _exercise_qte_outcome("success", true, viewport)
		await _exercise_qte_outcome("miss", false, viewport)
	for finding in findings:
		push_error(finding)
	print("tutorial QTE handoff layout  success and miss retain visible stage/Continue" if findings.is_empty() else "tutorial QTE handoff layout  FAILED")
	quit(0 if findings.is_empty() else 1)

func _exercise_qte_outcome(label: String, hit_zone: bool, viewport: Vector2) -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	# This focused test supplies World-owned divers but prevents the map beam
	# from racing another tutorial battle into the same party.
	world._first_encounter_started = true
	world._intro_active = false
	world._transitioning_to_encounter = false
	if is_instance_valid(world._intro_arrow):
		world._intro_arrow.visible = false
	world.set_process(false)
	world.set_physics_process(false)
	for diver_value in world.divers:
		(diver_value as Diver).stats.agility = 0
	var battle := Battle.new()
	battle.party_source = world.divers
	battle.world = world
	battle.tutorial_encounter = true
	battle._tutorial_step = battle._TUTORIAL_SCRIPT.size()
	battle._tutorial_enemy_turns = 0
	# Mirror World's production ownership/wiring. Constructing a Battle directly
	# is useful to start at the live QTE, but the handoff being tested must still
	# travel through World._on_battle_finished() rather than leaving an orphan
	# CanvasLayer that cannot ever restore the route.
	world.battle = battle
	world.battling = true
	battle.finished.connect(world._on_battle_finished)
	world.add_child(battle)

	var qte_seen := false
	var qte_resolved := false
	var sent_x := false
	var qte_explanation_acked := false
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline and not qte_resolved:
		# This is the pre-QTE explanation, whose rendered button is deliberately
		# used rather than an Enter injection. The post-QTE card below must stay
		# untouched until its visibility/geometry has been verified.
		if battle._tutorial_awaiting_enter and battle._tutorial_qte_detail.visible and not qte_explanation_acked:
			_expect(battle.tutorial_continue_btn.visible and not battle.tutorial_continue_btn.disabled,
				"%s QTE EXPLANATION: visible instruction has no usable Continue button" % label)
			battle.tutorial_continue_btn.emit_signal("pressed")
			qte_explanation_acked = true
		if battle._qte_active:
			qte_seen = true
			if hit_zone and battle.qte_indicator.position.x > 0.0 and not sent_x:
				var zone_center := battle.qte_zone.position.x + battle.qte_zone.size.x * 0.5
				battle.qte_indicator.position.x = zone_center - battle.qte_indicator.size.x * 0.5
				battle._unhandled_input(_key(KEY_X))
				sent_x = true
		elif qte_seen:
			qte_resolved = true
		await process_frame

	_expect(qte_seen, "%s QTE: the real timing widget never appeared" % label)
	_expect(qte_resolved, "%s QTE: timing widget did not resolve before timeout" % label)
	if hit_zone:
		_expect(sent_x and battle._qte_success, "success QTE: in-zone X did not resolve as a dodge")
	else:
		_expect(not battle._qte_success, "miss QTE: timeout unexpectedly resolved as a dodge")

	deadline = Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline and not (battle._tutorial_finale_shown and battle._tutorial_awaiting_enter):
		await process_frame
	_expect(battle._tutorial_finale_shown and battle._tutorial_awaiting_enter,
		"%s QTE HANDOFF: result never reached the post-QTE acknowledgement" % label)
	if battle._tutorial_finale_shown and battle._tutorial_awaiting_enter:
		await _check_post_qte_layout(battle, viewport, label)
		# This models a click on the verified visible button. If production wiring
		# breaks, World will stay in battle and fail the observable handoff check.
		battle.tutorial_continue_btn.emit_signal("pressed")
		deadline = Time.get_ticks_msec() + TIMEOUT_MS
		while Time.get_ticks_msec() < deadline and world.battle != null:
			await process_frame
		_expect(world.battle == null and not world.battling,
			"%s QTE HANDOFF: visible Continue did not return control to World" % label)
		_expect(world.route != null and world.route.objective_id == "shallow_angler",
			"%s QTE HANDOFF: World did not expose the Shallows objective after Continue" % label)

	if is_instance_valid(world):
		world.queue_free()
	await process_frame

func _check_post_qte_layout(battle: Battle, viewport: Vector2, label: String) -> void:
	await process_frame
	await process_frame
	var screen := Rect2(Vector2.ZERO, viewport)
	print("%s QTE layout: panel min=%s rect=%s caption=%s levelup=%s" % [
		label, battle._bottom_panel.get_combined_minimum_size(), battle._bottom_panel.get_global_rect(),
		battle._tutorial_caption.get_global_rect(), battle._levelup_caption.get_global_rect(),
	])
	var button_rect := battle.tutorial_continue_btn.get_global_rect()
	_expect(battle.tutorial_continue_btn.visible and not battle.tutorial_continue_btn.disabled,
		"%s QTE HANDOFF: Continue is hidden or disabled while acknowledgement is required" % label)
	_expect(screen.encloses(button_rect),
		"%s QTE HANDOFF: Continue is outside viewport (%s in %s)" % [label, button_rect, screen])
	_expect(battle._tutorial_caption.visible and battle._tutorial_caption.text.contains("Click Continue or press Enter"),
		"%s QTE HANDOFF: required acknowledgement has no visible instruction" % label)
	_expect(battle._stage_container.size.y >= MIN_STAGE_HEIGHT,
		"%s QTE HANDOFF: battle stage collapsed to %.1fpx under tutorial UI" % [label, battle._stage_container.size.y])
	var stage_rect := battle._stage_container.get_global_rect()
	_expect(screen.encloses(stage_rect) and stage_rect.size.y >= MIN_STAGE_HEIGHT,
		"%s QTE HANDOFF: stage is clipped or too short (%s)" % [label, stage_rect])
	if battle._levelup_caption.visible:
		_expect(screen.encloses(battle._levelup_caption.get_global_rect()),
			"%s QTE HANDOFF: mandatory level-up information is clipped" % label)
	for entry_value in battle.party:
		var entry := entry_value as Dictionary
		var actor := entry.get("actor") as Node3D
		_expect(actor != null and actor.visible,
			"%s QTE HANDOFF: active battle actor disappeared behind a blank stage" % label)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
