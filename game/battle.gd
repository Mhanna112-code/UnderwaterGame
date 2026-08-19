# The turn-based screen a random encounter drops you into: a small 3D stage
# showing all three divers and however many grunts stopped you, with a menu
# underneath. world.gd freezes the dive and hands over the mouse while this
# is up, then un-freezes once `finished` fires.
#
# Combatants live as plain Dictionaries (not a class) in two arrays -
# `party` and `enemies` - each entry shaped
# {kind, stats, model_name, display_name, equipped_spells, actor, hp_bar,
# hp_label, barrier_bar}. A Dictionary rather than a real class because
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

signal finished(result: String)     # "won", "fled", or "lost"

# Set by world.gd before add_child - the real Diver nodes from the dive
# site (world.divers), so .stats (shared by reference - a Resource, not
# copied) carries level-ups back out, and .equipped_spells says what each
# one can actually cast here. Nothing about these nodes is touched beyond
# reading those three fields - they stay right where they are in the dive
# site the whole fight, frozen like everything else while battling.
var party_source: Array = []

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
const BASE_MOVES := {
	"Staff_Diver": [
		{"name": "Swift Jab", "power": 4, "acc_mod": 6, "hint": "Fast, reliable", "text": "You jab it in a burst of speed"},
		{"name": "Riptide Kick", "power": 7, "acc_mod": 2, "hint": "Balanced", "text": "You kick it on a current", "oxygen_cost": 10.0},
		{"name": "Crashing Wave", "power": 12, "acc_mod": -2, "hint": "Heavy, riskier", "text": "You crash into it like a wave", "oxygen_cost": 16.0},
	],
	"Prototype_1(1910)": [
		{"name": "Precise Tap", "power": 3, "acc_mod": 9, "hint": "Nearly unmissable, light", "text": "You land a precise tap"},
		{"name": "Weaken", "power": 0, "acc_mod": 2, "debuff": "defense", "amount": 2, "hint": "Lowers its defense", "text": "You strike a nerve - its defense drops", "oxygen_cost": 10.0},
		{"name": "Slow", "power": 0, "acc_mod": 2, "debuff": "agility", "amount": 2, "hint": "Lowers its agility", "text": "You hobble it - its agility drops", "oxygen_cost": 10.0},
	],
	"Prototype_V(1922)": [
		{"name": "Guard Bash", "power": 6, "acc_mod": 3, "hint": "Sturdy, reliable", "text": "You bash it with your guard"},
		{"name": "Heavy Kick", "power": 10, "acc_mod": 0, "hint": "Balanced, heavier", "text": "You drive a heavy kick home", "oxygen_cost": 10.0},
		{"name": "Crushing Haymaker", "power": 15, "acc_mod": -3, "hint": "Very heavy, slow", "text": "You wind up and crush it", "oxygen_cost": 16.0},
	],
}

const ENEMY_MOVE := {"power": 9, "acc_mod": 1, "quick_time_bool": true}

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
var attack_btn: Button
var run_btn: Button
var back_btn: Button
var move_buttons: Array = []
var target_buttons: Array = []

# The battle-stage SubViewport (see _build_stage()) - stored so
# _turn_cursor can be built as a child of the same 3D world the party/enemy
# actors live in, not the CanvasLayer's 2D UI tree.
var _stage_vp: SubViewport

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
			"equipped_spells": dv.equipped_spells,
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

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.8, 5.5)
	cam.fov = 70.0
	vp.add_child(cam)
	# look_at() needs the node in the tree first - it operates on global
	# transform, which doesn't exist until add_child runs.
	cam.look_at(Vector3(0.0, 1.1, -1.5), Vector3.UP)

	# Party visuals, spread left-to-right so 1-3 divers don't overlap.
	# Diver.rotation.y == 0 is the model's own rest-facing direction (-Z, see
	# diver.gd), so leaving it untouched here is what puts its back to camera.
	var pn := party.size()
	for i in range(pn):
		var actor := Diver.new()
		actor.model_name = String(party[i].model_name)
		actor.position = Vector3(_spread(i, pn, 1.3) - 0.4, 0.0, 1.0)
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
	var count := randi_range(MIN_ENEMIES, MAX_ENEMIES)
	for i in range(count):
		var g := Goblin.new()
		g.position = Vector3(_spread(i, count, 1.1) + 0.6, 0.0, -2.2)
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

	move_menu = HFlowContainer.new()
	move_menu.add_theme_constant_override("h_separation", 12)
	move_menu.add_theme_constant_override("v_separation", 8)
	move_menu.visible = false
	col.add_child(move_menu)
	back_btn = _menu_button("Back", "")
	back_btn.pressed.connect(_show_main)
	move_menu.add_child(back_btn)

	target_menu = HFlowContainer.new()
	target_menu.add_theme_constant_override("h_separation", 12)
	target_menu.add_theme_constant_override("v_separation", 8)
	target_menu.visible = false
	col.add_child(target_menu)

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

	# HP bar and its barrier bar sit side by side, not stacked - "next to
	# health," not overlapping it, so a full shield never hides how much HP
	# is actually left underneath.
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

	# Gray fill via a StyleBox override on just the "fill" slot, not
	# modulate - modulate would also tint the empty track, not only the
	# part that reads as "this much barrier is left."
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

