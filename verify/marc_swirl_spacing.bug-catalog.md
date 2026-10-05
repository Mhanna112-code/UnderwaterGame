# Marc c035c20 sphere-room spacing admission

## Module and boundaries

SwirlRoom was read completely (263 lines), followed through MazeLevel room
geometry, hazard stepping, Sonar visibility and chest placement. Public setup,
positions, reveal and hit_divers expose real moving hazards. Maze owns active
input, physical Diver swimming and camera. Random phase/mesh scale, physics time,
damage cooldown and knockback are the important boundaries; no files/network
are needed for this bounded test. Ring spacing changes count/clearance only;
damage, speed, bob, knockback, invisibility and aligned vertical layers stay.

Branches: small rooms have no rings; ring count has a minimum; reveal controls
rendering, not damage; cooldown skips another hit; outside-room bodies skip hits;
capsule contact differs from point distance; knockback collides and decays.

## Catalog before implementation

| ID | Failure / risk | Observable test and critique | Status |
|---|---|---|---|
| SWIRL-1 | Old 2m spacing leaves dense columns despite Marc's intended weaving gaps. | Public positions across six valid generated room sizes; independent angular-neighbor chords must leave at least 3.5m center spacing. This fails old output, survives a different ring builder, and checks actual gaps rather than copying RING_SPACING. | valid old red ~2m; repaired output ~4m passes |
| SWIRL-2 | Count changes but actual actors cannot swim to the clear eye, or knockback clips outside walls. | Actual MazeLevel and parsed W/mouse movement for all three divers from a controlled interior approach to the eye, observing position/hits/HP. Placement and disabling unrelated encounters are fixtures, not proof of normal door access or earning. No injected arrival, reward or damage. | headless and serial native pass; initial native timeout remains unaccepted |
| SWIRL-3 | Hidden/visible rocks stop moving or hazard damage disappears after reducing count. | Public timed positions, genuine capsule contact/hit signal and HP observation; rendered native before/after views with revealed fixture. No synthetic hit result or count-only acceptance. | actual orbit/contact and faded native traversal pass |
| SWIRL-4 | Revealed foreground rocks hide the diver/chest even in the clear eye. | Native rendered depth-mask comparison at eight camera angles, with the same posed diver and rocks present/hidden. Independent pixel visibility, not a rectangle/count assertion; normal screenshots supplement the mask. Keep hazard state unchanged. | valid aligned-angle red hides 52–95%; near-camera fade gives zero measured coverage in eight repaired views |
| SWIRL-5 | Diver swims inside the non-solid vortex chest; generic interaction wording hides its meaning. | Actual capsule movement against the real chest must stop outside it; actual nearby caption must say Press E to open, real E/Tween awards one Vortex Key. Generated geometry fixtures do not substitute for this chest consumer. | valid capsule/caption red; 2c32467 vortex subset passes headless/native collision, real E/reward and approach |

## Skipped / limits

Full puzzle route, acquiring Sonar Vision/map/chest and cold persistence belong
to separate pending admissions. No fixed hit-count target: random phase and
input timing affect collisions; native capture is not an independent balance
claim. Existing contains() lacks a Y bound; this port does not change that rule.
Chest solidity/cutscene input ownership and obsolete G copy are other upstream
rows, not silently fixed in this one-constant batch. Final visual/audio round
and browser/native target-platform behavior remain separate gates.

## Evaluation

Spacing red `/tmp/underwater-marc-swirl-red.log` fails all six generated sizes
with ~2m chords; `/tmp/underwater-marc-swirl-green.log` passes with ~4m chords.
Actual room is 124 rocks. `/tmp/underwater-marc-swirl-route-third.log` passes
all three genuine approaches and real contact damage, plus orbit stepping.
Checkpoint and physical first-current route regressions pass without script
errors in `/tmp/underwater-marc-swirl-checkpoint.log` and `-current-route.log`.

Rejected harness runs: first assigned a nonexistent encounter property; second
omitted the click that activates mouse look. Neither is a product defect or a
pass. Initial concurrent native run failed Maxilani's 20-second wall-clock
arrival; its cause is not established, and it remains unaccepted. Serial native
diagnostics show W held, look active, no modal, all actors arriving with real
hits (10→6 HP); `/tmp/underwater-marc-swirl-route-native-serial.log` is a distinct
successful run, not retrospective repair of that timeout.

Native inspection exposed SWIRL-4. Initial observer tests missed it because
hidden MultiMesh transforms were uninitialized, then because elevated/grid-only
camera samples missed the actual columns. Those green runs are inadequate
oracles, not visibility proof. After public reveal/physics initialization,
camera viewpoints aligned with actual inner-column positions reproduce 52–95%
skin occlusion in `/tmp/underwater-marc-swirl-occlusion-red-aligned.log`.
Normal screenshots show the same curtain. Pixel-alpha distance fading is
presentation-only, using documented BaseMaterial3D near-distance behavior:
https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#class-basematerial3d-property-distance-fade-min-distance
The same eight rendered views report zero skin coverage after repair in
`/tmp/underwater-marc-swirl-occlusion-green-first.log`. Angles 0/4 inspected.
Physical faded-rock contact rerun passes in
`/tmp/underwater-marc-swirl-route-native-fade.log`. The body still takes real
hits and knockback; hidden/transparent presentation does not remove hazards.

Captures: `/Volumes/Totallynotaharddrive/underwater-marc-swirl.qtnHg4`. Frozen
eye-camera fixtures are not real reward/chest access or normal Sonar earning;
the existing non-solid chest can intersect a deliberately centred fixture.
Chest collision/cutscene input admission remains separate. No browser, complete
route, target-platform, listening or final polish acceptance is implied.

Next native inspection exposed actual swimming into the nonsolid chest, not just
the deliberately centred frozen fixture. Captured red
`/tmp/underwater-marc-swirl-chest-red-final.log` records minimum capsule approach
0.00001m and generic caption. Marc 2c32467 vortex-chest collision/Press E copy
is carried over; map-chest counterpart remains pending because that chest is
not admitted yet. Actual key reward already worked; it is pinned, not claimed
as newly repaired. Repaired headless `-chest-green.log` and native
`-final-native.log` pass all three physical approaches, stopped capsule, caption,
real E/Tween/key and genuine contact. Final native approach/eye captures were
inspected with clear diver beside the solid chest. Settled-prompt capture rerun
passes in `/tmp/underwater-marc-swirl-settled-native.log`; inspected eye capture
shows the diver beside the chest and readable Press E to open. Initial capture
timing showed the preceding position's HUD copy. Updated public checkpoint
cold-load/real-defeat regression also passes in
`/tmp/underwater-marc-swirl-final-checkpoint.log` without script errors.
An earlier test tried nonexistent popup.close(); it is excluded as a harness
error and replaced by real Escape only when its actual panel is visible.
