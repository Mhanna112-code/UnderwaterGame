# Play a whole fight, from the overworld and back to it.
#
# Three separate things this proves, and every one of them was found by
# hand on the playtest call rather than by anything automated:
#
#  1. A fight that ends without handing control back leaves the player on
#     a battle screen with nothing to press (#13). The only way to catch
#     that is to play one to the end and then check the world came back.
#  2. A rigged diver who resolves a clip and animates nothing looks exactly
#     like a game that has frozen. This watches which clip each attacker is
#     really playing at the moment it swings, and whose clip it is (#25).
#  3. All three party members have to get a turn. A fight the bot wins on
#     the first diver's swings alone never exercises the other two.
#
# The bot presses the real buttons rather than calling resolve functions
# directly, so a move menu that builds nothing, or a target picker that
# never appears, fails here rather than in front of a player.
#
# Usage: godot --headless --path . --script verify/fight.gd
extends SceneTree

# Budgets, not a simulated clock. A headless SceneTree runs as fast as it
# can and battle.gd's waits are real timers, so counting frames tells you
# nothing about how long a fight is. What a stuck fight looks like is a bot
# that keeps pressing and never gets a result, or a screen with nothing
# left to press at all.
const MAX_PRESSES := 400
const MAX_WALL_SECONDS := 600.0
# How long the bot will sit with no button to press before calling it
# stuck. Generous, because battle.gd deliberately holds the screen for
# LOG_READ_DELAY after every action and again for each level-up line.
const MAX_IDLE_SECONDS := 30.0
# How far from its target an attacker may be when the swing is playing, and
# how far off the line to it they may be facing. The step in stops
# SWING_REACH short of the target, so this is that plus room for the models'
# own width and the tween still settling.
const MAX_SWING_GAP := 3.6
const MAX_SWING_ANGLE := 35.0

var world: Node3D
var findings: Array = []
var started_ms := 0
var last_press_ms := 0
var frames := 0
var result := ""
var presses := 0
var turns := 0
var swings_seen: Dictionary = {}
var aim_findings: Dictionary = {}
var aim_samples := 0
var reactions_seen: Dictionary = {}
var party_names: Array = []
var display_names: Array = []
var back_in_world := false
# One pass through every combat menu's Back button before the bot settles
# into actually fighting. Issue #37 asked for exactly this: any combat menu
# can be left without taking an action.
var backed_out_of_moves := false
var backed_out_of_targets := false
var backing := ""


func _initialize() -> void:
	# This is an interaction/animation gate, not the balance simulation (that
	# is verify/balance.gd across 120 fixed seeds). Fix the RNG so this gate
	# always exercises the same fight instead of occasionally rolling three
	# enemies that down a party member before their animation can run.
	seed(1)
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	started_ms = Time.get_ticks_msec()
	last_press_ms = started_ms

func _process(_dt: float) -> bool:
	frames += 1

	# _ready() has not run during _initialize(), so the title screen only
	# exists from the first iteration onward. Starting a new game is what
	# unpauses the tree; everything below is frozen until it happens.
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames == 2:
		for d in world.divers:
			party_names.append(String((d as Diver).model_name))
		world._start_battle()
		return false
	if frames == 3 and world.battle != null:
		for e in (world.battle as Battle).party:
			display_names.append(String(e.display_name))
		for e in (world.battle as Battle).enemies:
			display_names.append(String(e.display_name))

	var battle: Battle = world.battle
	if battle != null and not battle.finished.is_connected(_on_finished):
		battle.finished.connect(_on_finished)
	if battle != null:
		_watch(battle)
		_press_something(battle)
	elif result != "":
		# The world is back and steerable. Anything that leaves `battling`
		# true here is the stuck-after-combat bug.
		back_in_world = not world.battling
		return _report()

	if presses > MAX_PRESSES:
		findings.append("NEVER ENDED: %d button presses and no result" % presses)
		return _report()
	if _elapsed() > MAX_WALL_SECONDS:
		findings.append("NEVER ENDED: %.0f seconds and no result" % _elapsed())
		return _report()
	if float(Time.get_ticks_msec() - last_press_ms) / 1000.0 > MAX_IDLE_SECONDS:
		findings.append("NOTHING TO PRESS: %.0f seconds with no enabled button anywhere on the battle screen" % MAX_IDLE_SECONDS)
		return _report()
	return false

