# Ordinary random encounters must expose all three delivered enemy models,
# rather than making the Swordfish/Frilled Shark guardian-only preview assets.
extends SceneTree

# 48 independent actor rolls makes a one-species sample vanishingly unlikely
# while still exercising real Battle construction rather than a private helper.
const SAMPLES := 48
var findings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(EnemyRoster.id_for_roll(0.0) == "angler" and EnemyRoster.id_for_roll(0.32) == "angler"
		and EnemyRoster.id_for_roll(0.34) == "swordfish_duelist" and EnemyRoster.id_for_roll(0.65) == "swordfish_duelist"
		and EnemyRoster.id_for_roll(0.67) == "frilled_shark" and EnemyRoster.id_for_roll(0.9999) == "frilled_shark",
		"ORDINARY ROSTER: three-way roll boundary selects Angler, then Swordfish, then Frilled Shark — guards against an unreachable roster entry")
	_expect(Battle.encounter_intro([{"display_name": "Swordfish Duelist"}]) == "Swordfish Duelist blocks the way!",
		"ORDINARY ROSTER: lone battle announces the visible enemy — guards against stale Angler-only combat copy")

	seed(20260906)
	var seen: Dictionary = {}
	for _sample in range(SAMPLES):
		var battle := Battle.new()
		root.add_child(battle)
		await process_frame
		await process_frame
		for entry_value in battle.enemies:
			var actor := (entry_value as Dictionary).actor as Goblin
			var enemy_id := actor.enemy_id() if actor != null else "none"
			seen[enemy_id] = true
			_expect(enemy_id in EnemyRoster.ORDINARY_IDS,
				"ORDINARY ROSTER: every random actor has a declared ordinary identity — guards against bad roster dispatch (got '%s')" % enemy_id)
		battle.queue_free()
		await process_frame
	_expect(seen.has("angler") and seen.has("swordfish_duelist") and seen.has("frilled_shark"),
		"ORDINARY ROSTER: seeded normal battles include Angler, Swordfish and Frilled Shark — guards against any one being unreachable (saw %s)" % [seen.keys()])

	if findings.is_empty():
		print("ORDINARY ROSTER: clean — random packs draw Angler, Swordfish and Frilled Shark; fixed guardians remain site-selected")
		quit(0)
		return
	for finding in findings:
		print("FINDING  " + finding)
	quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
