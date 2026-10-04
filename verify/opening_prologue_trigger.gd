# OPEN-007/026/035: no idle/blocked/passive trigger; four seconds of actual
# requested swimming in any horizontal direction starts exactly one Angler.
extends SceneTree

const Trigger := preload("res://game/opening_prologue_trigger.gd")
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Heading/frame-rate/prior-idle property matrix. Expected outcomes describe
	# usable control, not the trigger's internal elapsed fields.
	for degrees in range(0, 360, 15):
		for dt in [0.016, 0.033, 0.1, 0.2]:
			for prior_idle in [0.0, 7.1, 60.0, 3600.0]:
				var trigger := Trigger.new()
				var origin := Vector3(8.0, 2.0, -3.0)
				trigger.reset(origin)
				_expect(not trigger.update(origin, prior_idle, false), "OPEN-035 idle time starts combat")
				var radians := deg_to_rad(float(degrees))
				var direction := Vector3(cos(radians), 0.0, sin(radians))
				var seconds := 0.0
				var fired := false
				while seconds < 4.3 and not fired:
					seconds += dt
					fired = trigger.update(origin + direction * seconds * 5.0, dt, true)
					if seconds < 3.99:
						_expect(not fired, "OPEN-035 idle time consumed the four-second swimming window")
				_expect(fired, "OPEN-007 requested swim did not trigger: heading=%d dt=%.3f idle=%.1f" % [degrees, dt, prior_idle])
				_expect(not trigger.update(origin + direction * 40.0, 10.0, true), "OPEN-007 fired more than once")

	var blocked := Trigger.new()
	blocked.reset(Vector3.ZERO)
	_expect(not blocked.update(Vector3.ZERO, 60.0, true), "OPEN-035 blocked input starts combat")
	_expect(not blocked.update(Vector3(0.0, 20.0, 0.0), 60.0, true), "OPEN-007 vertical-only motion starts combat")
	_expect(not blocked.update(Vector3(50.0, 0.0, 0.0), 60.0, false), "OPEN-035 passive movement starts combat")
	_expect(not blocked.update(Vector3(51.0, 0.0, 0.0), 0.2, true), "OPEN-035 blocked/passive time banks the swimming window")

	var short_swim := Trigger.new()
	short_swim.reset(Vector3.ZERO)
	for step in range(1, 51):
		_expect(not short_swim.update(Vector3(step * 0.05, 0.0, 0.0), 0.1, true), "OPEN-007 below-three-metre swimming starts combat")
	_expect(short_swim.update(Vector3(3.1, 0.0, 0.0), 0.1, true), "OPEN-007 sufficient swimming and displacement do not trigger")
	short_swim.reset(Vector3(3.1, 0.0, 0.0))
	_expect(not short_swim.update(Vector3(6.2, 0.0, 0.0), 0.1, true), "OPEN-035 reset retained previous swimming time")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING TRIGGER: clean" if findings.is_empty() else "OPENING TRIGGER: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
