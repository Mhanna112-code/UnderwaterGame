# Dedicated manual-playtest entry point. It starts the same real Battle and
# ability-id dispatch used by the game, but forces Musashi's enemy turn first
# so a browser tester reaches Grapple Intercept immediately.
extends Node

func _ready() -> void:
	var diver := Diver.new()
	diver.model_name = "Prototype_1(1910)"
	add_child(diver)
	await get_tree().process_frame
	diver.stats.agility = -999

	var battle := Battle.new()
	battle.party_source = [diver]
	battle.special_encounter = true
	add_child(battle)
