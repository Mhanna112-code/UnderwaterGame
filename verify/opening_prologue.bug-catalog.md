# Bug catalog: Cordys opening prologue

**Generated with `/design-tests` on 2026-10-03**

**Scope:** the public New Game → opening video → movement → Angler → Cordys →
recovery → optional training handoff, including save, audio, video, combat,
scene ownership, web export, and inherited PR #96 boundaries.

## What this feature does

The feature replaces the mandatory intro/tutorial funnel with an authored
first-run prologue. It persists durable milestones, normalizes interrupted
sessions, drives two specially-owned encounters, recovers rather than opening
normal Game Over, and leaves the current tutorial available but optional.

## Public interface

| Symbol | Type | Purpose |
| --- | --- | --- |
| normal `New Game` | title action | Begins a fresh persisted opening without query flags. |
| public prologue phase + `phase_changed` | state contract | Observable owner for HUD, audio, tests, and transitions. |
| `opening_video_seen` | save field | Prevents replay after successful viewing. |
| `prologue_complete` | save field | Unlocks ordinary game systems after recovery. |
| `tutorial_complete` | save field | Retires optional training without gating progression. |
| `prologue_angler` / `prologue_octopus` | encounter sources | Separate scripted encounters from random/tutorial/campaign fights. |
| `Optional Combat Training` beacon | world affordance | Deliberate entry to the unchanged current tutorial. |

## IO boundaries and branching points

- File system: save-slot JSON and persisted audio settings.
- Browser: trusted New Game gesture, WebAudio, Theora playback, canvas size,
  deployment/PCK retrieval.
- Time: video completion, movement/idle trigger, tween/fade timing, intro/loop
  handoff, deliberate recovery silence.
- Input: world movement, attack selection, video policy, tutorial beacon,
  Retry/Return/Skip.
- Scene ownership: title, video, World, Battle, actors, recovery modal, audio
  players, timers, and tweens.
- Import/export: FBX mesh/skin/clips/materials, OGG derivation, Godot PCK and
  hosted artifact.
- Magic-string contracts: prologue phases, encounter sources, RouteState
  objective/campaign Octopus states, Battle results.

## Bug catalog

