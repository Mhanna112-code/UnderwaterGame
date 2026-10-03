# Seeded policy gate for the two authored laboratory blockers.
#
# Usage: godot --headless --path . --script verify/deep_zone_blocker_balance.gd
extends SceneTree

const SEEDS := 400
const MAX_ROUNDS := 30
const CASUAL_FIGHT_MIN := 60.0
const SKILLED_FIGHT_MIN := 80.0
const CASUAL_SEQUENCE_MIN := 50.0
const SKILLED_SEQUENCE_MIN := 75.0
const MIN_SKILLED_HP_ADVANTAGE := 4.0
const MIN_SEQUENCE_HP_LOSS := 2.0

var findings: Array[String] = []

func _init() -> void:
	var results := {}
	for policy in ["casual", "skilled"]:
		for blocker_id in ["bomb_bot", "sword_slayer"]:
			results["%s:%s" % [policy, blocker_id]] = _measure_single(policy, blocker_id)
		results["%s:sequence" % policy] = _measure_sequence(policy)

	for key_value in results.keys():
		var key := String(key_value)
		var result := results[key] as Dictionary
		print("%-24s %5.1f%% wins  %4.1f rounds  %4.1f HP lost" % [key, result.rate, result.rounds, result.hp_lost])

	for blocker_id in ["bomb_bot", "sword_slayer"]:
		var casual := results["casual:%s" % blocker_id] as Dictionary
		var skilled := results["skilled:%s" % blocker_id] as Dictionary
		_expect(float(casual.rate) >= CASUAL_FIGHT_MIN,
			"DZ-BAL-001: casual %s win rate %.1f%% is below %.0f%%" % [blocker_id, casual.rate, CASUAL_FIGHT_MIN])
		_expect(float(skilled.rate) >= SKILLED_FIGHT_MIN,
			"DZ-BAL-001: skilled %s win rate %.1f%% is below %.0f%%" % [blocker_id, skilled.rate, SKILLED_FIGHT_MIN])

	var casual_sequence := results["casual:sequence"] as Dictionary
	var skilled_sequence := results["skilled:sequence"] as Dictionary
	_expect(float(casual_sequence.rate) >= CASUAL_SEQUENCE_MIN,
		"DZ-BAL-002: casual two-blocker completion %.1f%% is below %.0f%%" % [casual_sequence.rate, CASUAL_SEQUENCE_MIN])
	_expect(float(skilled_sequence.rate) >= SKILLED_SEQUENCE_MIN,
		"DZ-BAL-002: skilled two-blocker completion %.1f%% is below %.0f%%" % [skilled_sequence.rate, SKILLED_SEQUENCE_MIN])
	# Mandatory blockers are allowed to be broadly winnable. Skill should pay
	# in resources even when it does not need to manufacture extra losses.
	_expect(float(casual_sequence.hp_lost) - float(skilled_sequence.hp_lost) >= MIN_SKILLED_HP_ADVANTAGE,
		"DZ-BAL-003: skilled policy saves only %.1f HP, expected at least %.0f" % [float(casual_sequence.hp_lost) - float(skilled_sequence.hp_lost), MIN_SKILLED_HP_ADVANTAGE])
	_expect(float(skilled_sequence.hp_lost) >= MIN_SEQUENCE_HP_LOSS,
		"DZ-BAL-004: skilled sequence costs only %.1f HP, expected at least %.0f" % [skilled_sequence.hp_lost, MIN_SEQUENCE_HP_LOSS])

	for finding in findings:
		print("FINDING  " + finding)
	print("DEEP ZONE BLOCKER BALANCE: clean" if findings.is_empty() else "DEEP ZONE BLOCKER BALANCE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _measure_single(policy: String, blocker_id: String) -> Dictionary:
	var wins := 0
	var rounds := 0.0
	var hp_lost := 0.0
	for seed_value in range(SEEDS):
		var result := _fight(_party(), blocker_id, policy, 710000 + seed_value)
		if bool(result.win):
			wins += 1
			rounds += float(result.rounds)
			hp_lost += float(result.hp_lost)
	return _metric(wins, rounds, hp_lost)

func _measure_sequence(policy: String) -> Dictionary:
	var wins := 0
	var rounds := 0.0
	var hp_lost := 0.0
	for seed_value in range(SEEDS):
		var party := _party()
		var first := _fight(party, "bomb_bot", policy, 810000 + seed_value)
		if not bool(first.win):
			continue
		for entry_value in party:
			(entry_value as Dictionary).stats.recover_after_victory()
		var second := _fight(party, "sword_slayer", policy, 910000 + seed_value)
		if bool(second.win):
			wins += 1
			rounds += float(first.rounds) + float(second.rounds)
			hp_lost += float(first.hp_lost) + float(second.hp_lost)
	return _metric(wins, rounds, hp_lost)

func _metric(wins: int, round_total: float, hp_total: float) -> Dictionary:
	return {
		"rate": 100.0 * float(wins) / float(SEEDS),
		"rounds": round_total / float(maxi(1, wins)),
		"hp_lost": hp_total / float(maxi(1, wins)),
	}

func _fight(party: Array, blocker_id: String, policy: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var enemy_actor: Goblin = BombBot.new() if blocker_id == "bomb_bot" else SwordSlayer.new()
	var enemy := {
		"kind": "enemy",
		"enemy_id": blocker_id,
		"stats": enemy_actor.make_stats(_average(party), 1),
		"moves": enemy_actor.available_moves(),
	}
	enemy_actor.free()
	var starting_hp := _party_hp(party)
	var rounds := 0
	while not _living(party).is_empty() and (enemy.stats as CombatantStats).hp > 0 and rounds < MAX_ROUNDS:
		rounds += 1
		var queue: Array = _living(party)
		queue.append(enemy)
		queue.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_stats := left.stats as CombatantStats
			var right_stats := right.stats as CombatantStats
			if left_stats.effective_agility() == right_stats.effective_agility():
				return String(left.kind) == "party"
			return left_stats.effective_agility() > right_stats.effective_agility())
		for actor_value in queue:
			var actor := actor_value as Dictionary
			var stats := actor.stats as CombatantStats
			if stats.hp <= 0 or (enemy.stats as CombatantStats).hp <= 0 or _living(party).is_empty():
				continue
			if stats.is_stunned():
				stats.consume_status_turn("stun")
				continue
			stats.begin_turn()
			if String(actor.kind) == "party":
				_party_turn(actor, enemy, policy, rng)
			else:
				_enemy_turn(enemy, party, rng)
			stats.end_turn()
	var won := (enemy.stats as CombatantStats).hp <= 0
	return {"win": won, "rounds": rounds, "hp_lost": starting_hp - _party_hp(party)}

func _party_turn(actor: Dictionary, enemy: Dictionary, policy: String, rng: RandomNumberGenerator) -> void:
	if policy == "casual" and rng.randf() < 0.10:
		return
	var moves := (Battle.BASE_MOVES[String(actor.model)] as Array).filter(func(move: Dictionary) -> bool:
		return float(move.get("oxygen_cost", 0.0)) <= (actor.stats as CombatantStats).oxygen and _raw_power(actor.stats, move) > 0)
	if moves.is_empty():
		return
	var move := moves[0] as Dictionary
	if policy == "skilled":
		var best_score := -INF
		for candidate_value in moves:
			var candidate := candidate_value as Dictionary
			var score := _predicted_damage(actor.stats as CombatantStats, enemy.stats as CombatantStats, candidate)
			if score > best_score:
				best_score = score
				move = candidate
	elif rng.randf() >= 0.70:
		move = moves[rng.randi_range(0, moves.size() - 1)] as Dictionary
	(actor.stats as CombatantStats).oxygen -= float(move.get("oxygen_cost", 0.0))
	_apply_player_move(actor.stats as CombatantStats, enemy.stats as CombatantStats, move, rng)

func _enemy_turn(enemy: Dictionary, party: Array, rng: RandomNumberGenerator) -> void:
	var live_party := _living(party)
	if live_party.is_empty():
		return
	var primary := live_party[rng.randi_range(0, live_party.size() - 1)] as Dictionary
	var move := _weighted_move(enemy.moves as Array, rng)
	var targets := Battle.enemy_targets_for_scope(primary, live_party, String(move.get("target", "single")))
	var apply_self := true
	for target_value in targets:
		Battle.resolve_formula_hits(enemy.stats as CombatantStats, (target_value as Dictionary).stats as CombatantStats,
			move.combat as Dictionary, apply_self)
		apply_self = false

func _weighted_move(moves: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for move_value in moves:
		total += float((move_value as Dictionary).get("weight", 0.0))
	var roll := rng.randf() * total
	for move_value in moves:
		var move := move_value as Dictionary
		roll -= float(move.get("weight", 0.0))
		if roll <= 0.0:
			return move
	return moves.back() as Dictionary

func _apply_player_move(attacker: CombatantStats, defender: CombatantStats, move: Dictionary, rng: RandomNumberGenerator) -> void:
	if move.has("formula"):
		CombatRules.resolve(attacker, defender, move)
		return
	if attacker.effective_accuracy() + int(move.get("acc_mod", 0)) <= defender.evasion_current:
		defender.spend_evasion(attacker.effective_accuracy() + int(move.get("acc_mod", 0)))
		return
	Battle.apply_damage_roll(attacker, defender, move, rng.randf_range(0.85, 1.15))

func _predicted_damage(attacker: CombatantStats, defender: CombatantStats, move: Dictionary) -> float:
	if attacker.effective_accuracy() + int(move.get("acc_mod", 0)) <= defender.evasion_current:
		return 0.0
	return float(maxi(1, _raw_power(attacker, move) - defender.effective_defense())) - float(move.get("oxygen_cost", 0.0)) * 0.02

func _raw_power(attacker: CombatantStats, move: Dictionary) -> int:
	return CombatRules.formula_value(attacker, move.formula) if move.has("formula") else int(move.get("power", 0)) + attacker.strength

func _party() -> Array:
	var out: Array = []
	for model_value in Battle.DISPLAY_NAMES.keys():
		var model := String(model_value)
		var base := Diver.BASE_STATS[model] as Dictionary
		var stats := CombatantStats.new()
		stats.hp_max = int(base.hp)
		stats.strength = int(base.strength)
		stats.defense = int(base.defense)
		stats.agility = int(base.agility)
		stats.evasion = int(base.evasion)
		stats.accuracy = int(base.accuracy)
		stats.fill()
		out.append({"kind": "party", "model": model, "stats": stats})
	return out

func _average(party: Array) -> CombatantStats:
	var stats := CombatantStats.new()
	stats.hp_max = 10
	stats.strength = 2
	stats.defense = 2
	stats.agility = 2
	stats.evasion = 2
	stats.accuracy = 2
	stats.fill()
	return stats

func _living(party: Array) -> Array:
	return party.filter(func(entry: Dictionary) -> bool: return (entry.stats as CombatantStats).hp > 0)

func _party_hp(party: Array) -> int:
	var total := 0
	for entry_value in party:
		total += (entry_value as Dictionary).stats.hp
	return total

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
