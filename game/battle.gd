# The turn-based screen a random encounter drops you into: a small 3D stage
# showing all three divers and however many grunts stopped you, with a menu
# underneath. world.gd freezes the dive and hands over the mouse while this
# is up, then un-freezes once `finished` fires.
#
# Combatants live as plain Dictionaries (not a class) in two arrays -
# `party` and `enemies` - each entry shaped
# {kind, stats, model_name, display_name, equipped_spells, actor, hp_bar,
# hp_label}. A Dictionary rather than a real class because
# nothing here needs identity beyond "the fields", and it's the same
# lightweight shape BASE_MOVES entries already use in this file.
#
# Turn order is a live queue (`_queue`), not a fixed two-actor ping-pong:
# every living combatant is sorted by current agility at the start of each
# round, one entry is popped off and acts, and a landed agility-changing
# debuff re-sorts whatever's still waiting immediately - see
# _rebuild_queue()/_resort_pending()/_advance_turn().
class_name Battle
extends CanvasLayer

const BOSS_LAB_SCENE := preload("res://art/deep_zone/Broken_Office.fbx")
const PrologueOctopusScript := preload("res://game/prologue_octopus.gd")

signal finished(result: String)     # "won", "fled", or "lost"
signal prologue_angler_defeated
signal prologue_phase_changed(phase: String)
# Emitted after a party actor has stepped into range, faced the selected
# target, and started its authored attack clip. Gameplay does not consume this;
# the end-to-end fight gate uses the real selected target instead of guessing
# from proximity when several enemies share the stage.
signal player_swing_staged(attacker: Node3D, target: Node3D)

# Set by world.gd before add_child - the real Diver nodes from the dive
# site (world.divers), so .stats (shared by reference - a Resource, not
# copied) carries level-ups back out, and .equipped_spells says what each
# one can actually cast here. Nothing about these nodes is touched beyond
# reading those three fields - they stay right where they are in the dive
# site the whole fight, frozen like everything else while battling.
var party_source: Array = []

# Set by world.gd alongside party_source - the only reason battle.gd needs
# this is to reach World.inventory for the Items menu below (see
# _show_items()/_populate_item_menu()). Nothing else in this file touches
# world at all.
var world: World
var reward_item_on_win := ""
var encounter_intro_override := ""

# Set by World for the dedicated Glassgoat validation route. Ordinary
# random and guardian encounters still build Goblin grunts; this builds one
# TethysBoss with its authored animation and move cycle.
var boss_encounter := false
# Key-item guardian battles are solo ability challenges. World sets this
# independently of boss_encounter so the Tethys route remains unchanged.
var special_encounter := false
var _special_round := 0
# Artifact sites visibly place one guardian beside one item. Keep that
# encounter one-on-one with the party instead of secretly replacing the one
# approached actor with a random three-grunt pack.
var guardian_encounter := false
# The map sends the visible guardian's identity along with its reward. Ordinary
# packs roll their own Angler/Swordfish roster independently; this only pins
# the one visible artifact defender, so exploration never randomizes a reward.
var guardian_enemy_id := "angler"
# Public provenance for review logs and route verification. Ordinary encounters
# keep `random`; authored blockers and bosses are assigned by World before this
# node enters the tree.
var encounter_source := "random"

# Dedicated first-run configuration. This is not the long combat tutorial and
# never mutates Angler's shared species tuning: it filters this one Battle's
# visible choices to real attacks, builds one intentionally fragile opponent,
# and pauses at defeat so World can reveal Cordys in the same sequence.
var prologue_angler_encounter := false
var _prologue_angler_interrupted := false
var prologue_octopus_encounter := false
var _prologue_response_resolved := false

# The choreographed first fight (see World's light-beam intro sequence,
# _start_first_encounter()). All three divers (always starting with Maxilani -
# she's diver index 0 and TAB is disabled until she reaches the beam, see
# World._intro_active) against one goblin, weakened across the board (HP
# padded up, strength/accuracy cut down, heavy swings disabled entirely -
# see _build_stage()/_do_enemy_turn()) so it can't accidentally kill anyone
# before the lesson is even over. Walks the player through one scripted
# move each from Maxilani, Musashi, then Mech Pilot in turn (flashing
# button, everything else disabled - see _apply_tutorial_move_gate()), and
# spends the goblin's own one scripted turn guaranteeing a Quick Time Event
# actually shows up at least once (see _tutorial_prep_enemy_turn()) rather
# than leaving that entirely to ENEMY_QTE_CHANCE. Real _resolve_attack()
# math throughout; the fight is handed over for real once the script is
# done (_advance_turn()'s "Defeat the enemy!" prompt) - a genuine win or
# loss, not a guaranteed outcome.
var tutorial_encounter := false
# Ordered stage script for the choreographed first fight - each entry names
# which `party` index acts next and which of their own base moves
# _apply_tutorial_move_gate() forces, so a stage is a (diver, move) pair,
# not just a diver. NOT a 1:1 stage-index==party-index mapping: stages 3
# and 4 revisit Musashi (Weaken) and Maxilani (Flash Blast) for a second
# lesson each off their own kits, after Mech Pilot's stage 2 turn - see
# _tutorial_party_index_for_step().
const _TUTORIAL_SCRIPT: Array[Dictionary] = [
	{"party_index": 0, "move": "Electric Touch"},   # Maxilani
	{"party_index": 1, "move": "Precise Tap"},       # Musashi
	{"party_index": 2, "move": "Crushing Haymaker"}, # Mech Pilot
	{"party_index": 1, "move": "Weaken"},            # Musashi again
	{"party_index": 0, "move": "Flash Blast"},       # Maxilani again
]
# Index into _TUTORIAL_SCRIPT of whichever scripted stage is next. Only
# advances (see _resolve_party_move()/_resolve_party_move_all()) when
# whoever just acted is actually _TUTORIAL_SCRIPT[_tutorial_step]'s own
# diver (see _is_tutorial_scripted_turn()), so the enemy going first, or a
# diver whose stage already passed acting again later, doesn't skip a
# stage in the script early. _start_party_turn()/_show_moves() only apply
# the move-gate/flashing at all when the current actor matches that same
# diver; anyone else's turn during the tutorial plays out completely
# normally.
var _tutorial_step := 0
var _tutorial_enemy_turns := 0
# Flips true the one time _advance_turn() shows the "Defeat the enemy!"
# prompt (see its own header comment) - guards that prompt against firing
# again on every later _advance_turn() call once the script itself is done.
var _tutorial_finale_shown := false
# Same one-shot idea as _tutorial_finale_shown, for the first special
# encounter specifically - see _advance_turn()'s own second finale block.
# Can't reuse _tutorial_finale_shown's own trigger (_tutorial_step >=
# _TUTORIAL_SCRIPT.size()): _TUTORIAL_SCRIPT's stages 1-4 all name a party
# index (Musashi/Mech Pilot) that doesn't exist in this fight's solo party,
# so _tutorial_party_index_for_step() returns -1 for every step past 0 here
# and _tutorial_step can never actually reach _TUTORIAL_SCRIPT.size().
var _special_tutorial_finale_shown := false
# Set by _tutorial_prep_enemy_turn() right before its one scripted enemy
# turn, consumed (and reset) by _resolve_attack()'s own QTE roll - forces
# that specific swing into a Quick Time Event regardless of the normal
# ENEMY_QTE_CHANCE roll, so every player sees the mechanic demonstrated at
# least once instead of it being left entirely to chance.
var _tutorial_force_next_qte := false
var _tutorial_flash_tween: Tween
var _tutorial_caption: RichTextLabel
var _swap_demo_frame: PanelContainer
# Built unconditionally (see _build_ui()) - shows the per-diver level-up
# stat table _win() builds via _build_levelup_block(), any fight, not just
# the tutorial one.
var _levelup_caption: RichTextLabel
# Lazily built the first time _highlight_turn_order() runs - a red-bordered
# Panel sized to overlay _queue_bar, toggled on/off rather than rebuilt.
var _turn_order_highlight: Panel
# _explain_other_stats() boxes party[0]'s and enemies[0]'s whole status
# card (name/HP/oxygen/EVA together) via _set_row_highlight() on
# entry.card - see _build_overhead_bar(). Now that status cards sit in a
# fixed side column instead of floating over each combatant in the 3D
# stage, this is just a border toggle like every other highlight, not a
# per-frame repositioned overlay.
# How many "coming up" chips _refresh_queue_row() will ever draw, on top of
# the acting combatant's own separate "NOW" chip.
const MAX_QUEUE_SLOTS := 8
# Verification can hold the automatic entrance/turn dispatcher while it
# exercises each boss move directly. Shipped encounters leave this true.
var boss_intro_enabled := true

func _enemy_power_mult() -> float:
	return 1.0 + 0.15 * float(_special_round)

# Fallback identity only for the no-party_source case (tools/test_battle.gd
# instantiating a bare Battle) - mirrors whatever Diver would have built.
var diver_model_name := "Staff_Diver"

const RUN_CHANCE := 0.6
const MIN_ENEMIES := 1
const MAX_ENEMIES := 3
const OPENING_TWO_ENEMY_CHANCE := 0.25

# A fresh party can face one or two grunts. Three-grunt packs enter the roll
# only after the party has earned its first level; this removes the observed
# level-1 automatic-loss pack without deleting the harder formation.
static func max_enemies_for_level(player_level: int, is_guardian: bool = false) -> int:
	if is_guardian:
		return 1
	return 2 if player_level <= 1 else MAX_ENEMIES

# One shared roll policy for production and the balance gate. The opening
# keeps a minority two-enemy challenge, level 2 consolidates the mixed roster
# without introducing a three-pack, and level 3 unlocks all three formations.
static func ordinary_enemy_count_for_roll(player_level: int, roll: float, is_guardian: bool = false) -> int:
	if is_guardian:
		return 1
	var normalized := clampf(roll, 0.0, 0.999999)
	if player_level <= 1:
		return 2 if normalized < OPENING_TWO_ENEMY_CHANCE else 1
	if player_level == 2:
		return 1
	if normalized < 1.0 / 3.0:
		return 1
	return 2 if normalized < 2.0 / 3.0 else 3

# Authored enemy target scopes are content, not flavor text. `two` retains
# the already-selected primary and deterministically adds one other living
# diver; `all` preserves the live party order used by the HUD.
static func enemy_targets_for_scope(primary: Dictionary, alive_party: Array, scope: String) -> Array:
	if scope == "all":
		return alive_party.duplicate()
	var targets: Array = []
	if not primary.is_empty():
		targets.append(primary)
	if scope == "two":
		for candidate_value in alive_party:
			var candidate := candidate_value as Dictionary
			if candidate != primary:
				targets.append(candidate)
				break
	return targets

# Multi-hit formula moves consume the defender's current Evasion sequentially.
# Self-costs belong to the move, so they are applied on the first impact only.
static func resolve_formula_hits(attacker: CombatantStats, defender: CombatantStats, move: Dictionary, apply_self_effects: bool = true) -> Array:
	var results: Array = []
	for hit_index in range(maxi(1, int(move.get("hits", 1)))):
		if defender.hp <= 0:
			break
		results.append(CombatRules.resolve(attacker, defender, move, apply_self_effects and hit_index == 0))
	return results

# Compatibility alias for verification and any tools that enumerate the
# roster here. Cast is the single identity source used by Battle and World.
const DISPLAY_NAMES := Cast.DISPLAY_NAMES

# Attack is a category, not a single action: pressing it opens a move list
# instead of swinging right away. These base moves are always available -
# on top of whichever spells that specific party member has learned (see
# _moves_for()) - and now differ per diver instead of being one shared
# list, so the base kit itself carries some identity too, not just the
# spell tree layered on top of it. Glassgoat V2 moves use a `formula`
# Dictionary evaluated by CombatRules; legacy moves still use `power` and
# `acc_mod` until their own authored kits are ported.
#
# Prototype_1(1910) keeps Weaken/Slow as its base kit rather than damage
# moves - its whole identity is debuff support (see spell_tree.gd's header
# comment), so even the free moves everyone always has lean into that
# instead of being generic damage like the other two divers get.
#
# A missing `oxygen_cost` means a move is free. Glassgoat's current Scuba
# table specifies no oxygen costs, so all five are available while the two
# unported legacy kits retain their existing free basic/costly specials split.
const BASE_MOVES := {
	"Staff_Diver": CombatMoves.SCUBA,
	"Prototype_1(1910)": [
		{"name": "Precise Tap", "power": 1, "acc_mod": 9, "text": "You land a precise tap"},
		{"name": "Weaken", "power": 0, "acc_mod": 2, "debuff": "defense", "amount": 2, "hint": "Lowers a target's defense", "text": "You strike a nerve - its defense drops", "oxygen_cost": 10.0},
		{"name": "Slow", "power": 0, "acc_mod": 2, "debuff": "agility", "amount": 2, "hint": "Lowers a target's agility", "text": "You hobble it - its agility drops", "oxygen_cost": 10.0},
	],
	"Prototype_V(1922)": [
		{"name": "Guard Bash", "power": 6, "acc_mod": 3, "hint": "Sturdy, reliable", "text": "You bash it with your guard"},
		{"name": "Heavy Kick", "power": 10, "acc_mod": 0, "hint": "Balanced, heavier", "text": "You drive a heavy kick home", "oxygen_cost": 10.0},
		{"name": "Crushing Haymaker", "power": 15, "acc_mod": -3, "hint": "Very heavy, slow", "text": "You wind up and crush it", "oxygen_cost": 16.0},
	],
}

# var, not const: _ready() fills this in at runtime every time a Battle
# instance loads (see the loop just below _ready()'s declaration) - a const
# Dictionary in GDScript can't have its contents reassigned via subscript
# either, only a plain var can be mutated like this.
var stat_effects:= {}

# Maps a stats-panel row's display label to the key stat_effects stores it
# under (see _ready()'s stat_effects-building loop above). Only the four
# rows create_stats_panel() actually draws - a status effect like "bleed"/
# "blindness" can still land in stat_effects["enemy"] (see the "status"
# match branch above) but has no row to preview into, so it's silently
# skipped by _apply_stat_delta() rather than needing a fifth row here.
const STAT_ROW_KEYS := {"STR": "strength", "DEF": "defense", "ACC": "accuracy", "EVA": "evasion"}

# Built once in _build_ui() - see create_stats_panel(). Player panel is
# always visible and always shows whoever's turn it is (_start_party_turn()
# refreshes it); enemy panel only appears while hovering a specific enemy
# in target_menu (see _show_stat_preview()/_clear_stat_preview()).
var _player_stats_ui: Dictionary = {}
var _enemy_stats_ui: Dictionary = {}
# Set by _on_move_chosen() once a move's picked - the move's name on the
# left, its raw power right-aligned on the right (same "spell cost" layout
# as _add_power_badge() on the move button itself), sitting right above the
# two stat panels for as long as target_menu is up. _selected_move_panel
# wraps the row so _explain_damage() can box just the power number the
# same way _set_row_highlight() boxes a stat row. Cleared back to main
# menu/next turn - see _show_main()/_start_party_turn().
var _selected_move_panel: PanelContainer
var _selected_move_name: Label
var _selected_move_power: Label
# The party's authored V2 health scale is 10, not the former 10/26/42 mix.
# Nine flat power plus a grunt's Strength routinely one-shot that roster;
# three flat power keeps the ordinary claw on the same small-number scale as
# the player moves while defense and the occasional heavy still matter.
# It remains QTE-eligible because #66 decoupled QTE frequency from move type.
const ENEMY_MOVE := {"power": 3, "acc_mod": 1, "quick_time_bool": true}

# A much gentler stand-in for ENEMY_MOVE, used only for the choreographed
# first fight (see _do_enemy_turn()) - full power (9) plus a real grunt's
# strength was one-shotting Maxilani (hp_max 10, defense 0) in playtesting,
# well before she's had any chance to level up even once. Still a real
# hit with real quick_time_bool (so the forced QTE below has something to
# attach to), just not a lethal one.
const TUTORIAL_ENEMY_MOVE := {"power": 1, "acc_mod": 1, "quick_time_bool": true}

# Pinned onto the goblin's evasion_current right before Mech Pilot's
# Crushing Haymaker (stage 2) and Maxilani's Flash Blast (stage 4) resolve -
# see _explain_crushing_haymaker()/_explain_flash_blast(). Sits strictly
# between the two moves' own effective accuracy (Mech Pilot's base 4,
# minus Crushing Haymaker's own -3 acc_mod, is 1; Maxilani's base 3, Flash
# Blast carries no acc_mod at all) so the Haymaker's own accuracy cost is
# what makes IT miss while Flash Blast - identical target, same moment in
# the fight, no acc_mod of its own - still lands. Both divers' accuracy is
# fixed data (diver.gd's BASE_STATS), never randomized the way an enemy's
# own stats are, so this is reliable regardless of which goblin variant
# rolled for this fight.
const TUTORIAL_HAYMAKER_DODGE_EVASION := 2

# A grunt's occasional big swing - see _resolve_attack()'s "heavy" effect
# branch for how heavy_min/heavy_max actually turn into damage (a fraction
# of the DEFENDER's max HP, not power/strength like ENEMY_MOVE). Lower
# acc_mod than the normal swing - a hit this dangerous should be a little
# more telegraphed/missable, not just as reliable as a Jab.
const ENEMY_HEAVY_MOVE := {
	"power": 0, "acc_mod": -1, "quick_time_bool": true,
	"effect": "heavy", "heavy_min": 0.25, "heavy_max": 0.5,
}
# MODIFIED: was briefly dropped to 0.25 when this was still the QTE's own
# frequency knob (heavy swing and QTE used to be 1:1) - now that the QTE
# is its own independent roll (ENEMY_QTE_CHANCE) on either move, this
# constant goes back to just meaning "how often is this a heavy swing,"
# its original 0.3, with no more hidden coupling to QTE frequency.
const ENEMY_HEAVY_CHANCE := 0.3

# How often ANY enemy attack (normal or heavy - both are quick_time_bool
# true now) actually triggers the QTE, checked independently of which
# move was chosen - see _resolve_attack()'s own use of this. Player moves
# never carry quick_time_bool at all, so this only ever applies to the
# enemy's own turn regardless.
const ENEMY_QTE_CHANCE := 0.25

# Raised in place of ENEMY_HEAVY_CHANCE when the chosen target is already
# low enough that a heavy swing's own damage range could plausibly finish
# them (see _do_enemy_turn()) - an enemy that's just rolling dice every
# turn doesn't read as smart; one that goes for the kill when it's actually
# lined up does, without making the heavy swing itself hit any harder or
# any more reliably than it already did.
const ENEMY_HEAVY_FINISH_CHANCE := 0.65

# Glassgoat's combat-reading palette. Separate labels are required when one
# action produces more than one category; a Label3D only has one modulate
# color, so concatenating damage and Bleed made the requested distinction
# impossible.
const FEEDBACK_DAMAGE_COLOR := Color(1.0, 0.32, 0.27)
const FEEDBACK_EFFECT_COLOR := Color(0.3, 0.72, 1.0)
const FEEDBACK_NEGATIVE_COLOR := Color(0.76, 0.38, 1.0)

# How long a move's result stays on screen (log_label text) before whatever
# happens next - the next turn's own _log() call, or a win/lose/flee banner
# - overwrites it. log_label only ever shows one line at a time, no
# scrollback, so this is the entire reading window a player gets for any
# given message. Every create_timer() call directly after a _log() in this
# file uses this same constant now (they used to be separate 0.7/0.8/0.9
# magic numbers, all too short to actually read a sentence in) so pacing
# stays consistent and only needs tuning in one place.
const LOG_READ_DELAY := 1.6

# How far into a swing the hit is supposed to land. Waiting out the whole
# clip before resolving reads as the damage arriving after the attack has
# already finished, and skipping the wait entirely reads as the numbers
# moving before anyone has moved. Roughly half way is where a swing looks
# like it connects.
const IMPACT_FRACTION := 0.55

# How long the step in and the walk back take, and how far short of the
# target an attacker stops. SWING_REACH is roughly the length of the longest
# swing in the cast: Mech Pilot's hammer travels about that far.
const SWING_STEP_TIME := 0.18
const SWING_REACH := 1.8

# Overhead health bars.
const OVERHEAD_BAR_WIDTH := 104
const STATUS_COLUMN_WIDTH := 200
# How far above a combatant's own head the bar floats, in metres.
const OVERHEAD_LIFT := 0.12
# Shared by hp_label and oxygen_label (_build_overhead_bar()) - one number
# instead of two independently-picked ones (12 and 11) so "HP" and "O2"
# read as the same size at a glance instead of one looking like a demoted
# afterthought next to the other.
const OVERHEAD_VALUE_FONT_SIZE := 12
# World space set aside above each combatant for their own bar, so the
# camera frames the bar and not just the body. Roughly the bar's height at
# the distance these fights are fought at.
const OVERHEAD_HEADROOM := 0.55

var party: Array = []      # [{kind:"party", stats, model_name, display_name, equipped_spells, actor, hp_bar, hp_label}]
var enemies: Array = []    # [{kind:"enemy", stats, display_name, actor, hp_bar, hp_label}]

var _queue: Array = []     # combatants (same dict refs as party/enemies) still waiting to act this round
var _acting: Dictionary = {}
var _pending_move: Dictionary = {}
var _busy := false

var log_label: RichTextLabel
var queue_row: HBoxContainer
# HFlowContainer, not HBoxContainer - main_menu only ever has 2 buttons so
# it never mattered, but move_menu holds a diver's base moves + every
# learned spell + Back (more than one row's worth of 300px buttons) and target_menu can hold one button per living enemy/ally. A
# plain HBoxContainer doesn't wrap - it would just run buttons off the
# right edge instead of overflowing downward, the same "off-screen" bug
# class as _bottom_panel not sizing to content (see _fit_panel_height()).
var main_menu: HFlowContainer
var move_menu: HFlowContainer
var target_menu: HFlowContainer
var item_menu: HFlowContainer
var attack_btn: Button
var run_btn: Button
# Only built for tutorial_encounter (see _build_ui()) - Run itself stays
# disabled for the whole tutorial fight (see _start_party_turn()), so this
# is the one way to leave it early without fighting it out or losing on
# purpose. Ends the fight the same way choosing "Exit to World" on a real
# loss does (heal, return, mention the Esc menu replay) - see
# World._on_battle_finished()'s "skipped" case.
var skip_tutorial_btn: Button
var items_btn: Button
var back_btn: Button
var item_back_btn: Button
var target_back_btn: Button
var move_buttons: Array = []
# Move-menu scrolling. Learned spells are all auto-equipped with no cap, so
# a diver can have more moves than fit. At most MOVE_MENU_SLOTS buttons show
# at once (two rows of four); past that, the list pages with Up/Down,
# keeping MOVE_MENU_VISIBLE_MOVES moves plus the Up/Down pair and Back.
const MOVE_MENU_SLOTS := 8
const MOVE_MENU_VISIBLE_MOVES := MOVE_MENU_SLOTS - 2
var _move_scroll_box: VBoxContainer
var _move_up_btn: Button
var _move_down_btn: Button
var _move_scroll_offset := 0
var target_buttons: Array = []
var item_buttons: Array = []

# Set alongside _pending_move for a move, this for an item - exactly one
# of the two is ever non-empty at a time. _on_target_chosen() (target_menu's
# shared confirm handler) reads whichever one is set to know if it's
# resolving a move or an item use; target_back_btn reads it too, to know
# whether Back should return to move_menu or item_menu.
var _pending_item := ""

# The battle-stage SubViewport (see _build_stage()) - stored so
# _turn_cursor can be built as a child of the same 3D world the party/enemy
# actors live in, not the CanvasLayer's 2D UI tree.
var _stage_vp: SubViewport
# The stage stops at the top edge of the HUD rather than running the full
# height of the screen behind it. See _fit_panel_height().
var _stage_container: SubViewportContainer
var _stage_cam: Camera3D
# Fixed 2D status groups, not labels floating over each combatant in the
# 3D stage - enemies stack down the right while the party normally stacks
# down the left (see _build_overhead_bar()). The party uses a flow container
# so a tall tutorial caption can widen that one group and wrap the three cards
# into a short row without covering any of their numbers. This is still static
# HUD layout: no per-frame 3D projection or actor-following labels.
var _party_status_column: HFlowContainer
var _enemy_status_column: VBoxContainer
# The turn order, moved out of the bottom panel to the very top.
var _queue_bar: PanelContainer

# Same green downward cone world.gd's own active-diver cursor uses (see
# World._active_cursor) - marks whichever DIVER's turn it currently is on
# the battle stage itself, not just the queue row's "NOW" card. Only ever
# shown during a party member's turn (_start_party_turn()); hidden the
# instant it's an enemy's turn (_do_enemy_turn()) - there's no equivalent
# "whose turn" marker needed over a grunt, the move log already says who's
# attacking.
var _turn_cursor: MeshInstance3D
var _turn_cursor_target: Node3D
var _turn_cursor_height := 0.0

# Stored so _fit_panel_height() can resize it from anywhere menu visibility
# changes (_show_moves(), _show_main(), _on_move_chosen(), etc.), not just
# once at the end of _build_ui().
var _bottom_panel: PanelContainer

# The dodge prompt: an X-glyph panel to its left (what to press, static),
# a track to its right (when to press it, the part that actually moves).
# Built once here and reused every _quick_time_event() call, same
# build-once/reuse approach move_menu/target_menu already use, rather than
# constructing fresh nodes per QTE and leaking the old ones.
var qte_root: HBoxContainer
var qte_track: Control
var qte_zone: ColorRect
var qte_indicator: ColorRect
# MODIFIED: both scaled up 25% (150->187.5, 14->17.5) to make the whole
# popup physically bigger on screen - zone_width_frac/zone_start_frac in
# _quick_time_event() stay exactly as they were (fractions of this track,
# not absolute pixels), so the hit zone's actual on-screen size grows
# right along with the track automatically, no separate change needed.
const QTE_TRACK_WIDTH := 187.5
const QTE_TRACK_HEIGHT := 17.5

# Set for the duration of one _quick_time_event() call - _unhandled_input()
# only ever looks at these while _qte_active is true, so a stray X press
# outside a QTE (or during one that already resolved this frame) does
# nothing. No stored zone/duration fields alongside these two - qte_zone's
# and qte_indicator's own position/size ARE the hit-test data now (see
# _unhandled_input()), not a separate time-domain copy of them.
var _qte_active := false
var _qte_success := false

# Set for the duration of one _tutorial_show_step() call - _unhandled_input()
# flips this off the instant Enter/Numpad Enter is pressed, which is what
# lets the awaiting `while _tutorial_awaiting_enter` loop in that function
# return.
var _tutorial_awaiting_enter := false
var _tutorial_continue_btn: Button
# Separate from _busy, which remains true while an enemy action is in
# progress. This flag is only set when the player explicitly skips the
# tutorial, so turn flow cannot accidentally cancel instructional captions.
var _skip_tutorial_requested := false

# The subset of a spell def _register_stat_effects() reads, keyed by the
# same display name _moves_for() gives the spell's move-menu entry.
func _spell_preview_move(def: Dictionary, spell_id: String) -> Dictionary:
	var mv := {"name": String(def.get("display", spell_id))}
	for key in ["power", "acc_mod", "debuff", "amount", "effects"]:
		if def.has(key):
			mv[key] = def[key]
	if String(mv.get("debuff", "")) == "":
		mv.erase("debuff")
	return mv

# One move's entry in stat_effects - the per-stat deltas the stats panels
# preview while hovering a target (see _show_stat_preview()).
func _register_stat_effects(attack: Dictionary) -> void:
	var attack_name: String = attack["name"]

	if not stat_effects.has(attack_name):
		stat_effects[attack_name] = {
			"player": {},
			"enemy": {}
		}

	# -------------------------
	# Player's stat changes
	# -------------------------
	if "power" in attack:
		stat_effects[attack_name]["player"]["power"] = attack["power"]

	if "acc_mod" in attack:
		stat_effects[attack_name]["player"]["accuracy"] = attack["acc_mod"]

	# -------------------------
	# Enemy stat changes
	# -------------------------
	if "debuff" in attack:
		# Negated - _apply_debuff() actually subtracts `amount` from
		# the stat (a "debuff" lowers it), so the stored delta has to
		# be negative too, or _apply_stat_delta() would preview the
		# target's stat rising (green) instead of the drop (red) the
		# move actually causes.
		stat_effects[attack_name]["enemy"][attack["debuff"]] = -int(attack["amount"])

	# -------------------------
	# CombatMoves effects
	# -------------------------
	if "effects" in attack:
		for effect in attack["effects"]:
			var kind: String = effect.get("kind", "")

			match kind:

				"reduce_evasion":
					if "amount" in effect:
						if "accuracy" in effect["amount"]:
							# Negated - this is a reduction (see the
							# "reduce_" in the effect's own name), so
							# the preview reads as a decrease (red,
							# "-1"), not a stat increase.
							stat_effects[attack_name]["enemy"]["evasion"] = \
								-int(effect["amount"]["accuracy"])

				"status":
					if "status" in effect:
						var status_name: String = String(effect["status"])
						if "level" in effect:
							if "flat" in effect["level"]:
								var lvl: int = int(effect["level"]["flat"])
								stat_effects[attack_name]["enemy"][status_name] = lvl
								# Blindness has no row of its own in the
								# stats panel (see STAT_ROW_KEYS - only
								# STR/DEF/ACC/EVA), so without this its
								# preview would silently show nothing at
								# all despite actually lowering Agility,
								# Accuracy, AND Defense (see combatant_
								# stats.gd's effective_accuracy()/
								# effective_defense()). Negated same as
								# every other reduction above - mirror
								# onto the two of those three stats that
								# DO have a row.
								if status_name == "blindness":
									stat_effects[attack_name]["enemy"]["accuracy"] = -lvl
									stat_effects[attack_name]["enemy"]["defense"] = -lvl

				"self_temporary":
					if "accuracy" in effect:
						stat_effects[attack_name]["player"]["accuracy"] = \
							effect["accuracy"]

					if "evasion" in effect:
						stat_effects[attack_name]["player"]["evasion"] = \
							effect["evasion"]

func _ready() -> void:
	for diver in BASE_MOVES:
		for attack in BASE_MOVES[diver]:
			_register_stat_effects(attack)
	# Spell-tree moves too - they reach the move menu through _moves_for(),
	# not BASE_MOVES, so without this a learned spell's own acc_mod/debuff
	# (Tidal Burst's -4 ACC, Guard Break's -3 DEF) never previewed at all.
	for model_name in SpellTree.SPELL_TREES:
		for branch in SpellTree.SPELL_TREES[model_name]:
			for spell_id in SpellTree.SPELL_TREES[model_name][branch]:
				_register_stat_effects(_spell_preview_move(SpellTree.SPELL_TREES[model_name][branch][spell_id], String(spell_id)))

	layer = 10
	_build_party()
	_build_stage()
	_build_ui()
	_build_quick_time_ui()
	_refresh_all_bars()
	_rebuild_queue()
	if boss_encounter:
		_log("Tethys rises from the deep.")
		if boss_intro_enabled:
			_begin_boss_encounter()
	else:
		_log(encounter_intro_override if not encounter_intro_override.is_empty() else encounter_intro(enemies))
		_advance_turn()

static func encounter_intro(entries: Array) -> String:
	if entries.size() != 1:
		return "Enemies block the way!"
	return "%s blocks the way!" % String((entries[0] as Dictionary).get("display_name", "Enemy"))