| ID | Observable failure | Blast radius | Why plausible | Cheapest decisive test type | Status |
| --- | --- | --- | --- | --- | --- |
| OPEN-001 | Old PR #96 saves replay the new opening or become trapped in it. | High: existing players lose continuity. | Missing save fields can look identical to new false values. | captured migration + round-trip | caught and fixed in state contract; World journey pending |
| OPEN-002 | Quitting during video/Battle/recovery reloads a black screen or half-owned fight. | High: save soft-lock. | Video and Battle are transient async owners. | decision table + round-trip | safe-state decision table green; live journey pending |
| OPEN-003 | Opening policy makes the lab video unskippable, or the first-run opening skippable. | High: inherited route regression or broken product decision. | Both surfaces reuse one stream but require different policy. | `opening_video.gd` differential integration | green: owner policy; browser pending |
| OPEN-004 | Video is cropped, stretched, doubled, silent unexpectedly, or leaves world input live. | High: first player-visible surface looks broken. | Runtime-built CanvasLayer, viewport changes, separate audio player. | `opening_video.gd` structural invariant + `opening_video_world.gd` persistence + browser visual/input | green: owner/fallback/save; browser pending |
| OPEN-005 | Video, exploration, Battle, victory, boss, or Game Over audio overlap or transition to the wrong cue. | High: recreates audiovisual overload. | Multiple async phase boundaries and a separate VideoStreamPlayer. | audio state trace + browser listening | Final Boss assets and authored intro/loop handoff green; complete journey/listening pending |
| OPEN-006 | Saved Music/SFX settings are overwritten or do not affect the video independently. | High: user control is violated. | Authored cue gain and user bus gain can be conflated. | settings round-trip + differential mute table | local music trim vs persisted Music slider green; video mute table pending |
| OPEN-007 | Swimming in one direction never triggers, idle stalls forever, or repeated frames start duplicate Anglers. | High: opening progression blocks. | Movement is camera-relative and checked every physics frame. | `opening_prologue_trigger.gd` direction matrix + `opening_prologue_world.gd` real owner | green; visual journey pending |
| OPEN-008 | Random encounter, save point, ability gate, or route event interrupts before recovery. | High: authored sequence is corrupted. | Existing World systems were gated by tutorial completion. | negative-path production-world gate | open |
| OPEN-009 | A visible Angler option misses, deals zero, fails to kill, or allows the Angler to attack first. | High: promised one-action victory fails. | Real moves include non-damage/status choices and ACC/EVA. | decision table across every exposed move | open |
| OPEN-010 | Prologue changes ordinary Angler stats/moves or grants XP/items/spells. | High: global balance/progression regression. | Reusing existing enemy/content tables invites shared mutation. | differential normal/prologue + no-reward invariant | open |
| OPEN-011 | Normal victory fanfare/world handoff occurs before Cordys. | Medium-high: interruption loses meaning or duplicates scenes. | Existing Battle win handler owns music/rewards/removal. | captured end-to-end state transition | open |
| OPEN-012 | Cordys is invisible, static, backward, tiny, clipped, obstructed, or shows the bright-line artifact. | High: central hook visibly fails. | Delivered FBX has unusual composite bounds/front and known line surface. | import invariants + production projection + human visual | actor import/normalization/semantic poses/tint green; production Battle projection pending |
| OPEN-013 | Prologue mutates campaign Octopus route state or adopts final campaign balance/rewards. | High: future route becomes impossible or pre-completed. | Same character/media name serves two distinct owners. | state differential/invariant | encounter-source/state invariant green; combat pending |
| OPEN-014 | Player's Cordys attack is ignored by input or falsely appears to deal meaningful damage. | Medium-high: defeat reads as broken/rigged rather than hopeless. | Scripted control can bypass real Battle resolution. | public-input integration + bounded-damage invariant | open |
| OPEN-015 | Cordys finishing move leaves a survivor, opens normal Game Over, or replays the prologue. | High: narrative handoff fails. | Normal loss handler is load-bearing existing behavior. | captured special-result integration | open |
| OPEN-016 | Recovery returns a dead/damaged/misplaced party, omits the motivation, or saves too early/late. | High: player cannot continue or loses context. | Several state/visual/save operations cross an async boundary. | postcondition invariant + save round-trip | open |
| OPEN-017 | Tutorial beacon triggers immediately, captures the camera, becomes required, or disappears after Return to World. | High: mandatory tutorial funnel returns. | Existing beam was built as compulsory and tied to `_first_encounter_done`. | decision table across ignore/complete/skip/loss-return | open |
| OPEN-018 | Ignoring optional training leaves TAB, encounters, save points, abilities, or route progression locked. | High: “optional” is false. | Existing systems gate on old tutorial state. | normal-entry negative path | open |
| OPEN-019 | Repeated runs leak video, Battle, actor, UI, timer, tween, audio stream, CanvasItem, or RID owners. | Medium-high: tests/browser degrade or crash. | PR #96 previously found unparented UI and stream leaks. | repeated lifecycle teardown invariant | open |
| OPEN-020 | First Cordys reveal stalls/crashes the browser or bloats the PCK with duplicate media. | High: hook fails on deployment. | Large FBX/video plus new music derivatives. | package manifest + exact browser performance observation | open |
| OPEN-021 | Hosted link serves stale bytes or requires authentication. | High: review evidence is invalid. | Repeated historical stale-export incidents. | local/deployed PCK digest + HTTP/browser gate | open |
| OPEN-022 | A context-free tester cannot identify Cordys, intention, long-term goal, immediate freedom, or optional training. | High: feature works technically but misses its purpose. | Scripted loss and temporary Mermaid media can confuse narrative causality. | human comprehension protocol | open |

## Test plan and self-critique

### OPEN-001 / OPEN-002 — durable migration and interrupted phases

- **Type:** decision table plus save round-trip.
- **Description:** `opening save: old, new, and every transient phase normalize to a playable durable milestone — guards against replay and half-scene soft-locks`
- **Assertion:** load observable phase, party state, and video/prologue milestone from old missing-field saves, explicit new false fields, video-seen state, each transient phase, and completed state.
- **Self-critique:** wrong-but-stable output fails because each row requires a playable public destination and exact durable milestone, not matching serialized text. A refactor passes if public behavior is unchanged.

### OPEN-003 / OPEN-004 — video policy and presentation

- **Type:** differential integration plus browser visual/input boundary.
- **Description:** `opening video: first-run and lab owners retain independent policy and responsive single playback — guards against shared-cutscene contamination`
- **Assertion:** opening cannot be dismissed by production input before finish; lab can; both restore control; exactly one visible video fits the viewport; diver position cannot change underneath.
- **Self-critique:** structural owner/aspect assertions cannot prove beauty, so human wide/narrow/tall playback remains mandatory. The test avoids pixel snapshots and private-node ordering.

### OPEN-005 / OPEN-006 — one audio focus and user settings

