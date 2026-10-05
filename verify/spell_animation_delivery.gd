extends SceneTree
## SPELL-ANIM-01/02/03: authored spells must move the actual runtime rig,
## while the partial delivery must not remove base/movement animations.
const CASES := {
	"Staff_Diver": {
		"Swift Strike": "Scuba_(Attack) Swift Slash",
		"Riptide Slash": "Scuba_(Attack) Riptide Slash",
	},
	"Prototype_1(1910)": {
		"Blinding Silt": "Proto1_(Attack)Blinding)Silt",
		"Exploit Opening": "Proto1_(Attack)Blinding)Exploit_Opening",
		"Precise Jab": "Proto1_(Attack)Precise_Jab",
	},
	"Prototype_V(1922)": {
		"Guard Break": "Proto5_Guard_Break",
		"Heavy Slam": "Proto5_Heavy_Slam",
		"Mending Current": "Proto5_Mending Current",
		"Tidal Revival": "Proto5_Tidal_Revival",
	},
}
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for model_name in CASES:
		var diver := Diver.new()
		diver.model_name = model_name
		root.add_child(diver)
		await process_frame
		diver.set_process(false)
		diver.set_physics_process(false)
		var skeleton := _skeleton(diver)
		for move_name in CASES[model_name]:
			var expected: String = CASES[model_name][move_name]
			var chosen := Cast.ability(model_name, move_name)
			if chosen != expected:
				findings.append("SPELL-ANIM-01 %s/%s uses generic %s" % [model_name, move_name, chosen])
				continue
			var duration := diver.play_clip(chosen)
			if duration <= 0.05:
				findings.append("SPELL-ANIM-01 %s did not play" % move_name)
				continue
			diver.anim.seek(0.0, true)
			var initial := _poses(skeleton)
			var changed := 0
			for fraction in [0.2, 0.4, 0.6, 0.8]:
				diver.anim.seek(duration * fraction, true)
				var poses := _poses(skeleton)
				for index in range(poses.size()):
					if not poses[index].is_equal_approx(initial[index]):
						changed += 1
			if changed < 8:
				findings.append("SPELL-ANIM-03 %s resolves but barely moves the runtime rig (%d)" % [move_name, changed])
			print("SPELL POSE|%s|%s|%.3fs|changed=%d" % [model_name, move_name, duration, changed])
		for motion in ["idle", "swim_start", "swim", "swim_end", "hurt", "hurt_bad", "down_start", "down", "win"]:
			if diver.resolve(Cast.motion(model_name, motion)).is_empty():
				findings.append("SPELL-ANIM-02 lost %s/%s" % [model_name, motion])
		for move in Battle.BASE_MOVES[model_name]:
			if diver.resolve(Cast.ability(model_name, String(move.name))).is_empty():
				findings.append("SPELL-ANIM-02 lost base move %s" % move.name)
		diver.queue_free()
		await process_frame
	for finding in findings:
		print("FINDING ", finding)
	print("SPELL ANIMATION DELIVERY: ", "clean" if findings.is_empty() else "failed")
	quit(0 if findings.is_empty() else 1)

func _skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _skeleton(child)
		if found != null:
			return found
	return null

func _poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for index in range(skeleton.get_bone_count()):
		poses.append(skeleton.get_bone_pose(index))
	return poses
