# Bug Catalog: hosted core-route playtest repairs

**Created:** 2026-09-25  
**Scope:** regressions found in the normal-entry hosted PR #88 playtest. This
catalog supplements `progression_route.bug-catalog.md`; it is deliberately
about player-visible layout, traversal, and encounter-boundary behavior that
the earlier route-state suite could not prove.

## Public seams

- `Battle.finished(result)`, tutorial Continue button, QTE controls, stage
  viewport and camera are the combat handoff surface.
- `RouteProgression` exposes phase/objective/checkpoint/policy, while World
  exposes the live visible beacon and `Area3D` route trigger.
- A `Goblin` subclass exposes a displayed Node3D model; visual framing is
  observable through its rendered mesh bounds and Battle's stage camera.
- `World._on_battle_finished()` is the observable World return boundary for a
  tutorial, authored route battle, special challenge, or boss preview.

## IO / risk boundaries

- Canvas layout changes after deferred container sort and viewport resize.
- QTE timing uses an animated UI tween and keyboard input.
- Route reachability depends on real 3D collision layers, terrain, guardian
  geometry, and camera direction.
- Imported FBX rigs have materially different bounding-box shapes.
- Browser rendering and real controller/mouse input need hosted evidence in
  addition to headless Control geometry tests.

## Bug catalog

| # | Failure mode | Blast radius / plausibility | Cheapest proof | Status |
| --- | --- | --- | --- | --- |
| 1 | A real tutorial QTE resolves, but its success or miss leaves a zero-height/blank stage or an acknowledgement control outside the viewport. | P0: a new player believes the game froze. The prior test injects Enter and never inspects final screen geometry. | Captured bug / layout integration at 1280×720 and 1920×1080. | first repair |
| 2 | A required tutorial acknowledgement is keyboard-only or visually hidden, so an Enter press advances an apparently frozen screen. | P0: indistinguishable from a soft-lock. Deferred panel sizing can hide the only affordance. | Invariant combined with bug #1: visible, enabled Continue button with in-bounds rect whenever `_tutorial_awaiting_enter` is true. | first repair |
| 3 | A long imported enemy is normalized only by height, so its visible mesh exceeds the stage while the camera uses a smaller capped combat radius. | P1: Frilled Shark hides party/target UI. The current actor radius and mesh width intentionally diverge. | Captured visual-bounds camera test. | second repair |
| 4 | A route beacon exists in state but a player cannot physically reach it from one or more natural approaches because terrain/guardian collision blocks the line. | P1: route looks like an invisible wall. Existing test reaches only the first leg from one directed path. | Physics integration over each leg and multiple approach offsets. | third repair |
| 5 | The HUD says LEFT/RIGHT while the visible beacon is on screen, or both cues are simultaneously active. | P1: player receives contradictory navigation. Current code tests target origin, not the beacon's visible bounds. | Camera-quadrant invariant with one active guidance surface. | third repair |
| 6 | An optional guardian/special challenge begins without saying it is optional, what ability/controls it needs, or how to leave. | P1: an off-route experiment reads as a broken mandatory tutorial. | UI contract test for prompt labels/actions plus hosted manual minigame proof. | later UX repair |
| 7 | The deep route presents as the same bright, collinear empty space as shallows, despite phase transition wording. | P2: depth/progression fiction and pacing fail, while state tests remain green. | Visual environment/route-shape contract plus hosted comparison. | later presentation repair |
| 8 | A normal critical-route loss or boss preview returns to an unnamed/incorrect checkpoint, or an unbalanced Tethys fight is represented as route completion. | P0 for the lab endpoint: player cannot tell whether failure is expected or recoverable. Boss test currently inspects moves using inflated HP, not normal play. | Checkpoint round-trip and boss-preview contract; normal-party boss simulation only once final numbers exist. | later boundary repair |
| 9 | Green/red previews can be understood only by their colour, not by result wording or keyboard navigation. | P1 accessibility/regression: the core quick-read becomes inaccessible or misleading. | Semantic UI contract and desaturated hosted screenshot. | later accessibility repair |
| 10 | A battle cannot identify whether it was a route beat, optional guardian, or other source, so a reported wrong enemy cannot be reproduced. | P1 diagnosis: route/optional content is ambiguous to player and maintainer. | Encounter-source label/log contract across all battle entry paths. | later observability repair |

## Test self-critique

### Bugs #1–2 — QTE final handoff layout

- The test will drive the actual QTE's visual widget and key handler but will
  **not** inject Enter after it resolves. It will assert public visible
  controls, stage size, and World handoff behavior.
- It fails if a refactor leaves the same blank/hidden-control output, and
  passes under a behavior-preserving internal layout refactor because it uses
  Control visibility/rects rather than private helper names.
- Success and timeout are distinct QTE outcomes and both must be covered.

### Bug #3 — Frilled Shark framing

- The test will project actual `MeshInstance3D` AABB corners through the
  public stage camera and require the mesh/overhead presentation to fit.
- It does not assert a magic scale or camera distance, so changing either
  implementation while retaining an in-frame readable fight remains valid.

### Bugs #4–5 — physical route and guidance

- The test must use ordinary World movement/collision; emitting
  `body_entered`, teleporting to a target, or checking only RouteProgression
  state would pass for the shipped invisible-wall bug.
- Camera direction cases test output (one coherent cue), not the current
  `unproject_position` implementation.

## Skipped for now

- Final Tethys balance numbers: Glassgoat's final boss table/encounter
  direction is not supplied. The next repair makes it a labelled preview;
  it does not certify invented final values.
- Canonical diver naming: the inconsistency is recorded, but content-owner
  confirmation is needed before pinning a name in code.
- Exact fog art, final lab set dressing, cutscenes, and audio: these need
  visual/content review, not a brittle pixel or implementation snapshot.
- Full special-minigame skill balance: first make controls understandable;
  separately tune challenge speed/damage after an informed manual playtest.

## Evaluation

### Bugs caught

- **#1 and #2:** both QTE success and timeout initially produced a Continue
  button at y=-3490, a 0px stage, and clipped level-up information at
  1280×720. The source was a transient RichText/Container minimum size sampled
  before its final width settled. Battle now performs one coalesced
  next-frame panel-height settle, after which success and timeout pass at
  1280×720 and 1920×1080 without injecting Enter.

### Bugs characterized

- The existing headless QTE and full tutorial route gates remain green after
  the layout repair; the new windowed gate owns the browser-sized geometry
  that those faster tests deliberately cannot observe.

### Re-evaluation targets

- A valid visible stage does not by itself prove the imported dodge animation
  reads correctly. Its presentation remains a hosted screenshot/GIF review
  item in the next visual-evidence pass.
