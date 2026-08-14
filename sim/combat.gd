# Pure combat simulation. RefCounted, no Node, no scene, no timers.
# If a bot cannot run this headless with no scene instantiated, the split
# has already leaked. See SPEC.md 4.3 (G14 harness fidelity).
class_name Combat
extends RefCounted

const FRONT := 0
const FLANK := 1
const UNDER := 2
const REAR := 3
const BACKLINE := 4
const STATION_NAMES := ["FRONT", "FLANK", "UNDER", "REAR", "BACKLINE"]

const Encounters := preload("res://content/encounters.gd")

# Per-encounter, derived from the encounter's limb list so the two can
# never disagree. Fight one runs on FOUR stations: the histogram showed
# UNDER at 0.0 percent, and the cause was not that safety is worthless, it
# was that BACKLINE is ALSO safe with no downside, so UNDER was dominated
# by a duplicate. BACKLINE arrives in fight two with the scanner that makes
# standing there worth it.
var STATION_LIMB: Array = []
var OPEN_STATIONS: Array = []
var LIMB_NAMES: Array = []
var enc_id := "crab"
var enc: Dictionary = {}

const AIR_PER_TURN := 4   # see TUNE.air; this is the ceiling for clamping
const MOVE_COST := 1
# CUT. Kept as a constant only so nothing referring to it breaks.
# Two honest attempts to give the valve a niche failed: at 2 HP it bought
# exactly break-even value, and at 1 HP with a leaf that prices HP spent on
# a WON fight as nearly free, it was still never uniquely optimal in any
# encounter. With a shared 4-Air pool and actions costing 1, a fifth action
# is never decisive. A dead option is worse than no option.
const OVERDRAFT_HP := 1
const OVERDRAFT_ENABLED := false

class Diver extends RefCounted:
	var id: int
	var dname: String
	var cost: int
	var disables: bool = false
	var kit: Array = []
	var max_hp: int
	var hp: int
	var dmg: int
	var station: int
	var down: bool = false
	func _init(i: int, n: String, c: int, h: int, d: int, s: int) -> void:
		id = i; dname = n; cost = c; max_hp = h; hp = h; dmg = d; station = s

# Tunables in one place so the sweep can vary them and the bands can be
# measured rather than argued. Defaults are the day-zero values.
static var TUNE := {
	# Chosen by tools/sweep.gd, not by argument. Eight configurations land
	# G3 in band; this is the one with the smallest numbers, per
	# Glass_Goat's directive that results stay countable like chess.
	# Measured at these values: casual 73.0%, greedy 7.0 turns, 22.0 HP lost.
	# Re-swept after G-TEACH forced fight one down to two divers. Of 48
	# cells only ONE lands G3 in band, which is worth knowing: the
	# two-diver fight is a narrow design space and the next content change
	# will likely knock it out. Measured here: casual 66.3%, greedy 6.0
	# turns (floor 6.0), 10.0 squad HP lost (floor 8.0).
	# Re-swept after every live limb began swinging, which roughly tripled
	# incoming damage. SPEC 2.10 licenses these being moved by the bands.
	"diver_hp": [24, 34, 40],
	# Proto5 was 5 damage for 3 Air, the WORST rate in the party, against
	# Scuba's 2 for 1. With a shared pool and no per-diver action cap,
	# "concentrated" buys nothing and he was dominated everywhere. He is now
	# the efficient heavy: 8 for 3 beats 6 for 3.
	"diver_dmg": [2, 2, 8],
	"air": 4,
}

