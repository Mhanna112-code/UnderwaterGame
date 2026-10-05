# Poster-boundary integration — October 5

Bounded admission of PR97 bba8b80's poster fences into PR100. This does not
complete the full integration contract, update the hosted build, or authorize
merge. Production base:77cd7b7; resulting source fingerprints are in
`source.sha256`. Godot4.7.1 on AppleM1/macOS; native capture uses Metal Forward+
at1280×720. All accepted commands exited0 with no script/engine errors.

## Caught defect and repair

`original-red.log` is the unchanged captured real-W test at77cd7b7. Maxilani
starts at(278.3042,2,37.13657), swims through the missing western fence, and
ends atz43.05341 beyond the poster line39.13657. Terminal result1.

The production change carries Marc's two static poster fences: east to Box6,
west to the authored maze edge. It preserves the embedded west-perimeter entry
gap after the laboratory. A nonpositive eastern gap does not build an invalid
box. No second fence/save owner or resource-recovery policy is added.

## Behavioral receipts

| Receipt | Observable contract |
|---|---|
| `matrix.log` | 48 actual-input swimming cases:3 capsules ×2 gaps ×2 positions ×2 directions ×2 legal heights;636 physical rays cover the gaps/seams. The high approach derives from the real ceiling and capsule. Actors genuinely move, then stop before crossing. |
| `restore-living.log`, `restore-downed.log` | 36+36 generated JSON cases:3 selected actors ×2 saved coordinate frames ×2 gaps ×3 saved side offsets. All capsules end clear; active actor really swims away. Includes one downed member and Musashi at0 Oxygen; HP/Oxygen/evasion/Bleed, inventory, map and generic keys survive. These are generated live-restore cases, not newly captured historical disk fixtures. |
| `ramp.log` | Actual World→maze→World swimming, held-sink floor seams, single camera/HUD/Tab/R owner and first-person departure remain usable. Laboratory victory is not a prerequisite. |
| `box12-chest.log` | Three actual draft capsules, real chest E/L,36 historical raised-route JSON cases and raw legacy cold Title Load in guarded slot918367. Player slots remain untouched. |
| `world-chest.log` | Actual shared-World pre-map approach, chest acquisition and return through the independent ramp; no map grant/collision bypass. |
| `current-route.log` | Actual normal movement and L/E/Ctrl+E through the first current channel; retained collision/current contract. |
| `native.log`, `poster-west-blocked.png` | Real-W captured case on native Metal: stop atz38.20691. Uses the normal shared-maze camera. |

These static BoxShape bodies resolve saved overlap through normal physics;
the generated placements did not require a bespoke save migration. That is a
characterization, not an assertion that every campaign save is verified.

The still shows a stopped diver in dark open water, not a visible fence. It
cannot alone prove the collision behavior; the coordinate/movement receipts
do that. This is a native renderer receipt, **not final campaign visual quality**
or browser/Windows/Linux acceptance.

## Observer failures / limits

- An initial fixed5m high approach intersected the existing ceiling. The test
  correctly rejected that fixture before acceptance. Legal high approaches now
  come from an independent upward physical ray, not a weakened crossing rule.
- `rejected-numeric-observer.log` reports effect loss from comparing a literal
  integer Dictionary to decoded JSON float values. Semantic Bleed level/turn
  comparisons pass; production stats were not changed to placate the observer.
- Encounters/strong-room lessons are disabled in isolated boundary placements.
  Those cases are not onboarding, ordinary campaign, balance or discovery proof.
- Full suite, final integrated browser journeys, camera readability repair,
  hall whirlpools/autosaves, campaign pivot and same-source exports remain open.
  The public PR100 preview still serves bffe1b5.

## Reproduction

From the repository root, using Godot4.7.1:

```sh
godot --headless --path . --script res://verify/maze_poster_barriers.gd
godot --headless --path . --script res://verify/maze_poster_barriers.gd -- --matrix
godot --headless --path . --script res://verify/maze_poster_barriers.gd -- --restore
godot --headless --path . --script res://verify/maze_poster_barriers.gd -- --restore --downed
godot --headless --path . --script res://verify/embedded_maze.gd
godot --headless --path . --script res://verify/maze_box12_route.gd
godot --headless --path . --script res://verify/marc_earned_map.gd -- --world-acquisition
godot --headless --path . --script res://verify/maze_current_route.gd
```

For a native receipt, pass `--capture-dir=` naming an existing disposable
directory. The four new boundary commands are registered in `verify/gates.sh`.
Exit0 alone is insufficient: reject script/engine errors as the harness does.
