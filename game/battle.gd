# Turn-based encounter screen: a small 3D stage with the party and enemies plus
# a menu. world.gd freezes the dive while this is up and resumes on `finished`.
#
# Combatants are Dictionaries in `party` and `enemies`:
# {kind, stats, model_name, display_name, equipped_spells, actor, hp_bar, hp_label}.
#
# Turn order is a live queue (`_queue`) sorted by agility each round; landed
# agility debuffs re-sort the waiting entries (_rebuild_queue/_resort_pending).
class_name Battle
extends CanvasLayer

const BOSS_LAB_SCENE := preload("res://art/deep_zone/Broken_Office.fbx")
const PrologueOctopusScript := preload("res://game/prologue_octopus.gd")

signal finished(result: String)     # "won", "fled", or "lost"
signal prologue_angler_defeated
signal prologue_phase_changed(phase: String)
signal prologue_strike_resolved(move_name: String, target_name: String, result: Dictionary)
# Emitted once a party actor has stepped in, faced its target and started its
# attack clip. Used by the fight test gate, not gameplay.
signal player_swing_staged(attacker: Node3D, target: Node3D)
# Resolved-turn boundaries for authored continuous encounters.
signal encounter_wave_cleared(wave: int, total: int)
signal encounter_wave_started(wave: int, total: int)

# Set by world.gd before add_child: the real Diver nodes. Their .stats Resource
# is shared by reference so level-ups carry back out; only read here.
var party_source: Array = []
# Selected by World before its reveal. Empty keeps the direct Battle entry path.
var ordinary_enemy_ids: Array[String] = []

# World owns inventory and spell-unlock relics for world fights.
var world: World
var reward_item_on_win := ""
const ITEM_CARRIER_INTRO := "This enemy is carrying an item! Defeat the enemy and win the item."
var _intro_hold := ""
var encounter_intro_override := ""
const PUPPET_HP := 9
# Seconds the opening line stays up before the first turn (0 = straight in).
var encounter_intro_hold := 0.0
# Without a World (standalone maze), items come from this shared dictionary.
var inventory_source: Dictionary = {}
var campaign_key_items_source: Array[String] = []

func _party_inventory() -> Dictionary:
	return world.inventory if world != null else inventory_source

# Set by World for the Glassgoat route: builds one TethysBoss instead of grunts.
var boss_encounter := false
# Key-item guardian battles are solo ability challenges; independent of boss_encounter.
var special_encounter := false
var _special_round := 0
# Artifact guardian fights stay one-on-one with the visible guardian.
var guardian_encounter := false
# Identity of the visible artifact guardian, so rewards are never randomized.
var guardian_enemy_id := "angler"
# Provenance for logs and route verification; World sets non-random sources.
var encounter_source := "random"

# Authored maze waves using shared species tuning.
const PUPPET_WAVES := [
	["angler", "swordfish_duelist", "frilled_shark"],
	["bomb_bot", "sword_slayer"],
]
var _puppet_wave := 0
var _puppet_completed_xp := 0

# Dedicated first-run fight: real attacks only, one fragile Angler, and a pause
# at defeat so World can reveal Cordys. Never mutates shared Angler tuning.
var prologue_angler_encounter := false
var _prologue_angler_interrupted := false
var prologue_octopus_encounter := false
var _prologue_response_resolved := false
var _prologue_strike_index := 0

# Choreographed first fight: all three divers vs one weakened goblin. Walks
# through one scripted move per stage (see _apply_tutorial_move_gate()) and
# forces one QTE (_tutorial_prep_enemy_turn()); the outcome is still real.
var tutorial_encounter := false
# Tutorial stages as (party index, forced move) pairs; stages 3-4 revisit
# Musashi and Maxilani, so stage index != party index.
const _TUTORIAL_SCRIPT: Array[Dictionary] = [
	{"party_index": 0, "move": "Electric Touch"},   # Maxilani
	{"party_index": 1, "move": "Precise Tap"},       # Musashi
	{"party_index": 2, "move": "Crushing Haymaker"}, # Mech Pilot
	{"party_index": 1, "move": "Weaken"},            # Musashi again
	{"party_index": 0, "move": "Flash Blast"},       # Maxilani again
]
# Next _TUTORIAL_SCRIPT stage. Advances only when that stage's diver acts
# (_is_tutorial_scripted_turn()); other turns play out normally.
var _tutorial_step := 0
var _tutorial_enemy_turns := 0
# One-shot guard for the "Defeat the enemy!" prompt.
var _tutorial_finale_shown := false
# One-shot guard for the first special encounter's finale. Can't reuse the
# tutorial trigger: in a solo party _tutorial_step never reaches the script end.
var _special_tutorial_finale_shown := false
# Forces the next enemy swing into a QTE; consumed by _resolve_attack().
var _tutorial_force_next_qte := false
var _tutorial_flash_tween: Tween
var _skip_tutorial_flash_tween: Tween
var _tutorial_caption: RichTextLabel
var _swap_demo_frame: PanelContainer
# Per-diver level-up stat table shown by _win(), any fight.
var _levelup_caption: RichTextLabel
# Lazily built red border overlaying _queue_bar.
var _turn_order_highlight: Panel
# "Coming up" chips drawn by _refresh_queue_row(), besides the "NOW" chip.
const MAX_QUEUE_SLOTS := 8
# Verification can hold the automatic entrance/turn dispatcher. Shipped encounters keep this true.
var boss_intro_enabled := true

func _enemy_power_mult() -> float:
	return 1.0 + 0.15 * float(_special_round)

# Fallback identity when there is no party_source (bare test Battle).
var diver_model_name := "Staff_Diver"

const RUN_CHANCE := 0.6
const MIN_ENEMIES := 1
const MAX_ENEMIES := 3

# Ordinary encounters field up to three enemies at every level; guardians stay solo.
static func max_enemies_for_level(_player_level: int, is_guardian: bool = false) -> int:
	if is_guardian:
		return 1
	return MAX_ENEMIES

# Shared roll policy: one, two or three enemies with equal odds.
static func ordinary_enemy_count_for_roll(_player_level: int, roll: float, is_guardian: bool = false) -> int:
	if is_guardian:
		return 1
	var normalized := clampf(roll, 0.0, 0.999999)
	if normalized < 1.0 / 3.0:
		return 1
	return 2 if normalized < 2.0 / 3.0 else 3

static func select_ordinary_enemies(player_level: int) -> Array[String]:
	var selected: Array[String] = []
	for index in range(ordinary_enemy_count_for_roll(player_level, randf())):
		selected.append(EnemyRoster.random_id())
	return selected

# `two` keeps the primary and adds one other living diver; `all` keeps party order.
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

# Multi-hit moves consume Evasion sequentially; self-costs apply on the first impact only.
static func resolve_formula_hits(attacker: CombatantStats, defender: CombatantStats, move: Dictionary, apply_self_effects: bool = true) -> Array:
	var results: Array = []
	for hit_index in range(maxi(1, int(move.get("hits", 1)))):
		if defender.hp <= 0:
			break
		results.append(CombatRules.resolve(attacker, defender, move, apply_self_effects and hit_index == 0))
	return results

# Compatibility alias; Cast is the single identity source.
const DISPLAY_NAMES := Cast.DISPLAY_NAMES

# Per-diver base moves, always available alongside learned spells (_moves_for()).
# Glassgoat V2 moves use a `formula` evaluated by CombatRules; legacy moves use
# `power`/`acc_mod`. A missing `oxygen_cost` means the move is free.
const BASE_MOVES := {
	"Staff_Diver": CombatMoves.SCUBA,
	"Prototype_1(1910)": [
		{"name": "Precise Tap", "power": 1, "acc_mod": 9, "text": "You land a precise tap"},
		{"name": "Weaken", "power": 0, "acc_mod": 2, "debuff": "defense", "amount": 2, "hint": "Lowers defense", "text": "You strike a nerve - its defense drops", "oxygen_cost": 10.0},
		{"name": "Slow", "power": 0, "acc_mod": 2, "debuff": "agility", "amount": 2, "hint": "Lowers agility", "text": "You hobble it - its agility drops", "oxygen_cost": 10.0},
	],
	"Prototype_V(1922)": [
		{"name": "Guard Bash", "power": 4, "acc_mod": 3, "hint": "Sturdy, reliable", "text": "You bash it with your guard"},
		{"name": "Heavy Kick", "power": 8, "acc_mod": 1, "hint": "Balanced, heavier", "text": "You drive a heavy kick home", "oxygen_cost": 8.0},
		{"name": "Crushing Haymaker", "power": 15, "acc_mod": 0, "hint": "Very heavy, slow", "text": "You wind up and crush it", "oxygen_cost": 16.0},
	],
}

# var, not const: filled in by _ready() at runtime.
var stat_effects:= {}

# Stats-panel row label -> stat_effects key. Statuses without a row are skipped.
const STAT_ROW_KEYS := {"STR": "strength", "DEF": "defense", "ACC": "accuracy", "EVA": "evasion"}

# Player panel shows the current actor; enemy panel only while hovering a target.
var _player_stats_ui: Dictionary = {}
var _enemy_stats_ui: Dictionary = {}
# Selected move name + power above the stat panels while target_menu is up.
var _selected_move_panel: PanelContainer
var _selected_move_name: Label
var _selected_move_power: Label
# Small flat power keeps the ordinary claw on the V2 small-number scale; still QTE-eligible.
const ENEMY_MOVE := {"power": 3, "acc_mod": 1, "quick_time_bool": true}

# Gentler ENEMY_MOVE for the choreographed first fight; still QTE-eligible.
const TUTORIAL_ENEMY_MOVE := {"power": 1, "acc_mod": 1, "quick_time_bool": true}

# Goblin evasion pinned for tutorial stages 2 and 4: between Haymaker's and
# Flash Blast's accuracy so Haymaker misses and Flash Blast lands.
const TUTORIAL_HAYMAKER_DODGE_EVASION := 2

# Heavy swing: damage is a fraction of the defender's max HP (see _resolve_attack()).
# Lower acc_mod so it is more missable.
const ENEMY_HEAVY_MOVE := {
	"power": 0, "acc_mod": -1, "quick_time_bool": true,
	"effect": "heavy", "heavy_min": 0.25, "heavy_max": 0.5,
}
const ENEMY_HEAVY_CHANCE := 0.3

# Chance any enemy attack triggers a QTE, rolled independently of the move.
const ENEMY_QTE_CHANCE := 0.25

# Heavy chance used when a heavy swing could finish the target.
const ENEMY_HEAVY_FINISH_CHANCE := 0.65

# Combat feedback palette. One Label3D per category since a label has one color.
const FEEDBACK_DAMAGE_COLOR := Color(1.0, 0.32, 0.27)
const FEEDBACK_EFFECT_COLOR := Color(0.3, 0.72, 1.0)
const FEEDBACK_NEGATIVE_COLOR := Color(0.76, 0.38, 1.0)
# Boss shrugging off a stat-lowering effect.
const FEEDBACK_IMMUNE_COLOR := Color(0.62, 0.2, 1.0)

# Log lines hold LOG_MIN_READ_SECONDS plus 1-3 s for longer lines
# (_log_read_delay()). LOG_READ_DELAY is the upper bound.
const LOG_MIN_READ_SECONDS := 3.0
const LOG_READ_DELAY := 6.0
# Extra seconds the first combat tutorial holds "The enemies back off, beaten."
const TUTORIAL_WIN_EXTRA_HOLD := 6.0

# Fraction of a swing clip at which the hit lands.
const IMPACT_FRACTION := 0.55

# Step-in/back timing and stop distance; SWING_REACH ~ longest swing in the cast.
const SWING_STEP_TIME := 0.18
const SWING_REACH := 1.8

# Overhead health bars.
const OVERHEAD_BAR_WIDTH := 104
const STATUS_COLUMN_WIDTH := 200
# Bar height above the head, in metres.
const OVERHEAD_LIFT := 0.12
# Shared HP/O2 value font size.
const OVERHEAD_VALUE_FONT_SIZE := 12
# Space reserved above each combatant so the camera frames its bar.
const OVERHEAD_HEADROOM := 0.55

var party: Array = []      # [{kind:"party", stats, model_name, display_name, equipped_spells, actor, hp_bar, hp_label}]
var enemies: Array = []    # [{kind:"enemy", stats, display_name, actor, hp_bar, hp_label}]

var _queue: Array = []   # same dict refs as party/enemies, still waiting to act this round
var _acting: Dictionary = {}
var _pending_move: Dictionary = {}
var _busy := false

var log_label: RichTextLabel
var queue_row: HBoxContainer
# HFlowContainer so long move/target lists wrap instead of running off-screen.
var main_menu: HFlowContainer
var move_menu: HFlowContainer
var target_menu: HFlowContainer
var item_menu: HFlowContainer
var attack_btn: Button
var run_btn: Button
# Tutorial-only; Run is disabled in the tutorial, so this is the early exit.
# Ends like "Exit to World" on a loss (World._on_battle_finished "skipped").
var skip_tutorial_btn: Button
var items_btn: Button
var back_btn: Button
var item_back_btn: Button
var target_back_btn: Button
var move_buttons: Array = []
# Move-menu paging: at most MOVE_MENU_SLOTS buttons (two rows of four); longer
# lists page with Up/Down, keeping MOVE_MENU_VISIBLE_MOVES moves plus Up/Down and Back.
const MOVE_MENU_SLOTS := 8
const MOVE_MENU_VISIBLE_MOVES := MOVE_MENU_SLOTS - 2
var _move_scroll_box: VBoxContainer
var _move_up_btn: Button
var _move_down_btn: Button
var _move_scroll_offset := 0
var target_buttons: Array = []
var item_buttons: Array = []

# Item counterpart of _pending_move; at most one is set. Tells _on_target_chosen()
# and target Back whether a move or item is pending.
var _pending_item := ""

# Stage SubViewport, so _turn_cursor lives in the same 3D world as the actors.
var _stage_vp: SubViewport
# Stage ends at the top of the HUD. See _fit_panel_height().
var _stage_container: SubViewportContainer
var _stage_cam: Camera3D
# Fixed 2D status groups: enemies on the right, party on the left. The party
# flow container lets a tall tutorial caption wrap the cards into a row.
var _party_status_column: HFlowContainer
var _enemy_status_column: VBoxContainer
# Turn order bar at the top of the screen.
var _queue_bar: PanelContainer

# Green cone over the acting diver; shown only on party turns.
var _turn_cursor: MeshInstance3D
var _turn_cursor_target: Node3D
var _turn_cursor_height := 0.0

# Resized by _fit_panel_height() whenever menu visibility changes.
var _bottom_panel: PanelContainer

# Dodge prompt: X glyph on the left, moving track on the right. Built once, reused.
var qte_root: HBoxContainer
var qte_track: Control
var qte_zone: ColorRect
var qte_indicator: ColorRect
# Hit zone size is a fraction of the track, so it scales with these.
const QTE_TRACK_WIDTH := 187.5
const QTE_TRACK_HEIGHT := 17.5

# Input only checked while _qte_active. The zone/indicator controls' geometry is the hit-test data.
var _qte_active := false
var _qte_success := false

# Cleared by Enter in _unhandled_input() to release _tutorial_show_step()'s wait loop.
var _tutorial_awaiting_enter := false
var _tutorial_continue_btn: Button
# Set only by an explicit tutorial skip, separate from _busy.
var _skip_tutorial_requested := false

# Subset of a spell def read by _register_stat_effects(), keyed by its move-menu name.
func _spell_preview_move(def: Dictionary, spell_id: String) -> Dictionary:
	var mv := {"name": String(def.get("display", spell_id))}
	for key in ["power", "acc_mod", "debuff", "amount", "effects"]:
		if def.has(key):
			mv[key] = def[key]
	if String(mv.get("debuff", "")) == "":
		mv.erase("debuff")
	return mv

# Per-stat deltas previewed while hovering a target.
func _register_stat_effects(attack: Dictionary) -> void:
	var attack_name: String = attack["name"]

	if not stat_effects.has(attack_name):
		stat_effects[attack_name] = {
			"player": {},
			"enemy": {}
		}

	# Player's stat changes
	if "power" in attack:
		stat_effects[attack_name]["player"]["power"] = attack["power"]

	if "acc_mod" in attack:
		stat_effects[attack_name]["player"]["accuracy"] = attack["acc_mod"]

	# Enemy stat changes
	if "debuff" in attack:
		# Negated: _apply_debuff() subtracts `amount`, so the preview shows a drop.
		stat_effects[attack_name]["enemy"][attack["debuff"]] = -int(attack["amount"])

	# CombatMoves effects
	if "effects" in attack:
		for effect in attack["effects"]:
			var kind: String = effect.get("kind", "")

			match kind:

				"reduce_evasion":
					if "amount" in effect:
						# Negated reduction. A flat amount is exact; an accuracy-scaled one
						# shows its multiplier (the caster isn't known here).
						var amount: Dictionary = effect["amount"]
						var preview := int(amount.get("flat", 0)) + int(amount.get("accuracy", 0))
						if preview != 0:
							stat_effects[attack_name]["enemy"]["evasion"] = -preview

				"status":
					if "status" in effect:
						var status_name: String = String(effect["status"])
						if "level" in effect:
							if "flat" in effect["level"]:
								var lvl: int = int(effect["level"]["flat"])
								stat_effects[attack_name]["enemy"][status_name] = lvl
								# Blindness has no row; preview it on the rows it
								# lowers (ACC and DEF), negated like the others.
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

# Learned-spell bonus for ordinary enemies and Tethys. Cordys and the
# tutorial/prologue Angler are unchanged; Evasion is never scaled.
const UNLOCK_BONUS_SOME := 0.01
const UNLOCK_BONUS_HALF := 0.025
const UNLOCK_BONUS_ALL := 0.05

func _unlock_bonus() -> float:
	var known := 0
	var total := 0
	for d in party_source:
		var diver := d as Diver
		if diver == null:
			continue
		var tree: Dictionary = SpellTree.tree_for(diver.model_name)
		for branch in tree:
			total += (tree[branch] as Dictionary).size()
		known += diver.known_spells.size()
	if total == 0:
		return 0.0
	if known >= total:
		return UNLOCK_BONUS_ALL
	if known * 2 >= total:
		return UNLOCK_BONUS_HALF
	return UNLOCK_BONUS_SOME

func _with_unlock_bonus(s: CombatantStats) -> CombatantStats:
	if tutorial_encounter or prologue_angler_encounter or s == null:
		return s
	var k := 1.0 + _unlock_bonus()
	s.hp_max = int(round(float(s.hp_max) * k))
	s.strength = int(round(float(s.strength) * k))
	s.defense = int(round(float(s.defense) * k))
	s.agility = int(round(float(s.agility) * k))
	s.accuracy = int(round(float(s.accuracy) * k))
	s.fill()
	return s

# Suspend teaching before this fight builds UI; retain queued lesson ownership.
func _enter_tree() -> void:
	add_to_group("battle")
	Whirlpool.set_battle_running(true)
	var popup := get_node_or_null("/root/CharacterAbilityPopup")
	if popup != null and popup.has_method("suspend_for_battle"):
		popup.call("suspend_for_battle")

func _exit_tree() -> void:
	remove_from_group("battle")
	Whirlpool.set_battle_running(not get_tree().get_nodes_in_group("battle").is_empty())
	# Battle-only effects end here.
	for entry in party:
		var stats := entry.stats as CombatantStats
		stats.statuses.clear()
		stats.temporary_modifiers = {"accuracy": 0, "evasion": 0}
		stats.evasion_current = stats.effective_evasion()

func _ready() -> void:
	for diver in BASE_MOVES:
		for attack in BASE_MOVES[diver]:
			_register_stat_effects(attack)
	# Spell-tree moves reach the menu via _moves_for(), so register them too.
	for model_name in SpellTree.SPELL_TREES:
		for branch in SpellTree.SPELL_TREES[model_name]:
			for spell_id in SpellTree.SPELL_TREES[model_name][branch]:
				_register_stat_effects(_spell_preview_move(SpellTree.SPELL_TREES[model_name][branch][spell_id], String(spell_id)))

	layer = 10
	if encounter_source == "maze_puppets":
		ordinary_enemy_ids.assign(PUPPET_WAVES[0])
	_build_party()
	_build_stage()
	_build_ui()
	_build_quick_time_ui()
	_refresh_all_bars()
	_rebuild_queue()
	if encounter_source == "maze_puppets":
		encounter_wave_started.emit(1, PUPPET_WAVES.size())
	if boss_encounter:
		_log("Tethys rises from the deep.")
		if boss_intro_enabled:
			_begin_boss_encounter()
	elif encounter_source == "maze_cordys":
		_begin_campaign_cordys()
	else:
		var intro := encounter_intro_override if not encounter_intro_override.is_empty() else encounter_intro(enemies)
		# Only a real item reward may promise an item; authored intros and
		# tutorials keep their own narration.
		if not reward_item_on_win.is_empty() and encounter_intro_override.is_empty() and not tutorial_encounter:
			intro = ITEM_CARRIER_INTRO
			_intro_hold = intro
		_log(intro)
		if encounter_intro_hold > 0.0:
			_busy = true
			_set_all_buttons(false)
			await get_tree().create_timer(encounter_intro_hold).timeout
			_busy = false
		_advance_turn()

static func encounter_intro(entries: Array) -> String:
	if entries.size() != 1:
		return "Enemies block the way!"
	return "%s blocks the way!" % String((entries[0] as Dictionary).get("display_name", "Enemy"))

# Builds one stats box and returns its Labels: `values` per stat, and
# `deltas` ("+X"/"-Y", hidden until _apply_stat_delta()).
func create_stats_panel(title: String) -> Dictionary:
	var panel := PanelContainer.new()
	# IGNORE: this panel is visible all fight and would otherwise eat clicks
	# meant for minigames' _unhandled_input(). Hover previews use the buttons.
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

	# Compact 2x2 grid so the HUD fits at 1280x720; rows stay individually highlightable.
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

		# Wrapper so _set_row_highlight() draws the border as part of
		# the row's own layout rather than a separately positioned overlay.
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

