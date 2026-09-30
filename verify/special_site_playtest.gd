extends SceneTree

const SitesScript := preload("res://content/sites.gd")

var findings: Array[String] = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _advance_physics(frames: int = 3) -> void:
	for _i in range(frames):
		await physics_frame

func _run() -> void:
	var world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var requested_id := "reef"
	for arg_value in OS.get_cmdline_user_args():
		var arg := String(arg_value)
		if arg.begins_with("--special-site-playtest="):
			requested_id = arg.trim_prefix("--special-site-playtest=")
	if requested_id != "reef":
		_check(world._special_site_playtest_id.is_empty(), "unknown special-site id did not fall back to the ordinary game")
		for finding in findings:
			print("FINDING  " + finding)
		print("SPECIAL-SITE INVALID-ID REVIEW: clean" if findings.is_empty() else "SPECIAL-SITE INVALID-ID REVIEW: %d finding(s)" % findings.size())
		quit(0 if findings.is_empty() else 1)
		return
	_check(world._special_site_playtest_id == "reef", "special-site review did not read --special-site-playtest=reef")
	await world._on_title_new_game(0)
	await process_frame
	await _advance_physics()

	var site: Dictionary = SitesScript.by_id("reef")
	var diver = world.divers[world.active]
	var target := site.at as Vector3
	var radius := float(site.radius)
	_check(not paused, "special-site review left the world paused by onboarding")
	_check(world._current_slot == -1, "special-site review created a player save slot")
	_check(world.random_encounters_enabled, "special-site review did not enable encounters")
	_check(not world.battling, "special-site review directly dispatched the encounter before movement")
	_check(diver.global_position.distance_to(target) > radius, "special-site review began inside the real trigger radius")
	_check(diver.global_position.distance_to(target) <= radius + 1.6, "special-site review did not stage the diver one short movement outside the site")

	# Crossing the boundary is the same public world behavior a normal player
	# uses. The review route only staged position/orientation; it never invokes
	# _offer_special_encounter() or the minigame dispatcher directly.
	diver.global_position = target
	await _advance_physics()
	_check(
		world.battling and world.battle != null and world.battle.special_encounter,
		"special-site review did not start the real special encounter after crossing the radius"
	)

	for finding in findings:
		print("FINDING  " + finding)
	print("SPECIAL-SITE REVIEW: clean" if findings.is_empty() else "SPECIAL-SITE REVIEW: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _initialize() -> void:
	call_deferred("_run")
