# Frilled Shark is Glassgoat's third ordinary-enemy-compatible rig. Extends
# Goblin for the same reason Swordfish Duelist does - the base class is the
# public enemy contract for battle, guardian triggers, saving, balance,
# facing and death effects. Only asset identity, authored move data and
# stats vary by model.
class_name FrilledShark
extends Goblin

const SHARK_SRC := preload("res://game/FrilledShark.fbx")

# Its own authored floor (5 HP, 2 Strength, 2 Defense, 1 Agility, 2 Evasion,
# 2 Accuracy) rather than inheriting Goblin.FLOOR_STATS (the Angler's block)
# or SwordDuelist.DUELIST_FLOOR_STATS - the same per-species floor_stats()
# override pattern both of those already use. Named distinctly from either,
# same reason DUELIST_FLOOR_STATS is: GDScript does not allow a subclass
# const to shadow one already declared on its parent.
const SHARK_FLOOR_STATS := {
	"hp": 5, "strength": 2, "defense": 2, "agility": 1,
	"evasion": 2, "accuracy": 2,
}

func floor_stats() -> Dictionary:
	return SHARK_FLOOR_STATS

# No Angler-specific low-HP/Bite-streak state machine authored for this rig -
# keep Battle's plain two-step flow (a target picked first, then choose_move()
# asked independently which move to swing), the same override Swordfish
# Duelist uses.
func choose_move_and_target(_self_stats: CombatantStats, _alive_party: Array, default_target: Dictionary, _forced: bool) -> Dictionary:
	return {"move": choose_move(default_target.stats as CombatantStats), "target": default_target}

func model_source() -> PackedScene:
	return SHARK_SRC

func enemy_catalogue() -> Array:
	return EnemyMoves.frilled_shark_catalogue()

func enemy_id() -> String:
	return "frilled_shark"

func display_name() -> String:
	return "Frilled Shark"

func primary_attack_clip() -> String:
	return "attack)bite"
