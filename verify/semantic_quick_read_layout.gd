# Playtest repair: semantic Quick Read text remains visible with the live
# target preview at browser resolution. This guards against a colour-only
# regression and against the extra accessibility line collapsing the stage.
#
# MUST run windowed:
#   godot --path . --resolution 1280x720 --script verify/semantic_quick_read_layout.gd
#   godot --path . --resolution 1920x1080 --script verify/semantic_quick_read_layout.gd
extends SceneTree

const SETTLE_FRAMES := 10

var battle: Battle
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	if viewport.size.x < 1000.0 or viewport.size.y < 600.0:
		findings.append("SEMANTIC QUICK READ LAYOUT requires a browser-sized window, got %s" % viewport.size)
		_report()
		return
	battle = Battle.new()
	root.add_child(battle)
	for _i in SETTLE_FRAMES:
		await process_frame
	battle._acting = battle.party[0]
	battle._start_party_turn(battle._acting)
	battle._pending_move = CombatMoves.SCUBA[0] # Electric Touch
	battle._show_stat_preview(battle._pending_move, battle.enemies[0] as Dictionary)
	for _i in 3:
		await process_frame
	var summary := battle.get("_quick_read_summary") as Label
	_expect(summary != null and summary.visible,
		"SEMANTIC QUICK READ is not visible during a live target preview")
	if summary != null:
		_expect("Benefit:" in summary.text and "Opening: enemy EVA -3" in summary.text,
			"SEMANTIC QUICK READ lost its required non-colour language: '%s'" % summary.text)
		_expect(viewport.encloses(summary.get_global_rect()),
			"SEMANTIC QUICK READ is clipped: %s in %s" % [summary.get_global_rect(), viewport])
	_expect(battle._stage_container.size.y >= 160.0 and viewport.encloses(battle._stage_container.get_global_rect()),
		"SEMANTIC QUICK READ collapsed or clipped the live battle stage: %s" % battle._stage_container.get_global_rect())
	battle.queue_free()
	await process_frame
	_report()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _report() -> void:
	for finding in findings:
		push_error(finding)
	print("SEMANTIC QUICK READ LAYOUT: clean" if findings.is_empty() else "SEMANTIC QUICK READ LAYOUT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
