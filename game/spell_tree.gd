# Static spell data and learning rules; one tree per diver (keyed by Diver.model_name).
# Spells are battle.gd move defs; "requires_spells"/"requires_items" gate nodes, "cost" buys once, "oxygen_cost" (cost*8) is per cast.
# "inventory": true heal/revive spells are also castable from the pause menu. Learning auto-equips.
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
				"description": "A heavier cut carried on a current - more damage, less certain to land. Requires an Abyssal Lens.",
				"requires_spells": ["swift_strike"], "requires_items": ["abyssal_lens"],
				"power": 10, "acc_mod": 1, "oxygen_cost": 16.0,
				"hint": "Heavier, less certain", "text": "You carve a riptide slash",
			},
			"tidal_burst": {
				"display": "Tidal Burst", "cost": 3,
				"description": "A devastating burst of churning water. Real miss risk - the glass cannon's payoff move. Requires a Current Pearl.",
				"requires_spells": ["riptide_slash"], "requires_items": ["current_pearl"],
				"power": 17, "acc_mod": -4, "oxygen_cost": 24.0,
				"hint": "Devastating, real miss risk", "text": "You unleash a churning tidal burst",
			},
		},
		"debuff": {
			"current_snare": {
				"display": "Current Snare", "cost": 1,
				"description": "Wraps the target in a dragging current, lowering its evasion.",
				"requires_spells": [], "requires_items": [],
				"debuff": "evasion", "amount": 1, "acc_mod": 3, "oxygen_cost": 8.0,
				"hint": "Lowers evasion", "text": "A snare of current wraps the target",
			},
		},
		# Her only heal: learned with Spell Points (her base kit has none).
		"support": {
			"healing_current": {
				"display": "Healing Current", "cost": 2,
				"description": "A strong current restores 10 HP to the whole party.",
				"requires_spells": [], "requires_items": [],
				"effect": "heal", "amount": 10, "target": "all_allies", "oxygen_cost": 16.0, "inventory": true,
				"hint": "Restores 10 HP to everyone", "text": "You channel a stronger mending current",
			},
		},
	},
	"Prototype_1(1910)": {
		"debuff": {
			"weaken": {
				"display": "Weaken Empowered", "cost": 1,
				"description": "Strikes a nerve, lowering the target's defense.",
				"requires_spells": [], "requires_items": [],
				"debuff": "defense", "amount": 2, "acc_mod": 1, "oxygen_cost": 8.0,
				"hint": "Greatly lowers defense", "text": "You strike a nerve - defense drops",
			},
			"slow": {
				"display": "Slow Empowered", "cost": 1,
				"description": "Hobbles the target, lowering its agility.",
				"requires_spells": [], "requires_items": [],
				"debuff": "agility", "amount": 2, "acc_mod": 1, "oxygen_cost": 8.0,
				"hint": "Greatly lowers agility", "text": "You hobble the target - agility drops",
			},
			"blinding_silt": {
				"display": "Blinding Silt", "cost": 2,
				"description": "Kicks up a cloud that lowers the target's accuracy - builds on the same opening Weaken Empowered creates. Requires a Sunken Core.",
				"requires_spells": ["weaken"], "requires_items": ["sunken_core"],
				"debuff": "accuracy", "amount": 3, "acc_mod": 1, "oxygen_cost": 16.0,
				"hint": "Lowers accuracy", "text": "A cloud of silt blinds the target",
			},
			"exploit_opening": {
				"display": "Exploit Opening", "cost": 3,
				"description": "A precise strike into every weakness you've already opened up. Rarely misses. Requires an Abyssal Lens.",
				"requires_spells": ["blinding_silt"], "requires_items": ["abyssal_lens"],
				"power": 8, "acc_mod": 5, "oxygen_cost": 24.0,
				"hint": "A precise strike", "text": "You exploit the opening",
			},
		},
		"offense": {
			"precise_jab": {
				"display": "Precise Jab", "cost": 1,
				"description": "A quick, accurate jab - reliability over raw power.",
				"requires_spells": [], "requires_items": [],
				"power": 4, "acc_mod": 2, "oxygen_cost": 8.0,
				"hint": "Accurate", "text": "You land a precise jab",
			},
		},
	},
	"Prototype_V(1922)": {
		"offense": {
			"heavy_slam": {
				"display": "Heavy Slam", "cost": 1,
				"description": "A very heavy blow - slow and uncertain to land, but hits hard when it does.",
				"requires_spells": [], "requires_items": [],
				# Base ACC is 1 and never rises, so acc_mod stays 0 (it requires exhausting EVA instead).
				"power": 12, "acc_mod": 0, "oxygen_cost": 10.0,
				"hint": "Very heavy, slow to land", "text": "You drive a heavy slam home",
			},
		},
		"debuff": {
			"guard_break": {
				"display": "Guard Break", "cost": 2,
				"description": "Batters through the target's guard, lowering its defense. Requires a Sunken Core.",
				"requires_spells": [], "requires_items": ["sunken_core"],
				"debuff": "defense", "amount": 3, "acc_mod": 4, "oxygen_cost": 16.0,
				"hint": "Lowers target's defense by 3", "text": "You batter through the target's guard",
			},
		},
		# heal/revive always succeed and target an ally (battle.gd _resolve_move()).
		"support": {
			"mending_current": {
				"display": "Mending Current", "cost": 1,
				"description": "Wraps an ally in a warm current, restoring 8 HP.",
				"requires_spells": [], "requires_items": [],
				"effect": "heal", "amount": 8, "oxygen_cost": 8.0, "inventory": true,
				"hint": "Restores an ally's HP", "text": "You wrap an ally in a mending current",
			},
			"tidal_revival": {
				"display": "Tidal Revival", "cost": 3,
				"description": "Pulls a downed ally back up on a surge of current.",
				"requires_spells": ["mending_current"], "requires_items": ["reef_plate"],
				"effect": "revive", "amount": 12, "oxygen_cost": 28.0, "inventory": true,
				"hint": "Revives a downed ally", "text": "A surge of current pulls an ally back up",
			},
		},
	},
}

