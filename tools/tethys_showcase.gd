# Captures the actual PR #54 battle scene while explicitly playing every
# character-motion category Glassgoat needs to review. The clip banner makes
# the resulting movie/GIF auditable instead of asking reviewers to infer which
# imported take is on screen.
#
# Usage:
#   godot --path . --resolution 1280x720 --write-movie /tmp/tethys-rig.avi \
#     --fixed-fps 30 --script tools/tethys_showcase.gd
extends SceneTree

const PLAYBACK_SPEED := 1.8

var battle: Battle
var boss: TethysBoss
var banner: Label

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	battle = Battle.new()
	battle.boss_encounter = true
	battle.boss_intro_enabled = false
	root.add_child(battle)
	await process_frame
	await process_frame

	boss = battle.enemies[0].actor as TethysBoss
	boss.anim.speed_scale = PLAYBACK_SPEED
	_build_banner()

	await _show("Idle", "idle", 0.75)
	await _show("Swim Start", "swim_start")
	await _show("Swim Loop", "swim_loop", 0.8)
	await _show("Swim End", "swim_end")
	await _show("Double Scratch", "double_cratch")
	await _show("Tail Sweep", "tail_sweep")
	await _show("Poison Breath", "poison_breath")
	await _show("Tail Slam", "tail_slam")
	await _show("Tongue Slayer", "tongue_slayer")
	await _show("Spinning Death", "spinning_death")
	await _show("Weak Hit", "weak_hit")
	await _show("Strong Hit", "strong_hit")
	await _show("Death", "death")
	await _show("Idle (review complete)", "idle", 0.8)
	quit()

func _build_banner() -> void:
	var backing := ColorRect.new()
	backing.color = Color(0.015, 0.04, 0.08, 0.88)
	backing.position = Vector2(24, 20)
	backing.size = Vector2(420, 54)
	battle.add_child(backing)

	banner = Label.new()
	banner.position = Vector2(42, 28)
	banner.size = Vector2(388, 40)
	banner.add_theme_font_size_override("font_size", 24)
	banner.add_theme_color_override("font_color", Color("88e8ff"))
	battle.add_child(banner)

func _show(label: String, key: String, fixed_seconds: float = -1.0) -> void:
	banner.text = "NON-HUMANOID RIG  •  %s" % label
	battle._log("Animation proof: %s" % label)
	var source_length := boss.play(key)
	var wait_seconds := fixed_seconds if fixed_seconds > 0.0 else source_length / PLAYBACK_SPEED
	await create_timer(maxf(0.45, wait_seconds)).timeout