var divers: Array = []
var limb_hp: Array = []
var limb_broken: Array = []
var air := AIR_PER_TURN
var air_penalty := 0          # umbilicals cut last turn
var turn := 1
var outcome := "ongoing"      # ongoing | victory | defeat
var log_lines: Array = []
var _rotation := 0            # deterministic enemy cycle
var overdrafted := false      # the valve opens once per turn, not endlessly
# The Aug 6 evening ruling: each diver's FIRST move of a turn is free, and
# the shared tank pays for abilities only. Three playtests converged on the
# same wall: move-both-then-strike-both cost 5 against a 4-air tank, so the
# squad turn the player kept reaching for was illegal, and the cheapest
# line left was mashing one diver. Extra moves past the first still cost.
var _moved: Dictionary = {}   # diver index -> true once the free move is spent
# Desperation is a valve, not an engine. Unlimited, the masher gate showed
# a squad HP-burning through the dredge in four turns, faster than the
# judge plays it; capped per TURN it still sustained an alpha-strike every
# round. One push past the empty tank per diver per FIGHT keeps
# Glass_Goat's rule (you may always act, at a cost you choose) as the
# dramatic moment it reads as, not a renewable resource. The judges never
# desperate at all, so this prices exactly one policy: the masher's.
var _desperate: Dictionary = {}  # diver index -> true once the fight's one push is spent
# The ramp: a limb flagged "ramp" grows 1 announced damage every time it
# actually swings un-prevented. The first escalation in the game, SPEC
# 2.4's open question answered small: a break or a shut is how you stop
# the number climbing, so attack-only play races a clock it always loses.
# Deterministic and printed in the telegraph like everything else.
var _ramp: Dictionary = {}       # limb index -> accumulated bonus damage
# A shut does not hold the same limb two turns running: the drum's charge
# rebuilds. Without this one diver parked at range CC-locked the whole
# final fight by re-shutting the same limb forever, and the masher gate
# proved the dumbest policy could not lose. Immunity lasts exactly the
# player turn after the stun expires, printed nowhere as a number: the
# rule is one sentence and the telegraph shows the consequence.
var _no_reshut: Dictionary = {}  # limb index -> true while a re-shut will not hold
# The salvage on the board (Into the Breach's buildings, sized to one
# crate): the thing you came down for sits at a station, announced
# attacks that land there unblocked chip it, and a diver standing there
# takes the hit instead. It cannot win or lose the fight; it decides
# what you surface WITH, which is the ending screen's story. Offense
# and defense finally compete for the same free move.
var salvage_hp := 0
var salvage_station := -1
var salvage_crushed := false
# STUN: a limb that is stunned does not attack on its next turn. Chosen
# because it is deterministic (Q1 forbids hidden rolls) and because it makes
# the telegraph ACTIONABLE: you see the jaw winding up and you shut it. That
# is the counterplay the whole information design was missing.
var limb_stun: Array = []
# The announced attack, fixed at the start of the player's turn. Recomputing
# it at resolution let a shutdown SUBSTITUTE a different, never-announced
# attack: announced 'the maw lunges at FRONT for 3', delivered 'Scuba took 3
# at FLANK'. That is the determinism contract broken, not a balance issue.
# EVERY live limb swings, and all of them are announced. With one attack a
# turn, shutting down that single limb prevented the entire enemy turn for
# 2 Air, and the greedy bot finished the vent worm without taking a scratch.
# A shutdown should be a PARTIAL answer: it removes one limb's swing from a
# turn that has several.
var analyzed: Array = []   # which limbs a diver has read
var locked: Array = []