# Builds one stats box (used for both the player panel and the enemy
# preview panel - see _build_ui()) and hands back every Label a caller
# might need to update later, since the locals here disappear the moment
# this function returns. `values` holds each stat's base-number Label;
# `deltas` holds the "+X"/"-Y" Label next to it, hidden until
# _apply_stat_delta() has something to show (see _show_stat_preview()/
# _clear_stat_preview()).
func create_stats_panel(title: String) -> Dictionary:
	var panel := PanelContainer.new()
	# MODIFIED (fixed): none of panel/margin/rows/stat_grid/row_panel below
	# ever set mouse_filter, so every one of them defaulted to STOP - unlike
	# _bottom_panel/margin/content_row/col (see _build_ui()'s own IGNORE
	# fixes on those), this panel was missed. It sits visible for the whole
	# fight, not just while a menu with real buttons is up (see this
	# function's own "player one sits visible all fight" comment elsewhere),
	# which made it a standing click-eater: during a special-encounter
	# minigame (mouse captured, no menus even shown) a click landing
	# anywhere over this panel's own screen rect - very likely, since it's
	# where the player's cursor was last resting before the mouse got
	# captured - was consumed here via _gui_input before it could ever reach
	# GrappleInterceptMinigame's _unhandled_input(), which is exactly why
	# left-clicking the correct-colored orbs did nothing at all (not even
	# the beam _grapple() always draws, confirming the click never arrived).
	# None of these nodes need real mouse interaction of their own - every
	# hover-driven preview in this file is wired through the actual target/
	# move BUTTONS' own mouse_entered/mouse_exited signals, never through
	# this panel or its row children.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(rows)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	rows.add_child(title_label)

	# Four stats in a compact 2x2 grid. Keeping the old one-column stack made
	# the bottom HUD tall enough to crop Bucky's status card at 1280x720 once
	# the move descriptions were added. The row panels remain individually
	# addressable, so Marc's tutorial highlights still target the same stats.
	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 14)
	stat_grid.add_theme_constant_override("v_separation", 2)
	stat_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(stat_grid)

	var values := {}
	var deltas := {}
	var stat_rows := {}
	for stat in ["STR", "DEF", "ACC", "EVA"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var name_label := Label.new()
		name_label.text = stat
		name_label.custom_minimum_size.x = 34
		name_label.add_theme_font_size_override("font_size", 13)

		var value_label := Label.new()
		value_label.text = "0"
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_color", Color.WHITE)

		var delta_label := Label.new()
		delta_label.text = ""
		delta_label.visible = false
		delta_label.add_theme_font_size_override("font_size", 13)

		row.add_child(name_label)
		row.add_child(value_label)
		row.add_child(delta_label)

		# Wraps `row` so a highlight (see _set_row_highlight()) can be drawn
		# as this PanelContainer's own background/border - always exactly
		# the right size and position by construction, since it's part of
		# the row's own layout pass rather than a separately-positioned
		# overlay Panel that has to be manually kept in sync (and can go
		# stale - see _highlight_box()'s own header comment on the queue
		# bar's simpler, non-nested case where that approach is still fine).
		var row_panel := PanelContainer.new()
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_panel.add_theme_stylebox_override("panel", _row_stylebox(false))
		row_panel.add_child(row)
		stat_grid.add_child(row_panel)

		values[stat] = value_label
		deltas[stat] = delta_label
		stat_rows[stat] = row_panel

	return {"panel": panel, "title": title_label, "values": values, "deltas": deltas, "rows": stat_rows}

# Transparent fill either way - `on` just adds/removes a bordered outline
# in `color` (red by default - _reposition_hp_highlight() passes purple
# instead, to read as visually distinct from the stat-row highlights).
# Kept as a plain StyleBoxFlat factory (not a cached resource swapped in/
# out) since a fresh override is cheap and this only ever runs on an
# explicit highlight toggle, never per-frame.
func _row_stylebox(on: bool, color: Color = Color(1, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	if on:
		style.border_color = color
		style.set_border_width_all(3)
	return style

# `row_panel` is one of create_stats_panel()'s returned `rows` entries (a
# PanelContainer wrapping that stat's name/value/delta row) - see
# _explain_dodging()/_explain_damage() for actual use.
func _set_row_highlight(row_panel: PanelContainer, on: bool, color: Color = Color(1, 0, 0)) -> void:
	row_panel.add_theme_stylebox_override("panel", _row_stylebox(on, color))

const STAT_COLOR_UP := Color(0.4, 0.9, 0.4)
const STAT_COLOR_DOWN := Color(0.9, 0.35, 0.35)
const STAT_COLOR_NEUTRAL := Color.WHITE

# The one place that knows which CombatantStats field/method backs each
# displayed row - shared by _set_stats_panel_base() (plain current value)
# and _apply_stat_delta() (current value, then value+delta once a preview
# lands), so the two can never disagree about what a row's base number is.
func _stat_value(s: CombatantStats, stat: String) -> int:
	match stat:
		"STR": return s.strength
		"DEF": return s.effective_defense()
		"ACC": return s.effective_accuracy()
		"EVA": return s.evasion_current
	return 0

# The move's own power, before any defense is subtracted - an "ability
# cost"-style number that only depends on the attacker, not on who's being
# hit. Formula-based moves (Glassgoat V2) go through CombatRules.
# formula_value() - the same static helper CombatRules.resolve() itself
# calls, so this can never read differently than a real hit's own raw
# damage; legacy power-based moves use apply_damage_roll()'s "power +
# strength", without its ±15% variance multiplier. Shown on the selected-
# move label (see _on_move_chosen()) - _preview_damage() below is the
# further, target-specific number _explain_damage() builds on top of this
# one. NOT what the move button's own corner badge shows (see
# _move_base_power() below, right next to this) - that's the move's own
# power alone, attacker-independent, so the same move reads the same
# number no matter who's about to use it.
func _preview_raw_power(mv: Dictionary, attacker: CombatantStats) -> int:
	# heal/revive have neither "formula" nor "power" - they're not an
	# attack missing one, they're a third category that does no damage
	# math at all. Falling through to the legacy branch below would read
	# "power + strength" as 0 + attacker.strength, showing the attacker's
	# raw Strength stat as if it were the move's power - meaningless for a
	# move that doesn't attack, and the actual reason this got noticed:
	# a heal button was badging the caster's Strength number.
	var effect := String(mv.get("effect", ""))
	if effect == "heal" or effect == "revive":
		return 0
	if mv.has("formula"):
		return int(round(CombatRules.formula_value(attacker, mv.get("formula", {}))))
	return int(round(float(mv.get("power", 0)) + float(attacker.strength)))

# The move's own power, on its own - no attacker stats folded in (contrast
# _preview_raw_power() above, which adds the wielder's Strength/other stats
# for a real damage preview). This is what the move button's own corner
# badge shows (see _add_power_badge()/_populate_move_menu()) and what
# _explain_damage()'s tutorial caption calls out as "the same number in the
# yellow badge" - a fixed property of the move itself, not a preview of what
# it'll do in this particular attacker's hands, so two divers looking at the
# same move see the same badge. Legacy moves: the "power" field directly.
# Formula moves: just the formula's own "base" term, none of its
# strength/defense/agility/evasion coefficients (see CombatRules.
# formula_value()) - those are exactly the attacker-dependent part this is
# deliberately leaving out.
func _move_base_power(mv: Dictionary) -> int:
	var effect := String(mv.get("effect", ""))
	if effect == "heal" or effect == "revive":
		return 0
	if mv.has("formula"):
		return int((mv.get("formula", {}) as Dictionary).get("base", 0))
	return int(mv.get("power", 0))

# Deterministic preview of what a move would actually deal against a
# specific defender right now - _preview_raw_power() above, minus that
# defender's Defense, using the exact same floor rule combat_rules.gd's
# resolve() applies (0 if Defense outstrips raw power by more than 5,
# otherwise never less than 1) so this can never describe the mechanic
# differently than a real hit would.
func _preview_damage(mv: Dictionary, attacker: CombatantStats, defender: CombatantStats) -> int:
	var raw := _preview_raw_power(mv, attacker)
	if raw <= 0:
		return 0
	var defense := defender.effective_defense()
	if defense - raw > 5:
		return 0
	return maxi(1, raw - defense)

# Base numbers only, no delta annotations - the "nothing hovered" state
# (main menu, items menu, just opened the move menu). Also resets each
# value's color to neutral white - without this, a value colored by a
# previous preview (see _apply_stat_delta()) would stay green/red forever
# once nothing's hovered.
func _set_stats_panel_base(ui: Dictionary, s: CombatantStats) -> void:
	for stat in ["STR", "DEF", "ACC", "EVA"]:
		(ui.values[stat] as Label).text = str(_stat_value(s, stat))
		(ui.values[stat] as Label).add_theme_color_override("font_color", STAT_COLOR_NEUTRAL)
	for stat in (ui.deltas as Dictionary):
		(ui.deltas[stat] as Label).visible = false

func _refresh_player_stats_panel() -> void:
	if _player_stats_ui.is_empty() or not _acting.has("stats"):
		return
	_set_stats_panel_base(_player_stats_ui, _acting.stats as CombatantStats)

# The stat's own number becomes what it would actually BE after this move
# (current value + delta), not just the current value recolored - green if
# that's a raise, red if it's a drop - with the delta itself alongside it
# in parentheses, e.g. "4 (-1)". Reads amounts straight out of
# stat_effects[move.name] (see _ready()'s own header comment on how that
# gets built) rather than re-deriving them, so the preview can never drift
# from whatever a move's actual data says it does.
func _apply_stat_delta(ui: Dictionary, s: CombatantStats, deltas: Dictionary) -> void:
	for stat in STAT_ROW_KEYS:
		var key: String = STAT_ROW_KEYS[stat]
		var value_label := ui.values[stat] as Label
		var delta_label := ui.deltas[stat] as Label
		var base := _stat_value(s, stat)
		if not deltas.has(key) or int(deltas[key]) == 0:
			value_label.text = str(base)
			value_label.add_theme_color_override("font_color", STAT_COLOR_NEUTRAL)
			delta_label.visible = false
			continue
		var amount := int(deltas[key])
		# Every real stat floors at 0 (effective_accuracy()/_apply_debuff()/
		# etc. all maxi(0, ...) their result) - the big number previews that
		# same floor rather than showing a negative total that could never
		# actually happen, but the delta alongside it stays the full,
		# unclamped amount so a -3 against a base of 1 still reads as -3,
		# not a misleadingly small -1.
		value_label.text = str(maxi(0, base + amount))
		value_label.add_theme_color_override("font_color", STAT_COLOR_UP if amount > 0 else STAT_COLOR_DOWN)
		delta_label.text = "(+%d)" % amount if amount > 0 else "(%d)" % amount
		delta_label.add_theme_color_override("font_color", STAT_COLOR_NEUTRAL)
		delta_label.visible = true

# Called on mouse_entered for a target button (see _populate_target_menu()/
# _populate_all_target_menu()) - shows what THIS move would do to THIS
# enemy: the enemy panel appears with their current stats, and both panels
# get the move's deltas overlaid via stat_effects. Only ever wired for
# enemy-targeting moves - a heal/revive's target picker lists allies, and
# previewing "enemy" deltas against an ally would just be wrong.
func _show_stat_preview(move: Dictionary, enemy: Dictionary) -> void:
	if not enemy.has("stats"):
		return
	var effects: Dictionary = stat_effects.get(String(move.get("name", "")), {})
	_apply_stat_delta(_player_stats_ui, _acting.stats as CombatantStats, effects.get("player", {}) as Dictionary)
	_set_stats_panel_base(_enemy_stats_ui, enemy.stats as CombatantStats)
	(_enemy_stats_ui.title as Label).text = String(enemy.get("display_name", "Enemy"))
	_apply_stat_delta(_enemy_stats_ui, enemy.stats as CombatantStats, effects.get("enemy", {}) as Dictionary)
	(_enemy_stats_ui.panel as Control).visible = true

# Called on mouse_exited, and from every path that leaves target_menu
# (choosing a target, backing out) so a stale preview never survives past
# the hover that produced it. Ignored while _stat_preview_frozen -
# _explain_dodging() sets that once the player's hovered once, so idly
# drifting the mouse off the (disabled but still hover-tracked) enemy
# button while reading the caption can't yank the panel/highlights away
# mid-explanation.
var _stat_preview_frozen := false

# Extra panels _show_all_stat_preview() builds beyond the one enemy that
# already fits in the shared _enemy_stats_ui slot - freed in
# _clear_all_stat_preview() rather than reused/pooled, since a hover only
# needs them for as long as it lasts and target counts vary fight to fight.
var _extra_enemy_stats_uis: Array[Dictionary] = []

# Only ever wired from _populate_all_target_menu()'s single "All enemies"
# button - the enemy picker's per-target buttons hover _show_stat_preview()
# instead, one panel is enough there since exactly one enemy is being
# considered. An all-target move (Flash Blast, Multiple Knee Combo, ...)
# actually hits every enemy at once, so showing only the first one's stats
# (what this used to do, sharing the single _enemy_stats_ui slot the normal
# single-target hover uses) hid what the move was about to do to everyone
# else. Reuses that same shared slot for enemies[0], then builds one
# throwaway extra panel per additional enemy in the same stats row.
func _show_all_stat_preview(move: Dictionary, enemies: Array) -> void:
	if enemies.is_empty():
		return
	_show_stat_preview(move, enemies[0] as Dictionary)
	var container := (_enemy_stats_ui.panel as Control).get_parent()
	var effects: Dictionary = stat_effects.get(String(move.get("name", "")), {})
	for i in range(1, enemies.size()):
		var enemy := enemies[i] as Dictionary
		if not enemy.has("stats"):
			continue
		var extra := create_stats_panel(String(enemy.get("display_name", "Enemy")))
		_set_stats_panel_base(extra, enemy.stats as CombatantStats)
		_apply_stat_delta(extra, enemy.stats as CombatantStats, effects.get("enemy", {}) as Dictionary)
		(extra.panel as Control).visible = true
		container.add_child(extra.panel as Control)
		_extra_enemy_stats_uis.append(extra)

func _clear_all_stat_preview() -> void:
	if _stat_preview_frozen:
		return
	for extra in _extra_enemy_stats_uis:
		(extra.panel as Control).queue_free()
	_extra_enemy_stats_uis.clear()
	_clear_stat_preview()

func _clear_stat_preview() -> void:
	if _enemy_stats_ui.is_empty() or _stat_preview_frozen:
		return
	(_enemy_stats_ui.panel as Control).visible = false
	# Full reset, not just hiding the delta labels - _apply_stat_delta() now
	# overwrites the value text itself with the post-move total, so without
	# this the player panel would keep showing that total (and its green/red
	# tint) after the hover that produced it ends.
	if _acting.has("stats"):
		_set_stats_panel_base(_player_stats_ui, _acting.stats as CombatantStats)

func _begin_boss_encounter() -> void:
	_busy = true
	_set_all_buttons(false)
	if not enemies.is_empty() and enemies[0].actor is TethysBoss:
		await (enemies[0].actor as TethysBoss).play_swim_intro()
	_log("Tethys settles over the battlefield.")
	await get_tree().create_timer(0.45).timeout
	_advance_turn()

# The existing stage, party actors and combat UI survive the interruption.
# Only the fallen enemy and its status card are replaced; no world/result
# surface appears between the player's victory and the new threat.
func reveal_prologue_octopus() -> void:
	if prologue_octopus_encounter:
		return
	_busy = true
	_audio_call(&"fade_music_out", [0.15])
	await get_tree().create_timer(0.65).timeout
	prologue_angler_encounter = false
	prologue_octopus_encounter = true
	encounter_source = "prologue_octopus"
	for old_enemy in enemies:
		if old_enemy.has("actor") and is_instance_valid(old_enemy.actor):
			(old_enemy.actor as Node).queue_free()
		if old_enemy.has("card") and is_instance_valid(old_enemy.card):
			(old_enemy.card as Control).queue_free()
	enemies.clear()
	_clear_all_stat_preview()
	_selected_move_panel.visible = false
	(_player_stats_ui.panel as Control).visible = false
	var cordys := PrologueOctopusScript.new() as Node3D
	_stage_vp.add_child(cordys)
	cordys.position = Vector3(3.6, 0.0, -0.6)
	var party_center := Vector3.ZERO
	for index in range(party.size()):
		var entry := party[index] as Dictionary
		var actor := entry.actor as Diver
		# A compact, grounded formation keeps a four-metre threat readable in
		# the short laptop stage. This changes only the prologue presentation.
		actor.position = Vector3(-2.8 + 1.4 * index, -actor.foot_offset(), 0.5 + 0.4 * (index % 2))
		entry.home_pos = actor.position
		party_center += (entry.actor as Node3D).position
	party_center /= float(maxi(1, party.size()))
	cordys.call("face_toward", party_center)
	for entry in party:
		(entry.actor as Diver).look_at(cordys.position, Vector3.UP)
		entry.home_rot = (entry.actor as Diver).rotation.y
	var stats := CombatantStats.new()
	stats.hp_max = 1000
	# Opening-only numbers: the normal low-level kit can hurt Cordys, but
	# cannot defeat him. No player damage clamp or invulnerability modifier.
	stats.strength = 80
	stats.accuracy = 30
	stats.agility = 20
	stats.evasion = 0
	stats.defense = 0
	stats.fill()
	var enemy := {
		"kind": "enemy", "stats": stats, "display_name": "Cordys",
		"actor": cordys, "home_pos": cordys.position,
		"home_rot": cordys.rotation.y, "xp_reward": 0,
	}
	enemies.append(enemy)
	_build_overhead_bar(enemy)
	_refresh_all_bars()
	for child in _stage_vp.get_children():
		if child is WorldEnvironment:
			var environment := (child as WorldEnvironment).environment
			environment.background_color = Color("06151f")
			environment.fog_light_color = Color("092332")
			environment.fog_density = 0.028
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25.0, 150.0, 0.0)
	rim.light_color = Color("9cbfff")
	rim.light_energy = 1.35
	_stage_vp.add_child(rim)
	_audio_call(&"play_cordys_music")
	_log("Cordys.")
	_frame_stage_camera()
	var reveal_length := float(cordys.call("play", "reveal"))
	await get_tree().create_timer(maxf(1.1, reveal_length)).timeout
	cordys.call("play", "idle")
	prologue_phase_changed.emit("octopus_response")
	_queue.clear()
	_queue.append(enemy)
	_acting = party[0]
	_refresh_queue_row()
	_start_party_turn(_acting)

func _resolve_prologue_finisher() -> void:
	if _prologue_response_resolved:
		return
	_prologue_response_resolved = true
	_busy = true
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	_selected_move_panel.visible = false
	(_player_stats_ui.panel as Control).visible = false
	(_enemy_stats_ui.panel as Control).visible = false
	# Let the real damage/status result remain readable before the response.
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	prologue_phase_changed.emit("scripted_defeat")
	var cordys := enemies[0].actor as Node3D
	_log("Cordys unleashes Poison Breath.")
	var length := float(cordys.call("play", "finish"))
	await get_tree().create_timer(maxf(0.4, length * IMPACT_FRACTION)).timeout
	_audio_call(&"duck_music", [-9.0, 0.4])
	var attacker := enemies[0].stats as CombatantStats
	attacker.begin_turn()
	var breath := {"name": "Poison Breath", "formula": {"strength": 1}, "effects": [
		{"kind": "status", "status": "poison", "level": {"flat": 4}, "duration": 3},
	]}
	var summaries: Array[String] = []
	var impact_played := false
	for entry in _living(party):
		var result := CombatRules.resolve(attacker, entry.stats as CombatantStats, breath)
		var audible := bool(result.hit) and int(result.damage) > 0 and not impact_played
		_show_combat_feedback(entry, result, audible)
		impact_played = impact_played or audible
		_react(entry, result)
		summaries.append("%s %s" % [String(entry.display_name), "-%d" % int(result.damage) if result.hit else "evades"])
		if (entry.stats as CombatantStats).hp <= 0:
			(entry.actor as Diver).play_death_fade()
	_log("Cordys uses Poison Breath: %s." % "; ".join(summaries))
	print("PROLOGUE_BREATH|strength=%d|accuracy=%d|%s" % [attacker.strength, attacker.effective_accuracy(), "; ".join(summaries)])
	_finish_actor_turn(enemies[0])
	_refresh_all_bars()
	await get_tree().create_timer(maxf(0.8, length * (1.0 - IMPACT_FRACTION))).timeout
	if not _living(party).is_empty():
		# Diagnostic/high-stat survivors are real survivors, not silently
		# overwritten to preserve the scene. Another normal choice is legal.
		_prologue_response_resolved = false
		cordys.call("play", "idle")
		_acting = _living(party)[0]
		_start_party_turn(_acting)
		return
	_audio_call(&"stop_music")
	finished.emit("prologue_defeat")

# The top and bottom of a combatant in world space. Diver and Goblin put
# their models at different heights relative to their own origin, so this
# asks them (head_offset/foot_offset) instead of adding `height` and being
# right about half the cast.
func _top_of(a: Node3D) -> Vector3:
	return a.global_position + Vector3(0.0, float(a.call("head_offset")), 0.0)

func _bottom_of(a: Node3D) -> Vector3:
	return a.global_position + Vector3(0.0, float(a.call("foot_offset")), 0.0)

# Same technique the overhead HP/status bars used before they moved into a
# fixed side column (see _build_overhead_bar()'s own header comment, and
# the git history it points to) - unproject_position() answers in the
# STAGE VIEWPORT's own pixel space, which then has to be scaled up to
# _stage_container's actual on-screen size and offset by that container's
# own position, since the stage doesn't start at this CanvasLayer's
# top-left corner. Falls back to the stage's own center when there's no
# camera/container to project through, or the point is behind the camera
# (unproject_position() answers nonsense for a point behind it) - a rough
# fallback spot beats a crash or an uninitialized (0, 0).
func _project_to_screen(point: Vector3) -> Vector2:
	if _stage_cam == null or _stage_container == null or _stage_vp == null or _stage_cam.is_position_behind(point):
		if _stage_container != null:
			return _stage_container.position + _stage_container.size * 0.5
		return get_viewport().get_visible_rect().size * 0.5
	var scale_to_screen := Vector2(
		_stage_container.size.x / maxf(1.0, float(_stage_vp.size.x)),
		_stage_container.size.y / maxf(1.0, float(_stage_vp.size.y)),
	)
	return _stage_cam.unproject_position(point) * scale_to_screen + _stage_container.position

# Battle keeps combatants as plain Dictionaries (see this file's own header
# comment), so a bare CombatantStats (all _resolve_attack() has - see its
# own signature) can't point back to the Node3D actor that owns it without
# a search. Used only for the QTE's own screen position (_quick_time_event()
# via _resolve_attack()) - nothing performance-sensitive enough for this
# linear scan (party.size() + enemies.size() is always tiny) to matter.
func _actor_for_stats(s: CombatantStats) -> Node3D:
	for entry in (party + enemies):
		if entry.get("stats") == s and entry.has("actor") and is_instance_valid(entry.actor):
			return entry.actor as Node3D
	return null

func _display(model_name: String) -> String:
	return Cast.display_name(model_name)

# Stand-in used only when nothing hands this Battle a party before it
# enters the tree - mirrors whatever Diver would have built for
# diver_model_name, so a standalone Battle (see tools/test_battle.gd)
# still has real numbers to fight with instead of nulls.
func _default_player_stats() -> CombatantStats:
	var base: Dictionary = Diver.BASE_STATS.get(diver_model_name, Diver.BASE_STATS["Staff_Diver"])
	var s := CombatantStats.new()
	s.hp_max = int(base.hp)
	s.strength = int(base.strength)
	s.defense = int(base.defense)
	s.agility = int(base.agility)
	s.evasion = int(base.evasion)
	s.accuracy = int(base.accuracy)
	s.fill()
	return s

func _build_party() -> void:
	if party_source.is_empty():
		party.append({
			"kind": "party", "stats": _default_player_stats(),
			"model_name": diver_model_name, "display_name": _display(diver_model_name),
			"equipped_spells": [],
			"ability_id": String(Diver.BASE_STATS.get(diver_model_name, {}).get("ability", "")),
		})
		return
	for d in party_source:
		var dv := d as Diver
		party.append({
			"kind": "party", "stats": dv.stats,
			"model_name": dv.model_name, "display_name": _display(dv.model_name),
			"equipped_spells": dv.equipped_spells, "ability_id": dv.ability_id,
			"diver": dv,
		})

# A SubViewport with its own camera, light and fog: isolated from the dive
# site's World3D (own_world_3d) so the two scenes can't see each other.
# Builds one throwaway visual Diver per party member and however many
# Goblins the encounter rolled - these actors are display-only, the real
# stats live in party[]/enemies[], not on these nodes.
func _build_stage() -> void:
	# Full width, and from the top of the screen down to wherever the HUD
	# starts. It used to be the whole screen with the HUD painted over it,
	# and since Godot's default PanelContainer background is 60% black
	# rather than opaque, that did not hide the fight so much as smear it:
	# the lower half of every combatant showed through a grey sheet. The
	# camera aimed there too, so at 1280x720 all five combatants sat below
	# the HUD's top edge while the top half of the screen was empty water.
	# _fit_panel_height() keeps the bottom edge on the panel, and the
	# resized signal reframes the camera into whatever is left.
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	# MODIFIED (added): a Control's default mouse_filter is STOP, and this
	# container covers the entire battle screen (PRESET_FULL_RECT) - every
	# mouse motion/click landing anywhere on it was being consumed right
	# here before it could ever reach _unhandled_input(), which is exactly
	# how GrappleInterceptMinigame's own mouse-look/left-click-to-grapple
	# input (added as a sibling Control on this same CanvasLayer, see
	# _do_grapple_intercept_encounter()) receives look and fire at all.
	# IGNORE lets those events pass straight through; nothing embedded in
	# the 3D stage viewport itself needs real mouse input (targeting is
	# keyboard-driven, see world.gd's target_selector).
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_stage_container = container
	container.resized.connect(_frame_stage_camera)

	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.own_world_3d = true
	container.add_child(vp)
	_stage_vp = vp

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.13, 0.17)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.5, 0.56)
	e.ambient_light_energy = 1.1
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.16, 0.2)
	e.fog_density = 0.05
	env.environment = e
	vp.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_color = Color(0.75, 0.9, 1.0)
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 70.0
	vp.add_child(cam)
	_stage_cam = cam
	# Positioned by _frame_stage_camera() once the actors exist, not here.
	# The hand-placed position this replaces was tuned against a full height
	# stage and put every combatant behind the HUD once the HUD grew.
	if boss_encounter:
		_build_boss_lab_stage(vp)

	# Party visuals, spread left-to-right so 1-3 divers don't overlap.
	# Diver.rotation.y == 0 is the model's own rest-facing direction (-Z, see
	# diver.gd), so leaving it untouched here is what puts its back to camera.
	var is_swap_encounter := special_encounter and not party.is_empty() and String(party[0].get("ability_id", "")) == "swap"
	# Tethys is fought inside the Broken Office rather than in the open-water
	# lanes. Keep the party wholly inside that room and compact enough that all
	# four silhouettes remain legible in the supported 720px-wide browser.
	var diver_z := -0.5 if boss_encounter else (3.4 if is_swap_encounter else (2.2 if special_encounter else 1.0))
	# MODIFIED (changed): was -6.0 for a swap encounter - pushed a few more
	# units back so the portraits (which spawn just in front of the enemy
	# and fly to just in front of the diver - see diver_swap_minigame.gd's
	# _select_correct_portraits()) get a longer stretch of open water to
	# cross instead of a short hop, giving the player more time to actually
	# see one coming and react.
	var enemy_z := -9.0 if is_swap_encounter else (-4.6 if special_encounter else -2.2)
	var pn := party.size()
	for i in range(pn):
		if (party[i].stats as CombatantStats).hp <= 0:
			continue
		var actor := Diver.new()
		actor.model_name = String(party[i].model_name)
		vp.add_child(actor)
		# Open-water fights deliberately use the actors' normal centred depth.
		# Tethys's enclosed lab has a visible floor at y=0, however, and Diver's
		# public foot_offset() says its feet sit below its centred origin. Ground
		# only that boss formation after _ready() has measured the selected rig.
		var floor_y := -actor.foot_offset() if boss_encounter else 0.0
		var party_spread := 1.3 if boss_encounter else 2.9
		var party_depth_spread := 0.3 if boss_encounter else 0.7
		var party_x_offset := -1.0 if boss_encounter else -0.4
		actor.position = Vector3(_spread(i, pn, party_spread) + party_x_offset, floor_y, diver_z - _spread(i, pn, party_depth_spread))
		party[i]["actor"] = actor
		# Where this one stands when it is not swinging. Attacks step in
		# toward whoever they are aimed at and come back here afterwards.
		party[i]["home_pos"] = actor.position
		party[i]["home_rot"] = actor.rotation.y

	_build_turn_cursor()

	# Enemies: a random count, each with stats rolled close to the party's
	# own current average (see _party_average_stats()/goblin.gd's
	# make_stats()) rather than an independent level curve.
	var lvl := int((party[0].stats as CombatantStats).level) if not party.is_empty() else 1
	var ref_stats := _party_average_stats()
	# MODIFIED (added): make_stats() below scales the grunt to be a
	# credible threat against `ref_stats` regardless of context - in a
	# normal fight that reference is a full party's average, worn down by
	# three attackers' combined output. `party` is just the one chosen
	# diver in a special encounter (see _start_battle()'s custom_party),
	# so `ref_stats` here is really just that solo diver's own stats - the
	# grunt came out exactly as tough as a normal-fight grunt, but with
	# only one diver's own moveset chipping away at it instead of three,
	# which is why a special encounter dragged on far longer than intended
	# and read as "barely doing any damage." Halving hp_max/defense
	# specifically (not the grunt's own offense - strength/agility/
	# accuracy/evasion are untouched, this isn't about it hitting softer)
	# brings a solo fight's pace back in line with a normal one. _edge()'s
	# own 1.08x-1.35x difficulty bump in make_stats() still applies on top
	# of this, same as any other fight. Skipped for a boss - Tethys is built
	# from its own scaling entirely (see TethysBoss.make_stats() below).
	if (special_encounter or tutorial_encounter) and not boss_encounter:
		ref_stats.hp_max = maxi(1, int(round(float(ref_stats.hp_max) * 0.5)))
		ref_stats.defense = int(round(float(ref_stats.defense) * 0.5))
	# A special encounter is always a solo diver against exactly one grunt -
	# it's built around one character's ability minigame (see _do_enemy_
	# turn()'s special_encounter branch), not a real multi-enemy fight. The
	# tutorial fight is solo for the same reason: one diver, one grunt, no
	# random pack size to complicate a first-ever fight.
	var count := 1 if boss_encounter or special_encounter or tutorial_encounter or prologue_angler_encounter else ordinary_enemy_count_for_roll(lvl, randf(), guardian_encounter)
	if boss_encounter:
		var boss := TethysBoss.new()
		# Keep the boss close to the party's depth plane. At the grunt row's
		# -2.7 z position, perspective made a four-metre creature read smaller
		# on screen than the divers despite its measured native scale.
		# Keep Tethys on the opposite side of the room rather than directly
		# behind Bucky. The old overlap hid her torso and most of the authored
		# animation even though every actor technically fit inside the frame.
		boss.position = Vector3(2.1, 0.0, -2.5)
		vp.add_child(boss)
		# Mermaid_Freak's authored front is local +Z (the humanoid/Goblin
		# actors use -Z), so point that axis at the party's actual centre.
		# MODIFIED (fixed): a party member who entered this fight already at
		# hp<=0 never gets an "actor" here at all (see the hp<=0 skip just
		# below, in the per-diver visual loop) - dot-accessing .actor on that
		# entry crashed instead of just leaving her out of the average.
		var party_centre := Vector3.ZERO
		var party_actor_count := 0
		for party_entry in party:
			if not party_entry.has("actor"):
				continue
			party_centre += (party_entry.actor as Node3D).global_position
			party_actor_count += 1
		party_centre /= maxf(1.0, float(party_actor_count))
		boss.face_toward(party_centre)
		var boss_stats := boss.make_stats(ref_stats, lvl)
		enemies.append({
			"kind": "enemy", "stats": boss_stats,
			"display_name": TethysBoss.DISPLAY_NAME,
			"actor": boss,
			"home_pos": boss.position,
			"home_rot": boss.rotation.y,
			"xp_reward": boss.xp_reward,
			"boss": true,
		})
		_frame_stage_camera()
		return
	for i in range(count):
		# The opening lesson explicitly teaches against the Angler. Drawing from
		# the ordinary roster here made that contract random: a Frilled Shark or
		# Swordfish could replace the named tutorial opponent even though every
		# caption and QTE explanation still described an Angler. Special tutorial
		# practice uses the same predictable onboarding opponent.
		var g: Goblin = _actor_for_enemy_id("angler") if tutorial_encounter or prologue_angler_encounter else (_guardian_actor() if guardian_encounter else _ordinary_actor())
		# Special encounters use the deliberately deeper lane selected above.
		# Grapple Intercept needs that depth to read as an incoming wave rather
		# than a ring spinning near the player; swap encounters already use the
		# same spacing principle for their incoming portraits.
		# The authored lab blockers are single, broad-bodied set-piece actors.
		# The ordinary centre lane visually interleaves them with the three-diver
		# row from the production camera, making it unclear which side is which.
		# Give only this encounter source a distinct enemy lane; random packs and
		# special minigames keep their established composition.
		var enemy_x := _spread(i, count, 2.3) + 0.6
		# A solo Frilled Shark is still much longer than an Angler after its
		# horizontal cap. The generic centre lane places that silhouette across
		# Bucky from the production camera, so give this one-body formation the
		# same clear opposing-side read as authored broad-bodied encounters.
		if g is FrilledShark and count == 1:
			enemy_x = 5.0
		if encounter_source == "lab_blocker":
			# Sword Slayer's pivot sits near its mid-body while the long bill and
			# tail extend left across Bucky at the shared blocker lane. Give only
			# that long silhouette extra separation; Bomb Bot already frames cleanly.
			enemy_x = 6.2 if guardian_enemy_id == "sword_slayer" else 4.2
		g.position = Vector3(enemy_x, 0.0, enemy_z - _spread(i, count, 0.5))
		vp.add_child(g)
		# Same hp<=0-skips-the-actor case as the boss branch above.
		var party_centre := Vector3.ZERO
		var party_actor_count := 0
		for party_entry in party:
			if not party_entry.has("actor"):
				continue
			party_centre += (party_entry.actor as Node3D).global_position
			party_actor_count += 1
		party_centre /= maxf(1.0, float(party_actor_count))
		g.face_toward(party_centre)
		var st: CombatantStats = g.make_stats(ref_stats, lvl)
		if prologue_angler_encounter:
			# Isolated one-action promise. Every exposed attack still resolves
			# through normal target selection, animation and CombatRules, but this
			# instance cannot evade, mitigate, survive, or win the first turn.
			st.hp_max = 1
			st.strength = 0
			st.defense = 0
			st.agility = 0
			st.accuracy = 0
			st.evasion = 0
			st.fill()
		if tutorial_encounter:
			# Five-plus real turns (every scripted move, then however many
			# more real ones it actually takes to win or lose once
			# _advance_turn()'s "Defeat the enemy!" prompt hands the fight
			# over for real) would otherwise stand a real chance of killing
			# this grunt before the lesson's even over - pad its own HP out
			# so it survives long enough. Its offense gets cut too (see
			# TUTORIAL_ENEMY_MOVE/_do_enemy_turn()'s tutorial-only no-heavy-
			# swing rule) - a full-strength grunt one-shotting Maxilani (hp_max
			# 10) on her very first fight, before any level-up, was an actual
			# observed playtest death, not a hypothetical one.
			st.hp_max *= 3
			st.hp = st.hp_max
			st.strength = maxi(1, int(round(float(st.strength) * 0.5)))
			st.accuracy = maxi(1, int(round(float(st.accuracy) * 0.7)))
			if special_encounter:
				# Forced below the reference's own agility (ref_stats here IS
				# Maxilani's agility - this fight's party is just her, see
				# _build_stage()'s own comment on ref_stats above) so this
				# exact fight actually delivers on _first_fight_prompt()'s
				# "In this case, Maxilani will attack first." caption. Left to
				# the ordinary roll a few lines up (Goblin.make_stats() via
				# _edge(), always > 1.0) the enemy's agility would end up >=
				# hers almost every time instead.
				st.agility = maxi(1, ref_stats.agility - 1)
		enemies.append({
			"kind": "enemy", "stats": st,
			"display_name": g.display_name() if count == 1 else "%s %d" % [g.display_name(), i + 1],
			"actor": g,
			"home_pos": g.position,
			"home_rot": g.rotation.y,
			"xp_reward": g.xp_reward,
		})

	_frame_stage_camera()

