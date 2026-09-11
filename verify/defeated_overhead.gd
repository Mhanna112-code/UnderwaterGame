# A defeated grunt fades out and frees its actor, while Battle keeps the
# combatant dictionary for result/XP accounting. The status card's own
# lifecycle must tolerate that split: no dead card may remain visible after
# the actor is gone. Status cards moved from floating per-frame-projected
# labels to fixed side-column cards (see battle.gd's _party_status_column/
# _enemy_status_column) - _refresh_bar() now hides entry.card directly the
# moment HP hits 0, rather than a separate per-frame layout pass doing it.
#
# Usage: godot --headless --path . --script verify/defeated_overhead.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var battle := Battle.new()
	root.add_child(battle)
	await process_frame

	if battle.enemies.is_empty():
		findings.append("SETUP: Battle did not create a grunt")
		_finish()
		return

	var enemy := battle.enemies[0] as Dictionary
	var actor := enemy.actor as Goblin
	var actor_ref: WeakRef = weakref(actor)
	var card := enemy.card as Control
	(enemy.stats as CombatantStats).hp = 0
	battle._refresh_bar(enemy)
	actor.play_death_fade()

	if card.visible:
		findings.append("DEAD CARD REMAINS: defeated grunt status card is still visible right after _refresh_bar()")

	# The fade lasts 0.9 seconds. Wait until its queued free has completed,
	# and confirm nothing brings the card back in the meantime - there's no
	# per-frame layout pass to re-hide it anymore, so this is really
	# checking that nothing else (the fade, the actor's own cleanup)
	# touches card.visible after _refresh_bar() already set it.
	await create_timer(1.1).timeout
	for _frame in range(6):
		await process_frame

	if actor_ref.get_ref() != null:
		findings.append("SETUP: defeated grunt actor did not finish its death fade")
	if card.visible:
		findings.append("DEAD CARD REMAINS: defeated grunt status card is visible again after the death fade")

	_finish()

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("DEFEATED OVERHEAD: clean" if findings.is_empty() else "DEFEATED OVERHEAD: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
