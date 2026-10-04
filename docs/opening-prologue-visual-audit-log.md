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
