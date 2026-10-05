# Deep-water guidance and visual progression contract.
#
# Bugs caught:
# - DZ-27: one uniformly dark floor substitutes for progressive depth.
# - DZ-28: a mandatory blocker is presented as the route's main objective.
# - DZ-28A: the deeper-water warning repeats or is not persisted.
#
# Usage: godot --headless --path . --script verify/deep_zone_guidance.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var layout: Variant = (load("res://content/deep_zone_layout.gd") as Script).new()
	if not layout.has_method("depth_factor_for_position"):
		findings.append("DZ-27: shared layout has no progressive depth function")
	else:
		var entry := float(layout.call("depth_factor_for_position", layout.DEEP_ENTRY))
		var bomb := float(layout.call("depth_factor_for_position", layout.BOMB_BOT))
		var lab := float(layout.call("depth_factor_for_position", layout.LAB))
		_expect(entry < bomb and bomb < lab and lab >= 0.95,
			"DZ-27: depth does not increase monotonically from entry through Bomb Bot to the lab")

	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world._first_encounter_done = true
	var diver := world.divers[world.active] as Diver

	diver.global_position = layout.DEEP_ENTRY
	world._update_route_zone()
	_expect(world.route_state.objective_id == "find_lab",
		"DZ-28: entering Deep does not keep the laboratory as the main objective")
	_expect(world.banner.text == "You've entered deeper water. Stronger enemies may appear.",
		"DZ-28: entering Deep does not show the agreed concise danger warning")
	_expect(world.route_state.get("deep_warning_seen") == true,
		"DZ-28A: deeper-water warning is not represented in the saveable route state")

	world.banner.text = "sentinel"
	world.route_state.set_zone("shallows")
	world._update_route_zone()
	world.route_state.set_zone("deep")
	world._update_route_zone()
	_expect(world.banner.text == "sentinel",
		"DZ-28A: deeper-water warning repeats after its persisted state is set")

	world._resolve_deep_zone_blocker("bomb_bot", "won")
	_expect(world.route_state.objective_id == "find_lab",
		"DZ-28: Bomb Bot victory replaces the lab objective with another enemy objective")
	world._resolve_deep_zone_blocker("sword_slayer", "won")
	_expect(world.route_state.objective_id == "find_lab",
		"DZ-28: Sword Slayer victory replaces the lab objective instead of opening its entrance")

	var world_environment := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		findings.append("DZ-27: production world has no environment to grade by depth")
	elif not world.has_method("_update_deep_zone_visuals"):
		findings.append("DZ-27: production World has no position-driven depth treatment")
	else:
		diver.global_position = layout.DEEP_ENTRY
		world.call("_update_deep_zone_visuals")
		var entry_color := world_environment.environment.background_color
		var entry_fog := world_environment.environment.fog_density
		diver.global_position = layout.BOMB_BOT
		world.call("_update_deep_zone_visuals")
		var bomb_color := world_environment.environment.background_color
		var bomb_fog := world_environment.environment.fog_density
		diver.global_position = layout.LAB
		world.call("_update_deep_zone_visuals")
		var lab_color := world_environment.environment.background_color
		var lab_fog := world_environment.environment.fog_density
		_expect(entry_color.get_luminance() > bomb_color.get_luminance()
			and bomb_color.get_luminance() > lab_color.get_luminance(),
			"DZ-27: visible water color does not darken continuously toward the lab")
		_expect(entry_fog < bomb_fog and bomb_fog < lab_fog,
			"DZ-27: water fog does not thicken continuously toward the lab")

	world.queue_free()
	await process_frame
	var audio_owner := root.get_node_or_null("GameAudio")
	if audio_owner != null:
		audio_owner.call("release_streams_for_shutdown")
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("DEEP ZONE GUIDANCE: clean" if findings.is_empty() else "DEEP ZONE GUIDANCE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
