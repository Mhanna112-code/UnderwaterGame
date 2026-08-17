# The turn-based screen a random encounter drops you into: a small 3D stage
# showing the diver you're steering and the grunt that stopped you, with a
# menu underneath (Attack opens a move list, Run gambles on getting clear).
# world.gd freezes the dive and hands over the mouse while this is up, then
# un-freezes once `finished` fires.
class_name Battle
extends CanvasLayer

signal finished(result: String)     # "won", "fled", or "lost"

var diver_model_name := "Staff_Diver"

# Set by world.gd before add_child, so the diver's level/XP carry in and
# level-ups carry back out (CombatantStats is a Resource - shared by
# reference, not copied). If nothing sets this (tools/test_battle.gd
# instantiates a bare Battle), _ready builds a stand-in from Diver's own
# base-stat table so the fight still runs.
var player_stats: CombatantStats
var enemy_stats: CombatantStats
var _busy := false

# FF-style flee: not guaranteed. Failing costs the turn and the grunt gets a
# free swing, same as the moves you'd rather have picked instead.
const RUN_CHANCE := 0.6

# Attack is a category, not a single action: pressing it opens this list
# instead of swinging right away. Each move sits on the same accuracy/power
# axis (safe and light vs risky and heavy) and says so on its own button, so
# the choice is legible before you commit rather than something you only
# learn from the log after the fact. `power` feeds _resolve_attack() below,
# same formula as the grunt's own attack - stats do the differentiating
# between combatants, not separate damage math per side.
const MOVES := [
	{"name": "Jab", "power": 4, "acc": 1.0, "hint": "Always hits, light", "text": "You jab the grunt"},
	{"name": "Kick", "power": 7, "acc": 0.85, "hint": "Balanced", "text": "You kick the grunt"},
	{"name": "Haymaker", "power": 12, "acc": 0.55, "hint": "Heavy, often misses", "text": "You wind up and swing at the grunt"},
]

const ENEMY_MOVE := {"power": 5, "acc": 0.85}

var player_bar: ProgressBar
var player_barrier_bar: ProgressBar
var player_hp_label: Label
var enemy_bar: ProgressBar
var enemy_barrier_bar: ProgressBar
var enemy_hp_label: Label
var log_label: Label
var main_menu: HBoxContainer
var move_menu: HBoxContainer
var attack_btn: Button
var run_btn: Button
var move_buttons: Array = []
var back_btn: Button
var enemy_actor: Goblin

func _ready() -> void:
	layer = 10
	if player_stats == null:
		player_stats = _default_player_stats()
	_build_stage()
	_build_ui()
	_refresh_hp()
	_log("A goblin grunt blocks the way!")

# Stand-in used only when nothing hands this Battle a player_stats before it
# enters the tree - mirrors whatever Diver would have built for
# diver_model_name, so a standalone Battle (see tools/test_battle.gd) still
# has real numbers to fight with instead of nulls.
func _default_player_stats() -> CombatantStats:
	var base: Dictionary = Diver.BASE_STATS.get(diver_model_name, Diver.BASE_STATS["Staff_Diver"])
	var s := CombatantStats.new()
	s.hp_max = int(base.hp)
	s.attack = int(base.attack)
	s.defense = int(base.defense)
	s.speed = int(base.speed)
	s.luck = int(base.luck)
	s.dodge = float(base.dodge)
	s.accuracy = float(base.accuracy)
	s.barrier_max = int(base.barrier_max)
	s.grow_hp = int(base.grow_hp)
	s.grow_attack = int(base.grow_attack)
	s.grow_defense = int(base.grow_defense)
	s.grow_speed = int(base.grow_speed)
	s.grow_luck = int(base.grow_luck)
	s.fill()
	return s

