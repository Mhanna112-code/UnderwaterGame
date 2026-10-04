# Cordys opening prologue — visual/audio audit log

This log is part of the release contract. A green test suite, successful
export, or attractive isolated screenshot cannot produce the final PASS.

## Round template

| Field | Record |
| --- | --- |
| Date/time | |
| Candidate commit | |
| Parent PR #96 base | |
| Local exported PCK bytes/SHA-256 | |
| Immutable deployment | |
| Stable PR alias | |
| Served PCK bytes/SHA-256 | |
| Browser/build | |
| Viewports | 1280×720; 720×480; tall review viewport |
| Audio outputs/settings | laptop; headphones; 100%; 50%; Music mute; SFX mute |
| Journeys reviewed | normal opening; ignore training; training completion; Skip; loss Retry; loss Return to World; reload boundaries |
| Console/Godot errors | |
| Defects observed | none, or links to records below |
| Round result | PASS / FAIL |

## Defect record template

| Field | Record |
| --- | --- |
| Identifier | OPEN-AUDIT-### |
| Candidate commit/deployment | |
| Reproduction from ordinary title | |
| Expected | |
| Observed | |
| Evidence | screenshot/GIF/audio capture/log |
| Related bug-catalog entry | |
| Focused gate red/green | |
| Fix commit | |
| Whole affected journey re-audited | |
| Status | open / fixed / accepted explicit product decision |

## Mandatory inspection path

1. Cold title and cover: correct art, silent background, restrained UI cues.
2. New Game/slot: trusted gesture and no stale world/HUD.
3. Opening video: one frame, correct fit, readable, synchronized, no input
   leak, correct Music control.
4. Transition: no stacked audio, black hang, title flash, or world pop.
5. Quiet spawn: exploration ambience restrained; controls and camera available.
6. Trigger: swim in multiple directions and test idle fallback.
7. Angler: every visible attack, actor framing, readable UI, restrained audio,
   no rewards, no enemy-first damage.
8. Interruption: no victory fanfare/world flicker; clear false-relief beat.
9. Cordys: scale, facing, materials, composite, line artifact, reveal, player
   hit, finishing animation, music and impact.
10. Recovery: silence, exact motivation, healthy party, safe position, save,
    ordinary exploration resumes once.
11. Optional beacon: label, distance, no camera/objective capture.
12. Ignore branch: normal PR #96 world, encounters, save, abilities and route.
13. Training branch: complete, Skip, Retry, Return to World and Combat Help.
14. Reload: video, spawn, fights, recovery, complete and old-save boundaries.
15. Teardown: title return/later Game Over and repeated session owner/leak check.

## Acceptance rule

Fix every observed technical, visual, audio, input, state, collision, pacing,
or presentation defect; run its focused gate; rebuild and deploy the exact
commit; then replay the whole affected journey. Continue until one complete
round finds no defect and no browser/Godot error.

The following are explicit temporary product decisions rather than hidden
defects:

- Mermaid Freak is reused as the opening until Glassgoat supplies the final
  opening media.
- The same asset remains the skippable Tethys lab scene.
- Campaign Cordys progression/balance remains deferred.

Their implementation can still be defective: duplicate bytes, wrong policy,
cropping, poor audio, broken state, or an incorrect replacement seam blocks
the round.

## Rounds

### Checkpoint persistence follow-up, 2026-10-04 (focused audit, not final PASS)

The previous web gate covered cold Load but omitted actual exported ordinary
combat death. Native write denial and browser persistence are separate IO
boundaries; a green FileAccess return is not a browser-durability promise.

OPEN-033 red: the unmodified complete opening on source 2bf19ac, with only this
disposable profile's completed IndexedDB transaction rejected, reached recovery
and offered successful Continue. `/tmp/opening-browser-durable-red/` and log
retain that failure. Repair waits for the browser's canonical exact bytes,
disables Continue while saving, and retains visible Retry Save on failure.
The canonical database is only read by the acknowledgement owner; Godot still
owns writes and sync. The player's stored checkpoints were never modified.