# kit_size 0 means "everything this diver owns", which is what the bots and
# the search want. The RUN passes the number actually earned so far.
func _init(encounter := "crab", kit_size := 0) -> void:
	enc_id = encounter
	enc = (Encounters.ALL[encounter] as Dictionary)
	STATION_LIMB = Encounters.station_limb(enc)
	analyzed = []
	for _l in enc.limbs:
		analyzed.append(false)
	var sv: Dictionary = enc.get("salvage", {})
	if not sv.is_empty():
		salvage_hp = int(sv.hp)
		salvage_station = int(sv.station)
	var freebie: int = int(enc.get("read_free", -1))
	if freebie >= 0 and freebie < analyzed.size():
		analyzed[freebie] = true
	OPEN_STATIONS = (enc.open_stations as Array).duplicate()
	LIMB_NAMES = []
	limb_hp = []
	limb_broken = []
	limb_stun = []
	for l in enc.limbs:
		LIMB_NAMES.append(String(l.name))
		limb_hp.append(int(l.hp))
		limb_broken.append(false)
		limb_stun.append(0)
	var hp: Array = TUNE.diver_hp
	var dm: Array = TUNE.diver_dmg
	# Callsigns, placeholder for Marc: the rig's working identifiers
	# (Prototype1, Proto5) read as debug scaffolding on screen, which
	# eight cold reviews and the playtester flagged independently. The
	# callsign IS the readable fact about each diver: the bare swimmer,
	# the drum carrier, the brass suit.
	var roster := [["Scuba", 1, false], ["Drum", 2, false], ["Brass", 3, false]]
	# Two abilities per diver, named for the clips that actually exist in
	# the rig (standing rule: ability names come FROM the animation list).
	# SPEC 2.9 gives each diver one verb expressed twice.
	var kits := [
		# Double Knee trades nothing for the step: at 1 damage against Axe
		# Kick's 2 it was strictly worse whenever you did not want to move.
		# SPEC 2.9 verbatim: Axe Kick "knocks the target limb's guard
		# open, or shoves an enemy part". Shipped as a plain hit and the
		# audit called the reversal out; built as written now. The shove
		# re-aims the limb's ANNOUNCED swing to its own station, so the
		# telegraph changes in front of you and where the attack lands is
		# something you steer. Displacement, the genre's biggest source of
		# non-damage variety, at zero state-space cost.
		[{"name": "Axe Kick", "dmg": 2, "kind": "hit_shove"},
		 {"name": "Double Knee", "dmg": 2, "kind": "hit_and_step"}],
		[{"name": "Palm Strike", "dmg": 2, "kind": "shut", "turns": 1},
		 {"name": "Dual Palm", "dmg": 0, "kind": "shut", "turns": 2}],
		# Attck2 spills onto every neighbouring station, so 5 became 10+ per
		# action and cleared the dredge in 2 turns against a teaching floor
		# of 6. The crowd answer trades per-target damage for reach.
		# display names for the heavy's two swings; the CLIPS stay keyed
		# by their rig names in RIG_BY_ABILITY, so the motion-name match
		# the naming rule exists for is preserved by the mapping
		[{"name": "Piston Swing", "dmg": 8, "kind": "hit"},
		 {"name": "Wide Sweep", "dmg": 3, "kind": "hit_wide"}],
	]
	var starts: Array = enc.get("starts", [])
	divers = []
	var n: int = min(int(enc.party), roster.size())
	for i in range(n):
		var start: int = int(starts[i]) if i < starts.size() else int(OPEN_STATIONS[i % OPEN_STATIONS.size()])
		var dv := Diver.new(i, String(roster[i][0]), int(roster[i][1]), int(hp[i]), int(dm[i]), start)
		dv.disables = String(roster[i][0]) == "Drum" and bool(enc.get("drum", false))
		dv.kit = (kits[i] as Array).duplicate(true)
		if kit_size > 0 and dv.kit.size() > kit_size:
			dv.kit.resize(kit_size)
		divers.append(dv)
	air = int(TUNE.air)
	_lock_intent()

# ---- enemy anatomy: fight one, the hunter crab -------------------------
# Three limbs. UNDER is deliberately empty, which is what proves the
# geometry is real: it is a place you can stand that does nothing
# offensively, and the jaw cannot reach it. Safety is a reason to move.
func attacks() -> Array:
	return enc.attacks

# A limb may carry more than one arc, and it takes them in turn. Without
# this every live limb swung at the same stations every round, so the union
# of the arcs never changed: the safe station was either permanent or, on
# the later encounters, absent. Measured before changing anything -- the
# spitter left nowhere safe on 3 of 8 turns and the dredge on 11 of 17, so
# the blue ring stopped meaning anything exactly as the game escalated.
#
# Alternating by TURN keeps SPEC 2.11: there is no hidden roll between the
# announcement and the outcome, because the turn number is on the screen
# and the telegraph names the arc it picked.
func live_attacks() -> Array:
	var by_limb: Dictionary = {}
	for a in attacks():
		if limb_broken[a.limb] or int(limb_stun[a.limb]) > 0:
			continue
		var key := int(a.limb)
		if not by_limb.has(key):
			by_limb[key] = []
		by_limb[key].append(a)
	var out: Array = []
	for key in by_limb.keys():
		var opts: Array = by_limb[key]
		if bool(enc.get("ferocious", false)):
			# a fewer-limbed thing fights with everything it has, every
			# turn: one limb, all its arcs. Diversity means new questions,
			# not less fight.
			for o in opts:
				out.append(o)
		else:
			out.append(opts[turn % opts.size()])
	return out

# The telegraph. Deterministic, shown at the START of the player's turn,
# and it is exactly what will happen (SPEC 2.11).
# the whole announced turn
# Every station an announced attack will land on this turn, read off the
# locked intents. Lives here rather than in the scene so that the ring the
# player sees, the words the telegraph prints and the invariant the fuzz
# checks are all one function. The presentation drew "safe to stand" at any
# station with no limb standing on it, which is a different question: a
# limb's arc reaches stations it does not occupy, so BACKLINE was drawn
# safe while the same screen announced 3 damage landing there.
func threatened_stations() -> Array:
	var out: Array = []
	for it in intents():
		if int(limb_stun[int(it.limb)]) > 0:
			continue          # shut down: prevented, and the telegraph says so
		for st in it.stations:
			if not (int(st) in out):
				out.append(int(st))
	return out

