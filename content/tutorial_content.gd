# Tutorial text as plain data, rendered by game/tutorial_book.gd.
# Every mechanic described here must match the code that implements it.
class_name TutorialContent
extends RefCounted

# Shared landscape slot for every tutorial clip surface.
const VIDEO_FRAME_SIZE := Vector2(320, 180)

const GENERAL_PAGES: Array[Dictionary] = [
	{
		"title": "Combat Basics",
		"body": "A fight is turns, one combatant at a time, fastest Agility going first each round. On your turn: Attack (use a base move, or any spell you've learned), Items (use one on any living party member to heal or boost their stats), or Run (leave the fight - not guaranteed to work). The queue bar across the top shows the coming order.",
	},
	{
		"title": "Dodging: Accuracy vs. Evasion",
		"body": "A hit lands only if the attacker's (left stats panel's ACC number) is strictly greater than the defender's current Evasion (right stats panel's EVA number). In this case, the attacker has equal accuracy to the defender's evasion, so the attack will miss. Evasion is a pool that a successful dodge spends down by however much Accuracy it just beat, and it only refills at the start of that combatant's own next turn. Get baited into dodging early in a turn and you may have nothing left to dodge with later in the same turn.",
	},
	{
		"title": "Every Other Stat",
		"body": "HP (health points) red bars end the fight when either all party members or all enemies reach 0. The blue bar underneath each health bar is oxygen which is consumed to cast certain attacks.",
	},
	{
		"title": "Special Encounters",
		"body": "Sonar (Q, Maxilani's passive) reveals nearby guarded sites as red dots. Swim into a site to trigger its fight or special challenge, even with Sonar and random encounters off. A special challenge sends in exactly one diver to use their ability. Clear it flawlessly and the enemy's closing swing misses. Losing restores the diver's entry HP. Wins grant the site's item.",
	},
	{
		"title": "Getting Around",
		"body": "Dark water limits real sight to a short range, so the map leans on sonar and beacons rather than a HUD compass. Toggle sonar with Q; it costs oxygen the whole time it's on. Save points restore the whole party's HP and Oxygen and write your progress - use them before pushing into anything risky. Key items (won from special encounters) unlock each diver's strongest, capstone spell in their own spell tree.",
	},
]

const SAVING_IMAGE := "res://media/tutorials/saving_save_point.png"

# "Saving" lesson: shown at the first save point, replayable from Combat Help.
static func saving_page() -> Dictionary:
	return {
		"title": "Saving",
		"body": "The game autosaves your progress every few minutes while you explore (not during battles, menus or cutscenes), and again right before the final boss. Load Game lets you continue from the latest save.

Save Points let you save manually: stand on one and press P to write your progress to one of three save slots. Save Points also revive downed divers and fully refill the party's HP and O2.",
		"slot": null,
		"media_control": Callable(TutorialContent, "_saving_image"),
	}

static func _saving_image() -> Control:
	var picture := TextureRect.new()
	picture.texture = load(SAVING_IMAGE) as Texture2D
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return picture

static func page_body(title: String) -> String:
	for page in GENERAL_PAGES:
		if String(page.title) == title:
			return String(page.body)
	return ""

# One entry per combat stat: Combat Help's Stats section and damaging-move tooltips.
const STAT_GLOSSARY: Array[Dictionary] = [
	{
		"title": "HP",
		"body": "Health. A fight ends the instant either every party member or every enemy reaches 0.",
	},
	{
		"title": "Strength (STR)",
		"body": "Added to a move's base power for its raw damage number, before the target's Defense reduces it.",
	},
	{
		"title": "Defense (DEF)",
		"body": "Subtracted from an incoming hit's raw damage (base power plus the attacker's Strength) before it reaches HP.",
	},
	{
		"title": "Agility (AGI)",
		"body": "Decides turn order - whoever has the highest goes first each round, and the order updates immediately if a move changes it mid-round.",
	},
	{
		"title": "Accuracy (ACC)",
		"body": "A hit lands only if it's strictly greater than the defender's current Evasion.",
	},
	{
		"title": "Evasion (EVA)",
		"body": "A pool spent down by a successful dodge, by however much Accuracy it just beat. It only refills at the start of that combatant's own next turn.",
	},
]

