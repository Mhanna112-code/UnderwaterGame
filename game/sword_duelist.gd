# Swordfish Duelist is Glassgoat's second ordinary-enemy-compatible rig.
# It extends Goblin deliberately: the base class is the public enemy contract
# for battle, guardian triggers, saving, balance, facing and death effects.
# Only asset identity and authored move data vary by model.
class_name SwordDuelist
extends Goblin

const DUELIST_SRC := preload("res://characters/Sword_Duelist.fbx")

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

# Swordfish Duelist's own fixed, real stats - same "no scaling, no per-
# fight variance" change Goblin.BASE_STATS made for Angler, just a
# different real enemy with a different real kit (high Agility/Evasion,
# built to actually dodge rather than tank). Named DUELIST_BASE_STATS, not
# BASE_STATS - GDScript refuses to reload a subclass that redeclares a
# const with the same name as one already on its parent (Goblin.BASE_STATS).
const DUELIST_BASE_STATS := {
	"hp": 8, "strength": 2, "defense": 1, "agility": 6,
	"evasion": 4, "accuracy": 3,
}

func make_stats(ref: CombatantStats, player_level: int = 1) -> CombatantStats:
	xp_reward = maxi(1, int(round(float(BASE_XP) * (1.0 + float(maxi(player_level - 1, 0)) * 0.12))))
	if legacy_scaling_requested():
		return _legacy_stats_from(ref)
	return _stats_from(DUELIST_BASE_STATS)
