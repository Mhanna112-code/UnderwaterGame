# Recurring saved-game opening replay investigation

2026-10-04. Player report: clicking Load Game plays the opening cutscene.
Gameplay was not changed or redeployed by this investigation. Review source:
`4c6ca744e528c3cd11f98815e97ce2afe341043c`.

## Observed, not inferred

- Current hosted ordinary New Game, full media, actual mouse combat choices,
  recovery Continue, IndexedDB inspection, cold page reload, real Load Game
  and slot selection returned directly to controllable Shallows. Saved
  `opening_video_seen` and `prologue_complete` remained true before/after Load.
  The additional public phase was only `complete`; no opening/spawn phase.
  `browser-result.json` retains the full run and its independent failure:
  engaged opening time 125.710 seconds exceeds the existing two-minute band.
  That whole-flow failure is not a Load failure or a green whole-opening claim.
  `loaded-world.png` was visually inspected and confirms the returned world.
- Native state/migration matrix passed. Native actual opening-combat journey,
  persistent recovery checkpoint, ordinary loss-result boundary, scene restart
  and independent title Load passed after the stale reveal wait was repaired.
  Ordinary loss in this default native test is a result-boundary fixture, not
  a claim of newly testing actual ordinary enemy-caused death this round.
- Cross-slot denial gate was NOT run successfully: it refused existing owned
  fixture files in the reused isolated user directory. No files were deleted
  to manufacture a green result. This does not alter the independent hosted
  completed-slot Load observation.

## Existing player profile, read-only Safari inspection

Origin is the correct stable review URL. Developer-console inspection only
opened existing IndexedDB databases and readonly transactions; no save was
written, deleted, migrated, loaded or assigned guessed completion.

| UI slot | Stored file | Timestamp (UTC) | Opening seen | Prologue complete | Tutorial complete |
|---|---|---|---|---|---|
| 1 | slot_0.json | 2026-10-04T11:41:10.232Z | true | true | false |
| 2 | slot_1.json | 2026-10-04T04:08:30.065Z | true | false | false |
| 3 | slot_2.json | 2026-10-04T13:09:02.358Z | true | true | false |

All three parties are level 1, so the title's level-only summaries do not
distinguish these milestones. No claim is made about which slot the player
selected. The active Safari page's `GODOT_CONFIG.fileSizes['index.pck']` is
104,161,224 bytes, matching the earlier `a4c2445` TAB-hint export. Its retained
combat console uses `PROLOGUE_BREATH` (old AoE). A no-store build-info fetch
reports current served source `4c6ca74`, PCK 111,641,396 bytes. This proves an
already-running older page, not that stale code caused the reported replay:
the older build also has completion/viewing guards in its Load path.

The inspector was closed and the paused Inventory view restored. No reload
was performed, because it would discard the player's unsaved exploration.
An attempted read-only AppleScript query did not return and was terminated;
the successful read was through Safari Web Inspector, not that attempt.

## Captured verification defect and remaining question

The native save/load journey expected ordinary combat after one frame. The
new 1.5-second reveal made it fail OPEN-018 and exit before death/Load tests.
It now waits up to five seconds for observable Battle ownership. Missing
battles still fail; no timer fast-forward or completion injection was added.
This repairs coverage, not a proven player-facing save bug.

The recurring report remains unresolved until the selected slot and replayed
movie are identified: Mermaid opening versus Cordys introduction/aftermath.
Do not infer prologue completion from level/tutorial/merely having a file or
retroactively rewrite the player's older incomplete slot.
