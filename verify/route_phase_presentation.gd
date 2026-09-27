# `progression route: Deep water changes the live environment and follows a
# lateral route — guards against a cosmetic phase label on an empty ruler line`.
extends SceneTree

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
	world._intro_active = false
	world._begin_core_route_after_tutorial()
	if world.route_transition_card != null:
		world.route_transition_card.dismiss()
	await process_frame
	var shallow := world.route_phase_presentation()
	_expect(not bool(shallow.landmarks_visible) and float(shallow.fog_density) <= 0.04,
		"ROUTE PRESENTATION: Shallows started with Deep landmarks/fog %s" % shallow)

	# Advance the public route state through the complete Shallows. The World
	# listens to its phase signal, so no private environment mutator is called.
	for _i in 3:
		world.route.begin_active_encounter()
		world.route.resolve_active_encounter("won")
	var deep := world.route_phase_presentation()
	_expect(world.route.phase == RouteProgression.PHASE_DEEP,
		"ROUTE PRESENTATION: shallow capstone did not enter Deep water")
	_expect(bool(deep.landmarks_visible) and float(deep.fog_density) >= 0.055 and float(deep.ambient_energy) < float(shallow.ambient_energy),
		"ROUTE PRESENTATION: Deep water did not darken/show landmarks (%s -> %s)" % [shallow, deep])

	var signed_turns: Array[float] = []
	for index in range(1, RouteProgression.BEATS.size() - 1):
		var previous := (RouteProgression.BEATS[index - 1] as Dictionary).at as Vector3
		var current := (RouteProgression.BEATS[index] as Dictionary).at as Vector3
		var following := (RouteProgression.BEATS[index + 1] as Dictionary).at as Vector3
		var a := Vector2(current.x - previous.x, current.z - previous.z)
		var b := Vector2(following.x - current.x, following.z - current.z)
		signed_turns.append(a.x * b.y - a.y * b.x)
	_expect(signed_turns.any(func(turn: float) -> bool: return absf(turn) > 250.0),
		"ROUTE PRESENTATION: route positions remain effectively collinear: %s" % [signed_turns])

	world.queue_free()
	for finding in findings:
		push_error(finding)
	print("ROUTE PHASE PRESENTATION: clean" if findings.is_empty() else "ROUTE PHASE PRESENTATION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
