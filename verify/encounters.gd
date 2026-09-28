# Is there anywhere to go, and does going there work?
#
# The dive site has four guarded items - no fixed guardian statue to swim
# into anymore (see game/item_guardian.gd's own header comment for why):
# sonar reveals a spot's red circle once you're close enough (diver.gd),
# the minimap marks it or points at it (mini_map.gd), and an ordinary
# random encounter rolled inside that circle now deterministically resolves
# that site's own guarded fight (World._on_encounter_triggered()) - no
# chance involved any more. "special" sites (Sites.ALL) go through the solo
# diver-ability minigame; the rest are a plain fight for that site's own
# key item. Outside the circle, not yet revealed, or already claimed, an
# encounter there is exactly as ordinary as one in open water.
#
# Usage: godot --headless --path . --script verify/encounters.gd
extends SceneTree

var world: World
var findings: Array = []
var frames := 0

func _initialize() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames == 2:
		_report_encounter_rate()
		_check_spots_are_reachable()
		# The first tutorial route intentionally suppresses random encounters.
		# Complete that gate for this ordinary-encounter test rather than
		# treating the documented onboarding contract as a regression.
		world._intro_active = false
		_check_open_water_is_ordinary()
		_check_unrevealed_spot_is_ordinary()
		_check_claimed_spot_stays_ordinary()
		call_deferred("_run_probabilistic_checks")
		return false
	return false

