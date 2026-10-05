extends SceneTree
## MSG-1/2: public queue output must obey FIFO, newest-four and toggle coalescing.
const Queue = preload("res://game/orange_message_queue.gd")
var findings: Array[String] = []
var cases := 0

func _initialize() -> void:
	for count in range(1, 13):
		var queue = Queue.new()
		queue.push("Warning", 2.0)
		for i in range(1, count + 1):
			queue.push("Reward %d" % i, 3.0)
		var retained: Array[String] = []
		for i in range(maxi(1, count - 3), count + 1):
			retained.append("Reward %d" % i)
		_expect(queue.current_text() == "Warning" and queue.pending_messages() == retained,
			"MSG-1/2 unique notices overwrite current or ignore newest-four FIFO")
		# Duplicate pending message doesn't add an entry or change its order.
		queue.push(retained[0])
		_expect(queue.pending_messages() == retained, "MSG-2 duplicate pending notice changes FIFO")
		queue.advance(1.5)
		queue.push("Warning", 1.0)
		_expect(is_equal_approx(queue.seconds_left(), 1.0), "MSG-2 repeat current notice doesn't renew readable time")
		queue.push("Warning", 0.1)
		_expect(is_equal_approx(queue.seconds_left(), 1.0), "MSG-2 shorter duplicate truncates current readable time")
		queue.advance(1.0)
		for expected in retained:
			_expect(queue.current_text() == expected and is_equal_approx(queue.seconds_left(), 3.0), "MSG-1 retained message isn't displayed once in FIFO with its full duration")
			queue.advance(3.0)
		_expect(queue.current_text().is_empty() and queue.pending_messages().is_empty(), "MSG-1 drained queue replays messages")
		cases += 1
	for count in range(9):
		for toggles in range(1, 25):
			var queue = Queue.new()
			queue.push("Found the Ancient Relic")
			for i in range(count):
				queue.push("Loot %d" % i)
			for i in range(toggles):
				queue.push("Random encounters on." if i % 2 == 0 else "Random encounters off.")
			var expected: Array[String] = []
			for i in range(maxi(0, count - 3), count):
				expected.append("Loot %d" % i)
			expected.append("Random encounters on." if toggles % 2 == 1 else "Random encounters off.")
			_expect(queue.current_text() == "Found the Ancient Relic" and queue.pending_messages() == expected,
				"MSG-2 repeated encounter toggles displace current reward, duplicate or evict additional loot")
			cases += 1
	# SV-5: independently coalesce both controls, never all toggles together.
	# Sonar/R spam must retain both rewards and each control's latest state.
	for sonar_toggles in range(1, 17):
		for encounter_toggles in range(1, 17):
			var mixed = Queue.new()
			mixed.push("Sonar on.")
			mixed.push("Door unlocked")
			mixed.push("Relic earned")
			for i in sonar_toggles:
				mixed.push("Sonar off." if i % 2 == 0 else "Sonar on.")
			for i in encounter_toggles:
				mixed.push("Random encounters off." if i % 2 == 0 else "Random encounters on.")
			var latest_sonar := "Sonar off." if sonar_toggles % 2 == 1 else "Sonar on."
			var latest_r := "Random encounters off." if encounter_toggles % 2 == 1 else "Random encounters on."
			_expect(mixed.current_text() == latest_sonar and mixed.pending_messages() == ["Door unlocked", "Relic earned", latest_r],
				"SV-5 mixed Q/R toggles lose either control's latest state or queued rewards")
			cases += 1
	var queue = Queue.new()
	queue.push("Random encounters off.")
	queue.push("Door unlocked", 8.0)
	queue.advance(2.0)
	queue.push("Random encounters on.")
	_expect(queue.current_text() == "Random encounters on." and queue.pending_messages() == ["Door unlocked"], "MSG-2 active toggle renewal deletes queued milestone")
	queue.advance(4.0)
	_expect(queue.current_text() == "Door unlocked" and is_equal_approx(queue.seconds_left(), 8.0), "MSG-1 authored per-message duration is lost")
	queue.advance(-10.0)
	_expect(is_equal_approx(queue.seconds_left(), 8.0), "MSG-3 negative time changes readable lifetime")
	queue.push("Later")
	queue.push("")
	_expect(queue.current_text().is_empty() and queue.pending_messages().is_empty(), "MSG-4 clear text leaves stale pending messages")
	for finding in findings:
		print("FINDING ", finding)
	print("ORANGE MODEL: clean|generated=%d" % cases if findings.is_empty() else "ORANGE MODEL: failed")
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