# Transparent fill; `on` adds a border in `color`.
func _row_stylebox(on: bool, color: Color = Color(1, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	if on:
		style.border_color = color
		style.set_border_width_all(3)
	return style

# `row_panel` is one of create_stats_panel()'s `rows` entries.
func _set_row_highlight(row_panel: PanelContainer, on: bool, color: Color = Color(1, 0, 0)) -> void:
	row_panel.add_theme_stylebox_override("panel", _row_stylebox(on, color))

const STAT_COLOR_UP := Color(0.4, 0.9, 0.4)
const STAT_COLOR_DOWN := Color(0.9, 0.35, 0.35)
const STAT_COLOR_NEUTRAL := Color.WHITE

# Single source for which CombatantStats value backs each displayed row.
func _stat_value(s: CombatantStats, stat: String) -> int:
	match stat:
		"STR": return s.strength
		"DEF": return s.effective_defense()
		"ACC": return s.effective_accuracy()
		"EVA": return s.evasion_current
	return 0

# Move power before defense, for this attacker. Formula moves use
# CombatRules.formula_value(); legacy moves use power + strength without variance.
func _preview_raw_power(mv: Dictionary, attacker: CombatantStats) -> int:
	# heal/revive do no damage math; don't badge the caster's Strength.
	var effect := String(mv.get("effect", ""))
	if effect == "heal" or effect == "revive":
		return 0
	if mv.has("formula"):
		return int(round(CombatRules.formula_value(attacker, mv.get("formula", {}))))
	return int(round(float(mv.get("power", 0)) + float(attacker.strength)))

# Attacker-independent move power shown on the button badge: legacy "power",
# or the formula's "base" term only.
func _move_base_power(mv: Dictionary) -> int:
	var effect := String(mv.get("effect", ""))
	if effect == "heal" or effect == "revive":
		return 0
	if mv.has("formula"):
		return int((mv.get("formula", {}) as Dictionary).get("base", 0))
	return int(mv.get("power", 0))

# Deterministic damage preview: raw power minus Defense, with
# combat_rules.gd's floor rule (0 if Defense exceeds power by more than 5, else >= 1).
func _preview_damage(mv: Dictionary, attacker: CombatantStats, defender: CombatantStats) -> int:
	var raw := _preview_raw_power(mv, attacker)
	if raw <= 0:
		return 0
	var defense := defender.effective_defense()
	if defense - raw > 5:
		return 0
	return maxi(1, raw - defense)

# Base numbers only (nothing hovered); also resets value colors.
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

# Shows the post-move value (green raise / red drop) with the delta, e.g. "4 (-1)".
# Amounts come from stat_effects.
# `floors`: lowest value each stat can be pushed to (stat key -> value). Legacy
# debuffs (Weaken, Slow...) stop at an enemy's floor stat; everything else at 0.
func _apply_stat_delta(ui: Dictionary, s: CombatantStats, deltas: Dictionary, floors: Dictionary = {}) -> void:
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
		# A drop shows only what can really go: down to the floor stat, or 0.
		var floor_value := int(floors.get(key, 0))
		var floor_limited := false
		if amount < 0:
			var room := maxi(0, base - floor_value)
			if -amount > room:
				amount = -room
				floor_limited = floor_value > 0
		value_label.text = str(maxi(0, base + amount))
		value_label.add_theme_color_override("font_color", STAT_COLOR_UP if amount > 0 else STAT_COLOR_DOWN)
		if floor_limited:
			# Stopped by the floor stat: "-1 (Floor Stat)", or "-0 (Floor Stat)" when already there.
			delta_label.text = "-%d (Floor Stat)" % -amount
			delta_label.add_theme_color_override("font_color", STAT_COLOR_NEUTRAL)
		elif amount == 0:
			# Already at 0: the move still targets this stat, but nothing is left to lose.
			delta_label.text = "(-0)"
			delta_label.add_theme_color_override("font_color", STAT_COLOR_NEUTRAL)
		else:
			delta_label.text = "(+%d)" % amount if amount > 0 else "(%d)" % amount
			delta_label.add_theme_color_override("font_color", STAT_COLOR_NEUTRAL)
		delta_label.visible = true

var _miss_label: Label

# Floors a move's stat drop stops at: legacy debuffs use the target's floor stats
# (as _apply_debuff does; Agility never below 1), other effects stop at 0.
func _debuff_floors(move: Dictionary, target: CombatantStats) -> Dictionary:
	if String(move.get("debuff", "")) == "":
		return {}
	var floors := target.stat_floor.duplicate()
	floors["agility"] = int(floors.get("agility", 1))
	return floors

# Damage `move` will deal to `defender` if it lands: after Defense, with the
# same rules as the real hit (a miss is shown by the MISS sign instead). Always one
# number (power moves show their un-rolled total). "" for moves that deal no damage.
func _effective_damage_text(move: Dictionary, defender: CombatantStats) -> String:
	var attacker: CombatantStats = _acting.stats as CombatantStats if _acting.has("stats") else null
	if attacker == null or String(move.get("effect", "")) in ["heal", "revive"] or String(move.get("debuff", "")) != "":
		return ""
	var raw := _preview_raw_power(move, attacker)
	if raw <= 0:
		return ""
	if move.has("formula"):
		return str(_preview_damage(move, attacker, defender))
	# Power moves: one number, the un-rolled total (power + STR - DEF), never below 0.
	return str(maxi(0, raw - defender.effective_defense()))

# The yellow line above the stat panels: move name and its effective damage
# on the hovered enemy (or each enemy, for an all-enemies hover).
func _show_move_damage_line(move: Dictionary, targets: Array) -> void:
	var values: Array[String] = []
	for target in targets:
		if (target as Dictionary).has("stats"):
			var text := _effective_damage_text(move, (target as Dictionary).stats as CombatantStats)
			if text != "" and not values.has(text):
				values.append(text)
	_selected_move_name.text = String(move.get("name", "")) if not values.is_empty() else ""
	_selected_move_power.text = " / ".join(values)
	_selected_move_panel.visible = not values.is_empty()

# True when `move` can't beat `defender`'s current Evasion (ACC <= EVA misses).
func _preview_misses(move: Dictionary, defender: CombatantStats) -> bool:
	if String(move.get("effect", "")) in ["heal", "revive"] or not _acting.has("stats"):
		return false
	var accuracy := (_acting.stats as CombatantStats).effective_accuracy() + int(move.get("acc_mod", 0))
	return accuracy <= defender.evasion_current

# Target-button hover: previews this move's deltas on both panels, or a MISS
# sign instead of the enemy's changes when it would be evaded. The caster's
# own self cost still shows: it's paid even on a miss. Enemy-targeting moves only.
func _show_stat_preview(move: Dictionary, enemy: Dictionary) -> void:
	if not enemy.has("stats"):
		return
	var effects: Dictionary = stat_effects.get(String(move.get("name", "")), {})
	var misses := _preview_misses(move, enemy.stats as CombatantStats)
	_show_move_damage_line(move, [enemy])
	_apply_stat_delta(_player_stats_ui, _acting.stats as CombatantStats, effects.get("player", {}) as Dictionary)
	_set_stats_panel_base(_enemy_stats_ui, enemy.stats as CombatantStats)
	(_enemy_stats_ui.title as Label).text = String(enemy.get("display_name", "Enemy"))
	if not misses:
		_apply_stat_delta(_enemy_stats_ui, enemy.stats as CombatantStats, effects.get("enemy", {}) as Dictionary, _debuff_floors(move, enemy.stats as CombatantStats))
	if _miss_label != null:
		_miss_label.visible = misses
	(_enemy_stats_ui.panel as Control).visible = true

# Cleared on mouse_exited and whenever target_menu is left. While frozen
# (set by _explain_dodging()), the preview stays up during the caption.
var _stat_preview_frozen := false

# Extra enemy panels built per hover by _show_all_stat_preview(); freed on clear.
var _extra_enemy_stats_uis: Array[Dictionary] = []

# "All enemies" hover: enemies[0] uses the shared slot, each additional
# enemy gets a throwaway panel in the same row.
func _show_all_stat_preview(move: Dictionary, enemies: Array) -> void:
	if enemies.is_empty():
		return
	_show_stat_preview(move, enemies[0] as Dictionary)
	_show_move_damage_line(move, enemies)
	var container := (_enemy_stats_ui.panel as Control).get_parent()
	var effects: Dictionary = stat_effects.get(String(move.get("name", "")), {})
	for i in range(1, enemies.size()):
		var enemy := enemies[i] as Dictionary
		if not enemy.has("stats"):
			continue
		var extra_misses := _preview_misses(move, enemy.stats as CombatantStats)
		var extra := create_stats_panel(String(enemy.get("display_name", "Enemy")) + ("  MISS" if extra_misses else ""))
		_set_stats_panel_base(extra, enemy.stats as CombatantStats)
		if not extra_misses:
			_apply_stat_delta(extra, enemy.stats as CombatantStats, effects.get("enemy", {}) as Dictionary, _debuff_floors(move, enemy.stats as CombatantStats))
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
	if _miss_label != null:
		_miss_label.visible = false
	_selected_move_panel.visible = false
	# Full reset: _apply_stat_delta() overwrote the value text.
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

func _begin_campaign_cordys() -> void:
	_busy = true
	_set_all_buttons(false)
	_log("Cordys. This time, you can fight back.")
	var actor := enemies[0].actor as CampaignCordys
	var length := actor.play("reveal")
	# Hold for the normal combat-text read time (3 s+), even if the clip is shorter.
	await get_tree().create_timer(maxf(_log_read_delay(), length)).timeout
	actor.play("idle")
	_advance_turn()

# Replaces only the fallen enemy and its card; stage, party and UI stay.
func reveal_prologue_octopus() -> void:
	if prologue_octopus_encounter:
		return
	_busy = true
	_audio_call(&"fade_music_out", [0.15])
	# Short hold before the reveal; the film already built anticipation.
	await get_tree().create_timer(0.25).timeout
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
		# Compact grounded formation so the large threat stays readable (prologue only).
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
	# Opening-only numbers: the low-level kit can hurt Cordys but not defeat him.
	stats.strength = 80
	stats.accuracy = 30
	stats.agility = 20
	stats.evasion = 0
	stats.defense = 0
	stats.immune_to_stat_loss = true   # bosses shrug off stat-lowering effects
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
	var entry := _acting
	# Let the result stay readable before the response.
	await get_tree().create_timer(_log_read_delay()).timeout
	prologue_phase_changed.emit("scripted_defeat")
	var cordys := enemies[0].actor as PrologueOctopus
	var attacker := enemies[0].stats as CombatantStats
	attacker.begin_turn()
	_acting = enemies[0]
	_queue.clear()
	_refresh_queue_row()
	_turn_cursor.visible = false # This cursor is Diver-only; NOW identifies Cordys.
	# One target per boss turn; every remaining diver acts before the next response.
	var strikes := [
		{"name": "Octo Stab", "clip": "octo_stab", "formula": {"strength": 1}},
		{"name": "Head Bash", "clip": "head_bash", "formula": {"strength": 1}},
		{"name": "Electric Shooting", "clip": "electric_shooting", "formula": {"strength": 1}},
	]
	var move: Dictionary = strikes[_prologue_strike_index % strikes.size()]
	_prologue_strike_index += 1
	var target_name := String(entry.display_name)
	cordys.face_toward((entry.actor as Node3D).global_position)
	cordys.set_framing_clip(String(move.clip))
	_frame_stage_camera()
	_log("Cordys uses %s on %s." % [move.name, target_name])
	# A decisive, readable response, not a long idle tail after each choice.
	var length := cordys.play(String(move.clip), 2.2)
	_audio_call(&"play_combat_swing", [true])
	await get_tree().create_timer(maxf(0.35, length * IMPACT_FRACTION)).timeout
	var result := CombatRules.resolve(attacker, entry.stats as CombatantStats, move)
	_audio_call(&"duck_music", [-9.0, 0.4])
	_show_combat_feedback(entry, result)
	_react(entry, result)
	if (entry.stats as CombatantStats).hp <= 0:
		(entry.actor as Diver).play_death_fade()
	_refresh_all_bars()
	var summary := "-%d" % int(result.damage) if result.hit else "evades"
	_log("%s: %s %s.%s" % [move.name, target_name, summary, " %s falls." % target_name if (entry.stats as CombatantStats).hp <= 0 else ""])
	print("PROLOGUE_STRIKE|move=%s|target=%s|damage=%d|hit=%s|hp=%d|living=%d" % [move.name, target_name, result.damage, str(result.hit), (entry.stats as CombatantStats).hp, _living(party).size()])
	prologue_strike_resolved.emit(String(move.name), target_name, result.duplicate(true))
	await get_tree().create_timer(maxf(_log_read_delay(), length * (1.0 - IMPACT_FRACTION))).timeout
	cordys.play("idle")
	_finish_actor_turn(enemies[0])
	_refresh_all_bars()
	await get_tree().create_timer(0.15).timeout
	if not _living(party).is_empty():
		# High-stat survivors stay alive; another normal choice is legal.
		_prologue_response_resolved = false
		cordys.call("play", "idle")
		cordys.set_framing_clip("")
		_frame_stage_camera()
		for offset in range(1, party.size() + 1):
			var next: Dictionary = party[(party.find(entry) + offset) % party.size()]
			if (next.stats as CombatantStats).hp > 0:
				_acting = next
				break
		_queue.append(enemies[0])
		_refresh_queue_row()
		_start_party_turn(_acting)
		return
	_audio_call(&"stop_music")
	finished.emit("prologue_defeat")

# Combatant top/bottom in world space; models disagree on origin height, so ask them.
func _top_of(a: Node3D) -> Vector3:
	return a.global_position + Vector3(0.0, float(a.call("head_offset")), 0.0)

func _bottom_of(a: Node3D) -> Vector3:
	return a.global_position + Vector3(0.0, float(a.call("foot_offset")), 0.0)

func get_battlefield_texture() -> Texture2D:
	# Read-only presentation for an interstitial; exclude stale combat controls.
	return _stage_vp.get_texture() if is_instance_valid(_stage_vp) else null

# Stage-viewport projection scaled/offset into CanvasLayer pixels; falls back
# to the stage centre when there's no camera or the point is behind it.
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

# Stage SubViewport with its own World3D, camera, light and fog. Actors here
# are display-only; real stats live in party[]/enemies[].
func _build_stage() -> void:
	# Opaque backing so the paused World never shows through.
	var backing := ColorRect.new()
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.color = Color(0.05, 0.13, 0.17)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	# Full width, top of screen down to the HUD. _fit_panel_height() keeps the
	# bottom edge on the panel and the resized signal reframes the camera.
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	# IGNORE so mouse events reach _unhandled_input() (minigames' mouse look/fire).
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
	# Camera is positioned by _frame_stage_camera() once actors exist.
	if boss_encounter:
		_build_boss_lab_stage(vp)

	# Party spread left-to-right; rest rotation already faces away from camera.
	var is_swap_encounter := special_encounter and not party.is_empty() and String(party[0].get("ability_id", "")) == "swap"
	# Tethys fight: keep the party inside the Broken Office and compact.
	var diver_z := -0.5 if boss_encounter else (3.4 if is_swap_encounter else (2.2 if special_encounter else 1.0))
	# Swap encounters sit deeper so incoming portraits have more distance to cross.
	var enemy_z := -9.0 if is_swap_encounter else (-4.6 if special_encounter else -2.2)
	var pn := party.size()
	for i in range(pn):
		# Every party member gets an actor; knocked-out ones start hidden.
		var actor := Diver.new()
		actor.model_name = String(party[i].model_name)
		vp.add_child(actor)
		# Ground the formation only in Tethys's lab, which has a visible floor at y=0.
		var floor_y := -actor.foot_offset() if boss_encounter else 0.0
		var party_spread := 1.3 if boss_encounter else 2.9
		var party_depth_spread := 0.3 if boss_encounter else 0.7
		var party_x_offset := -1.0 if boss_encounter else -0.4
		if encounter_source == "maze_puppets" or encounter_source == "maze_cordys":
			party_spread = 2.1
			party_depth_spread = 0.3
			party_x_offset = -2.6
		if encounter_source == "maze_cordys":
			# Keep Maxilani's silhouette to the right of the stacked status cards.
			party_spread = 1.6
			party_x_offset = -1.4
		actor.position = Vector3(_spread(i, pn, party_spread) + party_x_offset, floor_y, diver_z - _spread(i, pn, party_depth_spread))
		party[i]["actor"] = actor
		if (party[i].stats as CombatantStats).hp <= 0:
			actor.visible = false
		# Rest position; attacks step in and return here.
		party[i]["home_pos"] = actor.position
		party[i]["home_rot"] = actor.rotation.y

	_build_turn_cursor()

	# Enemies: random count, stats rolled near the party's current average.
	var lvl := int((party[0].stats as CombatantStats).level) if not party.is_empty() else 1
	var ref_stats := _party_average_stats()
	if encounter_source == "maze_cordys":
		var cordys := CampaignCordys.new()
		cordys.position = Vector3(4.5, 0.0, -1.0)
		vp.add_child(cordys)
		var centre := Vector3.ZERO
		for entry in party:
			centre += (entry.actor as Node3D).position
		centre /= float(maxi(1, party.size()))
		cordys.face_toward(centre)
		for entry in party:
			(entry.actor as Diver).look_at(cordys.position, Vector3.UP)
			entry.home_rot = (entry.actor as Diver).rotation.y
		enemies.append({"kind": "enemy", "stats": cordys.make_stats(),
			"display_name": "Cordys", "actor": cordys,
			"home_pos": cordys.position, "home_rot": cordys.rotation.y,
			"xp_reward": CampaignCordys.XP_REWARD, "boss": true})
		_frame_stage_camera()
		return
	# Solo/tutorial fights: halve the grunt's hp_max/defense since only one
	# diver is attacking. Offense is untouched. Not for bosses.
	if (special_encounter or tutorial_encounter) and not boss_encounter:
		ref_stats.hp_max = maxi(1, int(round(float(ref_stats.hp_max) * 0.5)))
		ref_stats.defense = int(round(float(ref_stats.defense) * 0.5))
	# Special and tutorial encounters are always one diver vs one grunt.
	var use_revealed_roster := not ordinary_enemy_ids.is_empty() and not (boss_encounter or special_encounter or tutorial_encounter or prologue_angler_encounter or guardian_encounter)
	var count := 1
	if use_revealed_roster:
		count = ordinary_enemy_ids.size()
	elif not (boss_encounter or special_encounter or tutorial_encounter or prologue_angler_encounter):
		count = ordinary_enemy_count_for_roll(lvl, randf(), guardian_encounter)
	if boss_encounter:
		var boss := TethysBoss.new()
		if encounter_source == "lab_boss":
			boss.model_scene = preload("res://characters/Freak_Mermaid-Weirdo.fbx")
		# Boss near the party's depth plane and opposite side so it reads full size and unobscured.
		boss.position = Vector3(2.1, 0.0, -2.5)
		vp.add_child(boss)
		# Mermaid_Freak faces local +Z; point it at the party centre.
		# Divers with hp<=0 have no actor and are skipped.
		var party_centre := Vector3.ZERO
		var party_actor_count := 0
		for party_entry in party:
			if not party_entry.has("actor"):
				continue
			party_centre += (party_entry.actor as Node3D).global_position
			party_actor_count += 1
		party_centre /= maxf(1.0, float(party_actor_count))
		boss.face_toward(party_centre)
		var boss_stats := _with_unlock_bonus(boss.make_stats(ref_stats, lvl))
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
	_build_ordinary_enemy_wave(vp, enemy_z, lvl, ref_stats, use_revealed_roster, count)

func _build_ordinary_enemy_wave(vp: SubViewport, enemy_z: float, lvl: int, ref_stats: CombatantStats, use_revealed_roster: bool, count: int) -> void:
	for i in range(count):
		# Tutorials always use the Angler the captions describe.
		var g: Goblin
		if use_revealed_roster:
			g = actor_for_enemy_id(ordinary_enemy_ids[i])
		else:
			g = actor_for_enemy_id("angler") if tutorial_encounter or prologue_angler_encounter else (_guardian_actor() if guardian_encounter else _ordinary_actor())
		# Special encounters use a deeper lane. Lab blockers get a distinct lane so
		# they don't interleave with the party row.
		var enemy_x := _spread(i, count, 2.3) + 0.6
		# A solo Frilled Shark is long; move it to the opposing side.
		if g is FrilledShark and count == 1:
			enemy_x = 5.0
		if encounter_source == "lab_blocker":
			# Sword Slayer's long bill needs extra separation.
			enemy_x = 6.2 if guardian_enemy_id == "sword_slayer" else 4.2
		if encounter_source == "maze_puppets":
			# Mixed long silhouettes get their own opposing row.
			enemy_x = 2.6 + float(i) * 3.6 if count == 3 else 3.5 + float(i) * 4.2
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
		var st: CombatantStats = _with_unlock_bonus(g.make_stats(ref_stats, lvl))
		if prologue_angler_encounter:
			# Shorter fight only; keep the species' other stats.
			st.hp_max = 3
			st.fill()
		if encounter_source == "maze_puppets" and _puppet_wave == 0:
			# First wave only: every puppet has the same fixed HP; other stats stay per species.
			st.hp_max = PUPPET_HP
			st.hp = PUPPET_HP
		if tutorial_encounter:
			# Tutorials fight a fixed Angler: TUTORIAL_ENEMY_HP and unboosted floor stats.
			st.hp_max = TUTORIAL_ENEMY_HP
			for field in ["strength", "defense", "agility", "evasion", "accuracy"]:
				st.set(field, int(st.stat_floor.get(field, st.get(field))))
			# Beginner tutorial: stats chosen so every lesson caption is true.
			#  - EVA = Maxilani's Accuracy - 1: her first Electric Touch lands.
			#  - DEF 3 with a debuff floor of 0: Weaken's "-2" lands in full (3 -> 1)
			#    and Flash Blast's Blindness still visibly lowers DEF afterwards.
			#  - AGI 2 < Maxilani's 3: she goes first, as the turn-order lesson says.
			if not special_encounter and not party.is_empty():
				st.evasion = maxi(0, (party[0].stats as CombatantStats).effective_accuracy() - 1)
				st.defense = TUTORIAL_ENEMY_DEFENSE
				st.stat_floor = {"strength": 0, "defense": 0, "agility": 0, "evasion": 0, "accuracy": 0}
			st.fill()
			if special_encounter:
				# Below Maxilani's agility so she goes first, as the caption says.
				st.agility = maxi(1, ref_stats.agility - 1)
		enemies.append({
			"kind": "enemy", "stats": st,
			"display_name": g.display_name() if count == 1 or encounter_source == "maze_puppets" else "%s %d" % [g.display_name(), i + 1],
			"actor": g,
			"home_pos": g.position,
			"home_rot": g.rotation.y,
			"xp_reward": g.xp_reward,
		})

	# Tutorials: no knockouts during the guided part.
	if tutorial_encounter:
		_set_tutorial_guard(true)
	_apply_dev_statuses()
	_frame_stage_camera()

# Set by whoever starts the fight (World or the maze) when --dev is on.
var dev_mode := false

# Dev mode (--dev): every status on every combatant in ordinary fights (never
# bosses or scripted fights). Level 1, 9 turns (Stun: 1).
const DEV_STATUSES := [["blindness", 1, 9], ["stun", 1, 1], ["evasion_down", 1, 9],
	["defense_down", 1, 9], ["bleed", 1, 0], ["poison", 1, 9]]

func _apply_dev_statuses() -> void:
	if not dev_mode and (world == null or not bool(world.get("dev_mode"))):
		return
	if boss_encounter or encounter_source in ["maze_cordys", "maze_puppets", "lab_boss", "prologue_octopus"] \
		or tutorial_encounter or special_encounter or guardian_encounter \
		or prologue_angler_encounter or prologue_octopus_encounter:
		return
	for entry in party + enemies:
		var s := (entry as Dictionary).get("stats") as CombatantStats
		if s == null or s.hp <= 0:
			continue
		for st in DEV_STATUSES:
			s.add_status(String(st[0]), int(st[1]), int(st[2]))
		_refresh_bar(entry)

const TUTORIAL_ENEMY_HP := 10
const TUTORIAL_ENEMY_DEFENSE := 3

func _start_next_puppet_wave() -> void:
	_busy = true
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	_selected_move_panel.visible = false
	(_player_stats_ui.panel as Control).visible = false
	_clear_all_stat_preview()
	# Living players who haven't acted stay queued; new enemies join them.
	var pending_party := _queue.filter(func(entry: Dictionary) -> bool:
		return String(entry.kind) == "party" and (entry.stats as CombatantStats).hp > 0)
	_queue.clear()
	_acting = {}
	_turn_cursor.visible = false
	for old_enemy in enemies:
		_puppet_completed_xp += int(old_enemy.get("xp_reward", 0))
		for field in ["actor", "card"]:
			var old_value: Variant = old_enemy.get(field)
			if is_instance_valid(old_value):
				(old_value as Node).queue_free()
	enemies.clear()
	for button in target_buttons:
		if is_instance_valid(button):
			(button as Node).queue_free()
	target_buttons.clear()
	_puppet_wave += 1
	ordinary_enemy_ids.assign(PUPPET_WAVES[_puppet_wave])
	var lvl := int((party[0].stats as CombatantStats).level) if not party.is_empty() else 1
	_build_ordinary_enemy_wave(_stage_vp, -2.2, lvl, _party_average_stats(), true, ordinary_enemy_ids.size())
	for enemy in enemies:
		_build_overhead_bar(enemy)
	_refresh_all_bars()
	_queue = pending_party + _living(enemies)
	_queue.sort_custom(_by_agility)
	_refresh_queue_row()
	_log("Their hold breaks. More of Cordys's puppets approach.")
	encounter_wave_started.emit(_puppet_wave + 1, PUPPET_WAVES.size())
	# One brief arrival hold.
	await get_tree().create_timer(0.9).timeout
	_advance_turn()

func _build_boss_lab_stage(viewport: SubViewport) -> void:
	# The boss battle has its own 3D world, so instantiate the lab room here.
	var wrapper := Node3D.new()
	wrapper.name = "BrokenOfficeBattleStage"
	wrapper.add_to_group("boss_lab_stage")
	viewport.add_child(wrapper)
	var office := BOSS_LAB_SCENE.instantiate() as Node3D
	wrapper.add_child(office)
	_style_boss_lab_materials(office)
	# Scale large enough to enclose both rows, camera outside the open front.
	wrapper.scale = Vector3.ONE * 0.47
	wrapper.rotation_degrees.y = 180.0
	wrapper.force_update_transform()
	# Align the wall/floor shell, not the distant decorative lantern.
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

# Color-grade the bright imported textures into a damaged underwater lab.
func _style_boss_lab_materials(office: Node3D) -> void:
	for mesh_value in _battle_set_meshes(office):
		var mesh := mesh_value as MeshInstance3D
		if mesh.name == "Staff_Lantern":
			# Source outlier far outside the room.
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

# Room shell bounds, ignoring the far-off decorative lantern; aggregate fallback.
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
	return actor_for_enemy_id(guardian_enemy_id)

func _ordinary_actor() -> Goblin:
	return actor_for_enemy_id(EnemyRoster.random_id())

static func actor_for_enemy_id(enemy_id: String) -> Goblin:
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

# Three-quarter view so the 2D-authored attacks read; the only taste constant.
# Camera distance is computed to fit the stage into the space above the HUD.
const STAGE_CAMERA_DIR := Vector3(3.0, 2.2, 5.5)
# Margin around the group, and a minimum distance.
const STAGE_FRAMING_MARGIN := 1.08
const STAGE_MIN_DISTANCE := 3.5

func _frame_stage_camera() -> void:
	if _stage_cam == null or _stage_container == null:
		return

	# Head and feet corners plus a sideways allowance for swings.
	var pts: Array = []
	for e in (party + enemies):
		if not e.has("actor") or not is_instance_valid(e.actor):
			continue
		var a := e.actor as Node3D
		if a.has_method("framing_points"):
			# Actual skinned silhouette, not rotated world-AABB corners.
			var measured: Array = a.call("framing_points")
			if not measured.is_empty():
				pts.append_array(measured)
				continue
		# Frame real visual bounds when available; imported enemies can be much
		# longer than their collision radius (e.g. Frilled Shark).
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
		# Include the health bar above the head, not just the model.
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
	if prologue_octopus_encounter or encounter_source == "maze_cordys":
		# Use an enclosing box so dense mesh point clouds don't bias the camera.
		var enclosing := AABB(pts[0] as Vector3, Vector3.ZERO)
		for point in pts:
			enclosing = enclosing.expand(point as Vector3)
		centre = enclosing.get_center()

	# More frontal view for enclosed boss/prologue arenas.
	var dir: Vector3 = (Vector3(0.4, 1.8, 6.0) if boss_encounter or prologue_octopus_encounter or encounter_source in ["maze_puppets", "maze_cordys"] else STAGE_CAMERA_DIR).normalized()
	# Measure the group in the camera's view plane.
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(dir).normalized()
	if prologue_octopus_encounter or encounter_source == "maze_cordys":
		# Orthographic stage keeps deep tentacle actions in frame without camera pumping.
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

	# fov is vertical (KEEP_HEIGHT), so the limiting dimension depends on aspect.
	var box: Vector2 = _stage_container.size
	var aspect: float = maxf(0.2, box.x / maxf(1.0, box.y))
	var tan_v: float = maxf(0.01, tan(deg_to_rad(_stage_cam.fov) * 0.5))
	var tan_h: float = maxf(0.01, tan_v * aspect)

	# Solved per point because the party stands nearer the camera than the grunts.
	# For camera at centre + dir*d, point p (w toward camera) fits at depth d - w;
	# the group needs the largest such d.
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

# Green cone in the stage world marking the acting diver; shown on party turns only.
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

# Blinking red cones over the enemy (or enemies) a hovered target button would hit.
var _target_cursors: Array = []   # [cone MeshInstance3D, enemy actor Node3D]
const TARGET_CURSOR_COLOR := Color(1.0, 0.2, 0.2)

func _show_target_cursors(targets: Array) -> void:
	_hide_target_cursors()
	for target_value in targets:
		var target := target_value as Dictionary
		if not target.has("actor") or not is_instance_valid(target.actor):
			continue
		if (target.stats as CombatantStats).hp <= 0:
			continue
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.2
		cone.height = 0.35
		var cursor := MeshInstance3D.new()
		cursor.mesh = cone
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.albedo_color = TARGET_CURSOR_COLOR
		mat.emission = TARGET_CURSOR_COLOR
		cursor.material_override = mat
		cursor.rotation_degrees.x = 180.0
		_stage_vp.add_child(cursor)
		var blink := cursor.create_tween().set_loops()
		blink.tween_callback(func() -> void: cursor.visible = not cursor.visible).set_delay(0.25)
		_target_cursors.append([cursor, target.actor])
	_update_target_cursors()

func _hide_target_cursors() -> void:
	for pair in _target_cursors:
		if is_instance_valid(pair[0]):
			(pair[0] as Node).queue_free()
	_target_cursors.clear()

func _update_target_cursors() -> void:
	# Whatever closed the target menu, the markers go with it.
	if not _target_cursors.is_empty() and not target_menu.is_visible_in_tree():
		_hide_target_cursors()
		return
	for pair in _target_cursors:
		if is_instance_valid(pair[0]) and is_instance_valid(pair[1]):
			(pair[0] as Node3D).global_position = _top_of(pair[1] as Node3D) + Vector3.UP * 0.45

# Fresh averaged CombatantStats of living divers (or all, if none alive) for
# Goblin.make_stats(); never aliases a real diver's stats.
func _party_average_stats() -> CombatantStats:
	var living := _living(party)
	var pool: Array = living if not living.is_empty() else party
	var avg := CombatantStats.new()
	if pool.is_empty():
		return avg
	# Sum into ints first: CombatantStats.new() has non-zero defaults.
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

# Evenly spaces `n` actors around x=0, `step` apart.
func _spread(i: int, n: int, step: float) -> float:
	return (float(i) - float(n - 1) * 0.5) * step

func _build_ui() -> void:
	# Status cards: party down the left, enemies down the right. Added first so
	# the bottom panel and queue bar win in z-order.
	_party_status_column = HFlowContainer.new()
	_party_status_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_party_status_column.offset_left = 12.0
	_party_status_column.offset_top = 70.0
	_party_status_column.offset_right = 12.0 + STATUS_COLUMN_WIDTH
	_party_status_column.offset_bottom = 70.0 + 320.0
	_party_status_column.add_theme_constant_override("h_separation", 8)
	_party_status_column.add_theme_constant_override("v_separation", 8)
	_party_status_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_status_column.sort_children.connect(func() -> void: call_deferred("_fit_panel_height"))
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
	# IGNORE so the empty background doesn't eat minigame mouse input; child buttons keep STOP.
	_bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Opaque so the paused overworld never shows through; color matches the stage.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.13, 0.17)
	bg.border_width_top = 2
	bg.border_color = Color(0.18, 0.34, 0.4)
	_bottom_panel.add_theme_stylebox_override("panel", bg)

	add_child(_bottom_panel)
	# Refit when the flow's minimum size actually changes (after deferred sorting).
	_bottom_panel.minimum_size_changed.connect(func() -> void: call_deferred("_fit_panel_height"))

	var margin := MarginContainer.new()
	var compact_battle_ui := get_viewport().get_visible_rect().size.y <= 500.0
	margin.add_theme_constant_override("margin_left", 12 if compact_battle_ui else 16)
	margin.add_theme_constant_override("margin_right", 12 if compact_battle_ui else 16)
	margin.add_theme_constant_override("margin_top", 2 if compact_battle_ui else 10)
	margin.add_theme_constant_override("margin_bottom", 4 if compact_battle_ui else 16)
	# IGNORE is per-node; margin and col need it too. Menu buttons inside stay STOP.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_panel.add_child(margin)

	# col shares the row with _swap_demo_frame (hidden outside the first special encounter).
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

	# Demo clip of the swap minigame for the first special encounter, loaded
	# from TutorialContent.SPECIAL_ENCOUNTER_MEDIA["swap"]. Pinned to the top of the row.
	_swap_demo_frame = PanelContainer.new()
	_swap_demo_frame.visible = false
	_swap_demo_frame.custom_minimum_size = TutorialContent.VIDEO_FRAME_SIZE
	# Fixed size; expanding would stretch the 16:9 video frame.
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

	# Turn order bar across the top of the screen.
	_queue_bar = PanelContainer.new()
	_queue_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Refit so a shorter turn strip still meets the stage.
	_queue_bar.resized.connect(func() -> void: call_deferred("_fit_panel_height"))
	# Non-interactive strip; IGNORE so it doesn't eat mouse input.
	_queue_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qbg := StyleBoxFlat.new()
	# Opaque so the paused overworld doesn't show through.
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

	# Status cards: see _build_overhead_bar() and _layout_overhead_bars().
	for entry in party:
		_build_overhead_bar(entry)
	for entry in enemies:
		_build_overhead_bar(entry)

	log_label = RichTextLabel.new()
	# Single-line height in compact layouts keeps the stage actors large.
	log_label.custom_minimum_size = Vector2(0, 28 if compact_battle_ui else 56)
	log_label.fit_content = true
	log_label.finished.connect(_fit_panel_height)
	log_label.minimum_size_changed.connect(func() -> void: call_deferred("_fit_panel_height"))
	log_label.scroll_active = false
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Reading order: narration/level-up first, the current turn log below.

	# Wrapping caption above the log for tutorial narration and the QTE warning.
	# Starts hidden: an empty RichTextLabel still claims a line of height.
	# RichTextLabel for BBCode highlights.
	_tutorial_caption = RichTextLabel.new()
	_tutorial_caption.visible = false
	_tutorial_caption.bbcode_enabled = true
	_tutorial_caption.fit_content = true
	# Refit once layout finishes; fit_content's height is known only after layout.
	_tutorial_caption.finished.connect(_fit_panel_height)
	_tutorial_caption.scroll_active = false
	_tutorial_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# White base so [color=yellow] emphasis stands out.
	_tutorial_caption.add_theme_color_override("default_color", Color.WHITE)
	_tutorial_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Enables [pulse] BBCode (pulse_text_effect.gd).
	_tutorial_caption.install_effect(PulseTextEffect.new())
	col.add_child(_tutorial_caption)

	# Mouse alternative to Enter; both clear the same wait flag.
	_tutorial_continue_btn = Button.new()
	_tutorial_continue_btn.name = "TutorialContinue"
	_tutorial_continue_btn.text = "Continue"
	_tutorial_continue_btn.custom_minimum_size = Vector2(180, 40)
	_tutorial_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tutorial_continue_btn.visible = false
	_tutorial_continue_btn.pressed.connect(_continue_tutorial_caption)
	col.add_child(_tutorial_continue_btn)

	# Level-up table, any win. RichTextLabel for colored "(+N)"; starts hidden
	# so it claims no height.
	_levelup_caption = RichTextLabel.new()
	_levelup_caption.visible = false
	_levelup_caption.bbcode_enabled = true
	_levelup_caption.fit_content = true
	_levelup_caption.finished.connect(_fit_panel_height)
	_levelup_caption.scroll_active = false
	_levelup_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_levelup_caption.add_theme_color_override("default_color", Color.WHITE)
	_levelup_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup_caption.install_effect(PulseTextEffect.new())
	col.add_child(_levelup_caption)
	col.add_child(log_label)

	main_menu = HFlowContainer.new()
	main_menu.add_theme_constant_override("h_separation", 12)
	main_menu.add_theme_constant_override("v_separation", 8)
	col.add_child(main_menu)
	attack_btn = _menu_button("Attack", "Pick a move")
	attack_btn.pressed.connect(_show_moves)
	main_menu.add_child(attack_btn)
	run_btn = _menu_button("Run", "" if _no_escape() else "Might not escape")
	run_btn.tooltip_text = "You can't run from a boss." if _no_escape() else ""
	run_btn.pressed.connect(_on_run)
	main_menu.add_child(run_btn)
	items_btn = _menu_button("Items", "")
	items_btn.pressed.connect(_show_items)
	main_menu.add_child(items_btn)

	# Reparented as the last button of whichever menu is visible
	# (_place_skip_tutorial_btn_last()). No hint: it wouldn't fit.
	if tutorial_encounter:
		skip_tutorial_btn = _menu_button("Skip Tutorial", "")
		# No focus, so Enter (caption continue) can't trigger a skip.
		skip_tutorial_btn.focus_mode = Control.FOCUS_NONE
		skip_tutorial_btn.pressed.connect(_on_skip_tutorial_pressed)
		_place_skip_tutorial_btn_last(main_menu)
		# Flashes all tutorial; separate from _tutorial_flash_tween.
		_skip_tutorial_flash_tween = create_tween()
		_skip_tutorial_flash_tween.set_loops()
		_skip_tutorial_flash_tween.tween_property(skip_tutorial_btn, "modulate", Color(1.0, 0.45, 0.35), 0.5)
		_skip_tutorial_flash_tween.tween_property(skip_tutorial_btn, "modulate", Color.WHITE, 0.5)

	_selected_move_panel = PanelContainer.new()
	# IGNORE: visible for the rest of the fight, including minigames.
	_selected_move_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_move_panel.add_theme_stylebox_override("panel", _row_stylebox(false))
	col.add_child(_selected_move_panel)
	var selected_move_row := HBoxContainer.new()
	# Small fixed gap keeps the power right next to the name.
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
	# Shown instead of the enemy's stat changes when the hovered move would miss.
	_miss_label = Label.new()
	_miss_label.text = "MISS"
	_miss_label.custom_minimum_size = Vector2(84, 0)
	_miss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_miss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_miss_label.add_theme_font_size_override("font_size", 24)
	_miss_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
	_miss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_miss_label.add_theme_constant_override("outline_size", 6)
	_miss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_miss_label.visible = false
	stats_row.add_child(_miss_label)
	_enemy_stats_ui = create_stats_panel("Enemy")
	(_enemy_stats_ui.panel as Control).visible = false
	stats_row.add_child(_enemy_stats_ui.panel as Control)
	# The MISS sign belongs to the enemy panel: hide it whenever that hides.
	(_enemy_stats_ui.panel as Control).visibility_changed.connect(func() -> void:
		if not (_enemy_stats_ui.panel as Control).visible:
			_miss_label.visible = false)
	# Fill real numbers now; _start_party_turn() may be several frames away.
	if not party.is_empty():
		_set_stats_panel_base(_player_stats_ui, party[0].stats as CombatantStats)


	move_menu = HFlowContainer.new()
	move_menu.add_theme_constant_override("h_separation", 12)
	move_menu.add_theme_constant_override("v_separation", 8)
	move_menu.visible = false
	col.add_child(move_menu)
	# Up/Down stacked in one slot; hidden unless moves overflow.
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
	# Back returns to move_menu or item_menu depending on what is pending.
	target_back_btn.pressed.connect(_show_moves_or_items_from_target_menu)
	target_menu.add_child(target_back_btn)

	call_deferred("_fit_panel_height")

# Sizes _bottom_panel to its visible content (hidden children don't count).
# Always call deferred: minimum size is stale until containers re-sort.
func _fit_panel_height() -> void:
	# Re-apply status-band widths on resize. Compact cards use "t" for turns
	# (full wording in the tooltip).
	for entry in party + enemies:
		if entry.has("hp_bar"):
			var width := 72.0 if _uses_narrow_info_band() else float(OVERHEAD_BAR_WIDTH)
			(entry.hp_bar as ProgressBar).custom_minimum_size.x = width
			if entry.has("oxygen_bar"):
				(entry.oxygen_bar as ProgressBar).custom_minimum_size.x = width
			_refresh_bar(entry)
	_bottom_panel.offset_bottom = 0.0
	_bottom_panel.offset_top = -(_bottom_panel.get_combined_minimum_size().y + 12.0)
	_fit_party_status_cards_above_panel()
	# Stage ends at the panel's top so a taller HUD shrinks the fight instead of covering it.
	if _stage_container != null:
		_stage_container.offset_bottom = _bottom_panel.offset_top
		# And starts below the turn bar.
		_stage_container.offset_top = _queue_bar.size.y if _queue_bar != null else 0.0
		if _uses_narrow_info_band() and _busy:
			# Keep spell effects below the compact party row.
			for entry in party:
				var card := entry.card as Control
				if card.is_visible_in_tree():
					_stage_container.offset_top = maxf(_stage_container.offset_top, card.get_global_rect().end.y + 8.0)

func _uses_narrow_info_band() -> bool:
	return get_viewport().get_visible_rect().size.y <= 500.0 and not (tutorial_encounter or special_encounter or prologue_angler_encounter or prologue_octopus_encounter or boss_encounter)

# Widen the party flow into rows when a tall bottom panel would cover the
# stacked cards; stops before the enemy column. Uses minimum sizes because
# HFlow sorting is deferred.
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
	_party_status_column.offset_right = expanded_right if _uses_narrow_info_band() or _party_status_column.offset_top + vertical_height > panel_top else normal_right

# Name plus a one-line tradeoff hint on the button.
# `hint_bbcode` (optional) draws the hint line in colour instead of `hint`.
func _menu_button(title: String, hint: String, hint_bbcode := "") -> Button:
	# TooltipButton everywhere (Godot shows no tooltip when tooltip_text is empty).
	var b := TooltipButton.new()
	b.text = title if hint == "" else "%s\n%s" % [title, hint]
	# 300px buttons on wide screens; 205px on narrow so three actions fit one row at 720px.
	var viewport_width := get_viewport().get_visible_rect().size.x
	b.custom_minimum_size = Vector2(205 if viewport_width < 900.0 else 300, 52)
	b.clip_text = true
	if hint_bbcode != "" or CombatRules.has_stat_loss(hint):
		# Hint line drawn by a rich-text overlay (button text is single-colour).
		b.text = "%s
 " % title
		var line := RichTextLabel.new()
		line.name = "HintLine"
		line.bbcode_enabled = true
		line.scroll_active = false
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
		line.offset_left = 4.0
		line.offset_right = -4.0
		line.text = "[center]%s[/center]" % (hint_bbcode if hint_bbcode != "" else CombatRules.red_stat_losses_bbcode(hint))
		# Match the button's own font, size and colour, and sit exactly on its
		# second text line (two centred lines: line 2 starts line_spacing/2 below centre).
		line.ready.connect(func() -> void:
			var font := b.get_theme_font("font")
			var font_size := b.get_theme_font_size("font_size")
			var spacing := float(b.get_theme_constant("line_spacing"))
			line.add_theme_font_override("normal_font", font)
			line.add_theme_font_size_override("normal_font_size", font_size)
			line.add_theme_color_override("default_color",
				b.get_theme_color("font_disabled_color" if b.disabled else "font_color"))
			line.offset_top = spacing * 0.5
			line.offset_bottom = line.offset_top + font.get_height(font_size) + 4.0
		)
		b.add_child(line)
	return b

# Reparents the single skip_tutorial_btn to the end of the visible menu.
# No-op outside the tutorial.
func _place_skip_tutorial_btn_last(menu: Container) -> void:
	if skip_tutorial_btn == null:
		return
	if skip_tutorial_btn.get_parent() != menu:
		if skip_tutorial_btn.get_parent() != null:
			skip_tutorial_btn.get_parent().remove_child(skip_tutorial_btn)
		menu.add_child(skip_tutorial_btn)
	menu.move_child(skip_tutorial_btn, menu.get_child_count() - 1)

# X glyph beside a track in an HBox; hidden until a QTE starts.
func _build_quick_time_ui() -> void:
	qte_root = HBoxContainer.new()
	# TOP_LEFT: _quick_time_event() positions it over the dodging combatant.
	qte_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	qte_root.add_theme_constant_override("separation", 14)
	qte_root.visible = false
	add_child(qte_root)

	# Sized to match the QTE track.
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

	# Placeholders; set per QTE.
	qte_zone = ColorRect.new()
	qte_zone.color = Color(0.85, 0.2, 0.2)
	qte_zone.size = Vector2(30, QTE_TRACK_HEIGHT)
	qte_track.add_child(qte_zone)

	qte_indicator = ColorRect.new()
	qte_indicator.color = Color(0.95, 0.95, 0.9)
	qte_indicator.size = Vector2(3.75, QTE_TRACK_HEIGHT)
	qte_track.add_child(qte_indicator)

# Races an X press (_unhandled_input(), pixel hit-test) against the sweep
# finishing (tw.finished). Waits until _qte_active flips off.
func _quick_time_event(target_actor: Node3D = null) -> bool:
	var duration := 1.6
	var zone_width_frac := randf_range(0.06, 0.12)
	# Keep the zone away from both ends of the sweep.
	var zone_start_frac := randf_range(0.15, 1.0 - zone_width_frac - 0.15)

	qte_zone.position.x = zone_start_frac * QTE_TRACK_WIDTH
	qte_zone.size.x = zone_width_frac * QTE_TRACK_WIDTH
	qte_indicator.position.x = 0.0

	# Over the dodging actor's head; null only for a headless test Battle.
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

# kill() on early press doesn't emit finished; guard kept defensively.
func _on_qte_timeout() -> void:
	if _qte_active:
		_qte_success = false
		_qte_active = false

# Shows a narration caption and waits for Enter/Continue. Real-action waits
# (hover, click) await their own signals instead.
# `on_layout_ready` runs after _fit_panel_height() has resized the panel, so
# highlight boxes land on the new row positions.
func _tutorial_show_step(text: String, on_layout_ready: Callable = Callable()) -> void:
	# Hidden by default outside tutorials (e.g. the QTE warning).
	_tutorial_caption.visible = true
	# [pulse] flashes the prompt inline at the end of the caption.
	_tutorial_caption.text = "%s\n[font_size=18][pulse]Press %s, %s, or click Continue[/pulse][/font_size]" % [text, Slot._badge("Space"), Slot._badge("Enter")]
	_caption_step_serial += 1
	var my_step := _caption_step_serial
	_tutorial_continue_btn.visible = true
	call_deferred("_fit_panel_height")
	await get_tree().process_frame
	if on_layout_ready.is_valid():
		on_layout_ready.call()
	_tutorial_awaiting_enter = true
	while _tutorial_awaiting_enter and not _skip_tutorial_requested:
		await get_tree().process_frame
	# Deferred so back-to-back captions don't flicker the Continue button.
	_hide_continue_if_idle.call_deferred(my_step)
	# Skip Tutorial released this wait; don't continue the interrupted narration.
	if _skip_tutorial_requested:
		return

var _caption_step_serial := 0

func _hide_continue_if_idle(step: int) -> void:
	if step == _caption_step_serial and is_instance_valid(_tutorial_continue_btn):
		_tutorial_continue_btn.visible = false

func _continue_tutorial_caption() -> void:
	if _tutorial_awaiting_enter:
		_tutorial_awaiting_enter = false


# _unhandled_input handles two independent gates: Space/Enter dismisses a caption
# (_tutorial_awaiting_enter), X resolves a QTE (_qte_active).
func _unhandled_input(event: InputEvent) -> void:
	if _tutorial_awaiting_enter and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_tutorial_awaiting_enter = false
		return
	# Hit test: the indicator's current position against the zone rect on screen.
	if not _qte_active:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_X:
		var indicator_center: float = qte_indicator.position.x + qte_indicator.size.x * 0.5
		var zone_left: float = qte_zone.position.x
		var zone_right: float = qte_zone.position.x + qte_zone.size.x
		_qte_success = indicator_center >= zone_left and indicator_center <= zone_right
		_qte_active = false


# Overhead bars are screen-space Controls so they stay legible at any depth.
# IGNORE does not cascade to children, so apply it recursively.
static func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)

