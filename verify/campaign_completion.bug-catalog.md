# Campaign completion and objective follow-up: bug catalog

2026-10-05. Scope: the World/Maze campaign result, handoff, checkpoint and
guidance module; RouteState, CampaignSession/Checkpoint, SaveManager and
BrowserCheckpoint read end-to-end. UI precedents: GameOverScreen and
PrologueRecovery. Unrelated World movement/minigame code is outside this slice.

## Contract and interface

Actual confirmed campaign Cordys victory completes the game visibly and saves
the existing independent `octopus_state=defeated` plus removed `main_boss`
station. Title Load must not replay the encounter or duplicate XP/rewards.
The opening and Cordys film relocation are explicitly deferred for Miguel's
final review. Fixed75HP boss, generic keys, independent laboratory and no
ordinary victory refill remain unchanged.

Public surfaces: physical boss approach and Y/No, Battle move/target buttons,
completion/retry/title controls, title chosen-slot signal, plain checkpoint
readback and validated restore. Existing completion of ItemRock is the relic,
not the campaign boss. Do not confuse its `maze_completed` signal with ending.

Load-bearing rules: CampaignCheckpoint strips recursive envelopes, retains
shared party identity and outer-world positions; SaveManager stages/flushes
before rename; browser success must await actual durable byte readback. A
save failure must preserve previous bytes and selected slot, and not promise
a saved ending. Completed opening is independent of laboratory/maze wins.

IO: actual combat randomness/time/animations; atomic user-file writes and
IndexedDB confirmation; SceneTree title destruction/reload; modal focus and
paused shared actors. Dispatch branches: ordinary/puppets/Cordys; won/fled/lost;
selected/no slot; write denied/write confirmed/sync rejected/rollback failed;
existing completion UI/first victory/completed load/legacy incomplete load.

## Catalog

| ID | Failure and impact | Why plausible / cheapest test | Status |
|---|---|---|---|
| END-1 | Final boss victory is only a temporary exploration notice and is not checkpointed | Current Maze result handler; real legal-kit battle through UI, visible modal and durable file readback | Reproduced red; local native repair passes |
| END-2 | Failed ending write falsely offers saved exit or destroys previous checkpoint | World write and async browser boundary; denied staging then actual Retry, exact bytes/slot checks; hosted IDB rejection separately | Native denied IO/retry and local exported browser IDB denial/retry characterized; hosted pending |
| END-3 | Title Load resurrects boss or rewards/opening, or completed save lacks ending | Cross-scene restoration; actual Return to Title/Load and resource/conservation checks | Native public title boundary characterized |
| END-4 | Completion screen leaks swimming/input or clips narrow choices | Existing shared party/HUD ownership; held W/Tab/P and 1280/720/360 rendered controls | Native held controls/bounds characterized; rendered images inspected |
| GOAL-1 | Maze-first/return/completed routes display stale laboratory/relic goals | Existing location/objective split; generated meaningful campaign state combinations and actual handoffs | Local native repair/evidence in campaign_goals.bug-catalog.md |
| LAB-1 | Lab victory never acknowledges recovered computer/controller before suggested maze | Current post-victory handler; actual lab victory presentation/progression and persistence | Local native real-win/Close/Load repair in campaign_goals.bug-catalog.md |

## Test design and self-critique

END-1 first: a declared level5 legal-kit/room fixture isolates ending, not
earning/navigation/balance. Real E spends a supplied key; actual proximity/Y
and ordinary move/target buttons win against fixed75HP. No won signal or
HP-zero injection. Require a visible completion screen, paused ownership and
saved defeated/removed station state. Wrong-but-stable temporary notice fails.
Observe result/UI/checkpoint, not an internal helper call sequence.

END-2: only a uniquely owned disposable slot is made unwritable. Actual retry
must save the live completed state while retaining previous checkpoint on
failure; hosted transaction rejection remains required before delivery.
END-3: actual title boundary and chosen-slot signal rebuild/restore the game;
compare earned XP/items and independently unfinished lab/puppets. No runtime
state injection during verification. END-4 adds actual keys/control bounds and
screenshots, not a golden snapshot. GOAL-1's state matrix must cover >5 shapes
with explicit intended destination invariants. LAB-1 must show player-visible
payoff, not merely a milestone name. Add each only after the prior red is fixed.

## Skipped/deferred

- Tethys opening/Cordys film relocation: user-approved final review gate;
  leave current opening untouched throughout this batch.
- Full earned casual/skilled balance and complete key/maze navigation: separate
  next batch; a granted-kit win is not proof of earning the kit.
- New music/voice/dialogue or boss/key tuning: not authorized by this follow-up.
- Mermaid variant role: inspect its actual asset before deciding; no speculative
  model replacement inside the checkpoint repair.

## Evaluation

- Caught END-1: baseline real 12-action win yielded zero screens, unpaused
  exploration, saved `available` state and live station. Four independent
  assertions failed. Local repair yields one paused completion screen and
  saved `defeated`/removed station, with independently unfinished lab/puppets.
- END-2/3/4 passed when added after END-1 was green. Native denied staging
  preserves exact prior bytes/selected slot; real Retry confirms the completed
  live state. Actual title button reloads World, chosen-slot Load shows ending
  with unchanged save bytes, XP/level/HP/O2 and no live boss/opening replay.
- Rendered Metal run passed with held W/TAB/P, 1280/720/360 widths and actual
  denied/saved/loaded screenshots. Inspected narrow success and wide denied
  surfaces: wrapped readable status, exclusive backdrop, reachable choices.
- Adversarial preservation: existing standalone Cordys confirmation and 48
  generated World/maze checkpoint cases plus legacy cold Load still pass.
- Actual local exported-browser fight now characterizes durable-IDB rejection,
  exact previous bytes/disabled exit, Retry, responsive controls and destroyed-
  page cold Load with exact completed bytes. Receipt under
  docs/evidence/campaign-ending-oct5/browser-local. Native file readback was not
  substituted for this proof. Hosted acceptance remains pending; no complete
  earned-route, full-suite or release claim.
- No tests removed; no additional confirmed bug outside END-1 yet. GOAL-1 and
  LAB-1 remain separate next tests, not characterized by this ending fixture.