# A SubViewport with its own camera, light and fog: isolated from the dive
# site's World3D (own_world_3d) so the two scenes can't see each other.
func _build_stage() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	add_child(container)

	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.own_world_3d = true
	container.add_child(vp)

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
	cam.position = Vector3(0.0, 1.5, 4.5)
	vp.add_child(cam)
	# look_at() needs the node in the tree first - it operates on global
	# transform, which doesn't exist until add_child runs.
	cam.look_at(Vector3(0.0, 1.1, -1.5), Vector3.UP)

	# Diver.rotation.y == 0 is the model's own rest-facing direction (-Z, see
	# diver.gd), so leaving it untouched here is what puts its back to camera.
	var player := Diver.new()
	player.model_name = diver_model_name
	player.position = Vector3(-1.1, 0.0, 1.0)
	vp.add_child(player)

	# The grunt's own rest facing was never checked against the camera (no
	# editor open to look): 180 is a guess. Flip to 0 here if it turns out to
	# be facing away instead of into shot.
	enemy_actor = Goblin.new()
	enemy_actor.position = Vector3(1.0, 0.0, -2.2)
	enemy_actor.rotation.y = PI
	vp.add_child(enemy_actor)
	enemy_stats = enemy_actor.make_stats(player_stats.level)

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Generous on purpose: two-line buttons plus the HP readouts need more
	# than a guess's worth of room, and PanelContainer won't clip or shrink
	# its child to fit - anything that doesn't fit just renders past the
	# bottom of the screen instead of wrapping or scrolling.
	panel.offset_top = -240.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 40)
	col.add_child(bars)
	var pb := _add_bar(bars, "You")
	player_bar = pb[0]
	player_hp_label = pb[1]
	player_barrier_bar = pb[2]
	var eb := _add_bar(bars, "Grunt")
	enemy_bar = eb[0]
	enemy_hp_label = eb[1]
	enemy_barrier_bar = eb[2]

	log_label = Label.new()
	log_label.custom_minimum_size = Vector2(0, 40)
	col.add_child(log_label)

	main_menu = HBoxContainer.new()
	main_menu.add_theme_constant_override("separation", 12)
	col.add_child(main_menu)
	attack_btn = _menu_button("Attack", "Pick a move")
	attack_btn.pressed.connect(_show_moves)
	main_menu.add_child(attack_btn)
	run_btn = _menu_button("Run", "Might not escape")
	run_btn.pressed.connect(_on_run)
	main_menu.add_child(run_btn)

	move_menu = HBoxContainer.new()
	move_menu.add_theme_constant_override("separation", 12)
	move_menu.visible = false
	col.add_child(move_menu)
	for i in range(MOVES.size()):
		var mv: Dictionary = MOVES[i]
		var b := _menu_button(String(mv.name), String(mv.hint))
		b.pressed.connect(_on_move.bind(i))
		move_menu.add_child(b)
		move_buttons.append(b)
	back_btn = _menu_button("Back", "")
	back_btn.pressed.connect(_show_main)
	move_menu.add_child(back_btn)

# Name plus a one-line tradeoff, right on the button: the choice needs to
# read before it's clicked, not just get explained after in the log.
func _menu_button(title: String, hint: String) -> Button:
	var b := Button.new()
	b.text = title if hint == "" else "%s\n%s" % [title, hint]
	b.custom_minimum_size = Vector2(150, 46)
	return b

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
	bar.custom_minimum_size = Vector2(200, 20)
	bar.show_percentage = false
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.78, 0.15, 0.15)
	bar.add_theme_stylebox_override("fill", hp_fill)
	bar_row.add_child(bar)

	# Gray fill via a StyleBox override on just the "fill" slot, not
	# modulate - modulate would also tint the empty track, not only the
	# part that reads as "this much barrier is left."
	var barrier_bar := ProgressBar.new()
	barrier_bar.custom_minimum_size = Vector2(48, 20)
	barrier_bar.show_percentage = false
	var barrier_fill := StyleBoxFlat.new()
	barrier_fill.bg_color = Color(0.62, 0.64, 0.68)
	barrier_bar.add_theme_stylebox_override("fill", barrier_fill)
	bar_row.add_child(barrier_bar)

	var hp_label := Label.new()
	wrap.add_child(hp_label)
	return [bar, hp_label, barrier_bar]

func _refresh_hp() -> void:
	player_bar.max_value = player_stats.hp_max
	player_bar.value = player_stats.hp
	player_hp_label.text = "%d / %d   Lv %d" % [player_stats.hp, player_stats.hp_max, player_stats.level]
	_refresh_barrier_bar(player_barrier_bar, player_stats)

	enemy_bar.max_value = enemy_stats.hp_max
	enemy_bar.value = enemy_stats.hp
	enemy_hp_label.text = "%d / %d" % [enemy_stats.hp, enemy_stats.hp_max]
	_refresh_barrier_bar(enemy_barrier_bar, enemy_stats)

# Hidden entirely for a combatant with no barrier at all (the grunt, right
# now) rather than showing a permanently-empty gray sliver next to their HP.
func _refresh_barrier_bar(bar: ProgressBar, stats: CombatantStats) -> void:
	bar.visible = stats.barrier_max > 0
	if not bar.visible:
		return
	bar.max_value = stats.barrier_max
	bar.value = stats.barrier

func _log(text: String) -> void:
	log_label.text = text

func _show_moves() -> void:
	if _busy:
		return
	main_menu.visible = false
	move_menu.visible = true

func _show_main() -> void:
	if _busy:
		return
	move_menu.visible = false
	main_menu.visible = true

