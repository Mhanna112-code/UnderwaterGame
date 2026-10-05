# Marc light-orb grapple integration

## Contract and code reading

Read `Diver`, `ItemOrb`, `GrappleAnchor`, `Cast`, and `CombatantStats` completely.
The public gameplay entry is `Diver.use_ability(direction)`. A physics hit on
an anchor pulls the diver; a hit on a light pickup reels it to the firing diver
and emits `ItemOrb.collected(item_id, diver)` once. Collection listeners own
inventory grants; the orb does not invent inventory or choose a nearby player.

Load-bearing rules: misses cost no cooldown; environmental verbs cannot be
exhausted by Oxygen; layer 2 divers must not obstruct aim; solid layer 1 walls
still occlude shots. Item targets use layer 5 to avoid blocking swimming.
IO boundaries: PhysicsServer ray queries, frame-driven tweens, actor deletion,
and pickup signals. Branches: miss/wall/anchor/orb, valid/deleted collector,
touch-only/grapple-only/reeling pickup, cooldown and scene teardown.
Existing World aim tests cover visibility/cancel/reticle size, not a real orb hit.

## Bug catalog

| ID | Failure | Risk | Test | Status |
|---|---|---|---|---|
| ORB-1 | Live grapple ignores layer-5 orbs visible in the aim preview | Required floating reward becomes unreachable | Actual physics shot and collection signal | Caught and fixed |
| ORB-2 | Grapple moves Musashi or awards the item to the nearest bystander | Wrong traversal and reward ownership | Moving shooter, closer bystander, identity assertion | Integrated and pinned |
| ORB-3 | Duplicate shots/touch collect a reeling pickup twice | Duplicate reward or wrong collector | Signal count, repeat input, synchronous reward re-entry | Hardened and pinned |
| ORB-4 | Shooter deletion leaves an uncollectable, untargetable orb | Permanent lost reward | Delete shooter mid-reel, retry with a surviving shooter; scene teardown | Hardened and pinned |
| ORB-5 | Broadening the ray makes walls transparent or buddies block it | Anchors/puzzle progression regress | Actual wall, ally and ordinary anchor shots | Preserved and pinned |

## Test design and self-critique

ORB-1/2 use the public ability with real collision targets; an independent
oracle is collection by exactly the firing diver with unchanged position until
the test itself moves that diver. A bounded set varies distance, translation,
gold shimmer, and movement rather than asserting a private tween implementation.
ORB-3 asserts one observable signal. ORB-4 asserts the surviving item can be
reacquired, not a private flag. ORB-5 asserts real motion and occlusion.
These would reject wrong-but-stable output and tolerate internal refactoring.

## Skipped

- Golden-shimmer pixel aesthetics: retained upstream artwork; needs later visual
  evidence, not a numerical assertion about its colors.
- F/E routing, embedded ownership, balance and save migration: separate required
  batches, not claimed by this ability test.
- Restoring upstream grapple/shockwave Oxygen charges: superseded by the approved
  environmental-ability anti-softlock contract; preserve free Swap and the safer
  existing environmental verbs.

## Evaluation

The first test on e7072ab exited 1: `ORB-1: actual zero-Oxygen grapple collects
the layer-5 light orb` failed. No script exception caused this failure; the
real firing ray simply missed the target. After integration, that shot passed.

Expanded native-headless verification passes six translated/distance combinations,
moving shooters, intersecting bystanders, cooldown/repeated shots, synchronous
body-event re-entry during collection, shooter loss/recollection, scene teardown,
wall occlusion, buddy-transparent anchor traversal and ordinary overlap collection.
The final run passed all 59 checks. Fresh `world_grapple_aim`, `animations`,
and `swim` gates also pass with zero exit and no captured script errors.

Adversarial omissions examined: cross-feature ray-mask mismatch (fixed preview
and fire through one constant), deletion during an item tween (retryable item),
and synchronous signal re-entry (guard before listeners). These are not claims
that every hypothetical bug was independently reproduced. ORB-1 is the captured
product failure; other rows protect the admitted upstream behavior.

This receipt does not claim full campaign acceptance or a refreshed hosted build.
