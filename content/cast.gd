# Who the divers are, which file each one arrives in, and what their motions
# are called. One table, read by the dive site and by the fight both, so the
# two can never disagree about which model is which.
#
# The deliveries come one character per file and all three share a single
# 132-bone rig, so every file contains every character's ANIMATIONS and only
# one character's MESH. That is why each entry names a clip family: matching
# a clip on "idle" alone hands the scuba diver the brass suit's stance.
class_name Cast
extends RefCounted

const ALL := [
	{
		"id": "scuba", "family": "Scuba",
		"file": "res://art/characters/Scuba_Rigged.fbx",
		"mesh": "Staff_Diver",
		# the staff is skinned to the same rig and animates with her, so it
		# is part of the character rather than a prop to place nearby. Hiding
		# it was what left it floating on its own in the world.
		"carries": ["Staff_Lantern"],
		"abilities": {
			"Axe Kick": "Scuba_(Attack)Axe_Kick1",
			"Double Knee": "Scuba_(Attack)Double_Knee1",
		},
	},
	{
		"id": "proto1", "family": "Proto1",
		"file": "res://art/characters/Prototype1_Rigged.fbx",
		"mesh": "Prototype_1(1910)",
		"carries": [],
		"abilities": {
			"Palm Strike": "Proto1_(Attack)Palm_Strike",
			"Dual Palm": "Proto1_(Attack)DualPalm",
		},
	},
	{
		"id": "protov", "family": "Proto5",
		"file": "res://art/characters/PrototypeV_Rigged.fbx",
		"mesh": "Prototype_V(1922)",
		"carries": [],
		"abilities": {
			"Piston Swing": "Proto5_(Attack)Hammer",
			"Wide Sweep": "Proto5_(Attack)Spin",
		},
	},
]

# Motions every character has. Returned WITHOUT a rig prefix: each delivery
# names its armature node differently (rig, rig_001, rig_002), so the actor
# resolves the prefix against the file it actually loaded. Held states ship
# as Start / Mid (Loop) / End, and the loop is the one to play.
static func clip(family: String, motion: String) -> String:
	match motion:
		"idle":
			match family:
				"Scuba": return "Scuba_(Idle)1(Loop)"
				"Proto1": return "Proto1_(Idle1)"
				_: return "Proto5_(Idle)(Loop)"
		"swim":
			return "%s_(Swimming1)(Mid)(Loop)" % family
		"hurt":
			return "%s_(Damaged1)Weak_Hit" % family
		"hurt_bad":
			return "%s_(Damaged2)Heavy_Hit" % family
		"down":
			return "%s_(Faint)(Mid)(Loop)" % family
		"win":
			return "%s_(Win)(Mid)(Loop)" % family
	return ""

static func by_mesh(mesh: String) -> Dictionary:
	for c in ALL:
		if String(c.mesh) == mesh:
			return c
	return {}

static func by_index(i: int) -> Dictionary:
	return ALL[i % ALL.size()] as Dictionary
