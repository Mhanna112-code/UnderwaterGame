# Black-box-ish player-path regression for the stacked Tutorial -> gate ->
# Maze prototype. It drives the same Tab/E/click/Enter input routes a player
# uses and the real ability/collision code; it never emits progress signals
# or assigns LockPlate.occupant by hand.
# Usage: godot --headless --path . --script verify/onboarding.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _press(world: World, key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	world._unhandled_input(event)

func _click(world: World) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	world._unhandled_input(event)

func _diver(world: World, model_name: String) -> Diver:
	for value in world.divers:
		var d := value as Diver
		if d.model_name == model_name:
			return d
	return null

func _await_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func _expect_cue(world: World, expected: TutorialCue.Kind, id: String) -> void:
	if world._onboarding_cue == null or not is_instance_valid(world._onboarding_cue):
		findings.append("%s: no physical tutorial cue exists" % id)
		return
	if world._onboarding_cue.kind != expected:
		findings.append("%s: cue type %d, expected %d" % [id, world._onboarding_cue.kind, expected])

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	root.add_child(world)
	await process_frame
	await process_frame

	# A clean New Game must be playable, visibly teach Shockwave, and leave
	# both ordinary and guardian encounters unable to interrupt the lesson.
	world._on_title_new_game(-1)
	await physics_frame
	if paused or not world.get_node("HUD").visible:
		findings.append("OB-01: New Game does not leave the world immediately playable")
	if not world.onboarding_active or world.onboarding_step != World.OnboardingStep.SHOCKWAVE:
		findings.append("OB-02: New Game did not begin at Shockwave")
	# The lesson must replace—not merely add to—the fixed-width free-swim HUD.
	# This makes the mobile layout contract testable without relying on a human
	# noticing a clipped controls line in a screenshot.
	var panel := world.onboarding_panel
	if panel == null or not panel.visible:
		findings.append("UX-01: New Game has no visible onboarding card")
	elif panel.position.x < 20.0 or panel.size.x > panel.get_viewport_rect().size.x - 40.0:
		findings.append("UX-01: onboarding card is not safely inset and viewport-responsive")
	else:
		var action := panel.get_node_or_null("Card/Rows/Instruction") as Label
		var chip := panel.get_node_or_null("Card/Rows/AbilityChip") as Label
		var hint := panel.get_node_or_null("Card/Rows/Hint") as Label
		if action == null or chip == null or not action.text.contains("MECH PILOT") or not chip.text.contains("SHOCKWAVE"):
			findings.append("UX-01: first card does not name the diver and ability")
		if hint == null or not hint.text.contains("TAB"):
			findings.append("UX-01: first card does not teach how to select the diver")
	if world.hud.visible:
		findings.append("UX-01: verbose free-swim controls compete with the first lesson")
	if world.minimap.visible or world.hp_wrap.visible or world.oxygen_wrap.visible:
		findings.append("UX-01: minimap or status bars compete with the first lesson")
	_expect_cue(world, TutorialCue.Kind.SHOCKWAVE, "OB-03")
	if world._onboarding_cue == null or world._onboarding_cue.get_node_or_null("Instruction") == null:
		findings.append("UX-01: obstacle has no world-space action label")
	# The maze and the deliberate first fight are post-door content.  Their
	# existence here would make the tutorial only cosmetic: a player could
	# reach the later loop before demonstrating the three taught abilities.
	if world._maze_instance != null or world.first_combat_pending or world.first_combat_seen:
		findings.append("OB-03: maze or first combat was available before the opening gate")
	world._on_encounter_triggered(world.divers[world.active] as Diver)
	if world.battle != null:
		findings.append("OB-04: ordinary encounter interrupted Shockwave lesson")
	if not world._item_guardians.is_empty():
		var guardian := world._item_guardians[0]
		world._on_item_guardian_triggered(String(guardian.item), guardian.guardian, guardian.decoy, "angler")
		if paused:
			findings.append("OB-04: guardian chooser interrupted onboarding")

	# TAB twice from Maxilani reaches Mech Pilot. E calls the real shockwave
	# and has to break the actual barrier; no progress signal is emitted here.
	_press(world, KEY_TAB)
	_press(world, KEY_TAB)
	var mech := _diver(world, "Prototype_V(1922)")
	if world.divers[world.active] != mech:
		findings.append("OB-05: Tab route did not select Mech Pilot for Shockwave")
	mech.global_position = Vector3(14.0, 2.0, 10.0)
	_press(world, KEY_E)
	await physics_frame
	if world.onboarding_step != World.OnboardingStep.GRAPPLE:
		findings.append("OB-05: real Shockwave did not break the entrance barrier")
	_expect_cue(world, TutorialCue.Kind.GRAPPLE, "OB-06")
	# The state written by a mid-route save must rebuild the same lesson on
	# restore, rather than turning Load Game into a silent escape from it.
	var saved_onboarding: Dictionary = world._serialize_state().get("onboarding", {}) as Dictionary
	var musashi := _diver(world, "Prototype_1(1910)")
	# Simulate a save made by the old build after several charged misses. The
	# restored tutorial must recover this exact legacy failure state rather than
	# make the player abandon the run.
	musashi.stats.oxygen = 0.0
	world._clear_onboarding()
	world._restore_onboarding(saved_onboarding)
	if not world.onboarding_active or world.onboarding_step != World.OnboardingStep.GRAPPLE:
		findings.append("OB-06: serialized mid-route state did not resume Grapple")
	_expect_cue(world, TutorialCue.Kind.GRAPPLE, "OB-06")
	if not is_equal_approx(musashi.stats.oxygen, musashi.stats.oxygen_max):
		findings.append("OB-06: legacy empty-oxygen tutorial save did not recover")

	# The near anchor is deliberately not enough. It must leave the route at
	# Grapple even though the real ray/pull succeeds, then a far-anchor pull has
	# to finish before Swap becomes available.
	_press(world, KEY_TAB)
	_press(world, KEY_TAB)
	musashi.global_position = Vector3(21.0, 2.0, 10.0)
	# A player naturally tests the line before finding the anchor. Those misses
	# are feedback, not completed abilities: they must neither spend oxygen nor
	# put Grapple on cooldown, otherwise five exploratory shots exhaust Musashi
	# and make the mandatory final crossing impossible.
	var oxygen_before_misses := musashi.stats.oxygen
	for attempt in range(6):
		# Deliberately aim out into open water, but not straight up: the latter
		# is a degenerate orientation for the temporary beam mesh.
		if musashi.use_ability(Vector3(0.25, 0.2, -1.0)):
			findings.append("OB-07: vertical Grapple miss %d unexpectedly completed" % (attempt + 1))
		await physics_frame
	if not is_equal_approx(musashi.stats.oxygen, oxygen_before_misses):
		findings.append("OB-07: repeated Grapple misses drained oxygen and can softlock the tutorial")
	if not musashi.can_use_ability():
		findings.append("OB-07: repeated Grapple misses left the required ability unavailable")
	var oxygen_before_crossing := musashi.stats.oxygen
	world.yaw = PI * 0.5
	world.pitch = 0.0
	_press(world, KEY_E)
	_click(world)
	await _await_seconds(Diver.GRAPPLE_PULL_DURATION + 0.12)
	if world.onboarding_step != World.OnboardingStep.GRAPPLE:
		findings.append("OB-07: near-anchor grapple falsely completed the crossing")
	if not is_equal_approx(musashi.stats.oxygen, oxygen_before_crossing):
		findings.append("OB-07: successful tutorial Grapple spent hidden oxygen")
	await _await_seconds(Diver.GRAPPLE_COOLDOWN + 0.08)
	musashi.global_position = Vector3(29.0, 2.0, 10.0)
	_press(world, KEY_E)
	_click(world)
	await _await_seconds(Diver.GRAPPLE_PULL_DURATION + 0.12)
	if world.onboarding_step != World.OnboardingStep.SWAP:
		findings.append("OB-08: far-anchor pull did not unlock the real Swap lesson")
	_expect_cue(world, TutorialCue.Kind.SWAP, "OB-08")
	if not is_equal_approx(musashi.stats.oxygen, oxygen_before_crossing):
		findings.append("OB-08: tutorial traversal spent oxygen the player was never taught")

	# A Swap near spawn may be a valid player experiment but cannot skip the
	# route. The actual selector (E/Enter) must put Maxilani across the gap.
	_press(world, KEY_TAB)
	_press(world, KEY_TAB)
	var maxilani := _diver(world, "Staff_Diver")
	maxilani.global_position = Vector3(0.0, 2.0, 0.0)
	musashi.global_position = Vector3(2.0, 2.0, 0.0)
	mech.global_position = Vector3(2.0, 2.0, 0.0)
	_press(world, KEY_E)
	_press(world, KEY_ENTER)
	await physics_frame
	if world.onboarding_step != World.OnboardingStep.SWAP:
		findings.append("OB-09: spawn-area Swap incorrectly skipped to the door")
	await _await_seconds(Diver.SWAP_COOLDOWN + 0.08)
	maxilani.global_position = Vector3(23.0, 2.0, 10.0)
	musashi.global_position = Vector3(31.0, 2.0, 10.0)
	_press(world, KEY_E)
	_press(world, KEY_ENTER)
	await physics_frame
	if world.onboarding_step != World.OnboardingStep.DOOR:
		findings.append("OB-10: a real across-gap Swap did not reveal the plate finale")
	_expect_cue(world, TutorialCue.Kind.DOOR, "OB-10")
	if not world._onboarding_halos.is_empty():
		findings.append("UX-02: plate finale still has redundant diver halos")
	var progress := world.onboarding_panel.get_node_or_null("Card/Rows/Progress") as Label
	if progress == null or not progress.text.contains("0 / 3"):
		findings.append("UX-02: plate finale does not start with an explicit 0/3 progress state")
	for plate_value in world._lock_plates:
		var identity := (plate_value as LockPlate).get_node_or_null("Identity") as Label3D
		if identity == null or identity.text.strip_edges().is_empty():
			findings.append("UX-02: a lock plate has no named identity label")
			break

	# Put the actual CharacterBody3Ds on the actual Area3D plates. Physics,
	# not a test-written occupant field, must open every door and instantiate
	# the authored maze.
	for i in range(world.divers.size()):
		(world.divers[i] as Diver).global_position = (world._lock_plates[i] as LockPlate).global_position
	for _frame in range(4):
		await physics_frame
	if world.onboarding_active or not world._puzzle_solved:
		findings.append("OB-11: actual diver/plate collision did not complete the finale")
	for door in world._doors:
		if not bool((door as Door).get("_opened")):
			findings.append("OB-11: a plate door remained closed")
			break
	if world._maze_instance == null or not is_instance_valid(world._maze_instance):
		findings.append("OB-12: door opened without embedding the authored maze")
	if world._puzzle_goal != null and world._puzzle_goal.visible:
		findings.append("OB-12: completed plate waypoint still hides the first combat cue")
	for plate_value in world._lock_plates:
		if (plate_value as LockPlate).visible:
			findings.append("OB-12: completed lock plate still competes with the first combat cue")
			break
	if not world.first_combat_pending or world._first_combat_trigger == null or not world._first_combat_actor.visible:
		findings.append("OB-13: no visible guaranteed first encounter was armed after the door")
	var handoff := world.onboarding_panel.get_node_or_null("Card/Rows/Action") as Label
	if handoff == null or handoff.text.to_upper() != "RED ANGLER AHEAD":
		findings.append("UX-03: maze handoff is not a single clear Angler prompt")
	if not world.banner.text.strip_edges().is_empty():
		findings.append("UX-03: a second world banner duplicates the maze handoff")
	if world._onboarding_cue == null or world._onboarding_cue.kind != TutorialCue.Kind.COMBAT or world._onboarding_cue.get_node_or_null("CombatReticle") == null:
		findings.append("UX-03: first combat lacks its red world cue")
	if world._active_cursor.visible:
		findings.append("UX-03: active-diver cursor competes with the first combat cue")
	var post_door_state: Dictionary = world._serialize_state().get("onboarding", {}) as Dictionary
	if not bool(post_door_state.get("first_combat_pending", false)) or bool(post_door_state.get("first_combat_seen", true)):
		findings.append("OB-13: save state did not record that the first combat became available")
	world._on_encounter_triggered(world.divers[world.active] as Diver)
	if world.battle != null:
		findings.append("OB-13: random encounter ran before the deliberate first combat")

	# Swim (rather than invoking a handler) from the final plate through the
	# opened exit to the red Angler trigger. If a wall disconnects the maze or
	# no Area detects the player, this times out instead of claiming success.
	world.active = 0
	world.scripted = true
	world.scripted_dir = Vector3(1.0, 0.0, 0.22).normalized()
	for _frame in range(210):
		await physics_frame
		if world.battle != null:
			break
	world.scripted = false
	if world.battle == null or not world.first_combat_seen:
		var d := world.divers[world.active] as Diver
		findings.append("OB-14: swimming beyond the opened door did not reach first combat (ended at %s, trigger %s, monitor=%s, overlaps=%s)" % [d.global_position, world._first_combat_trigger.global_position, world._first_combat_trigger.monitoring, world._first_combat_trigger.get_overlapping_bodies().size()])

	for finding in findings:
		print("FINDING  " + finding)
	print("ONBOARDING: clean" if findings.is_empty() else "ONBOARDING: %d finding(s)" % findings.size())
	world.queue_free()
	quit(0 if findings.is_empty() else 1)