func _elapsed() -> float:
	return float(Time.get_ticks_msec() - started_ms) / 1000.0

# Whoever is mid one-shot is swinging or recoiling. Reading it off the
# AnimationPlayer rather than hooking the resolve means the check is on
# what a player would see, not on what the code meant to play.
func _watch(battle: Battle) -> void:
	for e in battle.party:
		if not e.has("actor") or not is_instance_valid(e.actor) or not (e.actor is Diver):
			continue
		var d := e.actor as Diver
		if d.anim == null:
			continue
		var playing := String(d.anim.current_animation)
		var who := String(e.model_name)
		if playing.contains("(Attack)"):
			_note(swings_seen, who, playing)
			_check_aim(battle, e, who)
		elif playing.contains("(Damaged"):
			_note(reactions_seen, who, playing)

# Is the swing pointed at anybody?
#
# Glass_Goat animated this cast for a 2D presentation, so an attack travels
# along the character's own forward axis and nowhere else. Every attack used
# to play on the spot facing whichever way the actor was built facing, which
# meant Marine Man's hammer reaching most of a body length into open water
# while the grunt it was aimed at stood off to one side. Reported as "the
# animations arent aimed at or hit the enemy".
#
# Measured against the nearest living enemy, because the attacker has
# already stepped toward whoever it picked by the time the clip is playing,
# so the nearest one IS the target.
func _check_aim(battle: Battle, entry: Dictionary, who: String) -> void:
	var a := entry.actor as Node3D
	var nearest: Node3D = null
	var best := INF
	for foe in battle.enemies:
		if not foe.has("actor") or not is_instance_valid(foe.actor):
			continue
		if (foe.stats as CombatantStats).hp <= 0:
			continue
		var gap: float = a.global_position.distance_to((foe.actor as Node3D).global_position)
		if gap < best:
			best = gap
			nearest = foe.actor as Node3D
	if nearest == null:
		return

	aim_samples += 1
	if best > MAX_SWING_GAP:
		_note(aim_findings, who, "swung from %.1f m away, further than the %.1f m a swing reaches" % [best, MAX_SWING_GAP])
		return
	var to: Vector3 = nearest.global_position - a.global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	# rotation.y == 0 faces -Z for these models.
	var facing := Vector3(-sin(a.rotation.y), 0.0, -cos(a.rotation.y))
	var off: float = rad_to_deg(facing.angle_to(to.normalized()))
	if off > MAX_SWING_ANGLE:
		_note(aim_findings, who, "swung %.0f deg away from the enemy they were aimed at" % off)

func _note(into: Dictionary, who: String, clip: String) -> void:
	if not into.has(who):
		into[who] = {}
	(into[who] as Dictionary)[clip] = true

# Always the first enabled move that does damage. Picking at random would
# measure a different fight every run, which is the opposite of what a gate
# is for, and picking the literal first button makes Staff_Diver open with
# Heal every turn and lose to a fight she is meant to win.
func _press_something(battle: Battle) -> void:
	# Check the result of a Back press before doing anything else with the
	# menus, since the whole claim is about where it lands you.
	if backing == "moves":
		backing = ""
		if not battle.main_menu.visible:
			findings.append("BACK GOES NOWHERE: Back on the move menu did not return to the main menu")
		backed_out_of_moves = true
		return
	if backing == "targets":
		backing = ""
		if not battle.move_menu.visible:
			findings.append("BACK GOES NOWHERE: Back on the target picker did not return to the move menu")
		backed_out_of_targets = true
		return

	if battle.target_menu.visible:
		if not backed_out_of_targets and is_instance_valid(battle.target_back_btn):
			battle.target_back_btn.pressed.emit()
			presses += 1
			last_press_ms = Time.get_ticks_msec()
			backing = "targets"
			return
		_press_first(battle.target_buttons)
	elif battle.move_menu.visible:
		if not backed_out_of_moves and is_instance_valid(battle.back_btn):
			battle.back_btn.pressed.emit()
			presses += 1
			last_press_ms = Time.get_ticks_msec()
			backing = "moves"
			return
		_press_attacking_move(battle)
	elif battle.main_menu.visible and is_instance_valid(battle.attack_btn) and not battle.attack_btn.disabled:
		battle.attack_btn.pressed.emit()
		presses += 1
		turns += 1
		last_press_ms = Time.get_ticks_msec()