# One damage roll, used identically for the player's moves and the grunt's
# counter - stats (not separate formulas per side) are what make the two
# feel different.
#
# Resolution order:
#  1. Dodge. defender.dodge is a flat chance to avoid the hit completely,
#     no matter how hard it would have landed. attacker.accuracy cancels
#     that chance point-for-point (never past zero) rather than adding a
#     bonus of its own - it only ever makes a dodgy target easier to hit.
#  2. Power + attack, with variance and crit.
#  3. Defense subtracts flat from that raw amount - unlike a percentage
#     mitigation, this can floor a hit at 0: a well-armoured target can
#     shrug a weak attack off entirely, not just take less from it.
#  4. Barrier - a temporary shield that eats damage before HP does. Doesn't
#     refill on its own (see CombatantStats.fill()/gain_xp()), so once
#     it's spent it stays spent until the next level-up.
func _resolve_attack(attacker: CombatantStats, defender: CombatantStats, move: Dictionary) -> Dictionary:
	var effective_dodge: float = maxf(0.0, defender.dodge - attacker.accuracy)
	var hit_chance: float = clampf(float(move.acc) - effective_dodge, 0.05, 0.95)
	if randf() > hit_chance:
		return {"hit": false, "crit": false, "damage": 0, "absorbed": 0}

	var crit: bool = randf() <= 0.05 + float(attacker.luck) * 0.01
	var variance: float = randf_range(0.85, 1.15)
	var raw: float = (float(move.power) + float(attacker.attack)) * variance * (1.5 if crit else 1.0)
	var incoming: int = maxi(0, int(round(raw)) - defender.defense)

	var absorbed: int = 0
	if defender.barrier > 0 and incoming > 0:
		absorbed = mini(defender.barrier, incoming)
		defender.barrier -= absorbed
	var to_hp: int = incoming - absorbed
	defender.hp = maxi(0, defender.hp - to_hp)

	return {"hit": true, "crit": crit, "damage": to_hp, "absorbed": absorbed}

func _do_player_attack(move: Dictionary) -> void:
	var r: Dictionary = _resolve_attack(player_stats, enemy_stats, move)
	_refresh_hp()
	if not r.hit:
		_log("%s - it dodges!" % String(move.text))
	elif int(r.damage) == 0 and int(r.absorbed) > 0:
		_log("%s - its barrier soaks the hit completely!" % String(move.text))
	elif int(r.absorbed) > 0:
		_log("%s for %d (%d soaked by its barrier)." % [String(move.text), int(r.damage), int(r.absorbed)])
	elif r.crit:
		_log("%s for %d. Critical hit!" % [String(move.text), int(r.damage)])
	else:
		_log("%s for %d." % [String(move.text), int(r.damage)])
	if r.hit:
		enemy_actor.play("walk")
	await get_tree().create_timer(0.8).timeout
	enemy_actor.play("idle")

func _do_enemy_attack(verb: String) -> void:
	var r: Dictionary = _resolve_attack(enemy_stats, player_stats, ENEMY_MOVE)
	_refresh_hp()
	if not r.hit:
		_log("The grunt lunges, but you dodge clear.")
	elif int(r.damage) == 0 and int(r.absorbed) > 0:
		_log("%s - your barrier soaks the hit completely!" % verb)
	elif int(r.absorbed) > 0:
		_log("%s for %d (%d soaked by your barrier)." % [verb, int(r.damage), int(r.absorbed)])
	elif r.crit:
		_log("%s for %d! A solid hit." % [verb, int(r.damage)])
	else:
		_log("%s for %d." % [verb, int(r.damage)])
	await get_tree().create_timer(0.9).timeout

func _on_move(i: int) -> void:
	if _busy:
		return
	_busy = true
	_set_buttons(false)
	move_menu.visible = false

	var p_move: Dictionary = MOVES[i]
	var player_first: bool
	if player_stats.speed == enemy_stats.speed:
		player_first = randf() < 0.5
	else:
		player_first = player_stats.speed > enemy_stats.speed

	if player_first:
		await _do_player_attack(p_move)
		if enemy_stats.hp <= 0:
			await _win()
			return
		await _do_enemy_attack("The grunt claws back")
		if player_stats.hp <= 0:
			await _lose()
			return
	else:
		await _do_enemy_attack("The grunt is faster - it claws first")
		if player_stats.hp <= 0:
			await _lose()
			return
		await _do_player_attack(p_move)
		if enemy_stats.hp <= 0:
			await _win()
			return

	main_menu.visible = true
	_busy = false
	_set_buttons(true)

func _win() -> void:
	_log("The grunt backs off, beaten.")
	await get_tree().create_timer(0.9).timeout
	var levels: Array = player_stats.gain_xp(enemy_actor.xp_reward)
	for lv in levels:
		_log("%s reached level %d!" % [diver_model_name, int(lv)])
		await get_tree().create_timer(1.0).timeout
	finished.emit("won")

func _lose() -> void:
	_log("You're battered and pull back.")
	await get_tree().create_timer(0.9).timeout
	finished.emit("lost")

func _on_run() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons(false)

	if randf() <= RUN_CHANCE:
		_log("You break off and swim for it.")
		await get_tree().create_timer(0.7).timeout
		finished.emit("fled")
		return

	_log("Can't get clear - the grunt cuts you off!")
	await get_tree().create_timer(0.8).timeout
	await _do_enemy_attack("It claws you as you struggle free")
	if player_stats.hp <= 0:
		await _lose()
		return

	_busy = false
	_set_buttons(true)

func _set_buttons(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	run_btn.disabled = not enabled
	back_btn.disabled = not enabled
	for b in move_buttons:
		(b as Button).disabled = not enabled
