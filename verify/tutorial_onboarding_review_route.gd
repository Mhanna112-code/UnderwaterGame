# `tutorial onboarding review route: query-only title action opens the real
# controls walkthrough — guards against inaccessible visual evidence`.
#
# The browser URL itself is exercised manually because JavaScriptBridge is a
# web-only API. This checks the durable part of the route: the title action
# World wires for that URL reaches the real overlay without starting a battle,
# saving a game, or changing the ordinary title surface.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.enable_onboarding_playtest()
	world.title_screen.open()
	await process_frame
	var review_button := _button_named(world.title_screen, "Review World Controls")
	_expect(review_button != null, "ONBOARDING REVIEW ROUTE: title did not expose the query-only review action")
	if review_button != null:
		review_button.emit_signal("pressed")
		await process_frame
	_expect(not world.title_screen.visible, "ONBOARDING REVIEW ROUTE: title stayed open over the walkthrough")
	_expect(world.ability_onboarding.visible, "ONBOARDING REVIEW ROUTE: action did not open the real walkthrough")
	_expect(world.battle == null, "ONBOARDING REVIEW ROUTE: visual review unexpectedly started combat")
	_expect(world._current_slot == -1, "ONBOARDING REVIEW ROUTE: visual review created or selected a save slot")
	_expect(world.banner.text.is_empty(), "ONBOARDING REVIEW ROUTE: stale intro-beacon instruction remained behind the walkthrough")
	_expect(paused, "ONBOARDING REVIEW ROUTE: walkthrough did not pause world input")
	world.ability_onboarding.call("dismiss")
	await process_frame
	_expect(not paused, "ONBOARDING REVIEW ROUTE: closing walkthrough left review world paused")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial onboarding route  title action opens the exact review UI without combat or saves")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _button_named(root_node: Node, text: String) -> Button:
	for candidate in root_node.find_children("*", "Button", true, false):
		if candidate is Button and (candidate as Button).text == text:
			return candidate as Button
	return null

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
