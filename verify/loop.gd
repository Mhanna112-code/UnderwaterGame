# Does the whole loop close without a human?
#
# Swim to the guarded salvage, get taken into the fight, win it with the
# bot, come back to a site with one less thing guarding it. Every one of
# those seams is a place where a scene swap can leave two worlds alive, or
# none, and none of it shows up in a screenshot of either end.
#
# Usage: godot --headless --path . --script verify/loop.gd
extends SceneTree

# untyped on purpose: world is a script property, and reaching it
# through a statically typed Node reference returns null without an error,
# which read as "the world never came up" when it was right there
var game
var frames := 0
var stage := "swim"
var findings: Array = []
var swim_frames := 0
var battle_turns := 0
var outcome := ""

func _initialize() -> void:
	game = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(game)

func _process(_dt: float) -> bool:
	frames += 1
	if frames < 3:
		return false

	match stage:
		"swim":
			return _swim()
		"fight":
			return _fight()
		"back":
			return _back()
	return true

func _swim() -> bool:
	# check the battle FIRST: contact frees the overworld in the same frame
	# it starts the fight, so looking for the world first reports that it
	# vanished when what actually happened is that it handed over
	if game.get("battle") != null:
		print("contact    after %d physics frames" % swim_frames)
		stage = "fight"
		return false
	var w = game.get("world")
	if w == null:
		findings.append("NO OVERWORLD: the game came up with no world scene")
		return _report()
	if w.marks.is_empty():
		findings.append("NOTHING TO FIGHT: the site placed no enemies")
		return _report()
	# steer the player at the guarded salvage
	var target: Vector3 = (w.marks[0].node as Node3D).global_position
	var me: Vector3 = (w.divers[w.active] as Node3D).global_position
	var to := target - me
	w.scripted = true
	w.scripted_dir = Vector3(to.x, 0.0, to.z).normalized()
	w.scripted_rise = clampf(to.y * 0.5, -1.0, 1.0)
	swim_frames += 1

	if swim_frames > 2400:
		findings.append("NEVER MET IT: swam at the enemy for %d frames and no fight started" % swim_frames)
		return _report()
	return false

func _fight() -> bool:
	var b = game.get("battle")
	if b == null:
		if game.get("world") != null:
			stage = "back"
			return false
		findings.append("LIMBO: the battle ended and nothing came up in its place")
		return _report()
	var c: Combat = b.combat
	if c == null:
		return false
	if c.outcome != "ongoing":
		outcome = String(c.outcome)
		# the scene waits on a button; the gate is allowed to press it
		b.finished.emit(c.outcome)
		stage = "back"
		return false
	# the presentation gates input while the enemy swings, so wait it out
	if b._phase != "player":
		return false
	var acts: Array = Bots.legal(c)
	if acts.is_empty():
		b._end_turn()
		battle_turns += 1
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a: Dictionary = Bots.greedy(c, rng)
	if a.is_empty() or not Bots.apply(c, a):
		b._end_turn()
		battle_turns += 1
	if c.turn > 60:
		findings.append("FIGHT NEVER ENDS: 60 turns and still ongoing")
		return _report()
	return false

func _back() -> bool:
	if game.get("world") == null:
		return false      # deferred reopen has not run yet
	var w = game.get("world")
	print("battle     %s in %d turns" % [outcome if outcome != "" else "?", battle_turns])
	print("returned   overworld is back up, %d guard(s) still out there" % w.marks.size())
	if game.get("battle") != null:
		findings.append("TWO SCENES: the battle is still alive after returning to the world")
	# the map has several sites now, so a mark left over is expected. What
	# must be gone is the ONE that was just beaten.
	var still_there := false
	for m in w.marks:
		if String((m.site as Dictionary).guard) == "grunt_shallows":
			still_there = true
	if outcome == "victory" and still_there:
		findings.append("WON AND STILL GUARDED: the guard we beat is back on its site")
	if outcome == "victory" and not bool(game.get("beaten").get("grunt_shallows", false)):
		findings.append("WIN NOT RECORDED: beating the grunt did not stick")
	return _report()

func _report() -> bool:
	for f in findings:
		print("FINDING  " + f)
	print("LOOP: clean" if findings.is_empty() else "LOOP: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
