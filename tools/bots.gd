# Pinned judge policies. Bots enter through the SAME functions the input
# handler will call: act_ability, act_move, end_turn.
# Anything else is harness drift (SPEC 4.3, G14).
class_name Bots
extends RefCounted

static func legal(c: Combat) -> Array:
	var out: Array = []
	for d in c.divers:
		if d.down:
			continue
		if c.afford(d.cost) and c.can_attack(d):
			for slot in range(d.kit.size()):
				out.append({"kind": "attack", "i": d.id, "slot": slot})
		if Combat.OVERDRAFT_ENABLED and not c.overdrafted and d.hp > Combat.OVERDRAFT_HP:
			out.append({"kind": "overdraft", "i": d.id})
		if c.afford(Combat.ANALYZE_COST) and c.target_limb(d) >= 0 and not c.known(c.target_limb(d)):
			out.append({"kind": "analyze", "i": d.id})
		if c.can_move_now(d.id):
			for s in c.OPEN_STATIONS:
				if s == d.station:
					continue
				# ask the sim rather than reimplementing its rule here: the
				# duplicate copy of this check did not know about row mode
				if c.station_free(int(s)):
					out.append({"kind": "move", "i": d.id, "s": int(s)})
	return out

static func apply(c: Combat, a: Dictionary) -> bool:
	match a.kind:
		"attack": return c.act_ability(a.i, int(a.get("slot", 0)))
		"analyze": return c.act_analyze(a.i)
		"move": return c.act_move(a.i, a.s)
		"overdraft": return c.act_overdraft(a.i)
	return false

# casual: a plausible inexperienced human, not noise.
#
# JUDGE CHANGE, logged with its reason (standing rule: pinned judges may
# only change with a logged reason and a re-run of every gate that used
# them). The first version was uniform random over ALL legal actions. In
# a positional game that is roughly 3 attacks against 12 moves, so it
# attacked 20 percent of the time and spent the rest wandering. It won
# 1.4 percent of fights and a full parameter sweep found NO configuration
# that could lift it into band, because every number that lengthens the
# fight for the skilled bot also feeds the wanderer more enemy turns.
#
# That is judge pathology, not a broken game: a human who does not know
# what they are doing still mostly attacks. This version attacks when it
# can and wanders sometimes, which measures difficulty instead of noise.
const CASUAL_MOVE_CHANCE := 0.3

static func casual(c: Combat, rng: RandomNumberGenerator) -> Dictionary:
	var opts: Array = legal(c)
	if opts.is_empty() or rng.randf() < 0.12:
		return {}
	var attacks: Array = []
	var moves: Array = []
	var burns: Array = []
	var reads: Array = []
	for a in opts:
		if a.kind == "analyze": reads.append(a)
		elif a.kind == "attack": attacks.append(a)
		elif a.kind == "overdraft": burns.append(a)
		else: moves.append(a)
	# Burning HP for air is a desperate act; a novice does it occasionally,
	# not one time in three. Leaving it in the uniform pool dropped casual
	# from 65 to 31 percent, which measured the bot's recklessness rather
	# than the fight's difficulty. Same judge pathology as the first sweep.
	if not reads.is_empty() and rng.randf() < 0.18:
		return reads[rng.randi() % reads.size()]
	if not burns.is_empty() and rng.randf() < 0.06:
		return burns[rng.randi() % burns.size()]
	var want_move: bool = attacks.is_empty() or (not moves.is_empty() and rng.randf() < CASUAL_MOVE_CHANCE)
	var pool: Array = moves if want_move else attacks
	if pool.is_empty():
		pool = opts
	# A novice presses the FIRST button most of the time. Picking uniformly
	# among six abilities halved the casual win rate the moment the kit
	# doubled, which measured the bot's indecision rather than the fight.
	# Same judge pathology as the first sweep and the overdraft.
	if not want_move and rng.randf() < 0.7:
		for a in pool:
			if int(a.get("slot", 0)) == 0:
				return a
	return pool[rng.randi() % pool.size()]

