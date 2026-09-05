# Opens the same opt-in Tethys route the web build exposes at ?boss=1 and
# captures the actual battle framing after the authored swim intro.
# Usage: godot --path . --resolution 1280x720 --script tools/shoot_boss.gd -- /tmp/tethys.png
extends SceneTree

var out_png := "/tmp/tethys-boss.png"
var frames := 0
var world: World

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_png = String(args[0])
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		world._on_title_boss_playtest()
		return false
	if frames < 300:
		return false
	root.get_texture().get_image().save_png(out_png)
	print("shot       %s" % out_png)
	if world.battle != null and not world.battle.enemies.is_empty():
		var boss := world.battle.enemies[0].actor as TethysBoss
		print("boss       %.2fm tall, playing %s" % [boss.height,
			boss.anim.current_animation if boss.anim != null else "NOTHING"])
	return true
