# `progression route: a completed tutorial exposes the one shallow objective,
# dismisses its short handoff card, rejects an ordinary roll, and starts the
# authored Angler — guards against a post-tutorial soft lock or random route`.
#
# The former automatic multi-page ability modal is intentionally not the
# first-free-play handoff anymore: it blocked movement before the player saw
# the beacon. F1 still exposes that reference material; this gate protects
# the new playable route instead.
extends SceneTree

# A complete live win includes staged attack/death animation, one ordinary log
# beat, the three party XP lines, and the explicit victory Continue. The old
# 9-second ceiling only covered the start of that real presentation.
const TIMEOUT_MS := 20000
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world._start_battle("", false, "angler", world.divers, false, true)
	await process_frame
	var battle: Battle = world.battle
	if battle == null:
		findings.append("ROUTE HANDOFF START: no tutorial battle was created")
	else:
		# The opening teaches the visual Quick Read with one safe action.  A
		# longer forced script would contradict the route brief by making full
		# move/formula instruction mandatory before free exploration.
		_expect(battle._TUTORIAL_SCRIPT.size() == 1,
			"TUTORIAL SCOPE: opening lesson must contain one forced quick-read move, not a multi-move lecture")
		if battle._TUTORIAL_SCRIPT.size() == 1:
			var lesson := battle._TUTORIAL_SCRIPT[0] as Dictionary
			_expect(int(lesson.get("party_index", -1)) == 0 and String(lesson.get("move", "")) == "Electric Touch",
				"TUTORIAL SCOPE: opening quick-read move must remain Maxilani's Electric Touch")
		# The old check set the enemy HP to zero and jumped straight to
		# _advance_turn(), which only proved an already-finished battle's
		# callback. Keep the production Angler intact, then use its actual
		# Continue button, highlighted move button, hover signal, target button,
		# CombatRules resolution, live QTE, Battle victory path and World
		# finished signal. This is the whole tutorial contract, not a fake win.
		var completed := await _complete_live_quick_read(battle, world)
		if not completed:
			findings.append("ROUTE HANDOFF: live quick-read choice did not resolve into the World handoff")
		elif world.battle != null:
			findings.append("ROUTE HANDOFF: completed tutorial left Battle mounted")
		else:
			await _verify_handoff(world)

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial route handoff  completed lesson opened one safe authored objective")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

# Uses the visible controls rather than direct battle helpers. `emit_signal`
# delivers the exact Button signal a mouse click does; the target hover is
# deliberately part of the route because it is where the Quick Read's live
# green/red result appears. The tutorial owns exactly one Angler turn after
# that choice, then ends through the normal Battle victory wiring; the first
# route Angler is the first full combat challenge.
func _complete_live_quick_read(battle: Battle, world: World) -> bool:
	if not await _wait_for("TUTORIAL CARD", func() -> bool: return battle._tutorial_awaiting_enter and battle.tutorial_continue_btn.visible):
		return false
	battle.tutorial_continue_btn.emit_signal("pressed")
	if not await _wait_for("HIGHLIGHTED MOVE", func() -> bool:
		return not battle.move_buttons.is_empty() and not (battle.move_buttons[0] as Button).disabled):
		return false
	var move_btn := battle.move_buttons[0] as Button
	_expect(move_btn.text.begins_with("Electric Touch"), "TUTORIAL CHOICE: the only enabled move is not Electric Touch")
	move_btn.emit_signal("pressed")
	if not await _wait_for("HIGHLIGHTED TARGET", func() -> bool: return not battle.target_buttons.is_empty()):
		return false
	var target_btn := battle.target_buttons[0] as Button
	# This is the same signal `_show_stat_preview` and the tutorial await use
	# in production. It demonstrates that the comparison gate is real before
	# the choice becomes available.
	target_btn.emit_signal("mouse_entered")
	if not await _wait_for("QUICK-READ PREVIEW", func() -> bool: return not target_btn.disabled):
		return false
	_expect(battle._stat_preview_frozen, "TUTORIAL PREVIEW: target hover did not hold the live comparison")
	target_btn.emit_signal("pressed")
	return await _finish_live_tutorial(battle, world)

