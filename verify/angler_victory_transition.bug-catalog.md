# Angler victory -> Octopus suspense

## Responsibility and public interface

The opening's real Angler defeat must acknowledge a win before the split Cordys
movie plays. Battle emits its existing `prologue_angler_defeated` signal after a
genuine kill, while its busy latch suppresses ordinary XP/win/reward handling.
World owns the bridge and one movie/Battle owner. RouteState's phase signal is
the public lifecycle trace. The bridge exposes readable static beats and a
completion signal; input must not leak to paused gameplay beneath it.

## Load-bearing contracts / types

`prologue_complete`, `opening_video_seen` and `tutorial_complete` remain the only
durable opening milestones. Transient victory/notice/omen phases never become a
checkpoint or campaign boss victory. Existing split movie retains its complete
25-second introduction and title ending. The actual combat remains normal stats,
not a forced hit or victory. RouteState validates its phase vocabulary.

## IO and branching

- Actual player move -> normal damage -> dead Angler -> one interruption signal.
- First-signal phase guard prevents duplicate bridges/movies; nonlethal actions
  do not enter this path. UI timers/tweens run while World is paused.
- Victory uses the existing Phoenix pair at local -9 dB, then fades to silence
  during the omen. Movie audio starts only after that owner is stopped.
- Scene teardown cancels owned UI; refresh loads durable milestones, not a stale
  live phase. No writes during this bridge. Decoder fallback remains unchanged.
- Narrow/wide rendering and actual browser click/input/timing are independent
  boundaries; headless green alone does not establish readable presentation.

## Bug catalog

| ID | Failure mode | Blast radius / plausible cause | Cheapest check |
| --- | --- | --- | --- |
| VICT-001 | Real win jumps directly to movie with no readable victory | High: destroys intended confidence/reversal; current handler only waits 0.65s | Red real World/move-button witness; visible Victory before movie |
| VICT-002 | Suspense flashes too fast or skips the causal bridge | High: player cannot connect victory and Octopus; timers/fades can hide copy | Real-time public phase + visible-label assertions, native/browser frames |
| VICT-003 | Music overlaps movie or victory is too loud/changes preferences | Medium: prior opening sensory overload; global bus gain can be misused | Local cue gain/setting equality; stopped before movie; rendered listening evidence |
| VICT-004 | Input during bridge opens menus/starts another action | High: state/ownership leak; World has not completed opening | Real Escape/R/move input during paused bridge; owner and HP/position invariants |
| VICT-005 | Bridge awards XP/saves success or resumes ordinary world early | High: prior checkpoint bugs; reusing normal win handlers | Actual kill/journey: no XP/spells/completion, same Battle through Cordys |
| VICT-006 | Added live phases leak through Load or break the full opening | High: phase enum and expected journey can drift | Existing generated milestone x every-phase save/load property; full native/browser journey |
| VICT-007 | Copy clips or is obscured on small screens / hard-cuts to movie | Medium: old HUD overlap; independent CanvasLayer stacking | Native 1280x720 / 720x480 screenshots + transition GIF, browser visual inspection |

## Test order and self-critique

1. One VICT-001 red integration through actual Angler attacks, not a fake defeat.
2. Fix, then check the three ordered readable beats, 5.5–7.5s total bridge, actual
   input exclusion, transient state/reward/audio invariants and full handoff.
3. Update existing public-phase journey and milestone property tests; run them.
4. Export exact source; full normal browser New Game uses real combat and movies.

Semantic assertions reject a stable-but-empty/instant bridge. No exact whitespace
snapshots. Public visible copy/phase/controls are checked; test-only baseline
checkpoint skips Mermaid playback in the focused native fixture only. The hosted
normal-entry test must not use that fixture or accelerate the new bridge.

## Skipped

- Base combat balance, post-opening tutorial/navigation and lab/maze redesign:
  outside this request.
- New animation assets or new synthetic sound effects: use existing approved
  presentation/music, not unseen dependencies.
- A causal claim about the boss's lore or power source: not established; copy
  says victory attracted attention, not that killing Angler created Cordys.
- Arbitrary elapsed-time property generation: a fixed authored sequence; state
  restoration is instead covered by the existing bounded generated phase matrix.

## Evaluation

- Real attack-button red reproduced VICT-001: actual kill immediately entered
  `octopus_introduction`, with no visible Victory. Fixed gate passes headless and
  rendered at 1280x720 and 720x480 (6.60 / 6.63 seconds respectively).
- VICT-002 caught an implementation-time tween sequencing defect: the omen's
  copy faded concurrently with its intended hold. The delayed-alpha assertion
  now rejects that regression. The final fade follows the readable hold.
- Native visual inspection caught VICT-007: the dead Angler's turn queue and
  old move controls lingered underneath the bridge. A read-only texture of the
  actual 3D stage now excludes those controls, with aspect preserved. Final
  wide/narrow screenshots have readable, unclipped static copy.
- Real Escape/R/W during the bridge leave gameplay, encounter preference, HP,
  positions and the same Battle owner unchanged. No XP/spells/completion are
  awarded. Local fanfare gain and unchanged player audio settings are asserted;
  music is stopped before movie playback. These are lifecycle/gain checks, not
  a claim of subjective audio audition on every device.
- Existing full native journey and generated durable milestone x every-phase
  save/load matrix pass. The focused native fixture skips only the Mermaid
  movie; hosted normal-entry verification must play it in full.
- A first narrow run never entered combat while native harnesses ran together.
  Sequential real-input rerun passed; the test now reports missing setup
  separately rather than misdiagnosing it as an absent victory bridge.

Release and hosted evidence: `docs/evidence/angler-victory-bridge/README.md`.
