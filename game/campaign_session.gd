# Live campaign owner across scene destruction. Stats and inventory retain
# their identity; only scene-local Diver nodes and positions are recreated.
# This is not a JSON save format. Durable scene/checkpoint restore is separate.
class_name CampaignSession
extends RefCounted

var party: Array[Dictionary] = []
var active := 0
var inventory: Dictionary = {}
var campaign_key_items: Array[String] = []
var route_state: RouteState
var random_encounters_enabled := true
var selected_slot := -1
var outer_world_checkpoint: Dictionary = {}
var maze_snapshot: Dictionary = {}

static func vector_data(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func vector_from(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func capture_party(divers: Array, selected: int) -> void:
	party.clear()
	for diver in divers:
		party.append((diver as Diver).campaign_member_state())
	active = selected

func restore_party(divers: Array) -> void:
	assert(divers.size() == party.size(), "Campaign party identity must not change across scenes")
	for i in range(divers.size()):
		(divers[i] as Diver).restore_campaign_member(party[i])