func intents() -> Array:
	return locked

# the first announced attack, for callers that want one
func intent() -> Dictionary:
	return {} if locked.is_empty() else locked[0]

func _lock_intent() -> void:
	# A hunting arc aims where divers actually stand. Free moves (the Aug 6
	# ruling) made repositioning cheap enough that optimal play camped one
	# station and abandoned others, which the station-health checks caught
	# the same hour. A hunt re-prices camping without re-pricing movement:
	# it locks onto the occupied station nearest the limb's own, a full
	# turn ahead, printed in the telegraph like every other arc. Moving
	# after the announcement IS the counterplay. The back line is out of a
	# hunt's reach; standing back is the point of the back line.
	locked = []
	for a in live_attacks():
		# duplicate(true): a shallow copy shared the stations array with
		# the content template, and shared inner state with every clone
		var b: Dictionary = a.duplicate(true)
		if bool(b.get("hunts", false)):
			b.stations = [_hunt_station(int(b.limb))]
		var bonus := int(_ramp.get(int(b.limb), 0))
		if bonus > 0:
			b.dmg = int(b.dmg) + bonus
		locked.append(b)

func _hunt_station(limb: int) -> int:
	var home := int((enc.limbs[limb] as Dictionary).station)
	var best := -1
	var best_d := 999
	for d in divers:
		if d.down or int(d.station) == BACKLINE:
			continue
		var dist: int = abs(int(d.station) - home)
		if dist < best_d or (dist == best_d and int(d.station) < best):
			best_d = dist
			best = int(d.station)
	return best if best >= 0 else home

func air_this_turn() -> int:
	return max(0, int(TUNE.air) - air_penalty)

# ---- player actions ----------------------------------------------------
func alive() -> Array:
	var out: Array = []
	for d in divers:
		if not d.down:
			out.append(d)
	return out

# what a limb turns out to be, once a diver has read it
const TRAITS := {
	"brittle": "brittle: it takes double damage",
	"pressurised": "pressurised: breaking it shuts every other limb for a turn",
	"leaking": "leaking: breaking it gives the squad 2 air back",
	"plated": "plated: it takes one less from every hit",
}

func trait_of(limb: int) -> String:
	if limb < 0 or limb >= enc.limbs.size():
		return ""
	return String((enc.limbs[limb] as Dictionary).get("trait", ""))

func known(limb: int) -> bool:
	return limb >= 0 and limb < analyzed.size() and bool(analyzed[limb])

# Reading a limb costs air like anything else. It is the cheapest action in
# the game because information should be affordable, and the only one that
# does no damage at all.
const ANALYZE_COST := 1

func act_analyze(i: int) -> bool:
	if i < 0 or i >= divers.size():
		return false
	var d = divers[i]
	if outcome != "ongoing" or d.down or not afford(ANALYZE_COST):
		return false
	var limb: int = target_limb(d)
	if limb < 0 or known(limb):
		return false
	air -= ANALYZE_COST
	analyzed[limb] = true
	var t := trait_of(limb)
	if t == "":
		log_lines.append("%s reads the %s: nothing unusual about it" % [d.dname, LIMB_NAMES[limb]])
	else:
		log_lines.append("%s reads the %s -- %s" % [d.dname, LIMB_NAMES[limb], String(TRAITS[t])])
	return true

func can_attack(d) -> bool:
	# From BACKLINE the disabler reaches with the drum: it shuts down
	# whatever is winding up, wherever it is. That is what makes standing
	# at range a decision rather than a retreat, and it is why BACKLINE and
	# conditions are one idea rather than two (SPEC 2.7 parts).
	# "there is something announced" is not the same as "there is something
	# I can shut". can_attack said yes on any announcement while target_limb
	# skipped limbs already shut or broken, so act_ability took the yes and
	# then refused on the -1. The bots offered the action, the UI offered
	# the key, and the press did nothing. Ask the same question both do.
	if d.disables and d.station == BACKLINE:
		return target_limb(d) >= 0
	var tl: int = target_limb(d)
	return tl >= 0 and not limb_broken[tl]

