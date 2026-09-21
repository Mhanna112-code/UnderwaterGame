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
const ROUTE_SEEDS := 240
const MAX_ROUNDS := 40

# Broad invariant bands, fixed before looking at the result. A careless
# player must sometimes win and sometimes lose; the skilled policy must improve
# on it; and a skilled win still has to cost time and HP.
const CASUAL_MIN := 20.0
# Level 1 now excludes the documented automatic-loss three-enemy wall, so the
# isolated legal-pack distribution is intentionally friendlier; still require
# at least a 5% novice failure tail rather than an automatic win.
const CASUAL_MAX := 95.0
const SKILLED_MIN := 55.0
# Dropped from 3.0: Glassgoat's authored Angler Fish base stats (see
# Goblin.FLOOR_STATS) put its HP floor at 5, below the 10-HP party's own
# average, so a skilled party's average HP (not the old 15-HP floor) now
# governs its actual rolled HP. A basic single-digit-HP fish dying to a
# skilled trio in under 3 rounds is the expected shape of the weakest
# ordinary enemy, not a balance regression - SKILLED_MIN/*_ROUTE_MIN above
# are what actually guard against a fight so easy it stops being one.
const SKILLED_TURN_FLOOR := 2.5
const SKILLED_HP_FLOOR := 5.0
const CASUAL_ROUTE_MIN := 50.0
const SKILLED_ROUTE_MIN := 80.0
const ROUTE_SKILL_GAP := 10.0

# Explicit policy assumptions, rather than silently treating every player as
# an automatic QTE failure. They are intentionally conservative fixed rates,
# not claims about measured human reaction time.
const CASUAL_QTE_DODGE := 0.30
const SKILLED_QTE_DODGE := 0.80

var findings: Array = []

