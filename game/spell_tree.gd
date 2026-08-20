# All spell data and the rules for learning/equipping it, in one place with
# no state of its own - every function here is static. Nothing needs a
# .new().
#
# One tree PER DIVER (keyed by Diver.model_name), not one shared tree - see
# SPELL_TREES below. Each diver's tree is shaped to read as their role
# through which branch is deep vs. shallow, not just through numbers:
#   Staff_Diver (Mermaid): offense is the deep branch, defense is a single
#     weak node - a fast glass cannon with almost nothing to fall back on.
#     support is a single node too, upgrading the free "Heal" base move she
#     starts every game with (see battle.gd's BASE_MOVES) rather than
#     giving her a real sustain branch to lean on.
#   Prototype_1(1910) (Diver Boy): debuff is the deep branch, with four
#     different status effects to chain - utility, not raw power.
#   Prototype_V(1922) (Marine Man): defense is the deep branch, all barrier
#     spells that scale up to a real wall - tank/support, reliable rather
#     than flashy (barrier spells never miss, unlike everything else).
#
# Each branch is a small DAG, not a straight line: a spell's
# "requires_spells" can point at any earlier node in its branch, so one
# node can unlock several different follow-ups at once. "requires_items" is
# the same idea for key items earned from NPC mini-quests later - not
# wired to a real source yet (see find_def()'s caller sites), so any spell
# gated behind one is intentionally unreachable for now, same as it's been
# since this system was scaffolded.
#
# Every spell doubles as a battle.gd move definition - "power"/"acc_mod"
# work exactly like BASE_MOVES entries there. "effect" picks how the move
# resolves: "damage" (default, omitted) hits the target normally, "debuff"
# (paired with a "debuff"/"amount" key) lowers one of the target's stats,
# "barrier" targets the caster instead and adds "amount" to their own
# barrier, capped at barrier_max, always succeeding (no accuracy check) -
# see battle.gd's _resolve_move().
#
# "oxygen_cost" is what casting the spell actually costs in battle (read by
# battle.gd's _moves_for()/_resolve_party_move()) - a completely different
# spend from "cost" above, which only pays for *learning* it once at a save
# point. Every spell here uses cost*8 so a spell's up-front point price and
# its per-cast oxygen price stay proportional without needing two numbers
# hand-tuned per entry - see battle.gd's BASE_MOVES for each diver's one
# move that's exempt from any oxygen cost at all (their free basic attack).
#
# "inventory": true marks a "heal"/"revive" spell as also usable outside
# battle, from the Escape-key pause menu's "Party Spells" tab - see
# World._inventory_spells_for()/World.use_party_spell(), which only know
# how to resolve those two effects (same restriction as battle.gd's
# BASE_MOVES' own "inventory" tag). A known spell shows up there the moment
# it's learned, whether or not it's actually equipped for battle - the
# 4-slot equip cap (Diver.MAX_EQUIPPED_SPELLS) is a battle-loadout
# restriction, not a "can this diver use it at all" one.
class_name SpellTree
extends RefCounted