# which limb this diver would hit from where it stands
func target_limb(d) -> int:
	if d.disables and d.station == BACKLINE:
		# from range the drum shuts down whichever announced limb is not
		# already down: the first one still able to swing and able to be
		# gripped (a limb shut last turn will not hold again yet)
		for it in locked:
			if can_shut(int(it.limb)):
				return int(it.limb)
		return -1
	var own: int = int(STATION_LIMB[d.station])
	if own >= 0 and not limb_broken[own]:
		return own
	# a blocking limb is pried at from BESIDE it: it took the station you
	# would stand on, so the neighbouring stations are the way at it
	for nb in neighbours(int(d.station)):
		var bl: int = int(STATION_LIMB[int(nb)])
		if bl >= 0 and not limb_broken[bl] and bool((enc.limbs[bl] as Dictionary).get("blocks", false)):
			return bl
	return -1

func afford(cost: int) -> bool:
	return air >= cost

# which stations sit next to this one, for the abilities that step or spill
func neighbours(station: int) -> Array:
	var out: Array = []
	var order: Array = OPEN_STATIONS
	var at := order.find(station)
	if at < 0:
		return out
	if at > 0:
		out.append(int(order[at - 1]))
	if at < order.size() - 1:
		out.append(int(order[at + 1]))
	return out

# GLASS_GOAT'S CORE, from docs/glassgoat-combat-system.pdf, which I had
# never read until today: "At 100% Stamina you can use certain abilities...
# at 60% stamina you can use an inferior version of the attack, but at 20%
# you will use your health to perform the action risking your life."
#
# The same button, three different decisions depending on what is left in
# the tank. This is what turns "press SPACE four times" into a turn with a
# shape: spend big early and finish weak, or hold back and stay strong.
#
#   FULL       room to spare        the ability as written
#   STRAINED   the last of the air  one less damage, one less turn of shut
#   DESPERATE  the air is gone      pay the shortfall out of the diver
const STRAIN_HP := 4     # health per missing point of air

enum Tier { FULL, STRAINED, DESPERATE }

func tier_for(d) -> int:
	if air >= int(d.cost) + 1:
		return Tier.FULL
	if air >= int(d.cost):
		return Tier.STRAINED
	return Tier.DESPERATE

func tier_name(t: int) -> String:
	return ["full", "strained", "desperate"][t]

# What an ability actually does at a tier. The screen and the sim read this
# one function, so a card can never promise a number the sim will not pay.
func effect_at(d, slot: int, t: int) -> Dictionary:
	var ab: Dictionary = d.kit[slot]
	var dmg: int = int(ab.dmg)
	var turns: int = int(ab.get("turns", 1))
	if t == Tier.STRAINED and dmg > 0:
		dmg = max(1, dmg - 1)
	elif t == Tier.DESPERATE:
		if dmg > 0:
			dmg = max(1, dmg - 2)
		turns = max(1, turns - 1)
	var short: int = max(0, int(d.cost) - air)
	return {"dmg": dmg, "turns": turns, "hp_cost": short * STRAIN_HP if t == Tier.DESPERATE else 0}

