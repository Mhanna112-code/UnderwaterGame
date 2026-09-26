# `open water: a diver can cross beside the visible highway blockade — guards
# against a collision-only wall that bisects the free-swim world`.
#
# The old highway gate is visibly only the 8 m lane around z=10.  This starts
# a real, production Diver 10 m outside that lane (z=0) and swims it across
# the gate's x-coordinate through `Diver.swim()` / `move_and_slide()`.  It is
# deliberately not a route-beacon test: the player report is about free-world
# movement between party positions, where no visible gate exists.
extends SceneTree

const START := Vector3(8.0, 2.0, 0.0)
const FINISH_X := 22.0
const TIMEOUT_SECONDS := 8.0

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world._on_title_open_water_playtest()
	await process_frame
	# This test owns only the direct production swim.  Stop World's empty-input
	# steering and the tutorial handoff from competing with that movement.
	world.set_physics_process(false)
	var diver := world.divers[world.active] as Diver
	_expect(diver.global_position.is_equal_approx(START),
		"OPEN WATER REVIEW: the review entry did not place the swimmer at its documented start")
	# The review must isolate collision. A random fight while crossing would
	# make a successful physical movement look blocked to the human reviewer.
	diver.encounter_triggered.emit()
	await process_frame
	_expect(world.battle == null,
		"OPEN WATER REVIEW: an ordinary encounter interrupted the dedicated collision check")
	await physics_frame

	var deadline := Time.get_ticks_msec() + int(TIMEOUT_SECONDS * 1000.0)
	while diver.global_position.x < FINISH_X and Time.get_ticks_msec() < deadline:
		diver.swim(Vector3.RIGHT, 0.0, 1.0 / 60.0)
		await physics_frame

	_expect(diver.global_position.x >= FINISH_X,
		"OPEN WATER BLOCKADE: swimming beside the visible highway lane stopped at x=%.2f (needed x>=%.2f); a collision-only gate is cutting the free-swim world" % [
			diver.global_position.x, FINISH_X,
		])

	for finding in findings:
		push_error(finding)
	print("OPEN WATER BLOCKADE: clean" if findings.is_empty() else "OPEN WATER BLOCKADE: %d finding(s)" % findings.size())
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
