# Captures review evidence for the Group_StatsV2 vertical slice.
#
# Usage:
#   godot --path . --script tools/shoot_combat_v2.gd -- /tmp/v2-result.png result
#   godot --path . --script tools/shoot_combat_v2.gd -- /tmp/v2-target.png target
extends SceneTree

var out_png := "/tmp/v2-combat.png"
var mode := "result"
var frames := 0
var world: Node3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_png = String(args[0])
	if args.size() > 1:
		mode = String(args[1])
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames == 2:
		world._start_battle()
		return false
	if frames == 4:
		_stage_evidence()
		return false
	if frames < 8:
		return false
	root.get_texture().get_image().save_png(out_png)
	print("V2 EVIDENCE  %s (%s)" % [out_png, mode])
	return true

func _stage_evidence() -> void:
	var battle := world.battle as Battle
	battle._acting = battle.party[0]
	battle._start_party_turn(battle._acting)
	battle._refresh_queue_row()
	if mode == "moves":
		battle._show_moves()
		return
	if mode == "formulas":
		battle._show_moves()
		battle._toggle_move_details()
		return
	if mode == "target":
		battle._show_moves()
		battle._on_move_chosen(CombatMoves.SCUBA[0])
		return
	var target := battle.enemies[0] as Dictionary
	var target_stats := target.stats as CombatantStats
	target_stats.evasion = 2
	target_stats.evasion_current = 2
	var attacker := battle._acting.stats as CombatantStats
	var electric := CombatRules.resolve(attacker, target_stats, CombatMoves.SCUBA[0])
	var stabbing := CombatRules.resolve(attacker, target_stats, CombatMoves.SCUBA[1])
	battle._refresh_bar(target)
	battle._show_combat_feedback(target, stabbing)
	var stripped := attacker.effective_accuracy() if not (electric.effects as Array).is_empty() else 0
	battle._log("Electric Touch stripped %d EVA  •  Scuba Stabbing applied Bleed 2" % stripped)
