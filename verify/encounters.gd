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

func _initialize() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames == 2:
		_check_spawned()
		_check_spots_are_reachable()
		# Ordinary encounters first: open water, and then standing right on
		# a guarded spot, which must still be an ordinary encounter.
		cases.append({"at": Vector3(0.0, 2.0, 0.0), "what": "open water", "reward": "", "kind": "encounter"})
		for s in ItemGuardian.spots():
			cases.append({"at": s.at as Vector3, "what": "the %s spot" % String(s.item),
				"reward": "", "kind": "encounter"})
		# Then walking into each guardian, which must not be ordinary.
		for s in ItemGuardian.spots():
			cases.append({"at": s.at as Vector3, "what": "the %s guardian" % String(s.item),
				"reward": String(s.item), "kind": "guardian"})
		return false

	if at >= 0:
		_check_result()
	at += 1
	if at >= cases.size():
		return _report()
	_run(cases[at] as Dictionary)
	return false

# The bug that started all of this: the spawner ran and built nothing.
func _check_spawned() -> void:
	var guardians: Array = []
	var decoys := 0
	for c in world.get_children():
		if c is ItemGuardian:
			guardians.append(String((c as ItemGuardian).item_id))
		elif c is Goblin:
			decoys += 1
	print("built: %d guardian(s) %s, %d decoy(s)" % [guardians.size(), guardians, decoys])
	if guardians.size() != ItemGuardian.spots().size():
		findings.append("NOTHING TO SWIM TO: %d guardians in the water, expected %d" % [
			guardians.size(), ItemGuardian.spots().size()])
	if decoys < guardians.size():
		findings.append("UNGUARDED: %d guardians but only %d visible enemies beside them" % [
			guardians.size(), decoys])

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
		# Walk into it the way a player does, rather than calling the
		# handler: a guardian whose Area3D never fires is exactly the bug
		# this is here to catch.
		d.force_update_transform()
		for c in world.get_children():
			if c is ItemGuardian and (c as ItemGuardian).item_id == expect_reward:
				(c as Area3D).body_entered.emit(d)

func _check_result() -> void:
	var spot: Dictionary = cases[at] as Dictionary
	var battles := 0
	for c in world.get_children():
		if c is Battle:
			battles += 1
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

func _report() -> bool:
	for f in findings:
		print("FINDING  " + f)
	print("ENCOUNTERS: clean" if findings.is_empty() else "ENCOUNTERS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