func _init() -> void:
	var casual := _run_policy("casual")
	var skilled := _run_policy("skilled")
	_print_result("casual", casual)
	_print_result("skilled", skilled)
	var casual_route := _run_route_policy("casual")
	var skilled_route := _run_route_policy("skilled")
	_print_route("casual", casual_route)
	_print_route("skilled", skilled_route)

	if float(casual.rate) < CASUAL_MIN or float(casual.rate) > CASUAL_MAX:
		findings.append("CASUAL OUT OF BAND: %.1f%% wins, expected %.0f-%.0f%%" % [casual.rate, CASUAL_MIN, CASUAL_MAX])
	if float(skilled.rate) < SKILLED_MIN:
		findings.append("SKILLED TOO WEAK: %.1f%% wins, expected at least %.0f%%" % [skilled.rate, SKILLED_MIN])
	if float(skilled.rate) <= float(casual.rate):
		findings.append("NO SKILL CURVE: skilled %.1f%% does not beat casual %.1f%%" % [skilled.rate, casual.rate])
	var skilled_two_enemy_turns := _average_turns_for_count(skilled, 2)
	if skilled_two_enemy_turns < SKILLED_TURN_FLOOR:
		findings.append("FIGHT TOO SHORT: skilled two-enemy wins average %.1f rounds, expected at least %.1f" % [skilled_two_enemy_turns, SKILLED_TURN_FLOOR])
	if float(skilled.hp) < SKILLED_HP_FLOOR:
		findings.append("NO PRESSURE: skilled wins lose only %.1f party HP, expected at least %.0f" % [skilled.hp, SKILLED_HP_FLOOR])

	# A legal level-1 pack may be hard, but it cannot be an automatic loss for
	# the novice model hidden beneath a healthy aggregate headline.
	for count in casual.by_count:
		var cell := casual.by_count[count] as Array
		if int(cell[1]) > 0 and int(cell[0]) == 0:
			findings.append("CASUAL PACK WALL: 0/%d wins against %d enemies" % [int(cell[1]), int(count)])

	if float(casual_route.rate) < CASUAL_ROUTE_MIN:
		findings.append("CASUAL ROUTE BLOCKED: %.1f%% reach trench, expected at least %.0f%%" % [casual_route.rate, CASUAL_ROUTE_MIN])
	if float(skilled_route.rate) < SKILLED_ROUTE_MIN:
		findings.append("SKILLED ROUTE BLOCKED: %.1f%% reach trench, expected at least %.0f%%" % [skilled_route.rate, SKILLED_ROUTE_MIN])
	if float(skilled_route.rate) - float(casual_route.rate) < ROUTE_SKILL_GAP:
		findings.append("ROUTE SKILL CURVE: skilled %.1f%% vs casual %.1f%% is under %.0f points" % [skilled_route.rate, casual_route.rate, ROUTE_SKILL_GAP])

	for f in findings:
		print("FINDING  " + f)
	print("BALANCE: clean" if findings.is_empty() else "BALANCE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _run_policy(policy: String) -> Dictionary:
	var wins := 0
	var rounds_on_wins := 0.0
	var hp_lost_on_wins := 0.0
	var by_count := {1: [0, 0], 2: [0, 0], 3: [0, 0]}
	var turns_by_count := {1: [0.0, 0], 2: [0.0, 0], 3: [0.0, 0]}
	for seed_value in range(SEEDS):
		var result := _fight(seed_value, policy)
		var count := int(result.enemies)
		(by_count[count] as Array)[1] += 1
		if bool(result.win):
			wins += 1
			(by_count[count] as Array)[0] += 1
			(turns_by_count[count] as Array)[0] += float(result.rounds)
			(turns_by_count[count] as Array)[1] += 1
			rounds_on_wins += float(result.rounds)
			hp_lost_on_wins += float(result.hp_lost)
	return {
		"rate": 100.0 * float(wins) / float(SEEDS),
		"turns": rounds_on_wins / float(maxi(wins, 1)),
		"hp": hp_lost_on_wins / float(maxi(wins, 1)),
		"by_count": by_count,
		"turns_by_count": turns_by_count,
	}

func _run_route_policy(policy: String) -> Dictionary:
	var successes := 0
	var random_fights := 0
	var guardian_fights := 0
	var grunts := 0
	var battles_on_success := 0
	var hp_on_success := 0
	var level_on_success := 0
	var terminal_stages: Dictionary = {}
	for seed_value in range(ROUTE_SEEDS):
		var result := _route(seed_value, policy)
		var stage := String(result.get("terminal_stage", "unknown"))
		terminal_stages[stage] = int(terminal_stages.get(stage, 0)) + 1
		random_fights += int(result.random_fights)
		guardian_fights += int(result.guardian_fights)
		grunts += int(result.grunts)
		if bool(result.success):
			successes += 1
			battles_on_success += int(result.battles)
			hp_on_success += int(result.hp)
			level_on_success += int(result.level)
	return {
		"rate": 100.0 * float(successes) / float(ROUTE_SEEDS),
		"random_fights": float(random_fights) / float(ROUTE_SEEDS),
		"guardian_fights": float(guardian_fights) / float(ROUTE_SEEDS),
		"grunts": float(grunts) / float(ROUTE_SEEDS),
		"battles": float(battles_on_success) / float(maxi(successes, 1)),
		"hp": float(hp_on_success) / float(maxi(successes, 1)),
		"level": float(level_on_success) / float(maxi(successes, 1)),
		"terminal_stages": terminal_stages,
	}

# One production-shaped campaign: persistent party resources, the actual
# linked-site distances, Diver's distance-check order, ordinary random packs,
# and a guaranteed pack at each guarded artifact. No consumables or unearned
# between-fight healing are injected.
func _route(seed_value: int, policy: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100000 + seed_value
	var roster_rng := RandomNumberGenerator.new()
	roster_rng.seed = 900000 + seed_value
	var party := _party()
	var at: Vector3 = Sites.start().at as Vector3
	var next_check := rng.randf_range(8.0, 16.0)
	var random_fights := 0
	var guardian_fights := 0
	var grunts := 0
	var battles := 0
	var claimed_items: Array[String] = []

	for site_id in ["shallows", "trench"]:
		var site: Dictionary = Sites.by_id(site_id)
		var remaining := at.distance_to(site.at as Vector3)
		var segment_length := remaining
		var distance_along_segment := 0.0
		while remaining >= next_check:
			remaining -= next_check
			distance_along_segment += next_check
			# This is check_for_encounter()'s order: reset/draw the next
			# threshold, then roll whether this check becomes a fight.
			next_check = rng.randf_range(8.0, 16.0)
			var check_at := (at as Vector3).lerp(site.at as Vector3, minf(1.0, distance_along_segment / maxf(segment_length, 0.001)))
			# Mirrors World._on_encounter_triggered(): rolls that fall inside
			# an unclaimed guardian site consume their normal distance check but
			# do not launch a competing ordinary battle.
			if not _inside_unclaimed_guardian_site(check_at, claimed_items) and rng.randf() <= 0.5:
				var level := (party[0].stats as CombatantStats).level
				var count := Battle.ordinary_enemy_count_for_roll(level, rng.randf())
				var random_result := _fight_party(party, count, policy, rng, true, [], roster_rng)
				random_fights += 1
				battles += 1
				grunts += count
				if not bool(random_result.win):
					return _route_result(false, party, random_fights, guardian_fights, grunts, battles,
						"random:%s:%s" % [site_id, _enemy_label(random_result.enemy_ids as Array)])
		# Production retains the distance already swum toward the next check;
		# only the tiny per-frame overshoot at a fired check is discarded.
		next_check -= remaining

		# The visible guardian is a guaranteed one-enemy Battle. One actor on
		# the plinth cannot silently turn into an unrelated random pack.
		var guardian_count := Battle.max_enemies_for_level((party[0].stats as CombatantStats).level, true)
		var guardian_result := _fight_party(party, guardian_count, policy, rng, true, [String(site.enemy)], roster_rng)
		guardian_fights += 1
		battles += 1
		grunts += guardian_count
		if not bool(guardian_result.win):
			return _route_result(false, party, random_fights, guardian_fights, grunts, battles,
				"guardian:%s:%s" % [site_id, String(site.enemy)])
		claimed_items.append(String(site.item))
		at = site.at as Vector3

	return _route_result(true, party, random_fights, guardian_fights, grunts, battles, "success")

func _route_result(success: bool, party: Array, random_fights: int, guardian_fights: int, grunts: int, battles: int, terminal_stage: String) -> Dictionary:
	var hp := 0
	for actor in party:
		hp += (actor.stats as CombatantStats).hp
	return {
		"success": success,
		"random_fights": random_fights,
		"guardian_fights": guardian_fights,
		"grunts": grunts,
		"battles": battles,
		"hp": hp,
		"level": (party[0].stats as CombatantStats).level,
		"terminal_stage": terminal_stage,
	}

func _fight(seed_value: int, policy: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var roster_rng := RandomNumberGenerator.new()
	roster_rng.seed = 800000 + seed_value
	var party := _party()
	var enemy_count := Battle.ordinary_enemy_count_for_roll(1, rng.randf())
	return _fight_party(party, enemy_count, policy, rng, false, [], roster_rng)

func _fight_party(party: Array, enemy_count: int, policy: String, rng: RandomNumberGenerator, award_xp: bool, enemy_ids: Array = [], roster_rng: RandomNumberGenerator = null) -> Dictionary:
	if roster_rng == null:
		roster_rng = RandomNumberGenerator.new()
		roster_rng.randomize()
	var enemies: Array = []
	var resolved_ids: Array[String] = []
	var reference := _average(party)
	for i in range(enemy_count):
		var enemy_id := String(enemy_ids[i]) if i < enemy_ids.size() else EnemyRoster.id_for_roll(roster_rng.randf())
		enemies.append(_enemy(reference, rng, enemy_id))
		resolved_ids.append(enemy_id)

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
			var stats := actor.stats as CombatantStats
			if stats.hp <= 0:
				continue
			if _living(party).is_empty() or _living(enemies).is_empty():
				break
			if stats.is_stunned():
				# Mirrors Battle._advance_turn(): a stunned actor never reaches
				# begin_turn()/end_turn() at all, so Headbutt's Stun costs a
				# real tempo turn here too rather than reading as free damage.
				stats.consume_status_turn("stun")
				continue
			stats.begin_turn()
			if String(actor.kind) == "party":
				_party_turn(actor, party, enemies, policy, rng)
			else:
				_enemy_turn(actor, party, policy, rng)
			stats.end_turn()

	var hp_lost := 0
	for actor in party:
		var stats := actor.stats as CombatantStats
		hp_lost += stats.hp_max - stats.hp
	var won := _living(enemies).is_empty()
	if won and award_xp:
		var player_level := (party[0].stats as CombatantStats).level
		var per_grunt := maxi(1, int(round(float(Goblin.BASE_XP) * (1.0 + float(maxi(player_level - 1, 0)) * 0.12))))
		for actor in party:
			(actor.stats as CombatantStats).gain_xp(per_grunt * enemy_count)
		for actor in party:
			(actor.stats as CombatantStats).recover_after_victory()
	return {"win": won, "rounds": rounds, "hp_lost": hp_lost, "enemies": enemy_count, "enemy_ids": resolved_ids}

func _party_turn(actor: Dictionary, party: Array, enemies: Array, policy: String, rng: RandomNumberGenerator) -> void:
	var live_enemies := _living(enemies)
	if live_enemies.is_empty():
		return
	if policy == "casual" and rng.randf() < 0.12:
		return

	var target: Dictionary
	if policy == "skilled":
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
	if policy == "skilled":
		move = _best_move(actor.stats as CombatantStats, target.stats as CombatantStats, affordable)
	else:
		# A novice usually presses the first damaging button, but sometimes
		# experiments with another affordable attack. Formula-backed V2 moves
		# have no legacy `power` field; omitting them made the casual simulator
		# skip every Scuba turn and only went unnoticed while the other two
		# divers still carried their inflated prototype stats.
		var attacker_stats := actor.stats as CombatantStats
		var damaging := affordable.filter(func(mv: Dictionary) -> bool:
			return CombatRules.formula_value(attacker_stats, mv.get("formula", {})) > 0 if mv.has("formula") else int(mv.get("power", 0)) > 0)
		if damaging.is_empty():
			return
		move = damaging[0] if rng.randf() < 0.7 else damaging[rng.randi_range(0, damaging.size() - 1)]

	(actor.stats as CombatantStats).oxygen -= float(move.get("oxygen_cost", 0.0))
	if String(move.get("target", "one_enemy")) == "all_enemies":
		var first := true
		for enemy in live_enemies:
			var result := _apply_move(actor.stats as CombatantStats, enemy.stats as CombatantStats, move, rng, first)
			_record_damage_dealt(enemy, actor, result)
			first = false
	else:
		var result := _apply_move(actor.stats as CombatantStats, target.stats as CombatantStats, move, rng)
		_record_damage_dealt(target, actor, result)

# Mirrors Goblin.record_damage_taken() - keyed by model name (stable and
# unique per party slot here) rather than the actor Node production keys on,
# since this simulator's party entries never hold a real actor.
func _record_damage_dealt(enemy: Dictionary, attacker: Dictionary, result: Dictionary) -> void:
	if not (bool(result.get("hit", false)) and int(result.get("damage", 0)) > 0):
		return
	var by: Dictionary = enemy.get("damage_taken_by", {})
	var key := String(attacker.model)
	by[key] = int(by.get(key, 0)) + int(result.damage)
	enemy["damage_taken_by"] = by

func _best_move(attacker: CombatantStats, defender: CombatantStats, moves: Array) -> Dictionary:
	var best := {}
	var best_score := -1.0
	for move in moves:
		var score := -0.5
		if move.has("formula"):
			var raw := CombatRules.formula_value(attacker, move.get("formula", {}))
			var targets := 2.0 if String(move.get("target", "")) == "all_enemies" else 1.0
			score = float(raw) * targets + float((move.get("effects", []) as Array).size()) * 1.5
		elif String(move.get("debuff", "")) == "defense" and defender.defense > 0:
			score = 3.0 + float(defender.defense)
		elif int(move.get("power", 0)) > 0 and attacker.accuracy + int(move.get("acc_mod", 0)) > defender.evasion:
			score = float(move.power) + float(attacker.strength) - float(defender.defense)
			# Oxygen is finite: prefer the free move when two choices are close.
			score -= float(move.get("oxygen_cost", 0.0)) * 0.08
		if score > best_score:
			best_score = score
			best = move
	return best

func _apply_move(attacker: CombatantStats, defender: CombatantStats, move: Dictionary, rng: RandomNumberGenerator, apply_self_effects: bool = true) -> Dictionary:
	if move.has("formula"):
		return CombatRules.resolve(attacker, defender, move, apply_self_effects)
	if attacker.effective_accuracy() + int(move.get("acc_mod", 0)) <= defender.evasion_current:
		defender.spend_evasion(attacker.effective_accuracy() + int(move.get("acc_mod", 0)))
		return {"hit": false, "damage": 0}
	var debuff := String(move.get("debuff", ""))
	if debuff == "defense":
		defender.defense = maxi(0, defender.defense - int(move.get("amount", 0)))
		return {"hit": true, "damage": 0}
	if debuff == "agility":
		defender.agility = maxi(1, defender.agility - int(move.get("amount", 0)))
		return {"hit": true, "damage": 0}
	return Battle.apply_damage_roll(attacker, defender, move, rng.randf_range(0.85, 1.15))

func _enemy_turn(actor: Dictionary, party: Array, policy: String, rng: RandomNumberGenerator) -> void:
	var living_party := _living(party)
	if living_party.is_empty():
		return
	if String(actor.get("enemy_id", "angler")) == "angler":
		# Angler no longer picks moves through the generic weighted-random
		# _pick_enemy_move() below - see Goblin.choose_move_and_target() in
		# game/goblin.gd. Mirrored here rather than left on the old path, or
		# this gate would validate a route that production no longer runs.
		_angler_turn(actor, living_party, rng)
		return
	var target := _pick_enemy_target(living_party, rng)
	var target_stats := target.stats as CombatantStats
	var move := _pick_enemy_move(String(actor.get("enemy_id", "angler")), target_stats, rng)
	var combat := move.combat as Dictionary
	# Headbutt/Flash Blast (content/enemy_moves.gd) carry a "formula" key the
	# same way a player's V2 moves do - mirrors Battle._resolve_attack()'s own
	# dispatch, and _apply_move()'s above for the player side, so an enemy
	# formula move doesn't fall through to apply_damage_roll() below and read
	# a "power" key that formula-based moves never set.
	if combat.has("formula"):
		var targets := Battle.enemy_targets_for_scope(target, living_party, String(move.get("target", "single")))
		var apply_self_effects := true
		for target_entry in targets:
			Battle.resolve_formula_hits(actor.stats as CombatantStats, (target_entry as Dictionary).stats as CombatantStats, combat, apply_self_effects)
			apply_self_effects = false
		return
	var heavy := String(combat.get("effect", "")) == "heavy"
	var variance := rng.randf_range(0.85, 1.15)
	var fraction := rng.randf_range(float(combat.get("heavy_min", 0.25)), float(combat.get("heavy_max", 0.5))) if heavy else 0.0
	var dodge_rate := SKILLED_QTE_DODGE if policy == "skilled" else CASUAL_QTE_DODGE
	var player_dodge := heavy and rng.randf() < dodge_rate
	Battle.apply_damage_roll(actor.stats as CombatantStats, target_stats, combat, variance, fraction, player_dodge)

# Mirrors Goblin.choose_move_and_target()/record_bite_result() exactly - see
# that function's own comment in game/goblin.gd for the worked hit/miss
# examples this reproduces turn for turn.
func _angler_turn(actor: Dictionary, living_party: Array, rng: RandomNumberGenerator) -> void:
	var self_stats := actor.stats as CombatantStats
	var by_id := {}
	for move_value in EnemyMoves.angler_catalogue():
		by_id[String((move_value as Dictionary).id)] = move_value as Dictionary

	if float(self_stats.hp) < float(self_stats.hp_max) * Goblin.LOW_HP_FRACTION and rng.randf() < Goblin.STUN_PRIORITY_CHANCE:
		var headbutt := by_id.get("headbutt", {}) as Dictionary
		if not headbutt.is_empty():
			var stun_target := _highest_damage_target(actor, living_party, rng)
			CombatRules.resolve(self_stats, stun_target.stats as CombatantStats, headbutt.combat as Dictionary)
			return

	if bool(actor.get("use_flash_blast_next", false)):
		var flash := by_id.get("flash_blast", {}) as Dictionary
		if not flash.is_empty():
			actor["bite_hits"] = 0
			actor["bite_misses"] = 0
			actor["use_flash_blast_next"] = false
			for target_value in living_party:
				CombatRules.resolve(self_stats, (target_value as Dictionary).stats as CombatantStats, flash.combat as Dictionary)
			return

	var bite := by_id.get("bite", {}) as Dictionary
	var bite_target: Dictionary = living_party[rng.randi_range(0, living_party.size() - 1)]
	var result := CombatRules.resolve(self_stats, bite_target.stats as CombatantStats, bite.combat as Dictionary)
	if bool(result.get("hit", false)):
		actor["bite_hits"] = int(actor.get("bite_hits", 0)) + 1
	else:
		actor["bite_misses"] = int(actor.get("bite_misses", 0)) + 1
	actor["use_flash_blast_next"] = int(actor.get("bite_misses", 0)) >= int(actor.get("bite_hits", 0))

# Mirrors Goblin._highest_damage_target(): ties broken randomly, falls back
# to the usual weighted-toward-hurt pick if nobody's damaged this Angler yet.
func _highest_damage_target(actor: Dictionary, living_party: Array, rng: RandomNumberGenerator) -> Dictionary:
	var by: Dictionary = actor.get("damage_taken_by", {})
	var best_amount := 0
	var best_entries: Array = []
	for entry_value in living_party:
		var entry := entry_value as Dictionary
		var dealt := int(by.get(String(entry.model), 0))
		if dealt > best_amount:
			best_amount = dealt
			best_entries = [entry]
		elif dealt == best_amount and dealt > 0:
			best_entries.append(entry)
	if best_entries.is_empty():
		return _pick_enemy_target(living_party, rng)
	return best_entries[rng.randi_range(0, best_entries.size() - 1)] as Dictionary

func _pick_enemy_move(enemy_id: String, target: CombatantStats, rng: RandomNumberGenerator) -> Dictionary:
	# "angler" never actually reaches this generic weighted picker any more -
	# _enemy_turn() routes it to _angler_turn() instead - but every other
	# ordinary enemy (Swordfish, Frilled Shark) still uses this plain flow.
	var catalogue: Array
	match enemy_id:
		"swordfish_duelist":
			catalogue = EnemyMoves.swordfish_duelist_catalogue()
		"frilled_shark":
			catalogue = EnemyMoves.frilled_shark_catalogue()
		_:
			catalogue = EnemyMoves.angler_catalogue()
	var moves: Array = catalogue.filter(func(move: Dictionary) -> bool: return bool(move.enabled))
	moves.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("roll_order", 0)) < int(right.get("roll_order", 0)))
	var finisher := moves.any(func(move: Dictionary) -> bool:
		return float(move.get("finisher_below_hp", 0.0)) > 0.0 and float(target.hp) <= float(target.hp_max) * float(move.finisher_below_hp))
	var total := 0.0
	for move in moves:
		total += maxf(0.0, float(move.get("finisher_weight", 0.0) if finisher else move.get("weight", 0.0)))
	var roll := rng.randf() * total
	for move in moves:
		roll -= maxf(0.0, float(move.get("finisher_weight", 0.0) if finisher else move.get("weight", 0.0)))
		if roll <= 0.0:
			return (move as Dictionary).duplicate(true)
	return (moves.back() as Dictionary).duplicate(true)

# Mirrors Battle._pick_enemy_target(): hurt characters attract pressure, but
# every living diver keeps a nonzero chance of being chosen.
func _pick_enemy_target(living_party: Array, rng: RandomNumberGenerator) -> Dictionary:
	if living_party.size() <= 1:
		return living_party[0] as Dictionary
	var weights: Array[float] = []
	var total := 0.0
	for actor in living_party:
		var stats := actor.stats as CombatantStats
		var weight := 0.15 + (1.0 - float(stats.hp) / float(stats.hp_max))
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	for i in range(living_party.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return living_party[i] as Dictionary
	return living_party[living_party.size() - 1] as Dictionary

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
		stats.grow_hp = int(base.grow_hp)
		stats.grow_strength = int(base.grow_strength)
		stats.grow_defense = int(base.grow_defense)
		stats.grow_agility = int(base.grow_agility)
		stats.grow_accuracy = int(base.get("grow_accuracy", 0))
		stats.grow_evasion = int(base.get("grow_evasion", 0))
		stats.fill()
		out.append({"kind": "party", "model": String(model_name), "stats": stats})
	return out

func _average(party: Array) -> CombatantStats:
	var avg := CombatantStats.new()
	var living := _living(party)
	var pool: Array = living if not living.is_empty() else party
	var n := float(pool.size())
	avg.hp_max = int(round(pool.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).hp_max, 0) / n))
	avg.strength = int(round(pool.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).strength, 0) / n))
	avg.defense = int(round(pool.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).defense, 0) / n))
	avg.agility = int(round(pool.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).agility, 0) / n))
	avg.evasion = int(round(pool.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).evasion, 0) / n))
	avg.accuracy = int(round(pool.reduce(func(sum: int, e: Dictionary) -> int: return sum + (e.stats as CombatantStats).accuracy, 0) / n))
	avg.fill()
	return avg