func _press_attacking_move(battle: Battle) -> void:
	var moves: Array = battle._moves_for(battle._acting)
	for i in range(battle.move_buttons.size()):
		var btn := battle.move_buttons[i] as Button
		if not is_instance_valid(btn) or btn.disabled:
			continue
		if i < moves.size() and int((moves[i] as Dictionary).get("power", 0)) <= 0:
			continue
		btn.pressed.emit()
		presses += 1
		last_press_ms = Time.get_ticks_msec()
		return
	_press_first(battle.move_buttons)

func _press_first(buttons: Array) -> void:
	for b in buttons:
		var btn := b as Button
		if is_instance_valid(btn) and not btn.disabled:
			btn.pressed.emit()
			presses += 1
			last_press_ms = Time.get_ticks_msec()
			return

func _on_finished(r: String) -> void:
	result = r

func _report() -> bool:
	print("result       %s after %d party turns, %d button presses, %.0fs wall clock" % [
		result if result != "" else "NONE", turns, presses, _elapsed()])
	print("back in the world: %s" % ("yes" if back_in_world else "NO"))
	for who in party_names:
		var swings: Dictionary = swings_seen.get(who, {}) as Dictionary
		var hits: Dictionary = reactions_seen.get(who, {}) as Dictionary
		print("%-20s %d attack clip(s), %d hit reaction(s): %s" % [
			who, swings.size(), hits.size(),
			", ".join(swings.keys()) if swings.size() > 0 else "no attack seen"])
		if swings.is_empty():
			findings.append("NO SWING: %s never played an attack clip" % who)
		# Every file carries all three characters' attacks, so playing an
		# attack is not the same as playing YOUR attack.
		var fam := Cast.family(who)
		for clip in swings.keys():
			if not String(clip).contains(fam + "_(Attack)"):
				findings.append("WRONG CHARACTER'S SWING: %s (%s) played '%s'" % [who, fam, clip])

	print("backed out of the move menu: %s, out of the target picker: %s" % [
		"yes" if backed_out_of_moves else "NO", "yes" if backed_out_of_targets else "NO"])
	print("aim: %d swing samples checked" % aim_samples)
	if aim_samples == 0:
		findings.append("NEVER CHECKED AIM: no swing was ever caught mid animation")
	for who in aim_findings.keys():
		for note in (aim_findings[who] as Dictionary).keys():
			findings.append("SWING MISSES: %s %s" % [who, note])

	if not backed_out_of_moves:
		findings.append("NO WAY BACK: the move menu's Back button was never usable")
	if not backed_out_of_targets:
		findings.append("NO WAY BACK: the target picker's Back button was never usable")

	# Nobody should be able to end up in a fight where two combatants answer
	# to the same name. #23 was reported against exactly this.
	var seen: Dictionary = {}
	for who in display_names:
		if seen.has(who):
			findings.append("DUPLICATE NAME: two combatants are both called '%s'" % who)
		seen[who] = true
	print("names on screen: %s" % ", ".join(display_names))

	if result == "":
		findings.append("NO RESULT: the fight never emitted one")
	elif not ["won", "lost", "fled"].has(result):
		findings.append("STRANGE RESULT: the fight finished with '%s'" % result)
	elif not back_in_world:
		findings.append("STUCK: the fight finished '%s' and the world is still in battle" % result)
	if turns < 3 and result != "":
		findings.append("TOO SHORT: %d party turn(s), not enough for all three to act" % turns)

	for f in findings:
		print("FINDING  " + f)
	print("FIGHT: clean" if findings.is_empty() else "FIGHT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
