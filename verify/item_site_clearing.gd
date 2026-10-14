# Item encounter sites disappear only after their enemy is beaten and the
# item is won - never just because the item is owned.
#
# Bugs caught:
# - CLEAR-01: owning a site's item (e.g. from elsewhere) removes the site.
# - CLEAR-02: running from / losing a site's fight clears it.
# - CLEAR-03: winning a site's fight does not clear it (fight retriggers or
#   the red circle stays), or the clear is not saved.
#
# Usage: godot --headless --path . --script verify/item_site_clearing.gd
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	world.title_screen.close()
	paused = false
	world.random_encounters_enabled = true
	var site: Dictionary = {}
	for spot in ItemGuardian.spots():
		if not bool(spot.get("special", false)):
			site = spot
			break
	var site_id := String(site.get("site", site.item))
	var diver := world.divers[world.active] as Diver

	# CLEAR-01: owning the item alone keeps the site.
	world.key_items.append(String(site.item))
	world._inside_item_site_id = ""
	diver.position = site.at
	_expect(world._try_trigger_item_site(diver) and world.battling, "CLEAR-01 owning the item removed the site")
	# CLEAR-02: fleeing doesn't clear it.
	world.battle.finished.emit("fled")
	await process_frame
	_expect(not world.cleared_item_sites.has(site_id), "CLEAR-02 fleeing cleared the site")
	# CLEAR-03: winning clears it, stops the fight and is saved. (Back on the
	# site: the diver drifts up after a fight, and a site only triggers inside
	# the minimap's height window.)
	world._inside_item_site_id = ""
	diver.position = site.at
	world._try_trigger_item_site(diver)
	_expect(world.battling, "CLEAR-03 site did not retrigger after fleeing")
	world.battle.finished.emit("won")
	await process_frame
	_expect(world.cleared_item_sites.has(site_id), "CLEAR-03 winning did not clear the site")
	world._inside_item_site_id = ""
	diver.position = site.at
	_expect(not world._try_trigger_item_site(diver) and not world.battling, "CLEAR-03 cleared site still starts a fight")
	# HEIGHT-01: a site off the minimap (too far above it) doesn't trigger.
	var other: Dictionary = {}
	for spot in ItemGuardian.spots():
		if String(spot.get("site", spot.item)) != site_id and not bool(spot.get("special", false)):
			other = spot
			break
	world._inside_item_site_id = ""
	diver.position = (other.at as Vector3) + Vector3(0, MiniMap.MARKER_HEIGHT_RANGE + 1.0, 0)
	_expect(not world._try_trigger_item_site(diver) and not world.battling, "HEIGHT-01 a site above the minimap's height window still triggered")
	diver.position = other.at
	_expect(world._try_trigger_item_site(diver) and world.battling, "HEIGHT-01 a site inside the height window did not trigger")
	world.battle.finished.emit("fled")
	await process_frame
	_expect((world._serialize_state().get("cleared_item_sites", []) as Array).has(site_id), "CLEAR-03 clear not saved")

	world.queue_free()
	await process_frame
	root.get_node("GameAudio").release_streams_for_shutdown()
	print("ITEM SITE CLEARING: clean" if findings.is_empty() else "ITEM SITE CLEARING: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
		print("FINDING  ", message)
