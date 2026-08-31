# The turn-based screen a random encounter drops you into: a small 3D stage
# showing all three divers and however many grunts stopped you, with a menu
# underneath. world.gd freezes the dive and hands over the mouse while this
# is up, then un-freezes once `finished` fires.
#
# Combatants live as plain Dictionaries (not a class) in two arrays -
# `party` and `enemies` - each entry shaped
# {kind, stats, model_name, display_name, equipped_spells, actor, hp_bar,
# hp_label}. A Dictionary rather than a real class because nothing here
# needs identity beyond "the fields", and it's the same lightweight shape
# BASE_MOVES entries already use in this file.
#
# Turn order is a live queue (`_queue`), not a fixed two-actor ping-pong:
# every living combatant is sorted by current agility at the start of each
# round, one entry is popped off and acts, and a landed agility-changing
# debuff re-sorts whatever's still waiting immediately - see
# _rebuild_queue()/_resort_pending()/_advance_turn().
class_name Battle
extends CanvasLayer

signal finished(result: String)     # "won", "fled", or "lost"

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

# Set by world.gd before add_child() for a key-item-guarded special
# encounter (see World._on_special_encounter_diver_chosen()) - this file
# doesn't change behavior based on it at all, "lost" still just emits
# normally. It's read back by World._on_battle_finished() (before this
# Battle gets queue_free()'d) to decide whether a loss means the normal
# game-over screen or "restore this diver's pre-fight HP and hand control
# back" instead - that whole decision lives on World's side, not here.
var special_encounter := false

# How many of the enemy's own turns have already happened this special
# encounter - incremented once per enemy turn regardless of what the
# player chose that round (see _do_enemy_turn()'s normal-attack path and
# _do_rock_dodge_encounter()'s own tail), so dragging the fight out is
# what gets riskier, not any one specific move. Read by
# _enemy_power_mult() below; meaningless (never incremented) outside a
# special encounter.
var _special_round := 0

# +15% enemy power per round already survived - applied to the enemy's
# own attack power (see _do_enemy_turn()'s move_dict scaling) AND to
# each rock landed in the dodge minigame (_do_rock_dodge_encounter()'s
# rock_landed handler). Not applied to the player's own Blast Rocks
# damage output - see _do_blast_rocks_attack()'s own comment on why.
func _enemy_power_mult() -> float:
	return 1.0 + 0.15 * float(_special_round)

# Fallback identity only for the no-party_source case (tools/test_battle.gd
# instantiating a bare Battle) - mirrors whatever Diver would have built.
var diver_model_name := "Staff_Diver"

const RUN_CHANCE := 0.6
const MIN_ENEMIES := 1
const MAX_ENEMIES := 3

const DISPLAY_NAMES := {
	"Staff_Diver": "Mermaid",
	"Prototype_1(1910)": "Diver Boy",
	"Prototype_V(1922)": "Marine Man",
}

# Attack is a category, not a single action: pressing it opens a move list
# instead of swinging right away. These base moves are always available -
# on top of whichever spells that specific party member has equipped (see
# _moves_for()) - and now differ per diver instead of being one shared
# list, so the base kit itself carries some identity too, not just the
# spell tree layered on top of it. `power` feeds the damage half of
# _resolve_attack() below; `acc_mod` is added to the attacker's accuracy
# for that swing only, before it's compared to the defender's evasion.
#
# Prototype_1(1910) keeps Weaken/Slow as its base kit rather than damage
# moves - its whole identity is debuff support (see spell_tree.gd's header
# comment), so even the free moves everyone always has lean into that
# instead of being generic damage like the other two divers get.
#
# Every diver's first move is its free basic attack - no `oxygen_cost` key
# at all, the fallback that still works even at 0 oxygen, same role
# Diver.gd's abilities and every equipped spell (see _moves_for()) can't
# fill once the tank's empty. Everything else costs oxygen same as a spell
# would (_populate_move_menu() reads oxygen_cost with a 0.0 default, so the
# free move simply never shows a cost or blocks on one).
#
# `inventory: true` (Mermaid's Heal, below) marks a move as also usable
# outside battle, from the Escape-key pause menu's "Party Spells" tab (see
# inventory_menu.gd/World._inventory_spells_for()/World.use_party_spell()).
# Only "heal"/"revive" effect moves make sense to tag this way - there's no
# opponent to swing "damage"/"debuff" at while just swimming around, and
# World.use_party_spell() only knows how to resolve those two effects.
# Same tag exists on spell_tree.gd entries, for spells learned later that
# should carry the same out-of-battle use.
const BASE_MOVES := {
	"Staff_Diver": [
		{"name": "Heal", "power": 0, "effect": "heal", "amount": 5, "inventory": true, "oxygen_cost": 6.0, "hint": "Restores an ally's HP", "text": "You recover some health"},
		{"name": "Swift Jab", "power": 1, "acc_mod": 6, "hint": "Fast, reliable", "text": "You jab it in a burst of speed"},
		{"name": "Riptide Kick", "power": 7, "acc_mod": 2, "hint": "Balanced", "text": "You kick it on a current", "oxygen_cost": 10.0},
		{"name": "Crashing Wave", "power": 12, "acc_mod": -2, "hint": "Heavy, riskier", "text": "You crash into it like a wave", "oxygen_cost": 16.0},
	],
	"Prototype_1(1910)": [
		{"name": "Precise Tap", "power": 1, "acc_mod": 9, "hint": "Nearly unmissable, light", "text": "You land a precise tap"},
		{"name": "Weaken", "power": 0, "acc_mod": 2, "debuff": "defense", "amount": 2, "hint": "Lowers its defense", "text": "You strike a nerve - its defense drops", "oxygen_cost": 10.0},
		{"name": "Slow", "power": 0, "acc_mod": 2, "debuff": "agility", "amount": 2, "hint": "Lowers its agility", "text": "You hobble it - its agility drops", "oxygen_cost": 10.0},
	],
	"Prototype_V(1922)": [
		{"name": "Guard Bash", "power": 6, "acc_mod": 3, "hint": "Sturdy, reliable", "text": "You bash it with your guard"},
		{"name": "Heavy Kick", "power": 10, "acc_mod": 0, "hint": "Balanced, heavier", "text": "You drive a heavy kick home", "oxygen_cost": 10.0},
		{"name": "Crushing Haymaker", "power": 15, "acc_mod": -3, "hint": "Very heavy, slow", "text": "You wind up and crush it", "oxygen_cost": 16.0},
		# Only ever shown/usable in a special encounter (see _moves_for()'s
		# filter) - the offensive counterpart to rock_dodge_minigame.gd's
		# defensive one, played on Marine Man's OWN turn instead of the
		# enemy's. "effect": "blast_rocks" is special-cased in
		# _on_move_chosen()/_resolve_party_move() rather than going through
		# the normal damage/target-picker path - see
		# _do_blast_rocks_attack(). Costs real oxygen and can whiff per rock
		# (see blast_rocks_minigame.gd), same risk/reward as choosing to
		# keep gambling on it turn after turn while the encounter's own
		# round-based escalation (_enemy_power_mult()) keeps ramping up.
		{"name": "Blast Rocks", "power": 0, "effect": "blast_rocks", "oxygen_cost": 14.0,
			"special_encounter_only": true,
			"hint": "Time shockwaves on a grid - risky, no target needed", "text": "You call up a barrage of rocks"},
	],
}

const ENEMY_MOVE := {"power": 9, "acc_mod": 1, "quick_time_bool": false}

# A grunt's occasional big swing - see _resolve_attack()'s "heavy" effect
# branch for how heavy_min/heavy_max actually turn into damage (a fraction
# of the DEFENDER's max HP, not power/strength like ENEMY_MOVE). Lower
# acc_mod than the normal swing - a hit this dangerous should be a little
# more telegraphed/missable, not just as reliable as a Jab. Definitely
# QTE-gated: this is exactly the swing the dodge system exists for.
const ENEMY_HEAVY_MOVE := {
	"power": 0, "acc_mod": -1, "quick_time_bool": true,
	"effect": "heavy", "heavy_min": 0.25, "heavy_max": 0.5,
}
const ENEMY_HEAVY_CHANCE := 0.3