func _build_overhead_bar(entry: Dictionary) -> void:
	# PanelContainer so _set_row_highlight() can box the whole card.
	var card := PanelContainer.new()
	# IGNORE: read-only card visible during minigames.
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _row_stylebox(false))
	if String(entry.kind) == "party":
		_party_status_column.add_child(card)
	else:
		_enemy_status_column.add_child(card)

	var box := VBoxContainer.new()
	# Compact cards so all three divers fit above the HUD at 1280x720.
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
	var bar_width := 72.0 if _uses_narrow_info_band() else float(OVERHEAD_BAR_WIDTH)
	bar.custom_minimum_size = Vector2(bar_width, 10)
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

	# Green overlay spanning the HP restored by _win()'s regroup; manually positioned.
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
	var bleed_icon := BattleFx.StatusIcon.new("bleed")
	bar_row.add_child(bleed_icon)
	var poison_icon := BattleFx.StatusIcon.new("poison")
	bar_row.add_child(poison_icon)

	# Oxygen bar only for divers; enemies never spend oxygen.
	var oxygen_bar: ProgressBar
	var oxygen_label: Label
	var oxygen_heal_overlay: ColorRect
	var xp_bar: ProgressBar
	if String(entry.kind) == "party":
		var o2_row := HBoxContainer.new()
		o2_row.alignment = BoxContainer.ALIGNMENT_CENTER
		o2_row.add_theme_constant_override("separation", 3)
		box.add_child(o2_row)

		oxygen_bar = ProgressBar.new()
		oxygen_bar.custom_minimum_size = Vector2(bar_width, 8)
		oxygen_bar.show_percentage = false
		var o2_fill := StyleBoxFlat.new()
		# Same blue as the overworld oxygen bar.
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

		# Oxygen counterpart of hp_heal_overlay.
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

		# XP to the next level: a thin gold bar under O2; exact numbers on hover.
		xp_bar = ProgressBar.new()
		xp_bar.custom_minimum_size = Vector2(bar_width, 4)
		xp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		xp_bar.show_percentage = false
		var xp_fill := StyleBoxFlat.new()
		xp_fill.bg_color = XP_GOLD
		xp_bar.add_theme_stylebox_override("fill", xp_fill)
		var xp_track := StyleBoxFlat.new()
		xp_track.bg_color = Color(0.03, 0.06, 0.08, 0.85)
		xp_bar.add_theme_stylebox_override("background", xp_track)
		box.add_child(xp_bar)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wrap long status summaries inside the card instead of widening it.
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if xp_bar != null:
		entry["xp_bar"] = xp_bar
	entry["bleed_icon"] = bleed_icon
	entry["poison_icon"] = poison_icon
	entry["overhead"] = box
	entry["card"] = card
	_ignore_mouse_recursive(card)
	# PASS (not STOP) so hover shows the XP tooltip without eating clicks.
	if xp_bar != null:
		xp_bar.mouse_filter = Control.MOUSE_FILTER_PASS

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
	if entry.has("xp_bar") and not bool(entry.get("xp_animating", false)):
		var xp_bar := entry.xp_bar as ProgressBar
		var maxed := s.level >= CombatantStats.MAX_LEVEL
		xp_bar.max_value = s.xp_to_next
		xp_bar.value = s.xp_to_next if maxed else s.xp
		xp_bar.tooltip_text = "Max level" if maxed else "XP %d / %d to Lv %d" % [s.xp, s.xp_to_next, s.level + 1]
	if entry.has("bleed_icon"):
		(entry.bleed_icon as Control).visible = s.status_level("bleed") > 0
		(entry.poison_icon as Control).visible = s.status_level("poison") > 0
	var status_text := s.status_summary()
	# Live Evasion pool (spent by dodges, refilled each own turn) as current/max.
	if String(entry.kind) in ["party", "enemy"]:
		status_text = "EVA %d/%d%s" % [
			s.evasion_current, s.effective_evasion(),
			"   " + status_text if status_text != "" else "",
		]
	var label := entry.status_label as Label
	label.tooltip_text = status_text
	var font_size := 10 if _uses_narrow_info_band() else 11
	if label.get_theme_font_size("font_size") != font_size:
		label.add_theme_font_size_override("font_size", font_size)
	label.text = status_text.replace(" turns left", "t").replace(" turn left", "t") if _uses_narrow_info_band() else status_text
	label.visible = status_text != ""
	# Hide a dead combatant's card along with its death animation.
	if entry.has("card"):
		(entry.card as Control).visible = s.hp > 0

