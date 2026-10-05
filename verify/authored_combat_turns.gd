extends SceneTree
## TURN-01/02: exercise Battle's real dispatcher, not a hand-counted stats helper.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 1.0 if "--capture-authored-turns" in OS.get_cmdline_user_args() else 8.0
	var sources: Array[Diver] = []
	for model in Cast.ALL:
		var diver := Diver.new()
		diver.model_name = model
		root.add_child(diver)
		diver.stats.agility = 100 - sources.size()
		sources.append(diver)
	var battle := Battle.new()
	battle.party_source = sources
	battle.ordinary_enemy_ids.assign(["angler"])
	root.add_child(battle)
	await process_frame
	# Known queue inputs isolate the turn boundary without allowing unrelated
	# enemy animation coroutines to race these dispatch assertions.
	for side in ["party", "enemy"]:
		for duration in range(1, 4):
			var victim: Dictionary = battle.party[0] if side == "party" else battle.enemies[0]
			var next: Dictionary = battle.party[1]
			var stats := victim.stats as CombatantStats
			stats.add_status("stun", 1, duration)
			stats.evasion_current = 0
			var before_hp := stats.hp
			var before_o2 := stats.oxygen
			for remaining in range(duration, 0, -1):
				battle._queue = [victim, next]
				battle._advance_turn()
				_expect(battle._acting == next and battle.main_menu.visible and not battle.attack_btn.disabled,
					"TURN-01 %s stun %d: real dispatch did not hand control to next healthy actor" % [side, remaining])
				_expect(stats.status_turns("stun") == remaining - 1,
					"TURN-02 %s stun did not consume exactly one scheduled turn" % side)
				_expect(stats.hp == before_hp and stats.oxygen == before_o2 and stats.evasion_current == 0,
					"TURN-02 skipped %s turn mutated HP/Oxygen/refilled EVA" % side)
				# On the red version an enemy action is asynchronous. Stop this
				# fixture immediately rather than fabricate a pass with concurrent turns.
				if battle._acting != next:
					_finish()
					return
			if side == "party":
				battle._queue = [victim, next]
				battle._advance_turn()
				_expect(battle._acting == victim and not battle.attack_btn.disabled,
					"TURN-02 expired stun did not restore usable player turn")
			print("STUN DISPATCH|side=%s|duration=%d|skips=%d|restored=true" % [side, duration, duration])
	# Forced tutorial initiative must not bypass the shared status boundary.
	battle.tutorial_encounter = true
	battle._tutorial_step = 1
	(battle.party[1].stats as CombatantStats).add_status("stun", 1, 1)
	battle._queue = [battle.party[0], battle.party[1], battle.party[2]]
	battle._advance_turn()
	_expect(battle._acting == battle.party[0] and not (battle.party[1].stats as CombatantStats).is_stunned(),
		"TURN-01 forced tutorial initiative bypassed stun skip")
	battle.tutorial_encounter = false
	battle.queue_free()
	for source in sources:
		source.queue_free()
	await process_frame
	await process_frame
	await _angler_cases()
	_finish()