# Raised in place of ENEMY_HEAVY_CHANCE when the chosen target is already
# low enough that a heavy swing's own damage range could plausibly finish
# them (see _do_enemy_turn()) - an enemy that's just rolling dice every
# turn doesn't read as smart; one that goes for the kill when it's actually
# lined up does, without making the heavy swing itself hit any harder or
# any more reliably than it already did.
const ENEMY_HEAVY_FINISH_CHANCE := 0.65

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

var party: Array = []      # [{kind:"party", stats, model_name, display_name, equipped_spells, actor, hp_bar, hp_label, barrier_bar}]
var enemies: Array = []    # [{kind:"enemy", stats, display_name, actor, hp_bar, hp_label, barrier_bar}]

var _queue: Array = []     # combatants (same dict refs as party/enemies) still waiting to act this round
var _acting: Dictionary = {}
var _pending_move: Dictionary = {}
var _busy := false

var log_label: Label
var queue_row: HBoxContainer
# HFlowContainer, not HBoxContainer - main_menu only ever has 2 buttons so
# it never mattered, but move_menu can hold up to 3 base moves + 4 equipped
# spells + Back (8 buttons at 150px each, wider than the whole viewport at
# 1280px) and target_menu can hold one button per living enemy/ally. A
# plain HBoxContainer doesn't wrap - it would just run buttons off the
# right edge instead of overflowing downward, the same "off-screen" bug
# class as _bottom_panel not sizing to content (see _fit_panel_height()).
var main_menu: HFlowContainer
var move_menu: HFlowContainer
var target_menu: HFlowContainer
var item_menu: HFlowContainer
var attack_btn: Button
var run_btn: Button
var items_btn: Button
var back_btn: Button
var item_back_btn: Button
var target_back_btn: Button
var move_buttons: Array = []
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

# The battle stage's one camera - stored so it can be moved for the dodge
# minigame's over-the-shoulder-from-above angle (see _look_at_dodge_angle()
# below) and returned to its normal position afterward
# (_restore_default_camera()). DEFAULT_CAM_POS/DEFAULT_CAM_LOOK are what
# _build_stage() builds it with in the first place - the single source of
# truth both the initial setup and the restore read from.
var _stage_camera: Camera3D
const DEFAULT_CAM_POS := Vector3(3.5, 1.8, 4.5)
const DEFAULT_CAM_LOOK := Vector3(0.0, 1.1, -1.5)

# Same green downward cone world.gd's own active-diver cursor uses (see
# World._active_cursor) - marks whichever DIVER's turn it currently is on
# the battle stage itself, not just the queue row's "NOW" card. Only ever
# shown during a party member's turn (_start_party_turn()); hidden the
# instant it's an enemy's turn (_do_enemy_turn()) - there's no equivalent
# "whose turn" marker needed over a grunt, the move log already says who's
# attacking.
var _turn_cursor: MeshInstance3D

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
const QTE_TRACK_WIDTH := 150.0
const QTE_TRACK_HEIGHT := 14.0

# Set for the duration of one _quick_time_event() call - _unhandled_input()
# only ever looks at these while _qte_active is true, so a stray X press
# outside a QTE (or during one that already resolved this frame) does
# nothing. No stored zone/duration fields alongside these two - qte_zone's
# and qte_indicator's own position/size ARE the hit-test data now (see
# _unhandled_input()), not a separate time-domain copy of them.
var _qte_active := false
var _qte_success := false

func _ready() -> void:
	layer = 10
	_build_party()
	_build_stage()
	_build_ui()
	_build_quick_time_ui()
	_refresh_all_bars()
	_rebuild_queue()
	_log("Enemies block the way!" if enemies.size() > 1 else "A goblin grunt blocks the way!")
	_advance_turn()

func _display(model_name: String) -> String:
	return String(DISPLAY_NAMES.get(model_name, model_name))

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
	s.barrier_max = int(base.barrier_max)
	s.grow_hp = int(base.grow_hp)
	s.grow_strength = int(base.grow_strength)
	s.grow_defense = int(base.grow_defense)
	s.grow_agility = int(base.grow_agility)
	s.grow_accuracy = int(base.get("grow_accuracy", 0))
	s.grow_evasion = int(base.get("grow_evasion", 0))
	s.fill()
	return s

func _build_party() -> void:
	if party_source.is_empty():
		party.append({
			"kind": "party", "stats": _default_player_stats(),
			"model_name": diver_model_name, "display_name": _display(diver_model_name),
			"equipped_spells": [],
		})
		return
	for d in party_source:
		var dv := d as Diver
		party.append({
			"kind": "party", "stats": dv.stats,
			"model_name": dv.model_name, "display_name": _display(dv.model_name),
			"equipped_spells": dv.equipped_spells, "ability_id": dv.ability_id,
		})

# A SubViewport with its own camera, light and fog: isolated from the dive
# site's World3D (own_world_3d) so the two scenes can't see each other.
# Builds one throwaway visual Diver per party member and however many
# Goblins the encounter rolled - these actors are display-only, the real
# stats live in party[]/enemies[], not on these nodes.
func _build_stage() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	add_child(container)

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

	# MODIFIED: promoted from a local `cam` variable to the _stage_camera
	# field below - nothing outside _build_stage() could reach it before,
	# so there was no way to move it for the dodge minigame (see
	# _look_at_dodge_angle()/_restore_default_camera()) and move it back
	# afterward. DEFAULT_CAM_POS/DEFAULT_CAM_LOOK are what it's built with
	# here AND what _restore_default_camera() returns it to - one source
	# of truth for "where the camera normally sits" instead of the same
	# two Vector3 literals living in two places that could drift apart.
	_stage_camera = Camera3D.new()
	_stage_camera.position = DEFAULT_CAM_POS
	_stage_camera.fov = 70.0
	vp.add_child(_stage_camera)
	# look_at() needs the node in the tree first - it operates on global
	# transform, which doesn't exist until add_child runs.
	_stage_camera.look_at(DEFAULT_CAM_LOOK, Vector3.UP)

	# Party visuals, spread left-to-right so 1-3 divers don't overlap.
	# Diver.rotation.y == 0 is the model's own rest-facing direction (-Z, see
	# diver.gd), so leaving it untouched here is what puts its back to camera.
	#
	# MODIFIED: used to build a puppet unconditionally for every party
	# entry, even one already at 0 HP going into this battle (e.g. downed
	# in a previous fight, never healed at a save point since). That
	# looked wrong - a fresh Diver.new() has no memory of being downed,
	# so it rendered as a completely normal, standing, undamaged puppet,
	# even though _living()-based filtering elsewhere already correctly
	# keeps them out of the turn queue and off enemy targeting. Now
	# skipped entirely for anyone already at 0 HP - same end state
	# play_death_fade() leaves a diver in once it finishes (invisible,
	# queue_free()'d), just arrived at directly instead of animating a
	# death that already happened before this fight even started. Every
	# .actor read elsewhere in this file already guards with .has("actor")
	# first, so a party entry with no actor at all is a safe, already-
	# supported shape, not a new edge case.
	# MODIFIED (added): special encounters play out both rock minigames
	# right in this same space - rocks flying in laterally, a grid in front
	# of the diver, a full second flight from that grid out to the enemy -
	# and the normal 3.2-unit gap (1.0 - -2.2) left barely any room for any
	# of that to read clearly. Pulled both actors back further apart only
	# for special encounters; a normal multi-enemy fight never runs either
	# minigame, so its own spacing is untouched.
	# MODIFIED (added): the swap minigame's two 3-lane portrait spreads
	# (see diver_swap_minigame.gd's _select_correct_portraits() spacing
	# math) need even more room than the rock-dodge encounter's single
	# lateral barrage - widened further, but only for whichever special
	# encounter actually has the sonar/swap diver as its one party member,
	# so the rock-dodge encounter's own already-tuned spacing is untouched.
	var is_swap_encounter := false
	if special_encounter:
		for p in party:
			if String(p.get("ability_id", "")) == "swap":
				is_swap_encounter = true
				break
	var diver_z := 3.4 if is_swap_encounter else (2.2 if special_encounter else 1.0)
	var enemy_z := -6.0 if is_swap_encounter else (-4.6 if special_encounter else -2.2)

	var pn := party.size()
	for i in range(pn):
		if (party[i].stats as CombatantStats).hp <= 0:
			continue
		var actor := Diver.new()
		actor.model_name = String(party[i].model_name)
		actor.position = Vector3(_spread(i, pn, 1.3) - 0.4, 0.0, diver_z)
		vp.add_child(actor)
		party[i]["actor"] = actor

	_build_turn_cursor()

	# Enemies: a random count, each with stats rolled close to the party's
	# own current average (see _party_average_stats()/goblin.gd's
	# make_stats()) rather than an independent level curve. The grunt's own
	# rest facing was never checked against the camera (no editor open to
	# look): 180 is a guess. Flip to 0 here if it turns out to be facing
	# away instead of into shot.
	var lvl := int((party[0].stats as CombatantStats).level) if not party.is_empty() else 1
	var ref_stats := _party_average_stats()
	# A special encounter is always a solo diver against exactly one grunt -
	# it's built around one character's ability minigame (see _do_enemy_
	# turn()'s special_encounter branch), not a real multi-enemy fight.
	var count := 1 if special_encounter else randi_range(MIN_ENEMIES, MAX_ENEMIES)
	for i in range(count):
		var g := Goblin.new()
		g.position = Vector3(_spread(i, count, 1.1) + 0.6, 0.0, enemy_z)
		g.rotation.y = PI
		vp.add_child(g)
		var st: CombatantStats = g.make_stats(ref_stats, lvl)
		enemies.append({
			"kind": "enemy", "stats": st,
			"display_name": "Grunt" if count == 1 else "Grunt %d" % (i + 1),
			"actor": g,
		})

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
	var sum_bar := 0
	for entry in pool:
		var s := entry.stats as CombatantStats
		sum_hp += s.hp_max
		sum_str += s.strength
		sum_def += s.defense
		sum_agi += s.agility
		sum_eva += s.evasion
		sum_acc += s.accuracy
		sum_bar += s.barrier_max
	avg.hp_max = int(round(float(sum_hp) / n))
	avg.strength = int(round(float(sum_str) / n))
	avg.defense = int(round(float(sum_def) / n))
	avg.agility = int(round(float(sum_agi) / n))
	avg.evasion = int(round(float(sum_eva) / n))
	avg.accuracy = int(round(float(sum_acc) / n))
	avg.barrier_max = int(round(float(sum_bar) / n))
	return avg

