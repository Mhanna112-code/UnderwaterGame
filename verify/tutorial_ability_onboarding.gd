# `tutorial ability onboarding: a completed lesson opens the real paged
# world-control carousel and closes back to playable world state`.
extends SceneTree

const TIMEOUT_MS := 30000
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world._start_battle("", false, "angler", world.divers, false, true)
	await process_frame

	var battle := world.battle as Battle
	if battle == null:
		findings.append("TUTORIAL ONBOARDING START: no tutorial battle was created")
	else:
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
			await _verify_popup(world)

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial ability onboarding  completed lesson opened and dismissed the real ability carousel")
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	quit(0 if findings.is_empty() else 1)

func _verify_popup(world: World) -> void:
	var popup := root.get_node_or_null("CharacterAbilityPopup")
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while popup != null and not _panel_visible(popup) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(popup != null, "MISSING FIRST-FREE-PLAY HANDOFF: CharacterAbilityPopup autoload is absent")
	if popup == null:
		return
	_expect(_panel_visible(popup), "MISSING FIRST-FREE-PLAY HANDOFF: tutorial win did not show the ability carousel")
	_expect(paused, "ONBOARDING PAUSE: the world stayed live beneath the walkthrough")
	var pages := popup.get("_pages") as Array
	var titles: Array[String] = []
	for page_value in pages:
		titles.append(String((page_value as Dictionary).get("title", "")))
	for expected in ["The World Map", "Inventory"]:
		_expect(titles.has(expected), "ONBOARDING PAGE: missing '%s'" % expected)
	_expect(pages.size() == 6, "ONBOARDING PAGE COUNT: expected world, Swap, Sonar, Grapple, Shockwave, Inventory; got %d" % pages.size())
	popup.call("_close")
	await process_frame
	_expect(not _panel_visible(popup), "ONBOARDING DISMISS: walkthrough stayed visible")
	_expect(not paused, "ONBOARDING DISMISS: world remained paused")
	_expect(not world.battling and world._first_encounter_done, "ONBOARDING DISMISS: world did not return to playable post-tutorial state")

func _panel_visible(popup: Node) -> bool:
	var panel := popup.find_child("AbilityExplanationPanel", true, false) as Control
	return panel != null and panel.visible

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