# Lookup used by battle.gd's _move_tooltip_text().
static func stat_glossary_body(title: String) -> String:
	for entry in STAT_GLOSSARY:
		if String(entry.get("title", "")) == title:
			return String(entry.get("body", ""))
	return ""

# Exploration abilities/passives, shown in CharacterAbilityPopup after the tutorial fight.
const WORLD_ABILITY_BLURBS := {
	"swap": "Instantly trades places with another party member - press F, cycle who with Left/Right, confirm with Enter. Escape cancels. Uses no Oxygen. Useful for getting a diver across a gap or hazard once someone else already made it to the other side.",
	"grapple": "Press F to grapple golden targets. In aim mode, left-click fires and right-click or Escape cancels. Anchors pull Musashi toward them; floating light items reel toward him instead. Uses no Oxygen. Firing at open water or a wall does nothing and can be retried immediately.",
	"shockwave": "Press F to fire instantly in every direction at once - no aiming needed. Breaks nearby obstacles built to be shockwaved open. Costs 12 Oxygen and has a short cooldown.",
	"sonar": "Press Q as Maxilani to show nearby hidden sites as red dots. Costs 3 Oxygen every 3 seconds while on. Red dots are visible only while Sonar is on. Swim into a site to trigger it even with Sonar off; R only switches random fights off, not guarded-site challenges.",
}

# Shown on the special-encounter "Choose who goes" screen (a bbcode
# RichTextLabel there), with keys drawn as tiles via Slot._badge().
static var ABILITY_BLURBS := {
	"swap": "Portraits fly in from the enemy. Watch which one matches the reference sitting in each slot, then %s/%s and %s to swap into a mismatched slot before it lands." % [Slot._badge("Left"), Slot._badge("Right"), Slot._badge("E")],
	"grapple": "Three waves of yellow and green spheres swirl in from the enemy. Each wave names one color as safe: move the mouse to aim the crosshair and %s to grapple every sphere of that color before the wave reaches you. A wave you don't clear hits you." % Slot._badge("Left click"),
	"shockwave": "Three lanes come in at once: one rock, two solid walls. Hold %s/%s to lean into that lane (let go to snap back to middle) and line up with the rock, then %s to shockwave it before it lands - you only get one shockwave per wave, so time it carefully. Standing in a wall's lane gets you hit." % [Slot._badge("Left"), Slot._badge("Right"), Slot._badge("E")],
}

# Shown during the scripted first fight while that move's button flashes.
# Must match content/combat_moves.gd's SCUBA array.
const FIRST_BATTLE_MOVE_NOTES := {
	"Electric Touch": "ATTACK move - 1x Strength damage, and it also lowers the target's Evasion by 1 for the rest of the fight. A good opener: everything you throw after this lands more easily.",
	"Scuba Stabbing": "ATTACK move - 1x Strength damage plus Bleed (1 + Strength) that keeps ticking after the hit. Use it when you want damage spread over several turns instead of one big number.",
	"Flash Blast": "UTILITY move - no damage at all. Hits every enemy with Blindness 2 (lowers Agility, Accuracy, AND Defense) for as many turns as your own Accuracy. For making a whole group easier to dodge, not for ending a fight.",
	"Multiple Knee Combo": "ATTACK move - 1x Strength damage to every enemy, but -1 Accuracy/Evasion on yourself until your next turn. Worth it against several weak targets; riskier against one hard hitter.",
	"Axe Kick": "ATTACK move - your hardest single hit (Strength + Accuracy damage), but it drops your own Evasion by 3 until your next turn, so you're an easier target right after. Use it when you can afford that trade.",
}

