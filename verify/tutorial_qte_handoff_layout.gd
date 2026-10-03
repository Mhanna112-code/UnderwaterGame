# `tutorial QTE handoff layout: a resolved timing window leaves a visible
# stage and Continue action - guards against PR #88's blank post-QTE screen`.
#
# The current tutorial keeps its own curriculum. This test starts at the real
# forced Angler QTE and checks only the reusable layout/interaction boundary.
extends SceneTree

const TIMEOUT_MS := 18000
const MIN_STAGE_HEIGHT := 80.0
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
	if viewport.x < 700.0 or viewport.y < 470.0:
		findings.append("TUTORIAL QTE LAYOUT HARNESS: requires a real review window, got %s" % viewport)
	else:
		await _exercise("success", true, viewport)
		await _exercise("miss", false, viewport)
	for finding in findings:
		push_error(finding)
	print("tutorial QTE handoff layout  success and miss remain visible" if findings.is_empty() else "tutorial QTE handoff layout  FAILED")
	quit(0 if findings.is_empty() else 1)

func _exercise(label: String, hit_zone: bool, viewport: Vector2) -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(98)
	world._first_encounter_started = true
	world._intro_active = false
	world._transitioning_to_encounter = false
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
	world.add_child(battle)

	var qte_seen := false
	var sent_x := false
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline and not (qte_seen and not battle._qte_active):
		if battle._tutorial_awaiting_enter:
			battle._unhandled_input(_key(KEY_ENTER))
		if battle._qte_active:
			qte_seen = true
			if hit_zone and not sent_x and battle.qte_indicator.position.x > 0.0:
				var zone_center := battle.qte_zone.position.x + battle.qte_zone.size.x * 0.5
				battle.qte_indicator.position.x = zone_center - battle.qte_indicator.size.x * 0.5
				battle._unhandled_input(_key(KEY_X))
				sent_x = true
		await process_frame

	_expect(qte_seen, "%s QTE LAYOUT: live timing window never appeared" % label)
	_expect(battle._qte_success == hit_zone,
		"%s QTE LAYOUT: live result did not match the exercised outcome" % label)
	deadline = Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline and not (battle._tutorial_finale_shown and battle._tutorial_awaiting_enter):
		await process_frame
	_expect(battle._tutorial_finale_shown and battle._tutorial_awaiting_enter,
		"%s QTE LAYOUT: result never reached its next visible acknowledgement" % label)
	if battle._tutorial_finale_shown and battle._tutorial_awaiting_enter:
		await process_frame
		await process_frame
		var screen := Rect2(Vector2.ZERO, viewport)
		var button := battle.find_child("TutorialContinue", true, false) as Button
		_expect(button != null and button.visible and not button.disabled,
			"%s QTE LAYOUT: acknowledgement has no usable Continue action" % label)
		if button != null:
			_expect(screen.encloses(button.get_global_rect()),
				"%s QTE LAYOUT: Continue is outside the viewport (%s in %s)" % [label, button.get_global_rect(), screen])
		_expect(battle._tutorial_caption.visible and screen.encloses(battle._tutorial_caption.get_global_rect()),
			"%s QTE LAYOUT: acknowledgement text is hidden or clipped" % label)
		_expect(battle._stage_container.size.y >= MIN_STAGE_HEIGHT,
			"%s QTE LAYOUT: battle stage collapsed to %.1fpx" % [label, battle._stage_container.size.y])

	world.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