func _build_boss_lab_stage(viewport: SubViewport) -> void:
	# The exterior deliberately hides this incomplete room inside a rock shell.
	# The boss battle owns a separate 3D world, so it must instantiate the room
	# here as well; merely revealing the overworld copy would leave combat in
	# the generic empty-water stage.
	var wrapper := Node3D.new()
	wrapper.name = "BrokenOfficeBattleStage"
	wrapper.add_to_group("boss_lab_stage")
	viewport.add_child(wrapper)
	var office := BOSS_LAB_SCENE.instantiate() as Node3D
	wrapper.add_child(office)
	_style_boss_lab_materials(office)
	# At the imported room's old 0.31 scale, the front party row stood outside
	# its footprint and the office read as a small detached diorama behind the
	# fight. The larger authored arena encloses both rows while leaving the
	# camera outside its open front.
	wrapper.scale = Vector3.ONE * 0.47
	wrapper.rotation_degrees.y = 180.0
	wrapper.force_update_transform()
	# Align the actual wall/floor shell, not the delivery's distant decorative
	# lantern. The latter is outside the playable room and previously shifted
	# the whole office right, leaving the party over empty water.
	var bounds := _boss_lab_room_bounds(wrapper)
	if bounds.size.length() > 0.01:
		wrapper.global_position += Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z - 1.8)
		bounds = _boss_lab_room_bounds(wrapper)
		_add_boss_lab_light(
			wrapper, "EmergencyLight", bounds,
			Vector3(0.18, 0.68, 0.24), Color("ff4f63"))
		_add_boss_lab_light(
			wrapper, "ContainmentLight", bounds,
			Vector3(0.82, 0.58, 0.28), Color("43d9e6"))

# Broken Office's wall materials arrive at roughly 0.91 luminance. Under the
# normal bright battle environment that turns the authored room into a white
# test box and visually collapses its furniture into the party. Keep every
# delivered texture, but color-grade the surfaces into a damaged underwater
# laboratory with distinct shell, machinery, furniture, and warning props.
func _style_boss_lab_materials(office: Node3D) -> void:
	for mesh_value in _battle_set_meshes(office):
		var mesh := mesh_value as MeshInstance3D
		if mesh.name == "Staff_Lantern":
			# This source outlier sits tens of metres outside the room and belongs
			# to the asset-authoring scene, not the compact battle tableau.
			mesh.visible = false
			continue
		var tint := Color("59727d")
		match String(mesh.name):
			"Wall_Broken":
				tint = Color("17333f")
			"Door_Frame":
				tint = Color("6f4b35")
			"Computer":
				tint = Color("397d83")
			"Cone", "Cone_001":
				tint = Color("d46b3d")
			"Table", "Cube", "Cube_002":
				tint = Color("79503b")
			_:
				if String(mesh.name).begins_with("Cube_"):
					tint = Color("784238")
		if mesh.mesh == null:
			continue
		for surface_index in range(mesh.mesh.get_surface_count()):
			var source := mesh.get_active_material(surface_index)
			if not source is BaseMaterial3D:
				continue
			var styled := source.duplicate(true) as BaseMaterial3D
			var original := (source as BaseMaterial3D).albedo_color
			styled.albedo_color = Color(
				original.r * tint.r,
				original.g * tint.g,
				original.b * tint.b,
				original.a)
			styled.roughness = maxf(0.68, styled.roughness)
			mesh.set_surface_override_material(surface_index, styled)

func _add_boss_lab_light(
		wrapper: Node3D,
		light_name: String,
		bounds: AABB,
		normalized_position: Vector3,
		color: Color) -> void:
	var position := bounds.position + bounds.size * normalized_position
	var fixture := MeshInstance3D.new()
	fixture.name = "%sFixture" % light_name
	fixture.top_level = true
	var fixture_mesh := BoxMesh.new()
	fixture_mesh.size = Vector3(0.18, 0.85, 0.12)
	fixture.mesh = fixture_mesh
	var fixture_material := StandardMaterial3D.new()
	fixture_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fixture_material.albedo_color = color
	fixture_material.emission_enabled = true
	fixture_material.emission = color
	fixture_material.emission_energy_multiplier = 2.4
	fixture.material_override = fixture_material
	wrapper.add_child(fixture)
	fixture.global_position = position

	var light := OmniLight3D.new()
	light.name = light_name
	light.top_level = true
	light.light_color = color
	light.light_energy = 3.2
	light.omni_range = maxf(6.0, bounds.size.length() * 0.42)
	light.shadow_enabled = true
	wrapper.add_child(light)
	light.global_position = position + Vector3(0.0, -0.25, 0.45)

func _battle_set_bounds(node: Node3D) -> AABB:
	var combined := AABB()
	var first := true
	for mesh_value in _battle_set_meshes(node):
		var mesh := mesh_value as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		combined = box if first else combined.merge(box)
		first = false
	return combined

# The Broken Office delivery contains one decorative Staff_Lantern far above
# and left of the actual room. Aggregate bounds are still useful for asset
# inspection, but not for placing or validating the playable floor: including
# that outlier makes the wall/floor shell land several metres to the right of
# the combatants. Use the authored room shell when it is present, with the
# aggregate as a safe fallback if the asset is ever revised.
func _boss_lab_room_bounds(node: Node3D) -> AABB:
	for mesh_value in _battle_set_meshes(node):
		var mesh := mesh_value as MeshInstance3D
		if mesh.name == "Wall_Broken" and mesh.mesh != null:
			return mesh.global_transform * mesh.get_aabb()
	return _battle_set_bounds(node)

func _battle_set_meshes(node: Node) -> Array:
	var found: Array = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_battle_set_meshes(child))
	return found

func _guardian_actor() -> Goblin:
	return _actor_for_enemy_id(guardian_enemy_id)

func _ordinary_actor() -> Goblin:
	return _actor_for_enemy_id(EnemyRoster.random_id())

func _actor_for_enemy_id(enemy_id: String) -> Goblin:
	match enemy_id:
		"swordfish_duelist":
			return SwordDuelist.new()
		"frilled_shark":
			return FrilledShark.new()
		"bomb_bot":
			return BombBot.new()
		"sword_slayer":
			return SwordSlayer.new()
		_:
			return Goblin.new()

# Glass_Goat authored the attacks for a 2D presentation, so the arm travel
# and body recoil read from a three-quarter angle and disappear into the
# silhouette from straight on. That angle is the one thing here that is a
# taste call, so it is a constant; everything else is measured.
#
# The camera used to be a hand-placed position and look-at target, tuned
# once against a full height stage. Both of the numbers it depended on then
# moved: the HUD is content-sized and grew every time a row was added to it,
# and the enemy count is random, so the group being framed is a different
# size every fight. This backs the camera off far enough to fit whatever is
# actually on the stage into whatever height the HUD has left.
const STAGE_CAMERA_DIR := Vector3(3.0, 2.2, 5.5)
# Breathing room around the group, and a floor on the distance so a lone
# grunt does not end up with the camera inside its head.
const STAGE_FRAMING_MARGIN := 1.08
const STAGE_MIN_DISTANCE := 3.5

func _frame_stage_camera() -> void:
	if _stage_cam == null or _stage_container == null:
		return

	# Corners rather than centres: a combatant is framed when its head and
	# its feet are both on screen, and the sideways allowance keeps an
	# outstretched staff or a wind-up from poking out of frame.
	var pts: Array = []
	for e in (party + enemies):
		if not e.has("actor") or not is_instance_valid(e.actor):
			continue
		var a := e.actor as Node3D
		if a.has_method("framing_points"):
			# Actual skinned silhouette, not rotated world-AABB empty corners.
			# Those corners shrank the entire prologue despite valid mesh bounds.
			pts.append_array(a.call("framing_points"))
			continue
		# Imported enemies can be dramatically longer than their collision
		# radius suggests (Frilled Shark is the concrete regression). When an
		# actor exposes real world-space visual bounds, frame all eight mesh
		# corners rather than synthesizing a narrow box from radius/height.
		if a.has_method("visual_bounds"):
			var visual_box := a.call("visual_bounds") as AABB
			for corner in range(8):
				pts.append(visual_box.get_endpoint(corner))
			pts.append(
				visual_box.position
				+ Vector3(visual_box.size.x * 0.5, visual_box.size.y + OVERHEAD_LIFT + OVERHEAD_HEADROOM, visual_box.size.z * 0.5)
			)
			continue
		var low: Vector3 = _bottom_of(a)
		# Not the top of the model: the top of the model plus the health
		# bar riding above it. Framing the bodies alone put every head hard
		# against the top edge and left the bars themselves off screen,
		# which is not a framing problem you can see by looking at models.
		var high: Vector3 = _top_of(a) + Vector3(0.0, OVERHEAD_LIFT + OVERHEAD_HEADROOM, 0.0)
		var measured_radius := 0.7
		var radius_value: Variant = a.get("radius")
		if radius_value != null:
			measured_radius = maxf(measured_radius, float(radius_value))
		for dx in [-measured_radius, measured_radius]:
			pts.append(low + Vector3(dx, 0.0, 0.0))
			pts.append(high + Vector3(dx, 0.0, 0.0))
	if pts.is_empty():
		return

	var centre := Vector3.ZERO
	for p in pts:
		centre += p as Vector3
	centre /= float(pts.size())
	if prologue_octopus_encounter:
		# A mesh point cloud has many more points than a diver's small box;
		# its vertex density must not drag the camera away from the party.
		var enclosing := AABB(pts[0] as Vector3, Vector3.ZERO)
		for point in pts:
			enclosing = enclosing.expand(point as Vector3)
		centre = enclosing.get_center()

	# The enclosed boss arena benefits from a more frontal authored view: less
	# sideways foreshortening keeps the compact party formation and the office
	# walls readable without changing ordinary/open-water fight framing.
	var dir: Vector3 = (Vector3(0.4, 1.8, 6.0) if boss_encounter or prologue_octopus_encounter else STAGE_CAMERA_DIR).normalized()
	# Two axes across the view, so the group can be measured in the plane
	# the camera actually sees rather than in world X and Y.
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(dir).normalized()
	if prologue_octopus_encounter:
		# The composite's corpse/tentacle actions have considerable depth.
		# Perspective fit either clips them or shrinks idle into a miniature.
		# An authored orthographic stage keeps silhouettes consistently readable
		# and contains the full sampled action envelope without camera pumping.
		var projected_low := Vector2(INF, INF)
		var projected_high := Vector2(-INF, -INF)
		var nearest_depth := 0.0
		for point in pts:
			var delta: Vector3 = (point as Vector3) - centre
			var projected := Vector2(delta.dot(right), delta.dot(up))
			projected_low = projected_low.min(projected)
			projected_high = projected_high.max(projected)
			nearest_depth = maxf(nearest_depth, delta.dot(dir))
		var view_centre := (projected_low + projected_high) * 0.5
		centre += right * view_centre.x + up * view_centre.y
		var stage_aspect := _stage_container.size.x / maxf(1.0, _stage_container.size.y)
		var envelope := projected_high - projected_low
		_stage_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_stage_cam.size = maxf(envelope.y, envelope.x / stage_aspect) * 1.10
		_stage_cam.global_position = centre + dir * (nearest_depth + 10.0)
		_stage_cam.look_at(centre, Vector3.UP)
		return

	# fov is the vertical angle (Camera3D defaults to KEEP_HEIGHT), so a
	# wide short stage is limited by its height and a narrow tall one by its
	# width.
	var box: Vector2 = _stage_container.size
	var aspect: float = maxf(0.2, box.x / maxf(1.0, box.y))
	var tan_v: float = maxf(0.01, tan(deg_to_rad(_stage_cam.fov) * 0.5))
	var tan_h: float = maxf(0.01, tan_v * aspect)

	# Solved per point rather than off the group's overall size, because the
	# party stands three metres nearer the camera than the grunts do and
	# perspective makes them correspondingly bigger. Measuring the group as
	# a flat box put the party's feet through the floor of the frame while
	# the grunts had room to spare.
	#
	# For a camera at centre + dir*d, a point p sits at depth d - w where
	# w is how far p is toward the camera, and is in frame when its sideways
	# and vertical offsets fit inside the frustum at that depth. Rearranged,
	# that is the distance below, and the group needs the largest of them.
	var dist := STAGE_MIN_DISTANCE
	for p in pts:
		var v: Vector3 = (p as Vector3) - centre
		var w: float = v.dot(dir)
		var margin := 1.02 if boss_encounter or prologue_octopus_encounter else STAGE_FRAMING_MARGIN
		var need_w: float = absf(v.dot(right)) * margin / tan_h
		var need_h: float = absf(v.dot(up)) * margin / tan_v
		dist = maxf(dist, maxf(need_w, need_h) + w)

	_stage_cam.global_position = centre + dir * dist
	_stage_cam.look_at(centre, Vector3.UP)

# Built once, hidden until the first party turn (_start_party_turn() shows
# and positions it; _do_enemy_turn() hides it) - same downward-cone shape
# and color as target_selector.gd's and world.gd's own cursors, added to
# _stage_vp so it lives in the same 3D world as the actors it's marking,
# not the CanvasLayer's UI tree.
func _build_turn_cursor() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.35
	_turn_cursor = MeshInstance3D.new()
	_turn_cursor.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.albedo_color = Color(0.35, 0.95, 0.4)
	mat.emission = Color(0.35, 0.95, 0.4)
	_turn_cursor.material_override = mat
	_turn_cursor.rotation_degrees.x = 180.0
	_turn_cursor.visible = false
	_stage_vp.add_child(_turn_cursor)

# Averages every living party member's CombatantStats into one reference
# point for Goblin.make_stats() to roll grunts against - a fresh Resource,
# not a reference to any real diver's stats, so nothing here can ever leak
# a mutation back onto a party member. Falls back to whichever party
# entries exist at all if somehow nobody's currently alive (shouldn't
# happen - world.gd never starts a battle with a wiped party - but
# _living() returning empty shouldn't be able to divide by zero here).
func _party_average_stats() -> CombatantStats:
	var living := _living(party)
	var pool: Array = living if not living.is_empty() else party
	var avg := CombatantStats.new()
	if pool.is_empty():
		return avg
	# Summed into plain ints first, not straight into avg's own fields -
	# CombatantStats.new() starts with its own non-zero defaults (hp_max
	# 20, strength 5, ...), so accumulating directly onto avg would be
	# adding every party member's stat on top of those defaults instead of
	# starting from zero.
	var n := float(pool.size())
	var sum_hp := 0
	var sum_str := 0
	var sum_def := 0
	var sum_agi := 0
	var sum_eva := 0
	var sum_acc := 0
	for entry in pool:
		var s := entry.stats as CombatantStats
		sum_hp += s.hp_max
		sum_str += s.strength
		sum_def += s.defense
		sum_agi += s.agility
		sum_eva += s.evasion
		sum_acc += s.accuracy
	avg.hp_max = int(round(float(sum_hp) / n))
	avg.strength = int(round(float(sum_str) / n))
	avg.defense = int(round(float(sum_def) / n))
	avg.agility = int(round(float(sum_agi) / n))
	avg.evasion = int(round(float(sum_eva) / n))
	avg.accuracy = int(round(float(sum_acc) / n))
	return avg

# Evenly spaces `n` actors around x=0, `step` apart - shared by the party
# row and the enemy row so both scale the same way from 1 up to 3 without
# separate hand-picked positions for each possible count.
func _spread(i: int, n: int, step: float) -> float:
	return (float(i) - float(n - 1) * 0.5) * step

func _build_ui() -> void:
	# Party's status cards stack down the left edge, enemies' down the
	# right - added before the bottom panel/queue bar just so those still
	# win in z-order if a stack ever ran long enough to reach them.
	_party_status_column = HFlowContainer.new()
	_party_status_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_party_status_column.offset_left = 12.0
	_party_status_column.offset_top = 70.0
	_party_status_column.offset_right = 12.0 + STATUS_COLUMN_WIDTH
	_party_status_column.offset_bottom = 70.0 + 320.0
	_party_status_column.add_theme_constant_override("h_separation", 8)
	_party_status_column.add_theme_constant_override("v_separation", 8)
	_party_status_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party_status_column)

	_enemy_status_column = VBoxContainer.new()
	_enemy_status_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_enemy_status_column.offset_left = -(STATUS_COLUMN_WIDTH + 12.0)
	_enemy_status_column.offset_top = 70.0
	_enemy_status_column.offset_right = -12.0
	_enemy_status_column.offset_bottom = 70.0 + 320.0
	_enemy_status_column.add_theme_constant_override("separation", 8)
	_enemy_status_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_enemy_status_column)

	_bottom_panel = PanelContainer.new()
	_bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# MODIFIED (added): same STOP-by-default bug as _stage_container above -
	# this panel spans the full width of the bottom of the screen and was
	# never given its own mouse_filter, so its background (and the log/
	# margin area around whichever menu is actually visible) swallowed any
	# click or motion landing there. During a special-encounter minigame
	# main_menu/move_menu/item_menu/target_menu are all hidden (see
	# _do_enemy_turn()) but this panel itself stays up to hold the log/
	# overhead bars, so aiming a weak spot low on screen (see
	# GrappleInterceptMinigame's grid, which spawns rocks above AND below
	# center) drifted the virtual cursor into this strip and silently ate
	# the look/click from there on - "works near the middle, stops
	# entirely once you aim down." IGNORE here doesn't disable the actual
	# buttons inside it (they keep their own default STOP filter and still
	# receive clicks normally whenever they're visible) - it only stops the
	# panel's own empty background from intercepting anything.
	_bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Opaque, and deliberately so. This used to run on Godot's default
	# PanelContainer theme, which is 60% black, and that was fine only for
	# as long as the stage was full height behind it: what it actually did
	# was leave the bottom half of every combatant showing through a grey
	# sheet. Now the stage stops above this panel, so anything translucent
	# here would show the paused overworld through it instead. The colour
	# matches the stage's own background so the two read as one screen, and
	# the top border is what tells you where the fight ends and the numbers
	# begin.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.13, 0.17)
	bg.border_width_top = 2
	bg.border_color = Color(0.18, 0.34, 0.4)
	_bottom_panel.add_theme_stylebox_override("panel", bg)

	add_child(_bottom_panel)

	var margin := MarginContainer.new()
	var compact_battle_ui := get_viewport().get_visible_rect().size.y <= 500.0
	margin.add_theme_constant_override("margin_left", 12 if compact_battle_ui else 16)
	margin.add_theme_constant_override("margin_right", 12 if compact_battle_ui else 16)
	margin.add_theme_constant_override("margin_top", 2 if compact_battle_ui else 10)
	margin.add_theme_constant_override("margin_bottom", 4 if compact_battle_ui else 16)
	# MODIFIED (added): _bottom_panel's own IGNORE (above) only ever applies
	# to _bottom_panel itself - margin and col are separate nodes that each
	# still defaulted to STOP independently, which is what was actually
	# still blocking the panel's content area regardless of the outer
	# panel's own filter. NOT recursive into col's own children though -
	# main_menu/move_menu/item_menu/target_menu live inside col and their
	# real Buttons need to stay STOP for normal turns to keep working; they
	# also happen to be hidden (visible=false) during a special-encounter
	# minigame specifically, so this is safe either way.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_panel.add_child(margin)

	# MODIFIED (added): col used to be margin's only child, filling the whole
	# row - now wrapped in content_row alongside _swap_demo_frame (built
	# below) so the first special encounter's demo clip has a fixed slot in
	# the bottom-right corner instead of overlapping the caption text.
	# size_flags_horizontal = EXPAND_FILL on col keeps it claiming the rest
	# of the row's width (its own default is SIZE_FILL, which without
	# EXPAND shrinks to content instead of sharing space with a sibling).
	# _swap_demo_frame stays hidden for every other fight, and a hidden
	# Control claims no space in a Container by default, so this changes
	# nothing about how any other fight's panel lays out.
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 12)
	content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content_row)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4 if compact_battle_ui else 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 2.0
	content_row.add_child(col)

	# The first special encounter's own demo clip of the swap minigame
	# played correctly - same loading convention as character_ability_
	# popup.gd's _refresh_media() (TutorialContent.SPECIAL_ENCOUNTER_MEDIA,
	# a still image or a looping .ogv, falling back to a "Clip coming soon"
	# placeholder), so dropping a file at SPECIAL_ENCOUNTER_MEDIA["swap"]'s
	# path is the only step needed to make this show a real clip - no code
	# changes.
	# MODIFIED (changed): was SHRINK_END (bottom-right, level with the move
	# buttons/Skip Tutorial row) - moved to SHRINK_BEGIN so it pins to the
	# TOP of content_row instead, level with the caption text right next to
	# it (col's first two rows) rather than the bottom of the whole panel.
	_swap_demo_frame = PanelContainer.new()
	_swap_demo_frame.visible = false
	_swap_demo_frame.custom_minimum_size = TutorialContent.VIDEO_FRAME_SIZE
	# Keep tutorial clips at the same fixed size as the other tutorial
	# surfaces. Expanding this child shared the battle row's spare width and
	# made its video frame wider than its 16:9 height could support.
	_swap_demo_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_swap_demo_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var demo_style := StyleBoxFlat.new()
	demo_style.bg_color = Color(0.03, 0.09, 0.12)
	demo_style.border_width_top = 1
	demo_style.border_width_bottom = 1
	demo_style.border_width_left = 1
	demo_style.border_width_right = 1
	demo_style.border_color = Color(0.18, 0.34, 0.4)
	_swap_demo_frame.add_theme_stylebox_override("panel", demo_style)
	content_row.add_child(_swap_demo_frame)

	# Turn order across the very top, in its own bar rather than as the first
	# row of the bottom panel. It is the one piece of state that is about the
	# fight as a whole rather than about any one combatant, so it is the one
	# piece that has nowhere on the stage to live.
	_queue_bar = PanelContainer.new()
	_queue_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# MODIFIED (added): same reasoning as _bottom_panel's own mouse_filter
	# fix just above - this strip spans the full width of the TOP of the
	# screen and holds no interactive controls at all (just the turn-order
	# row), so there's no children relying on it staying STOP.
	_queue_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qbg := StyleBoxFlat.new()
	# Opaque, for the same reason the bottom strip is: the stage stops below
	# this bar, so anything translucent here shows the paused overworld's own
	# HUD through it, and the controls line bleeding through the turn order
	# reads as a rendering fault.
	qbg.bg_color = Color(0.05, 0.13, 0.17)
	qbg.border_width_bottom = 2
	qbg.border_color = Color(0.18, 0.34, 0.4)
	_queue_bar.add_theme_stylebox_override("panel", qbg)
	add_child(_queue_bar)

	var qmargin := MarginContainer.new()
	qmargin.add_theme_constant_override("margin_left", 16)
	qmargin.add_theme_constant_override("margin_right", 16)
	qmargin.add_theme_constant_override("margin_top", 6)
	qmargin.add_theme_constant_override("margin_bottom", 6)
	qmargin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_queue_bar.add_child(qmargin)

	queue_row = HBoxContainer.new()
	queue_row.add_theme_constant_override("separation", 10)
	queue_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qmargin.add_child(queue_row)

	# Health and status now hang over each combatant's own head.
	# See _build_overhead_bar() and _layout_overhead_bars().
	for entry in party:
		_build_overhead_bar(entry)
	for entry in enemies:
		_build_overhead_bar(entry)

	log_label = RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, 28 if compact_battle_ui else 36)
	log_label.scroll_active = false
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(log_label)

	# A second, wrapping line above the normal one-line log - the log's
	# combat messages ("You strike for 12.") are too short-lived and terse
	# to also carry a move's attack-vs-utility explanation or the stat
	# reasoning behind a scripted hit/miss (see _apply_tutorial_move_gate()/
	# _tutorial_prep_enemy_turn()), so tutorial fights get their own caption
	# instead of fighting the log for space.
	# MODIFIED (changed): now built for every fight, not just tutorial_
	# encounter - _resolve_attack()'s real (non-tutorial) QTE warning below
	# reuses this same "Press Enter to continue" caption/gate rather than
	# inventing a second one. Starts hidden, same reasoning _levelup_caption
	# just below already uses: an empty RichTextLabel still claims a line's
	# worth of height, which would otherwise nudge every ordinary fight's HUD
	# down by a few pixels for a caption that never shows outside a tutorial
	# fight or a real QTE.
	# RichTextLabel, not Label - _tutorial_show_step() below relies on
	# BBCode ([color=yellow]highlighted[/color], the dim "press Enter"
	# hint) actually rendering instead of showing as literal text.
	_tutorial_caption = RichTextLabel.new()
	_tutorial_caption.visible = false
	_tutorial_caption.bbcode_enabled = true
	_tutorial_caption.fit_content = true
	_tutorial_caption.scroll_active = false
	_tutorial_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Plain white base text, same as a classic FF-style dialogue box -
	# [color=yellow]emphasized[/color] words (see _apply_tutorial_move_
	# gate()) need a neutral background to actually stand out against;
	# a yellow base made those words nearly invisible.
	_tutorial_caption.add_theme_color_override("default_color", Color.WHITE)
	_tutorial_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lets [pulse]...[/pulse] BBCode actually pulse instead of rendering as
	# literal bracketed text - see pulse_text_effect.gd/_tutorial_show_step().
	_tutorial_caption.install_effect(PulseTextEffect.new())
	col.add_child(_tutorial_caption)

	# Narration must not be keyboard-only. The same wait state accepts Enter
	# and this visible action; both clear one shared flag so neither path can
	# advance twice. Hidden captions release the layout space automatically.
	_tutorial_continue_btn = Button.new()
	_tutorial_continue_btn.name = "TutorialContinue"
	_tutorial_continue_btn.text = "Continue"
	_tutorial_continue_btn.custom_minimum_size = Vector2(180, 40)
	_tutorial_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tutorial_continue_btn.visible = false
	_tutorial_continue_btn.pressed.connect(_continue_tutorial_caption)
	col.add_child(_tutorial_continue_btn)

	# Unconditional, unlike _tutorial_caption above - a level-up can happen
	# after ANY win, not just the tutorial fight. RichTextLabel for the same
	# reason: _build_levelup_block()'s green "(+N)" per grown stat needs
	# BBCode to actually render as color instead of literal text. Starts
	# hidden rather than just empty-text - an empty RichTextLabel can still
	# claim a line's worth of height, which would otherwise nudge every
	# other fight's HUD by a few pixels for a table that never shows.
	_levelup_caption = RichTextLabel.new()
	_levelup_caption.visible = false
	_levelup_caption.bbcode_enabled = true
	_levelup_caption.fit_content = true
	_levelup_caption.scroll_active = false
	_levelup_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_levelup_caption.add_theme_color_override("default_color", Color.WHITE)
	_levelup_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup_caption.install_effect(PulseTextEffect.new())
	col.add_child(_levelup_caption)

	main_menu = HFlowContainer.new()
	main_menu.add_theme_constant_override("h_separation", 12)
	main_menu.add_theme_constant_override("v_separation", 8)
	col.add_child(main_menu)
	attack_btn = _menu_button("Attack", "Pick a move")
	attack_btn.pressed.connect(_show_moves)
	main_menu.add_child(attack_btn)
	run_btn = _menu_button("Run", "Might not escape")
	run_btn.pressed.connect(_on_run)
	main_menu.add_child(run_btn)
	items_btn = _menu_button("Items", "")
	items_btn.pressed.connect(_show_items)
	main_menu.add_child(items_btn)

	# Reparented into whichever of main_menu/move_menu/item_menu/target_menu
	# is currently showing, always as its last button (see
	# _place_skip_tutorial_btn_last()) - not a fixed child of any one of
	# them, since those four toggle their own .visible on and off as the
	# player navigates (_show_main()/_show_moves()/_show_items()) and Skip
	# Tutorial needs to stay reachable no matter which is up, for the whole
	# tutorial fight. Plain title, no hint - "Ends the fight and returns to
	# the world" doesn't fit this button's width without clipping, unlike
	# the short hints every other menu button carries.
	if tutorial_encounter:
		skip_tutorial_btn = _menu_button("Skip Tutorial", "")
		# Enter is the tutorial-caption continue key. Keep this optional
		# escape hatch mouse-clickable without allowing it to steal keyboard
		# focus and turn Enter into an accidental tutorial skip.
		skip_tutorial_btn.focus_mode = Control.FOCUS_NONE
		skip_tutorial_btn.pressed.connect(_on_skip_tutorial_pressed)
		_place_skip_tutorial_btn_last(main_menu)

	_selected_move_panel = PanelContainer.new()
	# MODIFIED (fixed): same missing-IGNORE bug as create_stats_panel()'s
	# own panel just above (see its comment) - this one is worse in
	# practice, since it's never hidden between turns at all (only _win()
	# ever sets it invisible), so it sits there, visible, defaulting to
	# STOP, for the entire rest of the fight after a player's very first
	# move - including through every special-encounter minigame's own
	# mouse-captured input.
	_selected_move_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_move_panel.add_theme_stylebox_override("panel", _row_stylebox(false))
	col.add_child(_selected_move_panel)
	var selected_move_row := HBoxContainer.new()
	# Small, fixed gap rather than the theme default - deliberately not
	# giving _selected_move_name a SIZE_EXPAND_FILL flag, since that would
	# stretch it to fill the whole row and shove _selected_move_power all
	# the way to the panel's far edge instead of sitting right next to the
	# name it belongs to.
	selected_move_row.add_theme_constant_override("separation", 6)
	selected_move_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_move_panel.add_child(selected_move_row)
	_selected_move_name = Label.new()
	_selected_move_name.text = ""
	_selected_move_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	selected_move_row.add_child(_selected_move_name)
	_selected_move_power = Label.new()
	_selected_move_power.text = ""
	_selected_move_power.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_selected_move_power.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	selected_move_row.add_child(_selected_move_power)

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 12)
	col.add_child(stats_row)
	_player_stats_ui = create_stats_panel("You")
	stats_row.add_child(_player_stats_ui.panel as Control)
	_enemy_stats_ui = create_stats_panel("Enemy")
	(_enemy_stats_ui.panel as Control).visible = false
	stats_row.add_child(_enemy_stats_ui.panel as Control)
	# Real numbers from the moment this panel exists, not the "0" every row
	# starts at inside create_stats_panel() - _refresh_player_stats_panel()
	# doesn't run until _start_party_turn(), which can be several real,
	# rendered frames away (enemy-goes-first plus the tutorial's own
	# _first_fight_prompt()/_tutorial_prep_enemy_turn() prompts in between),
	# so without this the panel would sit at all-zeros and visibly snap to
	# the truth once the player's turn finally comes up. party[0] rather
	# than _acting - _acting isn't set yet this early in _ready() - but
	# every fight always has at least one living party member by definition,
	# and the tutorial fight only ever has the one anyway.
	if not party.is_empty():
		_set_stats_panel_base(_player_stats_ui, party[0].stats as CombatantStats)


	move_menu = HFlowContainer.new()
	move_menu.add_theme_constant_override("h_separation", 12)
	move_menu.add_theme_constant_override("v_separation", 8)
	move_menu.visible = false
	col.add_child(move_menu)
	# Up/Down stacked into one button-sized slot so they cost a single cell
	# of the flow rather than two. Hidden unless the moves overflow.
	_move_scroll_box = VBoxContainer.new()
	_move_scroll_box.add_theme_constant_override("separation", 4)
	_move_scroll_box.visible = false
	move_menu.add_child(_move_scroll_box)
	_move_up_btn = Button.new()
	_move_up_btn.text = "▲ Up"
	_move_up_btn.custom_minimum_size = Vector2(300, 24)
	_move_up_btn.pressed.connect(_scroll_moves.bind(-1))
	_move_scroll_box.add_child(_move_up_btn)
	_move_down_btn = Button.new()
	_move_down_btn.text = "▼ Down"
	_move_down_btn.custom_minimum_size = Vector2(300, 24)
	_move_down_btn.pressed.connect(_scroll_moves.bind(1))
	_move_scroll_box.add_child(_move_down_btn)
	back_btn = _menu_button("Back", "")
	back_btn.pressed.connect(_show_main)
	move_menu.add_child(back_btn)

	item_menu = HFlowContainer.new()
	item_menu.add_theme_constant_override("h_separation", 12)
	item_menu.add_theme_constant_override("v_separation", 8)
	item_menu.visible = false
	col.add_child(item_menu)
	item_back_btn = _menu_button("Back", "")
	item_back_btn.pressed.connect(_show_main)
	item_menu.add_child(item_back_btn)

	target_menu = HFlowContainer.new()
	target_menu.add_theme_constant_override("h_separation", 12)
	target_menu.add_theme_constant_override("v_separation", 8)
	target_menu.visible = false
	col.add_child(target_menu)
	target_back_btn = _menu_button("Back", "")
	# Routes to whichever menu actually opened the target picker - a move
	# (move_menu) or an item (item_menu), based on which of _pending_move/
	# _pending_item is currently set. See _show_moves_or_items_from_target_
	# menu() below; this used to be hardwired to _show_moves_from_target_
	# menu() alone, which would send an item's Back to the wrong menu.
	target_back_btn.pressed.connect(_show_moves_or_items_from_target_menu)
	target_menu.add_child(target_back_btn)

	call_deferred("_fit_panel_height")

# The bug this exists to fix: _bottom_panel used to have a single
# hand-guessed fixed height (300px). Godot Containers skip invisible
# children when computing minimum size, so the panel's actual required
# height changes depending on which of main_menu/move_menu/target_menu is
# currently showing (and, since those are HFlowContainers now, on how many
# rows a big move list wraps to) - a fixed number was always going to be
# wrong for some state eventually. Every call site uses
# call_deferred("_fit_panel_height") rather than calling this directly -
# get_combined_minimum_size() needs Godot's own container re-sort to have
# already run for a just-changed visible/child set, and that re-sort is
# queued for later in the frame rather than happening synchronously the
# instant a property changes, so reading it immediately after flipping
# .visible can still return the previous, stale size.
func _fit_panel_height() -> void:
	_bottom_panel.offset_bottom = 0.0
	_bottom_panel.offset_top = -(_bottom_panel.get_combined_minimum_size().y + 12.0)
	_fit_party_status_cards_above_panel()
	# Hand the rest of the screen to the stage. Both are anchored to the
	# bottom edge, so the panel's own top offset is exactly where the stage
	# has to stop. This is what makes the HUD's height self-correcting: a
	# row added to it now shrinks the fight instead of covering it, which is
	# visible immediately rather than three PRs later.
	if _stage_container != null:
		_stage_container.offset_bottom = _bottom_panel.offset_top
		# And below the turn bar at the top, for the same reason: anything
		# rendered under an opaque bar is rendered where nobody can see it.
		# The stage is now strictly the band between the two.
		_stage_container.offset_top = _queue_bar.size.y if _queue_bar != null else 0.0

