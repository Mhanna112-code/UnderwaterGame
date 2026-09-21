# Is there anywhere to go, and does going there work?
#
# The dive site has two guarded items - no fixed guardian statue to swim
# into anymore (see game/item_guardian.gd's own header comment for why):
# sonar reveals a spot's red circle once you're close enough (diver.gd),
# the minimap marks it or points at it (mini_map.gd), and an ordinary
# random encounter rolled inside that circle now has a real (not
# guaranteed) chance of opening the special encounter for that item instead
# of a normal fight (World._on_encounter_triggered()). Outside the circle,
# not yet revealed, or already claimed, an encounter there is exactly as
# ordinary as one in open water.
#
# Usage: godot --headless --path . --script verify/encounters.gd
extends SceneTree

var world: World
var findings: Array = []
var frames := 0

# High enough that a run of misses in a row is unremarkable, low enough this
# doesn't hang if the gate really did regress to "never" - at
# World.GUARDED_ENCOUNTER_CHANCE (0.35), the odds of this many misses in a
# row by chance alone are effectively zero, so hitting the cap means a real
# regression, not bad luck.
const MAX_ATTEMPTS := 200

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

# The one probabilistic case - retries until GUARDED_ENCOUNTER_CHANCE rolls
# true or MAX_ATTEMPTS is exhausted. Runs as its own deferred pass (not
# inline in frame 2) so nothing here has to fight the SceneTree's own
# _process cadence for the awaits _on_special_encounter_diver_chosen()'s
# battle construction needs.
func _run_probabilistic_checks() -> void:
	for entry_value in ItemGuardian.spots():
		var entry := entry_value as Dictionary
		var item_id := String(entry.item)
		var expected_enemy := String(entry.get("enemy", "angler"))
		var opened := false
		var d: Diver
		for attempt in range(MAX_ATTEMPTS):
			world.revealed_key_items.assign([item_id])
			world.key_items.clear()
			d = _trigger_encounter_at(entry.at as Vector3)
			if world.special_encounter_prompt.visible and world._special_encounter_item == item_id:
				opened = true
				break
		if not opened:
			findings.append("NEVER OPENS: %d attempts inside the revealed %s circle never opened the special encounter" % [MAX_ATTEMPTS, item_id])
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
	_report()

func _report() -> void:
	for f in findings:
		print("FINDING  " + f)
	print("ENCOUNTERS: clean" if findings.is_empty() else "ENCOUNTERS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
