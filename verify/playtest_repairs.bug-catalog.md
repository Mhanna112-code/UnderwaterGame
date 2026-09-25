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
| 4 | A route beacon exists in state but a player cannot physically reach it from one or more natural approaches because terrain/guardian collision blocks the line. | P1: route looks like an invisible wall. Existing test reaches only the first leg from one directed path. | Physics integration over each leg and multiple approach offsets. | repaired: full collision matrix |
| 5 | The HUD says LEFT/RIGHT while the visible beacon is on screen, or both cues are simultaneously active. | P1: player receives contradictory navigation. Current code tests target origin, not the beacon's visible bounds. | Camera-quadrant invariant with one active guidance surface. | repaired: rendered-bound contract |
| 6 | An optional guardian/special challenge begins without saying it is optional, what ability/controls it needs, or how to leave. | P1: an off-route experiment reads as a broken mandatory tutorial. | UI contract test for prompt labels/actions plus hosted manual minigame proof. | repaired: explicit choice + practice |
| 7 | The deep route presents as the same bright, collinear empty space as shallows, despite phase transition wording. | P2: depth/progression fiction and pacing fail, while state tests remain green. | Visual environment/route-shape contract plus hosted comparison. | repaired: phase presentation contract |
| 8 | A normal critical-route loss or boss preview returns to an unnamed/incorrect checkpoint, or an unbalanced Tethys fight is represented as route completion. | P0 for the lab endpoint: player cannot tell whether failure is expected or recoverable. Boss test currently inspects moves using inflated HP, not normal play. | Checkpoint round-trip and boss-preview contract; normal-party boss simulation only once final numbers exist. | repaired: explicit preview + named recovery |
| 9 | Green/red previews can be understood only by their colour, not by result wording or keyboard navigation. | P1 accessibility/regression: the core quick-read becomes inaccessible or misleading. | Semantic UI contract and desaturated hosted screenshot. | later accessibility repair |
| 10 | A battle cannot identify whether it was a route beat, optional guardian, or other source, so a reported wrong enemy cannot be reproduced. | P1 diagnosis: route/optional content is ambiguous to player and maintainer. | Encounter-source label/log contract across all battle entry paths. | repaired: source label contract |
| 11 | Opening optional Combat Help can consume a pending route handoff or leave the world paused, while counter lessons can drift away from the encounter they introduce. | P1: optional detail becomes a soft-lock or fails to teach the actual next fight. | Route-card/UI lifecycle plus full World/Battle playthrough. | repaired: Help-return + counter cards |

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

- The test starts a real World-to-Battle encounter with the authored Frilled
  Shark roster and projects every actual imported mesh corner through the live
  `Camera3D`.
- It preserves a behavioral composition contract: mesh bounds must fit the
  live stage, cannot consume more than 45% of its width, and cannot cover a
  player fighter's body point. It does not assert a model scale or camera
  distance.

### Bugs #4–5 — physical route and guidance

- `verify/progression_route_traversal_matrix.gd` starts each route beat from
  its prior location and left/center/right approach offsets, then drives
  ordinary `Diver.swim()`/`move_and_slide()` into the live `Area3D` trigger.
  It never emits `body_entered`, calls the route dispatch helper, or assigns a
  target position to the diver.
- Camera direction cases test output (one coherent cue), not the current
  `unproject_position` implementation.

**Repaired:** every beat now sits 8–12 seconds of ordinary swimming from its
predecessor and the full matrix drives each of those seven legs from left,
center, and right lateral approaches into the real `Area3D` collision. The
route deliberately goes around the optional guardian and the high corridor
blockade rather than silently treating either as a core-path detour. The
tutorial's hovering arrow is hidden during free route play; `World` projects
the rendered beacon's bounds and shows the readable HUD direction only when
those bounds are off-screen. `verify/route_guidance_visibility.gd` exercises
fully visible, partially visible, and off-screen camera cases on a real
1280×720 SubViewport.

### Bug #6 — optional guardian reads as an unexplained mandatory gate

