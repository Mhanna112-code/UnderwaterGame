# Which rigged file each diver arrives in, and what that character's motions
# are actually called inside it.
#
# Glass_Goat's deliveries come one character per file, and all three share a
# single 132 bone rig, so every file contains EVERY character's animations and
# only ONE character's mesh. That is the whole reason this table exists: match
# a clip on "idle" alone and the scuba diver gets handed the brass suit's
# stance. Every entry names a clip family, and the family picks the clip.
#
# Nothing here is guessed. Every clip name below was read out of the imported
# files, and verify/clips.gd fails the build if any of them stops resolving.
class_name Cast
extends RefCounted

# Keyed by model_name, which is the identifier the rest of the game already
# uses for a diver (diver.gd's model_name, battle.gd's BASE_MOVES, spell_tree's
# per-character branches). One name, one meaning, everywhere.
const ALL := {
	"Staff_Diver": {
		"family": "Scuba",
		"file": "res://art/characters/Scuba_Rigged.fbx",
		# The staff is skinned to the same rig and swims with her, so it is
		# part of the character and not a prop parked nearby. Hiding it is
		# what left it floating on its own beside her (#26).
		"carries": ["Staff_Lantern"],
	},
	"Prototype_1(1910)": {
		"family": "Proto1",
		"file": "res://art/characters/Prototype1_Rigged.fbx",
		"carries": [],
	},
	"Prototype_V(1922)": {
		"family": "Proto5",
		"file": "res://art/characters/PrototypeV_Rigged.fbx",
		"carries": [],
	},
}

# Player-facing identity lives beside the rig identity so exploration and
# combat cannot drift into separate nickname tables. Glassgoat confirmed
# Maxilani and Musashi in the meeting. The Proto5 pilot's proper name was not
# decided, so `Mech Pilot` is deliberately a role label rather than invented
# canon; changing it later is one data edit with no save/model migration.
const DISPLAY_NAMES := {
	"Staff_Diver": "Maxilani",
	"Prototype_1(1910)": "Musashi",
	"Prototype_V(1922)": "Mech Pilot",
}

# Motion names the game asks for, resolved per family.
#
# Returned WITHOUT the rig prefix. Each delivery names its armature node
# differently (rig, rig_001, rig_002), so a clip is "rig_002|Scuba_(Idle)1(Loop)"
# in one file and "rig|Scuba_(Idle)1(Loop)" in another. Diver.resolve() matches
# on the part after the bar, so this table never has to care which file it is.
#
# Held motions ship as Start / Mid (Loop) / End, and all three get used. The
# loop is what holds the state; the Start and End are the way in and out of it.
# Playing only the loop is what Glass_Goat spotted on the first build: the
# diver went from standing to swimming and back with nothing in between, and
# he had animated those transitions specifically.
#
# Playing only the Start is the opposite mistake, and it is what "the animation
# does not work" looked like before that: it runs once and drops the character
# back to a rest pose.
#
# The irregular entries are not typos. Proto5 has no (Win) clips at all, so it
# celebrates with the thumbs up it does have, and its heavy hit reaction is
# called Strong_Hit where the other two say Heavy_Hit. Scuba's win loop is
# (Mid2)(Loop), not (Mid)(Loop). Those three were wrong in the first draft of
# this table and only surfaced once verify/clips.gd asked the files directly.
const MOTIONS := {
	"Scuba": {
		"idle": "Scuba_(Idle)1(Loop)",
		"swim": "Scuba_(Swimming1)(Mid)(Loop)",
		"swim_start": "Scuba_(Swimming1)(Start)",
		"swim_end": "Scuba_(Swimming1)(End)",
		"hurt": "Scuba_(Damaged1)Weak_Hit",
		"hurt_bad": "Scuba_(Damaged2)Heavy_Hit",
		"down": "Scuba_(Faint)(Mid)(Loop)",
		"down_start": "Scuba_(Faint)(Start)",
		"win": "Scuba_(Win)(Mid2)(Loop)",
	},
	"Proto1": {
		"idle": "Proto1_(Idle1)",
		"swim": "Proto1_(Swimming1)(Mid)(Loop)",
		"swim_start": "Proto1_(Swimming1)(Start)",
		"swim_end": "Proto1_(Swimming1)(End)",
		"hurt": "Proto1_(Damaged1)Weak_Hit",
		"hurt_bad": "Proto1_(Damaged2)Heavy_Hit",
		"down": "Proto1_(Faint)(Mid)(Loop)",
		"down_start": "Proto1_(Faint)(Start)",
		"win": "Proto1_(Win)(Mid)(Loop)",
	},
	"Proto5": {
		"idle": "Proto5_(Idle)(Loop)",
		"swim": "Proto5_(Swimming1)(Mid)(Loop)",
		"swim_start": "Proto5_(Swimming1)(Start)",
		"swim_end": "Proto5_(Swimming1)(End)",
		"hurt": "Proto5_(Damaged1)Weak_Hit",
		"hurt_bad": "Proto5_(Damaged2)Strong_Hit",
		"down": "Proto5_(Faint)(Mid)(Loop)",
		"down_start": "Proto5_(Faint)(Start)",
		"win": "Proto5_(Thumbs_P)(Mid)(Loop)",
	},
}