# The bug that started all of this: the spawner ran and built nothing.
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
		or not is_equal_approx(d.encounter_chance, 0.5):
		findings.append("ENCOUNTER TUNING IGNORED: Marc's tested 8-16 m / 50%% values were replaced with %.0f-%.0f m / %.0f%%" % [
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
		var overlaps := space.intersect_shape(q, 4)
		var ray := PhysicsRayQueryParameters3D.create(start, spot, 1)
		var blocked := space.intersect_ray(ray)
		print("%-14s at %s: %d overlap(s), approach %s" % [
			String(entry.item), spot, overlaps.size(),
			"clear" if blocked.is_empty() else "BLOCKED at %s" % blocked.position])
		if not overlaps.is_empty():
			findings.append("BURIED: the %s spot is inside %d piece(s) of level geometry" % [
				String(entry.item), overlaps.size()])
		if not blocked.is_empty():
			findings.append("WALLED OFF: nothing can swim straight from the start to the %s spot" % String(entry.item))

func _reset_encounter_state() -> void:
	if world.battle != null:
		world.battle.free()
		world.battle = null
	world.battling = false
	world._pending_reward_item = ""
	world._special_encounter_item = ""
	if world.special_encounter_prompt.visible:
		world.special_encounter_prompt.close()
	# This script IS the SceneTree (extends SceneTree) - `paused` directly,
	# not get_tree().paused (there is no get_tree() to call from here).
	paused = false

func _trigger_encounter_at(pos: Vector3) -> Diver:
	_reset_encounter_state()
	var d: Diver = world.divers[world.active]
	d.position = pos
	d.encounter_triggered.emit()
	return d

func _expect_ordinary(what: String) -> void:
	var battles := 0
	for c in world.get_children():
		if c is Battle:
			battles += 1
	if battles != 1:
		findings.append("EXPECTED ORDINARY FIGHT: %s produced %d battle(s), not exactly one" % [what, battles])
	if world.special_encounter_prompt.visible:
		findings.append("UNEXPECTED SPECIAL ENCOUNTER: %s opened the diver-choice prompt instead of an ordinary fight" % what)

func _check_open_water_is_ordinary() -> void:
	_trigger_encounter_at(Vector3(0.0, 2.0, 0.0))
	_expect_ordinary("open water")

# Standing right on a guarded spot that sonar has never revealed must still
# be an ordinary encounter - discovery is sonar's job, not proximity alone.
func _check_unrevealed_spot_is_ordinary() -> void:
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		world.revealed_key_items.clear()
		world.key_items.clear()
		_trigger_encounter_at(entry.at as Vector3)
		_expect_ordinary("the unrevealed %s spot" % String(entry.item))

# Already claimed (in key_items) must stay ordinary too, regardless of
# revealed_key_items - nothing left to win there.
func _check_claimed_spot_stays_ordinary() -> void:
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		var item_id := String(entry.item)
		world.revealed_key_items.assign([item_id])
		world.key_items.assign([item_id])
		_trigger_encounter_at(entry.at as Vector3)
		_expect_ordinary("the already-claimed %s spot" % item_id)
	world.key_items.clear()

# No more retry loop - being in range of a revealed, unclaimed guarded
# item is deterministic now (World._on_encounter_triggered() no longer
# rolls a chance), so one trigger per site is enough. player_first_special_
# encounter is forced false first so this exercises the *steady-state*
# diver-choice prompt, not the one-time skip - see
# _check_first_special_encounter_skips_prompt() for that path specifically.
func _run_probabilistic_checks() -> void:
	world.player_first_special_encounter = false
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		if not bool(entry.get("special", false)):
			continue
		var item_id := String(entry.item)
		var expected_enemy := String(entry.get("enemy", "angler"))
		world.revealed_key_items.assign([item_id])
		world.key_items.clear()
		var d := _trigger_encounter_at(entry.at as Vector3)
		if not (world.special_encounter_prompt.visible and world._special_encounter_item == item_id):
			findings.append("NEVER OPENS: the revealed %s circle didn't open the special encounter" % item_id)
			continue
		world.special_encounter_prompt.diver_chosen.emit(d.model_name)
		await process_frame
		await process_frame
		var built_battle: Battle = null
		var battles := 0
		for c in world.get_children():
			if c is Battle:
				battles += 1
				built_battle = c as Battle
		if built_battle == null:
			findings.append("NO FIGHT: revealed %s circle opened the special encounter but built no battle" % item_id)
			continue
		if battles > 1:
			findings.append("STACKED FIGHTS: revealed %s circle started %d battle screens" % [item_id, battles])
		if built_battle.enemies.size() != 1:
			findings.append("GUARDIAN PACK: %s special encounter built %d enemies, expected 1" % [item_id, built_battle.enemies.size()])
		else:
			var actor := (built_battle.enemies[0] as Dictionary).actor as Goblin
			if actor == null or actor.enemy_id() != expected_enemy:
				findings.append("REAL WORLD GUARDIAN: %s special encounter builds %s — guards against map/battle identity drift (got %s)" % [
					item_id, expected_enemy, actor.enemy_id() if actor != null else "none"])
	_check_plain_guarded_sites_are_deterministic()
	await _check_first_special_encounter_skips_prompt()
	_report()

# shallows/trench (special: false) are plain fights for their own key item,
# every single time you're in range of the revealed item - no diver-choice
# prompt, no coin flip.
func _check_plain_guarded_sites_are_deterministic() -> void:
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		if bool(entry.get("special", false)):
			continue
		var item_id := String(entry.item)
		world.revealed_key_items.assign([item_id])
		world.key_items.clear()
		_trigger_encounter_at(entry.at as Vector3)
		if world.special_encounter_prompt.visible:
			findings.append("UNEXPECTED PROMPT: the plain %s spot opened the diver-choice prompt" % item_id)
		var battles := 0
		for c in world.get_children():
			if c is Battle:
				battles += 1
		if battles != 1:
			findings.append("EXPECTED PLAIN FIGHT: the revealed %s spot produced %d battle(s), not exactly one" % [item_id, battles])
		elif world._pending_reward_item != item_id:
			findings.append("WRONG REWARD: the revealed %s spot's battle carries reward '%s'" % [item_id, world._pending_reward_item])

# The very first special encounter of the game skips the Enter/Not Now
# prompt entirely and drops the player straight into the minigame as
# Maxilani (World._offer_special_encounter()) - a real, one-time-only
# behavior distinct from the steady-state prompt _run_probabilistic_checks()
# above already exercises with the flag forced off.
func _check_first_special_encounter_skips_prompt() -> void:
	var special_entry: Dictionary = {}
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		if bool(entry.get("special", false)):
			special_entry = entry
			break
	if special_entry.is_empty():
		findings.append("NO SPECIAL SITES: nothing on the map has special:true to test the first-encounter skip against")
		return
	world.player_first_special_encounter = true
	var item_id := String(special_entry.item)
	world.revealed_key_items.assign([item_id])
	world.key_items.clear()
	_trigger_encounter_at(special_entry.at as Vector3)
	await process_frame
	await process_frame
	if world.special_encounter_prompt.visible:
		findings.append("FIRST ENCOUNTER SHOULD SKIP: the diver-choice prompt opened instead of going straight to battle")
	if world.player_first_special_encounter:
		findings.append("FLAG NEVER CLEARS: player_first_special_encounter is still true after the first special encounter ran")
	var built_battle: Battle = null
	for c in world.get_children():
		if c is Battle:
			built_battle = c as Battle
	if built_battle == null:
		findings.append("NO FIGHT: the first special encounter never built a battle")
	elif not built_battle.tutorial_encounter:
		findings.append("NOT TUTORIALIZED: the first special encounter's battle isn't flagged tutorial_encounter")

func _report() -> void:
	for f in findings:
		print("FINDING  " + f)
	print("ENCOUNTERS: clean" if findings.is_empty() else "ENCOUNTERS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