# Party cards normally form the familiar left-side stack. A long tutorial
# explanation can legitimately make the opaque bottom panel taller, though,
# and at the browser review viewport that panel used to cover Bucky's HP/O2/
# EVA rows while leaving only his name visible. Widen the party flow only for
# those constrained states. Its right edge stops before the fixed enemy column,
# so the cards can wrap horizontally without colliding with enemy information.
#
# This derives the would-be vertical stack height from each card's public
# minimum size rather than its current position: Godot defers HFlow sorting, so
# current card positions may still describe the previous caption for one frame.
func _fit_party_status_cards_above_panel() -> void:
	if _party_status_column == null or _bottom_panel == null:
		return
	var vertical_height := 0.0
	var visible_cards := 0
	for child in _party_status_column.get_children():
		if child is Control and (child as Control).visible:
			vertical_height += (child as Control).get_combined_minimum_size().y
			visible_cards += 1
	if visible_cards > 1:
		vertical_height += float(visible_cards - 1) * 8.0
	var panel_top := get_viewport().get_visible_rect().size.y + _bottom_panel.offset_top
	var normal_right := 12.0 + STATUS_COLUMN_WIDTH
	var expanded_right := maxf(normal_right, get_viewport().get_visible_rect().size.x - STATUS_COLUMN_WIDTH - 24.0)
	_party_status_column.offset_right = expanded_right if _party_status_column.offset_top + vertical_height > panel_top else normal_right

# Name plus a one-line tradeoff, right on the button: the choice needs to
# read before it's clicked, not just get explained after in the log.
func _menu_button(title: String, hint: String) -> Button:
	# TooltipButton, not a plain Button - see its own header comment. Applied
	# to every menu button uniformly rather than only the ones that happen to
	# set tooltip_text, since Godot never shows a tooltip at all for a button
	# whose tooltip_text is empty regardless of this override.
	var b := TooltipButton.new()
	b.text = title if hint == "" else "%s\n%s" % [title, hint]
	# Four 300px choices plus their gaps fit in the 1248px-wide content area
	# at the evidence/playtest resolution. The previous 210px width packed five
	# across but visibly cut off both move names and result/formula summaries.
	# Three primary actions must stay on one row at the supported 720px review
	# width. At wide resolutions retain the larger formula-friendly buttons;
	# on narrow screens, 205px still fits two text lines while preventing the
	# extra wrapped row that used to collapse the 3D stage to 123px.
	var viewport_width := get_viewport().get_visible_rect().size.x
	b.custom_minimum_size = Vector2(205 if viewport_width < 900.0 else 300, 52)
	b.clip_text = true
	return b

# Moves skip_tutorial_btn (a single shared instance, not one per menu) so it
# always sits as the last button on whichever of main_menu/move_menu/
# item_menu/target_menu is currently visible - called at the end of every
# place those menus populate/reorder their own Back button
# (_populate_move_menu(), _populate_item_menu(), the two target-menu
# populate functions) plus _show_main()/_start_party_turn(). A Control can
# only have one parent, so this reparents rather than duplicating the
# button four times over with four copies of its enabled/disabled state to
# keep in sync. No-op outside the tutorial fight, where skip_tutorial_btn
# is never built at all.
func _place_skip_tutorial_btn_last(menu: Container) -> void:
	if skip_tutorial_btn == null:
		return
	if skip_tutorial_btn.get_parent() != menu:
		if skip_tutorial_btn.get_parent() != null:
			skip_tutorial_btn.get_parent().remove_child(skip_tutorial_btn)
		menu.add_child(skip_tutorial_btn)
	menu.move_child(skip_tutorial_btn, menu.get_child_count() - 1)

# X-glyph panel (what to press) beside a track (when to press it), laid out
# by an HBoxContainer so "button then gauge" is just child order, not a
# hand-picked offset. Centered on screen, hidden until a QTE actually
# starts - see _quick_time_event().
func _build_quick_time_ui() -> void:
	qte_root = HBoxContainer.new()
	# TOP_LEFT, not CENTER - _quick_time_event() now positions this itself
	# every time, over whichever combatant is actually dodging (see
	# _project_to_screen()), so its anchor just needs to leave `position`
	# meaning "top-left corner, in this CanvasLayer's own pixel space"
	# rather than fighting a center-anchor's own offset math.
	qte_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	qte_root.add_theme_constant_override("separation", 14)
	qte_root.visible = false
	add_child(qte_root)

	# MODIFIED: panel/glyph both scaled up 25% (34->42.5, 17->21.25 radius,
	# font 18->23) to match QTE_TRACK_WIDTH/HEIGHT's own 25% increase -
	# the button and the track are meant to read as one popup, not a
	# bigger track next to an unchanged button.
	var button_panel := Panel.new()
	button_panel.custom_minimum_size = Vector2(42.5, 42.5)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.75, 0.2)
	style.set_corner_radius_all(21)
	button_panel.add_theme_stylebox_override("panel", style)
	qte_root.add_child(button_panel)

	var glyph := Label.new()
	glyph.text = "X"
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 23)
	glyph.add_theme_color_override("font_color", Color(0.12, 0.09, 0.02))
	button_panel.add_child(glyph)

	qte_track = Control.new()
	qte_track.custom_minimum_size = Vector2(QTE_TRACK_WIDTH, QTE_TRACK_HEIGHT)
	qte_root.add_child(qte_track)

	var track_bg := ColorRect.new()
	track_bg.color = Color(0.15, 0.18, 0.2)
	track_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	qte_track.add_child(track_bg)

	# Position/size get set fresh every _quick_time_event() call (the zone
	# moves and resizes per attack) - these are just placeholders until then.
	qte_zone = ColorRect.new()
	qte_zone.color = Color(0.85, 0.2, 0.2)
	qte_zone.size = Vector2(30, QTE_TRACK_HEIGHT)
	qte_track.add_child(qte_zone)

	qte_indicator = ColorRect.new()
	qte_indicator.color = Color(0.95, 0.95, 0.9)
	qte_indicator.size = Vector2(3.75, QTE_TRACK_HEIGHT)
	qte_track.add_child(qte_indicator)

# Races a keypress against the sweep reaching the end of the track - both
# sides now read the same pixel-space state the player can actually see
# (qte_zone's/qte_indicator's own position/size), nothing measured in
# seconds. _unhandled_input() is the keypress side (checks where the
# indicator visually is against the zone rect the instant X is pressed);
# tw.finished (below) is the timeout side, for a press that never came at
# all. The while loop just waits for whichever one flips _qte_active off,
# once per frame via `await get_tree().process_frame`.
func _quick_time_event(target_actor: Node3D = null) -> bool:
	var duration := 1.6
	var zone_width_frac := randf_range(0.06, 0.12)
	# Margin on both ends so the zone never touches the very start (an
	# instant, no-real-choice press) or the very end (indistinguishable
	# from a timeout) of the sweep.
	var zone_start_frac := randf_range(0.15, 1.0 - zone_width_frac - 0.15)

	qte_zone.position.x = zone_start_frac * QTE_TRACK_WIDTH
	qte_zone.size.x = zone_width_frac * QTE_TRACK_WIDTH
	qte_indicator.position.x = 0.0

	# Over the head of whoever's actually dodging, not a fixed screen spot -
	# `target_actor` is null only for a standalone/headless Battle (see
	# tools/test_battle.gd), where there's no stage to project onto anyway,
	# so the fallback (wherever qte_root's anchor/position last left it) is
	# never actually seen by a player.
	if target_actor != null and is_instance_valid(target_actor):
		var above: Vector3 = _top_of(target_actor) + Vector3(0.0, OVERHEAD_LIFT + OVERHEAD_HEADROOM, 0.0)
		var at := _project_to_screen(above)
		qte_root.position = at - qte_root.size * 0.5

	qte_root.visible = true
	_qte_active = true
	_qte_success = false

	var tw := create_tween()
	tw.tween_property(qte_indicator, "position:x", QTE_TRACK_WIDTH - qte_indicator.size.x, duration)
	tw.finished.connect(_on_qte_timeout)

	while _qte_active:
		await get_tree().process_frame

	if tw.finished.is_connected(_on_qte_timeout):
		tw.finished.disconnect(_on_qte_timeout)
	tw.kill()
	qte_root.visible = false
	return _qte_success

# tw.finished only ever means "the sweep reached the end with nobody
# pressing anything" - a press that resolves the QTE early kills the tween
# (see _quick_time_event()'s loop exit) via kill(), which does not emit
# finished, so there's no risk of this overwriting an already-decided
# result. The `if _qte_active` guard is still here defensively, same
# spirit as _unhandled_input()'s own guard below.
func _on_qte_timeout() -> void:
	if _qte_active:
		_qte_success = false
		_qte_active = false

# Shows one tutorial caption and blocks until the player actually presses
# Enter - every scripted-fight caption reaching this is pure narration
# (turn order, why a stat just flashed red/green, the damage math, HP/
# oxygen) explaining something already sitting still on screen, so nothing
# is lost by making the player confirm they've read it before it clears.
# The moments that instead block on a real action the player has to take
# (hover over the enemy, click the flashing move/enemy) wait on that real
# signal directly rather than routing through here - see _explain_dodging()/
# _explain_precise_tap()'s mouse_entered await and _explain_click_to_attack()'s
# pressed await.
#
# `on_layout_ready`, if given, runs after the new (possibly taller/shorter)
# caption text has actually resized _bottom_panel via _fit_panel_height(),
# not before - _explain_dodging() uses this to position the ACC/EVA
# highlight boxes. Positioning them before this text swap would box
# wherever the stat rows sat under the OLD caption's height; the new
# caption changing panel height shifts everything in _bottom_panel (the
# stat rows included, since anchoring is bottom-up) to a different spot
# immediately after, leaving the boxes stranded at the stale position.
func _tutorial_show_step(text: String, on_layout_ready: Callable = Callable()) -> void:
	# Only ever starts hidden outside a tutorial fight (see _build_ui()) -
	# a real (non-tutorial) call, like the QTE warning in _resolve_attack(),
	# needs this explicit show; a tutorial fight's own first call is a no-op
	# here since it's already visible from the previous one.
	_tutorial_caption.visible = true
	# [pulse] (see pulse_text_effect.gd, installed on _tutorial_caption in
	# _build_ui()) keeps this flashing right where it sits in the text flow -
	# at the end of whatever the caption's last line is, wrapping onto its
	# own line only if it doesn't fit, the same as any other run of text.
	# [font_size=22] against the caption's own default (~16) is what makes
	# it read as its own callout rather than more body text to skim past.
	_tutorial_caption.text = "%s\n[font_size=18][pulse]Press Space, Enter, or click Continue[/pulse][/font_size]" % text
	_tutorial_continue_btn.visible = true
	call_deferred("_fit_panel_height")
	await get_tree().process_frame
	if on_layout_ready.is_valid():
		on_layout_ready.call()
	_tutorial_awaiting_enter = true
	while _tutorial_awaiting_enter and not _skip_tutorial_requested:
		await get_tree().process_frame
	_tutorial_continue_btn.visible = false
	# Skip Tutorial can be used during the special encounter's opening
	# captions. Its handler releases this wait and sets _busy; don't let the
	# interrupted narration start another caption afterward.
	if _skip_tutorial_requested:
		return

func _continue_tutorial_caption() -> void:
	if _tutorial_awaiting_enter:
		_tutorial_awaiting_enter = false


# Two independent gates share this one entry point, each guarded by its own
# flag so a press meant for one can't be misread as resolving the other:
# Space/Enter/Numpad Enter dismisses a narration caption while _tutorial_awaiting_
# enter is true (see _tutorial_show_step()), X resolves a QTE while
# _qte_active is true (see below). Neither is ever true at the same moment
# in practice (a QTE never runs while a caption's up), but checking each
# flag independently rather than an if/elif on one shared state keeps that
# an implementation detail instead of a hard requirement.
func _unhandled_input(event: InputEvent) -> void:
	if _tutorial_awaiting_enter and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_tutorial_awaiting_enter = false
		return
	# Only ever looked at while _qte_active is true (see _quick_time_event()) -
	# a stray X press between fights, or one arriving the same frame the sweep
	# already timed out, does nothing. The hit check compares the indicator's
	# actual current position (wherever the tween has it as of the last
	# processed frame - Godot handles input before advancing tweens within a
	# frame, so this is accurate to well under a frame's worth of time, far
	# tighter than human reaction time) against the zone ColorRect's own
	# position/size - the same rect drawn on screen, not a parallel copy of it.
	if not _qte_active:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_X:
		var indicator_center: float = qte_indicator.position.x + qte_indicator.size.x * 0.5
		var zone_left: float = qte_zone.position.x
		var zone_right: float = qte_zone.position.x + qte_zone.size.x
		_qte_success = indicator_center >= zone_left and indicator_center <= zone_right
		_qte_active = false


# One combatant's health and status, floating over their head.
#
# A Control laid out in screen space rather than a Label3D in the stage,
# because these have to stay legible: a Label3D shrinks with distance, and
# the grunts stand three metres further back than the party. The projection
# happens every frame in _layout_overhead_bars().
# MODIFIED (added): mouse_filter = IGNORE on a container only ever
# affects that ONE node - it does not cascade to children, which each
# default to STOP independently. Setting it on `box` alone (as the single
# line below already did) left every child inside it - name_label,
# bar_row, the HP ProgressBar, hp_label, status_label - still
# individually eating clicks/motion in their own little rects. Since
# these hang directly over each combatant (including the enemy launching
# a special encounter, usually front and center), that's exactly where a
# player would be aiming - the same STOP-by-default bug already found and
# fixed on _stage_container/_bottom_panel/_queue_bar/$HUD's own elements,
# just one level deeper (a container's non-button CHILDREN, not the
# container itself) and easy to miss for exactly that reason.
static func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)

func _build_overhead_bar(entry: Dictionary) -> void:
	# Wrapped in its own PanelContainer (transparent by default, same
	# _row_stylebox() pattern the stat rows use) so _explain_other_stats()
	# can box a whole card with _set_row_highlight() instead of needing a
	# separately-positioned overlay - see _party_status_column's own header
	# comment on why that's no longer necessary now the cards don't move.
	var card := PanelContainer.new()
	# Same missing-IGNORE bug as create_stats_panel()'s/_selected_move_
	# panel's own panels - a read-only status card, visible for the whole
	# fight including every special-encounter minigame, with no interactive
	# children of its own (box already sets IGNORE below) that still
	# defaulted to STOP.
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _row_stylebox(false))
	if String(entry.kind) == "party":
		_party_status_column.add_child(card)
	else:
		_enemy_status_column.add_child(card)

	var box := VBoxContainer.new()
	# Labels now sit beside their corresponding bars, so each card stays
	# compact enough for all three divers to remain above the dynamic HUD at
	# 1280x720. Four pixels still clears the outlined text between rows.
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var name_label := Label.new()
	name_label.text = String(entry.display_name)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_label.add_theme_constant_override("outline_size", 5)
	box.add_child(name_label)

	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_row.add_theme_constant_override("separation", 3)
	box.add_child(bar_row)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(OVERHEAD_BAR_WIDTH, 10)
	bar.show_percentage = false
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.78, 0.15, 0.15)
	bar.add_theme_stylebox_override("fill", hp_fill)
	var hp_track := StyleBoxFlat.new()
	hp_track.bg_color = Color(0.03, 0.06, 0.08, 0.85)
	hp_track.border_width_left = 1
	hp_track.border_width_right = 1
	hp_track.border_width_top = 1
	hp_track.border_width_bottom = 1
	hp_track.border_color = Color(0, 0, 0, 0.8)
	bar.add_theme_stylebox_override("background", hp_track)
	bar_row.add_child(bar)

	# Hidden until _win()'s post-victory regroup actually restores something -
	# _show_heal_overlay() positions/sizes this to span exactly the gap
	# between whatever HP a diver had before that restore and whatever they
	# have after, in green, rather than the bar just silently jumping to a
	# new number. Manual position/size (not anchors) since that gap is a
	# fraction of OVERHEAD_BAR_WIDTH computed fresh each time, not a fixed
	# rect - a plain child Control's default top-left anchor treats those
	# as exact pixel coordinates, which is exactly what's wanted here.
	var hp_heal_overlay := ColorRect.new()
	hp_heal_overlay.color = Color(0.35, 0.95, 0.4, 0.9)
	hp_heal_overlay.size.y = 10
	hp_heal_overlay.visible = false
	hp_heal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hp_heal_overlay)

	var hp_label := Label.new()
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", OVERHEAD_VALUE_FONT_SIZE)
	hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_label.add_theme_constant_override("outline_size", 5)
	bar_row.add_child(hp_label)

	# Oxygen only ever matters for the party's own divers (only their
	# abilities/sonar spend it - see diver.gd's oxygen spend, world.gd's
	# _build_oxygen_bar() header comment) - a grunt has the stat on its
	# CombatantStats like anyone else, but no move of its own ever reads
	# it, so giving it a bar here would just be clutter with nothing to show.
	var oxygen_bar: ProgressBar
	var oxygen_label: Label
	var oxygen_heal_overlay: ColorRect
	if String(entry.kind) == "party":
		var o2_row := HBoxContainer.new()
		o2_row.alignment = BoxContainer.ALIGNMENT_CENTER
		o2_row.add_theme_constant_override("separation", 3)
		box.add_child(o2_row)

		oxygen_bar = ProgressBar.new()
		oxygen_bar.custom_minimum_size = Vector2(OVERHEAD_BAR_WIDTH, 8)
		oxygen_bar.show_percentage = false
		var o2_fill := StyleBoxFlat.new()
		# Same blue used for the overworld oxygen bar (world.gd's
		# _build_oxygen_bar()) - one color means "oxygen" everywhere.
		o2_fill.bg_color = Color(0.25, 0.65, 0.85)
		oxygen_bar.add_theme_stylebox_override("fill", o2_fill)
		var o2_track := StyleBoxFlat.new()
		o2_track.bg_color = Color(0.03, 0.06, 0.08, 0.85)
		o2_track.border_width_left = 1
		o2_track.border_width_right = 1
		o2_track.border_width_top = 1
		o2_track.border_width_bottom = 1
		o2_track.border_color = Color(0, 0, 0, 0.8)
		oxygen_bar.add_theme_stylebox_override("background", o2_track)
		o2_row.add_child(oxygen_bar)

		# Same idea as hp_heal_overlay above, just for the Oxygen bar - see
		# _show_heal_overlay().
		oxygen_heal_overlay = ColorRect.new()
		oxygen_heal_overlay.color = Color(0.35, 0.95, 0.4, 0.9)
		oxygen_heal_overlay.size.y = 8
		oxygen_heal_overlay.visible = false
		oxygen_heal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		oxygen_bar.add_child(oxygen_heal_overlay)

		oxygen_label = Label.new()
		oxygen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		oxygen_label.add_theme_font_size_override("font_size", OVERHEAD_VALUE_FONT_SIZE)
		oxygen_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		oxygen_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		oxygen_label.add_theme_constant_override("outline_size", 5)
		o2_row.add_child(oxygen_label)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	status_label.add_theme_constant_override("outline_size", 5)
	box.add_child(status_label)

	entry["name_label"] = name_label
	entry["hp_bar"] = bar
	entry["hp_label"] = hp_label
	entry["hp_heal_overlay"] = hp_heal_overlay
	if oxygen_bar != null:
		entry["oxygen_bar"] = oxygen_bar
		entry["oxygen_label"] = oxygen_label
		entry["oxygen_heal_overlay"] = oxygen_heal_overlay
	entry["status_label"] = status_label
	entry["overhead"] = box
	entry["card"] = card
	_ignore_mouse_recursive(card)

func _refresh_all_bars() -> void:
	for e in party:
		_refresh_bar(e)
	for e in enemies:
		_refresh_bar(e)

func _refresh_bar(entry: Dictionary) -> void:
	if not entry.has("hp_bar"):
		return
	var s := entry.stats as CombatantStats
	(entry.hp_bar as ProgressBar).max_value = s.hp_max
	(entry.hp_bar as ProgressBar).value = s.hp
	var txt := "%d / %d" % [s.hp, s.hp_max]
	if String(entry.kind) == "party":
		txt += "   Lv %d" % s.level
	(entry.hp_label as Label).text = txt
	if entry.has("oxygen_bar"):
		(entry.oxygen_bar as ProgressBar).max_value = s.oxygen_max
		(entry.oxygen_bar as ProgressBar).value = s.oxygen
		(entry.oxygen_label as Label).text = "%d / %d O2" % [int(s.oxygen), int(s.oxygen_max)]
	var status_text := s.status_summary()
	if String(entry.kind) == "party":
		status_text = "EVA %d/%d%s" % [
			s.evasion_current, s.effective_evasion(),
			"   " + status_text if status_text != "" else "",
		]
	(entry.status_label as Label).text = status_text
	(entry.status_label as Label).visible = status_text != ""
	# A killing blow starts the actor's own death/fade animation on the
	# stage - its status card shouldn't outlive that, or survive as a
	# lingering "0/X" card in the side column. Replaces the same check
	# _layout_overhead_bars() used to make every frame; a card only ever
	# needs re-hiding right when the HP that changed it gets refreshed.
	if entry.has("card"):
		(entry.card as Control).visible = s.hp > 0

# Positions/sizes one heal overlay (hp_heal_overlay or oxygen_heal_overlay,
# both built in _build_overhead_bar()) to span exactly the [before, after]
# gap on its bar, as a fraction of OVERHEAD_BAR_WIDTH - a visible "this much
# came back" rather than the bar just silently jumping to a new number on
# the next _refresh_bar(). Hides the overlay instead of drawing a
# zero-width one when nothing actually grew (dead weight nobody restored,
# or already at max), same "no delta shown" rule _apply_stat_delta() uses
# for the in-fight stats panel.
func _show_heal_overlay(overlay: ColorRect, before: float, after: float, max_value: float) -> void:
	if max_value <= 0.0 or after <= before:
		overlay.visible = false
		return
	overlay.position.x = (before / max_value) * OVERHEAD_BAR_WIDTH
	overlay.size.x = ((after - before) / max_value) * OVERHEAD_BAR_WIDTH
	overlay.visible = true

func _log(text: String) -> void:
	log_label.clear()
	log_label.add_text(text)

func _audio_call(method: StringName, args: Array = []) -> void:
	var owner := get_node_or_null("/root/GameAudio")
	if owner != null and owner.has_method(method):
		owner.callv(method, args)

func _move_is_heavy(move: Dictionary) -> bool:
	var power := int(move.get("power", 0))
	var move_name := String(move.get("name", "")).to_lower()
	return power >= 10 or move_name.contains("heavy") or move_name.contains("crushing") \
		or move_name.contains("great") or move_name.contains("spinning")

func _current_log_text() -> String:
	return log_label.get_parsed_text()

func _log_grapple_wave(safe_is_yellow: bool, wave_index: int, total_waves: int) -> void:
	log_label.clear()
	log_label.add_text("Wave %d/%d: grapple " % [wave_index, total_waves])
	log_label.push_color(Color(1.0, 0.9, 0.15) if safe_is_yellow else Color(0.15, 0.95, 0.35))
	log_label.add_text("YELLOW" if safe_is_yellow else "GREEN")
	log_label.pop()
	log_label.add_text(", avoid ")
	log_label.push_color(Color(0.15, 0.95, 0.35) if safe_is_yellow else Color(1.0, 0.9, 0.15))
	log_label.add_text("GREEN" if safe_is_yellow else "YELLOW")
	log_label.pop()
	log_label.add_text(".")

# A combat result belongs on the combatant it happened to, not only in the
# fast-moving sentence at the bottom of the screen. Label3D keeps the proof
# next to the model inside Battle's isolated viewport.
func _show_combat_feedback(entry: Dictionary, result: Dictionary, play_sound: bool = true) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	var messages: Array[Dictionary] = []
	var result_kind := String(result.get("debuff", ""))
	# Keep audio attached to the same resolved result that owns floating text.
	# Heals/revives are not impacts; misses, QTE dodges, and landed damage each
	# have a distinct cue. A fifth-of-max-HP hit mirrors _react()'s existing
	# heavy-reaction threshold, so the stronger sound has mechanical meaning.
	if play_sound and result_kind not in ["heal", "revive"]:
		var hit := bool(result.get("hit", false))
		var dodged := bool(result.get("dodged", false))
		var damage := int(result.get("damage", 0))
		if not hit or dodged or damage > 0:
			var max_hp := 0
			if entry.has("stats") and entry.stats is CombatantStats:
				max_hp = (entry.stats as CombatantStats).hp_max
			_audio_call(&"play_combat_result", [hit, dodged, max_hp > 0 and damage >= int(ceil(float(max_hp) * 0.2))])
	if result_kind == "heal" or result_kind == "revive":
		messages.append({"text": "+%d HP" % int(result.get("changed", 0)), "color": FEEDBACK_EFFECT_COLOR})
	elif result_kind != "":
		messages.append({"text": "%s -%d" % [result_kind.to_upper(), int(result.get("changed", 0))], "color": FEEDBACK_NEGATIVE_COLOR})
	elif not bool(result.get("hit", false)) or bool(result.get("dodged", false)):
		messages.append({"text": "DODGE", "color": FEEDBACK_EFFECT_COLOR})
	elif int(result.get("damage", 0)) > 0:
		messages.append({"text": "-%d" % int(result.damage), "color": FEEDBACK_DAMAGE_COLOR})
	elif (result.get("effects", []) as Array).is_empty():
		messages.append({"text": "ABSORBED", "color": FEEDBACK_EFFECT_COLOR})
	var effects := result.get("effects", []) as Array
	for effect in effects:
		messages.append({"text": String(effect), "color": FEEDBACK_NEGATIVE_COLOR})
	for index in range(messages.size()):
		var message := messages[index] as Dictionary
		_show_floating_text(entry, String(message.text), message.color as Color, index)

func _show_floating_text(entry: Dictionary, text: String, color: Color, stack_index: int = 0) -> void:
	var actor := entry.actor as Node3D
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 42
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = _top_of(actor) - actor.global_position + actor.position + Vector3(0.0, 0.35 + float(stack_index) * 0.32, 0.0)
	_stage_vp.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.65, 1.1)
	tween.tween_property(label, "modulate:a", 0.0, 1.1)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _finish_actor_turn(entry: Dictionary) -> void:
	var tick := (entry.stats as CombatantStats).end_turn()
	var bleed_damage := int(tick.get("bleed_damage", 0))
	if bleed_damage > 0:
		_show_floating_text(entry, "BLEED -%d" % bleed_damage, Color(0.9, 0.12, 0.2))
		_log("%s  •  %s bleeds for %d." % [_current_log_text(), String(entry.display_name), bleed_damage])
	var poison_damage := int(tick.get("poison_damage", 0))
	if poison_damage > 0:
		_show_floating_text(entry, "POISON -%d" % poison_damage, Color(0.55, 0.9, 0.28))
		_log("%s  •  %s takes %d poison damage." % [_current_log_text(), String(entry.display_name), poison_damage])
	_refresh_bar(entry)
	if (entry.stats as CombatantStats).hp <= 0 and entry.has("actor") and is_instance_valid(entry.actor):
		if entry.actor is Diver:
			(entry.actor as Diver).play_death_fade()
		elif String(entry.kind) == "enemy":
			_play_enemy_death(entry)

func _living(list: Array) -> Array:
	return list.filter(func(e: Dictionary) -> bool: return (e.stats as CombatantStats).hp > 0)

# One sort, shared by the initial build and every later re-sort - highest
# agility first. GDScript's sort_custom isn't guaranteed stable, so ties
# can shuffle relative to each other; nothing here depends on tie order
# staying fixed.
func _by_agility(a: Dictionary, b: Dictionary) -> bool:
	return (a.stats as CombatantStats).effective_agility() > (b.stats as CombatantStats).effective_agility()

# Called whenever the queue empties (a full round has acted) - gathers
# every still-living combatant fresh and sorts by their CURRENT agility,
# so any debuff/buff applied last round is already reflected in this
# round's order without any special-casing.
func _rebuild_queue() -> void:
	_queue = _living(party) + _living(enemies)
	_queue.sort_custom(_by_agility)
	_refresh_queue_row()

# Called the instant a landed move changes someone's agility mid-round -
# only reorders _queue itself, which by construction only ever holds
# combatants still waiting to act (whoever already acted this round was
# already popped off), so this can never let someone go twice.
func _resort_pending() -> void:
	_queue.sort_custom(_by_agility)
	_refresh_queue_row()

func _refresh_queue_row() -> void:
	for c in queue_row.get_children():
		c.queue_free()
	# _acting is whoever's turn it actually is right now - already popped
	# off _queue by the time this runs (see _advance_turn()), so it's never
	# one of the cards _build_queue_chip() below would render. Its own
	# "NOW" card goes first and reads as a different tier entirely (gold
	# border, biggest text) rather than just another "next" card, since
	# "happening right now" and "coming up" are genuinely different things
	# to know at a glance mid-fight.
	if not _acting.is_empty():
		queue_row.add_child(_build_acting_chip(_acting))
	var header := Label.new()
	header.text = "Next"
	header.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	header.add_theme_font_size_override("font_size", 13)
	queue_row.add_child(header)
	# Capped rather than one chip per living combatant - _queue is bounded
	# low today (3 divers + up to MAX_ENEMIES grunts), but the row itself
	# shouldn't silently need a redesign the moment a fight ever gets
	# bigger than that.
	for i in range(mini(_queue.size(), MAX_QUEUE_SLOTS)):
		queue_row.add_child(_build_queue_chip(_queue[i], i))
	# MODIFIED (added): rebuilt fresh every turn, so a one-time IGNORE at
	# setup can't reach chips that don't exist yet - nothing in the turn
	# queue is ever meant to be clickable, so sweeping the whole row after
	# every rebuild is safe (see _ignore_mouse_recursive()'s own comment).
	_ignore_mouse_recursive(queue_row)

# The single spotlight card for whoever's turn it is right now - gold
# border regardless of party/enemy side, so "this is happening" reads as
# its own tier rather than competing with _build_queue_chip()'s "how soon"
# sizing/fading scheme below.
func _build_acting_chip(entry: Dictionary) -> Control:
	var is_enemy := String(entry.kind) == "enemy"
	var base_color := Color(0.55, 0.2, 0.22) if is_enemy else Color(0.22, 0.42, 0.58)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(7)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.set_border_width_all(3)
	style.border_color = Color(0.95, 0.85, 0.35)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)

	var tag := Label.new()
	tag.text = "NOW"
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	box.add_child(tag)

	var label := Label.new()
	label.text = String(entry.display_name)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	box.add_child(label)

	return panel

# A shrinking, fading run of cards instead of a flat list of names - the
# next-to-act entry (index 0) is the full-size, full-opacity, bright-bordered
# "spotlight" card; everyone behind it gets a little smaller and dimmer per
# step back, so the row reads as "how soon," not just "who," at a glance -
# the same visual language a Final Fantasy-style ATB rail uses, just laid
# out horizontally here instead of a vertical strip. Party cards and enemy
# cards get their own color family so the row also reads "whose side" on
# sight, matching the blue-ish O2 bar / red-ish HP bar split already used
# elsewhere in this HUD.
func _build_queue_chip(entry: Dictionary, index: int) -> Control:
	var is_enemy := String(entry.kind) == "enemy"
	var base_color := Color(0.5, 0.18, 0.2) if is_enemy else Color(0.2, 0.4, 0.56)
	var glow_color := Color(0.85, 0.3, 0.3) if is_enemy else Color(0.4, 0.85, 0.95)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	if index == 0:
		style.set_border_width_all(2)
		style.border_color = glow_color
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = String(entry.display_name)
	label.add_theme_font_size_override("font_size", 15 if index == 0 else 12)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if index == 0 else Color(0.8, 0.82, 0.85))
	panel.add_child(label)

	# Falls off toward the back of the line, clamped so nothing several
	# turns out goes fully invisible - still legible, just visibly "later."
	panel.modulate.a = maxf(0.4, 1.0 - float(index) * 0.22)
	return panel

