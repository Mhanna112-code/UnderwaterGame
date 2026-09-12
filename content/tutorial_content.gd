# Text for the general tutorial book (see game/tutorial_book.gd) - kept as
# plain data, separate from the Control that renders it, the same split
# content/sites.gd draws between map data and game/site.gd's building of it.
#
# Every mechanic described here was read out of the actual code that runs
# it (combatant_stats.gd, combat_rules.gd, battle.gd's apply_damage_roll(),
# diver.gd's oxygen spend) rather than guessed at, specifically because a
# tutorial that describes the game wrong is worse than no tutorial - a
# player who trusts it and gets burned learns to stop trusting it.
class_name TutorialContent
extends RefCounted

const GENERAL_PAGES: Array[Dictionary] = [
	{
		"title": "Combat Basics",
		"body": "The queue at the top shows who acts next. On your turn, choose Attack for a move, Items for recovery, or Run to try to leave. Choose a target to see its HP, DEF, EVA and ACC before committing.",
	},
	{
		"title": "Dodging: Accuracy vs. Evasion",
		"body": "An attack lands when the attacker's Accuracy, plus the move's modifier, is higher than the target's current EVA. A dodge spends some EVA; it refills at the start of that combatant's next turn.",
	},
	{
		"title": "Damage: Attack vs. Defense",
		"body": "On a hit, move power plus your STR is reduced by the target's DEF. Some moves trade accuracy, evasion, oxygen, or one target for more power—read the short line under each move before choosing.",
	},
	{
		"title": "Every Other Stat",
		"body": "Red bars are HP. The blue value under a diver's HP is oxygen, used by some moves. A party loses when every diver reaches 0 HP; a fight ends when every enemy does.",
	},
	{
		"title": "Special Encounters",
		"body": "Use sonar (Q) to discover guarded sites. You choose one diver for a short ability challenge; a flawless clear avoids the guardian's follow-up. Losing a challenge does not consume the site.",
	},
	{
		"title": "Getting Around",
		"body": "Sonar (Q) reveals guarded sites and costs oxygen outside the opening tutorial. Save points restore the party and record progress. Key items unlock stronger spells in each diver's spell tree.",
	},
]

# Looks up a page by title for contextual UI without maintaining a second
# copy of its wording. Empty string on a typo is safer than crashing a fight.
static func page_body(title: String) -> String:
	for page in GENERAL_PAGES:
		if String(page.title) == title:
			return String(page.body)
	return ""

# One line per special-encounter ability, read on the "Choose who goes"
# carousel next to whichever diver is currently selected - kept here
# rather than duplicated in special_encounter_prompt.gd so the wording
# only has to be right in one place.
const ABILITY_BLURBS := {
	"swap": "In the encounter: portraits fly in from the enemy. Watch which one matches the reference sitting in each slot, then Left/Right and E to swap into a mismatched slot before it lands.",
	"grapple": "In the encounter: click to capture the mouse, aim at the glowing weak spot, and left-click to grapple it. Each incoming rock needs two weak-spot hits before impact.",
	"shockwave": "In the encounter: three lanes come in at once - one rock, two solid walls. Hold Left/Right to lean into that lane (let go to snap back to middle) and line up with the rock, then E to shockwave it before it lands. Standing in a wall's lane gets you hit.",
}

# Where a short demo clip/image for each ability lives, once one exists.
# The carousel (special_encounter_prompt.gd) checks ResourceLoader.exists()
# and falls back to a plain placeholder frame if the file isn't there yet -
# these paths can be filled in one ability at a time with no other code
# changes needed. .ogv plays as video (Godot's built-in VideoStreamPlayer
# format); anything else is loaded as a still image.
const ABILITY_MEDIA := {
	"swap": "res://media/tutorials/swap_demo.ogv",
	"grapple": "res://media/tutorials/grapple_demo.ogv",
	"shockwave": "res://media/tutorials/shockwave_demo.ogv",
}

# One entry per status condition a move can apply - shared by the Combat
# Help tab (game/inventory_menu.gd's Esc-menu pause screen) and battle.gd's
# tutorial captions, so the numbers only ever have to be right in one
# place. Blindness's numbers were read straight out of the code that
# applies them (combatant_stats.gd's effective_accuracy()/effective_
# agility()/effective_defense(), all three reading status_level("blindness")
# the same way) - Stun has no move that inflicts it yet, so its entry
# describes the intended design rather than something presently reachable
# in a fight.
const STATUS_CONDITIONS: Array[Dictionary] = [
	{
		"title": "Blindness",
		"body": "Five levels, 1 through 5. Each level lowers Agility, Accuracy, and Defense by that same number - Blindness 1 takes 1 off all three stats, Blindness 5 takes 5 off all three. Flash Blast is the current source of it, applying level 2 to every enemy for as many turns as the caster's own Accuracy.",
	},
	{
		"title": "Stun",
		"body": "A stunned combatant skips its turn. No current starting move applies Stun yet; this reference is here for enemies and future moves that do.",
	},
]
