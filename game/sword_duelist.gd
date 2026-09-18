# Swordfish Duelist is Glassgoat's second ordinary-enemy-compatible rig.
# It extends Goblin deliberately: the base class is the public enemy contract
# for battle, guardian triggers, saving, balance, facing and death effects.
# Only asset identity and authored move data vary by model.
class_name SwordDuelist
extends Goblin

const DUELIST_SRC := preload("res://characters/Sword_Duelist.fbx")

# Goblin.FLOOR_STATS became Glassgoat's authored Angler Fish block; Swordfish
# keeps the previous shared floor unchanged rather than inheriting the Angler's
# specific numbers, since nobody has authored a Swordfish-specific stat block.
# Named distinctly from the parent's FLOOR_STATS - GDScript does not allow a
# subclass const to shadow one already declared on its parent.
const DUELIST_FLOOR_STATS := {
	"hp": 15, "strength": 3, "defense": 1, "agility": 3,
	"evasion": 2, "accuracy": 3,
}

func floor_stats() -> Dictionary:
	return DUELIST_FLOOR_STATS

# Goblin's low-HP Headbutt-priority / Bite-streak-into-Flash-Blast state
# machine is authored specifically for the Angler; Swordfish keeps Battle's
# older two-step flow (a target picked first, then choose_move() asked
# independently which move to swing) exactly as it always has.
func choose_move_and_target(_self_stats: CombatantStats, _alive_party: Array, default_target: Dictionary, _forced: bool) -> Dictionary:
	return {"move": choose_move(default_target.stats as CombatantStats), "target": default_target}

func model_source() -> PackedScene:
	return DUELIST_SRC

func enemy_catalogue() -> Array:
	return EnemyMoves.swordfish_duelist_catalogue()

func enemy_id() -> String:
	return "swordfish_duelist"

func display_name() -> String:
	return "Swordfish Duelist"

func primary_attack_clip() -> String:
	return "attack)greatslash"
