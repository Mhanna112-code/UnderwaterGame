# Retained wall riders — bounded October 5 batch

PR100 source built on ae13281; `source.sha256` identifies the exact production
and verifier files. This is one behavioral integration batch, not campaign or
release readiness. No new PR, main push/merge or deployment promotion.

## Repair

Outside C5, intercepted capsules retain their wall-local offset until motion
finishes. A transient owner prevents currents, swimming or another wall from
fighting that motion, preserving the actor's original mask and resources.
It refuses to steal a grapple/suction lock. Final release tests the real capsule,
solid CSG volumes and forecast attached skirts/rock against target geometry.
A newly obstructed destination is searched on the same wall face; no unchecked
blocked-point fallback. If no landing is available, saving stays locked while
bounded retries await clearance. Cancellation also validates a recovery approach
rather than trusting a stale cached point. The pathological case where BOTH
landing and recovery are entirely obstructed emits an error and is not treated
as safe release; no authored-route case has exhibited that condition.

Checkpoint cancellation releases ownership without changing already-loaded
party poses. Inactive/removed owners restore live actors and exact masks.
Already-carried actors arriving in C5 detach in place; walls10/11 remain ghosted
during motion and become solid afterward as verified by the preceding batch.

## Evidence / limits

- `red.log`, `red-observer.gd`: genuine original swept contact; frame8 loses
  along-wall offset. Earlier no-contact/paused fixtures were rejected.
- `matrix.log`: six walls × three capsules × opening/closing =36 actual carry,
  clear release, mask5, HP7/O2=0 and real W-swimming cases.
- `lifecycle.log`: three actors × restore/killed scheduler/inactive owner/
  removed owner/C5 arrival =15 cases. Loaded poses remain stable95 frames;
  removal preserves shared actors; C5 arrival relinquishes carry in place.
- `ownership.log`: three downed bodies and three preexisting public locks;
  no revival/refill or lock stealing.
- `blocked-current.log`: actual WaterCurrent overlap during sustained carry;
  new opaque CSG volume at the preferred landing forces a clear alternative.
- `c5-current.log`, `drafts.log`, `aim.log`, `box12.log`: focused preservation.
- `native.log`, `rider-moving.png`, `rider-released.png`: native Metal/Forward+
  runtime, 1280×720. Inspected: motion camera obscures most of the rider;
  ordinary close-wall chase framing crops the released actor. These images do
  NOT establish complete visual polish. Final integrated visual/browser
  acceptance must address framing/readability; no screenshot-count claim.

Generated placements isolate real geometry and motion. They are not an earned
map acquisition, normal New Game route, casual/skilled balance or target-OS
launch. No player save slots are written by the retained-rider driver.
Full current gates, normal campaigns, browser and final exports remain pending.
Public review alias still serves bffe1b5, not this batch.
