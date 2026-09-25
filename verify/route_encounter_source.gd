# `progression route: every battle visibly names its authored or optional
# source — guards against an Angler report that cannot be tied to a route beat`.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for beat_index in range(RouteProgression.BEATS.size()):
		var world := await _make_world()
		world._intro_active = false
		world._begin_core_route_after_tutorial()
		world.route.restore_state({"beat_index": beat_index})
		if world.route_transition_card != null:
			world.route_transition_card.dismiss()
		var player := world.divers[world.active] as Diver
		world._route_trigger.body_entered.emit(player)
		await process_frame
		var beat := RouteProgression.BEATS[beat_index] as Dictionary
		if bool(beat.get("preview", false)):
			_expect(world.battle == null,
				"BOSS BOUNDARY: %s preview unexpectedly opened a mandatory Battle" % String(beat.id))
			_expect(world.route.phase == RouteProgression.PHASE_COMPLETE and world.route_transition_card.visible and world.route_transition_card.body_text().contains("no boss fight begins"),
				"BOSS BOUNDARY: %s did not show an explicit no-fight preview handoff" % String(beat.id))
			world.queue_free()
			await process_frame
			continue
		_expect(world.battle != null,
			"ENCOUNTER SOURCE: %s did not open a battle through World" % String(beat.id))
		if world.battle != null:
			var expected_source := String(beat.encounter_label)
			if bool(beat.get("capstone", false)):
				expected_source += " • Checkpoint secured — party restored"
			_expect(world.battle.encounter_source == expected_source,
				"ENCOUNTER SOURCE: %s exposed '%s', expected '%s'" % [beat.id, world.battle.encounter_source, expected_source])
			var label := world.battle.get("_encounter_source_label") as Label
			_expect(label != null and label.visible and label.text == expected_source,
				"ENCOUNTER SOURCE: %s has no matching visible source label" % String(beat.id))
		world.queue_free()
		await process_frame

	var ordinary := Battle.new()
	ordinary.encounter_source = "Wandering encounter"
	root.add_child(ordinary)
	await process_frame
	var ordinary_label := ordinary.get("_encounter_source_label") as Label
	_expect(ordinary_label != null and ordinary_label.visible and ordinary_label.text == "Wandering encounter",
		"ENCOUNTER SOURCE: wandering fight did not label itself")
	ordinary.queue_free()

	for finding in findings:
		push_error(finding)
	print("ROUTE ENCOUNTER SOURCE: clean" if findings.is_empty() else "ROUTE ENCOUNTER SOURCE: %d finding(s)" % findings.size())
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

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