# Evenly spaces `n` actors around x=0, `step` apart - shared by the party
# row and the enemy row so both scale the same way from 1 up to 3 without
# separate hand-picked positions for each possible count.
func _spread(i: int, n: int, step: float) -> float:
	return (float(i) - float(n - 1) * 0.5) * step

func _build_ui() -> void:
	_bottom_panel = PanelContainer.new()
	_bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(_bottom_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 16)
	_bottom_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	queue_row = HBoxContainer.new()
	queue_row.add_theme_constant_override("separation", 10)
	col.add_child(queue_row)

	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 24)
	col.add_child(party_row)
	for entry in party:
		var b := _add_bar(party_row, String(entry.display_name))
		entry["hp_bar"] = b[0]
		entry["hp_label"] = b[1]
		entry["barrier_bar"] = b[2]

	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 24)
	col.add_child(enemy_row)
	for entry in enemies:
		var b := _add_bar(enemy_row, String(entry.display_name))
		entry["hp_bar"] = b[0]
		entry["hp_label"] = b[1]
		entry["barrier_bar"] = b[2]

	log_label = Label.new()
	log_label.custom_minimum_size = Vector2(0, 36)
	col.add_child(log_label)

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

	move_menu = HFlowContainer.new()
	move_menu.add_theme_constant_override("h_separation", 12)
	move_menu.add_theme_constant_override("v_separation", 8)
	move_menu.visible = false
	col.add_child(move_menu)
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

# Name plus a one-line tradeoff, right on the button: the choice needs to
# read before it's clicked, not just get explained after in the log.
func _menu_button(title: String, hint: String) -> Button:
	var b := Button.new()
	b.text = title if hint == "" else "%s\n%s" % [title, hint]
	b.custom_minimum_size = Vector2(150, 46)
	return b

# X-glyph panel (what to press) beside a track (when to press it), laid out
# by an HBoxContainer so "button then gauge" is just child order, not a
# hand-picked offset. Centered on screen, hidden until a QTE actually
# starts - see _quick_time_event().
func _build_quick_time_ui() -> void:
	qte_root = HBoxContainer.new()
	qte_root.set_anchors_preset(Control.PRESET_CENTER)
	qte_root.add_theme_constant_override("separation", 14)
	qte_root.visible = false
	add_child(qte_root)

	var button_panel := Panel.new()
	button_panel.custom_minimum_size = Vector2(34, 34)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.75, 0.2)
	style.set_corner_radius_all(17)
	button_panel.add_theme_stylebox_override("panel", style)
	qte_root.add_child(button_panel)

	var glyph := Label.new()
	glyph.text = "X"
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 18)
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
	qte_zone.size = Vector2(24, QTE_TRACK_HEIGHT)
	qte_track.add_child(qte_zone)

	qte_indicator = ColorRect.new()
	qte_indicator.color = Color(0.95, 0.95, 0.9)
	qte_indicator.size = Vector2(3, QTE_TRACK_HEIGHT)
	qte_track.add_child(qte_indicator)

# Races a keypress against the sweep reaching the end of the track - both
# sides now read the same pixel-space state the player can actually see
# (qte_zone's/qte_indicator's own position/size), nothing measured in
# seconds. _unhandled_input() is the keypress side (checks where the
# indicator visually is against the zone rect the instant X is pressed);
# tw.finished (below) is the timeout side, for a press that never came at
# all. The while loop just waits for whichever one flips _qte_active off,
# once per frame via `await get_tree().process_frame`.
func _quick_time_event() -> bool:
	var duration := 1.6
	var zone_width_frac := randf_range(0.06, 0.12)
	# Margin on both ends so the zone never touches the very start (an
	# instant, no-real-choice press) or the very end (indistinguishable
	# from a timeout) of the sweep.
	var zone_start_frac := randf_range(0.15, 1.0 - zone_width_frac - 0.15)

	qte_zone.position.x = zone_start_frac * QTE_TRACK_WIDTH
	qte_zone.size.x = zone_width_frac * QTE_TRACK_WIDTH
	qte_indicator.position.x = 0.0

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

# Only ever looked at while _qte_active is true (see _quick_time_event()) -
# a stray X press between fights, or one arriving the same frame the sweep
# already timed out, does nothing. The hit check compares the indicator's
# actual current position (wherever the tween has it as of the last
# processed frame - Godot handles input before advancing tweens within a
# frame, so this is accurate to well under a frame's worth of time, far
# tighter than human reaction time) against the zone ColorRect's own
# position/size - the same rect drawn on screen, not a parallel copy of it.
func _unhandled_input(event: InputEvent) -> void:
	if not _qte_active:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_X:
		var indicator_center: float = qte_indicator.position.x + qte_indicator.size.x * 0.5
		var zone_left: float = qte_zone.position.x
		var zone_right: float = qte_zone.position.x + qte_zone.size.x
		_qte_success = indicator_center >= zone_left and indicator_center <= zone_right
		_qte_active = false


func _add_bar(parent: Control, label_text: String) -> Array:
	var wrap := VBoxContainer.new()
	parent.add_child(wrap)
	var l := Label.new()
	l.text = label_text
	wrap.add_child(l)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	wrap.add_child(bar_row)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(160, 18)
	bar.show_percentage = false
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.78, 0.15, 0.15)
	bar.add_theme_stylebox_override("fill", hp_fill)
	bar_row.add_child(bar)

	var barrier_bar := ProgressBar.new()
	barrier_bar.custom_minimum_size = Vector2(40, 18)
	barrier_bar.show_percentage = false
	var barrier_fill := StyleBoxFlat.new()
	barrier_fill.bg_color = Color(0.62, 0.64, 0.68)
	barrier_bar.add_theme_stylebox_override("fill", barrier_fill)
	bar_row.add_child(barrier_bar)

	var hp_label := Label.new()
	wrap.add_child(hp_label)
	return [bar, hp_label, barrier_bar]

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
	_refresh_barrier_bar(entry.barrier_bar, s)

