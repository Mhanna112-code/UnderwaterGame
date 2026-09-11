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
		"body": "A fight is turns, one combatant at a time, fastest Agility going first each round. On your turn: Attack (use a base move, or any spell you've equipped), Items (use one on any living party member to heal or boost their stats), or Run (leave the fight - not guaranteed to work). The queue bar across the top shows the coming order; the log above your menu says what just happened.",
	},
	{
		"title": "Dodging: Accuracy vs. Evasion",
		"body": "A hit lands only if the attacker's (left stats panel's ACC number) is strictly greater than the defender's current Evasion (right stats panel's EVA number). In this case, the attacker and defender have equal evasion, so the attacker will miss. Evasion is a pool that a successful dodge spends down by however much Accuracy it just beat, and it only refills at the start of that combatant's own next turn. Get baited into dodging early in a turn round and you may have nothing left to dodge with later in the same turn.",
	},
	{
		"title": "Damage: Attack vs. Defense",
		"body": "Hits do move power + your Strength (STR in the left stats panel) minus the target's Defense (DEF in the right stats panel), straight off the target's HP. In this case, the attacker's strength equals the target's defense so the attack will only deal its base (1) power.",
	},
	{
		"title": "Every Other Stat",
		"body": "HP (health points) red bars end the fight when either all party members or all enemies reach 0 - your party's bars stack down the left side of the screen, the enemies' down the right. The blue bar underneath each health bar is oxygen which is consumed to cast certain attacks.",
	},
	{
		"title": "Special Encounters",
		"body": "Sonar (Q, Maxilani's passive) is the only way these are found - nothing is visible from a distance until sonar actually reveals it. Trigger one and you send in exactly one diver, alone, to survive a short timed challenge built around THEIR ability specifically (see the 'Choose who goes' screen for what each one plays like). Clear it flawlessly - nothing gets through at all - and the enemy's closing swing is guaranteed to miss instead of being a separate roll. Losing costs nothing permanent: a diver who falls here washes back out at the HP they went in with. Wins pay out either a key item or a temporary Attack/Defense boost that lasts the rest of whatever fight you use it in.",
	},
	{
		"title": "Getting Around",
		"body": "Dark water limits real sight to a short range, so the map leans on sonar and beacons rather than a HUD compass. Toggle sonar with Q; it costs oxygen the whole time it's on. Save points restore the whole party's HP and Oxygen and write your progress - use them before pushing into anything risky. Key items (won from special encounters) unlock each diver's strongest, capstone spell in their own spell tree.",
	},
]

# Pulls one GENERAL_PAGES entry's body by title, for battle.gd's
# choreographed first fight to fold into its own tutorial captions
# (_explain_turn_order() combines this with "Combat Basics",
# _explain_dodging() with "Dodging: Accuracy vs. Evasion") instead of
# maintaining a second copy of the same wording. Empty string on a title
# that doesn't exist rather than an error - a typo'd title should read as
# "page missing" during testing, not crash the fight.
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

# Read out in the choreographed first encounter (see battle.gd's
# tutorial_encounter) while that move's button is flashing and every other
# button is disabled - one at a time, forcing the player to actually use
# each of Maxilani's five starting SCUBA moves once before the fight ends.
# Every number/effect here matches content/combat_moves.gd's SCUBA array
# exactly, same "never describe a mechanic wrong" rule as GENERAL_PAGES above.
const FIRST_BATTLE_MOVE_NOTES := {
	"Electric Touch": "ATTACK move - 1x Strength damage, and it also strips the target's Evasion by your Accuracy. A good opener: everything you throw after this lands more easily.",
	"Scuba Stabbing": "ATTACK move - 1x Strength damage plus Bleed (1 + Strength) that keeps ticking after the hit. Use it when you want damage spread over several turns instead of one big number.",
	"Flash Blast": "UTILITY move - no damage at all. Hits every enemy with Blindness 2 (lowers Agility, Accuracy, AND Defense) for as many turns as your own Accuracy. For making a whole group easier to dodge, not for ending a fight.",
	"Multiple Knee Combo": "ATTACK move - 1x Strength damage to every enemy, but -1 Accuracy/Evasion on yourself until your next turn. Worth it against several weak targets; riskier against one hard hitter.",
	"Axe Kick": "ATTACK move - your hardest single hit (Strength + Accuracy damage), but it drops your own Evasion by 3 until your next turn, so you're an easier target right after. Use it when you can afford that trade.",
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
		"body": "A stunned combatant skips their turn entirely - the number attached to Stun is how many of their own upcoming turns get skipped, not a stat penalty the way Blindness's level is.",
	},
]
