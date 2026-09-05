# A defeated grunt fades out and frees its actor, while Battle keeps the
# combatant dictionary for result/XP accounting. The overhead-health layout
# must tolerate that lifecycle split: no dead bar may remain after the actor
# is gone, and repeated layout frames must stay safe.
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
	var overhead := enemy.overhead as Control
	(enemy.stats as CombatantStats).hp = 0
	battle._refresh_bar(enemy)
	overhead.visible = true
	actor.play_death_fade()

	# The fade lasts 0.9 seconds. Wait until its queued free has completed,
	# then let the real per-frame layout run several times.
	await create_timer(1.1).timeout
	for _frame in range(6):
		await process_frame

	if actor_ref.get_ref() != null:
		findings.append("SETUP: defeated grunt actor did not finish its death fade")
	if overhead.visible:
		findings.append("DEAD BAR REMAINS: defeated grunt overhead UI is still visible after its actor was freed")

	_finish()

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("DEFEATED OVERHEAD: clean" if findings.is_empty() else "DEFEATED OVERHEAD: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