func _refresh_barrier_bar(bar: ProgressBar, stats: CombatantStats) -> void:
	bar.visible = stats.barrier_max > 0
	if not bar.visible:
		return
	bar.max_value = stats.barrier_max
	bar.value = stats.barrier

func _log(text: String) -> void:
	log_label.text = text

func _living(list: Array) -> Array:
	return list.filter(func(e: Dictionary) -> bool: return (e.stats as CombatantStats).hp > 0)

# One sort, shared by the initial build and every later re-sort - highest
# agility first. GDScript's sort_custom isn't guaranteed stable, so ties
# can shuffle relative to each other; nothing here depends on tie order
# staying fixed.
func _by_agility(a: Dictionary, b: Dictionary) -> bool:
	return (a.stats as CombatantStats).agility > (b.stats as CombatantStats).agility

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
	for i in range(_queue.size()):
		queue_row.add_child(_build_queue_chip(_queue[i], i))

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
	if _living(enemies).is_empty():
		_win()
		return
	if _living(party).is_empty():
		_lose()
		return
	if _queue.is_empty():
		_rebuild_queue()
	_acting = _queue.pop_front()
	_refresh_queue_row()
	if (_acting.stats as CombatantStats).hp <= 0:
		_advance_turn()   # downed since the queue was built - skip them
		return
	if String(_acting.kind) == "enemy":
		_do_enemy_turn(_acting)
	else:
		_start_party_turn(_acting)

func _start_party_turn(actor: Dictionary) -> void:
	_busy = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	main_menu.visible = true
	call_deferred("_fit_panel_height")
	_show_turn_cursor_on(actor)
	_log("%s's turn." % String(actor.display_name))
	_set_all_buttons(true)

# Only ever called with a party entry (see _advance_turn()'s kind check) -
# actor.actor is always the Diver battle-stage instance built in
# _build_stage(), never a Goblin, so no type check needed before the cast.
func _show_turn_cursor_on(actor: Dictionary) -> void:
	if not actor.has("actor") or not is_instance_valid(actor.actor):
		return
	var d := actor.actor as Diver
	_turn_cursor.visible = true
	_turn_cursor.global_position = d.global_position + Vector3.UP * (d.height + 0.4)

# This diver's own BASE_MOVES plus whatever they currently have equipped,
# translated from spell data into the same move shape battle resolution
# already expects - see SpellTree.find_def()'s header comment on why spell
# defs double as move defs directly. Falls back to Staff_Diver's kit for
# the standalone-Battle stand-in case (tools/test_battle.gd), same fallback
# Diver.BASE_STATS.get() already uses elsewhere.
# "special_encounter_only" (Blast Rocks, see BASE_MOVES above) is
# filtered out here rather than just left in the list and disabled -
# there's no ordinary-battle version of "gamble oxygen on a rock-timing
# minigame that could win the whole fight," so showing it greyed out in
# a normal fight would just be confusing dead UI, not a real choice
# waiting on some condition to unlock.
func _moves_for(entry: Dictionary) -> Array:
	var base: Array = BASE_MOVES.get(String(entry.model_name), BASE_MOVES["Staff_Diver"])
	var out: Array = base.duplicate()
	if not special_encounter:
		out = out.filter(func(mv: Dictionary) -> bool: return not bool(mv.get("special_encounter_only", false)))
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
	return out

func _show_moves() -> void:
	if _busy:
		return
	main_menu.visible = false
	_populate_move_menu(_acting)
	move_menu.visible = true
	call_deferred("_fit_panel_height")

func _populate_move_menu(actor: Dictionary) -> void:
	for b in move_buttons:
		(b as Button).queue_free()
	move_buttons.clear()
	var available: float = (actor.stats as CombatantStats).oxygen
	for mv in _moves_for(actor):
		var ox_cost: float = float(mv.get("oxygen_cost", 0.0))
		var hint: String = String(mv.hint)
		if ox_cost > 0.0:
			hint = "%s - %d O2" % [hint, int(ox_cost)]
		var b := _menu_button(String(mv.name), hint)
		b.disabled = available < ox_cost
		b.pressed.connect(_on_move_chosen.bind(mv))
		move_menu.add_child(b)
		move_buttons.append(b)
	# Keep Back last - it's a persistent child of move_menu, not rebuilt
	# here, so re-adding fresh move buttons pushes it out of place unless
	# it's explicitly moved back to the end each time.
	move_menu.move_child(back_btn, move_menu.get_child_count() - 1)

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

# heal/oxygen items only ever make sense on a living party member (a
# downed diver has no oxygen tank to top off either) - _living(party)
# same as a heal move's own target pool. Filtered further
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

# Always succeeds, no accuracy roll - same as _apply_heal()/_apply_barrier(),
# nothing about using an item on an ally is something they could evade.
# Mirrors _resolve_party_move()'s tail exactly (log, refresh bars, advance
# turn) so an item-use turn reads identically to a move turn.
func _resolve_item(item_id: String, target: Dictionary) -> void:
	if world == null:
		_advance_turn()
		return
	_busy = true
	_set_all_buttons(false)
	var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
	var msg := Items.grant(item_id, target.stats as CombatantStats)
	var count: int = int(world.inventory.get(item_id, 0))
	world.inventory[item_id] = count - 1
	if world.inventory[item_id] <= 0:
		world.inventory.erase(item_id)
	_refresh_bar(target)
	_log(msg if msg != "" else "%s - nothing happened." % display)
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_advance_turn()

func _show_main() -> void:
	if _busy:
		return
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	main_menu.visible = true
	call_deferred("_fit_panel_height")

# Barrier moves target the caster - a single-entry target list rather than an
# immediate resolve, same as everything else below, so choosing a buff
# spell still lands on a screen with Back rather than committing the
# instant it's picked. Heal targets a living ally (a downed one has
# nothing a heal can do for it - see _apply_revive() for that); revive
# targets a downed one specifically. Everything else still targets an
# enemy. Always shows the target picker, even for a single candidate
# (e.g. the common one-enemy fight) - that single extra button is what
# gives the player a Back to bail out on a move they picked by mistake
# (see target_back_btn/_show_moves_or_items_from_target_menu()); previously
# a lone target skipped straight to resolution with no way back at all. An
# empty pool (e.g. Revive with nobody actually down) just reopens the
# move menu instead of silently eating the button press.
func _on_move_chosen(mv: Dictionary) -> void:
	if _busy:
		return
	if (_acting.stats as CombatantStats).oxygen < float(mv.get("oxygen_cost", 0.0)):
		return
	move_menu.visible = false
	var effect := String(mv.get("effect", ""))
	# Blast Rocks always targets the encounter's one enemy directly - no
	# target picker, straight to its own minigame sequence (same "no real
	# choice to make" reasoning barrier/buff moves already skip a picker
	# for, just routed to a dedicated function instead of _resolve_party_
	# move() since nothing about this resolves like a normal move).
	if effect == "blast_rocks":
		var oxygen_cost := float(mv.get("oxygen_cost", 0.0))
		(_acting.stats as CombatantStats).oxygen -= oxygen_cost
		await _do_blast_rocks_attack(_acting)
		return
	var targets: Array
	match effect:
		"barrier":
			targets = [_acting]
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
	_populate_target_menu(targets)
	target_menu.visible = true
	call_deferred("_fit_panel_height")

func _populate_target_menu(targets: Array) -> void:
	for b in target_buttons:
		(b as Button).queue_free()
	target_buttons.clear()
	for t in targets:
		var s := t.stats as CombatantStats
		var b := _menu_button(String(t.display_name), "%d / %d HP" % [s.hp, s.hp_max])
		b.pressed.connect(_on_target_chosen.bind(t))
		target_menu.add_child(b)
		target_buttons.append(b)
	# Keep Back last - same reason move_menu's own back_btn gets
	# re-positioned in _populate_move_menu(): it's a persistent child, not
	# rebuilt above, so re-adding fresh target buttons pushes it out of
	# place unless it's explicitly moved back to the end each time.
	target_menu.move_child(target_back_btn, target_menu.get_child_count() - 1)