Intermediate candidates were rejected: the initial JS bridge used eval as an
object-return API, which returns no arbitrary object in this Godot export.
Both failed browser rounds were retained and the interface corrected before
any deployment. Final local WebKit denial / Retry / cold Load passes at
96.786 seconds (including the intentional storage denial and retry wait), with
no runtime errors apart from the precisely injected transaction abort.
`08a-storage-failure.png` and `08b-retry-save.png` confirm readable Retry and
Continue surfaces. Native real-death, invalid Load, optional training and
denied slot-switch regressions also pass. Hosted OPEN-034 proof remains pending.

This confirms real replay-causing failure paths, not which storage failure
occurred in Miguel's earlier session. The old observed slots contained initial
milestones. We must not silently fabricate completion for those slots or claim
that the source repair reconstructs progress already absent from the save.

### Local diagnostic round 1, 2026-10-03: FAIL

Uncommitted D/E candidate based on `1f30164`; Godot 4.7.1 Compatibility,
ordinary New Game, actual complete Mermaid playback, physical W movement,
real Battle buttons. 1280×720 and 720×480 captures under `/tmp/opening-wide/`
and `/tmp/opening-narrow/`. Native title-to-recovery: 48.38/48.12 seconds.
No hosted/browser or subjective laptop/headphone approval is claimed.

- OPEN-AUDIT-001: Cordys reveal hid selected-move/player stat panels for the
  next real action. Journey gate reproduced two failures, then passed after
  restoring panels on each party turn.
- OPEN-AUDIT-002: Cordys framing used bind-pose/whole-motion empty bounds,
  making the boss and party miniature. Actual skinned idle bounds now own
  normalization/framing; production camera and horizontal staging tuned.
  Supplementary wide/narrow stage captures improve readability. Full revised
  cinematic journey still requires re-audit.
- OPEN-AUDIT-003: recovery left the earlier Angler message in the world HUD.
  Clear banner/timer as part of atomic restoration; round-2 world capture
  confirms absence. Complete new cinematic journey still pending.
- OPEN-AUDIT-004: game-over checkpoint restart bypassed optional-training
  setup. It now uses the same Load Game lifecycle; round-trip gate pending.
- OPEN-AUDIT-005: quiet spawn advertised disabled ability/TAB/random controls.
  Incomplete prologue HUD now shows movement/look only.
- OPEN-AUDIT-006: a one-shot decoder watchdog could miss a stream that claimed
  playing while stalled. Repeated progress watchdog replaces that check;
  failure and real-video gates remain to be strengthened.
- OPEN-AUDIT-007: inherited swim verifier now meets the new idle prologue while
  waiting for swim-end, preventing its locomotion-only scenario. Aggregate
  run interrupted after recording this failure; isolate its completed-world
  fixture, then rerun rather than classifying product behavior as green.

### User pacing revision, 2026-10-03

The 0.65-second Angler-to-Cordys gap is not accepted as final pacing. Miguel
approved the Octopus V3 first 25 seconds as an introduction and the remainder
after defeat/before motivation. He will discuss shortening with Glass.
Implement continuous pause/resume, then repeat the complete visual/audio
audit. This explicitly changes the earlier accepted no-interstitial sequence.

### Local diagnostic round 2, 2026-10-03: incomplete (not final PASS)

Uncommitted child based on `1f30164`; Godot 4.7.1 Metal/Forward+, 1280×720.
Actual ordinary title → full Mermaid movie → physical W → real attack buttons
→ first 25 seconds of V3 → Cordys response/finisher → resumed V3 → recovery
Continue → optional training. Captures: `/tmp/opening-split-wide/`.
Elapsed with prompt choices: **109.23 seconds**. No script/error output.
Single-decoder pause/resume and recovery-after-aftermath integration gates pass.
No hosted proof, subjective audio approval, narrow/tall acceptance or blind
comprehension result is claimed. Embedded V3 red-on-black copy is retained as
delivered; Miguel will discuss a shorter version with Glass.

OPEN-AUDIT-007 focused red/green: old swim fixture missed its End clip because
the incomplete-prologue idle fallback intentionally entered combat. A normal
completed-world fixture restores the full idle/start/loop/end/idle assertion,
and passes without changing locomotion. Forward-entry and visible-column
tests now start from the real recovered-save milestone and both pass.

OPEN-AUDIT-008: Compatibility 720×480 full journey completes in 109.18 seconds
but Cordys and party still read miniature. `/tmp/opening-split-narrow/08-cordys-response.png`
is rejected despite green import/state gates. Tighten the prologue-only stage
composition/framing, then repeat the affected complete journey; no final PASS.

