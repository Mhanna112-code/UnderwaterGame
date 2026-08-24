# Does the current fight have a difficulty curve, rather than an automatic
# win or an unwinnable wall?
#
# Issue #24 asked for the combat-core policies to be ported. That branch's
# simulator models limbs and five stations, systems that no longer exist on
# main, so importing it would test a different game. This is the equivalent
# gate for the live stats-and-moves battle: the roster, moves, enemy scaling,
# damage/mitigation function and enemy heavy-hit constants all come from the
# production classes. Only policy and seeded random inputs live here.
#
# Usage: godot --headless --path . --script verify/balance.gd
extends SceneTree

const SEEDS := 120
const MAX_ROUNDS := 40

# Broad invariant bands, fixed before looking at the result. A careless
# player must sometimes win and sometimes lose; the greedy policy must improve
# on it; and a greedy win still has to cost time and HP.
const CASUAL_MIN := 20.0
const CASUAL_MAX := 90.0
const GREEDY_MIN := 55.0
const GREEDY_TURN_FLOOR := 3.0
const GREEDY_HP_FLOOR := 5.0

var findings: Array = []

func _init() -> void:
	var casual := _run_policy("casual")
	var greedy := _run_policy("greedy")
	_print_result("casual", casual)
	_print_result("greedy", greedy)

	if float(casual.rate) < CASUAL_MIN or float(casual.rate) > CASUAL_MAX:
		findings.append("CASUAL OUT OF BAND: %.1f%% wins, expected %.0f-%.0f%%" % [casual.rate, CASUAL_MIN, CASUAL_MAX])
	if float(greedy.rate) < GREEDY_MIN:
		findings.append("GREEDY TOO WEAK: %.1f%% wins, expected at least %.0f%%" % [greedy.rate, GREEDY_MIN])
	if float(greedy.rate) <= float(casual.rate):
		findings.append("NO SKILL CURVE: greedy %.1f%% does not beat casual %.1f%%" % [greedy.rate, casual.rate])
	if float(greedy.turns) < GREEDY_TURN_FLOOR:
		findings.append("FIGHT TOO SHORT: greedy wins average %.1f rounds, expected at least %.0f" % [greedy.turns, GREEDY_TURN_FLOOR])
	if float(greedy.hp) < GREEDY_HP_FLOOR:
		findings.append("NO PRESSURE: greedy wins lose only %.1f party HP, expected at least %.0f" % [greedy.hp, GREEDY_HP_FLOOR])

	for f in findings:
		print("FINDING  " + f)
	print("BALANCE: clean" if findings.is_empty() else "BALANCE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _run_policy(policy: String) -> Dictionary:
	var wins := 0
	var rounds_on_wins := 0.0
	var hp_lost_on_wins := 0.0
	var by_count := {1: [0, 0], 2: [0, 0], 3: [0, 0]}
	for seed_value in range(SEEDS):
		var result := _fight(seed_value, policy)
		var count := int(result.enemies)
		(by_count[count] as Array)[1] += 1
		if bool(result.win):
			wins += 1
			(by_count[count] as Array)[0] += 1
			rounds_on_wins += float(result.rounds)
			hp_lost_on_wins += float(result.hp_lost)
	return {
		"rate": 100.0 * float(wins) / float(SEEDS),
		"turns": rounds_on_wins / float(maxi(wins, 1)),
		"hp": hp_lost_on_wins / float(maxi(wins, 1)),
		"by_count": by_count,
	}

func _fight(seed_value: int, policy: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var party := _party()
	var enemy_count := rng.randi_range(Battle.MIN_ENEMIES, Battle.MAX_ENEMIES)
	var enemies: Array = []
	var reference := _average(party)
	for _i in range(enemy_count):
		enemies.append(_enemy(reference, rng))

	var rounds := 0
	while not _living(party).is_empty() and not _living(enemies).is_empty() and rounds < MAX_ROUNDS:
		rounds += 1
		var queue: Array = []
		queue.append_array(_living(party))
		queue.append_array(_living(enemies))
		queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var sa := a.stats as CombatantStats
			var sb := b.stats as CombatantStats
			if sa.agility == sb.agility:
				return String(a.kind) == "party" and String(b.kind) != "party"
			return sa.agility > sb.agility)
		for actor in queue:
			if (actor.stats as CombatantStats).hp <= 0:
				continue
			if _living(party).is_empty() or _living(enemies).is_empty():
				break
			if String(actor.kind) == "party":
				_party_turn(actor, party, enemies, policy, rng)
			else:
				_enemy_turn(actor, party, policy, rng)

	var hp_lost := 0
	for actor in party:
		var stats := actor.stats as CombatantStats
		hp_lost += stats.hp_max - stats.hp
	return {"win": _living(enemies).is_empty(), "rounds": rounds, "hp_lost": hp_lost, "enemies": enemy_count}

func _party_turn(actor: Dictionary, party: Array, enemies: Array, policy: String, rng: RandomNumberGenerator) -> void:
	var live_enemies := _living(enemies)
	if live_enemies.is_empty():
		return
	if policy == "casual" and rng.randf() < 0.12:
		return

	var target: Dictionary
	if policy == "greedy":
		target = live_enemies[0]
		for enemy in live_enemies:
			if (enemy.stats as CombatantStats).hp < (target.stats as CombatantStats).hp:
				target = enemy
	else:
		target = live_enemies[rng.randi_range(0, live_enemies.size() - 1)]

	var moves: Array = Battle.BASE_MOVES[String(actor.model)]
	var affordable: Array = moves.filter(func(mv: Dictionary) -> bool:
		return float(mv.get("oxygen_cost", 0.0)) <= (actor.stats as CombatantStats).oxygen)
	var move: Dictionary
	if policy == "greedy":
		move = _best_move(actor.stats as CombatantStats, target.stats as CombatantStats, affordable)
	else:
		# A novice usually presses the first damaging button, but sometimes
		# experiments with another affordable attack.
		var damaging := affordable.filter(func(mv: Dictionary) -> bool: return int(mv.get("power", 0)) > 0)
		if damaging.is_empty():
			return
		move = damaging[0] if rng.randf() < 0.7 else damaging[rng.randi_range(0, damaging.size() - 1)]

	(actor.stats as CombatantStats).oxygen -= float(move.get("oxygen_cost", 0.0))
	_apply_move(actor.stats as CombatantStats, target.stats as CombatantStats, move, rng)

func _best_move(attacker: CombatantStats, defender: CombatantStats, moves: Array) -> Dictionary:
	var best := {}
	var best_score := -1.0
	for move in moves:
		var score := -0.5
		if String(move.get("debuff", "")) == "defense" and defender.defense > 0:
			score = 3.0 + float(defender.defense)
		elif int(move.get("power", 0)) > 0 and attacker.accuracy + int(move.get("acc_mod", 0)) > defender.evasion:
			score = float(move.power) + float(attacker.strength) - float(defender.defense)
			# Oxygen is finite: prefer the free move when two choices are close.
			score -= float(move.get("oxygen_cost", 0.0)) * 0.08
		if score > best_score:
			best_score = score
			best = move
	return best

func _apply_move(attacker: CombatantStats, defender: CombatantStats, move: Dictionary, rng: RandomNumberGenerator) -> void:
	if attacker.accuracy + int(move.get("acc_mod", 0)) <= defender.evasion:
		return
	var debuff := String(move.get("debuff", ""))
	if debuff == "defense":
		defender.defense = maxi(0, defender.defense - int(move.get("amount", 0)))
		return
	if debuff == "agility":
		defender.agility = maxi(1, defender.agility - int(move.get("amount", 0)))
		return
	Battle.apply_damage_roll(attacker, defender, move, rng.randf_range(0.85, 1.15))

func _enemy_turn(actor: Dictionary, party: Array, policy: String, rng: RandomNumberGenerator) -> void:
	var living_party := _living(party)
	if living_party.is_empty():
		return
	var target := living_party[rng.randi_range(0, living_party.size() - 1)] as Dictionary
	var target_stats := target.stats as CombatantStats
	var lined_up := float(target_stats.hp) <= float(target_stats.hp_max) * float(Battle.ENEMY_HEAVY_MOVE.heavy_max)
	var heavy := rng.randf() < (Battle.ENEMY_HEAVY_FINISH_CHANCE if lined_up else Battle.ENEMY_HEAVY_CHANCE)
	var move: Dictionary = Battle.ENEMY_HEAVY_MOVE if heavy else Battle.ENEMY_MOVE
	var variance := rng.randf_range(0.85, 1.15)
	var fraction := rng.randf_range(float(move.get("heavy_min", 0.25)), float(move.get("heavy_max", 0.5))) if heavy else 0.0
	# The action policies are what this gate compares. Both receive the same
	# no-QTE baseline so timing skill does not contaminate that comparison.
	Battle.apply_damage_roll(actor.stats as CombatantStats, target_stats, move, variance, fraction, false)

func _party() -> Array:
	var out: Array = []
	for model_name in Battle.DISPLAY_NAMES.keys():
		var base: Dictionary = Diver.BASE_STATS[model_name]
		var stats := CombatantStats.new()
		stats.hp_max = int(base.hp)
		stats.strength = int(base.strength)
		stats.defense = int(base.defense)
		stats.agility = int(base.agility)
		stats.evasion = int(base.evasion)
		stats.accuracy = int(base.accuracy)
		stats.barrier_max = int(base.barrier_max)
		stats.fill()
		out.append({"kind": "party", "model": String(model_name), "stats": stats})
	return out

func _average(party: Array) -> CombatantStats:
	var avg := CombatantStats.new()
	var n := float(party.size())
	avg.hp_max = int(round(party.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).hp_max, 0) / n))
	avg.strength = int(round(party.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).strength, 0) / n))
	avg.defense = int(round(party.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).defense, 0) / n))
	avg.agility = int(round(party.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).agility, 0) / n))
	avg.evasion = int(round(party.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).evasion, 0) / n))
	avg.accuracy = int(round(party.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).accuracy, 0) / n))
	avg.barrier_max = int(round(party.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).barrier_max, 0) / n))
	avg.fill()
	return avg