# Which swing belongs to which move, by the move's own name in battle.gd's
# BASE_MOVES and in spell_tree.gd. A move with no entry here is not a bug and
# does not need one: FALLBACK_ATTACK gives every family a swing that always
# plays, so a spell added tomorrow animates on the day it is added instead of
# standing still until somebody remembers this file.
const ABILITY_CLIPS := {
	# Staff_Diver / Scuba: Group_StatsV2's authored kit.
	"Electric Touch": "Scuba_(Attack)Eletric1",
	"Scuba Stabbing": "Scuba_(Attack)Stab1",
	"Flash Blast": "Scuba_(Attack)Flash1",
	"Multiple Knee Combo": "Scuba_(Attack)Double_Knee1",
	"Axe Kick": "Scuba_(Attack)Axe_Kick1",
	# Prototype_1(1910)
	"Precise Tap": "Proto1_(Attack)Palm_Strike",
	"Weaken": "Proto1_(Attack)DualPalm",
	"Slow": "Proto1_(Attack)Axe_Kick",
	# Prototype_V(1922)
	"Guard Bash": "Proto5_(Attack)BodyPress",
	"Heavy Kick": "Proto5_(Attack)Slam",
	"Crushing Haymaker": "Proto5_(Attack)Hammer",
}

const FALLBACK_ATTACK := {
	"Scuba": "Scuba_(Attack)Stab1",
	"Proto1": "Proto1_(Attack)Palm_Strike",
	"Proto5": "Proto5_(Attack)Hammer",
}

static func knows(model_name: String) -> bool:
	return ALL.has(model_name)

# Falls back rather than returning nothing, because every caller here is on
# a path that has to produce a diver, and a diver wearing the wrong model is
# at least visible. It says so loudly, though: a silent fallback would show
# the scuba diver in place of a character somebody just added and look like
# an art bug rather than a missing table entry. verify/clips.gd fails the
# build before this can happen at runtime.
static func entry(model_name: String) -> Dictionary:
	if not ALL.has(model_name):
		push_error("Cast has no entry for '%s', falling back to Staff_Diver" % model_name)
		return ALL["Staff_Diver"] as Dictionary
	return ALL[model_name] as Dictionary

static func family(model_name: String) -> String:
	return String(entry(model_name).family)

static func file(model_name: String) -> String:
	return String(entry(model_name).file)

static func carries(model_name: String) -> Array:
	return entry(model_name).carries as Array

static func display_name(model_name: String) -> String:
	return String(DISPLAY_NAMES.get(model_name, model_name))

static func motion(model_name: String, name: String) -> String:
	var m: Dictionary = MOTIONS.get(family(model_name), {}) as Dictionary
	return String(m.get(name, ""))

# The clip for a named move. Falls back to the family's default swing so an
# unmapped move still animates rather than freezing mid turn.
static func ability(model_name: String, move_name: String) -> String:
	var fam := family(model_name)
	var want := String(ABILITY_CLIPS.get(move_name, ""))
	# A move name maps to one family's clip. If a Staff_Diver spell somehow
	# names a Proto5 swing, the family's own fallback is still correct.
	if want != "" and want.begins_with(fam + "_"):
		return want
	return String(FALLBACK_ATTACK.get(fam, ""))

static func model_names() -> Array:
	return ALL.keys()
