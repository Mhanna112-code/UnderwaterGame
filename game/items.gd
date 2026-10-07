# Static item data and grant rules. Consumables apply to a Diver's stats on pickup (grant());
# key items are party-wide (World.key_items) and grant() refuses them.
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
	# Battle-only boosts: grant() adds them normally; battle.gd reverts them when the fight ends.
	"attack_up": {
		"display": "Attack Tonic", "kind": "attack_up", "amount": 4,
		"description": "Raises Strength by 4 for the rest of this fight.",
		"battle_only": true,
	},
	"defense_up": {
		"display": "Defense Shell", "kind": "defense_up", "amount": 3,
		"description": "Raises Defense by 3 for the rest of this fight.",
		"battle_only": true,
	},
	# Lets Maxilani's sonar reveal invisible objects. Passive; shown greyed out in the menu.
	"sonar_vision": {
		"display": "Sonar Vision", "kind": "info",
		"description": "This item works automatically. Make sure Sonar is toggled on and in certain places you can see hidden items.",
	},
	"accuracy_up": {
		"display": "Focus Tonic", "kind": "accuracy_up", "amount": 2,
		"description": "Raises Accuracy by 2 for the user's next 5 turns. Only one Focus Tonic or Slipstream Oil can be used per battle.",
		"battle_only": true, "turns": 5, "one_per_battle": true,
	},
	"evasion_up": {
		"display": "Slipstream Oil", "kind": "evasion_up", "amount": 2,
		"description": "Raises Evasion by 2 for the user's next 5 turns. Only one Focus Tonic or Slipstream Oil can be used per battle.",
		"battle_only": true, "turns": 5, "one_per_battle": true,
	},
}

# Removed items still in old saves: dropped on Load; pending drops become EVEN_DROP_ORDER[0].
const RETIRED_ITEMS := ["spell_shard"]

# Each consumable a rock can hold, once; rocks take them in order (drop_for_rock()) to spread evenly.
# Key items come from fixed rocks and guardians instead.
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

# Whether using this item now would change anything; checked before grant() so useless uses are refused.
static func would_help(item_id: String, s: CombatantStats) -> bool:
	match String(ITEMS.get(item_id, {}).get("kind", "")):
		"heal":
			# Potions heal the living only; a downed diver needs a revive.
			return s.hp > 0 and s.hp < s.hp_max
		"oxygen":
			return s.oxygen < s.oxygen_max
		"attack_up", "defense_up", "accuracy_up", "evasion_up":
			return true
		_:
			return false

# Applies a consumable to `s` and returns a message for World._announce(); "" for key/unknown items.
static func grant(item_id: String, s: CombatantStats) -> String:
	if not ITEMS.has(item_id):
		return ""
	var def: Dictionary = ITEMS[item_id]
	var display := String(def.display)
	match String(def.kind):
		"heal":
			if s.hp <= 0:
				return ""  # never revives
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
			return "%s! Accuracy up by %d for %d turns." % [display, int(def.amount), int(def.get("turns", 5))]
		"evasion_up":
			# Also top up the live dodge pool so the boost helps this round.
			s.evasion += int(def.amount)
			s.evasion_current += int(def.amount)
			return "%s! Evasion up by %d for %d turns." % [display, int(def.amount), int(def.get("turns", 5))]
		_:
			return ""
