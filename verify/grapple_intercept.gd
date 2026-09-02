extends SceneTree

var finished_result: Array = []
var impacts := 0
var wrong_hits := 0

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

	var minigame := GrappleInterceptMinigame.new()
	minigame.stage_root = viewport
	minigame.stage_camera = camera
	minigame.target_actor = diver
	minigame.source_position = Vector3(0.0, 1.5, -8.0)
	minigame.object_hit.connect(func() -> void: impacts += 1)
	minigame.wrong_object_hit.connect(func() -> void: wrong_hits += 1)
	minigame.finished.connect(func(hits: int, total: int) -> void: finished_result = [hits, total])
	root.add_child(minigame)
	minigame.run()

	var deadline := Time.get_ticks_msec() + 15000
	var tested_decoy := false
	while finished_result.is_empty() and Time.get_ticks_msec() < deadline:
		if not tested_decoy and minigame.auto_hit_decoy():
			tested_decoy = true
		minigame.auto_intercept_closest()
		await process_frame

	var clean := finished_result == [GrappleInterceptMinigame.TARGET_COUNT, GrappleInterceptMinigame.TARGET_COUNT] and impacts == 0 and wrong_hits == 1
	print("GRAPPLE INTERCEPT: %s, impacts %d, deliberate decoy penalties %d" % [str(finished_result), impacts, wrong_hits])
	if not clean:
		push_error("GRAPPLE INTERCEPT: automated aim did not intercept every target")
		quit(1)
		return
	print("GRAPPLE INTERCEPT: clean")
	quit()