- **Type:** semantic state trace and differential mute/volume table.
- **Description:** `opening audio: each phase owns one intended cue while authored trims preserve user Music/SFX settings — guards against overload and preference mutation`
- **Assertion:** trace video-only, exploration, Battle intro/safe loop, no victory, Final Boss intro/trimmed loop, silence, exploration; repeat under Music mute, SFX mute, 50%, and persisted restart.
- **Self-critique:** state traces cannot prove a mix sounds good; measured output and human laptop/headphone listening can reject green automation.

### OPEN-007 — direction-independent one-shot trigger

- **Type:** property/invariant.
- **Description:** `opening trigger: any meaningful horizontal movement or idle fallback starts exactly one Angler — guards against direction lock and duplicate battles`
- **Generator:** normalized horizontal vectors spanning the circle, distances below/above threshold, plus zero movement across fallback time.
- **Assertion:** below threshold/no timeout starts zero; threshold or timeout starts exactly one; repeated frames remain one.
- **Self-critique:** it asserts public battle ownership/source, not a private distance helper, and therefore survives implementation changes.

### OPEN-008 — protected prologue

- **Type:** negative-path production-world gate.
- **Description:** `opening protection: random and route systems cannot preempt any incomplete prologue phase — guards against authored-sequence corruption`
- **Assertion:** drive encounter RNG, save-point overlap, zone boundary, ability volumes, and tutorial-beacon proximity before completion; none may replace the active phase.
- **Self-critique:** does not merely inspect booleans; requires absence of player-visible competing owners.

### OPEN-009 / OPEN-010 — Angler decision table and isolation

- **Type:** decision table plus differential invariant.
- **Description:** `prologue Angler: every exposed offensive choice kills once without changing normal Anglers or progression — guards against false choice and shared-content mutation`
- **Assertion:** enumerate visible options, resolve through public Battle input, require hit/death; compare ordinary Angler before/after; require unchanged XP, spells, items, level and campaign state.
- **Self-critique:** it does not restate damage math and survives a refactor that preserves outcomes.

### OPEN-011 / OPEN-013 / OPEN-015 — interruption and special defeat

- **Type:** captured end-to-end state transition.
- **Description:** `Cordys prologue: Angler victory is interrupted and scripted defeat recovers without victory, Game Over, or campaign-state mutation — guards against normal-result fallthrough`
- **Assertion:** one continuous normal-entry journey observes sources/phases, no victory/Game Over owner/cue, unchanged campaign Octopus state, recovered party, complete save.
- **Self-critique:** public layers, audio state, result, party and save make wrong-but-stable internal flags insufficient.

### OPEN-012 — production Cordys presentation

- **Type:** import invariants, production projection, and human visual boundary.
- **Description:** `Cordys presentation: visible skinned animated bounds face the party and fit the real stage without the line artifact — guards against technically imported but broken boss art`
- **Assertion:** nonempty visible bounds, meshes driven by skeleton, selected clips deform, authored front dot faces party, projected bounds meet minimum/maximum size and avoid HUD/party overlap, forbidden line surface absent/hidden.
- **Self-critique:** projection metrics can pass an ugly image, so exact wide/narrow/tall frames require human rejection authority.

### OPEN-014 — registered negligible player response

- **Type:** public-input integration and bounded-effect invariant.
- **Description:** `Cordys response: a real selected attack visibly resolves but cannot materially change the scripted outcome — guards against ignored input and fake normal combat`
- **Assertion:** real button/target path produces animation, impact feedback and bounded HP change; then Cordys retains the deterministic next action.
- **Self-critique:** does not pin a literal damage number; it pins player-visible registration and negligible fraction.

### OPEN-016 — atomic recovery

- **Type:** postcondition invariant plus save round-trip.
- **Description:** `opening recovery: motivation, full party, safe position and durable completion commit together — guards against half-recovered saves`
- **Assertion:** after public completion all divers have max HP/O2, valid floor-safe positions, no battle/modal/audio except recovery contract, exact motivation shown once, saved reload enters normal play.
- **Self-critique:** assertions are semantic outcomes and tolerate internal transaction reorganization.

### OPEN-017 / OPEN-018 — genuinely optional training

- **Type:** decision table and normal-entry negative path.
- **Description:** `optional training: ignore, complete, skip, retry and Return to World all preserve intended availability and never gate normal progression — guards against mandatory-tutorial regression`
- **Assertion:** run every choice; require camera/input/objective/beacon/tutorial state and ability to reach a normal save/random encounter afterward.
- **Self-critique:** it tests the meaning of optional, not the beacon's implementation or exact coordinates.

### OPEN-019 — teardown

- **Type:** repeated lifecycle invariant.
- **Description:** `opening lifecycle: repeated complete/interrupted sessions leave no duplicate owners or leaked objects/RIDs — guards against async scene leaks`
- **Assertion:** create/destroy repeated World sessions across all phase exits; require bounded owner counts and no Godot leak report.
- **Self-critique:** owner-count checks target public semantic groups; engine leak output remains an independent oracle.

