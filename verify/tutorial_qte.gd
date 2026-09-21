# The first tutorial enemy swing must visibly demonstrate the real QTE rather
# than merely setting an internal force flag. This uses the same battle scene,
# captions, timing widget, and key handler as a player.
extends SceneTree

const TIMEOUT_MS := 10000

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
		# The initial _ready() dispatcher enters the actual tutorial enemy
		# branch. This test observes that turn only; it never injects a
		# QTE-capable replacement move, reorders the queue, or calls an enemy
		# method directly.
		var hp_before: Array[int] = []
		for entry in battle.party:
			hp_before.append((entry.stats as CombatantStats).hp)

		var qte_seen := false
		var x_pressed := false
		var qte_finished := false
		var deadline := Time.get_ticks_msec() + TIMEOUT_MS
		while Time.get_ticks_msec() < deadline and not qte_finished:
			if battle._tutorial_awaiting_enter:
				battle._unhandled_input(_key(KEY_ENTER))
			if battle._qte_active:
				qte_seen = true
				if not battle.qte_root.visible:
					findings.append("TUTORIAL QTE: timing widget was active but invisible")
				if not x_pressed:
					var indicator_center := battle.qte_indicator.position.x + battle.qte_indicator.size.x * 0.5
					var zone_left := battle.qte_zone.position.x
					var zone_right := zone_left + battle.qte_zone.size.x
					if indicator_center >= zone_left and indicator_center <= zone_right:
						battle._unhandled_input(_key(KEY_X))
						x_pressed = true
			# qte_root hides as soon as the timing tween returns, slightly before
			# the enemy coroutine records the resolved combat result. Wait for
			# that player-visible result rather than racing a later turn.
			elif qte_seen and x_pressed and not battle.qte_root.visible and String(battle.log_label.text).contains("dodges clear"):
				qte_finished = true
			await process_frame

		if not qte_seen:
			findings.append("TUTORIAL QTE: the first Angler turn never showed a timing window")
		if qte_seen and not x_pressed:
			findings.append("TUTORIAL QTE: indicator never entered its visible red zone")
		if not qte_finished:
			findings.append("TUTORIAL QTE: timing turn did not resolve before timeout")
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