func _angler_cases() -> void:
	var angler := Goblin.new()
	if not angler.has_method("choose_move_and_target") or not angler.has_method("record_damage_taken") or not angler.has_method("record_bite_result"):
		_expect(false, "AI-01/02 live enemy contract lost joint decision and damage/Bite history")
		angler.free()
		return
	var nodes: Array[Node] = [Node.new(), Node.new(), Node.new()]
	var party_entries: Array = []
	for actor in nodes:
		var stats := CombatantStats.new()
		stats.fill()
		party_entries.append({"actor": actor, "stats": stats})
	var self_stats := CombatantStats.new()
	self_stats.hp_max = 20
	self_stats.hp = 9
	angler.call("record_damage_taken", nodes[0], 2)
	angler.call("record_damage_taken", nodes[1], 4)
	angler.call("record_damage_taken", nodes[1], 3)
	var headbutts := 0
	for sample in range(128):
		seed(sample)
		var choice: Dictionary = angler.call("choose_move_and_target", self_stats, party_entries, party_entries[0], false)
		if String(choice.move.id) == "headbutt":
			headbutts += 1
			_expect(choice.target == party_entries[1], "AI-01 low-HP retaliation ignored cumulative largest damage")
	_expect(headbutts > 0 and headbutts < 128, "AI-01 low-HP retaliation lost authored probabilistic choice")
	# A dead/absent top dealer must never be selected; the largest remaining
	# living contributor wins. Exactly half HP is outside the priority band.
	for sample in range(32):
		seed(sample)
		var choice: Dictionary = angler.call("choose_move_and_target", self_stats, [party_entries[0], party_entries[2]], party_entries[2], false)
		if String(choice.move.id) == "headbutt":
			_expect(choice.target == party_entries[0], "AI-01 selected absent/dead top dealer")
	self_stats.hp = 10
	for sample in range(32):
		seed(sample)
		var choice: Dictionary = angler.call("choose_move_and_target", self_stats, party_entries, party_entries[0], false)
		_expect(String(choice.move.id) == "bite", "AI-01 priority fired at half HP without a Bite streak")
	for outcome in [true, true, false]:
		angler.call("record_bite_result", outcome)
	var before_threshold: Dictionary = angler.call("choose_move_and_target", self_stats, party_entries, party_entries[0], false)
	_expect(String(before_threshold.move.id) == "bite", "AI-02 Flash triggered before misses caught hits")
	angler.call("record_bite_result", false)
	var flash: Dictionary = angler.call("choose_move_and_target", self_stats, party_entries, party_entries[0], false)
	var reset: Dictionary = angler.call("choose_move_and_target", self_stats, party_entries, party_entries[0], false)
	_expect(String(flash.move.id) == "flash_blast" and String(reset.move.id) == "bite", "AI-02 missed Bite streak did not schedule and consume exactly one Flash")
	self_stats.hp = 1
	angler.call("record_bite_result", false)
	for sample in range(16):
		seed(sample)
		var choice: Dictionary = angler.call("choose_move_and_target", self_stats, party_entries, party_entries[2], true)
		_expect(choice.target == party_entries[2], "AI-03 forced tutorial/prologue target overridden")
		seed(sample)
		var original := angler.choose_move(party_entries[2].stats)
		_expect(String(choice.move.id) == String(original.id), "AI-03 forced choreography changed weighted move selection")
	for other in [SwordDuelist.new(), FrilledShark.new(), BombBot.new(), SwordSlayer.new()]:
		seed(127)
		var choice: Dictionary = other.choose_move_and_target(self_stats, party_entries, party_entries[2], false)
		seed(127)
		_expect(choice.target == party_entries[2] and String(choice.move.id) == String(other.choose_move(party_entries[2].stats).id), "AI-03 Angler policy leaked into another species")
		other.free()
	angler.free()
	var fresh := Goblin.new()
	self_stats.hp = 20
	var fresh_choice := fresh.choose_move_and_target(self_stats, party_entries, party_entries[0], false)
	_expect(String(fresh_choice.move.id) == "bite", "AI-02 Bite history leaked into a fresh fight")
	fresh.free()
	for actor in nodes:
		actor.free()
	print("ANGLER PROPERTIES|seeds=128|low_hp_headbutts=%d|streak_reset=true|forced_species_preserved=true" % headbutts)
	await _live_angler_history()