### OPEN-020 / OPEN-021 — exact web artifact

- **Type:** manifest invariant plus exact deployment integration.
- **Description:** `opening web: one canonical media set boots and completes from a public deployment whose PCK matches the reviewed commit — guards against duplicate bloat, reveal crash, stale bytes and auth`
- **Assertion:** reject duplicate digests/runtime roles, record size delta, compare PCK hash, HTTP 200 without auth, capture console, reach first Cordys reveal and recovery.
- **Self-critique:** load timing is environment-sensitive, so treat a visible multi-second stall/crash as human/browser rejection rather than a brittle millisecond threshold.

### OPEN-022 — comprehension

- **Type:** structured human acceptance protocol.
- **Description:** `opening comprehension: context-free players identify Cordys, intentional defeat, eventual goal, immediate freedom and optional training — guards against a technically correct but narratively failed hook`
- **Assertion:** record answers to the five fixed questions without coaching.
- **Self-critique:** subjective interpretation cannot be reduced to a headless proxy; fixed questions and raw answers prevent retrospective rationalization.

## Skipped

- Exact pixel snapshots of the video or Cordys — wrong-but-stable images could
  pass; use semantic geometry plus human review.
- Exact animation-frame timing — tune visually; pin only that selected clips
  visibly deform and the finishing move resolves once.
- Final campaign Cordys victory/balance/reward — outside this prologue PR.
- Redesign of existing tutorial prose and later route comprehension — explicit
  product deferral; preserve existing behavior.
- Final Glassgoat opening content/copy — blocked on delivery; the replacement
  seam and verification contract are covered instead.
- Camera shake/reduced-motion toggle — no shake/forced zoom/screen-wide flash
  is admitted by this scope.

## Approved split cinematic risks, 2026-10-03

OPEN-023: the Octopus cinematic restarts at zero, duplicates its decoder,
continues invisibly through combat, leaks input while visible, or overlaps
boss music. A continuous first-25-seconds/pause/remainder owner must preserve
its actual playback position; tests exercise public pause/resume, one-player
ownership and signal order, then real rendered/web playback verifies the
boundary without injected seeking. Decoder failure must release either wait.

OPEN-024: recovery is saved before the cinematic remainder/motivation, or
interrupted cinematic state is loaded as a half-owned battle. Extend the real
journey and old/new/transient save decision table with introduction/aftermath
phases. Existing durable milestone normalization remains the oracle.

## Post-write evaluation

Fill after each test is written and run, one at a time:

- **Bugs caught:** OPEN-001. The parent has no durable opening fields, so an
  implementation that defaulted missing data to false would replay the new
  prologue for every existing PR #96 save. The red gate produced 14 findings
  before the explicit old-save/new-save distinction was added.
- **Bugs characterized:** OPEN-002's three safe durable restore milestones;
  OPEN-013's semantic sources do not change campaign Octopus state.
- **Bugs discovered during writing:** a fresh worktree's inherited
  `verify/route_state.gd` printed `ROUTE STATE: clean` and exited 0 while
  incomplete FBX imports produced runtime errors. Project import is now a
  prerequisite and execution wrappers reject any `SCRIPT ERROR`/`ERROR:` line
  even when a legacy script exits 0.
- **Tests removed after self-critique:** pending.
- **Additional captured defects:** OPEN-014 hidden player/selected-move panels
  failed the real journey before restoration on party turns. OPEN-012 bind-pose
  bounds made the production boss miniature; an AABB projection also falsely
  passed, so the decisive narrow-stage test now projects actual skinned vertices.
  It failed at 36.0% stage height before exact-silhouette framing/compact staging.
  OPEN-023 split owner test failed before implementation and now preserves one
  paused decoder. OPEN-024 journey proves aftermath precedes recovery/save;
  all eight milestone combinations at all live phases round-trip safely.
- **Current integration evidence:** `opening_prologue_journey.gd` and
  `optional_training.gd` pass for real attack/target input, same Battle,
  negligible hit, scripted defeat, full recovery, no rewards/campaign mutation,
  optional label/arrival, Skip/Retry/Return and saved completion. Native ordinary
  full movies measure 109.23/109.18/109.22 seconds at wide/narrow/tall. Narrow
  framing was rejected and repaired; full revised review remains required.
- **Pass-plus-suspect items investigated:** pending.

If no test initially catches a real defect, probe at least cross-feature
composition, missing-field migration, video-policy contamination, and audio
owner overlap before accepting a zero-caught result.