func act_ability(i: int, slot: int) -> bool:
	if i < 0 or i >= divers.size():
		return false
	var d = divers[i]
	if slot < 0 or slot >= d.kit.size():
		return false
	var ab: Dictionary = d.kit[slot]
	if outcome != "ongoing" or d.down or not can_attack(d):
		return false
	var limb: int = target_limb(d)
	if limb < 0:
		return false
	var t: int = tier_for(d)
	var eff: Dictionary = effect_at(d, slot, t)
	# Desperation: you may always act, and the shortfall comes out of the
	# diver instead of the tank. It may never kill them outright -- that is
	# a cost you choose, not a way to lose without meaning to.
	if t == Tier.DESPERATE:
		if _desperate.has(i):
			return false
		if int(eff.hp_cost) >= int(d.hp):
			return false
		_desperate[i] = true
		d.hp -= int(eff.hp_cost)
		air = 0
		log_lines.append("%s pushes past the empty tank and takes %d for it" % [d.dname, int(eff.hp_cost)])
	else:
		air -= int(d.cost)
	var at_range: bool = d.disables and d.station == BACKLINE
	var dmg: int = 0 if at_range else int(eff.dmg)
	dmg = _after_trait(limb, dmg)
	if dmg > 0:
		limb_hp[limb] -= dmg
		log_lines.append("%s: %s hits the %s for %d" % [d.dname, String(ab.name), LIMB_NAMES[limb], dmg])
	else:
		log_lines.append("%s: %s on the %s" % [d.dname, String(ab.name), LIMB_NAMES[limb]])
	match String(ab.kind):
		"hit_shove":
			# the kick pushes blind; STEERING needs the read. Unread, the
			# hit lands and nothing redirects: you cannot aim a joint you
			# do not understand. (The masher gate's honest answer: the
			# policy that never reads loses its free defense.)
			if known(limb):
				# REPLACE the intent, never mutate it in place: the dicts
				# inside locked were shared with every clone of this state,
				# so an in-place steer here re-aimed the LIVE telegraph
				# whenever action_legal() probed a clone to draw a button
				# (Aug 8 audit; the repro steered a real swing into empty
				# water with no player input).
				for idx in range(locked.size()):
					var a2: Dictionary = locked[idx]
					if int(a2.limb) == limb and not limb_broken[limb]:
						var home := int((enc.limbs[limb] as Dictionary).station)
						if a2.stations != [home]:
							var re: Dictionary = a2.duplicate(true)
							re.stations = [home]
							re.hunts = false
							locked[idx] = re
							log_lines.append("the %s is knocked around: its swing re-aims at %s" % [
								LIMB_NAMES[limb], STATION_NAMES[home]])
		"shut":
			if can_shut(limb):
				limb_stun[limb] = int(eff.turns)
				log_lines.append("the %s is shut down and will not swing" % LIMB_NAMES[limb])
			elif not limb_broken[limb]:
				log_lines.append("the drum cannot grip the %s again so soon" % LIMB_NAMES[limb])
		"hit_and_step":
			# the step obeys the same legality as a move: no stacking onto
			# an occupied station, no stepping onto an unbroken squatter
			for st in neighbours(d.station):
				if station_free(int(st)):
					d.station = int(st)
					log_lines.append("%s steps to %s" % [d.dname, STATION_NAMES[d.station]])
					break
		"hit_wide":
			for st in neighbours(d.station):
				var lb2: int = STATION_LIMB[int(st)]
				if lb2 >= 0 and not limb_broken[lb2]:
					limb_hp[lb2] -= dmg
					log_lines.append("%s spills onto the %s for %d" % [String(ab.name), LIMB_NAMES[lb2], dmg])
					_break_if_spent(lb2)
	_break_if_spent(limb)
	return true

# a trait only bites once it is KNOWN, so reading a limb is what turns it
# into an opportunity rather than a hidden dice roll
func _after_trait(limb: int, dmg: int) -> int:
	# The trait ontology, settled by two instruments pulling opposite ways.
	# Gating everything on known() made reading a plated limb WEAKEN your
	# own hits, so ignorance was optimal (masher gate, Aug 6). Making
	# everything physical made reading buy nothing a clairvoyant searcher
	# could price, and the deep pass reported analyze dominated in every
	# encounter the same night. The split that satisfies both: armor is
	# physical (the plate blocks whether or not anyone looked), and the
	# brittle bonus is AIMED (doubling requires knowing where the crack
	# is). Reading buys exactly the upside, never the downside.
	if dmg <= 0:
		return dmg
	match trait_of(limb):
		"brittle":
			return dmg * 2 if known(limb) else dmg
		"plated":
			return max(1, dmg - 1)
	return dmg

func _break_if_spent(limb: int) -> void:
	if limb < 0 or limb_broken[limb] or limb_hp[limb] > 0:
		return
	limb_hp[limb] = 0
	limb_broken[limb] = true
	log_lines.append("the %s BREAKS" % LIMB_NAMES[limb])
	# what breaking it was FOR. Physical like the damage traits: the
	# pressure vessel blows whether or not anyone read the label. Reading
	# tells you it WILL happen, which is what makes choosing it a plan.
	match trait_of(limb):
		"pressurised":
			for o in range(limb_hp.size()):
				if o != limb and not limb_broken[o]:
					limb_stun[o] = max(int(limb_stun[o]), 1)
			log_lines.append("the pressure blows out: every other limb is shut down and will not swing")
		"leaking":
			air += 2
			log_lines.append("the line vents back into the tank: 2 air returned")
	_check_victory()

func act_attack(i: int) -> bool:
	# ability slot 0, kept so every existing caller and bot still works
	return act_ability(i, 0)