# The real victory panel deliberately waits for an explicit Continue before
# handing control back. Press the same rendered button rather than clearing a
# private await flag, so a stale overlay or a disconnected button is caught.
func _finish_live_tutorial(battle: Battle, world: World) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	var victory_continue_seen := false
	var qte_instruction_seen := false
	while Time.get_ticks_msec() < deadline:
		if world.battle == null:
			if not qte_instruction_seen:
				findings.append("TUTORIAL ORDER: the guided move did not lead directly to the live QTE")
			return victory_continue_seen
		if battle._tutorial_awaiting_enter and battle.tutorial_continue_btn.visible:
			if battle._tutorial_qte_detail.visible:
				qte_instruction_seen = true
				_expect(String(battle._acting.get("kind", "")) == "enemy",
					"TUTORIAL ORDER: a party turn appeared before the promised Angler QTE")
			# The QTE explanation and the short post-victory confirmation both
			# use the same real button. Count only the latter as proof that the
			# player actually saw the tutorial's completion state.
			victory_continue_seen = victory_continue_seen or battle._tutorial_caption.text.begins_with("Practice complete")
			battle.tutorial_continue_btn.emit_signal("pressed")
		await process_frame
	if not victory_continue_seen:
		findings.append("TUTORIAL VICTORY: no visible Continue appeared before timeout")
	else:
		findings.append("WORLD HANDOFF: timed out after live tutorial victory Continue")
	return false

func _wait_for(label: String, predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	findings.append("%s: timed out" % label)
	return false

func _verify_handoff(world: World) -> void:
	_expect(world.route != null and world.route.objective_id == "shallow_angler",
		"TUTORIAL HANDOFF: no active Shallows Angler objective after the lesson")
	_expect(world.route != null and world.route.objective_text == "Shallows — follow the beacon.",
		"TUTORIAL HANDOFF: first player-facing objective drifted")
	_expect(world.route_objective_label.visible,
		"TUTORIAL HANDOFF: sole route objective is not visibly displayed in the world")
	_expect(not world.hud.get_global_rect().intersects(world.route_objective_panel.get_global_rect()),
		"TUTORIAL HANDOFF: route objective overlaps the persistent world-controls hint")
	_expect(world.route_transition_card.visible and paused,
		"TUTORIAL HANDOFF: the short Continue card did not guard the initial handoff")
	var handoff_copy := world.route_transition_card.body_text()
	_expect(handoff_copy.contains("red on an enemy creates an opening"),
		"TUTORIAL HANDOFF: route card contradicted the Quick Read's side-specific color guidance: %s" % handoff_copy)
	if not findings.is_empty():
		return
	world.route_transition_card.dismiss()
	await process_frame
	_expect(not paused and not world.battling,
		"TRANSITION DISMISS: Continue did not return control to the world")
	# Headless viewports are intentionally 64px wide, so production correctly
	# declines to draw the cosmetic arrow there. Exercise its public placement
	# seam at a real 1280×720 review size instead: a top-centre cue that would
	# have crossed the objective must move into a clear slot.
	world.route_direction_label.text = "↑ Beacon"
	var arrow_size := world.route_direction_label.get_combined_minimum_size()
	var arrow_position := world.route_direction_label_position(
		Vector2(604.0, 72.0), arrow_size, Vector2.UP, Vector2(1280.0, 720.0))
	var arrow_rect := Rect2(arrow_position, arrow_size)
	_expect(not arrow_rect.intersects(world.hud.get_global_rect()),
		"ROUTE GUIDANCE: off-screen Beacon arrow overlaps world controls")
	_expect(not arrow_rect.intersects(world.route_objective_panel.get_global_rect()),
		"ROUTE GUIDANCE: off-screen Beacon arrow overlaps the route objective")

	var d := world.divers[world.active] as Diver
	d.encounter_triggered.emit()
	await process_frame
	_expect(world.battle == null,
		"ROUTE SAFETY: an ordinary distance roll interrupted the authored shallow path")

	world._on_route_triggered(d)
	await process_frame
	await process_frame
	_expect(world.battle != null,
		"AUTHORED DISPATCH: arriving at the active beacon did not begin combat")
	if world.battle != null:
		_expect(world.battle.enemies.size() == 1,
			"AUTHORED DISPATCH: shallow Angler did not stay a single-enemy fight")
		if not world.battle.enemies.is_empty():
			var actor := (world.battle.enemies[0] as Dictionary).actor as Goblin
			_expect(actor != null and actor.enemy_id() == "angler",
				"AUTHORED DISPATCH: shallow route built the wrong enemy")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