# Exactly one of _pending_move/_pending_item is ever set when target_menu
# is showing (see _on_move_chosen()/_on_item_chosen()) - branch on which,
# resolve it, then clear both so a stale pending value can never leak into
# the next turn's target picker.
func _on_target_chosen(target: Dictionary) -> void:
	target_menu.visible = false
	if _pending_item != "":
		var item_id := _pending_item
		_pending_item = ""
		_resolve_item(item_id, target)
		return
	_resolve_party_move(_pending_move, target)

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
#  4. Barrier absorbs damage before HP.
func _resolve_attack(attacker: CombatantStats, defender: CombatantStats, move: Dictionary) -> Dictionary:
	var effective_accuracy: int = attacker.accuracy + int(move.get("acc_mod", 0))
	if effective_accuracy <= defender.evasion:
		return {"hit": false, "damage": 0, "absorbed": 0, "debuff": "", "changed": 0, "dodged": false}

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

	# Only a move explicitly tagged for it (ENEMY_MOVE, currently) ever
	# triggers a QTE - a player's own attacks never set quick_time_bool, so
	# this is a no-op for anything the player swings themselves. A
	# successful dodge zeroes incoming outright.
	var player_dodge := false
	if bool(move.get("quick_time_bool", false)):
		player_dodge = await _quick_time_event()
	return apply_damage_roll(attacker, defender, move, variance, heavy_fraction, player_dodge)

# The deterministic half of _resolve_attack(), shared with verify/balance.gd.
# Production samples the variance/heavy fraction and the QTE result above;
# the seeded balance gate supplies those same inputs itself. Keeping the actual
# mutation and mitigation here prevents a test-only copy of the combat math
# drifting away from what players receive.
static func apply_damage_roll(attacker: CombatantStats, defender: CombatantStats, move: Dictionary, variance: float, heavy_fraction: float = 0.0, dodged: bool = false) -> Dictionary:
	var effective_accuracy: int = attacker.accuracy + int(move.get("acc_mod", 0))
	if effective_accuracy <= defender.evasion:
		return {"hit": false, "damage": 0, "absorbed": 0, "debuff": "", "changed": 0, "dodged": false}

	var raw: float
	if String(move.get("effect", "")) == "heavy":
		raw = float(defender.hp_max) * heavy_fraction
	else:
		raw = (float(move.power) + float(attacker.strength)) * variance
	var incoming: int = maxi(0, int(round(raw)) - defender.defense)
	if dodged:
		incoming = 0

	var absorbed := 0
	if defender.barrier > 0 and incoming > 0:
		absorbed = mini(defender.barrier, incoming)
		defender.barrier -= absorbed
	var to_hp: int = incoming - absorbed
	defender.hp = maxi(0, defender.hp - to_hp)
	return {"hit": true, "damage": to_hp, "absorbed": absorbed, "debuff": "", "changed": 0, "dodged": dodged}

# Dispatches on the move's "effect" key before falling through to the
# normal attack/debuff resolution above. "barrier" targets the caster instead of the
# defender and always succeeds, no accuracy check - raising your own
# stats isn't something the target could "evade." "heal"/"revive"
# (support-branch spells, see spell_tree.gd) target an ally instead of an
# enemy - `defender` here is really just "whoever _on_move_chosen()'s
# target picker resolved to," which for these two effects is a living or
# downed ally respectively, not literally a defender - and same as buff,
# always succeed: nothing about mending a wound is something the ally
# being healed could fail to receive.
func _resolve_move(attacker: CombatantStats, defender: CombatantStats, move: Dictionary) -> Dictionary:
	var effect := String(move.get("effect", ""))
	if effect == "barrier":
		return _apply_barrier(attacker, int(move.get("amount", 0)))
	if effect == "heal":
		return _apply_heal(defender, int(move.get("amount", 0)))
	if effect == "revive":
		return _apply_revive(defender, int(move.get("amount", 0)))
	return await _resolve_attack(attacker, defender, move)

func _apply_barrier(caster: CombatantStats, amount: int) -> Dictionary:
	var before := caster.barrier
	caster.barrier = mini(caster.barrier_max, caster.barrier + amount)
	var changed := caster.barrier - before
	return {"hit": true, "damage": 0, "absorbed": 0, "debuff": "barrier", "changed": changed}

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
func _apply_debuff(defender: CombatantStats, debuff: String, amount: int) -> Dictionary:
	var changed := 0
	match debuff:
		"defense":
			var before := defender.defense
			defender.defense = maxi(0, defender.defense - amount)
			changed = before - defender.defense
		"agility":
			var before := defender.agility
			defender.agility = maxi(1, defender.agility - amount)
			changed = before - defender.agility
		"accuracy":
			var before := defender.accuracy
			defender.accuracy = maxi(0, defender.accuracy - amount)
			changed = before - defender.accuracy
		"strength":
			var before := defender.strength
			defender.strength = maxi(0, defender.strength - amount)
			changed = before - defender.strength
		"evasion":
			var before := defender.evasion
			defender.evasion = maxi(0, defender.evasion - amount)
			changed = before - defender.evasion
	return {"hit": true, "damage": 0, "absorbed": 0, "debuff": debuff, "changed": changed}

func _log_player_result(actor: Dictionary, target: Dictionary, mv: Dictionary, r: Dictionary) -> void:
	var text: String = String(mv.get("text", "You use %s" % String(mv.name)))
	if not r.hit:
		_log("%s - %s evades!" % [text, String(target.display_name)])
		return
	if String(r.debuff) == "barrier":
		if int(r.changed) > 0:
			_log("%s - %s's barrier rises by %d." % [text, String(actor.display_name), int(r.changed)])
		else:
			_log("%s - %s's barrier is already full." % [text, String(actor.display_name)])
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
			_log("%s - %s has nothing left to lose there." % [text, String(target.display_name)])
		return
	if int(r.damage) == 0 and int(r.absorbed) > 0:
		_log("%s - %s's barrier soaks it completely!" % [text, String(target.display_name)])
	elif int(r.absorbed) > 0:
		_log("%s for %d (%d soaked by barrier)." % [text, int(r.damage), int(r.absorbed)])
	else:
		_log("%s for %d." % [text, int(r.damage)])

# Swing first, resolve at the moment of impact. Returns once the hit is
# supposed to land, leaving the rest of the clip to play out underneath the
# damage log. A move with no actor (a headless run, see verify/battle.gd)
# resolves instantly, so the gates are not paying for animation time.
func _swing(entry: Dictionary, mv: Dictionary) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor) or not (entry.actor is Diver):
		return
	var d := entry.actor as Diver
	var length: float = d.play_clip(Cast.ability(String(entry.model_name), String(mv.get("name", ""))))
	if length <= 0.0:
		return
	await get_tree().create_timer(length * IMPACT_FRACTION).timeout

# The recoil on whoever just got hit. Only for a hit that actually landed
# damage: a heal targets an ally, and flinching at being healed is worse
# than not reacting at all.
func _react(entry: Dictionary, r: Dictionary) -> void:
	if not bool(r.get("hit", false)) or int(r.get("damage", 0)) <= 0:
		return
	if not entry.has("actor") or not is_instance_valid(entry.actor) or not (entry.actor is Diver):
		return
	if (entry.stats as CombatantStats).hp <= 0:
		return   # going down has its own animation, see play_death_fade()
	# Two reactions ship per character. "Heavy" is a hit worth a fifth of
	# what this one can take, so the big recoil means something rather than
	# being the one that always plays.
	var heavy: bool = float(r.damage) >= float((entry.stats as CombatantStats).hp_max) * 0.2
	(entry.actor as Diver).play_hit_reaction(heavy)