OPEN-AUDIT-008 red/green: projecting an axis-aligned box falsely passed at
54.5% stage height. Projecting the actual skinned vertices reproduced the
observed miniature at **36.0%**. Exact idle-silhouette framing, a bounds-based
camera centre (not vertex-density weighted), and a compact grounded party
raise it to **76.7%** in the focused native stage, with no idle clipping.
The complete journey and all action poses still require another review.

OPEN-AUDIT-009: inherited aggregate (isolated user data, source `9048e12`)
found ordinary encounter/guardian/zero-O2 fixtures still in an incomplete
prologue, plus tutorial-exit expecting a mandatory beam. Those false states
are intentionally protected by the new contract. Update fixtures to recovered
milestones without weakening encounter/reward/collision/completion assertions.
Separately prove an ordinary encounter can start after the **actual** opening
handoff while training remains incomplete. Forward-entry intermittently meets
a legitimate random encounter; isolate voluntary training with encounters off,
as a player may do with R, rather than changing normal encounter design.

Pre-audit automation note, 2026-10-03: `opening_video.gd`,
`opening_video_world.gd`, `title_screen.gd`, `opening_prologue_state.gd`, and
`audio_lifecycle.gd` pass for the isolated owner, independent lab skip policy,
world pause/input ownership, -6 dB Music routing, decoder fallback, successful
milestone persistence, failed-view replay, and completed-view non-replay. This
is not a visual-audit round and does not approve browser framing or mix.

OPEN-AUDIT-010 / OPEN-004: ordinary exported New Game on Chromium reproduces
a black lock after Mermaid playback. No console error; public phase remains
`opening_video`. Diagnostic export observes decoder positions 35.917 through
59.927 seconds while `is_playing=true`; the independently probed media ends at
33.877333 seconds. The progress watchdog cannot detect a clock that advances
past EOF. This is a product defect, not dismissed as a harness timeout.
Use the decoder's reported complete stream length as an additional completion
boundary, never a wall-clock skip or shortened asset; preserve pause/resume.
Repeat ordinary browser entry through both full movies and recovered control.

OPEN-AUDIT-011 / OPEN-012: compact full tall journey still clips the outer
finishing tentacle at the right edge (`/tmp/opening-compact-full-tall/11-finisher.png`).
Idle-only projection passed but did not prove action poses. Extend the gate to
sample reveal/hurt/finish skins against the unchanged camera at all viewports;
repair fixed framing without a forced zoom, then rerun the complete journey.

Browser input diagnostic after OPEN-AUDIT-010: actual Attack opens the move
menu correctly. The verifier then clicks the old Angler move coordinate on
Cordys's shorter menu, hitting **Back**, not Electric Touch. Menu screenshots
prove this separately; real GUI input through the paused/hidden movie owner
also passes. Correct the verified menu coordinate and retain intermediate
menu captures. Do not classify this as a product click failure.

OPEN-AUDIT-010 browser repair evidence: exact exported source `b5b3e86`,
ordinary New Game, Chromium requested ANGLE Metal, actual mouse Attack/move/
target input, both full movies, recovery Continue and control complete in
118.711 seconds. `/tmp/opening-browser-metal/result.json` records the complete
public phase trace and no console errors. This is not the final visual candidate;
it retains the subsequently rejected Spinning Slay framing.

OPEN-AUDIT-011 repair iteration: full moving-pose sampling rejected the first
perspective-envelope/Head Bash attempt because it made the boss miniature.
Selected authored Poison Breath plus a fixed orthographic view contains the
actual surface envelope without zooming during animation. 21 samples of each
idle/reveal/hurt/finish clip pass at 1280×720, 720×480 and native tall 900×959, including
behind-camera checks. Uncommitted wide normal-entry capture in
`/tmp/opening-ortho-full-wide/` completes in 112.08 seconds; response/finisher
were visually inspected. Cached-framing tall journey completes in 108.26 seconds
at `/tmp/opening-cached-full-tall/`. Final browser export/review remains.

OPEN-AUDIT-012 / OPEN-020: deriving the action envelope inside actor `_ready()`
took 3,020–3,062 ms, a real first-reveal hitch. Move it to an offline generated,
source/clip-pinned framing resource. Cached actor creation measures 52 ms;
independent live skin projection remains green. Final exported browser timing
still required; do not claim native timing proves browser smoothness.

