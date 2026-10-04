# Direction-independent opening encounter trigger.
#
# Bugs caught:
# - OPEN-007/026: heading locks, premature interruption, vertical-only trigger,
#   missing idle fallback, or duplicate encounters.
#
# Usage: godot --headless --path . --script verify/opening_prologue_trigger.gd
extends SceneTree

const TRIGGER_PATH := "res://game/opening_prologue_trigger.gd"

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists(TRIGGER_PATH):
		findings.append("OPEN-007 opening trigger owner is missing")
		_finish()
		return
	var trigger_script := load(TRIGGER_PATH) as Script
	for degrees in range(0, 360, 15):
		var radians := deg_to_rad(float(degrees))
		var direction := Vector3(cos(radians), 0.0, sin(radians))
		var trigger = trigger_script.new()
		trigger.reset(Vector3(8.0, 2.0, -3.0))
		_expect(not trigger.update(Vector3(8.0, 2.0, -3.0) + direction * 2.99, 0.1),
			"OPEN-007 direction %d triggered below movement threshold" % degrees)
		_expect(not trigger.update(Vector3(8.0, 2.0, -3.0) + direction * 3.01, 0.1),
			"OPEN-026 direction %d interrupted exploration at 0.2 seconds" % degrees)
		_expect(not trigger.update(Vector3(8.0, 2.0, -3.0) + direction * 8.0, 3.7),
			"OPEN-026 direction %d interrupted exploration before four seconds" % degrees)
		_expect(trigger.update(Vector3(8.0, 2.0, -3.0) + direction * 3.01, 0.11),
			"OPEN-007 direction %d failed above movement threshold" % degrees)
		_expect(not trigger.update(Vector3(8.0, 2.0, -3.0) + direction * 8.0, 10.0),
			"OPEN-007 direction %d triggered more than once" % degrees)

	var vertical = trigger_script.new()
	vertical.reset(Vector3.ZERO)
	_expect(not vertical.update(Vector3(0.0, 20.0, 0.0), 4.1),
		"OPEN-007 vertical-only movement incorrectly counts as exploration")

	var short_swim = trigger_script.new()
	short_swim.reset(Vector3.ZERO)
	_expect(not short_swim.update(Vector3(2.99, 0.0, 0.0), 4.1),
		"OPEN-007 minimum exploration time incorrectly replaces movement threshold")
	_expect(short_swim.update(Vector3(3.01, 0.0, 0.0), 0.1),
		"OPEN-007 meaningful movement after exploration window does not trigger")

	var idle = trigger_script.new()
	idle.reset(Vector3.ZERO)
	_expect(not idle.update(Vector3.ZERO, 6.9), "OPEN-007 idle fallback fired too early")
	_expect(idle.update(Vector3.ZERO, 0.2), "OPEN-007 idle fallback did not fire near 7 seconds")
	_expect(not idle.update(Vector3.ZERO, 10.0), "OPEN-007 idle fallback fired twice")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING TRIGGER: clean" if findings.is_empty() else "OPENING TRIGGER: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