# Shows the restored [before, after] span on a bar; hidden if nothing grew.
func _show_heal_overlay(overlay: ColorRect, before: float, after: float, max_value: float) -> void:
	if max_value <= 0.0 or after <= before:
		overlay.visible = false
		return
	var actual_width := (overlay.get_parent() as Control).size.x
	overlay.position.x = (before / max_value) * actual_width
	overlay.size.x = ((after - before) / max_value) * actual_width
	overlay.visible = true

# --- Previews for items, heals and revives on divers ---

# Stat items: "+2" in green on that diver's stat table ("You" for the acting
# diver). HP / O2 items: green span on the bar they'd fill.
func _show_item_preview(item_id: String, target: Dictionary) -> void:
	var def: Dictionary = Items.ITEMS.get(item_id, {})
	var kind := String(def.get("kind", ""))
	var amount := int(def.get("amount", 0))
	var s := target.stats as CombatantStats
	var field := String({"attack_up": "strength", "defense_up": "defense", "accuracy_up": "accuracy", "evasion_up": "evasion"}.get(kind, ""))
	if field != "":
		var ui := _player_stats_ui if target == _acting else _enemy_stats_ui
		_set_stats_panel_base(ui, s)
		if ui == _enemy_stats_ui:
			(_enemy_stats_ui.title as Label).text = String(target.display_name)
		_apply_stat_delta(ui, s, {field: amount})
		(ui.panel as Control).visible = true
		if _miss_label != null:
			_miss_label.visible = false
	elif kind == "heal" and target.has("hp_heal_overlay"):
		_show_heal_overlay(target.hp_heal_overlay, s.hp, mini(s.hp_max, s.hp + amount), s.hp_max)
	elif kind == "oxygen" and target.has("oxygen_heal_overlay"):
		_show_heal_overlay(target.oxygen_heal_overlay, s.oxygen, minf(s.oxygen_max, s.oxygen + float(amount)), s.oxygen_max)

# Heal: green span from current HP to where it would land. Revive: the downed
# diver's card shows again with the restored HP in green and the name greyed.
func _show_heal_preview(move: Dictionary, targets: Array) -> void:
	var effect := String(move.get("effect", ""))
	var amount := int(move.get("amount", 0))
	for target_value in targets:
		var target := target_value as Dictionary
		if not target.has("hp_heal_overlay"):
			continue
		var s := target.stats as CombatantStats
		if effect == "revive":
			if target.has("card"):
				(target.card as Control).visible = true
			if target.has("name_label"):
				(target.name_label as Control).modulate = Color(0.55, 0.55, 0.55)
			# The card just reappeared; place the span once it has its size.
			_show_heal_overlay.call_deferred(target.hp_heal_overlay, 0.0, float(mini(s.hp_max, amount)), float(s.hp_max))
		elif effect == "heal" and s.hp > 0:
			_show_heal_overlay(target.hp_heal_overlay, s.hp, mini(s.hp_max, s.hp + amount), s.hp_max)

func _clear_support_preview() -> void:
	for entry in party:
		for key in ["hp_heal_overlay", "oxygen_heal_overlay"]:
			if entry.has(key):
				(entry[key] as ColorRect).visible = false
		if entry.has("name_label"):
			(entry.name_label as Control).modulate = Color.WHITE
		_refresh_bar(entry)   # hides a downed diver's card again
	if not _stat_preview_frozen and not _enemy_stats_ui.is_empty():
		(_enemy_stats_ui.panel as Control).visible = false
		if _acting.has("stats"):
			_set_stats_panel_base(_player_stats_ui, _acting.stats as CombatantStats)

func _log(text: String) -> void:
	log_label.clear()
	log_label.add_text(text)
	call_deferred("_fit_panel_height")

# Enemy-attack damage ("Bucky -3") shown in the stat-loss red.
static var _damage_regex: RegEx
func _log_enemy_damage(text: String) -> void:
	if _damage_regex == null:
		_damage_regex = RegEx.create_from_string("(?<![A-Za-z0-9])-[0-9]+")
	var safe := text.replace("[", "[lb]")
	log_label.clear()
	log_label.append_text(_damage_regex.sub(safe, "[color=#%s]$0[/color]" % CombatRules.STAT_LOSS_COLOR, true))
	call_deferred("_fit_panel_height")

# _log() for lines that show key tiles (Slot._badge() BBCode).
func _log_rich(text: String) -> void:
	log_label.clear()
	log_label.append_text(text)
	call_deferred("_fit_panel_height")

# Appends without rebuilding, so existing colored text keeps its colour.
func _log_append(text: String) -> void:
	log_label.add_text(text)
	call_deferred("_fit_panel_height")

func _audio_call(method: StringName, args: Array = []) -> void:
	var owner := get_node_or_null("/root/GameAudio")
	if owner != null and owner.has_method(method):
		owner.callv(method, args)

func _move_is_heavy(move: Dictionary) -> bool:
	var power := int(move.get("power", 0))
	var move_name := String(move.get("name", "")).to_lower()
	return power >= 10 or move_name.contains("heavy") or move_name.contains("crushing") \
		or move_name.contains("great") or move_name.contains("spinning")

# 3 s base; 10 words +1 s, 11-19 words +2 s, 20+ words +3 s.
func _log_read_delay() -> float:
	var words := _current_log_text().split(" ", false).size()
	var extra := 0.0
	if words >= 20:
		extra = 3.0
	elif words > 10:
		extra = 2.0
	elif words == 10:
		extra = 1.0
	return LOG_MIN_READ_SECONDS + extra

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

# Label3D feedback on the combatant the result happened to.
func _show_combat_feedback(entry: Dictionary, result: Dictionary, play_sound: bool = true) -> void:
	if String(result.get("debuff", "")) == "revive":
		# Single restore point for the resolved result; also handles actors that entered down.
		_return_to_stage(entry)
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	var messages: Array[Dictionary] = []
	var result_kind := String(result.get("debuff", ""))
	# Distinct cues for miss, QTE dodge and damage; heavy cue at the same
	# fifth-of-max-HP threshold as _react(). No impact sound for heals/revives.
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
		# Stat losses in the shared stat-loss red.
		messages.append({"text": "%s -%d" % [String(_STAT_ABBR.get(result_kind, result_kind.to_upper())), int(result.get("changed", 0))], "color": Color.html(CombatRules.STAT_LOSS_COLOR)})
	elif not bool(result.get("hit", false)) or bool(result.get("dodged", false)):
		messages.append({"text": "DODGE", "color": FEEDBACK_EFFECT_COLOR})
	elif int(result.get("damage", 0)) > 0:
		messages.append({"text": "-%d" % int(result.damage), "color": FEEDBACK_DAMAGE_COLOR})
	elif (result.get("effects", []) as Array).is_empty() and not bool(result.get("immune", false)):
		# A landed hit that did no damage reads as a red -0.
		messages.append({"text": "-0", "color": FEEDBACK_DAMAGE_COLOR})
	if bool(result.get("immune", false)):
		messages.append({"text": "IMMUNE", "color": FEEDBACK_IMMUNE_COLOR})
	var effects := result.get("effects", []) as Array
	for effect in effects:
		var effect_color := Color.html(CombatRules.STAT_LOSS_COLOR) if CombatRules.has_stat_loss(String(effect)) else FEEDBACK_NEGATIVE_COLOR
		messages.append({"text": String(effect), "color": effect_color})
	for index in range(messages.size()):
		var message := messages[index] as Dictionary
		_show_floating_text(entry, String(message.text), message.color as Color, index)
	_show_result_fx(entry, result)

# Stage effects for one result: red flash on damage, green bubbles on a heal,
# red down-arrows when a stat loss or status lands, yellow flash on Stun.
func _show_result_fx(entry: Dictionary, result: Dictionary) -> void:
	var actor := entry.actor as Node3D
	var result_kind := String(result.get("debuff", ""))
	var landed := bool(result.get("hit", false)) and not bool(result.get("dodged", false))
	if result_kind in ["heal", "revive"]:
		if int(result.get("changed", 0)) > 0:
			BattleFx.bubbles(_stage_vp, _fx_point(actor, 0.5))
		return
	if not landed:
		return
	if int(result.get("damage", 0)) > 0:
		BattleFx.flash(actor, BattleFx.DAMAGE_RED)
	var effects := (result.get("effects", []) as Array).filter(
		func(e: Variant) -> bool: return not String(e).ends_with(" -0"))
	if (result_kind != "" and int(result.get("changed", 0)) > 0) or not effects.is_empty():
		BattleFx.down_arrows(_stage_vp, _fx_point(actor, 1.0))
	if effects.any(func(e: Variant) -> bool: return String(e).begins_with("Stun")):
		# After the damage flash so the two colours don't overlap.
		# Delay on the actor's own tween so it dies with the actor.
		actor.create_tween().tween_callback(BattleFx.flash.bind(actor, BattleFx.STUN_YELLOW, 4)).set_delay(0.55)

# Stage-space point on `actor`: 0 = feet, 1 = head (same space as floating text).
func _fx_point(actor: Node3D, height_frac: float) -> Vector3:
	var top := _top_of(actor) - actor.global_position + actor.position
	var bottom := _bottom_of(actor) - actor.global_position + actor.position
	return bottom.lerp(top, height_frac)

const XP_GOLD := Color(1.0, 0.8, 0.25)

# Fills the card's XP bar from its old value; each level-up fills it to the
# end, flashes, says LEVEL UP and restarts with the leftover. Not awaited.
func _animate_xp_gain(entry: Dictionary, amount: int, xp_before: int, next_before: int, level_ups: int) -> void:
	if amount <= 0 or not entry.has("xp_bar") or (level_ups == 0 and (entry.stats as CombatantStats).level >= CombatantStats.MAX_LEVEL):
		return
	var bar := entry.xp_bar as ProgressBar
	var s := entry.stats as CombatantStats
	entry["xp_animating"] = true
	if entry.has("actor") and is_instance_valid(entry.actor):
		# Stacked high so LEVEL UP (below) never overlaps it.
		_show_floating_text(entry, "+%d XP" % amount, XP_GOLD, 3)
	bar.max_value = next_before
	bar.value = xp_before
	for i in level_ups:
		var fill := bar.create_tween()
		fill.tween_property(bar, "value", bar.max_value, 0.6)
		await fill.finished
		var flash := bar.create_tween()
		flash.tween_property(bar, "modulate", Color(2.0, 1.8, 1.2), 0.12)
		flash.tween_property(bar, "modulate", Color.WHITE, 0.3)
		if entry.has("actor") and is_instance_valid(entry.actor):
			_show_floating_text(entry, "LEVEL UP", XP_GOLD, 0)
		await flash.finished
		# The next level's requirement (same formula as CombatantStats.gain_xp).
		var reached := s.level - level_ups + i + 1
		bar.max_value = int(round(CombatantStats.XP_BASE * pow(float(reached), CombatantStats.XP_CURVE)))
		bar.value = 0
	var rest := bar.create_tween()
	rest.tween_property(bar, "value", bar.max_value if s.level >= CombatantStats.MAX_LEVEL else float(s.xp), 0.5)
	await rest.finished
	entry["xp_animating"] = false
	_refresh_bar(entry)

func _show_floating_text(entry: Dictionary, text: String, color: Color, stack_index: int = 0) -> void:
	var actor := entry.actor as Node3D
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 48
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = _top_of(actor) - actor.global_position + actor.position + Vector3(0.0, 0.35 + float(stack_index) * 0.32, 0.0)
	_stage_vp.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.65, 1.1)
	# Fade both glyph and outline; the outline alone leaves a black ghost.
	tween.tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.45)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.65).set_delay(0.45)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

# Item effects (floating "+HP" etc.) get this long before a Bleed/Poison tick.
const ITEM_EFFECT_SHOW := 1.2

# A diver's end of turn: when Bleed or Poison will tick, wait until they're back
# on their spot (attacks) or the item's effect has shown, so the tick doesn't
# read as part of the action. No wait when nothing ticks.
func _finish_party_turn(entry: Dictionary, after_item := false) -> void:
	var s := entry.stats as CombatantStats
	if s.status_level("bleed") > 0 or s.status_level("poison") > 0:
		if after_item:
			await get_tree().create_timer(ITEM_EFFECT_SHOW).timeout
		else:
			while Time.get_ticks_msec() < int(entry.get("home_at_ms", 0)):
				await get_tree().process_frame
	_finish_actor_turn(entry)

func _finish_actor_turn(entry: Dictionary) -> void:
	_show_damage_over_time(entry, (entry.stats as CombatantStats).end_turn())
	_tick_timed_buffs(entry)

# Floating text, log, bar refresh and death for one Bleed/Poison tick.
# stack_base lifts labels above any already shown this turn.
func _show_damage_over_time(entry: Dictionary, tick: Dictionary, stack_base: int = 0) -> void:
	var bleed_damage := int(tick.get("bleed_damage", 0))
	var poison_tick := int(tick.get("poison_damage", 0))
	if (bleed_damage > 0 or poison_tick > 0) and entry.has("actor") and is_instance_valid(entry.actor):
		var actor := entry.actor as Node3D
		if bleed_damage > 0:
			BattleFx.blood_drops(_stage_vp, _fx_point(actor, 0.75))
		if poison_tick > 0:
			BattleFx.poison_cloud(_stage_vp, _fx_point(actor, 0.6))
		actor.create_tween().tween_callback(BattleFx.flash.bind(actor, BattleFx.DAMAGE_RED)).set_delay(0.35)
	if bleed_damage > 0:
		_show_floating_text(entry, "BLEED -%d" % bleed_damage, Color(0.9, 0.12, 0.2), stack_base)
		stack_base += 1
		_log_append("  %s is bleeding and takes %d damage." % [String(entry.display_name), bleed_damage])
	var poison_damage := int(tick.get("poison_damage", 0))
	if poison_damage > 0:
		_show_floating_text(entry, "POISON -%d" % poison_damage, Color(0.55, 0.9, 0.28), stack_base)
		_log_append("  %s is poisoned and takes %d damage." % [String(entry.display_name), poison_damage])
	_refresh_bar(entry)
	if (entry.stats as CombatantStats).hp <= 0 and entry.has("actor") and is_instance_valid(entry.actor):
		if entry.actor is Diver:
			(entry.actor as Diver).play_death_fade()
		elif String(entry.kind) == "enemy":
			_play_enemy_death(entry)

func _living(list: Array) -> Array:
	return list.filter(func(e: Dictionary) -> bool: return (e.stats as CombatantStats).hp > 0)

# Highest agility first. sort_custom isn't stable; tie order doesn't matter.
func _by_agility(a: Dictionary, b: Dictionary) -> bool:
	return (a.stats as CombatantStats).effective_agility() > (b.stats as CombatantStats).effective_agility()

# New round: all living combatants sorted by current agility.
func _rebuild_queue() -> void:
	_queue = _living(party) + _living(enemies)
	_queue.sort_custom(_by_agility)
	_refresh_queue_row()

# Re-sorts only those still waiting, so nobody acts twice.
func _resort_pending() -> void:
	_queue.sort_custom(_by_agility)
	_refresh_queue_row()

func _refresh_queue_row() -> void:
	for c in queue_row.get_children():
		c.queue_free()
	# _acting is already popped off _queue; its "NOW" chip is drawn first in its own style.
	if not _acting.is_empty():
		queue_row.add_child(_build_acting_chip(_acting))
	var header := Label.new()
	header.text = "Next"
	header.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	header.add_theme_font_size_override("font_size", 13)
	queue_row.add_child(header)
	# Capped at MAX_QUEUE_SLOTS.
	for i in range(mini(_queue.size(), MAX_QUEUE_SLOTS)):
		queue_row.add_child(_build_queue_chip(_queue[i], i))
	if encounter_source == "maze_puppets":
		var wave := Label.new()
		wave.text = "Puppets %d/%d" % [_puppet_wave + 1, PUPPET_WAVES.size()]
		wave.add_theme_font_size_override("font_size", 13)
		wave.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		queue_row.add_child(wave)
	# Chips are rebuilt every turn, so re-apply IGNORE after each rebuild.
	_ignore_mouse_recursive(queue_row)

# Gold-bordered spotlight card for the current actor.
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

# Cards shrink and fade with distance from the front; party and enemy
# cards use separate color families.
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

	# Fade toward the back, clamped to stay legible.
	panel.modulate.a = maxf(0.4, 1.0 - float(index) * 0.22)
	return panel

