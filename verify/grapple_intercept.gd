extends SceneTree

var finished_result: Array = []
var impacts := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var diver := Diver.new()
	diver.model_name = "Prototype_1(1910)"
	viewport.add_child(diver)
	# MODIFIED (added): the grapple target is enemy_actor himself now, not
	# a group of thrown rocks - required for run() to do anything at all
	# (see its own guard).
	var enemy := Goblin.new()
	viewport.add_child(enemy)
	enemy.global_position = Vector3(0.0, 1.5, -8.0)

	var minigame := GrappleInterceptMinigame.new()
	minigame.stage_root = viewport
	minigame.stage_camera = camera
	minigame.target_actor = diver
	minigame.enemy_actor = enemy
	minigame.source_position = Vector3(0.0, 1.5, -8.0)
	minigame.object_hit.connect(func() -> void: impacts += 1)
	minigame.finished.connect(func(hits: int, total: int) -> void: finished_result = [hits, total])
	root.add_child(minigame)
	minigame.run()

	var deadline := Time.get_ticks_msec() + 15000
	while finished_result.is_empty() and Time.get_ticks_msec() < deadline:
		minigame.auto_intercept_closest()
		await process_frame

	# MODIFIED: was also asserting wrong_hits == 1, driven by deliberately
	# shooting a decoy (auto_hit_decoy(), now removed along with decoys
	# entirely - see grapple_intercept_minigame.gd).
	#
	# MODIFIED: TARGET_COUNT is now just ONE vortex wave's worth (2) - the
	# real total across the whole encounter is TARGET_COUNT *
	# TOTAL_VORTEX_WAVES (6), same product finished.emit() itself reports.
	var expected := GrappleInterceptMinigame.TARGET_COUNT * GrappleInterceptMinigame.TOTAL_VORTEX_WAVES
	var clean := finished_result == [expected, expected] and impacts == 0
	print("GRAPPLE INTERCEPT: %s, impacts %d" % [str(finished_result), impacts])
	if not clean:
		push_error("GRAPPLE INTERCEPT: automated aim did not intercept every target")
		quit(1)
		return
	print("GRAPPLE INTERCEPT: clean")
	quit()
