# `tutorial ability onboarding: a completed lesson opens world-control pages
# — guards against missing first-free-play handoff`.
#
# This drives the real Battle.finished -> World handoff, then speaks only to
# the public AbilityOnboarding actions. It intentionally does not call a
# private World helper to manufacture the overlay: the regression was that a
# player could complete the first lesson and never receive it.
extends SceneTree

const TIMEOUT_MS := 9000

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
		findings.append("TUTORIAL ONBOARDING START: no tutorial battle was created")
	else:
		# Complete the actual tutorial's final combat condition, following the
		# same route as tutorial_exit.gd rather than invoking onboarding directly.
		for enemy_entry in battle.enemies:
			(enemy_entry.stats as CombatantStats).hp = 0
		battle._tutorial_step = battle._TUTORIAL_SCRIPT.size()
		battle._tutorial_enemy_turns = 1
		battle._tutorial_finale_shown = false
		battle._qte_active = false
		battle._advance_turn()
		var deadline := Time.get_ticks_msec() + TIMEOUT_MS
		while world.battle != null and Time.get_ticks_msec() < deadline:
			if world.battle._tutorial_awaiting_enter:
				world.battle._tutorial_awaiting_enter = false
			await process_frame
		if world.battle != null:
			findings.append("TUTORIAL ONBOARDING: completed lesson left Battle mounted")
		else:
			await _verify_handoff(world)

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial ability onboarding  completed lesson opened and dismissed the world-control walkthrough cleanly")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _verify_handoff(world: World) -> void:
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	var onboarding: Node = null
	while onboarding == null and Time.get_ticks_msec() < deadline:
		onboarding = world.title_layer.find_child("AbilityOnboarding", true, false)
		if onboarding == null:
			await process_frame
	if onboarding == null:
		findings.append("MISSING FIRST-FREE-PLAY HANDOFF: tutorial win returned to world without ability onboarding")
		return
	_expect(onboarding.has_method("advance_page"), "ONBOARDING API: no advance action")
	_expect(onboarding.has_method("go_back"), "ONBOARDING API: no back action")
	_expect(onboarding.has_method("dismiss"), "ONBOARDING API: no dismiss action")
	_expect(onboarding.has_method("current_page_data"), "ONBOARDING API: no page data")
	_expect(onboarding.visible, "ONBOARDING VISIBILITY: handoff created a hidden walkthrough")
	_expect(paused, "ONBOARDING PAUSE: the world stayed live beneath the walkthrough")
	if not findings.is_empty():
		return

	var expected_pages := [
		{"id": "world-controls", "ability": "", "passive": "", "aim": false},
		{"id": "swap-sonar", "ability": "swap", "passive": "sonar", "aim": false},
		{"id": "grapple", "ability": "grapple", "passive": "", "aim": true},
		{"id": "shockwave", "ability": "shockwave", "passive": "", "aim": false},
	]
	for index in range(expected_pages.size()):
		var expected: Dictionary = expected_pages[index]
		var page: Dictionary = onboarding.call("current_page_data") as Dictionary
		_expect(String(page.get("id", "")) == String(expected.id), "ONBOARDING PAGE %d: expected %s, got %s" % [index + 1, String(expected.id), String(page.get("id", ""))])
		_expect(not String(page.get("title", "")).is_empty(), "ONBOARDING PAGE %d: no readable title" % [index + 1])
		_expect(String(page.get("ability_id", "")) == String(expected.ability), "ONBOARDING PAGE %d: ability metadata does not match the live lesson" % [index + 1])
		_expect(String(page.get("passive_id", "")) == String(expected.passive), "ONBOARDING PAGE %d: passive metadata does not match the live lesson" % [index + 1])
		_expect(bool(page.get("requires_aim", false)) == bool(expected.aim), "ONBOARDING PAGE %d: aim instruction does not match the live lesson" % [index + 1])
		if index == 0:
			_expect(bool(page.get("back_enabled", true)) == false, "ONBOARDING FIRST PAGE: Back should be disabled")
		if String(expected.ability) != "":
			var diver: Diver = _diver_with_ability(world, String(expected.ability))
			_expect(diver != null, "ONBOARDING PAGE %d: no live diver has ability %s" % [index + 1, String(expected.ability)])
			if diver != null:
				var old_oxygen := diver.stats.oxygen
				diver.stats.oxygen = 0.0
				_expect(diver.can_use_ability(), "ONBOARDING PAGE %d: environmental ability was unavailable at zero oxygen" % [index + 1])
				diver.stats.oxygen = old_oxygen
		if index < expected_pages.size() - 1:
			onboarding.call("advance_page")
			await process_frame
	var final_page: Dictionary = onboarding.call("current_page_data") as Dictionary
	_expect(bool(final_page.get("next_enabled", true)) == false, "ONBOARDING FINAL PAGE: Next should not lead to a blank page")
	onboarding.call("go_back")
	await process_frame
	var previous_page: Dictionary = onboarding.call("current_page_data") as Dictionary
	_expect(String(previous_page.get("id", "")) == "grapple", "ONBOARDING BACK: Back did not restore the preceding lesson")
	onboarding.call("dismiss")
	await process_frame
	_expect(not onboarding.visible, "ONBOARDING DISMISS: walkthrough stayed visible")
	_expect(not paused, "ONBOARDING DISMISS: world remained paused")
	_expect(not world.battling and world._first_encounter_done, "ONBOARDING DISMISS: world did not return to playable post-tutorial state")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _diver_with_ability(world: World, ability_id: String) -> Diver:
	for member in world.divers:
		if member is Diver and String((member as Diver).ability_id) == ability_id:
			return member as Diver
	return null
