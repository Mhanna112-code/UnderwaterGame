# Captured retired Control Room route

`maze_control_route_0d147b9.json` was generated before production changes,
against PR100 `0d147b9` using the actual PathButton E interaction, waiting for
the 12/13 swings and raised walls, then World serialization. Capture receipt is
in `docs/evidence/maze-box12-route-oct5/legacy-capture.log`.

Command (historical production only):

```sh
godot --headless --path . --script res://verify/maze_box12_route.gd -- --capture-legacy=/private/tmp/pr100-box12-legacy.json
```

This is generated disposable fixture data, not a user's save. The test's
capture-only branch deliberately no longer works on the replacement route:
it requires the removed PathButton. Acceptance tests consume the captured
JSON, crossing old/current coordinate frames, map ownership and selected actors
with original, overlapping and unchanged safe placements. Preserve the fixture;
do not regenerate it from the new layout and call that legacy evidence.