func _resolve_party_move(mv: Dictionary, target: Dictionary) -> void:
	if target.is_empty():
		_advance_turn()
		return
	_busy = true
	_set_all_buttons(false)

	(_acting.stats as CombatantStats).oxygen -= float(mv.get("oxygen_cost", 0.0))
	await _swing(_acting, mv)
	var r: Dictionary = await _resolve_move(_acting.stats, target.stats, mv)
	_react(target, r)
	if r.hit and String(r.debuff) == "agility":
		_resort_pending()
	_refresh_bar(target)
	_refresh_bar(_acting)
	_log_player_result(_acting, target, mv, r)

	# A killing blow gets the fade instead of the usual walk/idle reaction -
	# a dying grunt shouldn't play a normal hit-react animation, the fade
	# itself is the reaction. play_death_fade() frees the actor once it
	# finishes (goblin.gd), so nothing after this point may safely touch it
	# again - is_instance_valid() below is what keeps the idle call honest
	# about that instead of assuming LOG_READ_DELAY and the fade duration
	# never overlap.
	var target_died: bool = target.has("stats") and (target.stats as CombatantStats).hp <= 0
	if target_died and target.has("actor") and target.actor is Goblin:
		(target.actor as Goblin).play_death_fade()
	elif r.hit and String(r.debuff) == "" and target.has("actor") and target.actor is Goblin:
		(target.actor as Goblin).play("walk")
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	if not target_died and target.has("actor") and is_instance_valid(target.actor) and target.actor is Goblin:
		(target.actor as Goblin).play("idle")
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

func _do_enemy_turn(actor: Dictionary) -> void:
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
	var target: Dictionary = _pick_enemy_target(alive_party)
	var target_stats := target.stats as CombatantStats

	# Marine Man's special-encounter minigame takes over the enemy's whole
	# attack turn instead of a normal claw/heavy swing - see
	# rock_dodge_minigame.gd. Only reachable in a special (solo) encounter
	# (see World._on_special_encounter_diver_chosen()) where the one diver
	# actually in the fight has the shockwave ability - ability_id now
	# rides along on each party dict entry (see _build_stage()'s
	# party_source loop) specifically so this check can read it without
	# needing the real Diver node.
	# MODIFIED: was missing this return - without it, execution fell
	# through into the normal attack code right below after the minigame
	# already resolved (and already called _advance_turn() itself),
	# double-damaging the target and double-advancing the turn queue.
	if special_encounter and String(target.get("ability_id", "")) == "shockwave":
		await _do_rock_dodge_encounter(actor, target, target_stats)
		return
	elif special_encounter and String(target.get("ability_id", "")) == "swap":
		await _do_swap_minigame(actor, target, target_stats)
		return

	# "Lined up" means the target's already low enough that a heavy swing's
	# own damage range (see ENEMY_HEAVY_MOVE's heavy_max, a fraction of
	# their OWN max HP) could plausibly be a kill - not a fixed HP number,
	# so this scales correctly across levels the same way the heavy swing's
	# damage itself already does.
	var lined_up: bool = float(target_stats.hp) <= float(target_stats.hp_max) * float(ENEMY_HEAVY_MOVE.heavy_max)
	var heavy := randf() < (ENEMY_HEAVY_FINISH_CHANCE if lined_up else ENEMY_HEAVY_CHANCE)
	# Escalation: a fresh copy of the base move with power (and, for a
	# heavy swing, its hp-fraction range) scaled up by how many rounds
	# this special encounter has already run - see _enemy_power_mult().
	# A plain multiplier can't just scale r.damage after the fact (HP's
	# already been subtracted inside _resolve_attack() by then), so this
	# scales the INPUT instead and lets the normal formula do the rest.
	var base_move: Dictionary = ENEMY_HEAVY_MOVE if heavy else ENEMY_MOVE
	var move_dict: Dictionary = base_move.duplicate()
	if special_encounter:
		var mult := _enemy_power_mult()
		move_dict.power = float(move_dict.get("power", 0)) * mult
		if move_dict.has("heavy_min"):
			move_dict.heavy_min = float(move_dict.heavy_min) * mult
			move_dict.heavy_max = float(move_dict.heavy_max) * mult
	var r: Dictionary = await _resolve_attack(actor.stats, target.stats, move_dict)
	_refresh_bar(target)
	_react(target, r)
	var verb := ("%s winds up and slams into %s" % [String(actor.display_name), String(target.display_name)]) if heavy else ("%s claws at %s" % [String(actor.display_name), String(target.display_name)])
	if bool(r.get("dodged", false)):
		_log("%s - %s times it perfectly and dodges clear!" % [verb, String(target.display_name)])
	elif not r.hit:
		_log("%s, but %s evades!" % [verb, String(target.display_name)])
	else:
		_log("%s for %d." % [verb, int(r.damage)])
	if (target.stats as CombatantStats).hp <= 0 and target.has("actor") and target.actor is Diver:
		(target.actor as Diver).play_death_fade()
	if special_encounter:
		_special_round += 1
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_advance_turn()

# Only used during the dodge minigame (see _do_rock_dodge_encounter()) -
# normal attacks/Blast Rocks never call this, so the camera stays exactly
# where _build_stage() put it the rest of the time. Positioned up and to
# the diver's own right, angled down at them via look_at() - "over their
# shoulder from above" rather than the default straight-on framing, so
# rocks arriving from either side (blast_rocks_minigame.gd's rocks fly in
# from ±6 units laterally) are visible approaching instead of arriving
# from off-screen. Offsets are a first pass - worth eyeballing in an
# actual dodge sequence and adjusting if the incoming rocks read as too
# tight/wide in frame.
func _look_at_dodge_angle(target_pos: Vector3) -> void:
	_stage_camera.position = target_pos + Vector3(3.0, 3.5, 2.0)
	_stage_camera.look_at(target_pos, Vector3.UP)

# Only used during the portrait-swap minigame (see _do_swap_minigame()) -
# _look_at_dodge_angle() above is too tight for this one: that framing only
# has to cover one point (the target diver) from a few units away, but this
# minigame spreads two full 3-lane portrait rows (see diver_swap_minigame.gd's
# _select_correct_portraits() spacing math) across the entire enemy-to-player
# gap, which special_encounter's own widened is_swap_encounter spacing (see
# _build_stage()) makes even bigger. Looks at the midpoint between the two
# actors instead of just the target, pulled back and up further, with a
# wider FOV, so both actors and both portrait spreads stay in frame.
func _look_at_swap_angle(target_pos: Vector3, enemy_pos: Vector3) -> void:
	var mid := (target_pos + enemy_pos) / 2.0
	_stage_camera.position = mid + Vector3(0.0, 7.0, 7.0)
	_stage_camera.fov = 85.0
	_stage_camera.look_at(mid, Vector3.UP)

func _restore_default_camera() -> void:
	_stage_camera.position = DEFAULT_CAM_POS
	_stage_camera.fov = 70.0
	_stage_camera.look_at(DEFAULT_CAM_LOOK, Vector3.UP)

# Each rock that lands unbroken deals its own real hit, live, the instant
# it lands (via RockDodgeMinigame's rock_landed signal) - not one lump
# sum computed after the fact. Same power/strength/variance math as a
# normal ENEMY_MOVE swing (see _resolve_attack()), so one missed rock
# hurts about as much as one normal claw would - across a whole barrage
# that adds up fast, which is the actual incentive to play the minigame
# well rather than a graded curve papering over misses. If this drops the
# diver to 0 HP mid-barrage, _advance_turn()'s normal _lose() path still
# fires exactly like any other loss once the barrage ends - the "you
# don't really lose here" promise is handled entirely on World's side
# (see _on_battle_finished()'s special_encounter branch), not by this
# function pretending 0 HP can't happen.
var total_taken := 0