const SPELL_TREES := {
	"Staff_Diver": {
		"offense": {
			"swift_strike": {
				"display": "Swift Strike", "cost": 1,
				"description": "A fast, reliable lash - low risk, modest damage.",
				"requires_spells": [], "requires_items": [],
				"power": 5, "acc_mod": 6, "oxygen_cost": 8.0,
				"hint": "Fast, reliable", "text": "You lash out in a burst of speed",
			},
			"riptide_slash": {
				"display": "Riptide Slash", "cost": 2,
				"description": "A heavier cut carried on a current - more damage, less certain to land.",
				"requires_spells": ["swift_strike"], "requires_items": [],
				"power": 10, "acc_mod": 1, "oxygen_cost": 16.0,
				"hint": "Heavier, less certain", "text": "You carve a riptide slash",
			},
			"tidal_burst": {
				"display": "Tidal Burst", "cost": 3,
				"description": "A devastating burst of churning water. Real miss risk - the glass cannon's payoff move. Needs a current pearl to learn.",
				"requires_spells": ["riptide_slash"], "requires_items": ["current_pearl"],
				"power": 17, "acc_mod": -4, "oxygen_cost": 24.0,
				"hint": "Devastating, real miss risk", "text": "You unleash a churning tidal burst",
			},
		},
		"debuff": {
			"current_snare": {
				"display": "Current Snare", "cost": 1,
				"description": "Wraps the target in a dragging current, lowering its agility.",
				"requires_spells": [], "requires_items": [],
				"debuff": "agility", "amount": 3, "acc_mod": 3, "oxygen_cost": 8.0,
				"hint": "Lowers agility", "text": "A snare of current wraps the target",
			},
		},
		"defense": {
			"brief_ward": {
				"display": "Brief Ward", "cost": 2,
				"description": "A thin veil of current - a small, temporary shield. The only defensive trick a glass cannon keeps around.",
				"requires_spells": [], "requires_items": [],
				"effect": "barrier", "amount": 4, "oxygen_cost": 16.0,
				"hint": "A thin shield", "text": "A thin veil of current wraps you",
			},
		},
		# A single improvement over her free base "Heal" move (see
		# battle.gd's BASE_MOVES), not a real support branch to rival
		# Prototype_V(1922)'s - she still has nothing to fall back on for
		# actual survivability, just a stronger version of the sustain she
		# already starts with.
		"support": {
			"healing_current": {
				"display": "Healing Current", "cost": 2,
				"description": "A stronger current than her free heal knows - restores more HP.",
				"requires_spells": [], "requires_items": [],
				"effect": "heal", "amount": 10, "oxygen_cost": 16.0, "inventory": true,
				"hint": "Restores more HP than her base heal", "text": "You channel a stronger mending current",
			},
		},
	},
	"Prototype_1(1910)": {
		"debuff": {
			"weaken": {
				"display": "Weaken", "cost": 1,
				"description": "Strikes a nerve, lowering the target's defense.",
				"requires_spells": [], "requires_items": [],
				"debuff": "defense", "amount": 2, "acc_mod": 2, "oxygen_cost": 8.0,
				"hint": "Lowers defense", "text": "You strike a nerve - defense drops",
			},
			"slow": {
				"display": "Slow", "cost": 1,
				"description": "Hobbles the target, lowering its agility.",
				"requires_spells": [], "requires_items": [],
				"debuff": "agility", "amount": 2, "acc_mod": 2, "oxygen_cost": 8.0,
				"hint": "Lowers agility", "text": "You hobble the target - agility drops",
			},
			"blinding_silt": {
				"display": "Blinding Silt", "cost": 2,
				"description": "Kicks up a cloud that lowers the target's accuracy - builds on the same opening Weaken creates.",
				"requires_spells": ["weaken"], "requires_items": [],
				"debuff": "accuracy", "amount": 3, "acc_mod": 1, "oxygen_cost": 16.0,
				"hint": "Lowers accuracy", "text": "A cloud of silt blinds the target",
			},
			"exploit_opening": {
				"display": "Exploit Opening", "cost": 3,
				"description": "A precise strike into every weakness you've already opened up. Rarely misses.",
				"requires_spells": ["blinding_silt"], "requires_items": [],
				"power": 8, "acc_mod": 5, "oxygen_cost": 24.0,
				"hint": "A precise strike, rarely misses", "text": "You exploit the opening",
			},
		},
		"offense": {
			"precise_jab": {
				"display": "Precise Jab", "cost": 1,
				"description": "A quick, near-unmissable jab - reliability over raw power.",
				"requires_spells": [], "requires_items": [],
				"power": 4, "acc_mod": 8, "oxygen_cost": 8.0,
				"hint": "Nearly unmissable", "text": "You land a precise jab",
			},
		},
		"defense": {
			"evasive_ward": {
				"display": "Evasive Ward", "cost": 2,
				"description": "Weaves a moderate shield from open water.",
				"requires_spells": [], "requires_items": [],
				"effect": "barrier", "amount": 5, "oxygen_cost": 16.0,
				"hint": "A moderate shield", "text": "You weave an evasive ward",
			},
		},
	},
	"Prototype_V(1922)": {
		"defense": {
			"barrier_pulse": {
				"display": "Barrier Pulse", "cost": 1,
				"description": "A pulse of pressure raises a shield. Never misses.",
				"requires_spells": [], "requires_items": [],
				"effect": "barrier", "amount": 5, "oxygen_cost": 8.0,
				"hint": "Raises a shield", "text": "A pulse of pressure raises your shield",
			},
			"iron_shell": {
				"display": "Iron Shell", "cost": 2,
				"description": "Hardens your shield further, building on Barrier Pulse.",
				"requires_spells": ["barrier_pulse"], "requires_items": [],
				"effect": "barrier", "amount": 9, "oxygen_cost": 16.0,
				"hint": "A heavier shield", "text": "Your shell hardens further",
			},
			"bulwark_stance": {
				"display": "Bulwark Stance", "cost": 3,
				"description": "A near-total shield - the tank's capstone. Needs a reef plate to learn.",
				"requires_spells": ["iron_shell"], "requires_items": ["reef_plate"],
				"effect": "barrier", "amount": 14, "oxygen_cost": 24.0,
				"hint": "A near-total shield", "text": "You brace into an unbreakable bulwark",
			},
		},
		"offense": {
			"heavy_slam": {
				"display": "Heavy Slam", "cost": 1,
				"description": "A very heavy blow - slow and uncertain to land, but hits hard when it does.",
				"requires_spells": [], "requires_items": [],
				"power": 14, "acc_mod": -3, "oxygen_cost": 8.0,
				"hint": "Very heavy, slow to land", "text": "You drive a heavy slam home",
			},
		},
		"debuff": {
			"guard_break": {
				"display": "Guard Break", "cost": 2,
				"description": "Batters through the target's guard, lowering its defense.",
				"requires_spells": [], "requires_items": [],
				"debuff": "defense", "amount": 3, "acc_mod": 0, "oxygen_cost": 16.0,
				"hint": "Cracks the target's defense", "text": "You batter through the target's guard",
			},
		},
		# Nobody else has this branch - Prototype_V(1922) is this game's one
		# tank/support diver (see this file's header comment), and healing/
		# reviving an ally is the clearest possible expression of "support"
		# a spell can be. "effect": "heal"/"revive" here are read by
		# battle.gd's _resolve_move() exactly like "barrier" already is -
		# always succeeds, no accuracy check, targets an ally instead of an
		# enemy (see _on_move_chosen()'s target-pool branch for each).
		"support": {
			"mending_current": {
				"display": "Mending Current", "cost": 1,
				"description": "Wraps an ally in a warm current, restoring some HP.",
				"requires_spells": [], "requires_items": [],
				"effect": "heal", "amount": 8, "oxygen_cost": 8.0, "inventory": true,
				"hint": "Restores an ally's HP", "text": "You wrap an ally in a mending current",
			},
			"tidal_revival": {
				"display": "Tidal Revival", "cost": 3,
				"description": "Pulls a downed ally back up on a surge of current. The tank's other capstone - reviving an ally is worth more than any amount of raw defense.",
				"requires_spells": ["mending_current"], "requires_items": [],
				"effect": "revive", "amount": 12, "oxygen_cost": 28.0, "inventory": true,
				"hint": "Revives a downed ally", "text": "A surge of current pulls an ally back up",
			},
		},
	},
}