Verification-tool repair: an initial generator indentation error appended a
point inside the vertex loop rather than once per direction. It was stopped,
the partial generated resource was replaced, and a strict 1,976-point guard
now rejects an incorrectly sized derivative. No such generated resource was
committed or exported. Successful derivative: 67,693 bytes, source/clip metadata
and explicit point count checked; production must never run this generator.

Viewport evidence correction: native `--resolution 900x1400` is constrained by
the macOS display to **900×959**. PNG dimensions were probed before acceptance;
do not label the captures as 900×1400 proof. The verifier now prints its actual
viewport and retains a 90-pixel readability floor in width-limited tall stages.

Timing investigation: two simultaneously running native movie journeys gave
108.26 s (tall) but **209.05 s (narrow)**. That is not a passing timing result.
Possible background rendering/contention is not established as the cause yet.
Repeat the narrow journey alone with real per-phase wall-clock timestamps and
an explicit two-minute failure assertion; do not accept a script's old exit-0
as proof that its printed timing meets the contract.

Timing recheck: narrow repeat without another full-movie journey completes in
**108.77 s**, with `recovery` at 108.282 s and `complete` at 108.405 s.
`/tmp/opening-cached-full-narrow-single.log` records every phase wall-clock;
no script/error output. The two-minute assertion passes. Concurrent native
movies are not a reliable latency measurement; exact exported browser timing
is still the decisive deployment check. No footage was shortened.

## User-approved monologue removal, 2026-10-03

This explicitly supersedes the earlier no-shortening instruction for the long
“You arrived…” passage only. Original MP4 SHA `138c4d3…` and PR #96 full OGV
SHA `8cad2b49…` remain unchanged. Edited prologue OGV: 31.381333 s,
3,882,002 bytes, SHA `8425b83d…`. Retains [0,25) + [54⅓,EOF), beginning
at the first “C” of Cordys and preserving the complete final tableau/title.
One paused decoder remains; the unused full archive is excluded from web export.

OPEN-025 red media test failed before the derivative existed. Production-path,
actual decoder-length, digest, pause-boundary and archive-exclusion checks now
pass; existing split-owner, real-input recovery/optional-training and original
Octopus intake gates remain green. Independent 941-frame retained-source
comparison: overall SSIM 0.990974 after Theora encoding. Boundary/end frames
were visually inspected and contain no long monologue.

Native normal-entry journey reaches recovery at 78.025 s and control at
105.39 s. Its aftermath viewport capture unexpectedly showed only “C” at the
expected end-card time, with a long wait before the next rendered capture.
Do not accept that single viewport capture as proof of the full title. A
standalone **production** owner (actual 25 s boundary, no seek/fast-forward)
subsequently advances from 25.014 through 30.473 s with six distinct decoded
images; the last image visibly shows **Cordys / Mistress of the Puppets** and
the red boss tableau. This establishes decoder content, not yet the complete
World composition. Instrument the normal journey with both decoder-texture
and viewport captures, and verify the exact exported browser before release.
Audio listening acceptance remains pending; no claim of a completed polish round.

Exact source `e78e876` ordinary exported browser journey (real New Game, mouse
attack/move/target clicks, both video beats, recovery Continue, world control)
passes in **93.359 s**. Actual renderer: ANGLE Metal Apple M1. All ten public
phases occur once; no console/script errors. The aftermath is **6.638 s**.
Unlike the suspect native viewport capture, the actual browser screenshot
visibly contains the full **Cordys / Mistress of the Puppets** title over the
red boss tableau, then a separate recovery card. Evidence:
`docs/evidence/opening-prologue-title/title-web.png` and `title-native.png`;
result `/tmp/opening-browser-short-title/result.json`. Native background-window
capture discrepancy remains recorded, not relabelled as a diagnosed harness
defect; standalone decoder and browser observations independently pass.

Public prebuilt review candidate (no public-main promotion):
`https://underwatergame-5s8dreh6s-immortaldemongods-projects.vercel.app/`.
Unauthenticated build-info returns HTTP 200 with source `e78e876`; remote PCK
matches local SHA `52b7d6bd…`. A separate empty-project loader confirms the
edited movie's exact SHA is inside the PCK and the full archive is absent.
Main URL still resolves to Oct 1 deployment `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`;
PR #96 remains open at `27a5b525…`. Hosted full journey is being verified;
blind comprehension, actual listening and final zero-defect round remain open.

