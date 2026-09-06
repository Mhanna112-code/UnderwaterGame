# Contract gate for the data-driven ordinary-enemy move catalogue. It proves
# that an artist's extra attack clip can be kept in the catalogue without
# changing Battle, and that enabled moves remain playable through the same
# production actor interface.
extends SceneTree

var findings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var angler := Goblin.new()
	root.add_child(angler)
	await process_frame
	await process_frame

	var catalogue := EnemyMoves.angler_catalogue()
	_expect(catalogue.size() >= 3,
		"ENEMY MOVES: catalogue omitted delivered Angler attack clips — guards against hard-coding Bite as the only reusable attack")
	var enabled := angler.available_moves()
	_expect(not enabled.is_empty(), "ENEMY MOVES: no enabled move — guards against an enemy turn with no playable attack")
	var target := CombatantStats.new()
	target.hp_max = 100
	target.hp = 100
	for _sample in range(32):
		var chosen := angler.choose_move(target)
		_expect(not chosen.is_empty() and bool(chosen.get("enabled", false)),
			"ENEMY MOVES: selector returned no/disabled move — guards against an ordinary turn bypassing the catalogue")
	for move_value in catalogue:
		var move := move_value as Dictionary
		_expect(move.has_all(["id", "name", "clip", "enabled", "target", "roll_order", "weight", "combat", "verb"]),
			"ENEMY MOVES: %s lacks a declarative move field — guards against a new attack requiring Battle code" % String(move.get("id", "unnamed")))
		_expect(angler.has_clip_fragment(String(move.get("clip", ""))),
			"ENEMY MOVES: %s has no imported clip match — guards against selecting a move that the delivered rig cannot play" % String(move.get("id", "unnamed")))
	for move_value in enabled:
		var move := move_value as Dictionary
		_expect(bool(move.enabled), "ENEMY MOVES: disabled %s leaked into selection — guards against unfinished art entering combat" % String(move.id))
		_expect(String(move.target) == "single", "ENEMY MOVES: enabled %s has an unsupported target scope — guards against silently mis-resolving a move" % String(move.id))
		var length := angler.play_move(move)
		_expect(length > 0.0,
			"ENEMY MOVES: enabled %s did not start — guards against data-driven selection resolving to idle" % String(move.id))

	# A caller gets a deep copy. If presentation/balance code decorates a move
	# during a turn, it must not permanently edit the artist-facing catalogue.
	if not enabled.is_empty():
		(enabled[0] as Dictionary).enabled = false
		_expect(angler.available_moves().any(func(m: Dictionary) -> bool: return String(m.id) == "bite"),
			"ENEMY MOVES: caller mutation changed the catalogue — guards against one turn disabling future attacks")

	angler.queue_free()
	await process_frame
	if findings.is_empty():
		print("ENEMY MOVES: clean — delivered clips catalogue independently; enabled moves play through the reusable actor API")
		quit(0)
		return
	for finding in findings:
		print("FINDING  " + finding)
	print("ENEMY MOVES: %d finding(s)" % findings.size())
	quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
