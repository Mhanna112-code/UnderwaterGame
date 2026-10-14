# Is there anywhere to go, and does going there work?
#
# Two things this covers, and they used to be one tangled thing.
#
# The dive site has two guarded items. Every part of that was built and
# wired: sonar reveals a spot once you are close enough (diver.gd), the
# minimap marks it or points at it (mini_map.gd), the guardian is a finished
# class, and winning its fight grants the item. The only missing piece was
# the six lines that put a guardian in the water, and they were present but
# wrapped in a triple-quoted string, which GDScript parses as a string
# literal and Godot never warns about. So the function ran and built
# nothing, for weeks, and the map had nothing in it to swim toward. See #45.
#
# Meanwhile the half that WAS switched on handed you a key item for winning
# any random encounter that happened to roll inside an unmarked ten metre
# circle. That is gone. An encounter is an encounter; the item is behind the
# guardian.
#
# Usage: godot --headless --path . --script verify/encounters.gd
extends SceneTree

var world: Node3D
var findings: Array = []
var frames := 0
var stage := 0
var cases: Array = []
var at := -1
var expect_reward := ""
var _finishing := false

func _initialize() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	# This gate exercises ordinary play after recovery, not protected prologue.
	world.route_state.opening_video_seen = true
	world.route_state.prologue_complete = true
	world.route_state.tutorial_complete = true
	root.add_child(world)

func _process(_d: float) -> bool:
	if _finishing:
		return false
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames == 2:
		_report_encounter_rate()
		_check_site_contracts()
		_check_spots_are_reachable()
		# The first tutorial route intentionally suppresses random encounters.
		# Complete that gate for this ordinary-encounter test rather than
		# treating the documented onboarding contract as a regression.
		world._intro_active = false
		# Ordinary encounters belong to open water. The dedicated guardian-zone
		# gate verifies that an unclaimed artifact site rejects one instead of
		# making its deliberate encounter ambiguous.
		cases.append({"at": Vector3(0.0, 2.0, 0.0), "what": "open water", "reward": "", "kind": "encounter"})
		# Then walking into each guardian, which must not be ordinary.
		for s in ItemGuardian.spots():
			cases.append({"at": s.at as Vector3, "what": "the %s guardian" % String(s.item),
				"reward": String(s.item), "enemy": String(s.get("enemy", "angler")), "kind": "guardian"})
		return false

	if at >= 0:
		# Ordinary rolls now reveal their real enemies in the exploration world
		# before constructing Battle. Site dispatch remains immediate/chooser.
		if world._transitioning_to_encounter:
			return false
		_check_result()
	at += 1
	if at >= cases.size():
		return _report()
	_run(cases[at] as Dictionary)
	return false

# The guarded-site contract is data-driven now: no visible ItemGuardian node
# or debug ring is required. Verify that every record resolves to real content
# before exercising entry below.
func _check_site_contracts() -> void:
	var ids: Array[String] = []
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		var site_id := String(entry.get("site", ""))
		if site_id == "" or Sites.by_id(site_id).is_empty():
			findings.append("MISSING SITE: guarded item '%s' has no world site record" % String(entry.get("item", "")))
		if ids.has(site_id):
			findings.append("DUPLICATE SITE: guarded site '%s' appears more than once" % site_id)
		ids.append(site_id)
		if not EnemyRoster.ORDINARY_IDS.has(String(entry.get("enemy", ""))):
			findings.append("MISSING ENEMY: guarded site '%s' maps to unknown enemy '%s'" % [site_id, String(entry.get("enemy", ""))])

# How far you swim between fights, as a number.
# How far you swim between fights, as a number.
#
# Marc: "may need to turn up the encounter rate just a tad, sometimes im
# having to do a lot of swimming for little return." A check happens every
# min..max_encounter_distance metres and passes with encounter_chance, so
# the mean swim between fights is the mean of that range divided by the
# chance. Printed rather than asserted: the right value is a judgement, and
# what was missing was not a rule but a figure to argue about.
func _report_encounter_rate() -> void:
	var d: Diver = world.divers[world.active]
	var mean_check: float = (d.min_encounter_distance + d.max_encounter_distance) * 0.5
	var between: float = mean_check / maxf(0.01, d.encounter_chance)
	print("encounter rate: a check every %.0f m on average, %.0f%% of them bite, so a fight every %.0f m" % [
		mean_check, d.encounter_chance * 100.0, between])
	if not is_equal_approx(d.min_encounter_distance, 8.0) \
		or not is_equal_approx(d.max_encounter_distance, 16.0) \
		or not is_equal_approx(d.encounter_chance, 0.7):
		findings.append("ENCOUNTER TUNING IGNORED: the requested 8-16 m / 70%% values were replaced with %.0f-%.0f m / %.0f%%" % [
			d.min_encounter_distance, d.max_encounter_distance, d.encounter_chance * 100.0])