static func tree_for(model_name: String) -> Dictionary:
	return SPELL_TREES.get(model_name, SPELL_TREES["Staff_Diver"])

# Fixed column order for the UI, independent of each tree's key order.
const BRANCH_ORDER := ["offense", "debuff", "defense", "support"]
# Auto-learn order where it differs from BRANCH_ORDER: Bucky picks up his heal
# (Mending Current) before Heavy Slam.
const LEARN_BRANCH_ORDER := {
	"Prototype_V(1922)": ["support", "offense", "debuff", "defense"],
}

static func branches(model_name: String) -> Array:
	var tree: Dictionary = tree_for(model_name)
	return BRANCH_ORDER.filter(func(b: String) -> bool: return tree.has(b))

static func spell_def(model_name: String, branch: String, spell_id: String) -> Dictionary:
	return tree_for(model_name)[branch][spell_id]

# Looks a spell up without knowing its branch.
static func find_def(model_name: String, spell_id: String) -> Dictionary:
	var tree: Dictionary = tree_for(model_name)
	for branch in tree:
		if tree[branch].has(spell_id):
			return tree[branch][spell_id]
	return {}

# Callers supply key_items; this file doesn't know where they're tracked.
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

# Spends points and grants the spell; returns false and changes nothing if can_learn() fails.
static func learn(diver: Diver, branch: String, spell_id: String, key_items: Array) -> bool:
	if not can_learn(diver, branch, spell_id, key_items):
		return false
	var def: Dictionary = spell_def(diver.model_name, branch, spell_id)
	diver.stats.spell_points -= int(def.cost)
	diver.known_spells.append(spell_id)
	# Learned spells are equipped automatically.
	if not diver.equipped_spells.has(spell_id):
		diver.equipped_spells.append(spell_id)
	return true

# Migrates older saves: every known spell equipped, in learned order.
static func equip_all_known(diver: Diver) -> void:
	for spell_id in diver.known_spells:
		if not diver.equipped_spells.has(spell_id):
			diver.equipped_spells.append(spell_id)

# Spends every usable point, repeating until no progress so new prerequisites unlock dependents.
# True once the diver has learned every spell in their tree.
static func knows_all(diver: Diver) -> bool:
	var tree := tree_for(diver.model_name)
	for branch in tree:
		for spell_id in tree[branch]:
			if not diver.known_spells.has(String(spell_id)):
				return false
	return not tree.is_empty()

static func learn_all_available(diver: Diver, key_items: Array) -> PackedStringArray:
	var learned := PackedStringArray()
	var tree := tree_for(diver.model_name)
	var made_progress := true
	var order: Array = LEARN_BRANCH_ORDER.get(diver.model_name, BRANCH_ORDER)
	while made_progress:
		made_progress = false
		for branch in order:
			if not tree.has(branch):
				continue
			for spell_id in tree[branch]:
				if learn(diver, String(branch), String(spell_id), key_items):
					learned.append(String(spell_def(diver.model_name, String(branch), String(spell_id)).display))
					made_progress = true
	return learned