# greedy: break limbs fast, and step out of a telegraphed station when it
# is cheap to do so. Pinned BEFORE any tuning.
static func greedy(c: Combat, _rng: RandomNumberGenerator) -> Dictionary:
	var all_intents: Array = c.intents()
	var threatened: Array = []
	for it in all_intents:
		for st in it.stations:
			if not (st in threatened):
				threatened.append(st)
	var best := {}
	var best_score := -1.0
	for a in legal(c):
		var d = c.divers[a.i]
		var score := 0.0
		if a.kind == "analyze":
			# reading a limb pays off only while there is enough of it left
			# for the trait to matter, and never as a whole turn's work
			var lb0: int = c.target_limb(c.divers[a.i])
			score = 2.6 if lb0 >= 0 and int(c.limb_hp[lb0]) > 4 else 0.4
		elif a.kind == "attack":
			var ab: Dictionary = d.kit[int(a.get("slot", 0))]
			var limb: int = c.target_limb(d)
			if limb < 0:
				continue
			var adm: int = int(ab.dmg)
			score = float(min(adm, c.limb_hp[limb])) / float(d.cost)
			if String(ab.kind) == "hit_shove" and limb >= 0:
				# a shove is worth the damage it steers off occupied ground,
				# priced like the shut and below parity for the same reason
				for it in all_intents:
					if int(it.limb) != limb:
						continue
					var home3 := int((c.enc.limbs[limb] as Dictionary).station)
					var steered := 0
					for dd in c.divers:
						if not dd.down and int(dd.station) in it.stations and int(dd.station) != home3:
							steered += int(it.dmg)
					score += float(steered) / float(d.cost) * 0.5
			if String(ab.kind) == "hit_wide":
				for st in c.neighbours(d.station):
					var lb3: int = c.STATION_LIMB[int(st)]
					if lb3 >= 0 and not c.limb_broken[lb3]:
						score += float(min(adm, c.limb_hp[lb3])) / float(d.cost)
			if adm >= c.limb_hp[limb]:
				score += 3.0   # finishing a limb changes the map
			# shutting down the limb that is ABOUT to swing is worth the
			# damage it would have dealt. Without this the judge cannot see
			# prevention at all and would report the disabler dominated
			# purely because it cannot value what the disabler does.
			# shutting down a limb that is ABOUT to swing is worth the damage
			# it would have dealt to bodies actually standing in its arc
			if String(ab.kind) == "shut" and limb >= 0 and int(c.limb_stun[limb]) <= 0:
				for it in all_intents:
					if int(it.limb) != limb:
						continue
					var would := 0
					for dd in c.divers:
						if not dd.down and int(dd.station) in it.stations:
							would += int(it.dmg)
					# Weighted BELOW parity on purpose. At full weight the judge
					# stunned every turn forever: prevention scored 2.5 against
					# an attack's 2.0, and since the ranged drum deals no
					# damage the fight never progressed (41 turns, G2 0/40).
					# A shutdown buys a turn; it does not win the fight.
					score += float(would) / float(d.cost) * 0.55
		elif a.kind == "overdraft":
			# The greedy judge NEVER burns HP, deliberately. Scored at all,
			# it fired every turn air ran short and doubled its own damage
			# taken, so the difficulty floor measured the bot's recklessness
			# instead of the fight. Pinned HP-averse for the same reason the
			# last project pinned its judge heal-averse: a floor should
			# measure pressure, not self-harm.
			continue
		else:
			# Move pricing, re-derived after the free-move ruling. The old
			# flat 0.9 was priced when moves cost air; with moves free it
			# made every diver shuffle to some limb station with its spare
			# move, which parked occupancy on the offensive stations and
			# reported the refuge and the drum platform dead. A move is
			# worth something when it CHANGES something: reaching a target
			# when you have none, reaching the platform when you cannot act
			# where you stand, or stepping out of an announced arc, which
			# costs nothing now and is therefore right at any HP.
			var limb2: int = c.STATION_LIMB[a.s]
			var here: int = c.target_limb(d)
			if limb2 >= 0 and not c.limb_broken[limb2]:
				score = 0.9 if here < 0 else 0.05
			elif a.s == Combat.BACKLINE and d.disables:
				# the platform is a real destination exactly when something
				# announced can be shut from it (same amendment class as
				# shut-scoring: the judge must see what the station is FOR)
				for it in all_intents:
					if int(c.limb_stun[int(it.limb)]) <= 0 and not c.limb_broken[int(it.limb)]:
						score = 0.9 if here < 0 else 0.05
						break
			if d.station in threatened and not (a.s in threatened):
				# a dodge is worth what the announced swing would have
				# taken, discounted; free moves made this the judge's
				# largest mispricing (G11 drift 2.23 the night the economy
				# changed: flat bonuses priced a 6-damage dodge at 0.95)
				var would2 := 0
				for it in all_intents:
					if int(d.station) in it.stations and int(c.limb_stun[int(it.limb)]) <= 0 and not c.limb_broken[int(it.limb)]:
						would2 += int(it.dmg)
				# capped below an attack's typical score: uncapped, the
				# judge dodge-thrashed (41-turn crab, G2 0/40). And a
				# HEALTHY diver discounts the dodge further: unconditional
				# dodge value stalemated every squatter shape at t41 (the
				# shut-forever pathology in movement clothes). A judge
				# fights while healthy and dodges while hurt, which is
				# also what a floor should measure.
				var dodge_w: float = 0.45 if float(d.hp) / float(d.max_hp) < 0.6 else 0.18
				score += minf(float(would2) * dodge_w, 1.2)
				if float(d.hp) / float(d.max_hp) < 0.5:
					score += 0.6
		if score > best_score:
			best_score = score
			best = a
	return best if best_score > 0.0 else {}
# NOTE: SALVAGE's puzzle policies (solve_step, solve_puzzle) were removed
# on the way over. They drive Puzzle and Pipes, which are lock grammars
# that project has and this one does not, and an unreachable reference to
# a missing class fails the whole file at parse time rather than at use.

static func run_fight(seed_val: int, policy: String, enc_id := "crab", cap := 40, kit_size := 0) -> Dictionary:
	var c := Combat.new(enc_id, kit_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	while c.outcome == "ongoing" and c.turn <= cap:
		var guard := 0
		while guard < 12:
			guard += 1
			var a: Dictionary = casual(c, rng) if policy == "casual" else greedy(c, rng)
			if a.is_empty() or not apply(c, a):
				break
			if c.outcome != "ongoing":
				break
		if c.outcome != "ongoing":
			break
		c.end_turn()
	var hp_lost := 0
	for d in c.divers:
		hp_lost += d.max_hp - d.hp
	# the party size is CONTENT: the descent runs one diver, so a hardcoded
	# 3 reported two divers down in a fight that never had them
	return {"win": c.outcome == "victory", "turns": c.turn, "hp_lost": hp_lost, "downed": c.divers.size() - c.alive().size()}