# A spot in clear water you cannot reach is not a destination. The first
# pair of coordinates sat inside rocks; the second pair I picked sat behind
# a wall. Both are checked here so the next person to move a rock finds out
# from the build rather than from a playtest.
func _check_spots_are_reachable() -> void:
	var space := (world.get_viewport() as Viewport).world_3d.direct_space_state
	var start := Vector3(0.0, 2.0, 0.0)
	for entry in ItemGuardian.spots():
		var spot: Vector3 = entry.at as Vector3
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 2.4
		q.shape = sph
		q.transform = Transform3D(Basis(), spot)
		q.collision_mask = 1               # the environment layer
		var overlaps: Array = []
		for hit_value in space.intersect_shape(q, 8):
			var collider := (hit_value as Dictionary).get("collider") as Node
			if collider == null or not collider.is_in_group("grapple_anchor"):
				overlaps.append(hit_value)
		var ray := PhysicsRayQueryParameters3D.create(start, spot, 1)
		var excluded: Array[RID] = []
		for node_value in get_nodes_in_group("grapple_anchor"):
			var collision_object := node_value as CollisionObject3D
			if collision_object != null:
				excluded.append(collision_object.get_rid())
		ray.exclude = excluded
		var blocked := space.intersect_ray(ray)
		print("%-14s at %s: %d overlap(s), approach %s" % [
			String(entry.item), spot, overlaps.size(),
			"clear" if blocked.is_empty() else "BLOCKED at %s" % blocked.position])
		if not overlaps.is_empty():
			findings.append("BURIED: the %s spot is inside %d piece(s) of level geometry" % [
				String(entry.item), overlaps.size()])
		# Deep Zone sites sit past the corridor walls; they're reached by route.
		if not blocked.is_empty() and not bool(entry.get("deep", false)):
			findings.append("WALLED OFF: nothing can swim straight from the start to the %s spot" % String(entry.item))

func _run(spot: Dictionary) -> void:
	if world.battle != null:
		world.battle.free()
		world.battle = null
	world.battling = false
	world._pending_reward_item = ""
	expect_reward = String(spot.reward)
	var d: Diver = world.divers[world.active]
	d.position = spot.at as Vector3
	if String(spot.kind) == "encounter":
		d.encounter_triggered.emit()
	else:
		world._inside_item_site_id = ""
		d.encounter_triggered.emit()
		# Special sites deliberately open Marc's chooser after the first
		# tutorial example. Drive its public selection signal when present.
		if world.special_encounter_prompt.visible:
			world.special_encounter_prompt.diver_chosen.emit(d.model_name)

func _check_result() -> void:
	var spot: Dictionary = cases[at] as Dictionary
	var battles := 0
	var built_battle: Battle = null
	for c in world.get_children():
		if c is Battle:
			battles += 1
			built_battle = c as Battle
	var got := String(world._pending_reward_item)
	print("%-28s %d battle(s), reward %s" % [
		String(spot.what), battles, got if got != "" else "none"])
	if battles == 0:
		findings.append("NO FIGHT: %s started nothing at all" % String(spot.what))
	elif battles > 1:
		findings.append("STACKED FIGHTS: %s started %d battle screens" % [String(spot.what), battles])
	if got != expect_reward:
		findings.append("WRONG REWARD: %s is worth '%s', expected '%s'" % [
			String(spot.what), got, expect_reward])
	if built_battle != null:
		var enemy_count := built_battle.enemies.size()
		if String(spot.kind) == "guardian" and enemy_count != 1:
			findings.append("GUARDIAN PACK: one visible guardian became %d combat enemies" % enemy_count)
		elif String(spot.kind) == "encounter" and enemy_count > Battle.max_enemies_for_level(1):
			findings.append("OPENING PACK: level 1 rolled %d enemies, max is %d" % [
				enemy_count, Battle.max_enemies_for_level(1)])
		if String(spot.kind) == "guardian" and enemy_count == 1:
			var actor := (built_battle.enemies[0] as Dictionary).actor as Goblin
			var expected_enemy := String(spot.get("enemy", "angler"))
			if actor == null or actor.enemy_id() != expected_enemy:
				findings.append("REAL WORLD GUARDIAN: %s trigger builds %s battle — guards against map/battle identity drift (got %s)" % [
					String(spot.reward), expected_enemy, actor.enemy_id() if actor != null else "none"])

func _report() -> bool:
	_finishing = true
	for f in findings:
		print("FINDING  " + f)
	print("ENCOUNTERS: clean" if findings.is_empty() else "ENCOUNTERS: %d finding(s)" % findings.size())
	world.queue_free()
	call_deferred("_finish_report")
	return true

func _finish_report() -> void:
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	quit(0 if findings.is_empty() else 1)