Hosted repeat now passes in **94.409 s** through ordinary New Game, actual
mouse combat, full retained intro/title ending and recovered world control.
No browser/script errors; all ten phases occur once; actual renderer ANGLE
Metal Apple M1. Hosted aftermath screenshot independently inspected: complete
boss name/subtitle and red tableau, followed by recovery. Stable review alias
returns HTTP 200 and the same source manifest. Persistent result:
`docs/evidence/opening-prologue-title/hosted-result.json`. This completes the
requested video edit/hosted-flow check, not the broader goal's blind listening,
viewport matrix or final zero-defect acceptance.

## Save/restart replay reported by user, 2026-10-03: OPEN, not final PASS

The user confirms reaching motivation and Continue, entering ordinary encounters,
dying, then repeating the full opening/Cordys sequence. Preserve this report;
native green flags do not resolve it.

Native real-button journey now includes ordinary loss, actual Restart from Save
Point scene reload, another loss, Return to Title and public Load Game selection.
The ordinary completed case passes. A newly probed decoder-fallback composition
fails: completed recovery retains the honest `opening_video_seen=false`, but
Load Game independently starts a movie despite `prologue_complete=true`. The
minimal guard fix lets completion take precedence, preserving the independent
viewing flag. Both native variants now pass; incomplete decoder failures still
retry. This fixes a real subset, not the user's repeated Cordys fight.

Exact hosted source `4e244a1` complete ordinary New Game → real mouse combat →
recovery → cold page reload → actual Load Game/slot buttons passes independently
in Chromium (87.067 s opening) and WebKit 26.5 (93.042 s opening). Each engine's
actual persisted IndexedDB checkpoint contains both flags true; each fresh World
reports only `complete` and shows controllable world/optional training. No
browser/script errors. These tests ran against the existing deployment, before
the fallback guard fix; they characterize the normal case, not prove a fix.

Direct observation in the existing Safari tab at the same review alias:
three occupied “Lv 1 party” slots. Slots 1 and 2 restore pre-prologue-complete
movement-only controls; Slot 3 starts the Mermaid movie. No completed destination
was observed. Diagnostic loads were interrupted by reload before recovery;
no slot was created, overwritten, deleted, or marked complete. The slots are
insufficiently distinguishable, but wrong selection alone cannot be claimed as
the cause because none restores completed play.

The user authorized enabling Safari developer tools. Through its console,
read-only `/userfs` → `FILE_DATA` inspection confirms all three slots actually
save `prologue_complete=false`. Slots 1/2 have watched-opening true; Slot 3
has it false. All contain three valid starting-position diver snapshots, full
starting HP/Oxygen, zero XP/spell points and tutorial incomplete. Thus neither
a malformed diver count nor a saved completed flag ignored by the loader
explains these particular snapshots. The loaded runtime's PCK size (92,096,636
bytes) and fetched build metadata agree with deployed `4e244a1`.

Do not bypass OS access controls or repair arbitrary early-game saves by falsely
marking every prologue complete. Browser identity of the original completed
session is being clarified: existing Safari data does not establish that it
was the browser used during the reported playtest. Completion-write failure,
later overwrite and a different browser/origin remain unproven explanations.
The user's full replay remains OPEN pending its exact save/runtime diagnosis.
Evidence: `docs/evidence/opening-prologue-save-recovery/`. Review alias remains
the existing source at this point; no full-fix deployment is claimed.

## Free-swim interruption reported by user, 2026-10-03

The user could not move anywhere before the first attack. OPEN-026 reproduces
the timing defect through real World physics and physical W input, with only
the movie fast-forwarded: 3.007 m travelled and Angler at 1.347 s after spawn,
including a 0.5 s idle observation. Only 0.847 s of swimming was available.
Native controls did move; this does not establish that the user's browser
focus was correct. The old distance-only tests incorrectly accepted this beat.

Added a minimum four-second exploration window, preserving three-metre
meaningful displacement, seven-second idle fallback and one-shot ownership.
Real-input rerun: **18.667 m travelled, encounter at 4.417 s**. The heading/time
matrix, protected World handoff and actual combat/recovery journey also pass,
with no runtime errors. These are native gates, not hosted proof. Export the
exact source and repeat ordinary browser New Game with held W, record the
free-swim phase interval and inspect start/moving screenshots before accepting
the review link as updated. No unrelated campaign/tutorial redesign.

