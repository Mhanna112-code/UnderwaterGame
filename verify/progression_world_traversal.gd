# `progression route: ordinary swim input reaches the first authored beacon —
# guards against a route objective that exists in state but is physically
# blocked or disconnected from World collision`.
#
# Unlike progression_playthrough, this test never emits Area3D.body_entered
# directly. It starts a normal World, dismisses the real route handoff, and
# drives World’s production movement input until physics delivers the player
# into the live beacon trigger.
extends SceneTree

const TRAVERSAL_TIMEOUT_SECONDS := 18.0
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
	# The tutorial completion itself is verified through live battle controls in
	# tutorial_ability_onboarding. This traversal gate owns the first free-world
	# leg immediately after that production handoff.
	world._intro_active = false
	world._begin_core_route_after_tutorial()
	world.route_transition_card.dismiss()
	await physics_frame

	var player := world.divers[world.active] as Diver
	var deadline := Time.get_ticks_msec() + int(TRAVERSAL_TIMEOUT_SECONDS * 1000.0)
	while world.battle == null and Time.get_ticks_msec() < deadline:
		var toward := world.route.active_position() - player.global_position
		toward.y = 0.0
		world.scripted = true
		world.scripted_dir = toward.normalized() if toward.length_squared() > 0.01 else Vector3.ZERO
		await physics_frame
	world.scripted = false
	world.scripted_dir = Vector3.ZERO

	_expect(world.battle != null,
		"ROUTE TRAVERSAL: 18 seconds of production swimming could not reach the first visible beacon (player %s, target %s, horizontal distance %.2f, velocity %s)" % [
			player.global_position, world.route.active_position(),
			Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(world.route.active_position().x, world.route.active_position().z)),
			player.velocity,
		])
	if world.battle != null:
		_expect(world.battle.enemies.size() == 1,
			"ROUTE TRAVERSAL: first reachable authored encounter did not have one enemy")
		if not world.battle.enemies.is_empty():
			var actor := (world.battle.enemies[0] as Dictionary).actor as Goblin
			_expect(actor != null and actor.enemy_id() == "angler",
				"ROUTE TRAVERSAL: normal movement reached the wrong first encounter")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("progression traversal  production swimming reached the first beacon and opened its authored Angler fight")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
