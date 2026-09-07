# Player-path regression for the stacked Tutorial -> gate -> maze prototype.
# Usage: godot --headless --path . --script verify/onboarding.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	await process_frame

	# New Game must begin a real, unpaused route, not leave a modal over it.
	world._on_title_new_game(-1)
	await process_frame
	if paused or not world.get_node("HUD").visible:
		findings.append("OB-01: New Game does not leave the world immediately playable")
	if not world.onboarding_active or world.onboarding_step != World.OnboardingStep.SHOCKWAVE:
		findings.append("OB-03: New Game did not begin at the Shockwave route step")
	if world._onboarding_marker == null or not world._onboarding_marker.visible:
		findings.append("OB-03: no visible opening-route objective marker was created")
	if not world.onboarding_label.text.contains("Shockwave"):
		findings.append("OB-03: opening objective does not explain Shockwave")

	# The active diver's ordinary trigger must be ignored until the door opens.
	world._on_encounter_triggered(world.divers[world.active] as Diver)
	if world.battle != null:
		findings.append("OB-02: an ordinary encounter interrupted onboarding")

	world._entrance_blockade.broken.emit()
	await process_frame
	if world.onboarding_step != World.OnboardingStep.GRAPPLE or not world.onboarding_label.text.contains("Grapple"):
		findings.append("OB-04: breaking entrance rubble did not advance to Grapple")

	world._far_grapple_anchor.grappled_to.emit()
	await process_frame
	if world.onboarding_step != World.OnboardingStep.SWAP or not world.onboarding_label.text.contains("Swap"):
		findings.append("OB-05: confirmed Grapple did not advance to Swap")

	(world.divers[world.active] as Diver).swapped_with.emit(world.divers[1] as Diver)
	await process_frame
	if world.onboarding_step != World.OnboardingStep.DOOR or not world.onboarding_label.text.contains("glowing plates"):
		findings.append("OB-05: confirmed Swap did not advance to the coordinated door")

	for i in range(world._lock_plates.size()):
		(world._lock_plates[i] as LockPlate).occupant = world.divers[i] as Diver
	world._check_gap_puzzle()
	await process_frame
	if world.onboarding_active or world.onboarding_step != World.OnboardingStep.COMPLETE:
		findings.append("OB-06: opening the three-plate door did not complete onboarding")
	for door in world._doors:
		if not bool((door as Door).get("_opened")):
			findings.append("OB-06: a plate-door remained closed after the combined puzzle")
			break

	world._on_encounter_triggered(world.divers[world.active] as Diver)
	if world.battle == null:
		findings.append("OB-06: ordinary encounters stayed suppressed after maze unlock")
	elif is_instance_valid(world.battle):
		world.battle.queue_free()
		world.battle = null
		world.battling = false

	world._on_title_load_game(-1)
	if world.onboarding_active or world.onboarding_step != World.OnboardingStep.OFF:
		findings.append("OB-07: Load Game restarted the first-run onboarding route")

	for finding in findings:
		print("FINDING  " + finding)
	print("ONBOARDING: clean" if findings.is_empty() else "ONBOARDING: %d finding(s)" % findings.size())
	world.queue_free()
	quit(0 if findings.is_empty() else 1)