Exact source `4e244a1` exported browser completes ordinary New Game → recovered
control in **90.789 s**, with a **5.298 s** spawn-to-Angler interval and no
errors. Start/moving screenshots visibly show swimming past world scenery.
Public candidate `dpl_6dqgyjHZ5sEEG2qWDf1T3wGZhBM2`, immutable
`https://underwatergame-4wcsqvdcl-immortaldemongods-projects.vercel.app/`, is now
on the same opening-prologue review alias. Public build-info reports `4e244a1`;
local/prebuilt/unauthenticated remote PCK SHA is `551d01df52b137c9…`.
Main URL still resolves to `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`; PR #96 unchanged.

Hosted complete journey passes in **98.843 s**, but its interim “moving”
screenshot finished after combat began: the initial GPU readback consumed
several seconds before W. Its **7.223 s** interval can prove idle fallback,
not movement. That image was rejected as movement proof. The full harness
now presses W before any readback and rejects a late dispatch or idle-only
interval; separate continuous recording verifies the actual input boundary.

First continuous recording shows real swimming and a 6.287 s interval, but
the harness failed an unjustified 0.5 s IPC limit (dispatch took 1.285 s).
Raw failure is preserved. Corrected criterion requires dispatch within the
usable window rather than arbitrary subsecond automation latency. Recheck:
**6.724 s** spawn-to-Angler, W dispatched at 1.500 s and held for **5.224 s**
before combat, no errors. The six-frame contact sheet was inspected: diver
swims past the starting marker/rocks, then the Angler stage appears. Continuous
six-second GIF: `docs/evidence/opening-prologue-free-swim/hosted-movement.gif`.
Result: `recording-result.json`. This is hosted normal entry, no query flags,
teleport, video fast-forward or injected trigger. The revised full harness is
being rerun; broader blind-listening/comprehension/polish acceptance stays open.

Further harness finding: the full run rejected a 7.479 s wall interval against
the idle clock's seven-second ceiling. Wall time and active physics time are
not interchangeable, so that limit cannot diagnose the trigger's cause. The
complete-flow gate now pins the four-second floor and two-minute total cap;
actual displacement is established by native physics plus continuous browser
video, not by phase time alone. The raw rejected result remains in evidence.

Final revised full hosted journey: **93.560 s**, **5.532 s** spawn-to-Angler,
W dispatched 0.896 s after spawn and held **4.636 s** before combat. All ten
phases occur once, no errors, complete boss title and recovery shown, then
optional training/world restored. `final-hosted-result.json` records the
actual keydown timestamp. Exact runtime remains `4e244a1`; later edits only
harden verification and record evidence/plan. OPEN-026 is fixed and has a
native red→green regression plus actual hosted movement proof. This does not
complete the wider opening goal's remaining acceptance matrix.

## Save-continuity coverage correction, 2026-10-04

The user correctly challenged the missing actual-death and failure-path tests.
There is no established Safari-specific cause. Earlier `finished("lost")`
injection skipped enemy attacks, QTE failures and Battle's actual defeat path.
Browser save inspection remains evidence of stored data, not causation.

Three deterministic native failures were reproduced before their repairs:

- OPEN-028: denied completion write silently left the initial checkpoint and
  permitted Continue; subsequent Restart replayed the full opening (nine
  findings). SaveManager now returns IO errors, writes/flushed/verifies a
  same-directory candidate before replacement, and recovery retains the
  restored session with Retry Save until success. No completion is invented
  in an existing user save.
- OPEN-029: missing/malformed Load silently launched New Game (three findings).
  Validated checkpoint shapes now fail before mutating actors. The title stays
  visible/paused with an error; the selected bytes remain untouched. Malformed
  JSON is handled without an engine-error log. Legacy and current valid loads
  after an invalid selection remain supported.
- OPEN-030: denied cross-slot save falsely announced success and selected the
  destination's older opening checkpoint (two findings). Failure now preserves
  the prior active slot; a successful retry switches slots with completion
  intact. Both previous files remain readable on failure.