# The dispatcher between rounds/turns: checks for a battle-ending wipe on
# either side first (before whoever's "next in line" on a side that no
# longer exists gets a phantom turn), rebuilds the queue if the round just
# ended, then hands off to the enemy-AI path or the player-menu path
# depending on who's up.
func _advance_turn() -> void:
	# The lesson's scripted portion is complete only after every scripted move
	# AND the enemy's QTE-teaching turn have happened. That's the moment to
	# hand the fight over for real: a "Defeat the enemy!" prompt explaining
	# both ways this can go (regardless of which one actually happens - the
	# outcome isn't known yet), then falls straight through to the normal
	# living-enemies/living-party checks below instead of declaring a win on
	# the spot. `_tutorial_finale_shown` keeps this one-shot if an async turn
	# callback resumes after the signal.
	if tutorial_encounter and not _tutorial_finale_shown and _tutorial_step >= _TUTORIAL_SCRIPT.size() and _tutorial_enemy_turns >= 1:
		_tutorial_finale_shown = true
		_set_all_buttons(false)
		await _tutorial_show_step("Now defeat the enemy for real to finish the lesson! Winning a battle awards XP to your whole party, not just whoever fought including anyone who went down during the fight, who gains XP the same as everyone else. Gain enough XP and a diver levels up, which refills their HP and Oxygen even if they went down. Otherwise a downed diver needs a Revive spell to get back on their feet. Leveling up doesn't change your combat stats - instead, you earn Spell Points, which can be used to gain new abilities by defeating enemies in battles. More on Spell Points and spell trees later.")
		await _tutorial_show_step("Winning won't grant any XP or rewards in this case but makes for good practice. There's no real risk in fighting this one out - a loss just sends the party back to the overworld to regroup, fully healed.")
	# The first special encounter's own version of the block just above -
	# fires once all three divers' own teaching turns (Maxilani, Musashi,
	# Bucky - see _swap_tutorial_special_diver()) have each actually played
	# their real minigame, explaining the stakes now that the player has
	# seen every mechanic rather than before any of them.
	if special_encounter and tutorial_encounter and not _special_tutorial_finale_shown and _tutorial_enemy_turns >= 3:
		_special_tutorial_finale_shown = true
		_set_all_buttons(false)
		# MODIFIED (changed): the "just for practice, no reward" framing
		# moved to _first_fight_prompt()'s own "In this case, Maxilani will
		# attack first." caption instead - the player hears that before
		# swinging, not after. This keeps just the reward-mechanic/loss
		# explanation, better taught now that they've actually seen a
		# special encounter play out.
		# MODIFIED (added): the reminder that THIS fight specifically won't
		# reward anything used to only show as an orange banner after the
		# win (world.gd's _on_battle_finished(), was_special and
		# was_tutorial) - moved here, to the end of the guided portion, so
		# it reads as part of the tutorial itself rather than a toast the
		# player sees after already being back in the overworld.
		await _tutorial_show_step("Defeat enemies in special encounters to unlock one-use stat-boosting battle items. Losing one is no real setback either - just like the very first combat tutorial, you'll get the choice to retry or head back to the overworld, fully healed. This particular fight is still just practice, though - winning it won't grant a reward, but the real special encounter that does will remain at this map location afterward.")
		# MODIFIED (fixed): same stale-caption bug as the other two special-
		# encounter captions - nothing else was about to overwrite this one
		# (unlike the plain tutorial's own finale block just above, which
		# hands straight off to a real enemy turn that locks the caption
		# down again anyway), so the "Press Enter to continue" pulse would
		# otherwise sit there flashing for the rest of the fight.
		_tutorial_caption.text = ""
		_tutorial_caption.visible = false
		call_deferred("_fit_panel_height")
	if _living(enemies).is_empty():
		if prologue_angler_encounter:
			if not _prologue_angler_interrupted:
				_prologue_angler_interrupted = true
				_busy = true
				_set_all_buttons(false)
				main_menu.visible = false
				move_menu.visible = false
				item_menu.visible = false
				target_menu.visible = false
				_log("The Angler falls. The water goes still.")
				prologue_angler_defeated.emit()
			return
		_win()
		return
	if _living(party).is_empty():
		_lose()
		return
	if _queue.is_empty():
		_rebuild_queue()
	# Forces each stage's own diver to go next, back to back, regardless of
	# real agility - without this, whichever combatant actually has the
	# highest agility could go first/between them, and the tutorial's
	# scripted turns would just silently wait for that diver's own natural
	# turn to come up instead of opening the fight. Removed from wherever
	# it sits in `_queue` (not necessarily the front) rather than popped
	# normally, so nobody else's place in this round's real order is
	# disturbed - everyone else just waits their actual turn once the
	# scripted portion (_tutorial_step < _TUTORIAL_SCRIPT.size()) ends.
	var forced_index := _tutorial_party_index_for_step(_tutorial_step) if tutorial_encounter else -1
	if forced_index >= 0:
		var forced: Dictionary = party[forced_index]
		if _living(party).has(forced) and _queue.has(forced):
			_queue.erase(forced)
			_acting = forced
			_refresh_queue_row()
			_start_party_turn(_acting)
			return
	_acting = _queue.pop_front()
	_refresh_queue_row()
	if (_acting.stats as CombatantStats).hp <= 0:
		_advance_turn()   # downed since the queue was built - skip them
		return
	if String(_acting.kind) == "enemy":
		var forced_target := {}
		if tutorial_encounter:
			# _do_enemy_turn() below is what normally locks everything down
			# for the enemy's turn, but that doesn't run until after these
			# two prompts finish - without disabling here first, whatever
			# was left enabled from the player's own turn (main menu, move
			# menu, ...) would still be clickable underneath the caption.
			_set_all_buttons(false)
			main_menu.visible = false
			move_menu.visible = false
			item_menu.visible = false
			target_menu.visible = false
			if _tutorial_step == 0:
				await _first_fight_prompt()
			forced_target = await _tutorial_prep_enemy_turn()
		_do_enemy_turn(_acting, forced_target)
	else:
		_start_party_turn(_acting)

# Used to script the goblin's first two swings (guaranteed miss, then
# guaranteed hit) to teach Accuracy vs. Evasion from the enemy's side - cut
# per feedback that it re-taught the same lesson Maxilani/Musashi/Mech
# Pilot's own three scripted attacks had already covered, just mirrored.
# What this does now instead: the enemy's normal swing is already QTE-
# eligible (see ENEMY_MOVE's quick_time_bool), but whether one actually
# shows up during any given fight is normally just the independent
# ENEMY_QTE_CHANCE roll in _resolve_attack() - it could never come up at
# all. This is the one enemy turn the tutorial still touches, and it
# spends that touch guaranteeing a QTE happens here, with a caption
# explaining the mechanic first (_tutorial_force_next_qte, consumed by
# _resolve_attack()'s own QTE roll) - so every player has actually seen a
# dodge-it-yourself window once before it's left to chance for the rest of
# the game. Turn 2 onward resolves completely for real, no scripting at all.
# Returns whoever it picked as the target, or {} once the one scripted
# turn has already happened - _advance_turn() passes that straight into
# _do_enemy_turn() as forced_target so the real attack lands on the exact
# combatant this caption was about, rather than letting _do_enemy_turn()
# re-roll _pick_enemy_target() and possibly land on someone else.
func _tutorial_prep_enemy_turn() -> Dictionary:
	_tutorial_enemy_turns += 1
	# MODIFIED (changed): was `> 1` - the first special encounter now walks
	# through all three divers' own minigames in turn (see
	# _swap_tutorial_special_diver()), one teaching enemy turn each, so this
	# has to stay "scripted" for three enemy turns instead of just one.
	if _tutorial_enemy_turns > 3:
		return {}
	var alive_party := _living(party)
	if alive_party.is_empty():
		return {}
	var target: Dictionary = _pick_enemy_target(alive_party)
	if special_encounter:
		# The special encounter's enemy turn never reaches _resolve_attack()'s
		# QTE roll at all - _do_enemy_turn() checks special_encounter first
		# and branches straight into its own minigame before ever getting
		# there. Explaining the QTE bar below would be narrating a mechanic
		# that isn't the one about to happen - this explains the actual
		# minigame instead, right before it plays for real.
		# Shown once, on the first of the three teaching turns only - it's a
		# general statement about every diver, not specific to whoever's up
		# this particular turn, so repeating it for Musashi/Bucky too would
		# just be saying the same thing three times.
		if _tutorial_enemy_turns == 1:
			await _tutorial_show_step("Each diver has their own special encounter minigame to play to dodge extra damage from the enemy before their attack. Play it perfectly and you'll dodge the attack completely.")
		match String(target.get("ability_id", "")):
			"swap":
				_swap_demo_frame.visible = true
				_refresh_swap_demo_media("swap")
				call_deferred("_fit_panel_height")
				# MODIFIED (added): matches diver_swap_minigame.gd's own
				# on-screen hint text ("Left/Right to aim, E to swap into
				# that spot") so this caption and the minigame's own prompt
				# never describe the controls two different ways.
				await _tutorial_show_step("Maxilani's special encounter involves swapping with portraits to the left and right of her position to correctly line them up with incoming portraits. Press left or right to choose portraits adjacent to her position, then press E to confirm swapping positions between Maxilani and that portrait.")
				# The clip's only job was illustrating the explanation above -
				# the real minigame (about to run, driven by _do_enemy_turn()
				# reading this function's return value) takes over the
				# screen next, so this frees the space back to the caption/
				# menus below it rather than sitting idle (and still
				# decoding, if it's a video) underneath it.
				for child in _swap_demo_frame.get_children():
					child.queue_free()
				_swap_demo_frame.visible = false
				call_deferred("_fit_panel_height")
			"grapple":
				# MODIFIED (added): matches grapple_intercept_minigame.gd's
				# actual controls (mouse-look aim, left click to fire) and
				# its own per-wave scoring rule (a correct-color hit clears
				# it; a wrong-color hit just flashes and wastes the shot,
				# it doesn't cost anything by itself - only a wave that
				# times out with a safe sphere still up actually damages
				# the diver, same "flawless run dodges everything" rule
				# every special encounter minigame shares).
				# MODIFIED (added): same demo-frame treatment "swap" already
				# gets above - this teaching turn used to be text-only, the
				# only one of the three with no clip. Falls back to the
				# frame's own "Clip coming soon" placeholder until a real
				# file lands at SPECIAL_ENCOUNTER_MEDIA["grapple"]'s path - no
				# code changes needed once it does.
				_swap_demo_frame.visible = true
				_refresh_swap_demo_media("grapple")
				call_deferred("_fit_panel_height")
				await _tutorial_show_step("Musashi's special encounter involves grappling the correctly-colored spheres before their wave reaches him. Move the mouse to aim your crosshair, then left-click to fire the grapple at the safe color - the wave clears once every safe-colored sphere has been hit, so watch which color is safe each round in the bottom battle text where it mentions to grapple/avoid [color=#ffe626]YELLOW[/color] and [color=#26f259]GREEN[/color].")
				for child in _swap_demo_frame.get_children():
					child.queue_free()
				_swap_demo_frame.visible = false
				call_deferred("_fit_panel_height")
			"shockwave":
				# MODIFIED (added): same demo-frame treatment as "swap"/
				# "grapple" above - falls back to the placeholder until a
				# real file lands at SPECIAL_ENCOUNTER_MEDIA["shockwave"]'s
				# path.
				_swap_demo_frame.visible = true
				_refresh_swap_demo_media("shockwave")
				call_deferred("_fit_panel_height")
				await _tutorial_show_step("Bucky's special encounter involves pressing left and right to move to the left and right lanes from the center or press nothing to stay in the center to position Bucky in lanes with breakable rocks and no walls. Hold the directional keys to stay in the lanes then time correctly pressing E to shockwave a rock when it arrives in the lane to break it.")
				for child in _swap_demo_frame.get_children():
					child.queue_free()
				_swap_demo_frame.visible = false
				call_deferred("_fit_panel_height")
		# MODIFIED (fixed): same stale-caption bug as _play_special_
		# encounter_intro() - _tutorial_show_step() leaves its own text
		# (flashing "Press Enter to continue" included) sitting in the
		# caption after the last Enter press, and nothing else was about to
		# overwrite it before the real minigame took over the screen.
		_tutorial_caption.text = ""
		_tutorial_caption.visible = false
		call_deferred("_fit_panel_height")
		return target
	# _resolve_attack() only ever rolls for a QTE once the swing has already
	# beaten Evasion (a real miss returns before reaching that roll at all -
	# see its own header comment) - without this, _tutorial_force_next_qte
	# below could easily do nothing at all, on whatever fight happens to
	# roll the target's Evasion high enough to dodge outright. Zeroing it
	# guarantees this one swing actually reaches the QTE roll; nothing
	# narrates a specific number here (unlike the old miss/hit scripting),
	# so there's no claim on screen this could contradict.
	var defender := target.stats as CombatantStats
	defender.evasion_current = 0
	_tutorial_force_next_qte = true
	# RichTextLabel's own [img] tag only takes an actual texture resource,
	# not a live Control - can't embed qte_root's real bar inline in
	# _tutorial_caption's text that way. Instead this temporarily moves the
	# real qte_root (normally positioned over whoever's actually dodging -
	# see _quick_time_event()/_project_to_screen()) into the caption's own
	# column, right between the two halves of the text, so what the player
	# sees IS the real bar (never a separate image that could drift out of
	# sync with it), just sitting inline for a moment instead of floating
	# over the stage. Restored back to its normal parent/anchor before
	# returning, so the real QTE (moments later, once the actual attack
	# resolves) positions itself the normal way again.
	var col := _tutorial_caption.get_parent()
	var qte_normal_parent := qte_root.get_parent()
	qte_normal_parent.remove_child(qte_root)
	col.add_child(qte_root)
	col.move_child(qte_root, _tutorial_caption.get_index() + 1)
	qte_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	qte_root.position = Vector2.ZERO
	qte_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	qte_root.visible = true
	qte_zone.position.x = 0.4 * QTE_TRACK_WIDTH
	qte_zone.size.x = 0.15 * QTE_TRACK_WIDTH
	qte_indicator.position.x = 0.0
	_tutorial_caption.text = "Sometimes during an enemy's attack, a Quick Time Event shows up:"
	# _levelup_caption reused here purely as "whatever RichTextLabel already
	# sits right after _tutorial_caption in this column" - never in use
	# during an actual fight (only _win() ever touches it), so borrowing it
	# for the second half of this one caption doesn't collide with its own
	# job. _tutorial_show_step()'s own Enter-wait, just spread across two
	# labels with the QTE preview sandwiched between them instead of one.
	_levelup_caption.text = "The white bar sweeps across the track, and pressing X the instant it's inside the red zone dodges the attack completely. Miss the timing and the attack just lands as normal.\n[font_size=22][pulse]Press Enter to continue[/pulse][/font_size]"
	_levelup_caption.visible = true
	call_deferred("_fit_panel_height")
	await get_tree().process_frame
	_tutorial_awaiting_enter = true
	while _tutorial_awaiting_enter:
		await get_tree().process_frame
	_levelup_caption.visible = false
	_levelup_caption.text = ""
	qte_root.visible = false
	col.remove_child(qte_root)
	qte_normal_parent.add_child(qte_root)
	qte_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	call_deferred("_fit_panel_height")
	return target

# The `party` index _TUTORIAL_SCRIPT names for stage `step`, or -1 once
# `step` runs past the end of the script (every stage done) or the entry
# names an index the current party doesn't have. Centralizing this lookup
# is what let stage 3 revisit Musashi (party index 1) without every call
# site re-deriving "which diver is this stage about" its own way.
func _tutorial_party_index_for_step(step: int) -> int:
	if step < 0 or step >= _TUTORIAL_SCRIPT.size():
		return -1
	var idx := int(_TUTORIAL_SCRIPT[step].get("party_index", -1))
	return idx if idx < party.size() else -1

# True only on the exact turn _TUTORIAL_SCRIPT's current stage is meant to
# be force-walked through its one scripted move - see _TUTORIAL_SCRIPT's
# own header comment. False once the script's fully done, and false for
# any diver whose OWN stage isn't the current one (including a diver
# acting again after their stage already passed), so
# _start_party_turn()/_show_moves()/_on_move_chosen() know when to apply
# the move-gate/explanation chain versus just letting a turn play out
# normally.
# MODIFIED (fixed): _TUTORIAL_SCRIPT is the full 3-diver combat tutorial's
# own script (Electric Touch, Precise Tap, ...) - stage 0 names party index
# 0, which happens to BE Maxilani in the first special encounter's solo
# party too, so without this exclusion her first move there was silently
# getting force-gated into Electric Touch specifically (flashing highlight,
# every other move disabled) exactly like the real combat tutorial, instead
# of the normal free choice a special encounter is supposed to give her.
func _is_tutorial_scripted_turn(actor: Dictionary) -> bool:
	if not tutorial_encounter or special_encounter:
		return false
	var idx := _tutorial_party_index_for_step(_tutorial_step)
	return idx >= 0 and actor == party[idx]

func _start_party_turn(actor: Dictionary) -> void:
	(actor.stats as CombatantStats).begin_turn()
	_refresh_bar(actor)
	_busy = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	main_menu.visible = true
	_place_skip_tutorial_btn_last(main_menu)
	_selected_move_name.text = ""
	_selected_move_power.text = ""
	_selected_move_panel.visible = true
	(_player_stats_ui.panel as Control).visible = true
	call_deferred("_fit_panel_height")
	_refresh_player_stats_panel()
	_clear_stat_preview()
	_show_turn_cursor_on(actor)
	_log("%s's turn." % String(actor.display_name))
	_set_all_buttons(true)
	if prologue_angler_encounter or prologue_octopus_encounter:
		run_btn.visible = false
		items_btn.visible = false
	# Run stays off for the entire tutorial fight, not just its scripted
	# steps - _set_all_buttons(true) just re-enabled it above like every
	# other button, and this fight is supposed to read as risk-free
	# (Battle._lose()'s own tutorial caption says as much) rather than
	# something a new player might reflexively flee from before ever
	# seeing what losing here actually costs (nothing).
	if tutorial_encounter:
		run_btn.disabled = true
	# Skip straight past Attack/Items/Run ONLY on the scripted diver's own
	# turn - the tutorial's whole point there is choosing between moves,
	# not re-discovering the top-level menu. Mech Pilot (never scripted)
	# and either scripted diver's own LATER turns (once _tutorial_step has
	# already moved past them) get a completely normal main menu instead.
	if _is_tutorial_scripted_turn(actor):
		_show_moves()
	elif special_encounter and tutorial_encounter and not _first_fight_prompt_shown:
		# MODIFIED (added): the special encounter is never a "scripted turn"
		# (see _is_tutorial_scripted_turn()), so it never used to auto-open
		# _show_moves() the way the plain tutorial's Maxilani does - the
		# player would see a fully clickable, enabled main menu the instant
		# the fight started, with "Welcome to your first special
		# encounter!..." only appearing once they happened to click Attack.
		# This plays that intro right here instead, with the menu disabled
		# for its duration, matching what a new player should see: the
		# captions first, buttons back the moment they're actually needed.
		_play_special_encounter_intro()

# The first special encounter's own version of the scripted-turn intro
# _show_moves() plays for the plain combat tutorial - deliberately doesn't
# call _explain_turn_order() (no "Combat Basics"/turn-order caption here,
# unlike the plain tutorial) and doesn't auto-open the move menu either:
# _first_fight_prompt() covers welcome/turn-order-for-this-fight/attacks-
# first entirely on its own, and once it's done Maxilani gets a completely
# normal, freely-clickable main menu rather than being funneled anywhere.
func _play_special_encounter_intro() -> void:
	_set_all_buttons(false)
	await _first_fight_prompt()
	if _skip_tutorial_requested:
		return
	# MODIFIED (fixed): _tutorial_show_step() leaves its own text (including
	# the flashing "Press Enter to continue" line) sitting in the caption
	# after the last Enter press - the plain tutorial never shows this
	# because _apply_tutorial_move_gate() immediately overwrites it with
	# "Choose the highlighted attack move..." right after, but the special
	# encounter has no move gate (it's a free choice) and nothing else was
	# clearing it, so the stale caption - "Press Enter" pulse included, even
	# though nothing is still waiting on a press - just sat there frozen
	# once the real main menu came up underneath it.
	_tutorial_caption.text = ""
	_tutorial_caption.visible = false
	call_deferred("_fit_panel_height")
	_set_all_buttons(true)
	if tutorial_encounter:
		run_btn.disabled = true

# Only ever called with a party entry (see _advance_turn()'s kind check) -
# actor.actor is always the Diver battle-stage instance built in
# _build_stage(), never a Goblin, so no type check needed before the cast.
func _process(_delta: float) -> void:
	if not is_instance_valid(_turn_cursor) or not _turn_cursor.visible:
		return
	if not is_instance_valid(_turn_cursor_target):
		_turn_cursor.visible = false
		return
	_turn_cursor.global_position = _turn_cursor_target.global_position + Vector3.UP * _turn_cursor_height

func _show_turn_cursor_on(actor: Dictionary) -> void:
	if not actor.has("actor") or not is_instance_valid(actor.actor) or not is_instance_valid(_turn_cursor):
		return
	var d := actor.actor as Diver
	_turn_cursor_target = d
	_turn_cursor_height = d.height + 0.4
	_turn_cursor.global_position = d.global_position + Vector3.UP * _turn_cursor_height
	_turn_cursor.visible = true

# This diver's own BASE_MOVES plus whatever they currently have equipped,
# translated from spell data into the same move shape battle resolution
# already expects - see SpellTree.find_def()'s header comment on why spell
# defs double as move defs directly. Falls back to Staff_Diver's kit for
# the standalone-Battle stand-in case (tools/test_battle.gd), same fallback
# Diver.BASE_STATS.get() already uses elsewhere.
func _moves_for(entry: Dictionary) -> Array:
	var base: Array = BASE_MOVES.get(String(entry.model_name), BASE_MOVES["Staff_Diver"])
	var out: Array = base.duplicate()
	for spell_id in entry.get("equipped_spells", []):
		var def: Dictionary = SpellTree.find_def(String(entry.model_name), spell_id)
		if def.is_empty():
			continue
		out.append({
			"name": String(def.get("display", spell_id)),
			"power": int(def.get("power", 0)),
			"acc_mod": int(def.get("acc_mod", 0)),
			"effect": String(def.get("effect", "")),
			"debuff": String(def.get("debuff", "")),
			"amount": int(def.get("amount", 0)),
			"hint": String(def.get("hint", "")),
			"text": String(def.get("text", "You cast %s" % String(def.get("display", spell_id)))),
			"oxygen_cost": float(def.get("oxygen_cost", 0.0)),
		})
	if prologue_angler_encounter:
		var attacks: Array = []
		for move_value in out:
			var original := move_value as Dictionary
			if not _move_deals_damage(original):
				continue
			var attack := original.duplicate(true)
			attack.acc_mod = maxi(int(attack.get("acc_mod", 0)), 1 - (entry.stats as CombatantStats).effective_accuracy())
			attacks.append(attack)
		return attacks
	return out

static func _move_deals_damage(move: Dictionary) -> bool:
	if move.has("formula"):
		return not (move.get("formula", {}) as Dictionary).is_empty()
	return int(move.get("power", 0)) > 0 and String(move.get("effect", "")) not in ["heal", "revive"]

func _show_moves() -> void:
	if _busy:
		return
	main_menu.visible = false
	_populate_move_menu(_acting)
	move_menu.visible = true
	call_deferred("_fit_panel_height")
	# MODIFIED (fixed): the intro captions (_first_fight_prompt()/
	# _explain_turn_order()) used to be nested inside the scripted-turn
	# check below, on the assumption the very first move menu of any
	# tutorial fight IS always a scripted turn - true for the full combat
	# tutorial, but _is_tutorial_scripted_turn() now deliberately excludes
	# the special encounter (see its own comment), which made this whole
	# block - captions included - stop running for it too. Split apart:
	# the intro always shows once on the first move menu of ANY tutorial
	# fight; only the move-gate below is conditional on being scripted.
	if tutorial_encounter and _tutorial_step == 0 and not _first_fight_prompt_shown:
		# Turn order/combat-basics gets explained once, on the very first
		# move menu of the fight - awaited so both fully finish (including
		# the player's Enter press each time) before the move gate below
		# ever touches the caption. Every move button (plus Back) is locked
		# for the whole intro, not just once _apply_tutorial_move_gate()
		# gets to it - _populate_move_menu() only disables a button for
		# being unaffordable, so without this the player could click a move
		# straight through these two prompts.
		for b in move_buttons:
			(b as Button).disabled = true
		back_btn.disabled = true
		await _first_fight_prompt()
		await _explain_turn_order()
		if not _is_tutorial_scripted_turn(_acting):
			# The special encounter (never scripted - see
			# _is_tutorial_scripted_turn()) has nothing else undoing the
			# blanket disable just above: the scripted branch below does its
			# own re-enable of exactly one forced move, but without an
			# equivalent here every move button would stay disabled forever,
			# leaving Maxilani with a move menu she can't actually click
			# anything in. Re-populating restores the normal affordability-
			# based enabled state _show_moves() already set before this
			# whole intro ran.
			_populate_move_menu(_acting)
			back_btn.disabled = false
	# Only the currently-scripted diver's own turn gets the move gate - any
	# diver clicking "Attack" on some later, un-scripted turn of their own
	# (their scripted stage already behind them, or a special encounter,
	# which is never scripted at all) just gets a normal move menu with
	# nothing forced or flashing.
	if _is_tutorial_scripted_turn(_acting):
		_apply_tutorial_move_gate()

# Guarded on _first_fight_prompt_shown, not just the _tutorial_step == 0
# check both call sites already do - _advance_turn() also awaits this
# ahead of the goblin's own turn (for the case where the enemy happens to
# act before the player ever gets a move menu open), so both paths can
# reach here on the very first round. Without its own guard, an enemy-
# goes-first round would show this, then _show_moves() would show it
# again the moment the player's own first turn opened right after.
var _first_fight_prompt_shown := false

# Same loading convention as character_ability_popup.gd's _refresh_media()/
# special_encounter_prompt.gd's own copy: a still image loads into a
# TextureRect, a .ogv loops via a VideoStreamPlayer replaying itself on
# `finished`, and nothing at the path yet (true today for "grapple"/
# "shockwave" - see TutorialContent.SPECIAL_ENCOUNTER_MEDIA's own comment)
# falls back to a plain placeholder label. Reads that table specifically,
# not character_ability_popup.gd's own ABILITY_MEDIA - the two used to be
# the same shared table, split apart so this fight's own clip (media/
# tutorials/special_encounters/) can be replaced without also changing
# what the Esc-menu's general ability reference shows, and vice versa.
# MODIFIED (changed): was hardcoded to "swap" - Maxilani's own portion of
# this same three-diver tutorial was the only one that ever showed a demo
# clip at all; Musashi's and Bucky's own explanations (see
# _tutorial_prep_enemy_turn()'s "grapple"/"shockwave" branches) had no clip
# to show, even once one existed, since this always looked up "swap"
# regardless of which diver was actually being explained. Takes the same
# key the caption's own match branch already switches on, so dropping a
# file at SPECIAL_ENCOUNTER_MEDIA["grapple"]/["shockwave"]'s path is the
# only step needed to show a real clip there too - same "no code changes"
# promise this frame's own header comment already makes for "swap".
func _refresh_swap_demo_media(ability_id: String = "swap") -> void:
	for child in _swap_demo_frame.get_children():
		child.queue_free()
	var path := String(TutorialContent.SPECIAL_ENCOUNTER_MEDIA.get(ability_id, ""))
	if path != "" and ResourceLoader.exists(path):
		if path.get_extension() == "ogv":
			var player := VideoStreamPlayer.new()
			var video_stream := VideoStreamTheora.new()
			video_stream.file = path
			player.expand = true
			# MediaFrame is a PanelContainer, so it positions its direct child
			# from size flags; anchors and a nested AspectRatioContainer do not
			# make that child fill the panel reliably. The frame keeps a 16:9
			# minimum and expands to roughly a third of the tutorial row, so let
			# the player claim that whole inner rect and scale the video texture
			# to it.
			player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			player.size_flags_vertical = Control.SIZE_EXPAND_FILL
			player.stream = video_stream
			player.finished.connect(player.play)
			_swap_demo_frame.add_child(player)
			# Deferred one frame for the same reason character_ability_
			# popup.gd's own player defers play() - starting Theora decode
			# the instant this fight's own stage/UI is still mid-build risks
			# contending with it instead of just showing a small clip.
			player.call_deferred("play")
			return
		var tex := load(path) as Texture2D
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_swap_demo_frame.add_child(rect)
			return
	var placeholder := Label.new()
	placeholder.text = "Clip\ncoming soon"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_swap_demo_frame.add_child(placeholder)

func _first_fight_prompt() -> void:
	if _first_fight_prompt_shown:
		return
	_first_fight_prompt_shown = true
	if special_encounter:
		# MODIFIED (changed): the "Each diver has their own..."/"Maxilani's
		# special encounter involves swapping..." captions (and the demo
		# clip) used to run here too, all up front before Maxilani's own
		# first move. Moved to _tutorial_prep_enemy_turn() instead, which
		# fires right before the enemy's own first turn - explaining the
		# dodge minigame immediately before it happens reads better than
		# explaining it, then making the player sit through choosing and
		# landing her own attack first, then FINALLY seeing what it was
		# about. This intro now only covers turn order.
		await _tutorial_show_step("Welcome to your first special encounter! By fighting special encounters, you can gain items that give you temporary stat boosting perks for other battles.")
		if _skip_tutorial_requested:
			return
		await _tutorial_show_step("Normally, only one chosen diver gets to enter the special encounter. For now, Maxilani is the chosen diver. Diver agility applies as normal and will determine whether you attack first or after the enemy.")
		if _skip_tutorial_requested:
			return
		# _build_stage() forces this one enemy's agility below Maxilani's for
		# this exact fight (see its own tutorial_encounter branch), so this
		# is a guarantee for THIS fight specifically, not just the general
		# agility rule the caption above already covered.
		# MODIFIED (changed): the no-reward "just for practice" framing used
		# to sit in the post-minigame caption (_advance_turn()'s own special-
		# encounter finale block) - moved up here instead, so the player
		# knows this won't grant anything before they even swing, not after.
		# That later caption keeps the reward-mechanic explanation for real
		# special encounters, since that's still better taught once they've
		# actually seen one play out.
		await _tutorial_show_step("In this case, Maxilani will attack first. This special encounter is just for practice and won't grant anything for winning or losing, and the normal special encounter that grants an item will remain at this map location after the tutorial.")
		if _skip_tutorial_requested:
			return

	else:
		await _tutorial_show_step("While exploring the deep, random encounters like this one with deep sea enemies can occur at any time.")

# One-shot: circles the turn-order bar in red, folds Combat Basics in with
# the turn-order explanation (one combined caption instead of two the
# player would have to click through separately), and waits for Enter
# before turning the highlight back off - see _tutorial_show_step().
func _explain_turn_order() -> void:
	_turn_order_highlight = _highlight_box(_turn_order_highlight, _queue_bar)
	var combat_basics := TutorialContent.page_body("Combat Basics")
	var turn_order_line := "Turn order is shown from first at left to last at right in the turn order bar at the top."
	var agility_line := "Turn order is decided by Agility - whoever has the highest goes first. If a move changes someone's Agility, the turn order always updates right away to reflect it."
	await _tutorial_show_step("%s %s %s" % [combat_basics, turn_order_line, agility_line])
	_turn_order_highlight.visible = false

# Generic red-bordered box: lazily creates `highlight` (a Panel with a
# transparent fill, border only) the first time it's used, then repositions
# it to exactly overlay `target` every call rather than only once at
# creation, in case target's own size/position ever changes. Shared by
# _explain_turn_order() (boxes _queue_bar) and _explain_dodging() (boxes
# the ACC/EVA stat rows) rather than three near-identical Panel-building
# blocks.
func _highlight_box(highlight: Panel, target: Control) -> Panel:
	if highlight == null:
		highlight = Panel.new()
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = Color(1, 0, 0)
		box.border_width_left = 4
		box.border_width_right = 4
		box.border_width_top = 4
		box.border_width_bottom = 4
		highlight.add_theme_stylebox_override("panel", box)
		add_child(highlight)
	highlight.global_position = target.global_position
	highlight.size = target.size
	highlight.visible = true
	return highlight

func _explain_stats() -> void:
	_tutorial_caption.text = "."


func _apply_tutorial_move_gate() -> void:
	if _tutorial_flash_tween != null and _tutorial_flash_tween.is_valid():
		_tutorial_flash_tween.kill()
	for i in range(move_buttons.size()):
		var b := move_buttons[i] as Button
		b.modulate = Color.WHITE
		b.disabled = true
	back_btn.disabled = true
	if move_buttons.is_empty():
		return
	var moves := _moves_for(_acting)
	var forced_name := String(
		(_TUTORIAL_SCRIPT[_tutorial_step] as Dictionary).get("move", "")
	) if _tutorial_step < _TUTORIAL_SCRIPT.size() else ""
	var move_index := 0
	for i in range(moves.size()):
		if String((moves[i] as Dictionary).name) == forced_name:
			move_index = i
			break
	var mv: Dictionary = moves[move_index]
	var note := String(TutorialContent.FIRST_BATTLE_MOVE_NOTES.get(String(mv.name), ""))
	var btn := move_buttons[move_index] as Button
	_scroll_move_into_view(move_index)
	_tutorial_flash_tween = create_tween()
	_tutorial_flash_tween.set_loops()
	_tutorial_flash_tween.tween_property(btn, "modulate", Color(1.0, 0.85, 0.25), 0.4)
	_tutorial_flash_tween.tween_property(btn, "modulate", Color.WHITE, 0.4)
	_tutorial_caption.text = "Choose the [color=yellow]highlighted[/color] attack move against the enemy."
	call_deferred("_fit_panel_height")
	btn.disabled = false

# Overlays `power` in the top-right corner of `btn`, on the same row as
# the move's name (the button's own text is two lines - name, then hint -
# so top-right lands beside the name specifically, not the hint below it),
# like a spell's mana cost sitting beside its name in other games. A
# separate Label layered on top via anchors rather than folded into the
# button's own text, so it reads as its own fixed number regardless of how
# long the name/hint text runs. mouse_filter IGNORE keeps it from stealing
# the click meant for the button underneath it.
func _add_power_badge(btn: Button, power: int) -> void:
	# A small opaque plate behind the number, not just the number floating
	# over the button's own text - on a long move name the text can run
	# right up under the corner, and a bare number there was getting lost
	# in/blended with the letters behind it.
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.05, 0.08, 0.1, 0.85)
	plate_style.set_corner_radius_all(4)
	plate_style.set_content_margin_all(2)
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	plate.offset_left = -40
	plate.offset_top = 3
	plate.offset_right = -4
	plate.offset_bottom = 21
	btn.add_child(plate)

	var badge := Label.new()
	badge.text = str(power)
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(badge)

func _populate_move_menu(actor: Dictionary) -> void:
	# The guided button belongs to this menu generation. An infinite tween
	# whose property targets have all been freed becomes a zero-duration
	# loop: debug Godot reports an error, but the release web build can hang.
	# Stop it BEFORE freeing buttons, including the final guided-to-free turn.
	if _tutorial_flash_tween != null and _tutorial_flash_tween.is_valid():
		_tutorial_flash_tween.kill()
	_tutorial_flash_tween = null
	for b in move_buttons:
		(b as Button).queue_free()
	move_buttons.clear()
	var available: float = (actor.stats as CombatantStats).oxygen
	for mv in _moves_for(actor):
		var ox_cost: float = float(mv.get("oxygen_cost", 0.0))
		var hint: String = CombatMoves.resolved_hint(actor.stats as CombatantStats, mv)
		if ox_cost > 0.0:
			hint = "%s - %d O2" % [hint, int(ox_cost)]
		var b := _menu_button(String(mv.name), hint)
		var base_power := _move_base_power(mv)
		if base_power > 0:
			_add_power_badge(b, base_power)
		var tooltip := _move_tooltip_text(mv, actor)
		if tooltip != "":
			b.tooltip_text = tooltip
		b.disabled = available < ox_cost
		b.pressed.connect(_on_move_chosen.bind(mv))
		move_menu.add_child(b)
		move_buttons.append(b)
	# Not rebuilt with the move buttons above - keep them after the choices.
	move_menu.move_child(_move_scroll_box, move_menu.get_child_count() - 1)
	move_menu.move_child(back_btn, move_menu.get_child_count() - 1)
	_place_skip_tutorial_btn_last(move_menu)
	_move_scroll_offset = 0
	_apply_move_scroll()