static func tree_for(model_name: String) -> Dictionary:
	return SPELL_TREES.get(model_name, SPELL_TREES["Staff_Diver"])

# Fixed order rather than tree_for(model_name).keys() - each diver's tree
# dict is written with a different key order (whichever branch is "theirs"
# comes first, for readability in the data above), but the UI's three
# columns need to land in the same left-to-right order for every diver, or
# switching whose tree you're viewing would shuffle the whole screen.
const BRANCH_ORDER := ["offense", "debuff", "defense", "support"]

static func branches(model_name: String) -> Array:
	var tree: Dictionary = tree_for(model_name)
	return BRANCH_ORDER.filter(func(b: String) -> bool: return tree.has(b))

static func spell_def(model_name: String, branch: String, spell_id: String) -> Dictionary:
	return tree_for(model_name)[branch][spell_id]

# Looks a spell id up without knowing which branch it's in - used by
# SpellEquipUI (which only has known_spells, just ids) and by battle.gd
# (which only has equipped_spells, also just ids).
static func find_def(model_name: String, spell_id: String) -> Dictionary:
	var tree: Dictionary = tree_for(model_name)
	for branch in tree:
		if tree[branch].has(spell_id):
			return tree[branch][spell_id]
	return {}

# key_items is passed in rather than read from a global - nothing here
# should assume where the party's key items are tracked (that's
# QuestManager's job, not built yet). Callers own that lookup.
static func can_learn(diver: Diver, branch: String, spell_id: String, key_items: Array) -> bool:
	if diver.known_spells.has(spell_id):
		return false
	var def: Dictionary = spell_def(diver.model_name, branch, spell_id)
	if diver.stats.spell_points < int(def.cost):
		return false
	for req in def.requires_spells:
		if not diver.known_spells.has(req):
			return false
	for item in def.requires_items:
		if not key_items.has(item):
			return false
	return true

# Spends the points and grants the spell - returns false and changes
# nothing if can_learn() would have failed, so a caller never needs to
# check both.
static func learn(diver: Diver, branch: String, spell_id: String, key_items: Array) -> bool:
	if not can_learn(diver, branch, spell_id, key_items):
		return false
	var def: Dictionary = spell_def(diver.model_name, branch, spell_id)
	diver.stats.spell_points -= int(def.cost)
	diver.known_spells.append(spell_id)
	return true

static func can_equip(diver: Diver, spell_id: String) -> bool:
	if not diver.known_spells.has(spell_id) or diver.equipped_spells.has(spell_id):
		return false
	return diver.equipped_spells.size() < Diver.MAX_EQUIPPED_SPELLS

static func equip(diver: Diver, spell_id: String) -> bool:
	if not can_equip(diver, spell_id):
		return false
	diver.equipped_spells.append(spell_id)
	return true

# Unlike learn(), unequipping is never actually invalid to attempt (a
# spell already missing from the loadout is just a no-op) - this returns
# whether anything changed, so callers know whether it's worth refreshing.
# (Array.erase() returns void in GDScript, not whether it found anything -
# the has() check is what actually answers that.)
static func unequip(diver: Diver, spell_id: String) -> bool:
	if not diver.equipped_spells.has(spell_id):
		return false
	diver.equipped_spells.erase(spell_id)
	return true