func _enemy(reference: CombatantStats, rng: RandomNumberGenerator, enemy_id: String) -> Dictionary:
	# Swordfish Duelist and Frilled Shark each author their own floor
	# (DUELIST_FLOOR_STATS / SHARK_FLOOR_STATS) since Goblin.FLOOR_STATS became
	# the Angler-specific block - mirror production's per-species
	# Goblin.floor_stats() override here instead of always reading the base
	# class's own const, or this simulator would silently test enemies
	# stronger/weaker than the ones players actually fight.
	var floor: Dictionary
	match enemy_id:
		"swordfish_duelist":
			floor = SwordDuelist.DUELIST_FLOOR_STATS
		"frilled_shark":
			floor = FrilledShark.SHARK_FLOOR_STATS
		_:
			floor = Goblin.FLOOR_STATS
	var stats := CombatantStats.new()
	if enemy_id == "swordfish_duelist":
		# Mirrors SwordDuelist.make_stats(): Glassgoat's supplied Swordfish
		# block is exact, not an Angler-style minimum that rises above the
		# party. Keeping this exception here is essential - otherwise the
		# balance gate would certify a generic scaled duel rather than the
		# actual 8/2/1/6/4/3 opponent production creates.
		stats.hp_max = int(floor.hp)
		stats.strength = int(floor.strength)
		stats.defense = int(floor.defense)
		stats.agility = int(floor.agility)
		stats.evasion = int(floor.evasion)
		stats.accuracy = int(floor.accuracy)
	else:
		stats.hp_max = maxi(1, int(round(maxf(float(floor.hp), float(reference.hp_max)) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
		stats.strength = maxi(1, int(round(maxf(float(floor.strength), float(reference.strength)) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
		stats.defense = maxi(0, int(round(maxf(float(floor.defense), float(reference.defense)) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
		stats.agility = maxi(1, int(round(maxf(float(floor.agility), float(reference.agility)) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
		stats.evasion = maxi(0, int(round(maxf(float(floor.evasion), float(reference.evasion)) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
		stats.accuracy = maxi(0, int(round(maxf(float(floor.accuracy), float(reference.accuracy)) * rng.randf_range(Goblin.MIN_EDGE, Goblin.MAX_EDGE))))
	stats.fill()
	# damage_taken_by/bite_hits/bite_misses/use_flash_blast_next mirror the
	# per-instance state Goblin now carries for the Angler's move AI - unused
	# by Swordfish, which still goes through the plain _pick_enemy_move() path.
	return {
		"kind": "enemy", "enemy_id": enemy_id, "stats": stats,
		"damage_taken_by": {}, "bite_hits": 0, "bite_misses": 0, "use_flash_blast_next": false,
	}

func _living(side: Array) -> Array:
	return side.filter(func(actor: Dictionary) -> bool: return (actor.stats as CombatantStats).hp > 0)

func _enemy_label(ids: Array) -> String:
	var labels: Array[String] = []
	for id_value in ids:
		labels.append(String(id_value))
	labels.sort()
	return "+".join(labels)

func _inside_unclaimed_guardian_site(at: Vector3, claimed_items: Array[String]) -> bool:
	for site_value in Sites.ALL:
		var site := site_value as Dictionary
		var item_id := String(site.get("item", ""))
		if item_id == "" or claimed_items.has(item_id):
			continue
		var center := site.at as Vector3
		if Vector2(at.x - center.x, at.z - center.z).length() <= float(site.radius):
			return true
	return false

func _print_result(label: String, result: Dictionary) -> void:
	var parts: Array = []
	for count in [1, 2, 3]:
		var cell := result.by_count[count] as Array
		parts.append("%d enemy %d/%d, %.1f r" % [count, int(cell[0]), int(cell[1]), _average_turns_for_count(result, count)])
	print("%-7s %5.1f%% wins, %4.1f rounds, %4.1f HP lost  (%s)" % [label, result.rate, result.turns, result.hp, ", ".join(parts)])

func _average_turns_for_count(result: Dictionary, count: int) -> float:
	var cell := (result.turns_by_count as Dictionary).get(count, [0.0, 0]) as Array
	return float(cell[0]) / float(maxi(int(cell[1]), 1))

func _print_route(label: String, result: Dictionary) -> void:
	print("%-7s route %5.1f%% reach trench | %.1f random + %.1f guardian fights/run | %.1f enemies/run | successes: %.1f battles, %.1f HP, level %.1f" % [
		label, result.rate, result.random_fights, result.guardian_fights,
		result.grunts, result.battles, result.hp, result.level])
	var stages: Array[String] = []
	for stage_value in (result.terminal_stages as Dictionary).keys():
		stages.append(String(stage_value))
	stages.sort()
	var summary: Array[String] = []
	for stage in stages:
		summary.append("%s=%d" % [stage, int((result.terminal_stages as Dictionary)[stage])])
	print("%-7s route terminal stages: %s" % [label, ", ".join(summary)])
