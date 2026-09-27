# `route landmark: the Shallows capstone is a readable reef passage with a
# physically open centre — guards against an anonymous beacon destination or
# decorative geometry becoming another invisible barrier`.
extends SceneTree

const PASSAGE_CENTRE := Vector3(55.0, 2.0, 40.0)
const EXIT_Z := 46.0
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
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world._intro_active = false
	world._begin_core_route_after_tutorial()
	world.route_transition_card.dismiss()
	await process_frame

	# Advance through the two ordinary shallow fights using the public route
	# state. The World signal must build the capstone destination itself.
	for _i in 2:
		world.route.begin_active_encounter()
		world.route.resolve_active_encounter("won")
		await process_frame
	var presentation := world.route_landmark_presentation()
	_expect(world.route.objective_id == "shallow_capstone",
		"REEF PASSAGE: test did not reach the named shallow capstone")
	_expect(String(presentation.kind) == "reef_passage" and float(presentation.opening_width) >= 8.0,
		"REEF PASSAGE: 'secure the reef passage' has no readable, broad reef-passage landmark: %s" % presentation)
	_expect(bool(presentation.collision_free),
		"REEF PASSAGE: destination decoration introduced collision geometry into the promised open passage")

	# Swim the production diver through the middle of the landmark, not around
	# it. The Area3D may start the intended encounter but cannot become a
	# physical wall; this reproduces the player-facing free-swim movement seam.
	world.set_physics_process(false)
	var diver := world.divers[world.active] as Diver
	diver.global_position = PASSAGE_CENTRE + Vector3(0.0, 0.0, -9.0)
	diver.velocity = Vector3.ZERO
	await physics_frame
	var deadline := Time.get_ticks_msec() + int(TIMEOUT_SECONDS * 1000.0)
	while diver.global_position.z < EXIT_Z and Time.get_ticks_msec() < deadline:
		# Godot's `FORWARD` is -Z; this passage is entered from its shallow
		# (-Z) side and crossed toward +Z.
		diver.swim(Vector3.BACK, 0.0, 1.0 / 60.0)
		await physics_frame
	_expect(diver.global_position.z >= EXIT_Z,
		"REEF PASSAGE: real swim movement did not pass through the central opening (stopped at %s)" % diver.global_position)

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("REEF PASSAGE: named landmark and physical central crossing are clean")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