func _do_rock_dodge_encounter(actor: Dictionary, target: Dictionary, target_stats: CombatantStats) -> void:
	_log("%s hurls a barrage of rocks at %s!" % [String(actor.display_name), String(target.display_name)])
	await get_tree().create_timer(LOG_READ_DELAY).timeout

	_look_at_dodge_angle(target.actor.global_position)

	var minigame := RockDodgeMinigame.new()
	minigame.thrower_position = actor.actor.global_position + Vector3.UP * (actor.actor as Goblin).height
	add_child(minigame)
	minigame.stage_root = _stage_vp
	# MODIFIED: was `_acting.actor`. This function runs from _do_enemy_
	# turn(), where _acting IS the enemy taking their turn (same
	# Dictionary as the `actor` param above) - so this was pointing
	# target_actor at the GOBLIN, not the diver being attacked. Two
	# separate symptoms traced back to this one line: rocks visually
	# flew toward the enemy's own position instead of the player's (both
	# thrower_position and target_actor ended up near the same spot), and
	# `(target_actor as Diver)._shockwave_vfx()` in rock_dodge_minigame.gd
	# crashed with a nil error - casting a Goblin `as Diver` fails
	# silently to null in GDScript, and calling a method on that null
	# result is exactly a "nil" error. `target` (the actual diver, picked
	# by _pick_enemy_target() before this function was even called) is
	# what this should have been reading all along.
	minigame.target_actor = target.actor
	minigame.rock_landed.connect(func() -> void:
		# MODIFIED: no longer scaled by _enemy_power_mult() - an unbroken
		# rock now always hits for the same base amount every round, round
		# after round. The escalation moved to the real follow-up swing
		# right after the barrage instead (below) - see its own comment for
		# why.
		var raw: float = (float(ENEMY_MOVE.power) + float(actor.stats.strength)) * randf_range(0.85, 1.15)
		var incoming: int = maxi(0, int(round(raw)) - target_stats.defense)
		target_stats.hp = maxi(0, target_stats.hp - incoming)
		total_taken += incoming
		_refresh_bar(target)
		_show_damage_popup(incoming)
	)
	# MODIFIED: minigame.run() was never called - _spawn_loop() only ever
	# starts from inside run(), so without this the minigame just sat on
	# its title/hint text forever and `await minigame.finished` below
	# would hang the whole battle indefinitely. Same fix applied to
	# _do_blast_rocks_attack()'s BlastRocksMinigame below.
	minigame.run()
	var result: Array = await minigame.finished
	minigame.queue_free()
	_restore_default_camera()
	var hits := int(result[0])
	var total := int(result[1])

	if total_taken <= 0:
		_log("%s shatters every rock - not a scratch! (%d/%d)" % [String(target.display_name), hits, total])
	else:
		_log("%s couldn't break them all - takes %d total. (%d/%d)" % [String(target.display_name), total_taken, hits, total])
	if target_stats.hp <= 0 and target.has("actor") and target.actor is Diver:
		(target.actor as Diver).play_death_fade()

	# MODIFIED (added): the real follow-up - once the barrage itself is
	# done, the goblin closes in with one genuine swing (same accuracy/
	# evasion-checked _resolve_attack() a normal turn uses), its power
	# scaled by _enemy_power_mult(). This is where round-over-round
	# escalation lives now, not on the rocks themselves (see rock_landed
	# above) - a barrage should stay a learnable, evadable pattern no
	# matter how long the fight drags on; only this closing swing is
	# supposed to get scarier the longer it goes.
	if target_stats.hp > 0:
		var mult := _enemy_power_mult()
		var move_dict: Dictionary = ENEMY_MOVE.duplicate()
		move_dict.power = float(move_dict.get("power", 0)) * mult
		var r: Dictionary = await _resolve_attack(actor.stats, target_stats, move_dict)
		_refresh_bar(target)
		if bool(r.get("dodged", false)):
			_log("%s follows up, but %s times it perfectly and dodges clear!" % [String(actor.display_name), String(target.display_name)])
		elif not r.hit:
			_log("%s follows up, but %s evades!" % [String(actor.display_name), String(target.display_name)])
		else:
			_log("%s follows up for %d." % [String(actor.display_name), int(r.damage)])
		if target_stats.hp <= 0 and target.has("actor") and target.actor is Diver:
			(target.actor as Diver).play_death_fade()

	_special_round += 1
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_advance_turn()
	
func _do_swap_minigame(actor: Dictionary, target: Dictionary, target_stats: CombatantStats) -> void:
	_log("%s sends portraits your way!" % [String(actor.display_name), String(target.display_name)])
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_look_at_swap_angle(target.actor.global_position, actor.actor.global_position)

	var minigame := DiverSwapMinigame.new()
	add_child(minigame)
	minigame.stage_root = _stage_vp

	minigame.target_actor = target.actor
	minigame.enemy_actor = actor.actor
	minigame.portrait_landed.connect(func() -> void:
		# MODIFIED: no longer scaled by _enemy_power_mult() - an unbroken
		# rock now always hits for the same base amount every round, round
		# after round. The escalation moved to the real follow-up swing
		# right after the barrage instead (below) - see its own comment for
		# why.
		# MODIFIED (added): result cut to a quarter relative to the
		# rock-dodge encounter's identical formula - that barrage allows up
		# to ROCK_COUNT (8) misses, while this one allows at most 2 per
		# round (see diver_swap_minigame.gd's _on_portrait_arrived()), so
		# full price per miss would make a single misfire cost as much as a
		# whole failed rock barrage's worth of individual hits. Was tried
		# as `ENEMY_MOVE.power * 0.5` first, but strength - boosted further
		# by Goblin.make_stats()'s own 1.08x-1.35x difficulty edge over the
		# party's average - was always the bigger term in this formula, so
		# halving only power barely moved the result. Scaling the whole
		# post-defense result instead actually cuts it proportionally
		# regardless of how power/strength/defense interact.
		var raw: float = (float(ENEMY_MOVE.power) + float(actor.stats.strength)) * randf_range(0.85, 1.15)
		var full_incoming: int = maxi(0, int(round(raw)) - target_stats.defense)
		var incoming: int = int(round(float(full_incoming) * 0.25))
		target_stats.hp = maxi(0, target_stats.hp - incoming)
		total_taken += incoming
		_refresh_bar(target)
		_show_damage_popup(incoming)
	)
	# MODIFIED: minigame.run() was never called - _spawn_loop() only ever
	# starts from inside run(), so without this the minigame just sat on
	# its title/hint text forever and `await minigame.finished` below
	# would hang the whole battle indefinitely. Same fix applied to
	# _do_blast_rocks_attack()'s BlastRocksMinigame below.
	minigame.run()
	var result: Array = await minigame.finished
	minigame.queue_free()
	_restore_default_camera()
	var hits := int(result[0])
	var total := int(result[1])

	if total_taken <= 0:
		_log("%s swapped all portraits correctly - not a scratch! (%d/%d)" % [String(target.display_name), hits, total])
	else:
		_log("%s couldn't swap all portraits to their correct positions - takes %d total. (%d/%d)" % [String(target.display_name), total_taken, hits, total])
	if target_stats.hp <= 0 and target.has("actor") and target.actor is Diver:
		(target.actor as Diver).play_death_fade()

	# MODIFIED (added): the real follow-up - once the barrage itself is
	# done, the goblin closes in with one genuine swing (same accuracy/
	# evasion-checked _resolve_attack() a normal turn uses), its power
	# scaled by _enemy_power_mult(). This is where round-over-round
	# escalation lives now, not on the rocks themselves (see rock_landed
	# above) - a barrage should stay a learnable, evadable pattern no
	# matter how long the fight drags on; only this closing swing is
	# supposed to get scarier the longer it goes.
	if target_stats.hp > 0:
		var mult := _enemy_power_mult()
		var move_dict: Dictionary = ENEMY_MOVE.duplicate()
		move_dict.power = float(move_dict.get("power", 0)) * mult
		var r: Dictionary = await _resolve_attack(actor.stats, target_stats, move_dict)
		_refresh_bar(target)
		if bool(r.get("dodged", false)):
			_log("%s follows up, but %s times it perfectly and dodges clear!" % [String(actor.display_name), String(target.display_name)])
		elif not r.hit:
			_log("%s follows up, but %s evades!" % [String(actor.display_name), String(target.display_name)])
		else:
			_log("%s follows up for %d." % [String(actor.display_name), int(r.damage)])
		if target_stats.hp <= 0 and target.has("actor") and target.actor is Diver:
			(target.actor as Diver).play_death_fade()

	_special_round += 1
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_advance_turn()


