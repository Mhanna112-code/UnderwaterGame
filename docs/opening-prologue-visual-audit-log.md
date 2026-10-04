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

Pre-audit automation note, 2026-10-03: `opening_video.gd`,
`opening_video_world.gd`, `title_screen.gd`, `opening_prologue_state.gd`, and
`audio_lifecycle.gd` pass for the isolated owner, independent lab skip policy,
world pause/input ownership, -6 dB Music routing, decoder fallback, successful
milestone persistence, failed-view replay, and completed-view non-replay. This
is not a visual-audit round and does not approve browser framing or mix.