func _moves_overflow() -> bool:
	return move_buttons.size() + 1 > MOVE_MENU_SLOTS

# Shows only the current page of move buttons. The rest stay in
# move_buttons (hidden), so index-based callers - the tutorial gate,
# verify scripts - still see every move.
func _apply_move_scroll() -> void:
	if _move_scroll_box == null:
		return
	var overflow := _moves_overflow()
	var max_offset := maxi(0, move_buttons.size() - MOVE_MENU_VISIBLE_MOVES)
	_move_scroll_offset = clampi(_move_scroll_offset, 0, max_offset) if overflow else 0
	for i in range(move_buttons.size()):
		(move_buttons[i] as Button).visible = not overflow or (i >= _move_scroll_offset and i < _move_scroll_offset + MOVE_MENU_VISIBLE_MOVES)
	_move_scroll_box.visible = overflow
	_move_up_btn.disabled = _move_scroll_offset <= 0
	_move_down_btn.disabled = _move_scroll_offset >= max_offset
	call_deferred("_fit_panel_height")

# Pages a full window at a time; the clamp in _apply_move_scroll() makes the
# last page end exactly on the last move instead of showing a short page.
func _scroll_moves(direction: int) -> void:
	_move_scroll_offset += direction * MOVE_MENU_VISIBLE_MOVES
	_apply_move_scroll()

# Scrolls just enough that move_buttons[index] is on screen.
func _scroll_move_into_view(index: int) -> void:
	if index < _move_scroll_offset or index >= _move_scroll_offset + MOVE_MENU_VISIBLE_MOVES:
		_move_scroll_offset = index
		_apply_move_scroll()

# Ready-to-assign tooltip text covering every explainable effect a move
# carries, not just the first - Flash Blast carries both a "status" (its own
# per-move name, Blindness) and a "self_temporary" cost, and a player
# hovering it needs both explanations, not whichever happened to be listed
# first in the move's own data. A damage-dealing formula-based move (Group_
# StatsV2/Scuba) also gets a leading "Damage" section, naming exactly which
# of `actor`'s stats it draws on - see _formula_damage_sentence().
# MODIFIED (changed): legacy moves (Musashi/Bucky, power>0 with no
# `formula`) used to get this same "Damage" section too - dropped. Their
# damage is a flat power+Strength add, not the formula math this section is
# actually explaining, and the power badge on the button itself already
# shows the move's own raw power without walking through the math.
# Returns "" only when a move has no damage and nothing else to explain
# either - a legacy debuff move (those apply their debuff directly, never
# through CombatantStats.add_status(), so there's no STATUS_CONDITIONS
# entry to point at) or an effect kind with no EFFECT_KIND_EXPLANATIONS
# entry.
func _move_tooltip_text(mv: Dictionary, actor: Dictionary) -> String:
	var sections: Array[String] = []
	var target_scope := String(mv.get("target", ""))
	var support_effect := String(mv.get("effect", ""))
	if support_effect == "revive":
		sections.append("Target\nOne downed ally.")
	elif support_effect == "heal":
		sections.append("Target\nOne living ally.")
	elif target_scope in ["all", "all_enemies"]:
		sections.append("Target\nAll enemies.")
	var deals_damage := mv.has("formula") and not (mv.get("formula", {}) as Dictionary).is_empty()
	if deals_damage:
		var formula: Dictionary = mv.get("formula", {})
		var damage_body := _formula_damage_sentence(String(actor.get("display_name", "the caster")), formula, String(mv.get("target", "")))
		# Every Scuba move's formula is pure stat coefficients (e.g.
		# Electric Touch's {"strength": 1}) with no "base" term at all (see
		# _move_base_power()), so none of them ever get the corner power
		# badge - there's no attacker-independent number to show. Called
		# out explicitly here so hovering explains why the badge is missing
		# instead of just leaving a player to wonder.
		if _move_base_power(mv) <= 0:
			damage_body = "This move has no power of its own - its entire damage comes from your Strength stat. %s" % damage_body
		sections.append("Damage\n%s" % damage_body)
	for effect_value in mv.get("effects", []):
		var effect := effect_value as Dictionary
		var kind := String(effect.get("kind", ""))
		if kind == "status":
			var status_name := String(effect.get("status", ""))
			var body := TutorialContent.status_condition_body(status_name)
			if body != "":
				sections.append("%s\n%s" % [status_name.capitalize(), body])
		elif kind == "self_temporary":
			# MODIFIED (changed): used to pull TutorialContent.
			# EFFECT_KIND_EXPLANATIONS["self_temporary"]'s generic body (still
			# used as-is by inventory_menu.gd's Combat Help tab, a general
			# reference page with no one move in mind) - this hover is
			# already looking at ONE specific move, so it names that move's
			# actual ACC/EVA cost instead of speaking in the abstract.
			sections.append("Self Cost\n%s" % _self_cost_sentence(effect))
		else:
			var explanation := TutorialContent.effect_kind_explanation(kind)
			if not explanation.is_empty():
				sections.append("%s\n%s" % [String(explanation.get("title", "")), String(explanation.get("body", ""))])
	# MODIFIED (added): legacy moves (Musashi/Bucky's own base kits, no
	# `formula`/`effects` at all - see BASE_MOVES) got no tooltip whatsoever
	# up to this point, not even for Weaken/Slow, whose entire point is a
	# debuff this hover never explained. A legacy move's flat power+Strength
	# damage still isn't repeated here (see this function's own header
	# comment - the corner badge already covers that), but its debuff and
	# any accuracy swing it carries for the one attack (acc_mod) - the same
	# two things the choreographed tutorial's own one-time captions already
	# walk through for Precise Tap/Weaken/Crushing Haymaker - are worth
	# surfacing on every later hover, not just that first scripted turn.
	if not mv.has("formula"):
		var debuff := String(mv.get("debuff", ""))
		if debuff != "":
			sections.append("Debuff\n%s lowers the target's %s by %d." % [
				String(mv.get("name", "This move")), debuff.capitalize(), int(mv.get("amount", 0)),
			])
		var acc_mod := int(mv.get("acc_mod", 0))
		if acc_mod != 0:
			sections.append("Accuracy\nThis move's own Accuracy for this one turn is %s by %d, %s." % [
				"boosted" if acc_mod > 0 else "reduced", absi(acc_mod),
				"making it much harder to dodge" if acc_mod > 0 else "making it more likely to miss",
			])
	return "\n\n".join(sections)

# "Strength" for a 1x-Strength move (Electric Touch/Scuba Stabbing/Multiple
# Knee Combo), "Strength plus Accuracy" for a move whose formula draws on
# more than one stat (Axe Kick) - named lower-case, mid-sentence, matching
# how the user-facing wording reads ("...equal to Maxilani's strength"),
# not the all-caps "STR"/"ACC" abbreviations the button/badge use, which
# are a UI-space constraint this full sentence doesn't have.
func _formula_damage_sentence(caster_name: String, formula: Dictionary, target: String) -> String:
	var stat_labels: Array[String] = []
	for key in ["strength", "accuracy", "agility", "evasion", "defense"]:
		if formula.has(key):
			stat_labels.append(key)
	var stat_text := " plus ".join(stat_labels) if not stat_labels.is_empty() else "power"
	var scope_text := " to all enemies" if target == "all_enemies" else ""
	return "This move deals damage equal to %s's %s%s." % [caster_name, stat_text, scope_text]

# Mirrors content/combat_moves.gd's own "combine ACC/EVA into one line when
# they match" rule (_resolved_legacy_hint()/resolved_hint()'s cost
# formatting), so this sentence and the button's own on-screen cost never
# describe the same number two different ways.
func _self_cost_sentence(effect: Dictionary) -> String:
	var acc := int(effect.get("accuracy", 0))
	var eva := int(effect.get("evasion", 0))
	var cost_parts: Array[String] = []
	if acc != 0 and acc == eva:
		cost_parts.append("ACC/EVA %s%d" % ["+" if acc > 0 else "", acc])
	else:
		if acc != 0:
			cost_parts.append("ACC %s%d" % ["+" if acc > 0 else "", acc])
		if eva != 0:
			cost_parts.append("EVA %s%d" % ["+" if eva > 0 else "", eva])
	var cost_text := ", ".join(cost_parts) if not cost_parts.is_empty() else "nothing"
	return "The cost of casting this move is %s on the caster. This wears off automatically at the caster's own next turn." % cost_text

func _show_items() -> void:
	if _busy:
		return
	main_menu.visible = false
	_populate_item_menu()
	item_menu.visible = true
	call_deferred("_fit_panel_height")

# Unlike _populate_move_menu(), this doesn't take an actor - items aren't
# owned by whoever's turn it is (see world.gd's shared, party-wide
# World.inventory), anyone can use any item on anyone. So there's no
# per-actor filtering here at all; that happens later, per-target, in
# _on_item_chosen() (Items.would_help() against each candidate target).
func _populate_item_menu() -> void:
	for b in item_buttons:
		(b as Button).queue_free()
	item_buttons.clear()
	if world != null:
		for item_id in world.inventory.keys():
			var count: int = int(world.inventory[item_id])
			if count <= 0:
				continue
			var def: Dictionary = Items.ITEMS.get(item_id, {})
			var b := _menu_button("%s (x%d)" % [String(def.get("display", item_id)), count],
				String(def.get("description", "")))
			b.pressed.connect(_on_item_chosen.bind(item_id))
			item_menu.add_child(b)
			item_buttons.append(b)
	# Keep Back last - same reason move_menu's own back_btn gets
	# re-positioned in _populate_move_menu(): it's a persistent child, not
	# rebuilt above, so re-adding fresh item buttons pushes it out of
	# place unless it's explicitly moved back to the end each time.
	item_menu.move_child(item_back_btn, item_menu.get_child_count() - 1)
	_place_skip_tutorial_btn_last(item_menu)

# heal/oxygen items only ever make sense on a living party member (a
# downed diver has no oxygen tank to top off) - _living(party) same as a
# heal move's own target pool. Filtered further
# by Items.would_help() per candidate, not by who's acting - an item
# isn't cast BY someone the way a move is, it's just applied TO someone,
# so there's no "does the acting diver have enough X" check the way
# _on_move_chosen() checks oxygen. If nobody would actually benefit, kick
# back to item_menu instead of opening an empty/useless target picker.
func _on_item_chosen(item_id: String) -> void:
	if _busy:
		return
	item_menu.visible = false
	var targets: Array = _living(party).filter(func(e: Dictionary) -> bool:
		return Items.would_help(item_id, e.stats as CombatantStats))
	if targets.is_empty():
		item_menu.visible = true
		call_deferred("_fit_panel_height")
		return
	_pending_item = item_id
	_populate_target_menu(targets)
	target_menu.visible = true
	call_deferred("_fit_panel_height")

# Always succeeds, no accuracy roll - same as _apply_heal(), nothing about
# using an item on an ally is something they could evade.
# Mirrors _resolve_party_move()'s tail exactly (log, refresh bars, advance
# turn) so an item-use turn reads identically to a move turn.
func _resolve_item(item_id: String, target: Dictionary) -> void:
	if world == null:
		_advance_turn()
		return
	_busy = true
	_set_all_buttons(false)
	var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
	var kind := String(Items.ITEMS.get(item_id, {}).get("kind", ""))
	var amount := int(Items.ITEMS.get(item_id, {}).get("amount", 0))
	var msg := Items.grant(item_id, target.stats as CombatantStats)
	# MODIFIED (added): attack_up/defense_up are battle_only and only
	# supposed to last THIS fight - Items.grant() above already applied the
	# raw stat increase (same as any other consumable), so this just
	# remembers what to subtract back off before the battle actually ends
	# (see _revert_temp_buffs(), called from all three finished.emit()
	# sites). Recorded by field name rather than by item_id specifically,
	# so a future third "for this fight" stat item needs no changes here -
	# just another kind -> field mapping.
	var temp_field: String = {"attack_up": "strength", "defense_up": "defense"}.get(kind, "")
	if temp_field != "":
		_temp_buffs.append({"stats": target.stats, "field": temp_field, "amount": amount})
	var count: int = int(world.inventory.get(item_id, 0))
	world.inventory[item_id] = count - 1
	if world.inventory[item_id] <= 0:
		world.inventory.erase(item_id)
	_refresh_bar(target)
	_log(msg if msg != "" else "%s - nothing happened." % display)
	_finish_actor_turn(_acting)
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_advance_turn()

# Every attack_up/defense_up applied so far this battle, as {stats, field,
# amount} - see _resolve_item() above for how entries get added, and
# _revert_temp_buffs() for how they come back off. A plain Array rather
# than keying by `stats` directly, since the same diver could use more
# than one of these across a single fight and each application needs its
# own amount subtracted back off independently.
var _temp_buffs: Array[Dictionary] = []

# Called from every one of this battle's three end points (_win(), _lose(),
# the flee handler) right before finished.emit() - a temporary buff is
# scoped to THIS fight specifically, so it needs to come back off no
# matter how the fight actually ends, not just on a win. Reads `field`
# dynamically via CombatantStats.set()/get() rather than a match on
# "strength"/"defense" by name, so adding a third temp-buffable field
# later needs no changes here.
func _revert_temp_buffs() -> void:
	for entry in _temp_buffs:
		var s := entry.stats as CombatantStats
		if s == null:
			continue
		var field := String(entry.field)
		s.set(field, int(s.get(field)) - int(entry.amount))
	_temp_buffs.clear()

func _show_main() -> void:
	if _busy:
		return
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	main_menu.visible = true
	_place_skip_tutorial_btn_last(main_menu)
	_selected_move_name.text = ""
	_selected_move_power.text = ""
	call_deferred("_fit_panel_height")

# Every effect still gets a target list rather than an immediate resolve,
# so choosing a move always lands on a screen with Back rather than
# committing the instant it's picked. Heal targets a living ally (a
# downed one has nothing a heal can do for it - see _apply_revive() for
# that); revive
# targets a downed one specifically. Everything else still targets an
# enemy. Always shows the target picker, even for a single candidate
# (e.g. the common one-enemy fight) - that single extra button is what
# gives the player a Back to bail out on a move they picked by mistake
# (see target_back_btn/_show_moves_from_target_menu()); previously a
# lone target skipped straight to resolution with no way back at all. An
# empty pool (e.g. Revive with nobody actually down) just reopens the
# move menu instead of silently eating the button press.
func _on_move_chosen(mv: Dictionary) -> void:
	if _busy:
		return
	if (_acting.stats as CombatantStats).oxygen < float(mv.get("oxygen_cost", 0.0)):
		return
	move_menu.visible = false
	var effect := String(mv.get("effect", ""))
	var targets: Array
	match effect:
		"heal":
			targets = _living(party)
		"revive":
			targets = party.filter(func(e: Dictionary) -> bool: return (e.stats as CombatantStats).hp <= 0)
		_:
			targets = _living(enemies)

	if targets.is_empty():
		move_menu.visible = true
		call_deferred("_fit_panel_height")
		return
	_pending_move = mv
	# Name on the left, raw power right-aligned on the right - see
	# _selected_move_panel's own declaration. Cleared again in
	# _show_main()/_start_party_turn(). Heal/revive have no "power" concept,
	# so the amount goes in the name slot instead and the power slot stays
	# blank rather than showing a misleading 0.
	_selected_move_name.text = String(mv.name)
	if effect == "heal" or effect == "revive":
		_selected_move_name.text = "%s - restores %d HP" % [String(mv.name), int(mv.get("amount", 0))]
		_selected_move_power.text = ""
	else:
		_selected_move_power.text = str(_preview_raw_power(mv, _acting.stats as CombatantStats))
	if String(mv.get("target", "one_enemy")) == "all_enemies":
		_populate_all_target_menu(targets)
	else:
		_populate_target_menu(targets)
	target_menu.visible = true
	call_deferred("_fit_panel_height")
	# Only on the scripted diver's own forced move (never heal/revive,
	# whose targets are allies rather than the enemy these explanations are
	# actually about) - stage 0 (Maxilani/Electric Touch) gets the full
	# dodging/evasion/damage walkthrough, stage 1 (Musashi/Precise Tap)
	# gets the shorter accuracy-boost one, stage 2 (Mech Pilot/Crushing
	# Haymaker) gets the accuracy-cost one, stage 3 (Musashi again/Weaken)
	# gets the no-damage-just-a-stat one, stage 4 (Maxilani again/Flash
	# Blast) gets the status-condition one. Any scripted diver picking a
	# move on some later un-scripted turn never reaches here at all.
	if _is_tutorial_scripted_turn(_acting) and effect not in ["heal", "revive"] and not targets.is_empty():
		if _tutorial_step == 0:
			await _explain_dodging(targets[0] as Dictionary)
		elif _tutorial_step == 1:
			await _explain_precise_tap(targets[0] as Dictionary)
		elif _tutorial_step == 2:
			await _explain_crushing_haymaker(targets[0] as Dictionary)
		elif _tutorial_step == 3:
			await _explain_weaken(targets[0] as Dictionary)
		elif _tutorial_step == 4:
			await _explain_flash_blast(targets[0] as Dictionary)

# Two beats, not one: first "hover over the enemy" (with the enemy button
# itself flashing and nothing clickable - disabled buttons still fire
# mouse_entered/exited in Godot, so hovering works fine while locked), THEN
# - only once that hover actually happens - the stat comparison and boxed
# ACC/EVA rows, held up with _tutorial_show_step()'s usual Enter-wait
# before anything becomes clickable again. Splitting it this way means the
# player has to actually go looking at the enemy before the payoff shows,
# rather than having it dumped on them the instant the target menu opens.
func _explain_dodging(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true

	# Tutorial fight is strictly 1v1, so target_buttons[0] is always the
	# one enemy button - same assumption _tutorial_prep_enemy_turn() and
	# render_light_beam()'s solo goblin already make.
	var enemy_btn := target_buttons[0] as Button
	var flash := create_tween()
	flash.set_loops()
	flash.tween_property(enemy_btn, "modulate", Color(1.0, 0.85, 0.25), 0.4)
	flash.tween_property(enemy_btn, "modulate", Color.WHITE, 0.4)

	_tutorial_caption.text = "Hover over the enemy you want to attack to see the stat comparison."
	call_deferred("_fit_panel_height")

	# Waits on an actual hover, not Enter - _populate_target_menu() already
	# wired this same button's mouse_entered to _show_stat_preview(), so by
	# the time this fires the enemy panel/deltas are already showing.
	# `await` directly on the signal rather than a locally-captured flag in
	# a polling loop - GDScript lambdas capture local variables BY VALUE,
	# so a `func(): hovered = true` closure only ever mutates its own private
	# copy, never the outer scope's - a `while not hovered:` loop built that
	# way spins forever no matter how many times the button's hovered.
	await enemy_btn.mouse_entered

	flash.kill()
	enemy_btn.modulate = Color.WHITE
	# From here on a stray mouse_exited (reading the caption pulls the
	# mouse off this small button) must not yank the panel away mid-explanation.
	_stat_preview_frozen = true

	await _tutorial_show_step(
		TutorialContent.page_body("Dodging: Accuracy vs. Evasion"),
		func() -> void:
			_set_row_highlight(_player_stats_ui.rows.ACC as PanelContainer, true)
			_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, true)
	)
	_set_row_highlight(_player_stats_ui.rows.ACC as PanelContainer, false)
	_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, false)
	# Then the evasion-reduction callout, then Damage: Attack vs. Defense -
	# same preview still up throughout; target buttons/Back stay disabled
	# the whole way through, right until _explain_click_to_attack() at the
	# very end finally re-enables them.
	await _explain_evasion_reduction(enemy)
	await _explain_damage(enemy)
	await _explain_click_to_attack(enemy)

# Calls out specifically why the enemy's EVA number is already showing red
# with a white delta (from _show_stat_preview(), still up since
# _explain_dodging() started it) - Electric Touch's own reduce_evasion
# effect - rather than leaving the player to notice it unexplained amid
# everything else on screen.
func _explain_evasion_reduction(enemy: Dictionary) -> void:
	var move_name := String(_pending_move.name)
	var enemy_name := String(enemy.get("display_name", "the enemy"))
	var delta := int((stat_effects.get(move_name, {}) as Dictionary).get("enemy", {}).get("evasion", 0))
	var delta_text := ("+%d" % delta) if delta > 0 else str(delta)
	await _tutorial_show_step(
		"%s will lower %s's Evasion - that's why its EVA number is shown in [color=%s]red[/color], with the white (%s) next to it showing exactly how much. A stat shown in [color=%s]red[/color] means its total went down; a stat shown in [color=%s]green[/color] means its total went up." % [
			move_name, enemy_name, STAT_COLOR_DOWN.to_html(false), delta_text,
			STAT_COLOR_DOWN.to_html(false), STAT_COLOR_UP.to_html(false),
		],
		func() -> void:
			_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, true)
	)
	_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, false)

# A staged reveal, not one flat caption: first the move's own raw power
# (already sitting right-aligned above the stat panels - see
# _selected_move_power/_add_power_badge()) gets boxed on its own while the
# text names it, THEN - after a beat, not another Enter press - STR/DEF
# also light up as the text extends into the full "power vs. defense"
# comparison, finishing on the actual computed total (_preview_damage() -
# the same deterministic, no-variance baseline shown on the move button
# itself). Reuses the same stat preview _explain_dodging() already started
# (both moves' worth of stat_effects deltas came from one
# _show_stat_preview() call), so this only ever adds highlights/text to
# what's already showing, never rebuilds it. One Enter-gate at the very
# end, once the whole explanation is on screen.
func _explain_damage(enemy: Dictionary) -> void:
	var attacker := _acting.stats as CombatantStats
	var defender := enemy.stats as CombatantStats
	var base_power := _move_base_power(_pending_move)
	var total := _preview_damage(_pending_move, attacker, defender)
	var move_name := String(_pending_move.name)
	var attacker_name := String(_acting.display_name)
	var enemy_name := String(enemy.get("display_name", "the enemy"))

	_set_row_highlight(_selected_move_panel, true)
	call_deferred("_fit_panel_height")
	await get_tree().create_timer(1.4).timeout

	_set_row_highlight(_player_stats_ui.rows.STR as PanelContainer, true)
	_set_row_highlight(_enemy_stats_ui.rows.DEF as PanelContainer, true)
	await _tutorial_show_step(
		"%s's own power is %d. This raw power number is shown in yellow at the top-right of its attack menu button before any stats are added. Add %s's Strength, then subtract %s's Defense (1-1 = 0), and this attack will deal %d damage." % [
			move_name, base_power, attacker_name, enemy_name, total,
		]
	)
	_set_row_highlight(_selected_move_panel, false)
	_set_row_highlight(_player_stats_ui.rows.STR as PanelContainer, false)
	_set_row_highlight(_enemy_stats_ui.rows.DEF as PanelContainer, false)

# Explanation's over - now tell the player what to actually do with it.
# Re-flashes the enemy button (target buttons are still disabled from
# _explain_dodging()) and waits for the real click rather than another
# Enter press, since clicking IS the action being asked for. That real
# click already resolves the move through the normal _on_target_chosen()
# wiring on its own; this just cleans up the flash/preview state once it
# happens; awaiting the button's own `pressed` signal lets both run
# concurrently without one blocking the other. `label_override`, if given,
# names the button instead of the enemy - _explain_flash_blast() needs
# this since _populate_all_target_menu() builds a single "All enemies"
# button rather than one button per enemy, so "Click the highlighted
# Grunt" would name something that isn't actually on the button.
func _explain_click_to_attack(enemy: Dictionary, label_override: String = "") -> void:
	var enemy_btn := target_buttons[0] as Button
	var label := label_override if label_override != "" else String(enemy.get("display_name", "the enemy"))
	var flash := create_tween()
	flash.set_loops()
	flash.tween_property(enemy_btn, "modulate", Color(1.0, 0.85, 0.25), 0.4)
	flash.tween_property(enemy_btn, "modulate", Color.WHITE, 0.4)
	_tutorial_caption.text = "Click the highlighted %s to attack." % label
	call_deferred("_fit_panel_height")
	# Only the flashing button itself - target_back_btn (and, in the
	# all_enemies case, any OTHER target_buttons entry) stay disabled, so
	# the only thing clickable during this prompt is the one thing it's
	# actually asking for.
	enemy_btn.disabled = false
	await enemy_btn.pressed
	flash.kill()
	_stat_preview_frozen = false
	_clear_stat_preview()