# Hidden entirely for a combatant with no barrier at all, rather than
# showing a permanently-empty gray sliver next to their HP.
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

func _show_main() -> void:
	if _busy:
		return
	move_menu.visible = false
	target_menu.visible = false
	main_menu.visible = true
	call_deferred("_fit_panel_height")

# Barrier moves target the caster and always succeed - no target picker,
# straight to resolution. Heal targets a living ally (a downed one has
# nothing a heal can do for it - see _apply_revive() for that); revive
# targets a downed one specifically. Everything else still targets an
# enemy. In every case: skip the picker entirely when there's only one
# valid target (no real choice to make), otherwise show one button per
# candidate. An empty pool (e.g. Revive with nobody actually down) just
# reopens the move menu instead of silently eating the button press.
func _on_move_chosen(mv: Dictionary) -> void:
	if _busy:
		return
	if (_acting.stats as CombatantStats).oxygen < float(mv.get("oxygen_cost", 0.0)):
		return
	move_menu.visible = false
	var effect := String(mv.get("effect", ""))
	if effect == "barrier":
		_resolve_party_move(mv, _acting)
		return

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
	if targets.size() <= 1:
		_resolve_party_move(mv, targets[0])
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

func _on_target_chosen(target: Dictionary) -> void:
	target_menu.visible = false
	_resolve_party_move(_pending_move, target)

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
#  4. Barrier - a temporary shield that eats damage before HP does. Doesn't
#     refill on its own (see CombatantStats.fill()/gain_xp() and, now,
#     _apply_barrier() below), so once it's spent it stays spent until the
#     next level-up or barrier spell.
func _resolve_attack(attacker: CombatantStats, defender: CombatantStats, move: Dictionary) -> Dictionary:
	var effective_accuracy: int = attacker.accuracy + int(move.get("acc_mod", 0))
	if effective_accuracy <= defender.evasion:
		return {"hit": false, "damage": 0, "absorbed": 0, "debuff": "", "changed": 0, "dodged": false}

	var debuff: String = String(move.get("debuff", ""))
	if debuff != "":
		return _apply_debuff(defender, debuff, int(move.get("amount", 0)))

	var variance: float = randf_range(0.85, 1.15)
	var raw: float
	if String(move.get("effect", "")) == "heavy":
		# A telegraphed signature hit, scaled off the DEFENDER's own max HP
		# rather than the attacker's power/strength - "a quarter to half of
		# your health," not a number that happens to land in that range at
		# the moment it was tuned. Still runs through the normal
		# defense/barrier mitigation below and the same QTE dodge check
		# right after (see ENEMY_HEAVY_MOVE's quick_time_bool) - investing
		# in defense/barrier or just timing the dodge both still matter,
		# this only changes how big the raw threat is before either kicks in.
		raw = float(defender.hp_max) * randf_range(float(move.get("heavy_min", 0.25)), float(move.get("heavy_max", 0.5)))
	else:
		raw = (float(move.power) + float(attacker.strength)) * variance
	var incoming: int = maxi(0, int(round(raw)) - defender.defense)

	# Only a move explicitly tagged for it (ENEMY_MOVE, currently) ever
	# triggers a QTE - a player's own attacks never set quick_time_bool, so
	# this is a no-op for anything the player swings themselves. A
	# successful dodge zeroes incoming outright rather than just skipping
	# barrier absorption below - the reward for timing it right is not
	# needing the barrier to save you at all, not just saving the barrier
	# for later.
	var player_dodge := false
	if bool(move.get("quick_time_bool", false)):
		player_dodge = await _quick_time_event()
		if player_dodge:
			incoming = 0

	var absorbed: int = 0
	if defender.barrier > 0 and incoming > 0:
		absorbed = mini(defender.barrier, incoming)
		defender.barrier -= absorbed
	var to_hp: int = incoming - absorbed
	defender.hp = maxi(0, defender.hp - to_hp)

	return {"hit": true, "damage": to_hp, "absorbed": absorbed, "debuff": "", "changed": 0, "dodged": player_dodge}

# Dispatches on the move's "effect" key before falling through to the
# normal attack/debuff resolution above. "barrier" (defense-branch spells)
# targets the caster instead of the defender and always succeeds, no
# accuracy check - raising your own shield isn't something the target
# could "evade." "heal"/"revive" (support-branch spells, see spell_tree.gd)
# target an ally instead of an enemy - `defender` here is really just
# "whoever _on_move_chosen()'s target picker resolved to," which for these
# two effects is a living or downed ally respectively, not literally a
# defender - and same as barrier, always succeed: nothing about mending a
# wound is something the ally being healed could fail to receive.
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

