extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _exercise("Staff_Diver", "swap")
	await _exercise("Prototype_V(1922)", "shockwave")
	for finding in findings:
		print("FINDING  " + finding)
	print("SPECIAL DISPATCH: clean" if findings.is_empty() else "SPECIAL DISPATCH: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _exercise(model_name: String, ability: String) -> void:
	var diver := Diver.new()
	diver.model_name = model_name
	root.add_child(diver)
	await process_frame
	diver.stats.agility = -999

	var battle := Battle.new()
	battle.party_source = [diver]
	battle.special_encounter = true
	root.add_child(battle)
	await process_frame
	var default_camera_position := battle._stage_cam.global_position

	var minigame: Node = null
	var deadline := Time.get_ticks_msec() + 6000
	while minigame == null and Time.get_ticks_msec() < deadline:
		for child in battle.get_children():
			if ability == "swap" and child is DiverSwapMinigame:
				minigame = child
			elif ability == "shockwave" and child is RockDodgeMinigame:
				minigame = child
		if minigame == null:
			await process_frame

	if minigame == null:
		findings.append("%s never dispatched its %s minigame" % [model_name, ability])
	else:
		minigame.call("request_abort")
		deadline = Time.get_ticks_msec() + 3000
		while is_instance_valid(minigame) and Time.get_ticks_msec() < deadline:
			await process_frame
		if is_instance_valid(minigame):
			findings.append("%s minigame did not finish after abort" % model_name)
		if battle._stage_cam.global_position.distance_to(default_camera_position) > 0.05 or not is_equal_approx(battle._stage_cam.fov, 70.0):
			findings.append("%s minigame did not restore the combat camera" % model_name)

	if is_instance_valid(battle):
		battle.free()
	if is_instance_valid(diver):
		diver.free()
	await process_frame