func _live_angler_history() -> void:
	var sources: Array[Diver] = []
	for model in Cast.ALL:
		var diver := Diver.new()
		diver.model_name = model
		root.add_child(diver)
		diver.stats.agility = 100 - sources.size()
		sources.append(diver)
	var battle := Battle.new()
	battle.party_source = sources
	battle.ordinary_enemy_ids.assign(["angler", "angler"])
	root.add_child(battle)
	await process_frame
	var enemy: Dictionary = battle.enemies[0]
	var enemy_stats := enemy.stats as CombatantStats
	enemy_stats.hp_max = 100
	enemy_stats.hp = 100
	enemy_stats.defense = 0
	enemy_stats.evasion_current = 0
	var second: Dictionary = battle.enemies[1]
	(second.stats as CombatantStats).hp_max = 100
	(second.stats as CombatantStats).hp = 100
	(second.stats as CombatantStats).evasion_current = 0
	var dealt: Array[int] = []
	for move_name in ["Multiple Knee Combo", "Precise Tap"]:
		var before := enemy_stats.hp
		battle.attack_btn.pressed.emit()
		await process_frame
		var chosen := false
		for button in battle.move_buttons:
			if (button as Button).text.get_slice("\n", 0) == move_name:
				(button as Button).pressed.emit()
				chosen = true
				break
		_expect(chosen, "AI-01 live witness missing real move button " + move_name)
		await process_frame
		(battle.target_buttons[0] as Button).pressed.emit()
		var deadline := Time.get_ticks_msec() + 10000
		while battle._busy and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect(not battle._busy, "AI-01 live player turn timed out")
		dealt.append(before - enemy_stats.hp)
	_expect(dealt[1] > dealt[0] and dealt[0] > 0, "AI-01 independent damage witnesses do not distinguish largest dealer")
	enemy_stats.hp = 40
	var angler := enemy.actor as Goblin
	var observed := 0
	for sample in range(128):
		seed(sample)
		var choice: Dictionary = angler.call("choose_move_and_target", enemy_stats, battle.party, battle.party[0], false)
		if String(choice.move.id) == "headbutt":
			observed += 1
			_expect(choice.target == battle.party[1], "AI-01 real single/all-target button damage not recorded for retaliation")
	_expect(observed > 0, "AI-01 live damage produced no retaliation witness")
	(second.stats as CombatantStats).hp = 40
	for sample in range(32):
		seed(sample)
		var choice := (second.actor as Goblin).choose_move_and_target(second.stats, battle.party, battle.party[2], false)
		if String(choice.move.id) == "headbutt":
			_expect(choice.target == battle.party[0], "AI-01 all-target move only recorded first enemy's damage history")
	# Above half HP forces normal Bite; high EVA independently guarantees a
	# real resolved miss. Next action must visibly debuff ALL three divers.
	enemy_stats.hp = 80
	for entry in battle.party:
		(entry.stats as CombatantStats).evasion_current = 100
	var played: Array[String] = []
	angler.anim.animation_started.connect(func(clip: StringName) -> void: played.append(String(clip).to_lower()))
	var before_hp: Array[int] = []
	for entry in battle.party:
		before_hp.append((entry.stats as CombatantStats).hp)
	battle._queue = [battle.party[2]]
	await battle._do_enemy_turn(enemy)
	_expect(played.any(func(clip: String) -> bool: return "attack)bite" in clip), "AI-02 live enemy witness did not play Bite")
	for index in range(battle.party.size()):
		_expect((battle.party[index].stats as CombatantStats).hp == before_hp[index], "AI-02 high-EVA Bite witness unexpectedly dealt damage")
	for entry in battle.party:
		(entry.stats as CombatantStats).evasion_current = 0
	battle._queue = [battle.party[2]]
	await battle._do_enemy_turn(enemy)
	_expect(played.any(func(clip: String) -> bool: return "attack)shine" in clip), "AI-02 follow-up did not play authored Flash Blast")
	for entry in battle.party:
		_expect((entry.stats as CombatantStats).status_level("evasion_down") > 0, "AI-02 missed live Bite did not trigger party-wide Flash Blast")
	# Confirm Battle itself uses the joint selector (not just that the actor
	# can choose correctly when queried in isolation). Preserve production
	# RNG order: weighted default-target pick precedes the low-HP AI roll.
	enemy_stats.hp = 40
	var retaliation_seed := -1
	for sample in range(128):
		seed(sample)
		randf()
		var choice := angler.choose_move_and_target(enemy_stats, battle.party, battle.party[0], false)
		if String(choice.move.id) == "headbutt":
			retaliation_seed = sample
			break
	_expect(retaliation_seed >= 0, "AI-01 no seeded live Headbutt witness available")
	seed(retaliation_seed)
	battle._queue = [battle.party[0]]
	await battle._do_enemy_turn(enemy)
	_expect((battle.party[1].stats as CombatantStats).status_turns("stun") == 2,
		"AI-01 live low-HP enemy turn did not Headbutt its real largest dealer")
	_expect(not (battle.party[0].stats as CombatantStats).is_stunned() and not (battle.party[2].stats as CombatantStats).is_stunned(),
		"AI-01 live retaliation hit a different or additional diver")
	battle._queue = [battle.party[1], battle.party[0]]
	battle._advance_turn()
	_expect(battle._acting == battle.party[0] and (battle.party[1].stats as CombatantStats).status_turns("stun") == 1,
		"TURN-01 actual landed Headbutt did not skip the victim's next real turn")
	if "--capture-authored-turns" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png("res://docs/evidence/authored-combat-turns/stun-skip.png") == OK,
			"TURN-01 could not capture the actual stunned-victim/next-actor presentation")
	print("ANGLER LIVE|button_damage=%s|retaliation=%d|miss_then_party_flash=true" % [str(dealt), observed])
	battle.queue_free()
	for source in sources:
		source.queue_free()
	await process_frame
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	Engine.time_scale = 1.0
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("AUTHORED COMBAT TURNS: clean" if findings.is_empty() else "AUTHORED COMBAT TURNS: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)
