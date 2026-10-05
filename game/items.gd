# All non-spell item data and the one rule for what an item actually does
# when you get it, in the same static/no-state shape as spell_tree.gd -
# nothing here needs a .new() either.
#
# Two kinds of item live in ITEMS, told apart by "kind":
#   - Consumables ("heal"/"oxygen" and the battle-only boosts) apply straight to a
#     Diver's stats the instant they're picked up - see grant(). These
#     are what ItemOrb hands out (see cracked_wall.gd's break handler in
#     world.gd - a shockwaved rock pops one, taken from EVEN_DROP_ORDER).
#   - Key items ("key") are party-wide spell requirements in spell_tree.gd
#     (see each spell's requires_items) - they don't touch a Diver's stats at all, they go
#     into World.key_items instead. grant() refuses these on purpose (see
#     below); world.gd adds them from guardian wins and fixed rock rewards
#     directly, since that's party-wide state, not a single diver's.
class_name Items
extends RefCounted

const ITEMS := {
	"potion": {
		"display": "Potion", "kind": "heal", "amount": 10,
		"description": "Restores 10 HP.",
	},
	"oxygen_cell": {
		"display": "Oxygen Cell", "kind": "oxygen", "amount": 30.0,
		"description": "Restores 30 oxygen.",
	},
	"current_pearl": {
		"display": "Current Pearl", "kind": "key",
		"description": "A key item. Unlocks Staff_Diver's Tidal Burst.",
	},
	"reef_plate": {
		"display": "Reef Plate", "kind": "key",
		"description": "A key item. Unlocks Prototype_V(1922)'s Tidal Revival.",
	},
	"abyssal_lens": {
		"display": "Abyssal Lens", "kind": "key",
		"description": "A key item. Unlocks Prototype_1(1910)'s Exploit Opening and Staff_Diver's Riptide Slash.",
	},
	"sunken_core": {
		"display": "Sunken Core", "kind": "key",
		"description": "A key item. Unlocks Prototype_V(1922)'s Guard Break and Prototype_1(1910)'s Blinding Silt.",
	},
	# Maze keys (used as KeyDoor.required_key_id / the vortex chest).
	"sphere_room_key": {
		"display": "Sphere Room Key", "kind": "key",
		"description": "Blasted out of a rock in the secret item room. Opens the room of swirling spheres.",
	},
	"vortex_key": {
		"display": "Vortex Key", "kind": "key",
		"description": "Found in the eye of the sphere vortex. Opens the sealed room between Box30 and Box32.",
	},
	"abyss_key": {
		"display": "Abyss Key", "kind": "key",
		"description": "Dropped by the secret boss. Opens the door to the main boss.",
	},
	"maze_nav_map": {
		"display": "Maze Navigation Map", "kind": "key",
		"description": "From the chest in the Control Room. Press L while within the maze to open the Maze Navigation Map.",
	},
	# battle_only, same as the old Blast Rocks move used to be flagged -
	# these raise strength/defense only for the fight they're used in.
	# grant() still just adds `amount` straight onto the stat like every
	# other consumable here; what makes it TEMPORARY is entirely on
	# battle.gd's side (_resolve_item() records the amount it just applied,
	# _revert_temp_buffs() subtracts it back off before the battle actually
	# ends) - Items itself has no notion of "for one fight," it only ever
	# grants or doesn't.
	"attack_up": {
		"display": "Attack Tonic", "kind": "attack_up", "amount": 4,
		"description": "Raises strength for the rest of this fight.",
		"battle_only": true,
	},
	"defense_up": {
		"display": "Defense Shell", "kind": "defense_up", "amount": 3,
		"description": "Raises defense for the rest of this fight.",
		"battle_only": true,
	},
	"accuracy_up": {
		"display": "Focus Tonic", "kind": "accuracy_up", "amount": 2,
		"description": "Raises accuracy for the rest of this fight.",
		"battle_only": true,
	},
	"evasion_up": {
		"display": "Slipstream Oil", "kind": "evasion_up", "amount": 2,
		"description": "Raises evasion for the rest of this fight.",
		"battle_only": true,
	},
}

# Removed items still present in older saves: dropped from inventory on Load,
# and a pending world drop of one becomes the first item of EVEN_DROP_ORDER.
const RETIRED_ITEMS := ["spell_shard"]

