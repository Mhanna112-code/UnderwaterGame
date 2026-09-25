# `progression route: drive the mounted World -> Battle -> World lifecycle
# through every authored beat -- guards against a route that unit tests can
# describe but whose real battle completion signal fails to advance/save`.
extends SceneTree

const TIMEOUT_MS := 40000
var findings: Array[String] = []
var seen_rosters: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := await _make_world()
	# The tutorial itself has dedicated victory/skip/QTE gates. This test owns
	# what follows it: start the real production handoff then use its actual
	# Area3D signal to dispatch every staged battle.
	world._intro_active = false
	world._begin_core_route_after_tutorial()
	_expect(world.route_transition_card.visible and paused,
		"PLAYTHROUGH START: tutorial handoff did not show its Continue card")
	world.route_transition_card.dismiss()
	await process_frame

	var expected := [
		["angler"], ["frilled_shark"], ["angler", "frilled_shark"],
		["swordfish_duelist"], ["sea_urchin"],
		["swordfish_duelist", "sea_urchin"],
	]
	for index in range(RouteProgression.BEATS.size()):
		if world.route.objective_id == "":
			findings.append("PLAYTHROUGH %d: route completed before its expected encounter" % index)
			break
		var player := world.divers[world.active] as Diver
		# Protected route space must never turn the synthetic distance roll into
		# an ordinary fight immediately before the authored arrival.
		player.encounter_triggered.emit()
		await process_frame
		_expect(world.battle == null, "PLAYTHROUGH %d: a random encounter interrupted the protected route" % index)

		# Damage the party before each capstone. The production trigger must
		# restore both resources before the fight, and the victory handler must
		# persist that same safe recovery after it.
		var capstone := world.route.is_capstone()
		if capstone:
			for diver_value in world.divers:
				var stats := (diver_value as Diver).stats
				stats.hp = 1
				stats.oxygen = 0.0
		world._route_trigger.body_entered.emit(player)
		await process_frame
		await process_frame
		var beat := RouteProgression.BEATS[index] as Dictionary
		if bool(beat.get("preview", false)):
			_expect(world.battle == null and world.route.phase == RouteProgression.PHASE_COMPLETE and world.route_transition_card.visible and world.route_transition_card.body_text().contains("no boss fight begins"),
				"PLAYTHROUGH %d: Mermaid Freak preview created a battle or lacked its no-boss boundary card" % index)
			world.route_transition_card.dismiss()
			await process_frame
			continue
		if world.battle == null:
			findings.append("PLAYTHROUGH %d: reaching the live beacon did not create a Battle" % index)
			break
		var actual: Array[String] = []
		for entry_value in world.battle.enemies:
			var actor: Variant = (entry_value as Dictionary).get("actor")
			if actor is TethysBoss:
				actual.append("tethys")
			elif actor is Goblin:
				actual.append((actor as Goblin).enemy_id())
			else:
				actual.append("missing")
		seen_rosters.append("+".join(actual))
		_expect(actual == expected[index],
			"PLAYTHROUGH %d: expected %s, built %s" % [index, expected[index], actual])
		if capstone:
			_expect(_party_is_full(world),
				"PLAYTHROUGH %d: capstone did not start with full HP/O2" % index)

		# _win() is the production victory path: it awards XP, animates/recover
		# state, emits Battle.finished, lets World advance the route, handles the
		# checkpoint write and opens any required transition card.
		var battle := world.battle
		await battle._win()
		var deadline := Time.get_ticks_msec() + TIMEOUT_MS
		while world.battle != null and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect(world.battle == null and not world.battling,
			"PLAYTHROUGH %d: Battle victory did not return to World" % index)
		if capstone:
			_expect(_party_is_full(world),
				"PLAYTHROUGH %d: capstone victory did not leave full HP/O2" % index)
		if world.route_transition_card.visible:
			world.route_transition_card.dismiss()
			await process_frame
			_expect(not paused, "PLAYTHROUGH %d: transition Continue did not restore control" % index)

	_expect(world.route.phase == RouteProgression.PHASE_COMPLETE and world.route.objective_id == "",
		"PLAYTHROUGH END: Mermaid Freak preview did not complete the playable route")
	_expect(seen_rosters == [
		"angler", "frilled_shark", "angler+frilled_shark", "swordfish_duelist",
		"sea_urchin", "swordfish_duelist+sea_urchin",
	], "PLAYTHROUGH ORDER: real battle lifecycle diverged from the declared route")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("progression playthrough  full authored World/Battle route clean: %s" % [seen_rosters])
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _make_world() -> World:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	return world

func _party_is_full(world: World) -> bool:
	for diver_value in world.divers:
		var stats := (diver_value as Diver).stats
		if stats.hp != stats.hp_max or not is_equal_approx(stats.oxygen, stats.oxygen_max):
			return false
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