# Character-ability demo media; missing files fall back to a placeholder. .ogv plays as video.
const ABILITY_MEDIA := {
	"world": "res://media/tutorials/character_ability_popups/WorldMap.ogv",
	"swap": "res://media/tutorials/character_ability_popups/swap_demo.ogv",
	"sonar": "res://media/tutorials/character_ability_popups/sonar_demo.ogv",
	"grapple": "res://media/tutorials/character_ability_popups/grapple_demo.ogv",
	"shockwave": "res://media/tutorials/character_ability_popups/shockwave_demo.ogv",
}

# Special-encounter chooser and in-fight demo media (kept separate from ABILITY_MEDIA).
const SPECIAL_ENCOUNTER_MEDIA := {
	"swap": "res://media/tutorials/special_encounters/swap_demo.ogv",
	"grapple": "res://media/tutorials/special_encounters/grapple_demo.ogv",
	"shockwave": "res://media/tutorials/special_encounters/shockwave_demo.ogv",
}

# The Swap recording is padded inside a 1920x1080 canvas; sample its useful 384x216 region.
const SPECIAL_ENCOUNTER_VIDEO_CROPS := {
	"swap": Vector4(732.0 / 1920.0, 384.0 / 1080.0, 384.0 / 1920.0, 216.0 / 1080.0),
}

# One entry per status condition: Combat Help, status tooltips and tutorial captions.
const STATUS_CONDITIONS: Array[Dictionary] = [
	{
		"title": "Blindness",
		"body": "Flash Blast subtracts 2 from an enemy's Agility, Accuracy, and Defense, lasting as many turns as the caster's own Accuracy. Unlike Bleed, it does not stack: recasting it while already active does not add to the penalty, only refreshes the remaining turns if the new cast would last longer.",
	},
	{
		"title": "Stun",
		"body": "Skips the combatant's turn entirely. Its number is how many turns get skipped, not a stat penalty. Bleed and Poison still deal their damage on a stunned turn. The Angler's Headbutt stuns for 2 turns.",
	},
	{
		"title": "Evasion Down",
		"body": "Temporarily subtracts its level from Evasion. Flash Blast sets both its level and duration from the caster's Accuracy.",
	},
	{
		"title": "Defense Down",
		"body": "Temporarily subtracts its level from Defense, then wears off after 3 turns. The Swordfish's Spinning Slayer and the Frilled Shark's Tail Spin set its level from the attacker's own Defense. Hitting again refreshes it rather than stacking.",
	},
	{
		"title": "Bleed",
		"body": "Deals its stacked amount as damage when the bleeding character's turn ends, every turn for the rest of the fight. Another Bleed move adds its full amount again, but it can only stack up 3 times per fight.",
	},
	{
		"title": "Poison",
		"body": "Poison applies a percentage of max health as damage for 3 turns, dealt at the end of each of the poisoned character's turns. Being poisoned again resets it to 3 turns rather than stacking the damage.",
	},
]

# Lookup by lowercase status key; returns "" when there is no entry.
static func status_condition_body(status_name: String) -> String:
	var normalized := status_name.replace("_", " ").to_lower()
	for entry in STATUS_CONDITIONS:
		if String(entry.get("title", "")).to_lower() == normalized:
			return String(entry.get("body", ""))
	return ""

# Explanations for move effect kinds that aren't CombatantStats statuses, keyed by "kind".
const EFFECT_KIND_EXPLANATIONS: Dictionary = {
	"reduce_evasion": {
		"title": "Evasion Reduction",
		"body": "Permanently lowers the target's Evasion for the rest of the fight, unlike a status effect - it does not wear off on its own.",
	},
	"self_temporary": {
		"title": "Self Cost",
		"body": "A cost the caster pays on themselves, not the target. It wears off automatically at the caster's own next turn.",
	},
}

static func effect_kind_explanation(kind: String) -> Dictionary:
	return EFFECT_KIND_EXPLANATIONS.get(kind, {}) as Dictionary