# Turn dispatcher: check for a wipe on either side first, rebuild the queue
# at round end, then run the enemy AI or the player menu.
func _advance_turn() -> void:
	# The attacking diver's turn is over: drop their move/damage line.
	_hide_move_damage_line()
	# After all scripted moves and the QTE turn, show "Defeat the enemy!" once,
	# then continue into the real fight checks below.
	if tutorial_encounter and not _tutorial_finale_shown and _tutorial_step >= _TUTORIAL_SCRIPT.size() and _tutorial_enemy_turns >= 1:
		_tutorial_finale_shown = true
		if not special_encounter:
			_set_tutorial_guard(false)   # the real fight starts here
		_set_all_buttons(false)
		await _tutorial_show_step("Now defeat the enemy for real to finish the lesson! Winning a battle awards XP to your whole party, not just whoever fought including anyone who went down during the fight, who gains XP the same as everyone else. Gain enough XP and a diver levels up, which refills their HP and Oxygen even if they went down. Otherwise a downed diver needs a Revive spell to get back on their feet. Leveling up doesn't change your combat stats but instead lets the divers gain new abilities.")
		await _tutorial_show_step("Winning won't grant any XP or rewards in this case but makes for good practice. A loss just sends the party back to the overworld to regroup, fully healed.")
		# Clear the lesson caption/Continue for the rest of the fight.
		_tutorial_caption.text = ""
		_tutorial_caption.visible = false
		_tutorial_continue_btn.visible = false
		call_deferred("_fit_panel_height")
	# Special-encounter finale: once every diver has played their minigame.
	if special_encounter and tutorial_encounter and not _special_tutorial_finale_shown and _tutorial_enemy_turns >= 3:
		_special_tutorial_finale_shown = true
		_set_all_buttons(false)
		await _tutorial_show_step("Defeat enemies in special encounters to unlock one-use stat-boosting battle items. Losing one is no real setback either - just like the very first combat tutorial, you'll get the choice to retry or head back to the overworld, fully healed. This particular fight is still just practice, though - winning it won't grant a reward, but the real special encounter that does will remain at this map location afterward.")
		# Clear the caption so the Continue pulse doesn't linger.
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
		if encounter_source == "maze_puppets":
			# A mutual knockout is not permission to progress/reward a wave.
			if _living(party).is_empty():
				_lose()
				return
			encounter_wave_cleared.emit(_puppet_wave + 1, PUPPET_WAVES.size())
			if _puppet_wave + 1 < PUPPET_WAVES.size():
				_start_next_puppet_wave()
				return
		_win()
		return
	if _living(party).is_empty():
		_lose()
		return
	if _queue.is_empty():
		_rebuild_queue()
	# Tutorial: force the stage's diver to act next, removed from wherever it
	# sits in _queue so others keep their order.
	var forced_index := _tutorial_party_index_for_step(_tutorial_step) if tutorial_encounter else -1
	var forced_actor := {}
	if forced_index >= 0:
		var forced: Dictionary = party[forced_index]
		if _living(party).has(forced) and _queue.has(forced):
			_queue.erase(forced)
			forced_actor = forced
	# Scripted initiative still passes through the same status boundary.
	_acting = forced_actor if not forced_actor.is_empty() else _queue.pop_front()
	_refresh_queue_row()
	if (_acting.stats as CombatantStats).hp <= 0:
		_advance_turn()   # downed since the queue was built
		return
	if (_acting.stats as CombatantStats).is_stunned():
		# Stun skips the action and only the Stun counter ticks; Bleed/Poison still apply.
		(_acting.stats as CombatantStats).consume_status_turn("stun")
		_show_floating_text(_acting, "STUNNED", FEEDBACK_NEGATIVE_COLOR)
		if _acting.has("actor") and is_instance_valid(_acting.actor):
			BattleFx.flash(_acting.actor as Node3D, BattleFx.STUN_YELLOW, 4)
		_log("%s is stunned for this turn and can't act." % String(_acting.display_name))
		_show_damage_over_time(_acting, (_acting.stats as CombatantStats).tick_damage_over_time(), 1)
		_refresh_bar(_acting)
		# Hold so the stun/DoT line can be read.
		_busy = true
		_set_all_buttons(false)
		await get_tree().create_timer(_log_read_delay()).timeout
		_advance_turn()
		return
	if String(_acting.kind) == "enemy":
		var forced_target := {}
		if tutorial_encounter:
			# Lock the menus during these prompts; _do_enemy_turn() runs only after.
			_set_all_buttons(false)
			main_menu.visible = false
			move_menu.visible = false
			item_menu.visible = false
			target_menu.visible = false
			if _tutorial_step == 0:
				await _first_fight_prompt()
			# Skip pressed during a caption: the skip handler owns the screen now.
			if _skip_tutorial_requested:
				return
			forced_target = await _tutorial_prep_enemy_turn()
			if _skip_tutorial_requested:
				return
		_do_enemy_turn(_acting, forced_target)
	else:
		_start_party_turn(_acting)

# Tutorial enemy turn: guarantees a QTE (via _tutorial_force_next_qte) after
# explaining it. Returns the chosen target, passed to _do_enemy_turn() as
# forced_target, or {} once the scripted turns are done.
func _tutorial_prep_enemy_turn() -> Dictionary:
	_tutorial_enemy_turns += 1
	# Special tutorial scripts three enemy turns, one per diver.
	if _tutorial_enemy_turns > 3:
		return {}
	var alive_party := _living(party)
	if alive_party.is_empty():
		return {}
	var target: Dictionary = _pick_enemy_target(alive_party)
	if special_encounter:
		# Special encounter turns run a minigame, not the QTE, so explain that instead.
		# Shown only on the first teaching turn.
		if _tutorial_enemy_turns == 1:
			await _tutorial_show_step("Each diver has their own special encounter minigame to play to dodge extra damage from the enemy before their attack. Play it perfectly and you'll dodge the attack completely.")
		match String(target.get("ability_id", "")):
			"swap":
				_swap_demo_frame.visible = true
				_refresh_swap_demo_media("swap")
				call_deferred("_fit_panel_height")
				# Wording matches diver_swap_minigame.gd's on-screen hint.
				await _tutorial_show_step("Maxilani's special encounter involves swapping with portraits to the left and right of her position to correctly line them up with incoming portraits. Press %s or %s to choose portraits adjacent to her position, then press %s to confirm swapping positions between Maxilani and that portrait." % [Slot._badge("Left"), Slot._badge("Right"), Slot._badge("E")])
				# Free the demo clip before the real minigame takes over.
				for child in _swap_demo_frame.get_children():
					child.queue_free()
				_swap_demo_frame.visible = false
				call_deferred("_fit_panel_height")
			"grapple":
				# Matches grapple_intercept_minigame.gd's controls and scoring. Demo clip
				# falls back to a placeholder until SPECIAL_ENCOUNTER_MEDIA["grapple"] exists.
				_swap_demo_frame.visible = true
				_refresh_swap_demo_media("grapple")
				call_deferred("_fit_panel_height")
				await _tutorial_show_step("Musashi's special encounter involves grappling the correctly colored spheres before their wave reaches him. Move the mouse to aim your crosshair, then %s to fire the grapple at the safe color. The wave clears once every safe-colored sphere has been hit, so watch which color is safe each round in the bottom battle text where it mentions to grapple/avoid [color=#ffe626]YELLOW[/color] and [color=#26f259]GREEN[/color]." % Slot._badge("Left click"))
				for child in _swap_demo_frame.get_children():
					child.queue_free()
				_swap_demo_frame.visible = false
				call_deferred("_fit_panel_height")
			"shockwave":
				# Demo clip (placeholder until SPECIAL_ENCOUNTER_MEDIA["shockwave"] exists).
				_swap_demo_frame.visible = true
				_refresh_swap_demo_media("shockwave")
				call_deferred("_fit_panel_height")
				await _tutorial_show_step("Bucky's special encounter involves pressing %s and %s to move to the left and right lanes from the center or press nothing to stay in the center to position Bucky in lanes with breakable rocks and no walls. Hold the directional keys to stay in the lanes then time correctly pressing %s to shockwave a rock when it arrives in the lane to break it. Be careful: you only get one shockwave per wave, so a press that's too early or too late is wasted until the next wave." % [Slot._badge("Left"), Slot._badge("Right"), Slot._badge("E")])
				for child in _swap_demo_frame.get_children():
					child.queue_free()
				_swap_demo_frame.visible = false
				call_deferred("_fit_panel_height")
		# Clear the caption before the minigame takes over.
		_tutorial_caption.text = ""
		_tutorial_caption.visible = false
		call_deferred("_fit_panel_height")
		return target
	# QTE only rolls after a swing beats Evasion, so zero it to guarantee the QTE.
	var defender := target.stats as CombatantStats
	defender.evasion_current = 0
	_tutorial_force_next_qte = true
	# [img] can't embed a Control, so the real qte_root is temporarily moved into
	# the caption column; it is restored before returning.
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
	# Borrows _levelup_caption (unused mid-fight) for the caption's second half.
	_levelup_caption.text = "The white bar sweeps across the track, and pressing %s the instant it's inside the red zone dodges the attack completely. Miss the timing and the attack just lands as normal.\n[font_size=22][pulse]Press %s to continue[/pulse][/font_size]" % [Slot._badge("X"), Slot._badge("Enter")]
	_levelup_caption.visible = true
	call_deferred("_fit_panel_height")
	await get_tree().process_frame
	_tutorial_awaiting_enter = true
	while _tutorial_awaiting_enter:
		await get_tree().process_frame
	_levelup_caption.visible = false
	_levelup_caption.text = ""
	# Clear the QTE caption.
	_tutorial_caption.text = ""
	_tutorial_caption.visible = false
	qte_root.visible = false
	col.remove_child(qte_root)
	qte_normal_parent.add_child(qte_root)
	qte_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	call_deferred("_fit_panel_height")
	return target

# Party index for stage `step`, or -1 past the end / missing from the party.
func _tutorial_party_index_for_step(step: int) -> int:
	if step < 0 or step >= _TUTORIAL_SCRIPT.size():
		return -1
	var idx := int(_TUTORIAL_SCRIPT[step].get("party_index", -1))
	return idx if idx < party.size() else -1

# True only on the current stage's diver's turn, while the script runs.
# Excluded for special encounters, whose moves are a free choice.
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
	# Shown once a damage move is picked (see the target step).
	_selected_move_panel.visible = false
	(_player_stats_ui.panel as Control).visible = true
	call_deferred("_fit_panel_height")
	_refresh_player_stats_panel()
	_clear_stat_preview()
	_show_turn_cursor_on(actor)
	var turn_text := "%s's turn." % String(actor.display_name)
	if not _intro_hold.is_empty():
		turn_text = "%s\n%s" % [_intro_hold, turn_text]
		_intro_hold = ""
	_log(turn_text)
	_set_all_buttons(true)
	if prologue_angler_encounter or prologue_octopus_encounter:
		run_btn.visible = false
		items_btn.visible = false
	# Run stays disabled for the whole tutorial fight.
	if tutorial_encounter:
		run_btn.disabled = true
	# Scripted turns skip straight to the move menu.
	if _is_tutorial_scripted_turn(actor):
		_show_moves()
	elif special_encounter and tutorial_encounter and not _first_fight_prompt_shown:
		# Special encounter intro plays with the menu disabled.
		_play_special_encounter_intro()

# Tutorials: nobody can be knocked out during the guided part (until "defeat
# the enemy for real", or until the last special minigame).
var _tutorial_guard := false

func _set_tutorial_guard(on: bool) -> void:
	_tutorial_guard = on
	for entry in party + enemies:
		var s := (entry as Dictionary).get("stats") as CombatantStats
		if s != null:
			s.min_hp = 1 if on else 0

func _play_special_encounter_intro() -> void:
	_set_tutorial_guard(true)
	# Full HP/Oxygen at the start of the special tutorial (swap-ins filled as they arrive).
	for entry in party:
		(entry.stats as CombatantStats).hp = (entry.stats as CombatantStats).hp_max
		(entry.stats as CombatantStats).oxygen = (entry.stats as CombatantStats).oxygen_max
		_refresh_bar(entry)
	_set_all_buttons(false)
	await _first_fight_prompt()
	if _skip_tutorial_requested:
		return
	# Clear the caption: no move gate follows to overwrite it.
	_tutorial_caption.text = ""
	_tutorial_caption.visible = false
	call_deferred("_fit_panel_height")
	_set_all_buttons(true)
	if tutorial_encounter:
		run_btn.disabled = true

func _process(_delta: float) -> void:
	# Reconcile the log's caption gate with our Continue action.
	if is_instance_valid(log_label):
		var show_log := not _tutorial_awaiting_enter
		if log_label.visible != show_log:
			log_label.visible = show_log
			call_deferred("_fit_panel_height")
	_update_target_cursors()
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

# BASE_MOVES plus equipped spells (spell defs double as move defs).
# Falls back to Staff_Diver's kit for a standalone test Battle.
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
			"target": String(def.get("target", "")),
		})
	return out

func _show_moves() -> void:
	if _busy:
		return
	main_menu.visible = false
	_populate_move_menu(_acting)
	move_menu.visible = true
	call_deferred("_fit_panel_height")
	# Intro shows on the first move menu of any tutorial; only the gate below
	# requires a scripted turn.
	if tutorial_encounter and _tutorial_step == 0 and not _first_fight_prompt_shown:
		# Lock every move button through the intro captions.
		for b in move_buttons:
			(b as Button).disabled = true
		back_btn.disabled = true
		await _first_fight_prompt()
		# Skipped during the intro: don't restore the caption or gate.
		if _skip_tutorial_requested:
			return
		await _explain_turn_order()
		if _skip_tutorial_requested:
			return
		if not _is_tutorial_scripted_turn(_acting):
			# Special encounter has no gate to re-enable buttons; repopulate instead.
			_populate_move_menu(_acting)
			back_btn.disabled = false
	# Move gate only on the scripted diver's turn.
	if _is_tutorial_scripted_turn(_acting):
		_apply_tutorial_move_gate()

# Own guard: both _advance_turn() (enemy first) and _show_moves() can reach this.
var _first_fight_prompt_shown := false

# Loads the special-encounter demo for `ability_id` from
# TutorialContent.SPECIAL_ENCOUNTER_MEDIA: image, looping .ogv, or placeholder.
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
			# MediaFrame positions its child via size flags; fill it and scale the video.
			player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			player.size_flags_vertical = Control.SIZE_EXPAND_FILL
			player.stream = video_stream
			player.finished.connect(player.play)
			_swap_demo_frame.add_child(player)
			# Deferred so Theora decode doesn't contend with the UI build.
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
		await _tutorial_show_step("Welcome to your first special encounter! By fighting special encounters, you can gain items that give you temporary stat boosting perks for other battles.")
		if _skip_tutorial_requested:
			return
		await _tutorial_show_step("Normally, only one chosen diver gets to enter the special encounter. For now, Maxilani is the chosen diver. Diver agility applies as normal and will determine whether you attack first or after the enemy.")
		if _skip_tutorial_requested:
			return
		# _build_stage() forces the enemy's agility below Maxilani's here.
		await _tutorial_show_step("In this case, Maxilani will attack first. This special encounter is just for practice and won't grant anything for winning or losing, and the normal special encounter that grants an item will remain at this map location after the tutorial.")
		if _skip_tutorial_requested:
			return

	else:
		await _tutorial_show_step("While exploring the deep, random encounters like this one with deep sea enemies can occur at any time.")

# One-shot: boxes the turn-order bar, explains turn order and combat basics,
# waits for Enter, then removes the highlight.
func _explain_turn_order() -> void:
	_turn_order_highlight = _highlight_box(_turn_order_highlight, _queue_bar)
	var combat_basics := TutorialContent.page_body("Combat Basics")
	var turn_order_line := "Turn order is shown from first at left to last at right in the turn order bar at the top."
	var agility_line := "Turn order is decided by Agility - whoever has the highest goes first. If a move changes someone's Agility, the turn order always updates right away to reflect it."
	await _tutorial_show_step("%s %s %s" % [combat_basics, turn_order_line, agility_line])
	_turn_order_highlight.visible = false

# Lazily creates a red-bordered Panel and repositions it over `target` each call.
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
	# Bucky's Haymaker is the first scripted move with an Oxygen cost.
	if forced_name == "Crushing Haymaker":
		_tutorial_caption.text += " This move has an Oxygen cost of %d as shown in the bottom right corner." % int(mv.get("oxygen_cost", 0.0))
	call_deferred("_fit_panel_height")
	btn.disabled = false

# Power badge in the button's top-right corner, beside the name. Separate
# Label with IGNORE so it doesn't steal the button's click.
func _add_power_badge(btn: Button, power: int) -> void:
	# Opaque plate so the number stays readable over long names.
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

# Oxygen cost ("16O2") on its own plate in the bottom-right corner.
func _add_oxygen_badge(btn: Button, cost: int) -> void:
	var plate := PanelContainer.new()
	plate.name = "OxygenBadge"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.05, 0.08, 0.1, 0.85)
	plate_style.set_corner_radius_all(4)
	plate_style.content_margin_left = 4
	plate_style.content_margin_right = 4
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.offset_right = -4
	plate.offset_bottom = -3
	plate.offset_left = -4
	plate.offset_top = -3
	btn.add_child(plate)
	var badge := Label.new()
	badge.text = "%dO2" % cost
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(badge)

# An item's effect as [plain text, green BBCode], e.g. "Heal 5 HP" or "DEF +2".
const _ITEM_EFFECT_LABELS := {
	"heal": "Heal %d HP", "oxygen": "O2 +%d", "attack_up": "STR +%d",
	"defense_up": "DEF +%d", "accuracy_up": "ACC +%d", "evasion_up": "EVA +%d",
}
func _item_effect_line(def: Dictionary) -> Array:
	var kind := String(def.get("kind", ""))
	if not _ITEM_EFFECT_LABELS.has(kind):
		var fallback := String(def.get("description", ""))
		return [fallback, ""]
	var text := String(_ITEM_EFFECT_LABELS[kind]) % int(def.get("amount", 0))
	return [text, "[color=#%s]%s[/color]" % [STAT_COLOR_UP.to_html(false), text]]

const _STAT_ABBR := {"strength": "STR", "defense": "DEF", "agility": "AGI", "accuracy": "ACC", "evasion": "EVA"}

# A move's effects as [plain text, coloured BBCode], e.g. "Damage; ACC +6" or
# "Enemy DEF -3; ACC +4": enemy stat losses red, accuracy gains green.
func _move_effect_line(mv: Dictionary, caster: CombatantStats) -> Array:
	var parts: Array[Array] = []   # [text, colour or null]
	var red := Color.html(CombatRules.STAT_LOSS_COLOR)
	var support := String(mv.get("effect", ""))
	if support == "heal":
		var everyone := String(mv.get("target", "")) == "all_allies"
		parts.append(["Heal %d HP%s" % [int(mv.get("amount", 0)), " (party)" if everyone else ""], STAT_COLOR_UP])
	elif support == "revive":
		parts.append(["Revive %d HP" % int(mv.get("amount", 0)), STAT_COLOR_UP])
	else:
		var debuff := String(mv.get("debuff", ""))
		var deals_damage := CombatRules.formula_value(caster, mv.get("formula", {})) > 0 if mv.has("formula") \
			else debuff == "" and int(mv.get("power", 0)) > 0
		if deals_damage:
			parts.append(["Damage", null])
		if debuff != "":
			parts.append(["Enemy %s -%d" % [_STAT_ABBR.get(debuff, debuff.to_upper()), int(mv.get("amount", 0))], red])
		for effect_value in mv.get("effects", []):
			var effect := effect_value as Dictionary
			match String(effect.get("kind", "")):
				"reduce_evasion":
					parts.append(["Enemy EVA -%d" % CombatRules.formula_value(caster, effect.get("amount", {})), red])
				"reduce_defense":
					parts.append(["Enemy DEF -%d" % CombatRules.formula_value(caster, effect.get("amount", {})), red])
				"status":
					parts.append([String(effect.get("status", "")).capitalize(), null])
				"self_temporary":
					parts.append(["Self Cost", null])
		var acc_mod := int(mv.get("acc_mod", 0))
		if acc_mod != 0:
			parts.append(["ACC %s%d" % ["+" if acc_mod > 0 else "", acc_mod], STAT_COLOR_UP if acc_mod > 0 else red])
	var plain: Array[String] = []
	var rich: Array[String] = []
	for part in parts:
		plain.append(String(part[0]))
		rich.append(String(part[0]) if part[1] == null else "[color=#%s]%s[/color]" % [(part[1] as Color).to_html(false), part[0]])
	return ["; ".join(plain), "; ".join(rich)]

func _populate_move_menu(actor: Dictionary) -> void:
	# Stop the flash tween BEFORE freeing its target buttons: a looping tween with
	# freed targets becomes a zero-duration loop that can hang the web build.
	if _tutorial_flash_tween != null and _tutorial_flash_tween.is_valid():
		_tutorial_flash_tween.kill()
	_tutorial_flash_tween = null
	for b in move_buttons:
		(b as Button).queue_free()
	move_buttons.clear()
	var available: float = (actor.stats as CombatantStats).oxygen
	for mv in _moves_for(actor):
		var ox_cost: float = float(mv.get("oxygen_cost", 0.0))
		# Second line: the move's effects only; details live in the tooltip.
		var effect_line := _move_effect_line(mv, actor.stats as CombatantStats)
		var b := _menu_button(String(mv.name), String(effect_line[0]), String(effect_line[1]))
		var base_power := _move_base_power(mv)
		if base_power > 0:
			_add_power_badge(b, base_power)
		if ox_cost > 0.0:
			_add_oxygen_badge(b, int(ox_cost))
		var tooltip := _move_tooltip_text(mv, actor)
		if tooltip != "":
			b.tooltip_text = tooltip
		b.disabled = available < ox_cost
		b.pressed.connect(_on_move_chosen.bind(mv))
		move_menu.add_child(b)
		move_buttons.append(b)
	# Keep the persistent scroll box after the rebuilt choices.
	move_menu.move_child(_move_scroll_box, move_menu.get_child_count() - 1)
	move_menu.move_child(back_btn, move_menu.get_child_count() - 1)
	_place_skip_tutorial_btn_last(move_menu)
	_move_scroll_offset = 0
	_apply_move_scroll()

func _moves_overflow() -> bool:
	return move_buttons.size() + 1 > MOVE_MENU_SLOTS

# Shows only the current page; hidden buttons stay in move_buttons so
# index-based callers still see every move.
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

# Pages a full window; the clamp makes the last page end on the last move.
func _scroll_moves(direction: int) -> void:
	_move_scroll_offset += direction * MOVE_MENU_VISIBLE_MOVES
	_apply_move_scroll()

# Scrolls just enough that move_buttons[index] is on screen.
func _scroll_move_into_view(index: int) -> void:
	if index < _move_scroll_offset or index >= _move_scroll_offset + MOVE_MENU_VISIBLE_MOVES:
		_move_scroll_offset = index
		_apply_move_scroll()

