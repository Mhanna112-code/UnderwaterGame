# Encounters as DATA. Every beat after fight one needs a different anatomy,
# and "the enemy is the board" (SPEC 2.4) means an enemy IS a level: its
# limbs, which stations expose them, and what it does on its turn.
#
# The station-to-limb map lives here ONCE and is read by the sim and the
# presentation both, so the contract can never be two lists that agree
# (SPEC 4.2.3, the bug that made the gullet seal silent last project).
class_name Encounters
extends RefCounted

const FRONT := 0
const FLANK := 1
const UNDER := 2
const REAR := 3
const BACKLINE := 4

static var ALL := {
	# Beat `descent`. One diver, one limb, NO station choice: it teaches
	# that a turn is a budget and the enemy announces itself, before
	# geography exists to complicate either (SPEC 2.7, one idea per beat).
	"descent": {
		"title": "something in the dark",
		"art": {"kind": "lurker", "scale": 150.0, "pos": [900, 330], "tint": [0.58, 0.68, 0.74]},
		"places": {"0": [600, 400]},
		# TEACHING BEAT, exempt from the difficulty bands and from the
		# dominant-station check by declaration, not by a silent special
		# case. Its job is to establish that a turn is a budget and the
		# enemy announces itself; it is meant to be trivially winnable and
		# to have exactly one place to stand.
		"teaching": true,
		"party": 1,
		"drum": false,
		"open_stations": [FRONT],
		"starts": [FRONT],
		"limbs": [{"name": "maw", "hp": 6, "station": FRONT}],
		"attacks": [{"limb": 0, "stations": [FRONT], "dmg": 5, "name": "snaps at"}],
	},
	# Beat `fight1`. Three limbs, four stations, UNDER deliberately empty.
	"crab": {
		"title": "the hunter crab",
		"art": {"kind": "crab", "scale": 158.0, "pos": [872, 330], "tint": [1.0, 1.0, 1.0]},
		"places": {"0": [590, 392], "1": [788, 322], "2": [896, 520], "3": [1108, 322]},
		# TWO divers. One was tried and REFUTED by measurement: the crab
		# became unwinnable (G2 0/40), casual fell to 5.2 percent, and
		# UNDER went dead because a lone diver never has a reason to stand
		# somewhere safe. The stations design needs two bodies, because
		# "who is standing where when the jaw comes down" is the whole
		# tension. Prototype1 earns its place here as the body that can
		# hold FRONT at 14 HP where Scuba at 8 cannot; it gains the drum,
		# and its verb, at the boat.
		"party": 2,
		"drum": false,
		# the jaw comes already read, so the first thing a player learns
		# about reading is what it BUYS, not what it costs
		"read_free": 0,
		"open_stations": [FRONT, FLANK, UNDER, REAR],
		# the opening tableau is content: Scuba in the jaw's face, Prototype1
		# under the belly. It decides what the first turn looks like and it
		# moves the bands, so it is declared rather than falling out of a loop.
		"starts": [FRONT, UNDER],
		"limbs": [
			# Swept after every limb gained an attack. Measured: casual
			# 69.3%, greedy 6.0 turns, 10.0 squad HP lost.
			# swept after Proto5 became the efficient heavy (8 dmg for 3 Air)
			# and the overdraft was cut. All three encounters land at limbs
			# x1.45: crab 66.7% / 9.0 turns / 14.0 HP
			# re-paid Aug 6 night: the free-move ruling made the casual bot
			# stronger everywhere (89.9 against a 90 ceiling here), so the
			# crab grew. Bands never move; the creature does.
			{"name": "jaw", "hp": 15, "station": FRONT, "trait": "brittle"},
			{"name": "claw", "hp": 12, "station": FLANK},
			{"name": "tail", "hp": 12, "station": REAR, "trait": "leaking"},
		],
		"refuge": UNDER,
		"_refuge_note": [
			# UNDER exists to be safe, not to act from: with the claw
			# pinching its own station every offensive stand is threatened
			# every turn, and ducking under the shell is the out. Declared,
			# and the declaration is checked (never in an arc, and
			# sometimes the only safe ground).
		],
		# SPEC 2.6 verbatim: "the jaw only reaches FRONT, and the tail sweeps
		# REAR and FLANK together. No conditions, no statuses, no special
		# rules." A third attack had crept in (the claw guarding the head),
		# which a fidelity review caught as a spec violation. The claw needs
		# no attack of its own to be worth breaking: the win condition is
		# breaking EVERY limb, so it is a target either way, and its station
		# is threatened by the tail so standing there still costs.
		"attacks": [
			{"limb": 0, "stations": [FRONT], "dmg": 5, "name": "snaps at"},
			# the claw had no attack at all, so FLANK was a free camp: the
			# station checks measured 66.7% occupancy the hour free moves
			# landed. The claw pinches its own station now.
			{"limb": 1, "stations": [FLANK], "dmg": 3, "name": "pinches at"},
			{"limb": 2, "stations": [REAR, FLANK], "dmg": 4, "name": "sweeps"},
		],
	},
	# Beat `reef1`. The artist's diversity ask made content: ONE limb,
	# and the limb is a squatter. The shell sits on FLANK and nobody
	# stands there until it is broken; its slam alternates around the
	# board, so the fight is a race to crack an armored thing that has
	# taken your ground. Fewer limbs, new question.
	"barnacle": {
		"title": "the barnacle",
		"art": {"kind": "crab", "scale": 120.0, "pos": [880, 330], "tint": [0.80, 0.62, 0.50]},
		"places": {"0": [600, 392], "1": [842, 330], "3": [1096, 392], "4": [338, 392]},
		"party": 2,
		"drum": true,
		"open_stations": [FRONT, FLANK, REAR, BACKLINE],
		"starts": [FRONT, BACKLINE],
		# two limbs is still the artist's "fewer": the single-limb space
		# proved degenerate against the pinned judge (a one-HP cliff
		# between clears-in-4 and stalemates-at-41), the same narrowness
		# the two-diver crab documented. The shell squats; the feeler
		# punishes the ground you pry from.
		"limbs": [
			{"name": "shell", "hp": 20, "station": FLANK, "trait": "leaking", "blocks": true},
			{"name": "feeler", "hp": 13, "station": REAR, "trait": "brittle"},
		],
		"attacks": [
			{"limb": 0, "stations": [REAR], "dmg": 5, "name": "slams"},
			{"limb": 0, "hunts": true, "stations": [], "dmg": 5, "name": "snaps toward"},
			{"limb": 1, "stations": [FRONT], "dmg": 4, "name": "scrapes at"},
			{"limb": 1, "stations": [FRONT, REAR], "dmg": 4, "name": "rakes"},
		],
	},
	# Beat `fight2`. A DIFFERENT anatomy, which is the question the whole
	# station design rests on: does the geometry survive a different body?
	# It inverts fight one deliberately. There, UNDER was the empty station
	# and REAR was swept; here UNDER holds a limb and REAR is the empty one,
	# so a player who learned "UNDER is safe" has to look again. Every close
	# station is threatened, which is what finally gives BACKLINE a reason
	# to exist and what makes the disabler's shutdown the answer.
	"spitter": {
		"title": "the vent worm",
		# a LONGER, thinner body: the stations sit further apart along it,
		# so the board itself reads differently from the crab's
		"art": {"kind": "worm", "scale": 188.0, "pos": [910, 312], "tint": [0.72, 0.78, 0.42]},
		"places": {"0": [584, 386], "1": [860, 318], "2": [952, 516], "4": [338, 386]},
		"party": 2,
		# The drum is fitted before this fight, so it is declared HERE.
		# While gear was a global set by the run, the bands measured the
		# worm without the drum: a configuration no player ever meets.
		"drum": true,
		# REAR is not open here. It held no limb AND the maw reached it, so
		# it was strictly dominated and the histogram called it dead. The
		# inversion is sharper without it: in fight one UNDER was the safe
		# empty station, here UNDER holds a limb and BACKLINE is the safe
		# one, so a player who learned "UNDER is safe" must look again.
		"open_stations": [FRONT, FLANK, UNDER, BACKLINE],
		"starts": [FRONT, BACKLINE],
		"limbs": [
			# swept at the played configuration, drum fitted
			# swept: casual 60.0%, greedy 6.0 turns, 14.0 squad HP lost.
			# Chose the harder-hitting variant so damage CLIMBS across the
			# ladder (crab 2s, worm 5/5/3, dredge 4/3/4) rather than the
			# gentler one that would have made fight two easier than fight
			# one.
			{"name": "maw", "hp": 10, "station": FRONT, "trait": "brittle"},
			{"name": "vent", "hp": 7, "station": FLANK, "trait": "pressurised"},
			{"name": "gut", "hp": 7, "station": UNDER, "trait": "plated"},
		],
		# Every limb attacks, so every station is threatened by something and
		# breaking any of them changes the map. The gut had no attack, which
		# made BACKLINE free safety: the greedy bot simply parked both divers
		# there, stunned whatever was winding up, and finished the fight
		# without taking a scratch. Same defect as the crab's claw, found the
		# same way.
		"attacks": [
			{"limb": 0, "stations": [FRONT], "dmg": 5, "name": "lunges at"},
			{"limb": 1, "stations": [FLANK, UNDER], "dmg": 5, "name": "sprays"},
			# the first hunting arc in the run: the vent tracks a diver's
			# actual station, announced a turn ahead. Moving after the
			# announcement is the dodge. It cannot reach the back line,
			# which is what makes standing back a real choice here.
			{"limb": 1, "hunts": true, "stations": [], "dmg": 5, "name": "chases"},
			{"limb": 2, "stations": [BACKLINE], "dmg": 3, "name": "vents over"},
			{"limb": 2, "stations": [UNDER], "dmg": 3, "name": "curls at"},
		],
	},
	# Beat `deep1`. A MACHINE, not a creature: SPEC 2.4 says a machine reads
	# as a puzzle box and should be earned after anatomy is taught, and by
	# now it has been, twice. Every station is open and every one is
	# threatened, so evading everything means moving the whole squad, which
	# is expensive with the big suit in the party. That is the beat where
	# the umbilical rule and the HP overdraft finally bite.
	"dredge": {
		"title": "the dredge",
		"art": {"kind": "dredge", "scale": 168.0, "pos": [884, 320], "tint": [0.46, 0.40, 0.30]},
		"places": {"0": [614, 400], "1": [782, 326], "3": [1108, 348], "4": [338, 400]},
		"party": 3,
		"drum": true,
		# UNDER is closed here. Every open station must either expose a limb
		# or be safe; UNDER would have been threatened and empty, which is
		# dead by construction. BACKLINE is the single safe place, and it
		# earns that because the drum reaches from it.
		"open_stations": [FRONT, FLANK, REAR, BACKLINE],
		"starts": [FRONT, BACKLINE, FLANK],
		# the pump part, physically on the board at the winch's own
		# station: the thing the whole run is FOR, defensible at the cost
		# of standing there. Sized to survive two lashes, not three.
		"salvage": {"station": REAR, "hp": 7},
		"limbs": [
			# swept after the boiler widened to three stations. Measured:
			# casual 63.3%, greedy 7.0 turns, 8.0 squad HP lost.
			# re-swept after the limbs gained alternating arcs. Splitting the
			# boiler's three-station vent into two smaller ones bought the
			# player safe ground and handed back too much: casual 92.5%,
			# outside the pinned band. Paid for in limb HP and damage, not
			# by moving the band.
			# re-paid Aug 6 night for the free-move ruling: greedy with free
			# repositioning cleared 31 total HP in 4 turns against a 6-turn
			# teaching floor, so the dredge grew to match the squad.
			# no brittle limb here on purpose: with the heavy's 8 landing
			# 16 on brittle, any brittle limb under 17 HP is a free
			# one-shot that deletes a third of the fight's pressure at
			# zero thought. The dredge is the fight about ORDER: the
			# pressurised boiler is the read that matters.
			# smaller limbs after the no-reshut rule and the ramp landed:
			# the fight gained two kinds of pressure the same evening, so
			# it gives back duration. Bands never move; the creature does.
			{"name": "arm", "hp": 12, "station": FRONT, "trait": "plated"},
			{"name": "boiler", "hp": 12, "station": FLANK, "trait": "pressurised"},
			{"name": "winch", "hp": 11, "station": REAR, "trait": "leaking"},
		],
		"attacks": [
			{"limb": 0, "stations": [FRONT, FLANK], "dmg": 4, "name": "sweeps"},
			{"limb": 0, "hunts": true, "stations": [], "dmg": 5, "name": "swings for"},
			# the vent-back-over arc made the drum platform untenable in the
			# one fight that needs it most: the hunt cannot reach BACKLINE,
			# so BACKLINE is where you answer the hunt, and the boiler was
			# hitting it every other turn. It alternates close arcs now.
			# the boiler RAMPS: every swing it lands un-prevented, its next
			# announced number grows by one, printed in the telegraph. Shut
			# it or break it and the climb stops. This is what finally
			# makes attack-only play lose the last fight: the masher races
			# a clock, the judge answers it.
			{"limb": 1, "stations": [FLANK], "dmg": 3, "name": "vents over", "ramp": true},
			{"limb": 1, "stations": [FLANK], "dmg": 3, "name": "hisses at", "ramp": true},
			{"limb": 2, "stations": [REAR], "dmg": 3, "name": "lashes"},
		],
	},
	# UnderwaterGame fight one: the goblin grunt. A SHOOTER, which the
	# creatures in SALVAGE never were, so the geometry means something new:
	# its reach is announced and long, and the answer is where you stand
	# rather than what you break first.
	#
	# Anatomy read off the clips the model actually has (Idle, Shooting1,
	# Shooting2, Taunt1, Walking). Standing rule from the last project:
	# ability and attack names come FROM the animation list, so nothing on
	# screen is a motion nobody authored.
	"goblin": {
		"title": "the goblin grunt",
		"rig": "GoblinGrunt",
		"party": 2,
		"drum": false,
		# the gun arm comes already read, so the first read a player does is
		# one they chose rather than one they owed
		"read_free": 0,
		# it shoots: accuracy eats a point of anyone's dodge
		"accuracy": 1,
		# Two rows, not four stations. Nobody at the Aug 15 meeting wanted to
		# choose which of four places each diver stood in; the trade they did
		# want is front reaches and is reached, back is safe and cannot swing.
		"rows": true,
		"open_stations": [FRONT, BACKLINE],
		"starts": [FRONT, BACKLINE],
		# Swept four times, not chosen. The last pass had to sweep DOWNWARD:
		# once the back row could reach at half damage and the whole squad
		# could share a row, the creature I had paid up was far too strong
		# and casual play measured 7 percent. Bands never move; the enemy
		# does, in both directions.
		#
		# Swept three times before that. Rows changed the shape again: with
		# only two places to stand the front row eats everything, so the
		# creature was paid in damage rather than in limb health, which was
		# already long enough to sit through.
		#
		# Swept twice before that. The first pass put a fight with no stat
		# system into band. Adding dodge, armour and barriers handed the
		# squad most of it back (casual 79.5 to 98.5 percent), so the
		# creature was re-paid in the same currency: another +3 limb HP and
		# +1 damage, measured, not guessed. Bands never move; the enemy does.
		"limbs": [
			# in row mode a limb's station is what the FRONT row exposes, so
			# the geography is carried by which of them is still standing
			{"name": "gun arm", "hp": 11, "station": FRONT, "trait": "brittle"},
			{"name": "satchel", "hp": 10, "station": BACKLINE, "trait": "pressurised"},
			{"name": "legs", "hp": 10, "station": FRONT, "trait": "plated"},
		],
		# Every limb reaches something, so no station is free parking. The
		# hunt is what a gun is FOR: it announces a station a turn early and
		# tracks whoever stood there, so moving after the announcement is the
		# dodge and standing still is a decision.
		"attacks": [
			{"limb": 0, "stations": [FRONT], "dmg": 6, "name": "fires on"},
			{"limb": 0, "hunts": true, "stations": [], "dmg": 6, "name": "draws a bead on"},
			# the satchel is what stops the back row being free parking: a
			# lobbed charge is the one thing that reaches it
			{"limb": 1, "stations": [BACKLINE], "dmg": 5, "name": "lobs a charge at"},
			{"limb": 2, "stations": [FRONT], "dmg": 5, "name": "kicks back at"},
		],
	},
}

# The station-to-limb table, derived from the limb list so it can never
# disagree with it.
static func station_limb(enc: Dictionary) -> Array:
	var out := [-1, -1, -1, -1, -1]
	var limbs: Array = enc.limbs
	for i in range(limbs.size()):
		out[int(limbs[i].station)] = i
	return out
