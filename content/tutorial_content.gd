# Copy for the in-game tutorial book.  Keeping the words in a small data
# script makes the runtime UI reusable and leaves the eventual narrative
# rewrite as a content-only change.
class_name TutorialContent
extends RefCounted

const GENERAL_PAGES: Array[Dictionary] = [
	{
		"title": "Welcome to the dive",
		"body": "Swim with WASD. Move the mouse to look around, TAB to switch divers, and press E to use the active diver's ability.",
	},
	{
		"title": "Your three abilities",
		"body": "Bucky's Shockwave breaks cracked barriers. Diver Boy's Grapple pulls to anchors. Marine Man's Swap trades places with an ally. The opening route lets you practice each one before the maze.",
	},
	{
		"title": "Finding your way",
		"body": "Follow the active objective marker through the opening route. Random encounters begin only after the route's final gate opens. Q toggles sonar for discoveries; P saves at a save point.",
	},
]

# Kept beside the general tutorial so the special-encounter picker and this
# opening walkthrough use the same ability vocabulary.  Video/image paths are
# intentionally empty until the art team supplies approved clips; the picker
# renders its explicit "coming soon" fallback in that case.
const ABILITY_BLURBS: Dictionary = {
	"swap": "In the encounter: portraits fly in from the enemy. Watch which one matches the reference sitting in each slot, then Left/Right and E to swap into a mismatched slot before it lands.",
	"grapple": "In the encounter: swim (WASD) into each telegraphed spot and press E to blast that rock back at the enemy before it fades.",
	"shockwave": "In the encounter: three lanes come in at once - one rock, two solid walls. Hold Left/Right to lean into that lane (let go to snap back to middle) and line up with the rock, then E to shockwave it before it lands. Standing in a wall's lane gets you hit.",
}

const ABILITY_MEDIA: Dictionary = {}
