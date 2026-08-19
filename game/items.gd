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

# Applies a consumable straight to the diver's stats and returns a message
# fit to hand to World._announce() as-is - callers shouldn't need to know
# what kind of item they just granted to say something sensible about it.
# Does nothing and returns "" for a key item or an unknown id - key items
# are World.key_items's business (see the header comment above), not a
# single Diver's, so this refuses rather than guessing which diver "holds"
# a party-wide item.
static func grant(item_id: String, diver: Diver) -> String:
	if not ITEMS.has(item_id):
		return ""
	var def: Dictionary = ITEMS[item_id]
	var display := String(def.display)
	match String(def.kind):
		"heal":
			var before := diver.stats.hp
			diver.stats.hp = mini(diver.stats.hp_max, diver.stats.hp + int(def.amount))
			var gained := diver.stats.hp - before
			return "Found a %s! +%d HP" % [display, gained] if gained > 0 else "Found a %s, but you're already at full health." % display
		"oxygen":
			var before_ox := diver.stats.oxygen
			diver.stats.oxygen = minf(diver.stats.oxygen_max, diver.stats.oxygen + float(def.amount))
			var gained_ox := diver.stats.oxygen - before_ox
			return "Found an %s! +%d O2" % [display, int(round(gained_ox))] if gained_ox > 0.0 else "Found an %s, but your tank's already full." % display
		"spell_point":
			diver.stats.spell_points += int(def.amount)
			return "Found a %s! +%d spell point" % [display, int(def.amount)]
		"barrier":
			diver.stats.barrier = diver.stats.barrier_max
			return "Found a %s! Barrier fully restored." % display
		_:
			return ""
