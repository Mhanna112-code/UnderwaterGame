# `playtest repair: every live route transition keeps its title, body,
# optional Help, and Continue control inside a browser viewport — guards
# against a long handoff card becoming another hidden-button soft lock`.
#
# MUST run windowed at both review sizes:
#   godot --path . --resolution 1280x720 --script verify/route_transition_layout.gd
#   godot --path . --resolution 1920x1080 --script verify/route_transition_layout.gd
extends SceneTree

const SETTLE_FRAMES := 8
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	if screen.size.x < 1000.0 or screen.size.y < 600.0:
		findings.append("ROUTE TRANSITION LAYOUT requires a browser-sized window, got %s" % screen.size)
		_report()
		return
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.new_game_chosen.emit(12)
	await process_frame
	world._intro_active = false
	world._begin_core_route_after_tutorial()
	await _assert_card(world, screen, "Shallows handoff", true)
	world.route_transition_card.dismiss()

	# These cards are reached by World's real battle-finished handler. The
	# lightweight Battle object only supplies that public callback boundary; the
	# test does not call a card-specific text/layout helper to fake a route win.
	await _route_win_to_card(world, 2, "shallow_capstone")
	await _assert_card(world, screen, "Deep descent", true)
	world.route_transition_card.dismiss()
	await _route_win_to_card(world, 3, "deep_swordfish")
	await _assert_card(world, screen, "Sea Urchin counter", true)
	world.route_transition_card.dismiss()
	await _route_win_to_card(world, 5, "deep_capstone")
	await _assert_card(world, screen, "Drowned lab approach", false)
	world.route_transition_card.dismiss()

	# The final beat is deliberately a no-boss preview. Enter it through the
	# same World trigger that a physical route arrival invokes.
	world.route.restore_state({"beat_index": 6, "checkpoint_id": "deep_capstone"})
	var player := world.divers[world.active] as Diver
	world._route_trigger.body_entered.emit(player)
	await _assert_card(world, screen, "Mermaid Freak preview", false)
	_expect(world.battle == null, "MERMAID PREVIEW LAYOUT: final route card unexpectedly created a battle")
	world.route_transition_card.dismiss()

	world.queue_free()
	await process_frame
	_report()

func _route_win_to_card(world: World, beat_index: int, beat_id: String) -> void:
	world.route.restore_state({"beat_index": beat_index})
	var encounter := world.route.begin_active_encounter()
	_expect(String(encounter.get("id", "")) == beat_id,
		"ROUTE TRANSITION SETUP: expected %s, got %s" % [beat_id, encounter.get("id", "")])
	world._route_battle_id = beat_id
	world.battling = true
	world.battle = Battle.new()
	world._on_battle_finished("won")
	await process_frame

func _assert_card(world: World, screen: Rect2, label: String, expect_help: bool) -> void:
	for _i in SETTLE_FRAMES:
		await process_frame
	var card := world.route_transition_card
	_expect(card.visible and paused, "%s: route transition is not visibly modal" % label)
	var rects := card.visible_rects()
	var panel := rects.get("panel", Rect2()) as Rect2
	var title := rects.get("title", Rect2()) as Rect2
	var body := rects.get("body", Rect2()) as Rect2
	var help := rects.get("help", Rect2()) as Rect2
	var continue_rect := rects.get("continue", Rect2()) as Rect2
	print("%s layout: panel=%s title=%s body=%s help=%s continue=%s" % [label, panel, title, body, help, continue_rect])
	_expect(screen.encloses(panel), "%s: card panel is clipped (%s in %s)" % [label, panel, screen])
	_expect(screen.encloses(title) and screen.encloses(body) and screen.encloses(continue_rect),
		"%s: required title/body/Continue is clipped" % label)
	_expect(continue_rect.size.y > 20.0 and continue_rect.position.y >= body.end.y - 1.0,
		"%s: Continue is collapsed or overlaps the transition body" % label)
	if expect_help:
		_expect(help.size.y > 20.0 and screen.encloses(help) and help.position.y >= body.end.y - 1.0 and continue_rect.position.y >= help.end.y - 1.0,
			"%s: optional Combat Help is clipped or overlaps body/Continue" % label)
	else:
		_expect(help.size == Vector2.ZERO, "%s: unexpected Combat Help control changed the intended transition" % label)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _report() -> void:
	for finding in findings:
		push_error(finding)
	print("ROUTE TRANSITION LAYOUT: clean" if findings.is_empty() else "ROUTE TRANSITION LAYOUT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
