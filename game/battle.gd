# The turn-based screen a random encounter drops you into: a small 3D stage
# showing the diver you're steering and the grunt that stopped you, with a
# menu underneath (Attack opens a move list, Run gambles on getting clear).
# world.gd freezes the dive and hands over the mouse while this is up, then
# un-freezes once `finished` fires.
class_name Battle
extends CanvasLayer

signal finished(result: String)     # "won", "fled", or "lost"

var diver_model_name := "Staff_Diver"

var player_hp := 30
var player_hp_max := 30
var enemy_hp := 16
var enemy_hp_max := 16
var _busy := false

# FF-style flee: not guaranteed. Failing costs the turn and the grunt gets a
# free swing, same as the moves you'd rather have picked instead.
const RUN_CHANCE := 0.6

# Attack is a category, not a single action: pressing it opens this list
# instead of swinging right away. Each move sits on the same accuracy/power
# axis (safe and light vs risky and heavy) and says so on its own button, so
# the choice is legible before you commit rather than something you only
# learn from the log after the fact.
const MOVES := [
	{"name": "Jab", "min": 3, "max": 5, "acc": 1.0, "hint": "Always hits, light", "text": "You jab the grunt"},
	{"name": "Kick", "min": 5, "max": 9, "acc": 0.85, "hint": "Balanced", "text": "You kick the grunt"},
	{"name": "Haymaker", "min": 8, "max": 15, "acc": 0.55, "hint": "Heavy, often misses", "text": "You wind up and swing at the grunt"},
]

var player_bar: ProgressBar
var player_hp_label: Label
var enemy_bar: ProgressBar
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
	_build_stage()
	_build_ui()
	_refresh_hp()
	_log("A goblin grunt blocks the way!")

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
	var eb := _add_bar(bars, "Grunt")
	enemy_bar = eb[0]
	enemy_hp_label = eb[1]

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
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 20)
	bar.show_percentage = false
	wrap.add_child(bar)
	var hp_label := Label.new()
	wrap.add_child(hp_label)
	return [bar, hp_label]

func _refresh_hp() -> void:
	player_bar.max_value = player_hp_max
	player_bar.value = player_hp
	player_hp_label.text = "%d / %d" % [player_hp, player_hp_max]
	enemy_bar.max_value = enemy_hp_max
	enemy_bar.value = enemy_hp
	enemy_hp_label.text = "%d / %d" % [enemy_hp, enemy_hp_max]

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

func _on_move(i: int) -> void:
	if _busy:
		return
	_busy = true
	_set_buttons(false)

	var mv: Dictionary = MOVES[i]
	if randf() <= float(mv.acc):
		var dmg := randi_range(int(mv.min), int(mv.max))
		enemy_hp = maxi(0, enemy_hp - dmg)
		_refresh_hp()
		enemy_actor.play("walk")
		_log("%s for %d." % [String(mv.text), dmg])
	else:
		_log("%s - it misses!" % String(mv.text))
	await get_tree().create_timer(0.8).timeout
	enemy_actor.play("idle")

	if enemy_hp <= 0:
		_log("The grunt backs off, beaten.")
		await get_tree().create_timer(0.9).timeout
		finished.emit("won")
		return

	var back := randi_range(2, 7)
	player_hp = maxi(0, player_hp - back)
	_refresh_hp()
	_log("The grunt claws back for %d." % back)
	await get_tree().create_timer(0.9).timeout

	if player_hp <= 0:
		_log("You're battered and pull back.")
		await get_tree().create_timer(0.9).timeout
		finished.emit("lost")
		return

	move_menu.visible = false
	main_menu.visible = true
	_busy = false
	_set_buttons(true)

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

	var back := randi_range(2, 7)
	player_hp = maxi(0, player_hp - back)
	_refresh_hp()
	_log("It claws you for %d as you struggle free." % back)
	await get_tree().create_timer(0.9).timeout

	if player_hp <= 0:
		_log("You're battered and pull back.")
		await get_tree().create_timer(0.9).timeout
		finished.emit("lost")
		return

	_busy = false
	_set_buttons(true)

func _set_buttons(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	run_btn.disabled = not enabled
	back_btn.disabled = not enabled
	for b in move_buttons:
		(b as Button).disabled = not enabled
