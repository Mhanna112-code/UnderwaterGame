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