func _enemy(reference: CombatantStats, rng: RandomNumberGenerator) -> Dictionary:
	var stats := CombatantStats.new()
	stats.hp_max = maxi(Goblin.FLOOR_STATS.hp, int(round(float(reference.hp_max) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
	stats.strength = maxi(Goblin.FLOOR_STATS.strength, int(round(float(reference.strength) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
	stats.defense = maxi(Goblin.FLOOR_STATS.defense, int(round(float(reference.defense) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
	stats.agility = maxi(Goblin.FLOOR_STATS.agility, int(round(float(reference.agility) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
	stats.evasion = maxi(Goblin.FLOOR_STATS.evasion, int(round(float(reference.evasion) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
	stats.accuracy = maxi(Goblin.FLOOR_STATS.accuracy, int(round(float(reference.accuracy) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
	stats.barrier_max = maxi(0, int(round(float(reference.barrier_max) * 0.5 * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
	stats.fill()
	return {"kind": "enemy", "stats": stats}

func _living(side: Array) -> Array:
	return side.filter(func(actor: Dictionary) -> bool: return (actor.stats as CombatantStats).hp > 0)

func _print_result(label: String, result: Dictionary) -> void:
	var parts: Array = []
	for count in [1, 2, 3]:
		var cell := result.by_count[count] as Array
		parts.append("%d grunt %d/%d" % [count, int(cell[0]), int(cell[1])])
	print("%-7s %5.1f%% wins, %4.1f rounds, %4.1f HP lost  (%s)" % [label, result.rate, result.turns, result.hp, ", ".join(parts)])
