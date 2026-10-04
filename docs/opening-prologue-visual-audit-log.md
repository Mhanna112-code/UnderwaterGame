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

No implementation round has been run yet.

Pre-audit automation note, 2026-10-03: `opening_video.gd`,
`opening_video_world.gd`, `title_screen.gd`, `opening_prologue_state.gd`, and
`audio_lifecycle.gd` pass for the isolated owner, independent lab skip policy,
world pause/input ownership, -6 dB Music routing, decoder fallback, successful
milestone persistence, failed-view replay, and completed-view non-replay. This
is not a visual-audit round and does not approve browser framing or mix.
