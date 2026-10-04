# Local world guidance (2026-10-04)

Scope: World objective panel, physical zone updates, existing puzzle entrance
blockade, consumed-world save/load and active-diver switching. No new route,
collision, mandatory objective or ability balance.

## Interfaces / IO / invariants (original defect analysis)

- Actual swimming updates the active diver's physical position. The existing
  shared DeepZoneLayout defines Deep at x >= 60. RouteState keeps progression
  state and emits objective_changed only when the objective ID changes.
- Current panel reacts only to objective_changed. Leaving Deep changes zone,
  not objective ID, so the old lab text remains visible. Loading a save already
  in the same zone or switching divers can also bypass a zone-change callback.
- Puzzle geometry is authored in `_build_highway`: x=15..45, z=6..14, y=0..6.
  A small proximity margin should be derived there, not introduce a new solid
  collider. `entrance_blockade` is the existing persistent consumed-world ID.
- Only current active-diver proximity drives the hint. Standing anywhere in
  Shallows does not make finding the lab an active on-screen instruction.
- Save JSON retains objective/blocker progress; display visibility is derived
  from physical location and intact geometry, never persisted separately.
- Existing deep-zone guidance, real Shockwave/collider and legacy plate gates
  cover related puzzle/progression mechanics.

## Subsequent contract addition, 2026-10-04

The user requested a short zone/purpose indication in ordinary Shallows water.
After prologue completion, previously blank Shallows views now show
`Shallows: fight to grow stronger.` The intact puzzle-contact hint still takes
priority; Deep retains its lab instruction; unfinished opening remains blank.
Native/browser checks now assert this replacement instead of an empty panel.
This deliberately supersedes the original blank-panel expectations, not the
location/state/active-diver invariants or the earlier source-labeled evidence.
New bug catalog: `verify/shallows_guidance.bug-catalog.md`.

## Bugs and tests

| ID | Failure / blast radius | Why plausible | Test |
| --- | --- | --- | --- |
| OPEN-043 | Lab text sticks in Shallows or fails to reappear in Deep. Conflicts with Sonar discovery. | Objective ID stays unchanged across zone crossings. | Real W/S movement across boundary, assert panel/text and unchanged lab progression; bounded position sweep and Load. |
| OPEN-044 | No Bucky hint at puzzle contact, or it follows player away / survives wall destruction. | No contextual hint exists; consumed geometry is separate from route objective. | Approach visible entrance by actual movement, inspect panel, Tab to Bucky and real E Shockwave, assert prompt retires; return/reload consumed state. |
| OPEN-045 | Inactive diver, altitude or nearby open water triggers wrong prompt. | Underwater 3D bounds and diver selection differ from simple x-only zone. | Spatial decision table around room's visible bounds, active diver switch, unfinished opening exclusion. |
| OPEN-049 | Bucky/wall hint omits the TAB switching key, leaving another diver's player unsure what to do. | The static instruction names the ability but assumes controls were read. | Actual puzzle approach with Maxilani selected: visible instruction contains parenthesized TAB; narrow/wide render for wrapping. |

Self-critique: expected observable panel visibility and semantic Bucky/wall
instruction, not callbacks or helper-call counts. Wrong stable output fails.
Fixture positions/saves isolate spatial branches; movement and actual ability
cases run production input. No direct broken/finished signals prove destruction.

## Skipped

- Puzzle redesign, remaining Grapple/Swap instructions, marker changes: not
  requested; preserve the existing room and optional training.
- Lab-goal progression rewrites: preserve pending objective while hidden.
- Sonar range/cost, enemies, maze, audio/asset polish: outside this change.

## Evaluation

- OPEN-043 reproduced red by actual W movement across the Deep boundary:
  `zone-red.log`. Same crossing, reverse crossing and preserved objective
  green after fix (`zone-green.log`).
- Full spatial/real Shockwave/consumed-wall Save/Load verifier passes rendered
  at 1280×720 and 720×480; both views inspected, hint panel contained in the
  viewport and outside minimap (`rendered-*-green.log`, screenshots).
- Existing Deep guidance, legacy plate separation, open-water collision and
  Sonar/encounter Save/Load gates pass without runtime errors.
- Initial rendered verification failures were harness defects: screenshot
  settling let the diver coast farther before a too-short return swim; and
  direct milestone mutation skipped the production Load handoff. Preserved
  in `rendered-harness-red.log`. Added a physical re-entry assertion, longer
  real return input and a valid unfinished checkpoint through actual Load.
  A simultaneous owned-slot run safely refused to overwrite the other test;
  final runs are sequential. These are not claimed as additional game bugs.
- Exact hosted browser boundary passes eight rendered observations with real
  W/S/arrow/Tab/E input and zero runtime errors. Checkpoint positions are
  explicit fixtures in a disposable profile, based on an actual recovered
  opening save. No victory or wall-consumption signals are injected.
  Served PCK SHA/size match the committed runtime export. No claim of a full
  clean visual/audio audit for the overall opening.