# Tooltip text covering every explainable effect of a move. Formula moves get
# a leading "Damage" section (_formula_damage_sentence()); legacy moves don't.
# Returns "" when there's nothing to explain.
func _move_tooltip_text(mv: Dictionary, actor: Dictionary) -> String:
	var sections: Array[String] = []
	var target_scope := String(mv.get("target", ""))
	var support_effect := String(mv.get("effect", ""))
	if support_effect == "revive":
		sections.append("Target\nOne downed ally.")
		sections.append("Revive\nBrings the ally back with %d HP." % int(mv.get("amount", 0)))
	elif support_effect == "heal":
		sections.append("Target\n%s" % ("Every living ally." if target_scope == "all_allies" else "One living ally."))
		sections.append("Heal\nRestores %d HP." % int(mv.get("amount", 0)))
	elif target_scope in ["all", "all_enemies"]:
		sections.append("Target\nAll enemies.")
	var deals_damage := mv.has("formula") and not (mv.get("formula", {}) as Dictionary).is_empty()
	if deals_damage:
		var formula: Dictionary = mv.get("formula", {})
		var damage_body := _formula_damage_sentence(String(actor.get("display_name", "the caster")), actor.stats as CombatantStats, formula, String(mv.get("target", "")))
		# Explain why formula moves with no "base" term have no power badge.
		if _move_base_power(mv) <= 0:
			var used: Array[String] = []
			for key in ["strength", "accuracy", "agility", "evasion", "defense"]:
				if formula.has(key):
					used.append(String(_STAT_ABBR.get(key, key.to_upper())))
			damage_body = "This move has no power of its own - its entire damage comes from your %s. %s" % [" and ".join(used), damage_body]
		sections.append("Damage\n%s" % damage_body)
	for effect_value in mv.get("effects", []):
		var effect := effect_value as Dictionary
		var kind := String(effect.get("kind", ""))
		if kind == "status":
			var status_name := String(effect.get("status", ""))
			var body := TutorialContent.status_condition_body(status_name)
			if body != "":
				var level := CombatRules.formula_value(actor.stats as CombatantStats, effect.get("level", {}))
				if status_name == "blindness":
					# Live-value first sentence; the rest of the shared help text follows.
					var turns := CombatRules.formula_value(actor.stats as CombatantStats, effect.get("duration", {}))
					var who := "every enemy's" if target_scope in ["all", "all_enemies"] else "the target's"
					var rest := body.substr(body.find(". ") + 2) if body.find(". ") >= 0 else ""
					body = "%s lowers %s AGI, ACC and DEF by %d for %d turns, equal to %s's ACC (%d). %s" % [
						String(mv.get("name", "This move")), who, level, turns,
						String(actor.get("display_name", "the caster")), (actor.stats as CombatantStats).effective_accuracy(), rest]
				sections.append("%s %d\n%s" % [status_name.capitalize(), level, body])
		elif kind == "self_temporary":
			# Names this move's actual ACC/EVA cost.
			sections.append("Self Cost\n%s" % _self_cost_sentence(effect))
		else:
			var explanation := TutorialContent.effect_kind_explanation(kind)
			if not explanation.is_empty():
				sections.append("%s\n%s" % [String(explanation.get("title", "")), String(explanation.get("body", ""))])
	# Legacy moves (no `formula`): explain their damage, debuff and acc_mod.
	if not mv.has("formula"):
		var debuff := String(mv.get("debuff", ""))
		if debuff == "" and support_effect == "" and mv.has("power"):
			var strength := (actor.stats as CombatantStats).strength
			sections.append("Damage\nDeals %d power plus %s's STR (%d), minus the target's DEF." % [
				int(mv.get("power", 0)), String(actor.get("display_name", "the caster")), strength,
			])
		if debuff != "":
			sections.append("Debuff\n%s lowers the target's %s by %d." % [
				String(mv.get("name", "This move")), String(_STAT_ABBR.get(debuff, debuff.to_upper())), int(mv.get("amount", 0)),
			])
		var acc_mod := int(mv.get("acc_mod", 0))
		if acc_mod != 0:
			sections.append("Accuracy\nThis move's own ACC for this one turn is %s by %d, %s." % [
				"boosted" if acc_mod > 0 else "reduced", absi(acc_mod),
				"making it much harder to dodge" if acc_mod > 0 else "making it more likely to miss",
			])
	return "\n\n".join(sections)

# Names the formula's stats with the caster's current values, e.g.
# "Maxilani's STR (1) plus ACC (3)" (a "x2" coefficient reads "2x STR (1)").
func _formula_damage_sentence(caster_name: String, caster: CombatantStats, formula: Dictionary, target: String) -> String:
	var parts: Array[String] = []
	for key in ["strength", "accuracy", "agility", "evasion", "defense"]:
		if not formula.has(key):
			continue
		var value := CombatRules.formula_value(caster, {key: 1})
		var times := int(formula[key])
		parts.append("%s%s (%d)" % ["%dx " % times if times != 1 else "", String(_STAT_ABBR.get(key, key.to_upper())), value])
	if int(formula.get("flat", 0)) != 0:
		parts.append("%d" % int(formula.flat))
	var stat_text := " plus ".join(parts) if not parts.is_empty() else "power"
	var scope_text := " to all enemies" if target == "all_enemies" else ""
	return "This move deals damage equal to %s's %s%s, minus the target's DEF." % [caster_name, stat_text, scope_text]

# Mirrors combat_moves.gd's ACC/EVA combining rule so wording matches the button.
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

# Items are party-wide, so no per-actor filtering; per-target checks happen in _on_item_chosen().
func _populate_item_menu() -> void:
	for b in item_buttons:
		(b as Button).queue_free()
	item_buttons.clear()
	var inv := _party_inventory()
	if not inv.is_empty():
		for item_id in inv.keys():
			var count: int = int(inv[item_id])
			if count <= 0:
				continue
			var def: Dictionary = Items.ITEMS.get(item_id, {})
			if String(def.get("kind", "")) == "info":
				continue   # explanatory items (Sonar Vision) have no battle use
			# Second line: just the effect ("DEF +2" in green); full text on hover.
			var effect_line := _item_effect_line(def)
			var b := _menu_button("%s (x%d)" % [String(def.get("display", item_id)), count],
				String(effect_line[0]), String(effect_line[1]))
			b.tooltip_text = String(def.get("description", ""))
			# One item per limit group per battle: Attack Tonic / Defense Shell,
			# and Focus Tonic / Slipstream Oil.
			var limit := String(def.get("battle_limit", ""))
			if limit != "" and _battle_limits_used.has(limit):
				b.disabled = true
				b.tooltip_text = String(BATTLE_LIMIT_USED_TEXT.get(limit, "Already used this battle."))
			b.pressed.connect(_on_item_chosen.bind(item_id))
			item_menu.add_child(b)
			item_buttons.append(b)
	# Keep the persistent Back button last.
	item_menu.move_child(item_back_btn, item_menu.get_child_count() - 1)
	_place_skip_tutorial_btn_last(item_menu)

# Item targets: living divers that Items.would_help(). Returns to item_menu if none.
func _on_item_chosen(item_id: String) -> void:
	if _busy:
		return
	item_menu.visible = false
	# Items only target living divers.
	var targets: Array = party.filter(func(e: Dictionary) -> bool:
		var s := e.stats as CombatantStats
		return s.hp > 0 and Items.would_help(item_id, s))
	if targets.is_empty():
		item_menu.visible = true
		call_deferred("_fit_panel_height")
		return
	_pending_item = item_id
	_populate_target_menu(targets)
	target_menu.visible = true
	call_deferred("_fit_panel_height")

# Always succeeds; mirrors _resolve_party_move()'s tail (log, bars, advance).
func _resolve_item(item_id: String, target: Dictionary) -> void:
	_busy = true
	_set_all_buttons(false)
	var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
	var kind := String(Items.ITEMS.get(item_id, {}).get("kind", ""))
	var amount := int(Items.ITEMS.get(item_id, {}).get("amount", 0))
	var was_down := (target.stats as CombatantStats).hp <= 0
	var hp_before := (target.stats as CombatantStats).hp
	var oxygen_before := (target.stats as CombatantStats).oxygen
	var msg := Items.grant(item_id, target.stats as CombatantStats)
	if was_down and (target.stats as CombatantStats).hp > 0:
		_return_to_stage(target)
	# Battle-only buffs: Items.grant() applied the stat; record it so
	# _revert_temp_buffs() removes it when the battle ends.
	var temp_field: String = {"attack_up": "strength", "defense_up": "defense", "accuracy_up": "accuracy", "evasion_up": "evasion"}.get(kind, "")
	if temp_field != "":
		var item_def: Dictionary = Items.ITEMS.get(item_id, {})
		# turns 0 = rest of the fight; timed boosts count down on the target's own
		# turns (not the turn used).
		_temp_buffs.append({"stats": target.stats, "field": temp_field, "amount": amount,
			"turns": int(item_def.get("turns", 0)), "fresh": true, "display": String(item_def.get("display", item_id))})
		var limit := String(item_def.get("battle_limit", ""))
		if limit != "":
			_battle_limits_used[limit] = true
	var inv := _party_inventory()
	var count: int = int(inv.get(item_id, 0))
	inv[item_id] = count - 1
	if inv[item_id] <= 0:
		inv.erase(item_id)
	_refresh_bar(target)
	# Same look as spells: bubbles for HP/O2, green arrows for a stat boost.
	if msg != "" and target.has("actor") and is_instance_valid(target.actor):
		var target_actor := target.actor as Node3D
		var gained_hp := (target.stats as CombatantStats).hp - hp_before
		var gained_oxygen := int(round((target.stats as CombatantStats).oxygen - oxygen_before))
		if kind == "heal" and gained_hp > 0:
			BattleFx.bubbles(_stage_vp, _fx_point(target_actor, 0.5))
			_show_floating_text(target, "+%d HP" % gained_hp, FEEDBACK_EFFECT_COLOR)
		elif kind == "oxygen" and gained_oxygen > 0:
			BattleFx.bubbles(_stage_vp, _fx_point(target_actor, 0.5))
			_show_floating_text(target, "+%d O2" % gained_oxygen, FEEDBACK_EFFECT_COLOR)
		elif temp_field != "":
			BattleFx.up_arrows(_stage_vp, _fx_point(target_actor, 1.0))
			_show_floating_text(target, String(_item_effect_line(Items.ITEMS.get(item_id, {}))[0]), STAT_COLOR_UP)
	_log(msg if msg != "" else "%s - nothing happened." % display)
	await _finish_party_turn(_acting, true)
	await get_tree().create_timer(_log_read_delay()).timeout
	_advance_turn()

# Each battle-only buff as {stats, field, amount}; one entry per use.
var _temp_buffs: Array[Dictionary] = []
# Item limit groups already used this battle (items.gd "battle_limit").
var _battle_limits_used: Dictionary = {}
const BATTLE_LIMIT_USED_TEXT := {
	"power": "Already used an Attack Tonic or Defense Shell this battle.",
	"focus": "Already used a Focus Tonic or Slipstream Oil this battle.",
}

# Counts down timed item boosts at the owner's turn end and removes expired ones.
func _tick_timed_buffs(entry: Dictionary) -> void:
	var stats := entry.get("stats") as CombatantStats
	if stats == null:
		return
	for i in range(_temp_buffs.size() - 1, -1, -1):
		var buff := _temp_buffs[i]
		if buff.stats != stats or int(buff.get("turns", 0)) <= 0:
			continue
		if bool(buff.get("fresh", false)):
			buff.fresh = false
			continue
		buff.turns = int(buff.turns) - 1
		if int(buff.turns) <= 0:
			var field := String(buff.field)
			stats.set(field, int(stats.get(field)) - int(buff.amount))
			if field == "evasion":
				stats.evasion_current = mini(stats.evasion_current, stats.effective_evasion())
			_temp_buffs.remove_at(i)
			_log_append("  %s wore off for %s." % [String(buff.get("display", "The boost")), String(entry.get("display_name", ""))])

# Called from every battle end before finished.emit(); fields are set/get dynamically.
func _revert_temp_buffs() -> void:
	# Never leave the tutorial HP floor behind.
	if _tutorial_guard:
		_set_tutorial_guard(false)
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

# Always opens a target picker (even for one target) so there's a Back.
# Heal targets hurt living allies, revive targets downed ones, everything else
# enemies. An empty pool reopens the move menu.
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
			# Living and hurt; a party-wide heal still needs at least one of them.
			targets = _living(party).filter(func(e: Dictionary) -> bool:
				var s := e.stats as CombatantStats
				return s.hp < s.hp_max)
			if String(mv.get("target", "")) == "all_allies" and not targets.is_empty():
				targets = _living(party)
		"revive":
			targets = party.filter(func(e: Dictionary) -> bool: return (e.stats as CombatantStats).hp <= 0)
		_:
			targets = _living(enemies)
			# Single-target moves can also land on the caster's fellow divers
			# (not themselves). Scripted tutorials stay enemy-only.
			if String(mv.get("target", "one_enemy")) not in ["all_enemies", "all_allies"] and not tutorial_encounter:
				targets += _living(party).filter(func(e: Dictionary) -> bool: return e != _acting)

	if targets.is_empty():
		if effect == "heal":
			_log("No one needs healing right now.")
		elif effect == "revive":
			_log("No one is down.")
		move_menu.visible = true
		call_deferred("_fit_panel_height")
		return
	_pending_move = mv
	# The yellow name + damage line appears on enemy hover (_show_move_damage_line).
	_selected_move_name.text = ""
	_selected_move_power.text = ""
	_selected_move_panel.visible = false
	if String(mv.get("target", "one_enemy")) in ["all_enemies", "all_allies"]:
		_populate_all_target_menu(targets)
	else:
		_populate_target_menu(targets)
	target_menu.visible = true
	call_deferred("_fit_panel_height")
	# Tutorial explanation for the scripted diver's forced move (stage-specific).
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

# Two beats: wait for a hover on the flashing (hover-only) enemy button, then
# show the ACC/EVA comparison and wait for Enter.
func _explain_dodging(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true

	# Tutorial fight is 1v1, so target_buttons[0] is the enemy.
	var enemy_btn := target_buttons[0] as Button
	_set_hover_only(enemy_btn, true)
	var flash := create_tween()
	flash.set_loops()
	flash.tween_property(enemy_btn, "modulate", Color(1.0, 0.85, 0.25), 0.4)
	flash.tween_property(enemy_btn, "modulate", Color.WHITE, 0.4)

	_tutorial_caption.text = "Hover over the enemy you want to attack to see the stat comparison."
	call_deferred("_fit_panel_height")

	# Await the signal directly: GDScript lambdas capture locals by value, so a
	# flag set in a closure would never end a polling loop.
	await enemy_btn.mouse_entered

	flash.kill()
	enemy_btn.modulate = Color.WHITE
	# Freeze the preview so a stray mouse_exited can't hide it mid-explanation.
	_stat_preview_frozen = true

	# Target buttons/Back stay disabled until _explain_click_to_attack().
	await _explain_evasion_reduction(enemy)
	await _explain_damage(enemy)
	await _explain_click_to_attack(enemy)

# Explains why the enemy's EVA already shows red (Electric Touch's reduce_evasion).
func _explain_evasion_reduction(enemy: Dictionary) -> void:
	var move_name := String(_pending_move.name)
	var enemy_name := String(enemy.get("display_name", "the enemy"))
	var delta := int((stat_effects.get(move_name, {}) as Dictionary).get("enemy", {}).get("evasion", 0))
	var delta_text := ("+%d" % delta) if delta > 0 else str(delta)
	await _tutorial_show_step(
		"When it connects, %s lowers %s's Evasion - that's why its EVA number is shown in [color=%s]red[/color], with the white (%s) next to it showing exactly how much. A stat shown in [color=%s]red[/color] means its total went down; a stat shown in [color=%s]green[/color] means its total went up." % [
			move_name, enemy_name, STAT_COLOR_DOWN.to_html(false), delta_text,
			STAT_COLOR_DOWN.to_html(false), STAT_COLOR_UP.to_html(false),
		],
		func() -> void:
			_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, true)
	)
	_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, false)

# Staged reveal: box the move's power, then STR/DEF and the computed total
# (_preview_damage()). Adds to the existing preview; one Enter gate at the end.
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
		"%s's own power is %d. This raw power number is shown in yellow at the top-right of its attack menu button before any stats are added. Add %s's Strength, then subtract %s's Defense (%s), and this attack would deal %d damage if it hit." % [
			move_name, base_power, attacker_name, enemy_name, _damage_math_text(_preview_raw_power(_pending_move, attacker), defender, total), total,
		]
	)
	_set_row_highlight(_selected_move_panel, false)
	_set_row_highlight(_player_stats_ui.rows.STR as PanelContainer, false)
	_set_row_highlight(_enemy_stats_ui.rows.DEF as PanelContainer, false)

# "1 - 3 = -2, but a hit always deals at least 1", built from the real stats.
func _damage_math_text(raw: int, defender: CombatantStats, total: int) -> String:
	var defense := defender.effective_defense()
	var math := "%d - %d = %d" % [raw, defense, raw - defense]
	if total == 0 and raw > 0:
		math += ", and Defense more than 5 above it blocks the hit completely"
	elif total > raw - defense:
		math += ", but a hit always deals at least 1"
	return math

# Hover-only: the button looks live and previews on hover but can't be
# activated (click/Enter/Space) until the explanation is done.
func _set_hover_only(btn: Button, hover_only: bool) -> void:
	if hover_only and not btn.has_meta("hover_only_focus"):
		btn.set_meta("hover_only_focus", btn.focus_mode)
	btn.disabled = false
	btn.button_mask = 0 if hover_only else MOUSE_BUTTON_MASK_LEFT
	if hover_only:
		btn.focus_mode = Control.FOCUS_NONE
		btn.release_focus()
	elif btn.has_meta("hover_only_focus"):
		btn.focus_mode = btn.get_meta("hover_only_focus")
		btn.remove_meta("hover_only_focus")

func _explain_click_to_attack(enemy: Dictionary, label_override: String = "") -> void:
	var enemy_btn := target_buttons[0] as Button
	var label := label_override if label_override != "" else String(enemy.get("display_name", "the enemy"))
	var flash := create_tween()
	flash.set_loops()
	flash.tween_property(enemy_btn, "modulate", Color(1.0, 0.85, 0.25), 0.4)
	flash.tween_property(enemy_btn, "modulate", Color.WHITE, 0.4)
	_tutorial_caption.text = "Click the highlighted %s to attack." % label
	call_deferred("_fit_panel_height")
	# Only the flashing button becomes clickable.
	_set_hover_only(enemy_btn, false)
	await enemy_btn.pressed
	flash.kill()
	_stat_preview_frozen = false
	_clear_stat_preview()

# Stage 1 (Musashi, Precise Tap): boxes the ACC row the acc_mod preview
# already shows green. acc_mod lasts for this one attack.
func _explain_precise_tap(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true

	var enemy_btn := target_buttons[0] as Button
	_set_hover_only(enemy_btn, true)
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
	var enemy_name := String(enemy.get("display_name", "the enemy"))
	var effective := _effective_damage_text(_pending_move, enemy.stats as CombatantStats)
	await _tutorial_show_step(
		"The yellow line above your stats shows Precise Tap and %s: the damage it will actually deal to %s. Everything is already factored in - the move's power, %s's STR and %s's DEF - so you don't have to work it out yourself. It appears whenever you hover over a target." % [
			effective, enemy_name, String(_acting.display_name), enemy_name,
		],
		func() -> void:
			_set_row_highlight(_selected_move_panel, true)
	)
	_set_row_highlight(_selected_move_panel, false)
	await _explain_click_to_attack(enemy)

# Stage 2 (Mech Pilot, Crushing Haymaker): a large hit at a large Oxygen cost;
# highlights the target's EVA pool.
func _explain_crushing_haymaker(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true
	# Pinned before the click so this swing misses (see TUTORIAL_HAYMAKER_DODGE_EVASION).
	(enemy.stats as CombatantStats).evasion_current = TUTORIAL_HAYMAKER_DODGE_EVASION

	var enemy_btn := target_buttons[0] as Button
	_set_hover_only(enemy_btn, true)
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

	var bucky_acc := (_acting.stats as CombatantStats).effective_accuracy() + int(_pending_move.get("acc_mod", 0))
	var angler_eva := (enemy.stats as CombatantStats).evasion_current
	await _tutorial_show_step(
		"If the enemy's Evasion (EVA, right panel) is greater than or equal to the attacker's Accuracy (ACC, left panel), the enemy evades and the attack misses. Here %s's Accuracy is %d and %s's Evasion is %d, so this attack will miss, shown by MISS in the middle. Each dodge spends the enemy's Evasion down by the Accuracy it beat, and it only refills at the start of that enemy's own next turn." % [
			String(_acting.get("display_name", "Bucky")), bucky_acc,
			String(enemy.get("display_name", "the enemy")), angler_eva,
		],
		func() -> void:
			_set_row_highlight(_player_stats_ui.rows.ACC as PanelContainer, true)
			_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, true)
			# Same red box as the stat rows, around the MISS sign.
			_miss_label.add_theme_stylebox_override("normal", _row_stylebox(true))
	)
	_set_row_highlight(_player_stats_ui.rows.ACC as PanelContainer, false)
	_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, false)
	_miss_label.remove_theme_stylebox_override("normal")
	await _tutorial_show_step(
		"Crushing Haymaker hits hard and costs 16 Oxygen, but Bucky's low Accuracy lets enemies dodge it while they have Evasion left. Electric Touch lowers an enemy's Evasion for the rest of the fight. Exhaust that pool first, then a heavy swing can connect.",
		func() -> void:
			_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, true)
	)
	_set_row_highlight(_enemy_stats_ui.rows.EVA as PanelContainer, false)
	await _explain_click_to_attack(enemy)

# Stage 3 (Musashi, Weaken): no damage, only lowers the enemy's DEF, so this
# boxes the enemy's DEF row.
func _explain_weaken(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true

	var enemy_btn := target_buttons[0] as Button
	_set_hover_only(enemy_btn, true)
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

# Stage 4 (Maxilani, Flash Blast): all-enemies target button; Blindness is
# previewed on the enemy's ACC/DEF rows. Points at Combat Help for other statuses.
func _explain_flash_blast(enemy: Dictionary) -> void:
	for b in target_buttons:
		(b as Button).disabled = true
	target_back_btn.disabled = true
	# Same pin; Flash Blast's accuracy still beats it.
	(enemy.stats as CombatantStats).evasion_current = TUTORIAL_HAYMAKER_DODGE_EVASION

	var enemy_btn := target_buttons[0] as Button
	_set_hover_only(enemy_btn, true)
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
		"Flash Blast deals no damage either, same as Weaken. Instead it hits every enemy at once with a status called Blindness, which lowers Agility, Accuracy, and Defense all by the same amount at once. That's why the enemy's ACC and DEF numbers are both shown in [color=%s]red[/color] here: lower Accuracy means their own attacks miss more, and lower Defense means your hits deal more damage to them. Flash Blast subtracts 2 from all three, for as many turns as %s's own Accuracy. Blindness is only one of several status conditions moves can inflict. Hover over any attack that names one on its own button (like Scuba Stabbing's Bleed) to see exactly what it does, or find full details on all of them, including ones not shown in this fight, from the Combat Help tab of the Esc menu out in the world." % [
			STAT_COLOR_DOWN.to_html(false), String(_acting.display_name),
		],
		func() -> void:
			_set_row_highlight(_enemy_stats_ui.rows.ACC as PanelContainer, true)
			_set_row_highlight(_enemy_stats_ui.rows.DEF as PanelContainer, true)
	)
	_set_row_highlight(_enemy_stats_ui.rows.ACC as PanelContainer, false)
	_set_row_highlight(_enemy_stats_ui.rows.DEF as PanelContainer, false)
	await _explain_click_to_attack(enemy, "All enemies")