Expanded native evidence: normal opening combat → recovery save before Continue
→ actual ordinary enemy-caused death → real Restart → another actual death →
real Return to Title → Load selected slot. A second run adds voluntary optional
training Skip before death. These do not inject loss, HP-zero or completion;
HP 1/DEF 0/EVA 0 and failed-escape RNG are explicit cheap attrition fixtures.
Recovery-denial Retry Save and cross-slot denial/retry also pass. Migration,
optional training Retry/Return/Skip (result-boundary coverage), video-save,
protected world, physical free swim and world/drop checkpoint regressions pass
with no runtime errors.

Actual Godot-rendered Retry Save, restored Continue and load-error screens were
inspected at 1280×720 and 720×480: text and actions fit, remain readable, and
have no observed clipping/overlap. This is a scoped error-UI audit, not the
full goal's final zero-defect audio/visual/human-comprehension acceptance.

Limits: these reproduced paths are credible mechanisms, not proof of which one
caused the user's earlier session. A native flushed file is not proof of
browser IndexedDB durability. Training win followed by actual normal death,
browser persistence-denial injection and the reported session's exact history
remain unproven. The hosted alias is unchanged until an exact-source export is
verified and published. Raw red/green logs and rendered screens are recorded
under `docs/evidence/opening-prologue-checkpoint-regressions/`.

Further OPEN-031 edge case: tutorial Return and Skip restored live HP/Oxygen,
but saved before restoration. The initial extra assertion passed because Retry
healed the party and the fixture's second loss did not reapply damage. That
green result was rejected as missing the condition. Corrected fixtures apply
HP 1/Oxygen 40 after Retry and before Skip; the exact pre-repair source
`765a59e` produces six checkpoint findings. Tutorial loss now retains the
healthy prior save while the recovery choice is pending, Return saves after
healing/repositioning, and Win/Skip save after their shared recovery. The
corrected Return/Skip assertions pass. Real tutorial-win combat remains a
separate unproven boundary.

Exact-source `765a59e` web export completes ordinary New Game, both movies,
real mouse combat and recovery in **86.049 s**. Its actual IndexedDB checkpoint
contains `opening_video_seen=true`, `prologue_complete=true` and training false;
a cold page reload and real title Load restore phase `complete` without replay.
No browser/runtime errors. This validates that atomic replacement works through
the exported browser's normal persistence path, not its denied-write behavior.
It predates OPEN-031, so a new exact-source export must supersede it before
updating the review alias.

Final checkpoint candidate is **`2bf19acb86f1727f9ed199e669658bcb010ac036`**.
Exact clean archive export: **92,951,692 bytes**, digest
**`b56c773115f36905bc18a3b226778635456fdb24d88a1829edd4902098f0cffb`**.
Native real ordinary
death after voluntary training Skip and corrected Return/Skip persistence
assertions are green. Exact final browser runs both complete ordinary opening
and persist completion through a cold page reload/real Load:

- Chromium local exact export: **104.245 s**, no errors.
- WebKit hosted immutable exact export, serial run: **89.320 s**, no errors.

The concurrent WebKit attempt is retained as a failed verification run: its
keyboard action completed **12.682 s** after the spawn-phase notification and
the harness rejected the late dispatch. It contains no game/runtime error and
proves neither product success nor a Safari-specific save failure. No timeout
or acceptance criterion was relaxed; serial hosted replay passes.

Ready unauthenticated deployment **`dpl_12wKPV7Qg8x8mGbVcLhcnxGfyPFD`**, immutable
`https://underwatergame-a85nxr641-immortaldemongods-projects.vercel.app/`, now serves
the existing `https://underwatergame-opening-prologue-review.vercel.app/` alias.
Unauthenticated metadata reports the final source; served PCK matches the local
digest exactly. `https://underwatergame.vercel.app/` still resolves to
`dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`; no main/PR #96 merge or public-main promotion.
User saves remain untouched. No child PR is opened/pushed before the goal's
complete acceptance matrix, as required by the execution contract.

Visual review of the cold-loaded world exposes OPEN-032: the training label is
partly occluded by the diver in the default view. Record it for the ongoing
opening polish loop; this checkpoint repair slice is **not** a final zero-defect
round. The earlier user's particular incomplete checkpoint cause remains open.
Final browser JSON, raw failed attempt, main-alias inspection and package
metadata/digest are stored with the checkpoint regression evidence.
