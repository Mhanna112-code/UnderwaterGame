# Orange announcement FIFO and presentation ownership

October 5, 2026. Authored contract: #97 835047b / #99 4a1ec34, retained in
#97 4ec6598. One current orange message plus at most four waiting messages;
FIFO, duplicate suppression/renewal and latest-only encounter-toggle feedback.
This is separate from CharacterAbilityPopup's existing WeakRef lesson FIFO.

## Module and boundary understanding

World's orange banner shares its text with held intro/save-point prompts.
Maze's banner shares the bottom area with its goal/control captions and an E
interaction cooldown. Current World/Maze announcement code overwrites a live
notice. World stops its timer during battles/inventory/maze ownership; Maze
currently drains it even when a modal/map/battle hides it. New shared queue
state must be scene-owned, not another autoload or persistent progression flag.

Public surfaces: physical R/Q input and visible labels; save-menu requests and
actual slots; explicit queue enqueue/tick/clear API. Time is supplied by the
active exploration owner's physics update, not background wall-clock time.
Relevant branches: empty/current/queued text, duplicate current versus pending,
on/off toggles, overflow, hidden versus readable HUD, pending intro/save prompt,
ownership change, new scene versus restored one. Messages aren't save data.

| ID | Failure and blast radius | Cheapest meaningful oracle | Status |
|---|---|---|---|
| MSG-1 | A later notice replaces an unread reward/warning. | Actual R then Q, both owners: current label remains R until its readable time finishes, then shows Sonar. Queue's independent FIFO examples/property traces. | fixed, actual-input red captured |
| MSG-2 | R spam fills/evicts the queue or leaves stale encounter preference. | Generated mixed normal/toggle/duplicate enqueue traces: one latest toggle, up to four pending, retained normal FIFO ordering; actual R sequence behind Q. | characterized after FIFO repair |
| MSG-3 | Hidden map/modal/battle/inactive HUD consumes important notices. | Actual map/inventory/Save-menu input plus readable labels after closure; timers advance only on active readable owner. | Save-menu red caught and fixed; map/inventory characterized; final cross-area/fight release checks still required |
| MSG-4 | Save-point/intro held text overwrites the queue, or transient old text leaks after fresh opening/recovery. | Actual save-point arrival with a pending notice; held prompt only after queue empty; reset/scene lifetime checks. | contact/held prompt/model clear/new-scene isolation characterized; full campaign reset acceptance remains open |
| MSG-5 | Queued E feedback fails to hide the interaction prompt, allowing repeated interactions to renew/block the queue. | Actual E at the split rock behind R: white prompt hides, repeated E cannot prolong its notice, and the prompt returns when the queue drains. | characterized with adapted interaction revision |
| MSG-6 | Failed save followed by a successful retry loses one confirmation or changes the wrong slot. | Real denied atomic staging write, slot/file-byte checks, retained failure followed by eventual successful confirmation. | characterized; obsolete immediate-replacement oracle corrected |

Self-critique: enqueue/tick are the new model's public API, not private engine
helpers. Independent sequence oracles catch stable but wrong FIFO/coalescing;
real input/labels cover production wiring. No callback-count or screenshot-only
assertions. Generated traces cover more than five shapes. Map/menu fixtures
disclose any pre-granted map and don't claim ordinary acquisition.

## Skipped

- No persistence of transient text; saves retain progression, not stale banners.
- No new priority UI, notification center or narration. Overflow keeps Marc's
  newest-four pending policy; encounter toggles coalesce rather than accumulate.
- Full campaign/recovery economy and public deployment remain separate work.
- Existing tutorial popup FIFO is not rewritten.

## Evaluation

- Caught: actual Q immediately replaced unread R in World on the original
  overwrite implementation (`input-overwrite-red.log`). A further composition
  probe caught SavePointMenu consuming unread messages because that menu does
  not pause the tree (`save-menu-red.log`); the FIFO alone did not fix this.
- After repairs: both headless and native actual R/Q, twenty-toggle coalescing,
  Inventory/map/Save-menu preservation, physical W/save Area3D contact/whole-party
  recovery/held P prompt and actual queued E cooldown/drain/reuse pass. Native
  screenshots were inspected, including the multiline rock notice.
- Model: 228 generated newest-four/FIFO/renewal/mixed-toggle cases plus authored
  duration, negative elapsed time, milestone preservation and clear semantics
  pass. New Maze does not inherit a destroyed World's pending notices.
- Real denied atomic save/retry retains source and target file bytes on failure,
  changes selected slot only on success and shows failure then success. The
  prior combined slot/banner assertion expected immediate overwrite and failed
  for the intended FIFO behavior; this is an obsolete oracle, not a save bug.
- Wiring errors excluded from product-red counts: CanvasLayer has `visible`,
  not Control's `is_visible_in_tree()`; the first World fixture also omitted
  showing its HUD and therefore correctly froze readable time. Accepted runs
  explicitly show/assert the active HUD. These invalid runs are retained.
- Preserved regressions: 86 real exploration-control checks, map review-route
  acquisition/return, real Stun/Angler dispatch, WeakRef tutorial FIFO and missing/
  malformed checkpoint handling pass. This does not claim the full gates, normal
  campaign routes or a current hosted build.
- Sonar follow-up: coalescing now distinguishes Q from R, so each control
  keeps its latest state without deleting queued rewards. Model coverage is
  now 484 cases. Full live R/Q/menu/save-contact/E rerun passes after adapting
  post-physics observers to a complete update. A separate paused first-L
  regression confirms the real synchronous map-caption leak (DISC-8) and
  its repair; this is not merely an assertion timing adjustment.