# After the first move resolves: boxes party[0]'s and enemies[0]'s status cards.
func _explain_other_stats() -> void:
	var player_card: PanelContainer = (party[0].card as PanelContainer) if not party.is_empty() else null
	var enemy_card: PanelContainer = (enemies[0].card as PanelContainer) if not enemies.is_empty() else null
	# Battle-specific callout added here; the shared TutorialContent page is also shown outside fights.
	var text := "Your party's HP is shown in the highlighted purple boxes in the status panels with your party's on the top left and enemies on the top right. %s" % TutorialContent.page_body("Every Other Stat")
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
	var party_wide := String(_pending_move.get("target", "")) == "all_allies"
	var button := _menu_button("Whole party" if party_wide else "All enemies", ", ".join(names))
	button.pressed.connect(_on_all_targets_chosen.bind(targets))
	if party_wide:
		button.mouse_entered.connect(_show_heal_preview.bind(_pending_move, targets))
		button.mouse_exited.connect(_clear_support_preview)
	else:
		button.mouse_entered.connect(_show_target_cursors.bind(targets))
		button.mouse_exited.connect(_hide_target_cursors)
	if not targets.is_empty() and not party_wide:
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
	# Preview only for moves against enemies, not heal/revive.
	var previewable: bool = String(_pending_move.get("effect", "")) not in ["heal", "revive"]
	for t in targets:
		var s := t.stats as CombatantStats
		# Enemy targets show EVA and HP; ally targets the full readout.
		var hint := ("EVA %d/%d  HP %d/%d" % [s.evasion_current, s.effective_evasion(), s.hp, s.hp_max]) if String(t.kind) == "enemy" else (
			"HP %d/%d  DEF %d  EVA %d/%d  ACC %d" % [
				s.hp, s.hp_max, s.effective_defense(), s.evasion_current,
				s.effective_evasion(), s.effective_accuracy(),
			])
		var b := _menu_button(String(t.display_name), hint)
		b.pressed.connect(_on_target_chosen.bind(t))
		if _pending_item != "":
			b.mouse_entered.connect(_show_item_preview.bind(_pending_item, t))
			b.mouse_exited.connect(_clear_support_preview)
		elif not previewable:
			b.mouse_entered.connect(_show_heal_preview.bind(_pending_move, [t]))
			b.mouse_exited.connect(_clear_support_preview)
		else:
			b.mouse_entered.connect(_show_target_cursors.bind([t]))
			b.mouse_exited.connect(_hide_target_cursors)
			b.mouse_entered.connect(_show_stat_preview.bind(_pending_move, t))
			b.mouse_exited.connect(_clear_stat_preview)
		target_menu.add_child(b)
		target_buttons.append(b)
	# Keep the persistent Back button last.
	target_menu.move_child(target_back_btn, target_menu.get_child_count() - 1)
	_place_skip_tutorial_btn_last(target_menu)

# Resolve whichever of _pending_move/_pending_item is set, then clear both.
# The yellow move/damage line is a targeting aid only: gone once a move is used.
func _hide_move_damage_line() -> void:
	_selected_move_name.text = ""
	_selected_move_power.text = ""
	_selected_move_panel.visible = false

func _on_target_chosen(target: Dictionary) -> void:
	target_menu.visible = false
	_hide_target_cursors()
	_clear_support_preview()
	_clear_stat_preview()
	# Keep the move/damage line up through this attack; _advance_turn() clears it.
	_hide_move_damage_line()
	if _pending_item == "" and not _pending_move.is_empty():
		_show_move_damage_line(_pending_move, [target])
	if _uses_narrow_info_band():
		(_player_stats_ui.panel as Control).visible = false
		_turn_cursor.visible = false
	if _pending_item != "":
		var item_id := _pending_item
		_pending_item = ""
		_resolve_item(item_id, target)
		return
	_resolve_party_move(_pending_move, target)

func _on_all_targets_chosen(targets: Array) -> void:
	target_menu.visible = false
	_hide_target_cursors()
	_clear_support_preview()
	_clear_stat_preview()
	_hide_move_damage_line()
	_show_move_damage_line(_pending_move, targets)
	if _uses_narrow_info_band():
		(_player_stats_ui.panel as Control).visible = false
		_turn_cursor.visible = false
	var move := _pending_move
	_pending_move = {}
	_resolve_party_move_all(move, targets)

# Nothing has been spent yet, so backing out is free. Returns to the item or
# move menu depending on what is pending.
func _show_moves_or_items_from_target_menu() -> void:
	if _busy:
		return
	target_menu.visible = false
	_hide_target_cursors()
	_clear_support_preview()
	_clear_stat_preview()
	if _pending_item != "":
		_pending_item = ""
		item_menu.visible = true
	else:
		_pending_move = {}
		move_menu.visible = true
	call_deferred("_fit_panel_height")

# One roll for both sides; stats make them differ.
#  1. Hit/miss: accuracy + acc_mod vs evasion, strictly greater wins. No RNG.
#  2. Power + strength with variance (the only randomness).
#  3. Defense subtracts flat; can floor a hit at 0.
func _resolve_attack(attacker: CombatantStats, defender: CombatantStats, move: Dictionary) -> Dictionary:
	if move.has("formula"):
		# Formula enemy moves still get the QTE window, but only if they beat
		# ACC/EVA; CombatRules owns the miss and Evasion spend.
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

	# Keep the RNG call order: variance before the heavy fraction and QTE roll.
	var variance := randf_range(0.85, 1.15)
	var heavy_fraction := 0.0
	if String(move.get("effect", "")) == "heavy":
		heavy_fraction = randf_range(float(move.get("heavy_min", 0.25)), float(move.get("heavy_max", 0.5)))

	# Independent ENEMY_QTE_CHANCE roll for quick_time_bool moves (enemy only);
	# a successful dodge zeroes damage. _tutorial_force_next_qte forces it and is
	# consumed here unconditionally.
	var force_qte := _tutorial_force_next_qte
	_tutorial_force_next_qte = false
	var player_dodge := false
	if bool(move.get("quick_time_bool", false)) and (force_qte or randf() < ENEMY_QTE_CHANCE):
		# Organic QTEs get an Enter-gated warning first; the forced tutorial swing
		# already had its own explanation.
		if not force_qte:
			await _tutorial_show_step("The enemy's attack triggers a quick time event! Be prepared to time a dodge.")
			_tutorial_caption.visible = false
			call_deferred("_fit_panel_height")
		player_dodge = await _quick_time_event(_actor_for_stats(defender))

	return apply_damage_roll(attacker, defender, move, variance, heavy_fraction, player_dodge)

# Deterministic half of _resolve_attack(), shared with verify/balance.gd so
# tests use the real combat math. Callers supply variance/heavy/QTE inputs.
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

# Dispatches on "effect": heal/revive target an ally and always succeed;
# everything else resolves as an attack/debuff.
func _resolve_move(attacker: CombatantStats, defender: CombatantStats, move: Dictionary) -> Dictionary:
	var effect := String(move.get("effect", ""))
	if effect == "heal":
		return _apply_heal(defender, int(move.get("amount", 0)))
	if effect == "revive":
		return _apply_revive(defender, int(move.get("amount", 0)))
	return await _resolve_attack(attacker, defender, move)

# Restores flat `amount` HP up to hp_max (living allies only).
func _apply_heal(target: CombatantStats, amount: int) -> Dictionary:
	var before := target.hp
	target.hp = mini(target.hp_max, target.hp + amount)
	var changed := target.hp - before
	return {"hit": true, "damage": 0, "absorbed": 0, "debuff": "heal", "changed": changed}

# A revived party member: a fresh fighter in their spot.
func _return_to_stage(entry: Dictionary) -> void:
	if String(entry.get("kind", "")) != "party" or _stage_vp == null:
		return
	var old: Node3D = entry.get("actor")
	var actor := Diver.new()
	actor.model_name = String(entry.model_name)
	actor.position = entry.get("home_pos", old.position if old != null and is_instance_valid(old) else Vector3.ZERO)
	actor.rotation.y = float(entry.get("home_rot", 0.0))
	if old != null and is_instance_valid(old):
		old.queue_free()
	_stage_vp.add_child(actor)
	entry["actor"] = actor

func _apply_revive(target: CombatantStats, amount: int) -> Dictionary:
	target.hp = mini(target.hp_max, amount)
	return {"hit": true, "damage": 0, "absorbed": 0, "debuff": "revive", "changed": target.hp}

# Mutates the target's stats (safe: enemies are rebuilt, party stats reset on
# level-up). Floors at stat_floor (an enemy's unboosted base) or the flat
# minimums (0, agility 1). `changed` is how much actually moved.
func _apply_debuff(defender: CombatantStats, debuff: String, amount: int) -> Dictionary:
	if defender.immune_to_stat_loss:
		return {"hit": true, "damage": 0, "absorbed": 0, "debuff": "", "changed": 0, "immune": true}
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
			# Takes effect now, not only after the target's pool refills.
			defender.evasion_current = mini(defender.evasion_current, defender.effective_evasion())
	return {"hit": true, "damage": 0, "absorbed": 0, "debuff": debuff, "changed": changed}

# Appended to the move's log line: "... - Tethys is immune to Weaken."
func _log_immunity(target: Dictionary, mv: Dictionary) -> void:
	_log_append("  %s is immune to %s." % [String(target.display_name), String(mv.get("name", "that move"))])

func _log_player_result(actor: Dictionary, target: Dictionary, mv: Dictionary, r: Dictionary) -> void:
	var text: String = String(mv.get("text", "You use %s" % String(mv.name)))
	# Immune to a stat-lowering move: never print its "defense drops" flavor;
	# _log_immunity() appends "<Boss> is immune to <Move>."
	if bool(r.get("immune", false)) and String(mv.get("debuff", "")) != "":
		_log("You use %s on %s." % [String(mv.name), String(target.display_name)])
		return
	if not r.hit:
		# Stat-lowering flavor ("agility drops") only plays when the move lands.
		var lowers_on_hit := String(mv.get("debuff", "")) != "" or (mv.get("effects", []) as Array).any(
			func(e: Variant) -> bool: return String((e as Dictionary).get("kind", "")) in ["status", "reduce_evasion"])
		if lowers_on_hit:
			_log("You use %s, but %s evades!" % [String(mv.name), String(target.display_name)])
		else:
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
			_log("You use %s on %s - %s -0, it can't go any lower." % [
				String(mv.name), String(target.display_name), String(_STAT_ABBR.get(String(r.debuff), String(r.debuff).to_upper()))])
		return
	_log("%s for %d." % [text, int(r.damage)])
	var effects := r.get("effects", []) as Array
	if not effects.is_empty():
		# Effects in red right after the hit line.
		log_label.add_text("  ")
		log_label.push_color(Color.html(CombatRules.STAT_LOSS_COLOR))
		log_label.add_text(", ".join(effects))
		log_label.pop()
		call_deferred("_fit_panel_height")

# Step in, face the target, swing, step back. Returns at the impact frame so
# the rest of the clip plays under the damage log. No actor = instant.
# Swings travel along the character's forward axis, so the character is aimed.
func _swing(entry: Dictionary, mv: Dictionary, target: Dictionary = {}) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor) or not (entry.actor is Diver):
		return
	var d := entry.actor as Diver
	# Support casts face the ally and cast in place (stepping in would overlap the row).
	var in_place := String(mv.get("effect", "")) in ["heal", "revive"]
	# Offensive gestures approach from the target's camera-facing flank.
	var clip_stem := Cast.ability(String(entry.model_name), String(mv.get("name", "")))
	var delivered := d.resolve(clip_stem).begins_with("spells/")
	await _step_toward(entry, target, in_place, delivered and not in_place)
	var length: float = d.play_clip(clip_stem)
	if length <= 0.0:
		_send_home(entry, 0.0)
		return
	if String(d.anim.current_animation).begins_with("spells/"):
		d.framing_clip = String(d.anim.current_animation)
		# Hide the cursor during the clip; restored on the next usable turn.
		_turn_cursor.visible = false
		_frame_stage_camera()
	if target.has("actor") and is_instance_valid(target.actor) and target.actor is Node3D:
		player_swing_staged.emit(d, target.actor as Node3D)
	_audio_call(&"play_combat_swing", [_move_is_heavy(mv)])
	await get_tree().create_timer(length * IMPACT_FRACTION).timeout
	# The rest of the clip plays under the damage log; walk back when it ends.
	_send_home(entry, length * (1.0 - IMPACT_FRACTION))

# Face the target and stop SWING_REACH short so the swing doesn't pass through it.
func _step_toward(entry: Dictionary, target: Dictionary, face_only: bool = false, camera_flank: bool = false) -> void:
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
	# Divers face local -Z, Angler local +Z; the actor owns this.
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
	if camera_flank and _stage_cam != null:
		var flank := _stage_cam.global_position - (target.actor as Node3D).global_position
		flank.y = 0.0
		if flank.length_squared() > 0.01:
			stand = (target.actor as Node3D).position + flank.normalized() * (SWING_REACH + target_radius)
			var facing := (target.actor as Node3D).position - stand
			a.rotation.y = atan2(-facing.x, -facing.z)
	stand.y = home.y
	var step := a.create_tween()
	step.tween_property(a, "position", stand, SWING_STEP_TIME)
	await step.finished

# Always return to the stored home so interrupted swings can't drift.
func _send_home(entry: Dictionary, delay: float) -> void:
	entry["home_at_ms"] = Time.get_ticks_msec() + int((maxf(delay, 0.0) + SWING_STEP_TIME) * 1000.0)
	# Read through Variant: assigning a freed Object to a typed local throws before is_instance_valid().
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

# Hit recoil, only for landed damage (not heals).
func _react(entry: Dictionary, r: Dictionary) -> void:
	if not bool(r.get("hit", false)) or int(r.get("damage", 0)) <= 0:
		return
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	if (entry.stats as CombatantStats).hp <= 0:
		return   # going down has its own animation, see play_death_fade()
	# Heavy reaction for a hit of at least a fifth of max HP.
	var heavy: bool = float(r.damage) >= float((entry.stats as CombatantStats).hp_max) * 0.2
	if entry.actor is Diver:
		(entry.actor as Diver).play_hit_reaction(heavy)
	elif entry.actor is TethysBoss:
		(entry.actor as TethysBoss).play_hit_reaction(heavy)
	elif entry.actor is CampaignCordys:
		(entry.actor as CampaignCordys).play_hit_reaction(heavy)
	elif prologue_octopus_encounter and entry.actor.has_method("play"):
		entry.actor.call("play", "hurt")

func _play_enemy_death(entry: Dictionary) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	if entry.actor is Goblin:
		(entry.actor as Goblin).play_death_fade()
	elif entry.actor is TethysBoss:
		(entry.actor as TethysBoss).play_death()
	elif entry.actor is CampaignCordys:
		(entry.actor as CampaignCordys).play_death()

func _play_enemy_hit(entry: Dictionary) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	# Tethys already reacted in _react(); Angler plays its damaged clip.
	if entry.actor is Goblin:
		(entry.actor as Goblin).play("hurt")

func _restore_enemy_idle(entry: Dictionary) -> void:
	if not entry.has("actor") or not is_instance_valid(entry.actor):
		return
	if entry.actor is Goblin:
		(entry.actor as Goblin).play("idle")
	elif entry.actor is TethysBoss:
		(entry.actor as TethysBoss).play("idle")
	elif (prologue_octopus_encounter or encounter_source == "maze_cordys") and entry.actor.has_method("play"):
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
	if target.get("actor") is Goblin:
		(target.actor as Goblin).record_damage_taken(_acting.actor, int(r.get("damage", 0)))
	_react(target, r)
	_show_combat_feedback(target, r)
	var applied_effects := r.get("effects", []) as Array
	if r.hit and (String(r.debuff) == "agility" or applied_effects.any(func(effect: Variant) -> bool: return String(effect).begins_with("Blindness"))):
		_resort_pending()
	_refresh_bar(target)
	_refresh_bar(_acting)
	# Refresh the player panel so self_temporary costs are visible.
	_refresh_player_stats_panel()
	_log_player_result(_acting, target, mv, r)
	if bool(r.get("immune", false)):
		_log_immunity(target, mv)
	if prologue_octopus_encounter:
		print("PROLOGUE_HIT|move=%s|damage=%d|hit=%s|hp=%d|effects=%s" % [String(mv.name), int(r.damage), str(r.hit), (target.stats as CombatantStats).hp, str(r.get("effects", []))])
		_audio_call(&"duck_music", [-7.0, 0.25])
		_finish_actor_turn(_acting)
		await _resolve_prologue_finisher()
		return

	# A killing blow plays the fade instead of a hit reaction. Revived actors were
	# already restored by _show_combat_feedback().
	var target_died: bool = target.has("stats") and (target.stats as CombatantStats).hp <= 0
	if target_died:
		if target.get("actor") is Diver:
			(target.actor as Diver).play_death_fade()
		else:
			_play_enemy_death(target)
	elif r.hit and String(r.debuff) == "":
		_play_enemy_hit(target)
	await _finish_party_turn(_acting)
	# Only the scripted diver's turn advances the script. Let the result line be
	# read before the HP explanation.
	var result_read := false
	if _is_tutorial_scripted_turn(_acting):
		if _tutorial_step == 0:
			await get_tree().create_timer(_log_read_delay()).timeout
			result_read = true
			await _explain_other_stats()
		_tutorial_step += 1
	if not result_read:
		await get_tree().create_timer(_log_read_delay()).timeout
	await _wait_for_delivered_cast(_acting)
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
	# All-target moves step toward the first target.
	await _swing(_acting, mv, targets[0] as Dictionary)
	var summaries: Array[String] = []
	var immune_targets: Array = []
	var first := true
	var changed_agility := false
	var party_heal := String(mv.get("effect", "")) == "heal"
	for target in targets:
		if (target.stats as CombatantStats).hp <= 0:
			continue
		if party_heal:
			var healed := _apply_heal(target.stats as CombatantStats, int(mv.get("amount", 0)))
			_show_combat_feedback(target, healed)
			_refresh_bar(target)
			summaries.append(("%s +%d HP" % [String(target.display_name), int(healed.changed)]) if int(healed.changed) > 0 else "%s already full" % String(target.display_name))
			continue
		var result := CombatRules.resolve(_acting.stats as CombatantStats, target.stats as CombatantStats, mv, first)
		if target.get("actor") is Goblin:
			(target.actor as Goblin).record_damage_taken(_acting.actor, int(result.get("damage", 0)))
		if prologue_octopus_encounter:
			print("PROLOGUE_HIT|move=%s|damage=%d|hit=%s|hp=%d|effects=%s" % [String(mv.name), int(result.damage), str(result.hit), (target.stats as CombatantStats).hp, str(result.get("effects", []))])
		first = false
		changed_agility = changed_agility or (result.get("effects", []) as Array).any(
			func(effect: Variant) -> bool: return String(effect).begins_with("Blindness"))
		_react(target, result)
		_show_combat_feedback(target, result)
		_refresh_bar(target)
		if bool(result.get("immune", false)):
			immune_targets.append(target)
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
	for target in immune_targets:
		_log_immunity(target, mv)
	_refresh_bar(_acting)
	# Refresh the player panel so self_temporary costs are visible.
	_refresh_player_stats_panel()
	await _finish_party_turn(_acting)
	if prologue_octopus_encounter:
		_audio_call(&"duck_music", [-7.0, 0.25])
		await _resolve_prologue_finisher()
		return
	# Same scripted-turn guard and read delay as _resolve_party_move().
	var result_read := false
	if _is_tutorial_scripted_turn(_acting):
		if _tutorial_step == 0:
			await get_tree().create_timer(_log_read_delay()).timeout
			result_read = true
			await _explain_other_stats()
		_tutorial_step += 1
	if not result_read:
		await get_tree().create_timer(_log_read_delay()).timeout
	await _wait_for_delivered_cast(_acting)
	_advance_turn()

func _wait_for_delivered_cast(entry: Dictionary) -> void:
	var actor_value: Variant = entry.get("actor")
	if actor_value == null or not is_instance_valid(actor_value) or not actor_value is Diver:
		return
	var actor := actor_value as Diver
	var clip := String(actor.anim.current_animation)
	# Let longer spell casts finish before the next turn.
	if clip.begins_with("spells/") and actor.anim.is_playing():
		var remaining := maxf(0.0, actor.anim.get_animation(clip).length - actor.anim.current_animation_position)
		await get_tree().create_timer(remaining / maxf(0.01, actor.anim.speed_scale) + SWING_STEP_TIME).timeout
	if not actor.framing_clip.is_empty():
		actor.framing_clip = ""
		_frame_stage_camera()

# True when Bleed + Poison finish this diver at the end of their next turn.
static func doomed_by_damage_over_time(stats: CombatantStats) -> bool:
	var pending := stats.status_level("bleed") + stats.status_level("poison")
	return pending > 0 and stats.hp <= pending

# Exact damage `combat` (a formula move) would land now, mirroring
# CombatRules.resolve() hit by hit (Evasion pool, first-hit self cost, on-hit
# Defense Down). -1 for unpredictable moves (legacy variance, QTE moves).
static func predicted_landed_damage(attacker: CombatantStats, defender: CombatantStats, combat: Dictionary) -> int:
	if not combat.has("formula") or bool(combat.get("quick_time_bool", false)):
		return -1
	var raw := CombatRules.formula_value(attacker, combat.get("formula", {}))
	if raw <= 0:
		return 0
	var accuracy := attacker.effective_accuracy() + int(combat.get("acc_mod", 0))
	var self_accuracy := 0
	var defense_cut := 0
	for effect_value in combat.get("effects", []):
		var effect := effect_value as Dictionary
		if String(effect.get("kind", "")) == "self_temporary":
			self_accuracy += int(effect.get("accuracy", 0))
		elif String(effect.get("kind", "")) == "status" and String(effect.get("status", "")) == "defense_down":
			defense_cut = maxi(defense_cut, CombatRules.formula_value(attacker, effect.get("level", {})))
	var pool := defender.evasion_current
	var defense := defender.effective_defense()
	var cut_applied := defender.status_level("defense_down") >= defense_cut
	var total := 0
	for hit_index in range(maxi(1, int(combat.get("hits", 1)))):
		if accuracy <= pool:
			pool -= mini(pool, accuracy)
		else:
			total += 0 if defense - raw > 5 else maxi(1, raw - defense)
			if not cut_applied and defense_cut > 0:
				defense = maxi(0, defense - (defense_cut - defender.status_level("defense_down")))
				cut_applied = true
		if hit_index == 0:
			accuracy += self_accuracy
	return total

# A guaranteed kill on a living, non-doomed diver, or {}. Prefers the widest
# Evasion margin, then the lowest-HP target.
static func lethal_enemy_choice(attacker: CombatantStats, moves: Array, alive_party: Array) -> Dictionary:
	var best := {}
	var best_margin := -INF
	var best_hp := 0
	for entry_value in alive_party:
		var entry := entry_value as Dictionary
		var stats := entry.stats as CombatantStats
		if stats.hp <= 0 or doomed_by_damage_over_time(stats):
			continue
		for move_value in moves:
			var move := move_value as Dictionary
			if not bool(move.get("enabled", true)):
				continue
			var combat := move.get("combat", {}) as Dictionary
			if predicted_landed_damage(attacker, stats, combat) < stats.hp:
				continue
			var margin := float(attacker.effective_accuracy() + int(combat.get("acc_mod", 0)) - stats.evasion_current)
			if margin > best_margin or (margin == best_margin and stats.hp < best_hp):
				best = {"move": move.duplicate(true), "target": entry}
				best_margin = margin
				best_hp = stats.hp
	return best

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
	var boss := actor.actor as Node3D
	var move := boss.call("next_move", actor.stats) as Dictionary
	if String(move.get("effect", "")) == "self_heal":
		await _do_boss_self_heal(actor, boss, move)
		return
	var primary: Dictionary = _pick_enemy_target(alive_party)
	var targets: Array = alive_party if String(move.get("target", "single")) == "all" else [primary]

	# Tethys stays planted but turns toward the party.
	var to: Vector3 = (primary.actor as Node3D).position - boss.position
	to.y = 0.0
	if to.length() > 0.05:
		boss.call("face_toward", (primary.actor as Node3D).global_position)
	if boss is CampaignCordys:
		(boss as CampaignCordys).set_framing_clip(String(move.clip))
		_frame_stage_camera()
		_log("Cordys prepares %s." % String(move.name))
		await get_tree().create_timer(0.65).timeout
	var length := float(boss.call("play_attack", move))
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
				var poison_turns := int(move.get("poison_turns", 3))
				effects.append("Poison %d (%d %s left)" % [poison_level, poison_turns, "turn" if poison_turns == 1 else "turns"])
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

	_log_enemy_damage("%s uses %s: %s." % [String(actor.display_name), String(move.name), "; ".join(summaries)])
	_finish_actor_turn(actor)
	await get_tree().create_timer(_log_read_delay()).timeout
	if is_instance_valid(boss):
		boss.call("play", "idle")
		if boss is CampaignCordys:
			(boss as CampaignCordys).set_framing_clip("")
			_frame_stage_camera()
	_advance_turn()

