# C5 collision and interrupted wall rotation — October 5

Base PR100: `3af1587`. This batch admits only the C5 no-carry exception and
moving-wall collision lifecycle, not complete maze geometry or merge readiness.
Source digests are recorded alongside the receipts.

## Actual defects and repair

The original published wall10/11 rotation retained real wall/skirt collision.
After porting Marc's C5 exception, generated capsule motion still exposed a
shove: the collider was `CSGBox3D10/SplitRock/Body`, a child travelling with the
wall. Suspend all attached collision bodies during the swing and restore their
exact prior layers afterward, rather than hardcoding layer1.

Tween ownership now cancels before checkpoint geometry is restored, on subtree
deactivation and on teardown. A killed Tween cannot retain the motion/input/save
lock indefinitely. Interrupted sets settle at their requested stable destination;
a valid checkpoint then supersedes it without a delayed old Tween rewriting it.

## Proof and limitations

- `red-original-collision.log`: actual wall/skirt ray queries fail on the base.
- `red-attached-rock.log`: real capsule displacement and slide collider expose
  the split-rock omission after the first port.
- `accepted.log`: 48 physical wall/skirt queries; 18 C5 cases (three actors ×
  opening/closing × three positions), positive swept-volume frames; nine JSON
  restores with genuinely selected actors at three interruption times; real
  swimming afterward; killed scheduler and inactive/re-entry cleanup.
- `current-on.log`: the same matrix with the authored C5 current active; movement
  is permitted by actual water/velocity, not by a direct wall shove.
- `teardown.log`: remove the actual maze owner while World actors survive;
  walls/skirt/split-rock restore non-default layers5/9/17 and stable geometry.
- Native `c5-motion-N.png` / `c5-released-N.png`: structural rotation view and
  post-return camera. During the overhead shot opaque moving walls may hide the
  actor; screenshots alone do not prove capsule clearance. Independent physical
  queries and post-release views provide the stronger checks. No browser claim.
- Preservation receipts cover original outgoing/return passages, new Box12
  route/old-save migration/cold Title Load, and grapple aim/teardown.

Fixtures position the real party to isolate this geometry and use the published
map rotate action. They do not prove an ordinary earned-map campaign journey.
No player save is written by the new wall verifier; the preserved Box12 gate uses
only its guarded disposable slot918367 and removes that own fixture afterward.

The initial actor type-inference parse error and early repeated selected-actor
labels were verifier errors, not product bugs. Only corrected terminal/error-free
receipts support accepted claims. Original versus adapted reds are distinguished
in the bug catalog.

Still required: retained outside-C5 riders and safe set-downs, western barrier,
hall whirlpools, autosaves, full normal campaign/browser checks, exact-source
public rebuild/packages and final PR readiness. The hosted alias remains old
`bffe1b5`; this batch does not update main or the canonical deployment.
