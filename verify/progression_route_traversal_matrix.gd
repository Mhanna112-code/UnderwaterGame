# `progression route: every authored beat is physically reachable from the
# prior beat and two lateral approaches — guards against close beacons,
# synthetic-trigger coverage, and invisible route blockers`.
#
# This never emits Area3D.body_entered, calls World._on_route_triggered(), or
# teleports a diver to a target. Each case starts a normal World, places the
# diver at the prior beat (or one of its real lateral approach offsets), and
# drives the production `scripted_dir` movement through physics until the live
# route trigger creates its Battle.
extends SceneTree

const MIN_NOMINAL_TRAVEL_SECONDS := 8.0
const MAX_NOMINAL_TRAVEL_SECONDS := 12.0
const APPROACH_OFFSETS := [-1.0, 0.0, 1.0]
const LATERAL_OFFSET_METERS := 5.0
const TIMEOUT_REAL_MS := 8000
const FIRST_BEAT := 0
const MAX_BEATS := 7

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Simulation speed only makes the verifier practical; every movement step
	# still runs through Diver.swim() / move_and_slide() with live collision.
	Engine.time_scale = 8.0
	print("ROUTE TRAVERSAL MATRIX: exercising beats %d–%d through fresh live worlds" % [
		FIRST_BEAT + 1, mini(RouteProgression.BEATS.size(), FIRST_BEAT + MAX_BEATS),
	])
	for beat_index in range(FIRST_BEAT, mini(RouteProgression.BEATS.size(), FIRST_BEAT + MAX_BEATS)):
		_check_nominal_spacing(beat_index)
		for approach in APPROACH_OFFSETS:
			print("ROUTE TRAVERSAL MATRIX: %s / %s" % [
				String((RouteProgression.BEATS[beat_index] as Dictionary).id),
				"center" if is_zero_approx(approach) else ("left" if approach < 0.0 else "right"),
			])
			await _exercise_live_leg(beat_index, approach)
	Engine.time_scale = 1.0
	for finding in findings:
		push_error(finding)
	print("ROUTE TRAVERSAL MATRIX: clean across %d beat(s) and %d physical approaches" % [
		mini(RouteProgression.BEATS.size(), FIRST_BEAT + MAX_BEATS) - FIRST_BEAT, APPROACH_OFFSETS.size()
	] if findings.is_empty() else "ROUTE TRAVERSAL MATRIX: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _check_nominal_spacing(beat_index: int) -> void:
	var beat := RouteProgression.BEATS[beat_index] as Dictionary
	var origin := _prior_position(beat_index)
	var target := beat.at as Vector3
	var distance := _horizontal_distance(origin, target)
	var seconds := distance / (Diver.new().speed)
	_expect(seconds >= MIN_NOMINAL_TRAVEL_SECONDS and seconds <= MAX_NOMINAL_TRAVEL_SECONDS,
		"ROUTE PACING: %s is %.1fm / %.1fs from its prior beat; expected %.0f–%.0fs at ordinary swim speed" % [
			String(beat.id), distance, seconds, MIN_NOMINAL_TRAVEL_SECONDS, MAX_NOMINAL_TRAVEL_SECONDS,
		])

func _exercise_live_leg(beat_index: int, approach: float) -> void:
	var beat := RouteProgression.BEATS[beat_index] as Dictionary
	var origin := _prior_position(beat_index)
	var target := beat.at as Vector3
	var travel := target - origin
	travel.y = 0.0
	var side := Vector3(-travel.z, 0.0, travel.x).normalized() * approach * LATERAL_OFFSET_METERS

	# Each approach has its own ordinary World. That is deliberate: a failed
	# encounter leaves its retry trigger live in production, so reusing a world
	# can accidentally test a queued overlap from the *previous* approach
	# rather than this swimmer's collision. A fresh World keeps all three paths
	# literal without giving the verifier a test-only cleanup privilege.
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world._intro_active = false
	var player := world.divers[world.active] as Diver
	# Put the swimmer at the prior route beat before the active Area exists;
	# this is route-leg setup, never a target teleport.
	player.global_position = origin + side
	player.velocity = Vector3.ZERO
	player.force_update_transform()
	world._begin_core_route_after_tutorial()
	# Restore only the public route state necessary to make THIS beat active.
	# The player begins at its prior beat and physically swims from there; the
	# target itself is never assigned to the diver or signalled by the test.
	world.route.restore_state({"beat_index": beat_index})
	if world.route_transition_card != null:
		world.route_transition_card.dismiss()
	await physics_frame
	target = world.route.active_position()

	var is_preview := bool(beat.get("preview", false))
	var deadline := Time.get_ticks_msec() + TIMEOUT_REAL_MS
	var arrived := false
	while not arrived and Time.get_ticks_msec() < deadline:
		var toward := target - player.global_position
		toward.y = 0.0
		world.scripted = true
		world.scripted_dir = toward.normalized() if toward.length_squared() > 0.01 else Vector3.ZERO
		await physics_frame
		arrived = (world.route_transition_card != null and world.route_transition_card.visible) if is_preview else world.battle != null
	world.scripted = false
	world.scripted_dir = Vector3.ZERO

	var approach_label := "center" if is_zero_approx(approach) else ("left" if approach < 0.0 else "right")
	print("ROUTE TRAVERSAL MATRIX: %s / %s completed with battle=%s preview=%s, distance=%.2f" % [
		String(beat.id), approach_label, world.battle != null, is_preview,
		_horizontal_distance(player.global_position, target),
	])
	if is_preview:
		_expect(world.battle == null and world.route.phase == RouteProgression.PHASE_COMPLETE and world.route_transition_card.visible and world.route_transition_card.body_text().contains("no boss fight begins"),
			"ROUTE BOUNDARY: %s from %s approach did not reach the explicit no-boss preview" % [String(beat.id), approach_label])
		_expect(_sonar_was_not_needed(world),
			"ROUTE SONAR: %s from %s approach required or activated sonar on the critical path" % [String(beat.id), approach_label])
		world.queue_free()
		await process_frame
		return
	_expect(world.battle != null,
		"ROUTE REACHABILITY: %s from %s approach could not reach its live beacon trigger (player %s, target %s, %.1fm away)" % [
			String(beat.id), approach_label, player.global_position, target,
			_horizontal_distance(player.global_position, target),
		])
	if world.battle != null:
		_expect(_enemy_ids(world.battle) == (beat.roster as Array),
			"ROUTE ROSTER: %s from %s approach opened %s instead of %s" % [
				String(beat.id), approach_label, _enemy_ids(world.battle), beat.roster,
			])
	_expect(_sonar_was_not_needed(world),
		"ROUTE SONAR: %s from %s approach required or activated sonar on the critical path" % [String(beat.id), approach_label])
	world.queue_free()
	await process_frame

func _sonar_was_not_needed(world: World) -> bool:
	for diver_value in world.divers:
		if (diver_value as Diver).sonar_active:
			return false
	return true

func _prior_position(beat_index: int) -> Vector3:
	if beat_index <= 0:
		return (World.CAST[0] as Dictionary).at as Vector3
	return (RouteProgression.BEATS[beat_index - 1] as Dictionary).at as Vector3

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _enemy_ids(battle: Battle) -> Array[String]:
	var out: Array[String] = []
	for entry in battle.enemies:
		var actor := (entry as Dictionary).get("actor") as Node3D
		if actor is Goblin:
			out.append((actor as Goblin).enemy_id())
		elif actor is TethysBoss:
			out.append("tethys")
	return out

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
