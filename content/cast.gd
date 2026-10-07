# Which rigged file each diver uses and what its clips are called.
# Every file shares one rig and holds all characters' clips, so clips are matched by family.
# Clip names were read from the imported files; verify/clips.gd fails the build if one stops resolving.
class_name Cast
extends RefCounted

# Keyed by model_name, the diver identifier used across the game.
const ALL := {
	"Staff_Diver": {
		"family": "Scuba",
		"file": "res://art/characters/Scuba_Rigged.fbx",
		"spell_animations": "res://art/characters/spell_animations/maxilani.res",
		# The staff is skinned to the same rig; hiding it left it floating beside her.
		"carries": ["Staff_Lantern"],
	},
	"Prototype_1(1910)": {
		"family": "Proto1",
		"file": "res://art/characters/Prototype1_Rigged.fbx",
		"spell_animations": "res://art/characters/spell_animations/musashi.res",
		"carries": [],
	},
	"Prototype_V(1922)": {
		"family": "Proto5",
		"file": "res://art/characters/PrototypeV_Rigged.fbx",
		"spell_animations": "res://art/characters/spell_animations/bucky.res",
		"carries": [],
	},
}

# Player-facing names, kept beside the rig identity so all scenes share them.
const DISPLAY_NAMES := {
	"Staff_Diver": "Maxilani",
	"Prototype_1(1910)": "Musashi",
	"Prototype_V(1922)": "Bucky",
}

# Motion names per family, without the rig prefix (Diver.resolve() matches after the "|").
# Held motions ship as Start / Mid (Loop) / End; all three are played.
# Irregular names are intentional: Proto5 has no (Win) clips and uses Strong_Hit; Scuba's win loop is (Mid2)(Loop).
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

# Move name -> swing clip; unmapped moves use FALLBACK_ATTACK.
const ABILITY_CLIPS := {
	# Staff_Diver / Scuba
	"Electric Touch": "Scuba_(Attack)Eletric1",
	"Scuba Stabbing": "Scuba_(Attack)Stab1",
	"Flash Blast": "Scuba_(Attack)Flash1",
	"Multiple Knee Combo": "Scuba_(Attack)Double_Knee1",
	"Axe Kick": "Scuba_(Attack)Axe_Kick1",
	# The delivered Swift Slash is the spell tree's Swift Strike.
	"Swift Strike": "Scuba_(Attack) Swift Slash",
	"Riptide Slash": "Scuba_(Attack) Riptide Slash",
	# Prototype_1(1910)
	"Precise Tap": "Proto1_(Attack)Palm_Strike",
	"Weaken": "Proto1_(Attack)DualPalm",
	"Slow": "Proto1_(Attack)Axe_Kick",
	"Blinding Silt": "Proto1_(Attack)Blinding)Silt",
	"Exploit Opening": "Proto1_(Attack)Blinding)Exploit_Opening",
	"Precise Jab": "Proto1_(Attack)Precise_Jab",
	# Prototype_V(1922)
	"Guard Bash": "Proto5_(Attack)BodyPress",
	"Heavy Kick": "Proto5_(Attack)Slam",
	"Crushing Haymaker": "Proto5_(Attack)Hammer",
	"Guard Break": "Proto5_Guard_Break",
	"Heavy Slam": "Proto5_Heavy_Slam",
	"Mending Current": "Proto5_Mending Current",
	"Tidal Revival": "Proto5_Tidal_Revival",
}

const FALLBACK_ATTACK := {
	"Scuba": "Scuba_(Attack)Stab1",
	"Proto1": "Proto1_(Attack)Palm_Strike",
	"Proto5": "Proto5_(Attack)Hammer",
}

static func knows(model_name: String) -> bool:
	return ALL.has(model_name)

# Falls back to a visible model, but warns loudly; verify/clips.gd catches this at build time.
static func entry(model_name: String) -> Dictionary:
	if not ALL.has(model_name):
		push_error("Cast has no entry for '%s', falling back to Staff_Diver" % model_name)
		return ALL["Staff_Diver"] as Dictionary
	return ALL[model_name] as Dictionary

static func family(model_name: String) -> String:
	return String(entry(model_name).family)

static func file(model_name: String) -> String:
	return String(entry(model_name).file)

static func spell_animations(model_name: String) -> AnimationLibrary:
	return load(String(entry(model_name).spell_animations)) as AnimationLibrary

static func carries(model_name: String) -> Array:
	return entry(model_name).carries as Array

static func display_name(model_name: String) -> String:
	return String(DISPLAY_NAMES.get(model_name, model_name))

static func motion(model_name: String, name: String) -> String:
	var m: Dictionary = MOTIONS.get(family(model_name), {}) as Dictionary
	return String(m.get(name, ""))

# Falls back to the family's default swing so unmapped moves still animate.
static func ability(model_name: String, move_name: String) -> String:
	var fam := family(model_name)
	var want := String(ABILITY_CLIPS.get(move_name, ""))
	# Only accept a clip from this diver's own family.
	if want != "" and want.begins_with(fam + "_"):
		return want
	return String(FALLBACK_ATTACK.get(fam, ""))

static func model_names() -> Array:
	return ALL.keys()
