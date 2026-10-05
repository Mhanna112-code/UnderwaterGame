# Bug Catalog: `verify/guardian_item_integration.gd`

**Updated 2026-10-03**
**Scope:** guarded-site dispatch, mapped enemy/reward ownership, and key-item persistence.

## Current contract

Guarded sites are proximity-driven records from `ItemGuardian.spots()`. There
is no physical `ItemGuardian` node or visible debug ring. A normal encounter
signal inside an unclaimed ordinary site must be intercepted into exactly one
mapped reward battle. Leaving grants nothing. Winning grants the key item once.
After save/load, a claimed site cannot reopen its reward encounter. Special
minigame sites share the content table but have their own chooser/minigame gates.

## Bug catalog

| # | Bug | Blast radius | Test | Status |
|---|---|---|---|---|
| GI-1 | A proximity signal inside an ordinary site starts a random pack. | Players cannot tell whether combat belongs to the reward and may never meet the mapped enemy. | Both ordinary sites, real World signal. | Green |
| GI-2 | The site loses its `reward_item_on_win` or mapped enemy in Battle construction. | Progression reward or authored enemy identity is wrong. | Differential site-to-Battle assertion. | Green |
| GI-3 | Fleeing grants the key item. | Rewards can be collected without winning. | Result lifecycle assertion. | Green |
| GI-4 | A won key item is dropped during save/load or its site reopens. | Progression can be lost or duplicated. | Fresh-World save/load round trip and proximity retry. | Green |

## Skipped

- Exact sonar/minimap pixels: browser visual verification owns presentation.
- Random encounter probability: the route/balance gates own distribution.
- Removed visible-guardian nodes and rings: restoring them would contradict
  the current approved discovery presentation rather than verify it.
