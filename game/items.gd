# All non-spell item data and the one rule for what an item actually does
# when you get it, in the same static/no-state shape as spell_tree.gd -
# nothing here needs a .new() either.
#
# Two kinds of item live in ITEMS, told apart by "kind":
#   - Consumables ("heal"/"oxygen"/"spell_point"/"barrier") apply straight
#     to a Diver's stats the instant they're picked up - see grant(). These
#     are what ItemOrb hands out (see cracked_wall.gd's break handler in
#     world.gd - a shockwaved rock pops one, chosen from RANDOM_DROP_TABLE).
#   - Key items ("key") are the current_pearl/reef_plate spell_tree.gd
#     already knows how to gate a capstone spell behind (see its
#     requires_items) - they don't touch a Diver's stats at all, they go
#     into World.key_items instead. grant() refuses these on purpose (see
#     below); world.gd's item-guardian handler adds them to key_items
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
	"spell_shard": {
		"display": "Spell Shard", "kind": "spell_point", "amount": 1,
		"description": "Grants 1 spell point.",
	},
	"barrier_tonic": {
		"display": "Barrier Tonic", "kind": "barrier", "amount": 0,
		"description": "Refills your barrier completely.",
	},
	"current_pearl": {
		"display": "Current Pearl", "kind": "key",
		"description": "A key item. Unlocks Staff_Diver's Tidal Burst.",
	},
	"reef_plate": {
		"display": "Reef Plate", "kind": "key",
		"description": "A key item. Unlocks Prototype_V(1922)'s Bulwark Stance.",
	},
}

# What a shockwaved rock can pop out - potions weighted heaviest by literal
# repetition (same trick Goblin.jitter_pct's callers use elsewhere: no
# separate weight table, just how many times an id appears) so a break
# usually pays out something small and reliable, occasionally something
# better. Key items are deliberately absent - those only ever come from a
# guardian fight (see world.gd's _build_item_guardians()), never luck.
const RANDOM_DROP_TABLE := [
	"potion", "potion", "potion", "potion",
	"oxygen_cell", "oxygen_cell",
	"spell_shard",
	"barrier_tonic",
]

static func random_drop() -> String:
	return RANDOM_DROP_TABLE[randi_range(0, RANDOM_DROP_TABLE.size() - 1)]

static func is_key_item(item_id: String) -> bool:
	return String(ITEMS.get(item_id, {}).get("kind", "")) == "key"

# Whether using this item right now would actually change anything -
# checked before grant() ever runs (see world.gd's use_inventory_item(),
# inventory_menu.gd's Use buttons, and battle.gd's item-target filtering)
# so a potion at full HP gets refused outright instead of being silently
# consumed for nothing, which is what grant() alone used to let happen
# (it already messaged "already at full health," but still returned a
# real message either way, and its caller never distinguished the two to
# skip the actual deduction). spell_point has no cap (CombatantStats.
# spell_points has no _max field to check against) - it always helps,
# same as a key item request always fails since is_key_item() catches it
# separately.
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
		"barrier":
			return s.barrier < s.barrier_max
		"spell_point":
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
		"spell_point":
			s.spell_points += int(def.amount)
			return "Found a %s! +%d spell point" % [display, int(def.amount)]
		"barrier":
			s.barrier = s.barrier_max
			return "Found a %s! Barrier fully restored." % display
		_:
			return ""
