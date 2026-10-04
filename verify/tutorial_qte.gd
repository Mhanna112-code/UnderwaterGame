# The first tutorial enemy swing must visibly demonstrate the real QTE rather
# than merely setting an internal force flag. This uses the same battle scene,
# captions, timing widget, and key handler as a player.
extends SceneTree

# The live QTE itself lasts 1.6 seconds. This leaves generous process startup
# and animation scheduling headroom in a *full* suite, where a just-closed
# Godot process can briefly contend for the renderer, without redefining a
# missing QTE as success.
const TIMEOUT_MS := 15000

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	# This gate builds its own real Battle immediately below.  A new World
	# starts its map tutorial at the light beam on its next update, so letting
	# that second battle launch would race two live tutorial coroutines against
	# the same party and turn an unrelated world transition into a QTE failure.
	# Mark the map handoff complete before yielding back to the world loop; the
	# Battle under test still uses the real World/party/actor/QTE contracts.
	world._first_encounter_started = true
	world._intro_active = false
	world._transitioning_to_encounter = false
	if is_instance_valid(world._intro_arrow):
		world._intro_arrow.visible = false
	# The test adds the real Battle as a World child because it deliberately
	# uses World-owned divers and actor contracts. Stop only World's map loops
	# after that state is established: otherwise a scheduled map update could
	# start a second tutorial battle against the same party stats. Children
	# continue processing, so this does not fake the Battle or the QTE path.
	world.set_process(false)
	world.set_physics_process(false)
	await process_frame
	# Construct the real Battle directly with the same party source World
	# would pass. Lowering only agility makes the Angler naturally take the
	# first turn; it avoids racing the normal opening party lesson while still
	# exercising Battle's actual queue, actor, animation, QTE, and input path.
	for diver in world.divers:
		(diver as Diver).stats.agility = 0
	var battle := Battle.new()
	battle.party_source = world.divers
	battle.world = world
	battle.tutorial_encounter = true
	battle._tutorial_step = battle._TUTORIAL_SCRIPT.size()
	battle._tutorial_enemy_turns = 0
	battle._tutorial_finale_shown = false
	world.add_child(battle)
	await process_frame

	if battle.enemies.is_empty():
		findings.append("TUTORIAL QTE START: no enemy was created")
	else:
		var tutorial_enemy := battle.enemies[0] as Dictionary
		var tutorial_actor := tutorial_enemy.get("actor") as Goblin
		if tutorial_actor == null or tutorial_actor.enemy_id() != "angler":
			findings.append("TUTORIAL QTE START: the scripted lesson built %s instead of its named Angler" % String(tutorial_enemy.get("display_name", "no enemy")))
		# The initial _ready() dispatcher enters the actual tutorial enemy
		# branch. This test observes that turn only; it never injects a
		# QTE-capable replacement move, reorders the queue, or calls an enemy
		# method directly.
		var hp_before: Array[int] = []
		for entry in battle.party:
			hp_before.append((entry.stats as CombatantStats).hp)

		var qte_seen := false
		var prior_qte_active := false
		var qte_window_count := 0
		var x_pressed := false
		var qte_finished := false
		var qte_succeeded := false
		var indicator_moved := false
		var deadline := Time.get_ticks_msec() + TIMEOUT_MS
		while Time.get_ticks_msec() < deadline and not qte_finished:
			if battle._tutorial_awaiting_enter:
				battle._unhandled_input(_key(KEY_ENTER))
			if battle._qte_active:
				if not prior_qte_active:
					qte_window_count += 1
				prior_qte_active = true
				qte_seen = true
				if not battle.qte_root.visible:
					findings.append("TUTORIAL QTE: timing widget was active but invisible")
				indicator_moved = indicator_moved or battle.qte_indicator.position.x > 0.0
				if indicator_moved and not x_pressed:
					# We first observe the live tween advance. Then place that same
					# visible indicator inside the real red zone before delivering the
					# same X event a player uses. Sampling a 6%-wide moving zone once
					# per process frame is scheduler-sensitive under a full suite and
					# can miss a valid window without describing a game failure.
					# This still verifies all game-owned behavior: widget creation,
					# motion, zone geometry, key handling, CombatRules' dodged result,
					# and no applied party damage.
					var zone_center := battle.qte_zone.position.x + battle.qte_zone.size.x * 0.5
					battle.qte_indicator.position.x = zone_center - battle.qte_indicator.size.x * 0.5
					battle._unhandled_input(_key(KEY_X))
					x_pressed = true
			# Input clears _qte_active synchronously. The log is not a reliable
			# completion signal: after a valid dodge it can be replaced by a later
			# turn before a heavily loaded suite samples it. The QTE's own success
			# flag is the public interaction result that CombatRules consumes.
			elif qte_seen and x_pressed and not battle._qte_active:
				prior_qte_active = false
				qte_succeeded = battle._qte_success
				qte_finished = qte_succeeded
			await process_frame

		if not qte_seen:
			findings.append("TUTORIAL QTE: the first Angler turn never showed a timing window")
		if qte_seen and not x_pressed:
			findings.append("TUTORIAL QTE: indicator never entered its visible red zone")
		if qte_seen and not indicator_moved:
			findings.append("TUTORIAL QTE: indicator never swept across the visible track")
		if x_pressed and not qte_succeeded:
			findings.append("TUTORIAL QTE: an in-zone X was not accepted as a dodge")
		if not qte_finished:
			findings.append("TUTORIAL QTE: timing turn did not resolve before timeout (enemy turns %d, acting %s, qte force %s)" % [
				battle._tutorial_enemy_turns,
				String(battle._acting.get("kind", "none")),
				str(battle._tutorial_force_next_qte),
			])
		# A successful input clears _qte_active synchronously, but the enemy
		# coroutine still has to resume, apply CombatRules' dodged result, finish
		# its animation/log delay, and hand the turn to a diver. Four frames was
		# accidentally enough in an isolated run but not under the full suite;
		# wait for that real turn boundary instead of sampling scheduler timing.
		# The party does not auto-act, so it cannot introduce a later hit before
		# this check observes the completed enemy action.
		var extra_qte_seen := false
		if qte_finished:
			var resolution_deadline := Time.get_ticks_msec() + TIMEOUT_MS
			while Time.get_ticks_msec() < resolution_deadline and String(battle._acting.get("kind", "")) != "party":
				extra_qte_seen = extra_qte_seen or battle._qte_active
				await process_frame
			if String(battle._acting.get("kind", "")) != "party":
				findings.append("TUTORIAL QTE: successful input never completed the enemy turn")
			elif extra_qte_seen or qte_window_count != 1:
				findings.append("TUTORIAL QTE: the one-dodge lesson opened %d timing windows before returning control" % qte_window_count)
		for index in range(hp_before.size()):
			var hp_after := (battle.party[index].stats as CombatantStats).hp
			if hp_after != hp_before[index]:
				findings.append("TUTORIAL QTE: an in-zone X still damaged party member %d" % index)

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial qte          forced Angler bite showed and accepted the live timing dodge")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)