# A floating "-N" that rises and fades, spawned fresh per hit rather than
# reused - each one is a one-shot throwaway, same VFX-node-per-event
# pattern diver.gd's _shockwave_vfx() already uses. Centered near the top
# of this CanvasLayer, not tied to the enemy's actual 3D position on the
# stage - the minigame overlay already covers the whole screen, and a
# fixed "damage lands here" spot is simpler and reads just as clearly as
# tracking a 3D-to-2D projection would.
func _show_damage_popup(amount: int) -> void:
	var popup := Label.new()
	popup.text = "-%d" % amount
	popup.add_theme_font_size_override("font_size", 26)
	popup.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	popup.set_anchors_preset(Control.PRESET_CENTER_TOP)
	popup.position = Vector2(-20, 90 + randf_range(-10.0, 10.0))
	add_child(popup)
	var tw := create_tween()
	tw.tween_property(popup, "position:y", popup.position.y - 40.0, 0.8)
	tw.parallel().tween_property(popup, "modulate:a", 0.0, 0.8)
	tw.tween_callback(popup.queue_free)

# The offensive counterpart to _do_rock_dodge_encounter() - Marine Man's
# own move (see BASE_MOVES' "Blast Rocks" entry), not the enemy's turn.
# Each successfully blasted rock (blast_rocks_minigame.gd's rock_blasted
# signal) deals its own hit to the enemy live, with its own damage popup,
# same per-event shape the dodge minigame's damage already uses - not a
# lump sum computed after the fact. Player damage output does NOT scale
# with _enemy_power_mult() - that ramp is specifically the enemy hitting
# harder over time, not the player hitting softer; the escalation's whole
# point is pressure to finish the fight, not a debuff on this move itself.
func _do_blast_rocks_attack(actor: Dictionary) -> void:
	_busy = true
	_set_all_buttons(false)
	_log("%s calls up a barrage of rocks!" % String(actor.display_name))
	await get_tree().create_timer(LOG_READ_DELAY).timeout

	var living_enemies := _living(enemies)
	var enemy: Dictionary = living_enemies[0] if not living_enemies.is_empty() else {}
	var enemy_stats: CombatantStats = enemy.stats as CombatantStats if not enemy.is_empty() else null

	# MODIFIED (added): nothing to blast toward - skip the minigame
	# entirely rather than running it with no enemy_actor to fly rocks at.
	# Previously this fell through into building/running the minigame
	# regardless, which would have hit the exact same missing-actor crash
	# fixed below the instant a rock tried to land.
	if enemy_stats == null:
		_log("%s calls up a barrage, but there's nothing left to hit." % String(actor.display_name))
		await get_tree().create_timer(LOG_READ_DELAY).timeout
		_advance_turn()
		return

	var minigame := BlastRocksMinigame.new()
	add_child(minigame)
	# MODIFIED (added): these three were never set - stage_root/diver_actor/
	# enemy_actor all stayed null, so the very first rock in
	# blast_rocks_minigame.gd's _run_one_rock() crashed reading
	# diver_actor.global_position (a method call on null). That crash
	# killed the coroutine outright, `finished` never got emitted, and
	# `await minigame.finished` below hung forever - the whole battle
	# looked frozen, and since no rock ever even spawned, it also looked
	# like pressing E to shockwave just did nothing.
	minigame.stage_root = _stage_vp
	minigame.diver_actor = actor.actor
	minigame.enemy_actor = enemy.actor
	var total_dealt := 0
	minigame.rock_blasted.connect(func() -> void:
		var raw: float = (10.0 + float((actor.stats as CombatantStats).strength)) * randf_range(0.85, 1.15)
		var incoming: int = maxi(0, int(round(raw)) - enemy_stats.defense)
		enemy_stats.hp = maxi(0, enemy_stats.hp - incoming)
		total_dealt += incoming
		_refresh_bar(enemy)
		_show_damage_popup(incoming)
	)
	minigame.run()
	var result: Array = await minigame.finished
	minigame.queue_free()
	var hits := int(result[0])
	var total := int(result[1])

	if total_dealt <= 0:
		_log("%s couldn't land a single blast. (%d/%d)" % [String(actor.display_name), hits, total])
	else:
		_log("%s slams %s for %d total! (%d/%d)" % [String(actor.display_name), String(enemy.display_name), total_dealt, hits, total])
	if enemy_stats != null and enemy_stats.hp <= 0 and enemy.has("actor") and enemy.actor is Goblin:
		(enemy.actor as Goblin).play_death_fade()
	_special_round += 1
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	_advance_turn()

func _win() -> void:
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	_log("The enemies back off, beaten.")
	# Whoever is still standing celebrates. The clip loops, so it holds for
	# as long as the XP lines take to read.
	for entry in _living(party):
		if entry.has("actor") and is_instance_valid(entry.actor) and entry.actor is Diver:
			(entry.actor as Diver).play_win()
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	var total_xp := 0
	for e in enemies:
		if e.has("actor") and is_instance_valid(e.actor) and e.actor is Goblin:
			total_xp += int((e.actor as Goblin).xp_reward)
	# A special encounter is a real, deliberate risk (see world.gd's
	# confirm-then-choose prompt) against a single grunt rather than the
	# usual 1-3 - the XP a normal fight would pay out for that alone
	# undersells it, so it's worth meaningfully more for taking the
	# gauntlet at all, on top of whatever treasure it's guarding.
	const SPECIAL_ENCOUNTER_XP_MULT := 1.5
	if special_encounter:
		total_xp = int(round(float(total_xp) * SPECIAL_ENCOUNTER_XP_MULT))
	# Every party member gets the full amount, not a split share - there's
	# no shared party XP pool concept in this game, and splitting it would
	# just make leveling slower for the same fights without adding a
	# meaningful choice anywhere. One shared line (not one per member,
	# since they all get the identical total) - XP gain used to be
	# entirely silent unless it happened to cross a level, so a win that
	# only made progress toward the next level gave no feedback at all.
	_log("The party gains %d XP." % total_xp)
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	for entry in party:
		var levels: Array = (entry.stats as CombatantStats).gain_xp(total_xp)
		for lv in levels:
			# +1 spell point per level is CombatantStats.gain_xp()'s own
			# rule (see combatant_stats.gd) - stated explicitly here since
			# the level-up line used to be the only feedback a level-up
			# gave at all, with the spell point itself going unmentioned.
			_log("%s reached level %d! (+1 spell point)" % [String(entry.display_name), int(lv)])
			await get_tree().create_timer(LOG_READ_DELAY).timeout
	finished.emit("won")

func _lose() -> void:
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	_log("The party is battered and pulls back.")
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	finished.emit("lost")

func _on_run() -> void:
	if _busy:
		return
	_busy = true
	_set_all_buttons(false)
	main_menu.visible = false

	if randf() <= RUN_CHANCE:
		_log("The party breaks off and swims for it.")
		await get_tree().create_timer(LOG_READ_DELAY).timeout
		finished.emit("fled")
		return

	var living_enemies := _living(enemies)
	var blocker := String(living_enemies[0].display_name) if not living_enemies.is_empty() else "something"
	_log("Can't get clear - %s cuts you off!" % blocker)
	await get_tree().create_timer(LOG_READ_DELAY).timeout
	if not living_enemies.is_empty():
		var attacker: Dictionary = living_enemies[randi_range(0, living_enemies.size() - 1)]
		var r: Dictionary = await _resolve_attack(attacker.stats, _acting.stats, ENEMY_MOVE)
		_refresh_bar(_acting)
		if bool(r.get("dodged", false)):
			_log("%s lunges - you time it perfectly and dodge clear!" % String(attacker.display_name))
		elif not r.hit:
			_log("%s lunges, but you evade clear." % String(attacker.display_name))
		else:
			_log("%s claws you for %d as you struggle free." % [String(attacker.display_name), int(r.damage)])
		if (_acting.stats as CombatantStats).hp <= 0 and _acting.has("actor") and _acting.actor is Diver:
			(_acting.actor as Diver).play_death_fade()
		await get_tree().create_timer(LOG_READ_DELAY).timeout
	_advance_turn()

func _set_all_buttons(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	run_btn.disabled = not enabled
	items_btn.disabled = not enabled
	back_btn.disabled = not enabled
	item_back_btn.disabled = not enabled
	target_back_btn.disabled = not enabled
	for b in move_buttons:
		(b as Button).disabled = not enabled
	for b in target_buttons:
		(b as Button).disabled = not enabled
	for b in item_buttons:
		(b as Button).disabled = not enabled