# Musashi's own scripted turn (_tutorial_step == 1) - same hover-then-
# explain shape as _explain_dodging(), but Precise Tap's payoff is
# different: its acc_mod (see BASE_MOVES) is already read by _ready()'s
# stat_effects loop as a player-side accuracy delta, so _show_stat_preview()
# (already fired by the hover, same as any other move) is already showing
# Musashi's ACC row green with a "(+9)" - this just boxes that row and
# explains what it actually means. acc_mod only affects THIS one attack's
# hit-chance roll, never Musashi's persistent Accuracy stat, but since a
# turn here IS one single move, "for this one turn" and "for this one
# attack" describe the exact same duration - there's no inaccuracy in
# saying it the simpler way.
func _explain_precise_tap(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true

	var enemy_btn := target_buttons[0] as Button
	var flash := create_tween()
	flash.set_loops()
	flash.tween_property(enemy_btn, "modulate", Color(1.0, 0.85, 0.25), 0.4)
	flash.tween_property(enemy_btn, "modulate", Color.WHITE, 0.4)

	_tutorial_caption.text = "Hover over the enemy you want to attack to see the stat comparison."
	call_deferred("_fit_panel_height")
	await enemy_btn.mouse_entered

	flash.kill()
	enemy_btn.modulate = Color.WHITE
	_stat_preview_frozen = true

	await _tutorial_show_step(
		"Precise Tap temporarily boosts %s's Accuracy stat for this one turn, making the attack much harder to dodge - that's why its ACC number is shown in [color=%s]green[/color], with the white (+X) next to it showing the increase." % [
			String(_acting.display_name), STAT_COLOR_UP.to_html(false),
		],
		func() -> void:
			_set_row_highlight(_player_stats_ui.rows.ACC as PanelContainer, true)
	)
	_set_row_highlight(_player_stats_ui.rows.ACC as PanelContainer, false)
	await _explain_click_to_attack(enemy)

# Mech Pilot's own scripted turn (_tutorial_step == 2) - same hover-then-
# explain shape as _explain_dodging()/_explain_precise_tap(), but Crushing
# Haymaker's payoff runs the opposite direction from Precise Tap's: its
# acc_mod (see BASE_MOVES) is a negative player-side accuracy delta, so
# _show_stat_preview() (already fired by the hover) is already showing the
# Mech Pilot's own ACC row red with a "(-3)" - this just boxes that row and
# explains why a move can cost its own user accuracy, then calls out the
# counter-play: pairing a heavy, less-accurate swing like this one with
# something that lowers the TARGET's Evasion first (Electric Touch, which
# _explain_evasion_reduction() already covered as a lasting-for-the-fight
# reduction, not a one-turn dip) buys back the accuracy this move gives up.
func _explain_crushing_haymaker(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true
	# See TUTORIAL_HAYMAKER_DODGE_EVASION's own comment - pinned here,
	# before the player can even click, so the swing they're about to
	# throw is guaranteed to whiff on its own accuracy penalty.
	(enemy.stats as CombatantStats).evasion_current = TUTORIAL_HAYMAKER_DODGE_EVASION

	var enemy_btn := target_buttons[0] as Button
	var flash := create_tween()
	flash.set_loops()
	flash.tween_property(enemy_btn, "modulate", Color(1.0, 0.85, 0.25), 0.4)
	flash.tween_property(enemy_btn, "modulate", Color.WHITE, 0.4)

	_tutorial_caption.text = "Hover over the enemy you want to attack to see the stat comparison."
	call_deferred("_fit_panel_height")
	await enemy_btn.mouse_entered

	flash.kill()
	enemy_btn.modulate = Color.WHITE
	_stat_preview_frozen = true

	await _tutorial_show_step(
		"Crushing Haymaker trades away some of %s's own Accuracy for a much bigger hit - that's why its ACC number is shown in [color=%s]red[/color], with the white (-3) next to it showing the cost. Some attacks are simply too heavy to throw with your usual precision. Pair a swing like this with something that weakens the target first: Electric Touch, for one, lowers an enemy's Evasion for the rest of the fight, so a harder-to-land hit like this one still connects." % [
			String(_acting.display_name), STAT_COLOR_DOWN.to_html(false),
		],
		func() -> void:
			_set_row_highlight(_player_stats_ui.rows.ACC as PanelContainer, true)
	)
	_set_row_highlight(_player_stats_ui.rows.ACC as PanelContainer, false)
	await _explain_click_to_attack(enemy)

# Musashi's SECOND scripted turn (_tutorial_step == 3) - same hover-then-
# explain shape as the other three, but Weaken's payoff isn't about a
# number changing on Musashi's own side at all: its power is 0, so it
# deals no damage whatsoever, only applying "defense" to the target's own
# stats (see BASE_MOVES' "Prototype_1(1910)" entry and _apply_debuff()).
# That's why this one boxes the ENEMY's DEF row instead of one of
# Musashi's - the whole point is a move that does nothing but move a
# stat.
func _explain_weaken(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true

	var enemy_btn := target_buttons[0] as Button
	var flash := create_tween()
	flash.set_loops()
	flash.tween_property(enemy_btn, "modulate", Color(1.0, 0.85, 0.25), 0.4)
	flash.tween_property(enemy_btn, "modulate", Color.WHITE, 0.4)

	_tutorial_caption.text = "Hover over the enemy you want to attack to see the stat comparison."
	call_deferred("_fit_panel_height")
	await enemy_btn.mouse_entered

	flash.kill()
	enemy_btn.modulate = Color.WHITE
	_stat_preview_frozen = true

	var enemy_name := String(enemy.get("display_name", "the enemy"))
	await _tutorial_show_step(
		"Weaken deals no damage at all - its power is 0, so there's nothing to subtract from %s's HP. What it does instead is lower their Defense, which is why its DEF number is shown in [color=%s]red[/color], with the white (-2) next to it. Some moves only ever affect an enemy's stats like this, with no damage of their own, but they're worth using to weaken enemies for greater party hits." % [
			enemy_name, STAT_COLOR_DOWN.to_html(false),
		],
		func() -> void:
			_set_row_highlight(_enemy_stats_ui.rows.DEF as PanelContainer, true)
	)
	_set_row_highlight(_enemy_stats_ui.rows.DEF as PanelContainer, false)
	await _explain_click_to_attack(enemy)

# Maxilani's SECOND scripted turn (_tutorial_step == 4) - Flash Blast is
# "all_enemies" (see BASE_MOVES' "Staff_Diver" entry, which is CombatMoves.
# SCUBA), so _on_move_chosen() built target_menu via _populate_all_target_
# menu() instead of _populate_target_menu(): target_buttons has exactly
# one "All enemies" button rather than one per enemy (there's only the one
# goblin here anyway, so the practical difference is just the button's
# label). Its hover still fires _show_stat_preview() the same way, and
# _ready()'s stat_effects loop mirrors Blindness's level onto the enemy's
# ACC and DEF rows specifically (see that loop's own comment on why -
# Blindness has no row of its own), so both light up red here same as any
# other reduction. First non-single-target move the script demonstrates,
# and the first status condition rather than a stat directly attached to
# one side of the fight - worth pointing at Combat Help for the rest of
# what status conditions exist rather than listing them all in one caption.
func _explain_flash_blast(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true
	# Same pin as _explain_crushing_haymaker(), same value - low enough
	# that Flash Blast's plain accuracy (no acc_mod of its own, unlike
	# Crushing Haymaker) still beats it and lands for real. See
	# TUTORIAL_HAYMAKER_DODGE_EVASION's own comment for the actual numbers.
	(enemy.stats as CombatantStats).evasion_current = TUTORIAL_HAYMAKER_DODGE_EVASION

	var enemy_btn := target_buttons[0] as Button
	var flash := create_tween()
	flash.set_loops()
	flash.tween_property(enemy_btn, "modulate", Color(1.0, 0.85, 0.25), 0.4)
	flash.tween_property(enemy_btn, "modulate", Color.WHITE, 0.4)

	_tutorial_caption.text = "Hover over the highlighted button to see what Flash Blast does."
	call_deferred("_fit_panel_height")
	await enemy_btn.mouse_entered

	flash.kill()
	enemy_btn.modulate = Color.WHITE
	_stat_preview_frozen = true

	await _tutorial_show_step(
		"Flash Blast deals no damage either, same as Weaken - instead it hits every enemy at once with a status called Blindness, which lowers Agility, Accuracy, and Defense all by the same amount at once. That's why the enemy's ACC and DEF numbers are both shown in [color=%s]red[/color] here: lower Accuracy means their own attacks miss more, and lower Defense means your hits deal more damage to them. Flash Blast subtracts 2 from all three, for as many turns as %s's own Accuracy. Blindness is only one of several status conditions moves can inflict - hover over any attack that names one on its own button (like Scuba Stabbing's Bleed) to see exactly what it does, or find full details on all of them, including ones not shown in this fight, from the Combat Help tab of the Esc menu out in the world." % [
			STAT_COLOR_DOWN.to_html(false), String(_acting.display_name),
		],
		func() -> void:
			_set_row_highlight(_enemy_stats_ui.rows.ACC as PanelContainer, true)
			_set_row_highlight(_enemy_stats_ui.rows.DEF as PanelContainer, true)
	)
	_set_row_highlight(_enemy_stats_ui.rows.ACC as PanelContainer, false)
	_set_row_highlight(_enemy_stats_ui.rows.DEF as PanelContainer, false)
	await _explain_click_to_attack(enemy, "All enemies")

# Fires once, right after the player's first move actually resolves (see
# _resolve_party_move()/_resolve_party_move_all()) - unlike the move
# gate/dodging/damage steps, this isn't gating an action (the move already
# happened), so nothing needs disabling here. Boxes party[0]'s and
# enemies[0]'s whole status card (name/HP/oxygen/EVA together, not just
# HP) via _set_row_highlight() - now that status cards sit fixed in the
# side columns instead of floating over each combatant, this is a plain
# border toggle, not a per-frame repositioned overlay.
func _explain_other_stats() -> void:
	var player_card: PanelContainer = (party[0].card as PanelContainer) if not party.is_empty() else null
	var enemy_card: PanelContainer = (enemies[0].card as PanelContainer) if not enemies.is_empty() else null
	# The purple-box callout is added here, in code, rather than baked into
	# TutorialContent's shared page body - that same "Every Other Stat"
	# text is also what the F1 general tutorial book shows outside of any
	# fight, where "the status panels on either side" wouldn't mean anything.
	var text := "HP is highlighted in purple in the status panels on either side - your party's on the left, the enemies' on the right. %s" % TutorialContent.page_body("Every Other Stat")
	await _tutorial_show_step(
		text,
		func() -> void:
			if player_card != null:
				_set_row_highlight(player_card, true, Color(0.65, 0.3, 0.9))
			if enemy_card != null:
				_set_row_highlight(enemy_card, true, Color(0.65, 0.3, 0.9))
	)
	if player_card != null:
		_set_row_highlight(player_card, false)
	if enemy_card != null:
		_set_row_highlight(enemy_card, false)

func _populate_all_target_menu(targets: Array) -> void:
	for b in target_buttons:
		(b as Button).queue_free()
	target_buttons.clear()
	var names: Array[String] = []
	for target in targets:
		names.append(String(target.display_name))
	var button := _menu_button("All enemies", ", ".join(names))
	button.pressed.connect(_on_all_targets_chosen.bind(targets))
	# "All enemies" only ever targets enemies (nothing heals/revives the
	# whole party at once), so previewing every one of them is always safe
	# here - unlike _populate_target_menu(), which is shared with heal/
	# revive's ally-targeting case. _show_all_stat_preview() builds one
	# panel per enemy rather than only the first, since the move is about
	# to hit all of them at once.
	if not targets.is_empty():
		button.mouse_entered.connect(_show_all_stat_preview.bind(_pending_move, targets))
		button.mouse_exited.connect(_clear_all_stat_preview)
	target_menu.add_child(button)
	target_buttons.append(button)
	target_menu.move_child(target_back_btn, target_menu.get_child_count() - 1)
	_place_skip_tutorial_btn_last(target_menu)

func _populate_target_menu(targets: Array) -> void:
	for b in target_buttons:
		(b as Button).queue_free()
	target_buttons.clear()
	# Shared with heal/revive, whose targets are allies, not enemies - only
	# wire the hover preview for an actual attack/debuff against an enemy;
	# previewing "enemy" stat_effects on an ally would be meaningless.
	var previewable: bool = String(_pending_move.get("effect", "")) not in ["heal", "revive"]
	for t in targets:
		var s := t.stats as CombatantStats
		# MODIFIED (changed): an enemy target's hint now shows only EVA (its
		# dodge-resource current/max) and HP, EVA first - DEF/ACC dropped as
		# clutter. Ally targets (heal/revive) keep the full readout unchanged.
		var hint := ("EVA %d/%d  HP %d/%d" % [s.evasion_current, s.effective_evasion(), s.hp, s.hp_max]) if String(t.kind) == "enemy" else (
			"HP %d/%d  DEF %d  EVA %d/%d  ACC %d" % [
				s.hp, s.hp_max, s.effective_defense(), s.evasion_current,
				s.effective_evasion(), s.effective_accuracy(),
			])
		var b := _menu_button(String(t.display_name), hint)
		b.pressed.connect(_on_target_chosen.bind(t))
		if previewable:
			b.mouse_entered.connect(_show_stat_preview.bind(_pending_move, t))
			b.mouse_exited.connect(_clear_stat_preview)
		target_menu.add_child(b)
		target_buttons.append(b)
	# Keep Back last - same reason move_menu's own back_btn gets
	# re-positioned in _populate_move_menu(): it's a persistent child, not
	# rebuilt above, so re-adding fresh target buttons pushes it out of
	# place unless it's explicitly moved back to the end each time.
	target_menu.move_child(target_back_btn, target_menu.get_child_count() - 1)
	_place_skip_tutorial_btn_last(target_menu)

# Exactly one of _pending_move/_pending_item is ever set when target_menu
# is showing (see _on_move_chosen()/_on_item_chosen()) - branch on which,
# resolve it, then clear both so a stale pending value can never leak into
# the next turn's target picker.
func _on_target_chosen(target: Dictionary) -> void:
	target_menu.visible = false
	_clear_stat_preview()
	if _pending_item != "":
		var item_id := _pending_item
		_pending_item = ""
		_resolve_item(item_id, target)
		return
	_resolve_party_move(_pending_move, target)

func _on_all_targets_chosen(targets: Array) -> void:
	target_menu.visible = false
	_clear_stat_preview()
	var move := _pending_move
	_pending_move = {}
	_resolve_party_move_all(move, targets)

# No cost has actually been spent yet at this point - _on_move_chosen()/
# _on_item_chosen() only check whether the move's affordable/the item
# would help, the real deduction happens once a target's actually been
# resolved against (_resolve_party_move()/_resolve_item()) - so backing
# out here is free, nothing to refund either way.
#
# Routes to whichever menu actually opened the target picker, based on
# the same _pending_item/_pending_move split _on_target_chosen() reads -
# used to be hardwired to move_menu alone (_show_moves_from_target_menu),
# which sent an item's Back to the wrong screen.
func _show_moves_or_items_from_target_menu() -> void:
	if _busy:
		return
	target_menu.visible = false
	_clear_stat_preview()
	if _pending_item != "":
		_pending_item = ""
		item_menu.visible = true
	else:
		_pending_move = {}
		move_menu.visible = true
	call_deferred("_fit_panel_height")

# One damage/effect roll, used identically for the player's moves and the
# grunt's counter - stats (not separate formulas per side) are what make
# the two feel different.
#
# Resolution order:
#  1. Hit/miss is a flat comparison, not a roll: attacker.accuracy plus
#     this move's own acc_mod against defender.evasion. Strictly greater
#     wins; a tie misses. No RNG here at all.
#  2. Power + strength, with damage variance (this is the only randomness
#     left in the whole resolve - whether you hit is deterministic, how
#     hard is not).
#  3. Defense subtracts flat from that raw amount - can floor a hit at 0.
func _resolve_attack(attacker: CombatantStats, defender: CombatantStats, move: Dictionary) -> Dictionary:
	if move.has("formula"):
		# Authored enemy moves use the shared formula resolver. They still need
		# the same timing-dodge window as legacy power moves; returning directly
		# here used to bypass the QTE entirely, including the forced first-lesson
		# demonstration. Do not open a QTE for an attack that already lost the
		# ACC/EVA comparison—CombatRules owns that miss and Evasion spend.
		var formula_accuracy := attacker.effective_accuracy() + int(move.get("acc_mod", 0))
		if formula_accuracy <= defender.evasion_current:
			_tutorial_force_next_qte = false
			return CombatRules.resolve(attacker, defender, move)
		var formula_force_qte := _tutorial_force_next_qte
		_tutorial_force_next_qte = false
		var formula_dodge := false
		if bool(move.get("quick_time_bool", false)) and (formula_force_qte or randf() < ENEMY_QTE_CHANCE):
			if not formula_force_qte:
				await _tutorial_show_step("The enemy's attack triggers a quick time event! Be prepared to time a dodge.")
				_tutorial_caption.visible = false
				call_deferred("_fit_panel_height")
			formula_dodge = await _quick_time_event(_actor_for_stats(defender))
		return CombatRules.resolve(attacker, defender, move, true, formula_dodge)
	var effective_accuracy: int = attacker.effective_accuracy() + int(move.get("acc_mod", 0))
	if effective_accuracy <= defender.evasion_current:
		var spent := defender.spend_evasion(effective_accuracy)
		return {"hit": false, "damage": 0, "absorbed": 0, "debuff": "", "changed": 0, "dodged": false, "evasion_spent": spent, "effects": []}

	var debuff: String = String(move.get("debuff", ""))
	if debuff != "":
		return _apply_debuff(defender, debuff, int(move.get("amount", 0)))

	# Preserve the production RNG order: variance was sampled before the
	# heavy fraction and before the QTE prior to splitting out the deterministic
	# damage helper for the balance gate.
	var variance := randf_range(0.85, 1.15)
	var heavy_fraction := 0.0
	if String(move.get("effect", "")) == "heavy":
		heavy_fraction = randf_range(float(move.get("heavy_min", 0.25)), float(move.get("heavy_max", 0.5)))

	# MODIFIED: used to fire the QTE unconditionally whenever quick_time_bool
	# was set (which used to only ever be ENEMY_HEAVY_MOVE, making the QTE
	# 1:1 with the heavy swing specifically). Both enemy moves are eligible
	# now, and this is what actually decides whether one fires THIS time -
	# an independent ENEMY_QTE_CHANCE roll, same on either move. Player
	# moves never set quick_time_bool at all, so this is still a no-op for
	# anything the player swings themselves regardless. A successful dodge
	# zeroes incoming outright rather than reducing it.
	#
	# _tutorial_force_next_qte overrides that roll for the choreographed
	# first fight's one scripted enemy turn (see _tutorial_prep_enemy_
	# turn()) - consumed (reset false) here unconditionally the instant
	# this runs, whether or not it actually ends up mattering this call, so
	# it can never leak into some later, real attack.
	var force_qte := _tutorial_force_next_qte
	_tutorial_force_next_qte = false
	var player_dodge := false
	if bool(move.get("quick_time_bool", false)) and (force_qte or randf() < ENEMY_QTE_CHANCE):
		# The forced tutorial swing (_tutorial_prep_enemy_turn()) already gets
		# its own dedicated, blocking explanation with the real QTE bar
		# embedded in it just before this - a second heads-up here would just
		# repeat that. Every other (real, organic) QTE never announced itself
		# at all before this; reuses the same "Press Enter to continue" gate
		# every tutorial caption already waits on (_tutorial_show_step()),
		# rather than a timed flash, so the player decides when they're ready
		# for the sweep bar instead of it starting on a fixed clock.
		if not force_qte:
			await _tutorial_show_step("The enemy's attack triggers a quick time event! Be prepared to time a dodge.")
			_tutorial_caption.visible = false
			call_deferred("_fit_panel_height")
		player_dodge = await _quick_time_event(_actor_for_stats(defender))

	return apply_damage_roll(attacker, defender, move, variance, heavy_fraction, player_dodge)

# The deterministic half of _resolve_attack(), shared with verify/balance.gd.
# Production samples the variance/heavy fraction and the QTE result above;
# the seeded balance gate supplies those same inputs itself. Keeping the actual
# mutation and mitigation here prevents a test-only copy of the combat math
# drifting away from what players receive.
static func apply_damage_roll(attacker: CombatantStats, defender: CombatantStats, move: Dictionary, variance: float, heavy_fraction: float = 0.0, dodged: bool = false) -> Dictionary:
	var effective_accuracy: int = attacker.effective_accuracy() + int(move.get("acc_mod", 0))
	if effective_accuracy <= defender.evasion_current:
		var spent := defender.spend_evasion(effective_accuracy)
		return {"hit": false, "damage": 0, "absorbed": 0, "debuff": "", "changed": 0, "dodged": false, "evasion_spent": spent, "effects": []}

	var raw: float
	if String(move.get("effect", "")) == "heavy":
		raw = float(defender.hp_max) * heavy_fraction
	else:
		raw = (float(move.power) + float(attacker.strength)) * variance
	var defense := 0 if bool(move.get("ignore_defense", false)) else defender.effective_defense()
	var incoming: int = maxi(0, int(round(raw)) - defense)
	if dodged:
		incoming = 0

	defender.hp = maxi(0, defender.hp - incoming)
	return {"hit": true, "damage": incoming, "absorbed": 0, "debuff": "", "changed": 0, "dodged": dodged, "evasion_spent": 0, "effects": []}

# Dispatches on the move's "effect" key before falling through to the
# normal attack/debuff resolution above. "heal"/"revive" (support-branch
# spells, see spell_tree.gd) target an ally instead of an enemy -
# `defender` here is really just "whoever _on_move_chosen()'s target
# picker resolved to," which for these two effects is a living or downed
# ally respectively, not literally a defender - and both always succeed:
# nothing about mending a wound is something the ally being healed could
# fail to receive.
func _resolve_move(attacker: CombatantStats, defender: CombatantStats, move: Dictionary) -> Dictionary:
	var effect := String(move.get("effect", ""))
	if effect == "heal":
		return _apply_heal(defender, int(move.get("amount", 0)))
	if effect == "revive":
		return _apply_revive(defender, int(move.get("amount", 0)))
	return await _resolve_attack(attacker, defender, move)

# Restores flat `amount` HP, capped at hp_max - only ever called with a
# living ally as the target (see _on_move_chosen()'s "heal" target pool),
# reviving a downed ally is _apply_revive()'s job specifically, not an
# edge case of this one.
func _apply_heal(target: CombatantStats, amount: int) -> Dictionary:
	var before := target.hp
	target.hp = mini(target.hp_max, target.hp + amount)
	var changed := target.hp - before
	return {"hit": true, "damage": 0, "absorbed": 0, "debuff": "heal", "changed": changed}

# Only ever called on a downed ally (see _on_move_chosen()'s "revive"
# target pool, which only ever lists party members at 0 HP) - amount is
# how much HP they come back with, not a bonus added on top of whatever
# they had, since a downed target always has exactly 0. Capped at hp_max
# same as a heal, in case amount was ever tuned above what a low-level
# reviver's hp_max could actually hold.
func _apply_revive(target: CombatantStats, amount: int) -> Dictionary:
	target.hp = mini(target.hp_max, amount)
	return {"hit": true, "damage": 0, "absorbed": 0, "debuff": "revive", "changed": target.hp}

# Directly mutates the target's CombatantStats. Safe for enemies (rebuilt
# fresh every battle, so nothing to reset after); safe for party members
# too, since CombatantStats.fill() on the next level-up resets everything
# a debuff could have touched, and nothing persists a mid-battle debuff
# past the fight ending. Floored so repeated use has a hard ceiling:
# defense/accuracy can't go below 0, agility can't go below 1 (0 agility
# would make "who goes first" meaningless rather than just "always last").
# `changed` is how much actually moved - 0 once a stat's already at its
# floor, so the log can say so instead of claiming points came off a stat
# that had none left to lose.
# MODIFIED (changed): each floor used to be a flat, stat-wide minimum (0,
# or 1 for agility) regardless of who was being debuffed. Now reads
# defender.stat_floor first - an enemy's own real, un-boosted BASE_STATS
# (see Goblin._stats_from()), so Weaken/Slow can strip this fight's random
# boost back off but never cut into the species' own true stat. A Diver's
# stat_floor is always empty (nothing debuffs a diver today), so this falls
# back to the exact same flat minimums as before for that case.
func _apply_debuff(defender: CombatantStats, debuff: String, amount: int) -> Dictionary:
	var changed := 0
	match debuff:
		"defense":
			var before := defender.defense
			defender.defense = maxi(int(defender.stat_floor.get("defense", 0)), defender.defense - amount)
			changed = before - defender.defense
		"agility":
			var before := defender.agility
			defender.agility = maxi(int(defender.stat_floor.get("agility", 1)), defender.agility - amount)
			changed = before - defender.agility
		"accuracy":
			var before := defender.accuracy
			defender.accuracy = maxi(int(defender.stat_floor.get("accuracy", 0)), defender.accuracy - amount)
			changed = before - defender.accuracy
		"strength":
			var before := defender.strength
			defender.strength = maxi(int(defender.stat_floor.get("strength", 0)), defender.strength - amount)
			changed = before - defender.strength
		"evasion":
			var before := defender.evasion
			defender.evasion = maxi(int(defender.stat_floor.get("evasion", 0)), defender.evasion - amount)
			changed = before - defender.evasion
	return {"hit": true, "damage": 0, "absorbed": 0, "debuff": debuff, "changed": changed}

func _log_player_result(actor: Dictionary, target: Dictionary, mv: Dictionary, r: Dictionary) -> void:
	var text: String = String(mv.get("text", "You use %s" % String(mv.name)))
	if not r.hit:
		_log("%s - %s evades!" % [text, String(target.display_name)])
		return
	if String(r.debuff) == "heal":
		if int(r.changed) > 0:
			_log("%s - %s recovers %d HP." % [text, String(target.display_name), int(r.changed)])
		else:
			_log("%s - %s is already at full health." % [text, String(target.display_name)])
		return
	if String(r.debuff) == "revive":
		_log("%s - %s is back on their feet with %d HP!" % [text, String(target.display_name), int(r.changed)])
		return
	if String(r.debuff) != "":
		if int(r.changed) > 0:
			_log("%s on %s by %d." % [text, String(target.display_name), int(r.changed)])
		else:
			# MODIFIED (changed): was the generic "has nothing left to lose
			# there" - now names which stat actually hit its floor
			# (_apply_debuff()'s own stat_floor clamp), matching how every
			# other result here names its own number instead of speaking in
			# the abstract.
			_log("This enemy's %s can't be lowered any further!" % String(r.debuff).capitalize())
		return
	_log("%s for %d." % [text, int(r.damage)])
	var effects := r.get("effects", []) as Array
	if not effects.is_empty():
		_log("%s  •  %s" % [_current_log_text(), ", ".join(effects)])

# Swing first, resolve at the moment of impact. Returns once the hit is
# supposed to land, leaving the rest of the clip to play out underneath the
# damage log. A move with no actor (a headless run, see verify/battle.gd)
# resolves instantly, so the gates are not paying for animation time.
# Step in, face them, swing, step back.
#
# Every attack used to play on the spot, facing whichever way the actor was
# built facing. Glass_Goat animated these for a 2D presentation, so a swing
# travels along the character's own forward axis and nowhere else: Marine
# Man's hammer reaches most of a body length forward and it was reaching
# into open water, because the grunt it was aimed at was off to one side.
# The animation was never going to aim itself. This aims the character.
func _swing(entry: Dictionary, mv: Dictionary, target: Dictionary = {}) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor) or not (entry.actor is Diver):
		return
	var d := entry.actor as Diver
	# Heal/revive target an ally, and allies stand in a row ~2.9m apart:
	# stepping to melee reach of a non-adjacent ally parked the caster right
	# on top of the diver standing between them. Support casts turn to face
	# the ally and cast from where they stand instead.
	var in_place := String(mv.get("effect", "")) in ["heal", "revive"]
	await _step_toward(entry, target, in_place)
	var length: float = d.play_clip(Cast.ability(String(entry.model_name), String(mv.get("name", ""))))
	if length <= 0.0:
		_send_home(entry, 0.0)
		return
	if target.has("actor") and is_instance_valid(target.actor) and target.actor is Node3D:
		player_swing_staged.emit(d, target.actor as Node3D)
	_audio_call(&"play_combat_swing", [_move_is_heavy(mv)])
	await get_tree().create_timer(length * IMPACT_FRACTION).timeout
	# The rest of the clip plays while the caller gets on with the damage
	# log, and the walk back starts when it finishes.
	_send_home(entry, length * (1.0 - IMPACT_FRACTION))

# Turn to face the target and close to within reach of it. Reach is a
# distance short of the target rather than the target itself, because these
# attacks have length: standing on top of somebody puts the swing through
# them and out the other side.
func _step_toward(entry: Dictionary, target: Dictionary, face_only: bool = false) -> void:
	var a: Node3D = entry.get("actor")
	if a == null or not is_instance_valid(a):
		return
	if not target.has("actor") or not is_instance_valid(target.actor) or target.actor == a:
		return
	var home: Vector3 = entry.get("home_pos", a.position)
	var to: Vector3 = (target.actor as Node3D).position - home
	to.y = 0.0
	if to.length() < 0.05:
		return
	# Divers use their local -Z front; Angler uses its local +Z front. The
	# actor owns this distinction so an asset swap cannot invert an attack.
	if a is Goblin:
		(a as Goblin).face_toward((target.actor as Node3D).global_position)
	else:
		a.rotation.y = atan2(-to.x, -to.z)
	if face_only:
		return
	var target_radius := 0.0
	var radius_value: Variant = (target.actor as Node3D).get("radius")
	if radius_value != null:
		target_radius = float(radius_value)
	var stand: Vector3 = (target.actor as Node3D).position - to.normalized() * (SWING_REACH + target_radius)
	stand.y = home.y
	var step := a.create_tween()
	step.tween_property(a, "position", stand, SWING_STEP_TIME)
	await step.finished

# Back to the spot on the line where this one belongs. Always to the stored
# home rather than to wherever it happened to start, so an interrupted
# swing cannot leave somebody drifting a metre further out every turn.
func _send_home(entry: Dictionary, delay: float) -> void:
	# Read through Variant first. Assigning a previously freed Object directly
	# to a typed Node3D local throws before is_instance_valid() can protect us.
	var actor_value: Variant = entry.get("actor")
	if actor_value == null or not is_instance_valid(actor_value):
		return
	var a := actor_value as Node3D
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		actor_value = entry.get("actor")
		if actor_value == null or not is_instance_valid(actor_value):
			return
		a = actor_value as Node3D
	var back := a.create_tween()
	back.tween_property(a, "position", entry.get("home_pos", a.position), SWING_STEP_TIME)
	back.parallel().tween_property(a, "rotation:y", float(entry.get("home_rot", a.rotation.y)), SWING_STEP_TIME)

# The recoil on whoever just got hit. Only for a hit that actually landed
# damage: a heal targets an ally, and flinching at being healed is worse
# than not reacting at all.
func _react(entry: Dictionary, r: Dictionary) -> void:
	if not bool(r.get("hit", false)) or int(r.get("damage", 0)) <= 0:
		return
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	if (entry.stats as CombatantStats).hp <= 0:
		return   # going down has its own animation, see play_death_fade()
	# Two reactions ship per character. "Heavy" is a hit worth a fifth of
	# what this one can take, so the big recoil means something rather than
	# being the one that always plays.
	var heavy: bool = float(r.damage) >= float((entry.stats as CombatantStats).hp_max) * 0.2
	if entry.actor is Diver:
		(entry.actor as Diver).play_hit_reaction(heavy)
	elif entry.actor is TethysBoss:
		(entry.actor as TethysBoss).play_hit_reaction(heavy)
	elif prologue_octopus_encounter and entry.actor.has_method("play"):
		entry.actor.call("play", "hurt")

func _play_enemy_death(entry: Dictionary) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	if entry.actor is Goblin:
		(entry.actor as Goblin).play_death_fade()
	elif entry.actor is TethysBoss:
		(entry.actor as TethysBoss).play_death()

func _play_enemy_hit(entry: Dictionary) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	# Tethys already received its authored weak/strong reaction in _react().
	# The Angler's own damaged clip replaces the retired Goblin walk recoil.
	if entry.actor is Goblin:
		(entry.actor as Goblin).play("hurt")

func _restore_enemy_idle(entry: Dictionary) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	if entry.actor is Goblin:
		(entry.actor as Goblin).play("idle")
	elif entry.actor is TethysBoss:
		(entry.actor as TethysBoss).play("idle")
	elif prologue_octopus_encounter and entry.actor.has_method("play"):
		entry.actor.call("play", "idle")

func _resolve_party_move(mv: Dictionary, target: Dictionary) -> void:
	if target.is_empty():
		_advance_turn()
		return
	_busy = true
	_set_all_buttons(false)

	(_acting.stats as CombatantStats).oxygen -= float(mv.get("oxygen_cost", 0.0))
	await _swing(_acting, mv, target)
	var r: Dictionary = await _resolve_move(_acting.stats, target.stats, mv)
	_react(target, r)
	_show_combat_feedback(target, r)
	var applied_effects := r.get("effects", []) as Array
	if r.hit and (String(r.debuff) == "agility" or applied_effects.any(func(effect: Variant) -> bool: return String(effect).begins_with("Blindness"))):
		_resort_pending()
	_refresh_bar(target)
	_refresh_bar(_acting)
	# MODIFIED (added): _refresh_bar() above only updates _acting's overhead
	# status card - the bottom "You" STR/DEF/ACC/EVA panel (_player_stats_ui)
	# was never refreshed after a move resolved at all, only once per turn
	# at _start_party_turn(). A self_temporary cost (Axe Kick/Multiple Knee
	# Combo's own EVA/ACC hit) was applying correctly to the real stats the
	# whole time, just invisibly - by the time that panel refreshed again on
	# this diver's own next turn, begin_turn() had already worn the cost
	# back off, so it never had a frame where a player could actually see it.
	_refresh_player_stats_panel()
	_log_player_result(_acting, target, mv, r)
	if prologue_octopus_encounter:
		print("PROLOGUE_HIT|move=%s|damage=%d|hit=%s|hp=%d|effects=%s" % [String(mv.name), int(r.damage), str(r.hit), (target.stats as CombatantStats).hp, str(r.get("effects", []))])
		_audio_call(&"duck_music", [-7.0, 0.25])
		_finish_actor_turn(_acting)
		await _resolve_prologue_finisher()
		return

	# A killing blow gets the fade instead of the usual walk/idle reaction -
	# a dying grunt shouldn't play a normal hit-react animation, the fade
	# itself is the reaction. _play_enemy_death()/_play_enemy_hit() only ever
	# act on a Goblin/TethysBoss actor (silent no-ops against a Diver
	# target), so a revive's own visual - the one case here that targets a
	# Diver - gets its own branch below instead.
	var target_died: bool = target.has("stats") and (target.stats as CombatantStats).hp <= 0
	if target_died:
		_play_enemy_death(target)
	elif r.hit and String(r.debuff) == "revive" and target.has("actor") and target.actor is Diver:
		(target.actor as Diver).play_revive()
	elif r.hit and String(r.debuff) == "":
		_play_enemy_hit(target)
	_finish_actor_turn(_acting)
	# Guarded on _is_tutorial_scripted_turn(), not just tutorial_encounter -
	# any diver whose scripted stage has already passed (e.g. Maxilani
	# resolving a second, un-scripted move later in the fight) can still act
	# completely normally while _tutorial_step has moved on to a later
	# diver; without this check that move would wrongly count as the
	# scripted one and skip a diver's turn in the script entirely.
	if _is_tutorial_scripted_turn(_acting):
		if _tutorial_step == 0:
			await _explain_other_stats()
		_tutorial_step += 1
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	if not target_died:
		_restore_enemy_idle(target)
	_advance_turn()

func _resolve_party_move_all(mv: Dictionary, targets: Array) -> void:
	if targets.is_empty():
		_advance_turn()
		return
	_busy = true
	_set_all_buttons(false)
	(_acting.stats as CombatantStats).oxygen -= float(mv.get("oxygen_cost", 0.0))
	# A move that hits everything still steps toward the first of them,
	# so the swing is aimed into the group rather than past it.
	await _swing(_acting, mv, targets[0] as Dictionary)
	var summaries: Array[String] = []
	var first := true
	var changed_agility := false
	for target in targets:
		if (target.stats as CombatantStats).hp <= 0:
			continue
		var result := CombatRules.resolve(_acting.stats as CombatantStats, target.stats as CombatantStats, mv, first)
		if prologue_octopus_encounter:
			print("PROLOGUE_HIT|move=%s|damage=%d|hit=%s|hp=%d|effects=%s" % [String(mv.name), int(result.damage), str(result.hit), (target.stats as CombatantStats).hp, str(result.get("effects", []))])
		first = false
		changed_agility = changed_agility or (result.get("effects", []) as Array).any(
			func(effect: Variant) -> bool: return String(effect).begins_with("Blindness"))
		_react(target, result)
		_show_combat_feedback(target, result)
		_refresh_bar(target)
		if not result.hit:
			summaries.append("%s dodges" % String(target.display_name))
		elif int(result.damage) > 0:
			summaries.append("%s -%d" % [String(target.display_name), int(result.damage)])
		else:
			summaries.append("%s affected" % String(target.display_name))
		if (target.stats as CombatantStats).hp <= 0:
			_play_enemy_death(target)
	if changed_agility:
		_resort_pending()
	_log("%s: %s." % [String(mv.get("name", "Move")), "; ".join(summaries)])
	_refresh_bar(_acting)
	# Same "the bottom 'You' panel never saw a self_temporary cost land"
	# fix as _resolve_party_move()'s own copy just above - Multiple Knee
	# Combo carries the exact same kind of cost Axe Kick does.
	_refresh_player_stats_panel()
	_finish_actor_turn(_acting)
	if prologue_octopus_encounter:
		_audio_call(&"duck_music", [-7.0, 0.25])
		await _resolve_prologue_finisher()
		return
	# Same guard as _resolve_party_move()'s own copy of this - see its
	# comment for why _is_tutorial_scripted_turn() matters here and
	# tutorial_encounter alone doesn't.
	if _is_tutorial_scripted_turn(_acting):
		if _tutorial_step == 0:
			await _explain_other_stats()
		_tutorial_step += 1
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_advance_turn()

# Weighted random rather than always-lowest-HP - a party member missing
# more of their max HP is proportionally more likely to get picked, but a
# full-HP member always keeps some nonzero shot too (the +0.15 floor
# below). Reads as "the enemy is going after the hurt one" over a few
# turns without ever being a deterministic focus-fire that feels like the
# AI is cheating rather than playing smart.
func _pick_enemy_target(alive_party: Array) -> Dictionary:
	if alive_party.size() <= 1:
		return alive_party[0]
	var weights: Array = []
	var total := 0.0
	for e in alive_party:
		var s := (e.stats as CombatantStats)
		var missing_frac: float = 1.0 - (float(s.hp) / float(s.hp_max))
		var w: float = 0.15 + missing_frac
		weights.append(w)
		total += w
	var roll := randf() * total
	for i in range(alive_party.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			return alive_party[i]
	return alive_party[alive_party.size() - 1]

func _do_boss_turn(actor: Dictionary, alive_party: Array) -> void:
	var boss := actor.actor as TethysBoss
	var move := boss.next_move()
	var primary: Dictionary = _pick_enemy_target(alive_party)
	var targets: Array = alive_party if String(move.get("target", "single")) == "all" else [primary]

	# Tethys remains planted like the massive encounter it is; unlike a
	# grunt, its tail, tongue and breath are the reach. It still turns toward
	# the party before playing the authored clip.
	var to: Vector3 = (primary.actor as Node3D).position - boss.position
	to.y = 0.0
	if to.length() > 0.05:
		boss.face_toward((primary.actor as Node3D).global_position)
	var length := boss.play_attack(move)
	_audio_call(&"play_combat_swing", [_move_is_heavy(move)])
	if length > 0.0:
		await get_tree().create_timer(length * IMPACT_FRACTION).timeout

	var summaries: Array[String] = []
	for target_value in targets:
		var target := target_value as Dictionary
		var hit_summaries: Array[String] = []
		for hit_index in range(int(move.get("hits", 1))):
			if (target.stats as CombatantStats).hp <= 0:
				break
			var result: Dictionary = await _resolve_attack(actor.stats, target.stats, move)
			if result.hit and float(move.get("poison_fraction", 0.0)) > 0.0:
				var target_stats := target.stats as CombatantStats
				var poison_level := maxi(1, int(round(float(target_stats.hp_max) * float(move.poison_fraction))))
				target_stats.add_status("poison", poison_level, int(move.get("poison_turns", 3)))
				var effects := result.get("effects", []) as Array
				effects.append("Poison %d·%d" % [poison_level, int(move.get("poison_turns", 3))])
				result["effects"] = effects
			_react(target, result)
			_show_combat_feedback(target, result)
			_refresh_bar(target)
			if not result.hit:
				hit_summaries.append("evades")
			elif bool(result.get("dodged", false)):
				hit_summaries.append("QTE dodge")
			elif int(result.damage) > 0:
				hit_summaries.append("-%d" % int(result.damage))
			else:
				hit_summaries.append("affected")
		if (target.stats as CombatantStats).hp <= 0 and target.actor is Diver:
			(target.actor as Diver).play_death_fade()
		summaries.append("%s %s" % [String(target.display_name), "/".join(hit_summaries)])

	_log("Tethys uses %s: %s." % [String(move.name), "; ".join(summaries)])
	_finish_actor_turn(actor)
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	if is_instance_valid(boss):
		boss.play("idle")
	_advance_turn()

func _do_enemy_turn(actor: Dictionary, forced_target: Dictionary = {}) -> void:
	(actor.stats as CombatantStats).begin_turn()
	_refresh_bar(actor)
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	_turn_cursor.visible = false

	var alive_party := _living(party)
	if alive_party.is_empty():
		_advance_turn()
		return
	if actor.actor is TethysBoss:
		await _do_boss_turn(actor, alive_party)
		return
	# forced_target comes from _tutorial_prep_enemy_turn() picking (and
	# narrating) the target ahead of time - calling _pick_enemy_target()
	# again here would re-roll its randf() and could land on someone else
	# entirely, no longer matching what was just explained.
	var target: Dictionary = forced_target if not forced_target.is_empty() else _pick_enemy_target(alive_party)
	var target_stats := target.stats as CombatantStats
	if special_encounter:
		match String(target.get("ability_id", "")):
			"shockwave":
				await _do_rock_dodge_encounter(actor, target, target_stats)
				return
			"swap":
				await _do_swap_minigame(actor, target, target_stats)
				return
			"grapple":
				await _do_grapple_intercept_encounter(actor, target, target_stats)
				return

	var enemy_actor := actor.actor as Goblin
	var move := enemy_actor.choose_move(target_stats)
	# The tutorial just named one defender and promised a timing dodge against
	# this swing. An all-party move can resolve another diver first, consume the
	# one-shot force flag on that unrelated result, and never show the promised
	# QTE. Pick the first authored single-target move for this one teaching turn;
	# every later AI choice remains weighted production behavior.
	if _tutorial_force_next_qte:
		for candidate_value in enemy_actor.available_moves():
			var candidate := candidate_value as Dictionary
			if String(candidate.get("target", "single")) == "single":
				move = candidate
				break
	if move.is_empty():
		_log("%s has no enabled attack." % String(actor.display_name))
		_finish_actor_turn(actor)
		await get_tree().create_timer(LOG_READ_DELAY).timeout
		_advance_turn()
		return
	await _step_toward(actor, target)
	# The selected data record owns its animation and mechanics. Step into
	# range first, then keep the authored clip on screen through its impact
	# frame. Previously play_move() ran before the walk and idle was restored
	# about 0.18 seconds later, making a valid Bite look like no attack at all.
	var attack_length := enemy_actor.play_move(move)
	_audio_call(&"play_combat_swing", [_move_is_heavy(move.get("combat", {}) as Dictionary)])
	if attack_length > 0.0:
		await get_tree().create_timer(attack_length * IMPACT_FRACTION).timeout
	var combat_move := move.combat as Dictionary
	# _tutorial_force_next_qte alone only overrides _resolve_attack()'s
	# RANDOM chance roll (force_qte or randf() < ENEMY_QTE_CHANCE) - it
	# still requires the move's own quick_time_bool to be true, and most
	# of a goblin's real moves aren't (see content/enemy_moves.gd - Bite,
	# the heavily-weighted normal swing, is quick_time_bool: false; only
	# the finisher carries true, and it isn't even eligible until the
	# target's HP is already below its own threshold, which it never is
	# yet on the tutorial's first enemy turn). Without this, the "guaranteed"
	# QTE _tutorial_prep_enemy_turn() sets up silently never fires whenever
	# choose_move()'s own weighted pick lands on anything but that
	# unreachable finisher. Duplicated rather than mutated in place, so
	# forcing it here doesn't permanently flip that move's own shared
	# Dictionary for every other fight that reuses the same content entry.
	if _tutorial_force_next_qte:
		combat_move = combat_move.duplicate()
		combat_move["quick_time_bool"] = true
	var resolved_targets := enemy_targets_for_scope(target, alive_party, String(move.get("target", "single")))
	var result_rows: Array[String] = []
	var apply_self_effects := true
	for target_value in resolved_targets:
		var resolved_target := target_value as Dictionary
		var results: Array
		# A formula move normally takes the deterministic multi-hit helper. A
		# QTE-capable formula move must instead pass through the async resolver
		# so the visible timing window can decide whether this hit lands. Today
		# that is the tutorial's forced Angler swing; keeping it data-driven also
		# prevents a future authored timing move from silently bypassing input.
		if combat_move.has("formula") and bool(combat_move.get("quick_time_bool", false)):
			results = [await _resolve_attack(actor.stats, resolved_target.stats, combat_move)]
		elif combat_move.has("formula"):
			results = resolve_formula_hits(actor.stats as CombatantStats, resolved_target.stats as CombatantStats, combat_move, apply_self_effects)
		else:
			results = [await _resolve_attack(actor.stats, resolved_target.stats, combat_move)]
		apply_self_effects = false
		var target_results: Array[String] = []
		for result_value in results:
			var result := result_value as Dictionary
			_refresh_bar(resolved_target)
			_react(resolved_target, result)
			_show_combat_feedback(resolved_target, result)
			if bool(result.get("dodged", false)):
				target_results.append("QTE dodge")
			elif not bool(result.get("hit", false)):
				target_results.append("evades")
			elif int(result.get("damage", 0)) > 0:
				target_results.append("-%d" % int(result.damage))
			else:
				target_results.append("affected")
		if (resolved_target.stats as CombatantStats).hp <= 0 and resolved_target.has("actor") and resolved_target.actor is Diver:
			(resolved_target.actor as Diver).play_death_fade()
		result_rows.append("%s %s" % [String(resolved_target.display_name), "/".join(target_results)])
	_send_home(actor, attack_length * (1.0 - IMPACT_FRACTION))
	_log("%s uses %s: %s." % [String(actor.display_name), String(move.get("name", "Attack")), "; ".join(result_rows)])
	_finish_actor_turn(actor)
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_restore_enemy_idle(actor)
	_advance_turn()

func _look_at_dodge_angle(target_pos: Vector3) -> void:
	_stage_cam.global_position = target_pos + Vector3(3.0, 3.5, 2.0)
	_stage_cam.look_at(target_pos, Vector3.UP)

func _look_at_swap_angle(target_pos: Vector3, enemy_pos: Vector3) -> void:
	var midpoint := (target_pos + enemy_pos) * 0.5
	# MODIFIED (changed): was offset (0, 7, 7) at fov 85 - close and wide,
	# which made a portrait's on-screen size fall off sharply with distance
	# (basic perspective: a wide FOV up close exaggerates how much smaller
	# something gets per unit it travels away from the camera). The whole
	# point of this camera is watching portraits read clearly across their
	# entire travel lane, not just near either end of it, so it's pulled
	# back roughly 2.5x farther and the FOV narrowed to match (keeps
	# approximately the same framed width, "dolly out + zoom in") -
	# standard perspective-flattening: the travel lane's own ~9-10 unit
	# depth is now small relative to the camera's distance from it, so a
	# portrait's apparent size barely changes as it crosses the lane
	# instead of shrinking into the background near the far end.
	_stage_cam.global_position = midpoint + Vector3(0.0, 17.5, 17.5)
	_stage_cam.fov = 40.0
	_stage_cam.look_at(midpoint, Vector3.UP)

func _restore_stage_camera() -> void:
	_stage_cam.fov = 70.0
	_frame_stage_camera()

# Minigame impacts are guaranteed hits: the skill test already decided
# whether they landed - a rock/wall/portrait that reaches the diver is the
# whole penalty for missing that beat, not a dice roll to then also let
# Defense mitigate away.
# MODIFIED (changed): used to subtract defender.effective_defense() the
# same way a normal _resolve_attack() hit does (PR #54's mitigation rules)
# - against a diver with enough Defense (Bucky's 4, notably) that routinely
# rounded the whole hit down to 0, so missing a beat in the minigame could
# cost nothing at all and just showed "ABSORBED" instead of any real
# consequence. True damage now: whatever the skill test decided landed
# lands in full, no mitigation layered on top.
func _apply_special_impact(attacker: CombatantStats, target: Dictionary, scale: float = 1.0) -> Dictionary:
	var defender := target.stats as CombatantStats
	var raw := (float(ENEMY_MOVE.power) + float(attacker.strength)) * randf_range(0.85, 1.15)
	var incoming := maxi(0, int(round(raw * scale)))
	defender.hp = maxi(0, defender.hp - incoming)
	var result := {
		"hit": true, "damage": incoming, "absorbed": 0,
		"debuff": "", "changed": 0, "dodged": false, "effects": [],
	}
	_refresh_bar(target)
	_react(target, result)
	_show_combat_feedback(target, result)
	return result

# MODIFIED (added): `flawless` - a perfect run through whichever minigame
# just played (every rock/wall/portrait handled, none reaching the diver)
# now guarantees dodging this closing swing entirely, rather than it
# staying a pure _resolve_attack() accuracy/evasion roll totally unrelated
# to how the minigame itself went. Skips the attack roll AND the walk-up/
# send-home animation beat that goes with it - there's no swing to close
# the distance for if it's not going to happen at all.
func _finish_special_enemy_turn(actor: Dictionary, target: Dictionary, flawless: bool = false) -> void:
	var target_stats := target.stats as CombatantStats
	if target_stats.hp > 0:
		if flawless:
			_log("%s's flawless run leaves %s no opening to follow up!" % [String(target.display_name), String(actor.display_name)])
		else:
			var move := ENEMY_MOVE.duplicate()
			move.power = float(move.power) * _enemy_power_mult()
			(actor.actor as Goblin).play("walk")
			await _step_toward(actor, target)
			var result: Dictionary = await _resolve_attack(actor.stats, target_stats, move)
			_send_home(actor, 0.0)
			if is_instance_valid(actor.actor):
				(actor.actor as Goblin).play("idle")
			_refresh_bar(target)
			_react(target, result)
			_show_combat_feedback(target, result)
			if not bool(result.get("hit", false)):
				_log("%s follows up, but %s evades." % [String(actor.display_name), String(target.display_name)])
			else:
				_log("%s follows up for %d." % [String(actor.display_name), int(result.get("damage", 0))])
	if target_stats.hp <= 0 and target.has("actor") and is_instance_valid(target.actor):
		(target.actor as Diver).play_death_fade()
	_special_round += 1
	_finish_actor_turn(actor)
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	# MODIFIED (added): the first special encounter walks through all three
	# divers' own minigames in turn - Maxilani (already just played out,
	# _tutorial_enemy_turns == 1), then Musashi, then Bucky. Only fires while
	# she/he is still alive (a death here already means the fight's lost -
	# nothing left to introduce) and only after the first two teaching
	# turns, since there's no fourth diver to hand off to after Bucky's own.
	if tutorial_encounter and special_encounter and target_stats.hp > 0:
		if _tutorial_enemy_turns == 1:
			await _swap_tutorial_special_diver("Prototype_1(1910)", "You get to choose between one of the three divers to send in for the special encounter before it starts. Now let's explore Musashi's minigame.")
			return
		elif _tutorial_enemy_turns == 2:
			await _swap_tutorial_special_diver("Prototype_V(1922)", "Now let's explore Bucky's minigame.")
			return
	_advance_turn()

# The first special encounter's own diver hand-off: fades the current
# occupant of the solo party slot out, brings in `new_model_name`'s REAL
# diver (same convention _offer_special_encounter()'s own forced-Maxilani
# branch already uses - this fight plays out against real, persistent
# stats, not a throwaway copy), and forces their turn immediately rather
# than letting the normal agility-sorted queue decide who goes next - the
# enemy's own agility was only ever forced below MAXILANI's specifically
# (see _build_stage()'s special_encounter branch), so leaving this to the
# real queue could easily hand the enemy a second turn in a row instead of
# letting the new diver swing first, same as Maxilani got to.
func _swap_tutorial_special_diver(new_model_name: String, intro_caption: String) -> void:
	_set_all_buttons(false)
	await _tutorial_show_step(intro_caption)
	var entry: Dictionary = party[0]
	var rest_pos: Vector3 = entry.get("home_pos", Vector3.ZERO)
	var rest_rot: float = float(entry.get("home_rot", 0.0))
	if entry.has("actor") and is_instance_valid(entry.actor):
		# MODIFIED (changed): play_death_fade() was reused here for a
		# moment, but that's the same sink-and-fade animation a downed
		# diver plays - wrong read for "stepping out to hand off to the
		# next diver," not dying. A Diver is a 3D CharacterBody3D with no
		# tree-wide "modulate" to just fade out either (that's a CanvasItem
		# thing), so this is a plain instant removal instead - she's simply
		# gone the moment the next diver is due to take her place.
		(entry.actor as Node3D).queue_free()
	var new_diver: Diver = null
	for d in world.divers:
		if String((d as Diver).model_name) == new_model_name:
			new_diver = d as Diver
			break
	# Same defensive heal-if-downed check _offer_special_encounter() already
	# does for Maxilani before forcing her into the very first fight of a
	# new game - neither she nor Musashi/Bucky should ever actually be down
	# this early, but nothing guarantees that forever, and the crash this
	# guards against (_build_stage() never gives a hp<=0 party member an
	# "actor" at all) is exactly the one that already happened once.
	if new_diver.stats.hp <= 0:
		new_diver.stats.hp = new_diver.stats.hp_max
		new_diver.stats.oxygen = new_diver.stats.oxygen_max
	var new_actor := Diver.new()
	new_actor.model_name = new_model_name
	new_actor.position = rest_pos
	_stage_vp.add_child(new_actor)
	new_actor.rotation.y = rest_rot
	# Mutated in place, not replaced - entry is the exact same Dictionary
	# object _queue/_refresh_bar() etc. already hold references to, and it
	# still owns this slot's overhead bar Controls (hp_bar/oxygen_bar/card/
	# name_label/...), built once in _build_overhead_bar() and never
	# rebuilt. Losing those by swapping in a brand-new Dictionary would
	# leave the new diver with no status card at all.
	entry["stats"] = new_diver.stats
	entry["model_name"] = new_diver.model_name
	entry["display_name"] = _display(new_diver.model_name)
	entry["equipped_spells"] = new_diver.equipped_spells
	entry["ability_id"] = new_diver.ability_id
	entry["actor"] = new_actor
	entry["home_pos"] = new_actor.position
	entry["home_rot"] = new_actor.rotation.y
	if entry.has("name_label"):
		(entry.name_label as Label).text = String(entry.display_name)
	_refresh_bar(entry)
	# MODIFIED (fixed): was _queue.clear() - by the time this runs, both
	# combatants have already acted this round (the diver's real turn, then
	# the enemy's, which is what triggered this swap), so _queue was already
	# empty regardless. Once this injected turn resolves, _resolve_party_move()/
	# _resolve_party_move_all()'s trailing _advance_turn() saw that same empty
	# queue and called _rebuild_queue() - starting a genuinely new round from
	# every living combatant, agility-sorted. The enemy's agility is only ever
	# forced below MAXILANI's specifically (see _build_stage()), not below
	# Musashi's or Bucky's, so the new diver routinely outran it into that
	# fresh round's first slot too - a second turn in a row before the enemy
	# ever got to act again and trigger the next minigame's own tutorial
	# explanation. Seeding the queue with just the enemy forces it to go next
	# regardless of agility, the same "don't leave this to the real queue"
	# reasoning this function's own header comment already gives for forcing
	# the new diver's turn immediately above.
	_queue = [enemies[0]]
	await _tutorial_show_step("Continue fighting the enemy")
	# Same stale-caption fix as _play_special_encounter_intro(): nothing else
	# overwrites _tutorial_caption's text after this last Enter press, so the
	# flashing "Press Enter to continue" pulse would otherwise sit there
	# frozen once _start_party_turn() below hands control back to the player.
	_tutorial_caption.text = ""
	_tutorial_caption.visible = false
	call_deferred("_fit_panel_height")
	# _acting still pointed at the enemy - whose turn this swap happened
	# during (see _finish_special_enemy_turn()) - every other
	# _start_party_turn() call site sets _acting to the same entry first;
	# without it here, _show_moves()'s _populate_move_menu(_acting) built the
	# move menu from the enemy's own dict (no model_name/moveset), so
	# choosing "Attack" produced an empty/broken menu the player could not
	# get past.
	_acting = entry
	_start_party_turn(entry)

func _do_grapple_intercept_encounter(actor: Dictionary, target: Dictionary, _target_stats: CombatantStats) -> void:
	# The safe color is announced by the minigame's wave_started signal.
	# This first line establishes the actual objective before its first wave.
	_log("%s launches a colored vortex. Grapple the instructed color before it reaches you!" % String(actor.display_name))
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	var minigame := GrappleInterceptMinigame.new()
	minigame.stage_root = _stage_vp
	minigame.stage_camera = _stage_cam
	minigame.target_actor = target.actor
	minigame.enemy_actor = actor.actor
	minigame.source_position = (actor.actor as Node3D).global_position + Vector3.UP * (actor.actor as Goblin).height
	# MODIFIED (added): the crosshair (and this minigame's whole 2D
	# coordinate frame) has to match where the 3D stage actually renders,
	# not the full screen - see GrappleInterceptMinigame.stage_rect's own
	# comment for why the two differ and what that mismatch did to aiming.
	if _stage_container != null:
		minigame.stage_rect = Rect2(_stage_container.position, _stage_container.size)
	add_child(minigame)
	var total_taken := 0
	minigame.object_hit.connect(func() -> void:
		var result := _apply_special_impact(actor.stats, target)
		total_taken += int(result.damage)
		if (target.stats as CombatantStats).hp <= 0:
			minigame.request_abort()
	)
	minigame.wave_started.connect(func(safe_is_yellow: bool, wave_index: int, total_waves: int) -> void:
		_log_grapple_wave(safe_is_yellow, wave_index, total_waves)
	)
	minigame.run()
	var score: Array = await minigame.finished
	minigame.queue_free()
	(target.actor as Node3D).visible = true
	_restore_stage_camera()
	_log("%s clears %d/%d vortex targets%s" % [String(target.display_name), int(score[0]), int(score[1]), " without damage." if total_taken == 0 else " and takes %d damage." % total_taken])
	await get_tree().create_timer(0.45).timeout
	# MODIFIED (added): passes along whether this was a flawless run (every
	# rock intercepted, none reaching the diver) so a perfect clear
	# guarantees dodging the follow-up entirely instead of that staying an
	# unrelated dice roll - see _finish_special_enemy_turn()'s own comment.
	await _finish_special_enemy_turn(actor, target, int(score[0]) >= int(score[1]))

func _do_rock_dodge_encounter(actor: Dictionary, target: Dictionary, _target_stats: CombatantStats) -> void:
	# Same "control hint as battle body text" treatment as _do_swap_
	# minigame()/_do_grapple_intercept_encounter()'s own log lines, for the
	# same parity reason - Bucky's minigame shouldn't be the one left
	# without this while Maxilani's and Musashi's both have it.
	_log("%s hurls rocks and walls at %s! Left/Right to move lanes, E to shockwave a rock when it arrives in your lane." % [String(actor.display_name), String(target.display_name)])
	_audio_call(&"play_shockwave")
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_look_at_dodge_angle((target.actor as Node3D).global_position)
	var minigame := RockDodgeMinigame.new()
	minigame.thrower_position = (actor.actor as Node3D).global_position + Vector3.UP * (actor.actor as Goblin).height
	minigame.stage_root = _stage_vp
	minigame.target_actor = target.actor
	add_child(minigame)
	var total_taken := 0
	minigame.rock_landed.connect(func() -> void:
		var result := _apply_special_impact(actor.stats, target)
		total_taken += int(result.damage)
		if (target.stats as CombatantStats).hp <= 0:
			minigame.request_abort()
	)
	minigame.run()
	var score: Array = await minigame.finished
	minigame.queue_free()
	# MODIFIED (fixed): same race as _do_swap_minigame()'s own fix -
	# RockDodgeMinigame's `back` tween (swimming target_actor back to
	# _player_base_pos on finish/abort) is never awaited, so `finished`
	# resolves before she's actually back there. Snapping straight to her
	# known home_pos/home_rot sidesteps the race instead of guessing a wait
	# long enough to cover it.
	if target.has("actor") and is_instance_valid(target.actor):
		var target_node := target.actor as Node3D
		target_node.global_position = target.get("home_pos", target_node.global_position)
		target_node.rotation.y = float(target.get("home_rot", target_node.rotation.y))
	_restore_stage_camera()
	_log("%s breaks %d/%d threats%s" % [String(target.display_name), int(score[0]), int(score[1]), " without damage." if total_taken == 0 else " and takes %d damage." % total_taken])
	await get_tree().create_timer(0.45).timeout
	# MODIFIED (added): passes along whether this was a flawless run (every
	# rock shockwaved, none reaching the diver) so a perfect clear guarantees
	# dodging the follow-up entirely instead of that staying an unrelated
	# dice roll - see _finish_special_enemy_turn()'s own comment.
	await _finish_special_enemy_turn(actor, target, int(score[0]) >= int(score[1]))

func _do_swap_minigame(actor: Dictionary, target: Dictionary, _target_stats: CombatantStats) -> void:
	# MODIFIED (changed): the "Left/Right to aim, E to swap into that spot"
	# control hint used to float over the minigame itself (diver_swap_
	# minigame.gd's own now-removed hint Label) - moved here, into the
	# battle log line that already announces the minigame starting, so it
	# reads as body text in the bottom panel instead of an overlay that
	# collided with the party status column at the top of the screen.
	_log("%s scrambles the diver portraits! Left/Right to aim, E to swap into that spot." % String(actor.display_name))
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_look_at_swap_angle((target.actor as Node3D).global_position, (actor.actor as Node3D).global_position)
	var minigame := DiverSwapMinigame.new()
	minigame.stage_root = _stage_vp
	minigame.target_actor = target.actor
	minigame.enemy_actor = actor.actor
	add_child(minigame)
	var total_taken := 0
	minigame.portrait_landed.connect(func() -> void:
		var result := _apply_special_impact(actor.stats, target, 0.25)
		total_taken += int(result.damage)
		if (target.stats as CombatantStats).hp <= 0:
			minigame.request_abort()
	)
	minigame.run()
	var score: Array = await minigame.finished
	minigame.queue_free()
	# MODIFIED (fixed): DiverSwapMinigame._finish_now() kicks off its own
	# tween swimming target_actor back to her rest spot, but never awaits
	# it - `finished` (and so this whole await) resolves the instant that
	# tween starts, not once it's actually done (~0.85s later). Restoring
	# the camera right away framed around wherever she still was mid-swim
	# instead - on an early abort (died partway through the portraits) that
	# could be anywhere in the swap grid, and nothing else ever re-framed
	# again afterward, so a bad, too-close shot just sat there through the
	# result log, the 0.45s pause below, and into the follow-up attack/
	# death-fade. Snapping her straight to her own known home_pos/home_rot
	# here - the same position _build_stage() gave her, already tracked on
	# this same dict - sidesteps the whole race instead of trying to time
	# around the minigame's own unawaited tween.
	if target.has("actor") and is_instance_valid(target.actor):
		var target_node := target.actor as Node3D
		target_node.global_position = target.get("home_pos", target_node.global_position)
		target_node.rotation.y = float(target.get("home_rot", target_node.rotation.y))
	_restore_stage_camera()
	_log("%s matches %d/%d portraits%s" % [String(target.display_name), int(score[0]), int(score[1]), " without damage." if total_taken == 0 else " and takes %d damage." % total_taken])
	await get_tree().create_timer(0.45).timeout
	# MODIFIED (added): passes along whether this was a flawless run (every
	# portrait matched correctly, none reaching the diver) so a perfect
	# clear guarantees dodging the follow-up entirely instead of that
	# staying an unrelated dice roll - see _finish_special_enemy_turn()'s
	# own comment.
	await _finish_special_enemy_turn(actor, target, int(score[0]) >= int(score[1]))

# One diver's block for _win()'s level-up table: name + level reached, plus
# how many Spell Points that jump earned (1 per level - see gain_xp() in
# combatant_stats.gd). `levels` is however many levels one gain_xp() call
# crossed at once, so a big XP dump reads as one combined line rather than
# a block repeated once per level crossed. Leveling no longer touches
# combat stats at all, so there's nothing else to report here.
func _build_levelup_block(entry: Dictionary, levels: Array) -> String:
	var s := entry.stats as CombatantStats
	var up := STAT_COLOR_UP.to_html(false)
	var points := levels.size()
	var line := "+%d Spell Point" % points
	if points != 1:
		line += "s"
	line = "[color=%s]%s[/color]" % [up, line]
	var last_level := int((levels[levels.size() - 1] as Dictionary).get("level", s.level))
	return "[b]%s[/b] - Lv.%d\n%s" % [String(entry.display_name), last_level, line]

func _win() -> void:
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	# Leftover from whoever's move resolved right before this - the name/
	# power row above the stats panels, and the panels themselves (the
	# player one sits visible all fight; the enemy one only when a hover
	# preview was still up) - neither menu-hide above touches these, so
	# without this the last diver's chosen attack and stats would keep
	# showing underneath the win sequence instead of just the stat-boost
	# table and (in the tutorial) the explanation of what winning did.
	_set_row_highlight(_selected_move_panel, false)
	_selected_move_panel.visible = false
	(_player_stats_ui.panel as Control).visible = false
	(_enemy_stats_ui.panel as Control).visible = false
	_log("Tethys sinks back into the dark, beaten." if boss_encounter else "The enemies back off, beaten.")
	# Whoever is still standing celebrates. The clip loops, so it holds for
	# as long as the XP lines take to read.
	for entry in _living(party):
		if entry.has("actor") and is_instance_valid(entry.actor) and entry.actor is Diver:
			(entry.actor as Diver).play_win()
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	# The tutorial's first win is narrated, not real - see the caption below,
	# which explicitly tells the player this particular win doesn't grant
	# XP. gain_xp() never runs here, so there's no level-up to log and no
	# Spell Point block to build for this fight.
	var levelup_blocks: Array[String] = []
	var spell_unlock_announcements: Array[Dictionary] = []
	if not tutorial_encounter:
		var total_xp := 0
		for e in enemies:
			total_xp += int(e.get("xp_reward", 0))
		if special_encounter:
			total_xp = int(round(float(total_xp) * 1.5))
		# Every party member gets the full amount, not a split share - there's
		# no shared party XP pool concept in this game, and splitting it would
		# just make leveling slower for the same fights without adding a
		# meaningful choice anywhere.
		for entry in party:
			var levels: Array = (entry.stats as CombatantStats).gain_xp(total_xp)
			for lv in levels:
				_log("%s reached level %d!" % [String(entry.display_name), int((lv as Dictionary).level)])
				await get_tree().create_timer(LOG_READ_DELAY).timeout
			if not levels.is_empty():
				levelup_blocks.append(_build_levelup_block(entry, levels))
		var available_key_items: Array = world.key_items.duplicate() if world != null else []
		# A guardian's key item is granted by World after this battle emits
		# "won". Include it now so the win that earns it can unlock its spell.
		if Items.is_key_item(reward_item_on_win) and not available_key_items.has(reward_item_on_win):
			available_key_items.append(reward_item_on_win)
		for entry in party:
			if not entry.has("diver"):
				continue
			var diver := entry.diver as Diver
			var unlocked: PackedStringArray = SpellTree.learn_all_available(diver, available_key_items)
			if not unlocked.is_empty():
				spell_unlock_announcements.append({
					"display_name": String(entry.display_name),
					"skills": unlocked,
				})
	# One combined block for every diver who leveled up this win, not a
	# separate popup per diver - name, level reached, and Spell Points
	# earned, in the same green used for a rising stat everywhere else in
	# this file (STAT_COLOR_UP/_apply_stat_delta()), even though nothing
	# about the diver's combat stats actually changed. Just a timed flash,
	# same as everywhere else outside the tutorial fight - the tutorial
	# fight never populates levelup_blocks at all (see above), so this
	# never fires during it.
	if not levelup_blocks.is_empty():
		_levelup_caption.text = "\n\n".join(levelup_blocks)
		_levelup_caption.visible = true
		call_deferred("_fit_panel_height")
	# The map has repeated random battles plus two guardians and no guaranteed
	# healer between them. A partial regroup prevents one victory from leaving
	# the next encounter mathematically decided while preserving attrition.
	# Shown as a green fill over each diver's own HP/Oxygen bar (any win,
	# including the tutorial's - this is the real, ungated partial heal, not
	# a stand-in for a level-up that isn't happening here), from wherever it
	# sat before this restore up to wherever it lands after - see
	# _show_heal_overlay() - rather than the bars just silently jumping to
	# new numbers.
	for entry in party:
		var s := entry.stats as CombatantStats
		var before_hp := float(s.hp)
		var before_o2 := s.oxygen
		s.recover_after_victory()
		if entry.has("hp_heal_overlay"):
			_show_heal_overlay(entry.hp_heal_overlay as ColorRect, before_hp, float(s.hp), float(s.hp_max))
		if entry.has("oxygen_heal_overlay"):
			_show_heal_overlay(entry.oxygen_heal_overlay as ColorRect, before_o2, s.oxygen, s.oxygen_max)
	_refresh_all_bars()
	# One extra beat only for the choreographed first fight - explains that
	# THIS win didn't grant XP, then describes what winning normally does
	# for every fight after it (XP to the whole party including anyone
	# downed, a level-up's HP/Oxygen refill, and Spell Points instead of any
	# stat change) rather than leaving the player to infer what they'll see
	# later. Deliberately brief on Spell Points/spell trees - a fuller
	# walkthrough of that is planned as its own separate tutorial later.
	# MODIFIED (fixed): `tutorial_encounter` alone is true for the first
	# special encounter too (see World._offer_special_encounter()) - this
	# caption is specifically about the plain combat tutorial's first-enemy
	# lesson (its wording doesn't even apply to the special encounter, which
	# never grants XP regardless of context). The special encounter's own
	# win message is world.gd's _on_battle_finished() "won" branch (was_
	# special and was_tutorial), already shown before this ever runs.
	if tutorial_encounter and not special_encounter:
		await _tutorial_show_step("You have defeated your first enemy! In this case you won't gain XP.")
		for entry in party:
			if entry.has("hp_heal_overlay"):
				(entry.hp_heal_overlay as ColorRect).visible = false
			if entry.has("oxygen_heal_overlay"):
				(entry.oxygen_heal_overlay as ColorRect).visible = false
	else:
		# No accompanying caption outside the tutorial - just a timed flash
		# instead of an Enter-gate, same reasoning _apply_stat_delta()-style
		# previews elsewhere in this file use a timer when nothing has to
		# stay synchronized with an explanation.
		await get_tree().create_timer(LOG_READ_DELAY * 1.5).timeout
		for entry in party:
			if entry.has("hp_heal_overlay"):
				(entry.hp_heal_overlay as ColorRect).visible = false
			if entry.has("oxygen_heal_overlay"):
				(entry.oxygen_heal_overlay as ColorRect).visible = false
		if not levelup_blocks.is_empty():
			_levelup_caption.visible = false
			call_deferred("_fit_panel_height")
	for unlock in spell_unlock_announcements:
		await _tutorial_show_step("%s unlocked %s." % [
			String(unlock.display_name), ", ".join(unlock.skills)
		])
	_revert_temp_buffs()
	finished.emit("won")

func _lose() -> void:
	# MODIFIED (added): a special-encounter loss reaches here through
	# _do_swap_minigame()/_do_rock_dodge_encounter()/_do_grapple_intercept_
	# encounter(), each of which already calls _restore_stage_camera() the
	# instant its own minigame ends (including an early end from dying mid-
	# minigame - request_abort() triggers that same restore). This re-frames
	# once more regardless, as a guaranteed-correct snapshot of wherever the
	# stage's living/fading actors actually are right as the loss screen is
	# about to take over - cheap, and it can't make a already-correct frame
	# any worse.
	_frame_stage_camera()
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	# The choreographed first fight can genuinely be lost now that
	# _advance_turn() no longer force-wins it after the "Defeat the enemy!"
	# prompt - spell out what a loss actually means. A normal battle's loss
	# still goes through world.gd's real game-over flow (_on_battle_finished()
	# calls _show_game_over(), whose Restart button reloads the current save
	# slot - see game_over_screen.gd), but the tutorial's is deliberately
	# softer: it's a brand-new player's first-ever fight, with no real save to
	# fall back to yet, so world.gd's "lost" branch instead heals the party
	# and returns them straight to the overworld (see its own was_tutorial
	# check) rather than showing Game Over.
	# MODIFIED (fixed): same leak as _win()'s own fix just above -
	# `tutorial_encounter` alone also covers the first special encounter,
	# and this caption's XP/leveling explanation doesn't apply there at all
	# (special encounters never grant XP). world.gd's _on_battle_finished()
	# "lost" branch already opens tutorial_result_popup with its own
	# special-encounter-appropriate explanation before this would run.
	if tutorial_encounter and not special_encounter:
		await _tutorial_show_step("In this case, the party lost the fight, but you can continue to fight enemies in the overworld. Winning a fight awards XP to your whole party, not just whoever fought - including anyone who went down during the fight, who gains XP the same as everyone else. Gain enough XP and a diver levels up, which refills their HP and Oxygen (green on the bars, outlined in purple at the top) even if they went down - otherwise a downed diver needs a Revive spell to get back on their feet. Leveling up doesn't change your combat stats - instead, you earn Spell Points, which can be used to gain new abilities by defeating enemies in battles. More on Spell Points and spell trees later.")
	else:
		_log("The party is battered and pulls back.")
		await get_tree().create_timer(LOG_READ_DELAY).timeout
	_revert_temp_buffs()
	finished.emit("lost")

func _on_skip_tutorial_pressed() -> void:
	if _busy:
		return
	_skip_tutorial_requested = true
	_busy = true
	_tutorial_awaiting_enter = false
	_set_all_buttons(false)
	main_menu.visible = false
	_log("Skipping the tutorial fight.")
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_revert_temp_buffs()
	finished.emit("skipped")

func _on_run() -> void:
	if _busy:
		return
	_busy = true
	_set_all_buttons(false)
	main_menu.visible = false

	if randf() <= RUN_CHANCE:
		_log("The party breaks off and swims for it.")
		await get_tree().create_timer(LOG_READ_DELAY).timeout
		_revert_temp_buffs()
		finished.emit("fled")
		return

	var living_enemies := _living(enemies)
	var blocker := String(living_enemies[0].display_name) if not living_enemies.is_empty() else "something"
	_log("Can't get clear - %s cuts you off!" % blocker)
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	if not living_enemies.is_empty():
		var attacker: Dictionary = living_enemies[randi_range(0, living_enemies.size() - 1)]
		var angler := attacker.actor as Goblin
		var move := angler.choose_move(_acting.stats as CombatantStats) if angler != null else {}
		var r: Dictionary = await _resolve_attack(attacker.stats, _acting.stats, move.get("combat", {}) as Dictionary)
		_refresh_bar(_acting)
		_show_combat_feedback(_acting, r)
		if bool(r.get("dodged", false)):
			_log("%s lunges - you time it perfectly and dodge clear!" % String(attacker.display_name))
		elif not r.hit:
			_log("%s lunges, but you evade clear." % String(attacker.display_name))
		else:
			_log("%s %s you for %d as you struggle free." % [String(attacker.display_name), String(move.get("verb", "attacks")), int(r.damage)])
		if (_acting.stats as CombatantStats).hp <= 0 and _acting.has("actor") and _acting.actor is Diver:
			(_acting.actor as Diver).play_death_fade()
		await get_tree().create_timer(LOG_READ_DELAY).timeout
	_finish_actor_turn(_acting)
	_advance_turn()

func _set_all_buttons(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	run_btn.disabled = not enabled
	if skip_tutorial_btn != null:
		# Keep Skip Tutorial available during the first special encounter's
		# opening captions, when the other combat controls are intentionally
		# disabled. The handler still rejects input once a turn is busy.
		var can_skip_during_intro := special_encounter and tutorial_encounter and not _skip_tutorial_requested
		skip_tutorial_btn.disabled = not enabled and not can_skip_during_intro
	items_btn.disabled = not enabled
	back_btn.disabled = not enabled
	item_back_btn.disabled = not enabled
	target_back_btn.disabled = not enabled
	for b in move_buttons:
		(b as Button).disabled = not enabled
	if _move_up_btn != null:
		if enabled:
			_apply_move_scroll()
		else:
			_move_up_btn.disabled = true
			_move_down_btn.disabled = true
	for b in target_buttons:
		(b as Button).disabled = not enabled
	for b in item_buttons:
		(b as Button).disabled = not enabled