func _legacy_attack(i: int) -> bool:
	var d = divers[i]
	if outcome != "ongoing" or d.down or not afford(d.cost) or not can_attack(d):
		return false
	air -= d.cost
	var limb: int = target_limb(d)
	# From BACKLINE the drum SHUTS a limb down; it does not break it.
	# While it also dealt damage, Prototype1 could dismantle the whole
	# creature from safety and FLANK and UNDER went dead: nobody ever had a
	# reason to stand anywhere. SPEC 2.9 says the drum applies a condition.
	var at_range: bool = d.disables and d.station == BACKLINE
	if not at_range:
		limb_hp[limb] -= d.dmg
		log_lines.append("%s hits the %s for %d" % [d.dname, LIMB_NAMES[limb], d.dmg])
	else:
		log_lines.append("%s points the drum at the %s" % [d.dname, LIMB_NAMES[limb]])
	# SPEC 2.9 gives Prototype1 the verb *disable*. Until it had one it was
	# strictly worse than Scuba at attacking and G4 reported it dominated.
	if d.disables and not limb_broken[limb]:
		limb_stun[limb] = 1
		log_lines.append("the %s is shut down" % LIMB_NAMES[limb])
	if not at_range and limb_hp[limb] <= 0:
		limb_hp[limb] = 0
		limb_broken[limb] = true
		log_lines.append("the %s BREAKS" % LIMB_NAMES[limb])
		_check_victory()
	return true

func station_open(station: int) -> bool:
	return station in OPEN_STATIONS

# One source of truth for what the NEXT move costs this diver, so the UI,
# the hints, the bots and the fuzz all read the same number.
func move_cost(i: int) -> int:
	return MOVE_COST if _moved.has(i) else 0

func can_shut(limb: int) -> bool:
	return limb >= 0 and not limb_broken[limb] and int(limb_stun[limb]) <= 0 \
		and not _no_reshut.has(limb)

func can_move_now(i: int) -> bool:
	return move_cost(i) == 0 or afford(MOVE_COST)

# One diver per station and no unbroken squatter. The sim never enforced
# what every other layer assumed: the halos skip busy stations, the hints
# never name them, the station checks count occupancy singly, and yet a
# slip could legally stack two divers under one swing. This predicate is
# the SINGLE gate every path that PLACES a diver must pass -- act_move
# and the Double Knee step. The step went around it for a day (Aug 8
# audit): one keypress restacked the divers act_move had just unstacked.
func station_free(station: int) -> bool:
	for o in divers:
		if not o.down and int(o.station) == station:
			return false
	var bl: int = STATION_LIMB[station]
	if bl >= 0 and not limb_broken[bl] and bool((enc.limbs[bl] as Dictionary).get("blocks", false)):
		return false
	return true

func act_move(i: int, station: int) -> bool:
	# Validate BEFORE spending anything. The fuzz bot proved act_move(0, 5)
	# put a diver on station 5, off a five-station board, and that a caller
	# could not tell refusal from corruption.
	if i < 0 or i >= divers.size() or station < 0 or station >= STATION_NAMES.size():
		return false
	if not station_open(station):
		return false
	var d = divers[i]
	if outcome != "ongoing" or d.down or d.station == station:
		return false
	if not station_free(station):
		return false
	var cost := move_cost(i)
	if cost > 0 and not afford(cost):
		return false
	if cost == 0:
		_moved[i] = true
		log_lines.append("%s moves to %s" % [d.dname, STATION_NAMES[station]])
	else:
		air -= cost
		log_lines.append("%s spends a line of air and moves to %s" % [d.dname, STATION_NAMES[station]])
	d.station = station
	return true

# Glass_Goat's desperation valve, kept as one rule rather than a system.
func act_overdraft(i: int) -> bool:
	# ONCE per turn. The fuzz bot stacked it to air 8 against a bound of 5,
	# which is unlimited actions for HP: a dominant strategy, not a valve.
	if i < 0 or i >= divers.size():
		return false
	var d = divers[i]
	if not OVERDRAFT_ENABLED:
		return false
	if outcome != "ongoing" or overdrafted or d.down or d.hp <= OVERDRAFT_HP:
		return false
	overdrafted = true
	d.hp -= OVERDRAFT_HP
	air += 1
	log_lines.append("%s burns %d HP for 1 Air" % [d.dname, OVERDRAFT_HP])
	return true

func _check_victory() -> void:
	for b in limb_broken:
		if not b:
			return
	outcome = "victory"
	log_lines.append("%s is disabled" % String(enc.get("title", "the crab")))

