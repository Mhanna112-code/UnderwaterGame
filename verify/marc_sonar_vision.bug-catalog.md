# Sonar-following hidden-hazard vision

October 5, 2026. Authored #97 c943218/bbadaaf retained in 4ec6598 makes
Sonar Vision part of Maxilani's Q sonar: no pickup and no separate G toggle.

## Module and interface understanding

MazeLevel selects the active shared Diver, accepts Q/Tab input, exposes
sonar_vision_active/hidden_marker_positions, and drives SwirlRoom's visible
MultiMesh. SwirlRoom's positions/contact damage remain independent of reveal.
Campaign snapshots retain legacy has_sonar_vision/sonar_vision_equipped boolean
flags; those obsolete gates must not disable Q after loading old saves.

Public boundaries: real Q/G/Tab input and HUD text, visible hazard mesh, public
campaign_snapshot/restore_campaign_snapshot and CampaignCheckpoint JSON APIs.
IO: no player files; JSON round-trip in memory. Time: actual physics/sonar drain,
not a mocked toggle or manual reveal. Branches: active diver identity, Q on/off,
inside/outside sphere room, maze active/inactive, four old ownership/equipment
flag pairs, fresh versus restored state, depleted O2 and a paused reading menu.
Types: legacy flags boolean; party stats CombatantStats; sonar passive only on
Cast's Staff_Diver; SwirlRoom is a Node3D with an independent hit signal.
Existing spacing/route/occlusion checks cover movement/damage/presentation, but
the route fixture currently pre-grants both legacy flags and misses this port.

| ID | Failure / impact | Test | Status |
|---|---|---|---|
| SV-1 | Q fails to show hazards until a separate late pickup/G action. High: players cannot use the authored sonar to navigate hidden obstacles. | Fresh sphere-room fixture, real Q and rendered hazard visibility; no pickup or G HUD instruction. | caught and fixed |
| SV-2 | Legacy false flags disable the new Q behavior or migration resets resources/rewards. High: old saves restore a contradictory/less playable system. | Four legacy flag pairs × three selected actors through real JSON decode/party/snapshot restore; real Q/Tab, ownership/resources/key assertions. | 12 restored actor/flag cases pass |
| SV-3 | Non-sonar diver, Q off, outside or inactive area keeps hidden hazards revealed. Medium: stale reveal/discovery crosses input owners. | Real Tab/Q, physical inside/outside fixtures and public maze activation; active/mesh/marker semantic checks. | characterized after active-owner port |
| SV-4 | Menu input/G bypasses the Q contract or zero O2 leaves a misleading active sonar. Medium: UI teaches and reports an unavailable action. | Actual Escape/G/Q with menu ownership and depleted resource fixture; no G toggle or pickup. | characterized after obsolete pickup/G removal |
| SV-5 | Queued Sonar-on notice contradicts the latest Q-off HUD state. Medium: players cannot tell whether the O2-consuming passive is active. | Real rapid Q on/off and latest visible notice; generated independent Sonar/R coalescing with preserved rewards. | caught and fixed; 256 mixed toggle cases |

Self-critique: visible mesh, labels, resources and real input are semantic
oracles, not callback counts. Save data is actually encoded/decoded/restored.
Generated flag/actor shapes exceed five and guard the whole compatibility class.
Near-room fixtures do not claim a normal earned-resource journey.

## Skipped

- No free sonar or changed O2 billing; environmental abilities remain distinct.
- No changes to rock positions, damage, knockback, earned keys or map acquisition.
- No new narration/dialogue or replacement tutorial-popup implementation.
- Full ordinary maze route/browser/export acceptance remains on the main ledger.

## Evaluation

- Caught SV-1 on fresh actual Q; after the port, native rendering exposed
  SV-5 (HUD Off but orange notice On). A semantic Q-off assertion reproduced
  that second defect; independent Sonar/R coalescing repaired it.
- Fresh and all 12 legacy flag/actor cases pass headless and native Apple M1
  OpenGL compatibility rendering; Q on/off captures inspected. Saved HP/O2,
  generic keys, inventory and campaign relics are conserved. This is an
  in-memory JSON round-trip, not browser durable-storage evidence.
- Probed cross-feature composition: full live orange test exposed map-caption
  leakage. A paused actual first-L regression (DISC-8) reproduced it with no
  later physics update available. Maze-owned synchronous visibility repaired
  it; full orange/menu/save-contact/E sequence and paused map checks pass.
- 484 queue cases include the 228 existing FIFO/duplicate/newest-four traces
  and 256 independent mixed Q/R traces. Real sphere-room traversal/damage/
  vortex E, embedded ramp/parked-area ownership, 86 controls, earned chest
  swimming/E/L/return and denied checkpoint/loss/Restart regressions pass.
- Observer corrections are not product defects: post-physics-frame label
  assertions saw the pre-update HUD; they now observe a completed update.
  The old checkpoint test required instant warning replacement, contrary to
  FIFO. It now waits for readable failure while preserving immediate slot
  and byte-conservation assertions. The paused first-L leak was independently
  confirmed, not dismissed as timing.
- Evidence/commands/fixture limits: docs/evidence/sonar-vision-oct5/README.md.
  No full-suite, normal-campaign, hosted or target-platform claim.
