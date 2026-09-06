extends SceneTree

var finished_result: Array = []
var impacts := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bounce_failure := _single_bounce_failure()
	if bounce_failure != "":
		push_error(bounce_failure)
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var diver := Diver.new()
	diver.model_name = "Prototype_1(1910)"
	viewport.add_child(diver)

	var minigame := GrappleInterceptMinigame.new()
	minigame.stage_root = viewport
	minigame.stage_camera = camera
	minigame.target_actor = diver
	minigame.source_position = Vector3(0.0, 1.5, -8.0)
	minigame.object_hit.connect(func() -> void: impacts += 1)
	minigame.finished.connect(func(hits: int, total: int) -> void: finished_result = [hits, total])
	root.add_child(minigame)
	minigame.run()
	# Let the real title hold complete and inspect the actual shuffled burst
	# before the aim helper can remove any rocks. Rocks are visible spheres,
	# so their centers must start at least two radii apart.
	await create_timer(GrappleInterceptMinigame.TITLE_HOLD + 0.05).timeout
	var overlap_pairs := _overlap_pair_count(minigame)
	if overlap_pairs > 0:
		push_error("GRAPPLE INTERCEPT: burst spheres start separated — guards against overlap-driven double bounces (%d overlapping pair(s))" % overlap_pairs)
		quit(1)
		return
	# By now the initial inward trajectories have reached contact distance.
	# This observes the real `_process()` owner, not only the pure resolver.
	await create_timer(0.40).timeout
	overlap_pairs = _overlap_pair_count(minigame)
	if overlap_pairs > 0:
		push_error("GRAPPLE INTERCEPT: approaching spheres stay separated after one collision response — guards against a live double bounce (%d overlapping pair(s))" % overlap_pairs)
		quit(1)
		return

	var deadline := Time.get_ticks_msec() + 15000
	while finished_result.is_empty() and Time.get_ticks_msec() < deadline:
		minigame.auto_intercept_closest()
		await process_frame

	# MODIFIED: was also asserting wrong_hits == 1, driven by deliberately
	# shooting a decoy (auto_hit_decoy(), now removed along with decoys
	# entirely - see grapple_intercept_minigame.gd).
	var clean := finished_result == [GrappleInterceptMinigame.TARGET_COUNT, GrappleInterceptMinigame.TARGET_COUNT] and impacts == 0
	print("GRAPPLE INTERCEPT: %s, impacts %d" % [str(finished_result), impacts])
	if not clean:
		push_error("GRAPPLE INTERCEPT: automated aim did not intercept every target")
		quit(1)
		return
	print("GRAPPLE INTERCEPT: clean")
	quit()

func _overlap_pair_count(minigame: GrappleInterceptMinigame) -> int:
	var overlap_pairs := 0
	for first_index in range(minigame._targets.size()):
		var first := minigame._targets[first_index]
		for second_index in range(first_index + 1, minigame._targets.size()):
			var second := minigame._targets[second_index]
			if first.global_position.distance_to(second.global_position) < GrappleInterceptMinigame.BIG_ROCK_RADIUS * 2.0 - 0.01:
				overlap_pairs += 1
	return overlap_pairs

# Eight approach normals cover axes and diagonals. This is an observable
# physics contract of the production resolver: after one elastic response
# the same pair must be moving apart and a second contact pass must not
# change its velocities again.
func _single_bounce_failure() -> String:
	var normals := [
		Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN,
		Vector3(1.0, 0.0, 1.0).normalized(), Vector3(-1.0, 0.0, 1.0).normalized(),
		Vector3(1.0, 1.0, 0.0).normalized(), Vector3(0.0, 1.0, 1.0).normalized(),
	]
	for normal in normals:
		var radius := GrappleInterceptMinigame.BIG_ROCK_RADIUS
		var first_position: Vector3 = -normal * radius * 0.75
		var second_position: Vector3 = normal * radius * 0.75
		var first_velocity: Vector3 = normal * 2.0
		var second_velocity: Vector3 = -normal * 2.0
		var first := GrappleInterceptMinigame.resolve_sphere_contact(
			first_position, first_velocity, second_position, second_velocity, radius)
		if not bool(first.impulse):
			return "GRAPPLE COLLISION: approaching spheres receive one elastic impulse — guards against rocks passing through each other"
		var separation: float = (first.second_position as Vector3).distance_to(first.first_position as Vector3)
		if separation < radius * 2.0:
			return "GRAPPLE COLLISION: bounced spheres separate fully — guards against overlap-driven double bounces"
		var second := GrappleInterceptMinigame.resolve_sphere_contact(
			first.first_position as Vector3, first.first_velocity as Vector3,
			first.second_position as Vector3, first.second_velocity as Vector3, radius)
		if bool(second.impulse):
			return "GRAPPLE COLLISION: separating spheres receive no second impulse — guards against double bounce"
		if (second.first_velocity as Vector3).distance_to(first.first_velocity as Vector3) > 0.0001 \
				or (second.second_velocity as Vector3).distance_to(first.second_velocity as Vector3) > 0.0001:
			return "GRAPPLE COLLISION: separating spheres keep their bounce velocity — guards against a hidden second response"
	return ""