func _resolve_party_move(mv: Dictionary, target: Dictionary) -> void:
	if target.is_empty():
		_advance_turn()
		return
	_busy = true
	_set_all_buttons(false)

	(_acting.stats as CombatantStats).oxygen -= float(mv.get("oxygen_cost", 0.0))
	var r: Dictionary = await _resolve_move(_acting.stats, target.stats, mv)
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
	# about that instead of assuming 0.8s and 0.9s never overlap.
	var target_died: bool = target.has("stats") and (target.stats as CombatantStats).hp <= 0
	if target_died and target.has("actor") and target.actor is Goblin:
		(target.actor as Goblin).play_death_fade()
	elif r.hit and String(r.debuff) == "" and target.has("actor") and target.actor is Goblin:
		(target.actor as Goblin).play("walk")
	await get_tree().create_timer(0.8).timeout
	if not target_died and target.has("actor") and is_instance_valid(target.actor) and target.actor is Goblin:
		(target.actor as Goblin).play("idle")
	_advance_turn()

func _do_enemy_turn(actor: Dictionary) -> void:
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	target_menu.visible = false
	_turn_cursor.visible = false

	var alive_party := _living(party)
	if alive_party.is_empty():
		_advance_turn()
		return
	var target: Dictionary = alive_party[randi_range(0, alive_party.size() - 1)]
	var heavy := randf() < ENEMY_HEAVY_CHANCE
	var r: Dictionary = await _resolve_attack(actor.stats, target.stats, ENEMY_HEAVY_MOVE if heavy else ENEMY_MOVE)
	_refresh_bar(target)
	var verb := ("%s winds up and slams into %s" % [String(actor.display_name), String(target.display_name)]) if heavy else ("%s claws at %s" % [String(actor.display_name), String(target.display_name)])
	if bool(r.get("dodged", false)):
		_log("%s - %s times it perfectly and dodges clear!" % [verb, String(target.display_name)])
	elif not r.hit:
		_log("%s, but %s evades!" % [verb, String(target.display_name)])
	elif int(r.damage) == 0 and int(r.absorbed) > 0:
		_log("%s - barrier soaks it completely!" % verb)
	elif int(r.absorbed) > 0:
		_log("%s for %d (%d soaked by barrier)." % [verb, int(r.damage), int(r.absorbed)])
	else:
		_log("%s for %d." % [verb, int(r.damage)])
	if (target.stats as CombatantStats).hp <= 0 and target.has("actor") and target.actor is Diver:
		(target.actor as Diver).play_death_fade()
	await get_tree().create_timer(0.9).timeout
	_advance_turn()

func _win() -> void:
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	target_menu.visible = false
	_log("The enemies back off, beaten.")
	await get_tree().create_timer(0.9).timeout
	var total_xp := 0
	for e in enemies:
		if e.has("actor") and is_instance_valid(e.actor) and e.actor is Goblin:
			total_xp += int((e.actor as Goblin).xp_reward)
	# Every party member gets the full amount, not a split share - there's
	# no shared party XP pool concept in this game, and splitting it would
	# just make leveling slower for the same fights without adding a
	# meaningful choice anywhere.
	for entry in party:
		var levels: Array = (entry.stats as CombatantStats).gain_xp(total_xp)
		for lv in levels:
			_log("%s reached level %d!" % [String(entry.display_name), int(lv)])
			await get_tree().create_timer(0.8).timeout
	finished.emit("won")

func _lose() -> void:
	_set_all_buttons(false)
	main_menu.visible = false
	move_menu.visible = false
	target_menu.visible = false
	_log("The party is battered and pulls back.")
	await get_tree().create_timer(0.9).timeout
	finished.emit("lost")

func _on_run() -> void:
	if _busy:
		return
	_busy = true
	_set_all_buttons(false)
	main_menu.visible = false

	if randf() <= RUN_CHANCE:
		_log("The party breaks off and swims for it.")
		await get_tree().create_timer(0.7).timeout
		finished.emit("fled")
		return

	var living_enemies := _living(enemies)
	var blocker := String(living_enemies[0].display_name) if not living_enemies.is_empty() else "something"
	_log("Can't get clear - %s cuts you off!" % blocker)
	await get_tree().create_timer(0.8).timeout
	if not living_enemies.is_empty():
		var attacker: Dictionary = living_enemies[randi_range(0, living_enemies.size() - 1)]
		var r: Dictionary = await _resolve_attack(attacker.stats, _acting.stats, ENEMY_MOVE)
		_refresh_bar(_acting)
		if bool(r.get("dodged", false)):
			_log("%s lunges - you time it perfectly and dodge clear!" % String(attacker.display_name))
		elif not r.hit:
			_log("%s lunges, but you evade clear." % String(attacker.display_name))
		elif int(r.damage) == 0 and int(r.absorbed) > 0:
			_log("%s - your barrier soaks it completely!" % String(attacker.display_name))
		else:
			_log("%s claws you for %d as you struggle free." % [String(attacker.display_name), int(r.damage)])
		if (_acting.stats as CombatantStats).hp <= 0 and _acting.has("actor") and _acting.actor is Diver:
			(_acting.actor as Diver).play_death_fade()
	_advance_turn()

func _set_all_buttons(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	run_btn.disabled = not enabled
	back_btn.disabled = not enabled
	for b in move_buttons:
		(b as Button).disabled = not enabled
	for b in target_buttons:
		(b as Button).disabled = not enabled