# Boss self-heal: restores heal_fraction of max HP and removes Bleed, then ends the turn.
func _do_boss_self_heal(actor: Dictionary, boss: Node3D, move: Dictionary) -> void:
	var stats := actor.stats as CombatantStats
	var boss_name := String(actor.display_name)
	if boss is CampaignCordys:
		(boss as CampaignCordys).set_framing_clip(String(move.clip))
		_frame_stage_camera()
	_log("%s prepares %s." % [boss_name, String(move.name)])
	var length := float(boss.call("play_attack", move))
	await get_tree().create_timer(maxf(0.6, length * IMPACT_FRACTION)).timeout

	var before := stats.hp
	var amount := maxi(1, roundi(float(stats.hp_max) * float(move.get("heal_fraction", 0.1))))
	stats.hp = mini(stats.hp_max, stats.hp + amount)
	var healed := stats.hp - before
	var cured_bleed := stats.status_level("bleed") > 0
	stats.statuses.erase("bleed")
	_refresh_bar(actor)
	if healed > 0:
		_show_floating_text(actor, "+%d HP" % healed, FEEDBACK_EFFECT_COLOR)
		BattleFx.bubbles(_stage_vp, _fx_point(boss, 0.5))
	if cured_bleed:
		_show_floating_text(actor, "BLEED CURED", FEEDBACK_EFFECT_COLOR, 1)
	var heal_text := ("recovers %d HP" % healed) if healed > 0 else "is already at full health"
	var bleed_text := " and stops the bleeding" if cured_bleed else ""
	_log("%s uses %s: %s%s." % [boss_name, String(move.name), heal_text, bleed_text])

	_finish_actor_turn(actor)
	await get_tree().create_timer(_log_read_delay()).timeout
	if is_instance_valid(boss):
		boss.call("play", "idle")
		if boss is CampaignCordys:
			(boss as CampaignCordys).set_framing_clip("")
			_frame_stage_camera()
	_advance_turn()

func _do_enemy_turn(actor: Dictionary, forced_target: Dictionary = {}) -> void:
	_hide_move_damage_line()
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
	if actor.actor is TethysBoss or actor.actor is CampaignCordys:
		await _do_boss_turn(actor, alive_party)
		return
	# Use the tutorial's pre-narrated target; re-rolling could pick someone else.
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
	var scripted_turn := not forced_target.is_empty() or tutorial_encounter or prologue_angler_encounter
	# Outside scripted fights: take a guaranteed kill, never target a DoT-doomed diver.
	var lethal := {} if scripted_turn else lethal_enemy_choice(actor.stats as CombatantStats, enemy_actor.available_moves(), alive_party)
	var decision: Dictionary
	if not lethal.is_empty():
		decision = lethal
	else:
		var candidates := alive_party
		if not scripted_turn:
			var not_doomed := alive_party.filter(func(e: Dictionary) -> bool: return not doomed_by_damage_over_time(e.stats as CombatantStats))
			if not not_doomed.is_empty():
				candidates = not_doomed
				if not candidates.has(target):
					target = _pick_enemy_target(candidates)
		decision = enemy_actor.choose_move_and_target(actor.stats as CombatantStats, candidates, target, scripted_turn)
	var move := decision.move as Dictionary
	target = decision.target as Dictionary
	target_stats = target.stats as CombatantStats
	# Forced-QTE turn: use a single-target move so the flag isn't consumed on another diver.
	if _tutorial_force_next_qte:
		for candidate_value in enemy_actor.available_moves():
			var candidate := candidate_value as Dictionary
			if String(candidate.get("target", "single")) == "single":
				move = candidate
				break
	if move.is_empty():
		_log("%s has no enabled attack." % String(actor.display_name))
		_finish_actor_turn(actor)
		await get_tree().create_timer(_log_read_delay()).timeout
		_advance_turn()
		return
	await _step_toward(actor, target)
	# Step into range first, then play the move clip through its impact frame.
	var attack_length := enemy_actor.play_move(move)
	_audio_call(&"play_combat_swing", [_move_is_heavy(move.get("combat", {}) as Dictionary)])
	if attack_length > 0.0:
		await get_tree().create_timer(attack_length * IMPACT_FRACTION).timeout
	var combat_move := move.combat as Dictionary
	# The forced QTE also needs quick_time_bool on the move; set it on a duplicate
	# so the shared content entry isn't mutated.
	if _tutorial_force_next_qte:
		combat_move = combat_move.duplicate()
		combat_move["quick_time_bool"] = true
	var resolved_targets := enemy_targets_for_scope(target, alive_party, String(move.get("target", "single")))
	var result_rows: Array[String] = []
	var apply_self_effects := true
	for target_value in resolved_targets:
		var resolved_target := target_value as Dictionary
		var results: Array
		# QTE-capable formula moves use the async resolver so the timing window decides the hit.
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
			if String(move.get("id", "")) == "bite":
				enemy_actor.record_bite_result(bool(result.get("hit", false)) and not bool(result.get("dodged", false)))
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
	_log_enemy_damage("%s uses %s: %s." % [String(actor.display_name), String(move.get("name", "Attack")), "; ".join(result_rows)])
	_finish_actor_turn(actor)
	await get_tree().create_timer(_log_read_delay()).timeout
	_restore_enemy_idle(actor)
	_advance_turn()

func _look_at_dodge_angle(target_pos: Vector3) -> void:
	_stage_cam.global_position = target_pos + Vector3(3.0, 3.5, 2.0)
	_stage_cam.look_at(target_pos, Vector3.UP)

func _look_at_swap_angle(target_pos: Vector3, enemy_pos: Vector3) -> void:
	var midpoint := (target_pos + enemy_pos) * 0.5
	# Far and narrow FOV so portraits keep a steady size across their lane.
	_stage_cam.global_position = midpoint + Vector3(0.0, 17.5, 17.5)
	_stage_cam.fov = 40.0
	_stage_cam.look_at(midpoint, Vector3.UP)

func _restore_stage_camera() -> void:
	_stage_cam.fov = 70.0
	_frame_stage_camera()

# Minigame impacts are true damage: the skill test already decided the hit.
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

# Fixed damage per hit (Bucky's rocks/walls: 2, Maxilani's portraits: 1).
func _apply_flat_special_impact(target: Dictionary, amount: int) -> Dictionary:
	var defender := target.stats as CombatantStats
	defender.hp = maxi(0, defender.hp - amount)
	var result := {
		"hit": true, "damage": amount, "absorbed": 0,
		"debuff": "", "changed": 0, "dodged": false, "effects": [],
	}
	_refresh_bar(target)
	_react(target, result)
	_show_combat_feedback(target, result)
	return result

# `flawless` (perfect minigame run) skips the closing attack entirely.
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
	# Bucky's minigame was the last; the tutorial is real from here.
	if _tutorial_guard and _tutorial_enemy_turns >= 3:
		_set_tutorial_guard(false)
	_finish_actor_turn(actor)
	await get_tree().create_timer(_log_read_delay()).timeout
	# Special tutorial: hand off to the next diver after each teaching turn.
	if tutorial_encounter and special_encounter and target_stats.hp > 0:
		if _tutorial_enemy_turns == 1:
			await _swap_tutorial_special_diver("Prototype_1(1910)", "Now let's explore Musashi's minigame.")
			return
		elif _tutorial_enemy_turns == 2:
			await _swap_tutorial_special_diver("Prototype_V(1922)", "Now let's explore Bucky's minigame.")
			return
	_advance_turn()

# Special tutorial hand-off: replaces the solo party slot with the real diver
# `new_model_name` and gives them the next turn immediately.
func _swap_tutorial_special_diver(new_model_name: String, intro_caption: String) -> void:
	_set_all_buttons(false)
	await _tutorial_show_step(intro_caption)
	var entry: Dictionary = party[0]
	var rest_pos: Vector3 = entry.get("home_pos", Vector3.ZERO)
	var rest_rot: float = float(entry.get("home_rot", 0.0))
	if entry.has("actor") and is_instance_valid(entry.actor):
		# Instant removal (a death fade would read wrong).
		(entry.actor as Node3D).queue_free()
	var new_diver: Diver = null
	for d in world.divers:
		if String((d as Diver).model_name) == new_model_name:
			new_diver = d as Diver
			break
	# Each incoming diver starts at full HP/Oxygen (also avoids a hp<=0 diver with no actor).
	new_diver.stats.hp = new_diver.stats.hp_max
	new_diver.stats.oxygen = new_diver.stats.oxygen_max
	var new_actor := Diver.new()
	new_actor.model_name = new_model_name
	new_actor.position = rest_pos
	_stage_vp.add_child(new_actor)
	new_actor.rotation.y = rest_rot
	# Mutate `entry` in place: other code holds references and it owns the slot's status card.
	if _tutorial_guard:
		(entry["stats"] as CombatantStats).min_hp = 0
		new_diver.stats.min_hp = 1
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
	# Enemy acts next regardless of agility (only forced below Maxilani's).
	_queue = [enemies[0]]
	await _tutorial_show_step("Continue fighting the enemy")
	# Clear the caption before handing control back.
	_tutorial_caption.text = ""
	_tutorial_caption.visible = false
	call_deferred("_fit_panel_height")
	# _acting must be the new diver before _start_party_turn().
	_acting = entry
	_start_party_turn(entry)

func _do_grapple_intercept_encounter(actor: Dictionary, target: Dictionary, _target_stats: CombatantStats) -> void:
	# The safe color is announced per wave; this line states the objective.
	_log_rich("%s launches a colored vortex. Aim with the mouse and %s to grapple the instructed color before it reaches you!" % [String(actor.display_name), Slot._badge("Left click")])
	await get_tree().create_timer(_log_read_delay()).timeout
	var minigame := GrappleInterceptMinigame.new()
	minigame.stage_root = _stage_vp
	minigame.stage_camera = _stage_cam
	minigame.target_actor = target.actor
	minigame.enemy_actor = actor.actor
	minigame.source_position = (actor.actor as Node3D).global_position + Vector3.UP * (actor.actor as Goblin).height
	# The minigame's 2D frame must match the stage's render rect.
	if _stage_container != null:
		minigame.stage_rect = Rect2(_stage_container.position, _stage_container.size)
	add_child(minigame)
	# Array, not int: lambdas capture locals by value.
	var total_taken := [0]
	minigame.object_hit.connect(func() -> void:
		var result := _apply_special_impact(actor.stats, target)
		total_taken[0] += int(result.damage)
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
	_log("%s clears %d/%d vortex targets%s" % [String(target.display_name), int(score[0]), int(score[1]), " without damage." if int(total_taken[0]) == 0 else " and takes %d damage." % int(total_taken[0])])
	await get_tree().create_timer(0.45).timeout
	# A flawless run skips the follow-up attack.
	await _finish_special_enemy_turn(actor, target, int(score[0]) >= int(score[1]))

# Damage per rock or wall that reaches Bucky.
const ROCK_DODGE_HIT_DAMAGE := 2
# Damage per portrait landing in the wrong lane (empty lanes don't count).
const SWAP_PORTRAIT_MISS_DAMAGE := 1

static func reward_claim_text(item_id: String) -> String:
	var display := String(Items.ITEMS.get(item_id, {}).get("display", item_id))
	if Items.is_key_item(item_id):
		return "Victory - you claim the key item %s!" % display
	var article := "an" if display.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"
	return "Victory - you claim %s %s!" % [article, display]

func _do_rock_dodge_encounter(actor: Dictionary, target: Dictionary, _target_stats: CombatantStats) -> void:
	# Control hint in the log line, like the other minigames.
	_log_rich("%s hurls rocks and walls at %s! %s/%s to move lanes, %s to shockwave a rock when it arrives in your lane - one shockwave per wave." % [String(actor.display_name), String(target.display_name), Slot._badge("Left"), Slot._badge("Right"), Slot._badge("E")])
	_audio_call(&"play_shockwave")
	await get_tree().create_timer(_log_read_delay()).timeout
	_look_at_dodge_angle((target.actor as Node3D).global_position)
	var minigame := RockDodgeMinigame.new()
	minigame.thrower_position = (actor.actor as Node3D).global_position + Vector3.UP * (actor.actor as Goblin).height
	minigame.stage_root = _stage_vp
	minigame.target_actor = target.actor
	add_child(minigame)
	# Array, not int: lambdas capture locals by value.
	var total_taken := [0]
	minigame.rock_landed.connect(func() -> void:
		var result := _apply_flat_special_impact(target, ROCK_DODGE_HIT_DAMAGE)
		total_taken[0] += int(result.damage)
		if (target.stats as CombatantStats).hp <= 0:
			minigame.request_abort()
	)
	minigame.run()
	var score: Array = await minigame.finished
	minigame.queue_free()
	# The minigame's return tween isn't awaited; snap to home to avoid the race.
	if target.has("actor") and is_instance_valid(target.actor):
		var target_node := target.actor as Node3D
		target_node.global_position = target.get("home_pos", target_node.global_position)
		target_node.rotation.y = float(target.get("home_rot", target_node.rotation.y))
	_restore_stage_camera()
	_log("%s breaks %d/%d threats%s" % [String(target.display_name), int(score[0]), int(score[1]), " without damage." if int(total_taken[0]) == 0 else " and takes %d damage." % int(total_taken[0])])
	await get_tree().create_timer(0.45).timeout
	# A flawless run skips the follow-up attack.
	await _finish_special_enemy_turn(actor, target, int(score[0]) >= int(score[1]))

func _do_swap_minigame(actor: Dictionary, target: Dictionary, _target_stats: CombatantStats) -> void:
	# Control hint in the log line.
	_log_rich("%s scrambles the diver portraits! %s/%s to aim, %s to swap into that spot." % [String(actor.display_name), Slot._badge("Left"), Slot._badge("Right"), Slot._badge("E")])
	await get_tree().create_timer(_log_read_delay()).timeout
	_look_at_swap_angle((target.actor as Node3D).global_position, (actor.actor as Node3D).global_position)
	var minigame := DiverSwapMinigame.new()
	minigame.stage_root = _stage_vp
	minigame.target_actor = target.actor
	minigame.enemy_actor = actor.actor
	add_child(minigame)
	# Array, not int: lambdas capture locals by value.
	var total_taken := [0]
	minigame.portrait_landed.connect(func() -> void:
		var result := _apply_flat_special_impact(target, SWAP_PORTRAIT_MISS_DAMAGE)
		total_taken[0] += int(result.damage)
		if (target.stats as CombatantStats).hp <= 0:
			minigame.request_abort()
	)
	minigame.run()
	var score: Array = await minigame.finished
	minigame.queue_free()
	# The minigame's return tween isn't awaited; snap to home before reframing.
	if target.has("actor") and is_instance_valid(target.actor):
		var target_node := target.actor as Node3D
		target_node.global_position = target.get("home_pos", target_node.global_position)
		target_node.rotation.y = float(target.get("home_rot", target_node.rotation.y))
	_restore_stage_camera()
	_log("%s matches %d/%d portraits%s" % [String(target.display_name), int(score[0]), int(score[1]), " without damage." if int(total_taken[0]) == 0 else " and takes %d damage." % int(total_taken[0])])
	await get_tree().create_timer(0.45).timeout
	# A flawless run skips the follow-up attack.
	await _finish_special_enemy_turn(actor, target, int(score[0]) >= int(score[1]))

# One diver's level-up line: name, level reached, Spell Points earned
# (combined across all levels crossed).
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
	# Victory music now, while Battle still owns the screen.
	_audio_call(&"play_victory_music")
	_set_all_buttons(false)
	# Clear the active turn so the NOW chip/cursor don't linger.
	_acting = {}
	_queue.clear()
	_turn_cursor_target = null
	_turn_cursor.visible = false
	for chip in queue_row.get_children():
		chip.queue_free()
	var victory := Label.new()
	victory.text = "Victory"
	victory.add_theme_font_size_override("font_size", 18)
	victory.add_theme_color_override("font_color", Color(0.6, 0.9, 0.8))
	queue_row.add_child(victory)
	main_menu.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	# Clear the last move's name/power row and stat panels.
	_set_row_highlight(_selected_move_panel, false)
	_selected_move_panel.visible = false
	(_player_stats_ui.panel as Control).visible = false
	(_enemy_stats_ui.panel as Control).visible = false
	_log("Cordys falls. You have defeated the creature that broke you." if encounter_source == "maze_cordys" else ("Tethys sinks back into the dark, beaten." if boss_encounter else "The enemies back off, beaten."))
	# Survivors celebrate; the clip loops while the XP lines read.
	for entry in _living(party):
		if entry.has("actor") and is_instance_valid(entry.actor) and entry.actor is Diver:
			(entry.actor as Diver).play_win()
	await get_tree().create_timer(_log_read_delay()).timeout
	# Extra hold before the first tutorial's victory caption.
	if tutorial_encounter and not special_encounter:
		await get_tree().create_timer(TUTORIAL_WIN_EXTRA_HOLD).timeout
	# The tutorial win grants no XP.
	var levelup_blocks: Array[String] = []
	var spell_unlock_announcements: Array[Dictionary] = []
	if not tutorial_encounter:
		var total_xp := _puppet_completed_xp
		for e in enemies:
			total_xp += int(e.get("xp_reward", 0))
		if special_encounter:
			total_xp = int(round(float(total_xp) * 1.5))
		# Every party member gets the full XP amount.
		for entry in party:
			var xp_stats := entry.stats as CombatantStats
			var xp_before := xp_stats.xp
			var next_before := xp_stats.xp_to_next
			var levels: Array = xp_stats.gain_xp(total_xp)
			_animate_xp_gain(entry, total_xp, xp_before, next_before, levels.size())
			for lv in levels:
				_log("%s reached level %d!" % [String(entry.display_name), int((lv as Dictionary).level)])
				await get_tree().create_timer(_log_read_delay()).timeout
			if not levels.is_empty():
				levelup_blocks.append(_build_levelup_block(entry, levels))
		var available_key_items: Array = world.key_items.duplicate() if world != null else campaign_key_items_source.duplicate()
		# Include the reward key item now so this win can unlock its spell.
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
					"all": SpellTree.knows_all(diver),
				})
	# Reward announced as the last log line; practice runs award nothing.
	if reward_item_on_win != "" and Items.ITEMS.has(reward_item_on_win) and not (special_encounter and tutorial_encounter):
		_log(reward_claim_text(reward_item_on_win))
		await get_tree().create_timer(_log_read_delay()).timeout
	# One combined level-up block (never in the tutorial).
	if not levelup_blocks.is_empty():
		_levelup_caption.text = "\n\n".join(levelup_blocks)
		_levelup_caption.visible = true
		call_deferred("_fit_panel_height")
	# Victories don't refill resources.
	_refresh_all_bars()
	# Plain combat tutorial only: explains this win gave no XP and what wins normally do.
	if tutorial_encounter and not special_encounter:
		await _tutorial_show_step("You have defeated your first enemy! In this case you won't gain XP.")
		for entry in party:
			if entry.has("hp_heal_overlay"):
				(entry.hp_heal_overlay as ColorRect).visible = false
			if entry.has("oxygen_heal_overlay"):
				(entry.oxygen_heal_overlay as ColorRect).visible = false
	else:
		# Timed hold outside the tutorial.
		await get_tree().create_timer(_log_read_delay()).timeout
		for entry in party:
			if entry.has("hp_heal_overlay"):
				(entry.hp_heal_overlay as ColorRect).visible = false
			if entry.has("oxygen_heal_overlay"):
				(entry.oxygen_heal_overlay as ColorRect).visible = false
		if not levelup_blocks.is_empty():
			_levelup_caption.visible = false
			call_deferred("_fit_panel_height")
	for unlock in spell_unlock_announcements:
		var unlock_text := "%s unlocked %s." % [String(unlock.display_name), ", ".join(unlock.skills)]
		if bool(unlock.get("all", false)):
			unlock_text += " That was %s's last ability - every ability is now unlocked!" % String(unlock.display_name)
		await _tutorial_show_step(unlock_text)
	_revert_temp_buffs()
	finished.emit("won")

func _lose() -> void:
	# Reframe once more before the loss screen.
	_frame_stage_camera()
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	# Plain combat tutorial loss: explains that World heals and returns the party
	# instead of Game Over.
	if tutorial_encounter and not special_encounter:
		await _tutorial_show_step("In this case, the party lost the fight, but you can continue to fight enemies in the overworld. Winning a fight awards XP to your whole party, not just whoever fought - including anyone who went down during the fight, who gains XP the same as everyone else. Gain enough XP and a diver levels up, which refills their HP and Oxygen (green on the bars, outlined in purple at the top) even if they went down - otherwise a downed diver needs a Revive spell to get back on their feet. Leveling up doesn't change your combat stats but instead lets the divers gain new abilities.")
	else:
		_log("The party is battered and pulls back.")
		await get_tree().create_timer(_log_read_delay()).timeout
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
	# Only the skip line stays on screen.
	_tutorial_caption.text = ""
	_tutorial_caption.visible = false
	_tutorial_continue_btn.visible = false
	_levelup_caption.visible = false
	move_menu.visible = false
	item_menu.visible = false
	target_menu.visible = false
	_selected_move_panel.visible = false
	(_player_stats_ui.panel as Control).visible = false
	(_enemy_stats_ui.panel as Control).visible = false
	_log("Skipping the tutorial fight.")
	await get_tree().create_timer(_log_read_delay()).timeout
	_revert_temp_buffs()
	finished.emit("skipped")

# Bosses (Tethys, Cordys) can't be run from; Run shows but stays disabled.
func _no_escape() -> bool:
	return boss_encounter or encounter_source == "maze_cordys"

func _on_run() -> void:
	if _busy or _no_escape():
		return
	_busy = true
	_set_all_buttons(false)
	main_menu.visible = false

	if randf() <= RUN_CHANCE:
		_log("The party breaks off and swims for it.")
		await get_tree().create_timer(_log_read_delay()).timeout
		_revert_temp_buffs()
		finished.emit("fled")
		return

	var living_enemies := _living(enemies)
	var blocker := String(living_enemies[0].display_name) if not living_enemies.is_empty() else "something"
	_log("Can't get clear - %s cuts you off!" % blocker)
	await get_tree().create_timer(_log_read_delay()).timeout
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
		await get_tree().create_timer(_log_read_delay()).timeout
	_finish_actor_turn(_acting)
	_advance_turn()

func _set_all_buttons(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	run_btn.disabled = not enabled or _no_escape()
	if skip_tutorial_btn != null:
		# Skip stays available during the special encounter's intro captions.
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
