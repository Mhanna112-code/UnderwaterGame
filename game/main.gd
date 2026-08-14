# The loop: swim, meet something, fight it, come back.
#
# One owner for which scene is up. The overworld does not know the battle
# exists and the battle does not know where it was fought; they each report
# upward and this decides. Two scenes that swap each other out directly is
# how you end up with two of one of them.
extends Node

const WORLD := preload("res://game/world.tscn")
const BATTLE := preload("res://game/battle.tscn")

var world: Node3D
var battle: Node3D
var beaten: Dictionary = {}      # enemy name -> true, so a win stays won

func _ready() -> void:
	_open_world()

func _open_world() -> void:
	world = WORLD.instantiate()
	# set state BEFORE the node enters the tree: add_child fires _ready, and
	# the world places its enemies there. Assigning afterwards meant every
	# beaten enemy came straight back, which the loop gate caught.
	world.beaten = beaten
	add_child(world)
	world.encountered.connect(_start_battle)

func _start_battle(enemy_name: String, encounter: String) -> void:
	if battle != null:
		return
	world.queue_free()
	world = null
	battle = BATTLE.instantiate()
	battle.encounter = encounter
	battle.set_meta("enemy_name", enemy_name)
	add_child(battle)
	battle.finished.connect(_end_battle)

func _end_battle(outcome: String) -> void:
	if battle == null:
		return
	if outcome == "victory":
		beaten[String(battle.get_meta("enemy_name", ""))] = true
	battle.queue_free()
	battle = null
	# defeat sends you back to the surface too. Losing a fight is a cost,
	# not a dead end: SALVAGE ruled that the dive fails and you keep going,
	# and nothing here has earned the right to overrule it.
	call_deferred("_open_world")