# Every consumable a breakable item rock can hold, each exactly once. Rocks
# take these in order by index (drop_for_rock()), so the item rocks spread
# them evenly instead of a random roll clumping potions. Key items stay out:
# two sit in fixed airborne rocks and the rest come from guardians.
const EVEN_DROP_ORDER := [
	"potion", "attack_up", "oxygen_cell", "defense_up", "accuracy_up", "evasion_up",
]

static func drop_for_rock(rock_index: int) -> String:
	return EVEN_DROP_ORDER[posmod(rock_index, EVEN_DROP_ORDER.size())]

# Equal odds of every consumable, for any caller without a fixed rock index.
static func random_drop() -> String:
	return EVEN_DROP_ORDER[randi_range(0, EVEN_DROP_ORDER.size() - 1)]

static func is_key_item(item_id: String) -> bool:
	return String(ITEMS.get(item_id, {}).get("kind", "")) == "key"

# Whether using this item right now would actually change anything -
# checked before grant() ever runs (see world.gd's use_inventory_item(),
# inventory_menu.gd's Use buttons, and battle.gd's item-target filtering)
# so a potion at full HP gets refused outright instead of being silently
# consumed for nothing, which is what grant() alone used to let happen
# (it already messaged "already at full health," but still returned a
# real message either way, and its caller never distinguished the two to
# skip the actual deduction). The battle-only boosts always help; a key item
# request always fails since is_key_item() catches it separately.
#
# MODIFIED: took a Diver originally - changed to CombatantStats directly
# so battle.gd's party entries (which only ever carry {stats, actor, ...}
# dicts, not real Diver nodes tied to world.divers - see battle.gd's own
# party_source loop) can call this without needing a Diver that doesn't
# exist in that context. A caller with a real Diver just passes
# `diver.stats` instead of `diver` now (see world.gd/inventory_menu.gd).
static func would_help(item_id: String, s: CombatantStats) -> bool:
	match String(ITEMS.get(item_id, {}).get("kind", "")):
		"heal":
			return s.hp < s.hp_max
		"oxygen":
			return s.oxygen < s.oxygen_max
		"attack_up", "defense_up", "accuracy_up", "evasion_up":
			return true
		_:
			return false

# Applies a consumable straight to `s` and returns a message fit to hand
# to World._announce() as-is - callers shouldn't need to know what kind
# of item they just granted to say something sensible about it. Does
# nothing and returns "" for a key item or an unknown id - key items are
# World.key_items's business (see the header comment above), not a
# single Diver's, so this refuses rather than guessing which diver
# "holds" a party-wide item.
#
# MODIFIED: took a Diver originally, same reason/same fix as would_help()
# above - now takes the CombatantStats directly so battle.gd (whose party
# entries carry .stats but not a real linked Diver) can call this too.
static func grant(item_id: String, s: CombatantStats) -> String:
	if not ITEMS.has(item_id):
		return ""
	var def: Dictionary = ITEMS[item_id]
	var display := String(def.display)
	match String(def.kind):
		"heal":
			var before := s.hp
			s.hp = mini(s.hp_max, s.hp + int(def.amount))
			var gained := s.hp - before
			return "Found a %s! +%d HP" % [display, gained] if gained > 0 else "Found a %s, but you're already at full health." % display
		"oxygen":
			var before_ox := s.oxygen
			s.oxygen = minf(s.oxygen_max, s.oxygen + float(def.amount))
			var gained_ox := s.oxygen - before_ox
			return "Found an %s! +%d O2" % [display, int(round(gained_ox))] if gained_ox > 0.0 else "Found an %s, but your tank's already full." % display
		"attack_up":
			s.strength += int(def.amount)
			return "%s! Strength up by %d for this fight." % [display, int(def.amount)]
		"defense_up":
			s.defense += int(def.amount)
			return "%s! Defense up by %d for this fight." % [display, int(def.amount)]
		"accuracy_up":
			s.accuracy += int(def.amount)
			return "%s! Accuracy up by %d for this fight." % [display, int(def.amount)]
		"evasion_up":
			# Also top up the live dodge pool so the boost helps this round.
			s.evasion += int(def.amount)
			s.evasion_current += int(def.amount)
			return "%s! Evasion up by %d for this fight." % [display, int(def.amount)]
		_:
			return ""
