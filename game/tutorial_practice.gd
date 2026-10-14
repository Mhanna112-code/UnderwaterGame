# Optional practice borrows diver identity but not earned combat resources.
class_name TutorialPractice
extends RefCounted

var _divers: Array[Diver] = []
var _members: Array[Dictionary] = []
var _inventory: Dictionary

func begin(divers: Array, inventory: Dictionary) -> Dictionary:
	assert(_divers.is_empty(), "Practice must restore before starting again")
	_inventory = inventory
	for value in divers:
		var diver := value as Diver
		_divers.append(diver)
		_members.append(diver.campaign_member_state())
		var practice_stats := CombatantStats.new()
		# Include non-exported script fields (HP/O2/statuses), which Resource's
		# default duplicate does not preserve. Mutable arrays/maps are isolated.
		for property in diver.stats.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var field: Variant = diver.stats.get(String(property.name))
			if field is Dictionary or field is Array:
				field = field.duplicate(true)
			practice_stats.set(String(property.name), field)
		practice_stats.fill()
		diver.stats = practice_stats
	return inventory.duplicate(true)

func restore() -> Dictionary:
	for index in _divers.size():
		if is_instance_valid(_divers[index]):
			_divers[index].restore_campaign_member(_members[index])
	_divers.clear()
	_members.clear()
	return _inventory