# ---- enemy turn --------------------------------------------------------
func end_turn() -> void:
	if outcome != "ongoing":
		return
	_no_reshut.clear()  # last turn's re-shut immunity expires as the enemy acts
	air_penalty = 0
	var any_hit := false
	var any_swing := false
	for a in locked:
		# a shut-down or broken limb simply does not swing. It is prevented,
		# not replaced, and a prevented attack is not "hitting empty water".
		if limb_broken[a.limb] or int(limb_stun[a.limb]) > 0:
			log_lines.append("the %s cannot swing" % LIMB_NAMES[a.limb])
			continue
		any_swing = true
		if bool(a.get("ramp", false)) and int(_ramp.get(int(a.limb), 0)) < 3:
			# bounded: +1 per un-prevented swing up to +3. Unbounded it
			# stopped measuring pressure and started executing anyone who
			# plays slowly, which is the casual band, not the masher.
			_ramp[int(a.limb)] = int(_ramp.get(int(a.limb), 0)) + 1
			log_lines.append("the %s runs hotter" % LIMB_NAMES[a.limb])
		var hit := false
		for d in divers:
			if d.down:
				continue
			if d.station in a.stations:
				hit = true
				any_hit = true
				d.hp -= int(a.dmg)
				log_lines.append("the %s %s %s for %d" % [LIMB_NAMES[a.limb], a.name, d.dname, int(a.dmg)])
				if d.hp <= 0:
					d.hp = 0
					d.down = true
					log_lines.append("%s is down" % d.dname)
		if not hit and salvage_station >= 0 and not salvage_crushed and salvage_station in a.stations:
			# the crate does not dodge: an unblocked swing through its
			# station lands on the salvage, not on empty water
			hit = true
			any_hit = true
			salvage_hp -= int(a.dmg)
			log_lines.append("the %s %s the salvage crate for %d" % [LIMB_NAMES[a.limb], a.name, int(a.dmg)])
			if salvage_hp <= 0:
				salvage_hp = 0
				salvage_crushed = true
				log_lines.append("the salvage is crushed; you will surface with nothing")
		elif not hit:
			log_lines.append("the %s hits empty water and cuts an air line" % LIMB_NAMES[a.limb])
	# The vacate rule: a swing that lands on nobody cuts the umbilicals.
	# Without it three divers empty every targeted station every turn and
	# the enemy never connects.
	if any_swing and not any_hit:
		air_penalty = 1
	_rotation += 1
	if alive().is_empty():
		outcome = "defeat"
		log_lines.append("the squad is lost")
	for i in range(limb_stun.size()):
		if int(limb_stun[i]) > 0:
			limb_stun[i] = int(limb_stun[i]) - 1
			if int(limb_stun[i]) == 0:
				_no_reshut[i] = true
	turn += 1
	overdrafted = false
	_moved.clear()
	air = air_this_turn()
	_lock_intent()


# Deep-set search needs to try an action and unwind. Cloning keeps the sim
# pure: no undo stack, no hidden state to get out of sync.
#
# This was deleted by a careless slice replacement of end_turn, and because
# the deep set's stderr was not gated, the dominance search crashed silently
# and two passes counted as DRY while finding nothing because they could not
# run at all.
func clone() -> Combat:
	var c := Combat.new(enc_id)
	for i in range(divers.size()):
		var a = divers[i]
		var b = c.divers[i]
		b.hp = a.hp; b.station = a.station; b.down = a.down
		b.kit = a.kit
	c.limb_hp = limb_hp.duplicate()
	c.limb_broken = limb_broken.duplicate()
	c.limb_stun = limb_stun.duplicate()
	c.air = air; c.air_penalty = air_penalty; c.turn = turn
	c.outcome = outcome; c._rotation = _rotation
	# duplicate(true): the shallow copy shared the intent dicts, so an
	# action searched ON A CLONE (deep.gd, action_legal) corrupted the
	# parent's live telegraph (Aug 8 audit)
	c.overdrafted = overdrafted; c.locked = locked.duplicate(true)
	c._moved = _moved.duplicate()
	c._desperate = _desperate.duplicate()
	c._ramp = _ramp.duplicate()
	c._no_reshut = _no_reshut.duplicate()
	c.salvage_hp = salvage_hp
	c.salvage_station = salvage_station
	c.salvage_crushed = salvage_crushed
	# found while adding _moved: clones were losing their limb reads, so
	# every searched line played with amnesia about traits it had paid for
	c.analyzed = analyzed.duplicate()
	return c