- **Test type:** World/UI contract.
- **Description string:**
  > `optional guardian: prompt identifies the off-route reward, objective, controls, practice, entry, and leave paths — guards against an unexplained artifact challenge masquerading as mandatory progression`
- **What it catches:** guardian collision jumps straight into an opaque
  challenge, fails to say that it is optional, hides its controls, or makes
  leaving consume the reward/site.
- **Repaired:** the real site now opens `Optional Guardian Challenge` with the
  reward and objective, all three named diver/ability control patterns,
  `Practice Controls`, `Enter Challenge`, and `Leave`. The public prompt
  contract is exercised against a real World guardian; leaving resumes play
  without a Battle or a consumed site.

### Bug #8 — unproven boss boundary and opaque loss recovery

- **Test type:** route/battle boundary contract plus save/load round trip.
- **Description string:**
  > `progression route: Mermaid Freak reaches an explicit no-boss preview and a loss names its secured full-resource checkpoint — guards against an unbalanced hidden-item wall`
- **What it catches:** a normal route arrival creates Tethys Battle before it
  has a normal-party balance pass, or defeat hides the precise checkpoint and
  recovery outcome that the save will apply.
- **Repaired:** `lab_mermaid_freak` is a `preview` beat. World resolves it to
  a labelled transition card with no Battle; the separate `?boss=1` review
  remains intact. The physical traversal matrix covers all three approaches,
  and route lifecycle/source gates verify no battle opens. The real checkpoint
  round-trip now asserts the defeat screen names Shallows Capstone and its
  full-HP/O2 recovery before recreating World from the saved checkpoint.

### Bug #11 — optional detail consumes the route or counter lesson drifts

- **Test type:** UI lifecycle plus real route progression.
- **Description string:**
  > `progression route: Combat Help returns to the same objective and the Deep cards name their immediate counter — guards against optional teaching that blocks or misdirects progression`
- **Repaired:** requesting the route card’s Combat Help opens the optional
  reference, closes back to an unpaused world, and leaves Shallows active.
  The real playthrough asserts Deep entry names Swordfish/Electric
  Touch/Evasion and the post-Swordfish card names Sea Urchin/Weaken/Defense.

### Bug #10 — encounter provenance

- **Test type:** World/UI contract.
- **Description string:**
  > `progression route: every battle visibly names its authored or optional source — guards against an Angler report that cannot be tied to a route beat`
- **What it catches:** a displayed fish has no replayable context, or a route
  source drifts from its declared objective and roster.
- **Repaired:** `Battle` receives a source label at World’s entry boundary and
  renders it above the turn queue. Route labels name the zone/beat/roster;
  tutorial, optional guardian, and wandering paths are distinct. The verifier
  checks each declared beat through World plus the visible UI label.

### Bug #7 — phase presentation

- **Test type:** visual-state contract.
- **Description string:**
  > `progression route: Deep water changes the live environment and follows a lateral route — guards against a cosmetic phase label on an empty ruler line`
- **Repaired:** the public Deep/Lab phase changes fog, ambient light, and
  background colour and reveals three non-colliding ruin silhouettes. The
  authored route turns around the map instead of forming a collinear chain;
  it remains independent of maze geometry. Fixed-camera hosted captures are
  still required to judge the art, while the verifier protects the state
  distinction and route shape.

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

- **#3:** the first 1280×720 run projected the Frilled Shark outside the
  stage and over all three party-body points. The test now passes at 1280×720
  and 1920×1080 after the bounded visual normalization and mesh-corner camera
  framing repair.

- **#8:** the previous lab beat treated a 180-HP Tethys review battle as an
  implied normal-route finale without normal-party victory evidence. The new
  preview contract caught that mismatch: the physical matrix completes all
  seven route legs while its final leg produces an explicit no-boss reveal.

### Bugs characterized

- The existing headless QTE and full tutorial route gates remain green after
  the layout repair; the new windowed gate owns the browser-sized geometry
  that those faster tests deliberately cannot observe.

### Re-evaluation targets

- A valid visible stage does not by itself prove the imported dodge animation
  reads correctly. Its presentation remains a hosted screenshot/GIF review
  item in the next visual-evidence pass.
