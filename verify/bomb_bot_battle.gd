# Plays the authored Bomb Bot encounter through the real World trigger, Battle
# menus, enemy-turn dispatcher, victory/progression path, and return to free
# movement. This specifically guards DZ-26: construction-only and data-only
# blocker tests cannot catch a crash during a production attack or victory.
#
# Usage: godot --headless --path . --script verify/bomb_bot_battle.gd
extends SceneTree

const MAX_WALL_SECONDS := 180.0
const MAX_IDLE_SECONDS := 30.0

var world: World
var battle: Battle
var started_ms := 0
var last_action_ms := 0
var frames := 0
var result := ""
var presses := 0
var observed_bomb_attacks: Dictionary = {}
var observed_bomb_animations: Dictionary = {}
var enemy_turn_frames := 0
var bomb_trace_connected := false
var findings: Array[String] = []

func _initialize() -> void:
	seed(96026)
	EnemyRoster._rng.seed = 96026
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	started_ms = Time.get_ticks_msec()
	last_action_ms = started_ms

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		world.title_screen.close()
		paused = false
		world._first_encounter_started = true
		world._first_encounter_done = true
		var diver := world.divers[world.active] as Diver
		diver.global_position = world.deep_zone_layout.route_points().bomb_bot as Vector3
		world._update_route_zone()
		world._update_deep_zone_blockers()
		return false

	if world.battle != null:
		battle = world.battle as Battle
		if not battle.finished.is_connected(_on_finished):
			battle.finished.connect(_on_finished)
		if not bomb_trace_connected:
			_connect_bomb_animation_trace()
		if not battle._acting.is_empty() and String(battle._acting.get("kind", "")) == "enemy":
			enemy_turn_frames += 1
		_press_next_action()
	elif result != "":
		return _report()

	var elapsed := float(Time.get_ticks_msec() - started_ms) / 1000.0
	var idle := float(Time.get_ticks_msec() - last_action_ms) / 1000.0
	if elapsed > MAX_WALL_SECONDS:
		findings.append("DZ-26: Bomb Bot fight did not finish within %.0f seconds" % MAX_WALL_SECONDS)
		return _report()
	if idle > MAX_IDLE_SECONDS:
		findings.append("DZ-26: Bomb Bot fight exposed no usable action for %.0f seconds" % MAX_IDLE_SECONDS)
		return _report()
	return false

func _connect_bomb_animation_trace() -> void:
	for enemy_value in battle.enemies:
		var enemy := enemy_value as Dictionary
		var actor := enemy.get("actor") as BombBot
		if actor != null and actor.anim != null and not actor.anim.animation_started.is_connected(_on_bomb_animation_started):
			actor.anim.animation_started.connect(_on_bomb_animation_started)
			bomb_trace_connected = true

func _on_bomb_animation_started(clip: StringName) -> void:
	# Imported take names contain spaces ("Lighting Blast"); observe the
	# same semantic fragment regardless of cosmetic spacing/case. Retain the
	# raw signal below so an idle-only fight can never masquerade as an attack.
	var lower := String(clip).to_lower().replace(" ", "")
	observed_bomb_animations[String(clip)] = true
	for fragment in ["lightingblast", "slingpunch", "sonic_bump"]:
		if lower.contains(fragment):
			observed_bomb_attacks[fragment] = true

func _press_next_action() -> void:
	if battle == null:
		return
	if battle.target_menu.visible:
		_press_first(battle.target_buttons)
	elif battle.move_menu.visible:
		_press_first(battle.move_buttons)
	elif battle.main_menu.visible and is_instance_valid(battle.attack_btn) and not battle.attack_btn.disabled:
		battle.attack_btn.pressed.emit()
		_note_press()

func _press_first(buttons: Array) -> void:
	for value in buttons:
		var button := value as Button
		if is_instance_valid(button) and button.visible and not button.disabled:
			button.pressed.emit()
			_note_press()
			return

func _note_press() -> void:
	presses += 1
	last_action_ms = Time.get_ticks_msec()

func _on_finished(value: String) -> void:
	result = value
	last_action_ms = Time.get_ticks_msec()

func _report() -> bool:
	if result != "won":
		findings.append("DZ-26: real Bomb Bot battle ended '%s', expected a playable victory" % (result if result != "" else "without a result"))
	if world.battling or world.battle != null:
		findings.append("DZ-26: victory did not return control from the Battle to World")
	if world.route_state.bomb_bot_state != "defeated":
		findings.append("DZ-26: victory did not persist Bomb Bot defeat")
	if world.route_state.sword_slayer_state != "available":
		findings.append("DZ-26: victory did not leave the next authored blocker available")
	if observed_bomb_attacks.is_empty():
		findings.append("DZ-26: the completed production fight never visibly started a Bomb Bot attack clip (enemy turn frames=%d; all clips=%s)" % [enemy_turn_frames, observed_bomb_animations.keys()])

	print("Bomb Bot result=%s presses=%d enemy_turn_frames=%d attacks=%s all_animations=%s" % [result, presses, enemy_turn_frames, observed_bomb_attacks.keys(), observed_bomb_animations.keys()])
	for finding in findings:
		print("FINDING  " + finding)
	print("BOMB BOT BATTLE: clean" if findings.is_empty() else "BOMB BOT BATTLE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
