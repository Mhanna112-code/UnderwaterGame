# Sonar and encounter friction

Generated with design-tests, 2026-10-05.

## Responsibility and contracts

Diver owns Q's toggle, Oxygen billing, and local discovery. World and MazeSpecialSites own physical guarded-site entry, solo chooser dispatch, reward/consumption and re-entry latches. R owns ordinary random combat, not authored destinations. Maze's strong-room forced encounter policy remains independent and unchanged.

Public boundaries: actual Q/R/W/S input, the engine's elapsed-seconds physics callback, visible chooser and Battle, checkpoint JSON and public CampaignSession handoff. IO: time/physics, random distance rolls, resource identity, saved discovery/consumed flags, media/modal ownership.

Load-bearing comments: Sonar and its discovery ping have separate clocks; switching areas preserves the billing clock; losing Oxygen shuts Sonar off; sites latch until exit to prevent prompt loops. World discovery follows the active diver even if Maxilani is parked. Maze vision deliberately follows the active Sonar diver.

Branches: Sonar off/on, non-Sonar actor, zero Oxygen, exploration paused, elapsed billing boundary, saved partial interval; site absent/present/consumed/latched, R off/on, first special tutorial/chooser, inactive area, height/wall obstruction, menu/aim/battle owner. Site and result strings come from Sites, MazeSpecialSites.DEFINITIONS and RouteState/CampaignCheckpoint, not arbitrary test literals.

Existing tests pin special dispatch/results, random toggle, physical sites, maze placement and persistence, and Marc's Sonar vision. Some maze fixtures used R-off as an incidental setup lock; they must use actual modal/inactive ownership now, not retain the contradictory gate.

## Catalog and self-critique

| ID | Failure and impact | Plausibility | Test and independent oracle |
|---|---|---|---|
| FR-1 | Navigation consumes most/all of a 100-Oxygen tank in two minutes. High: combat and exploration become competing bottlenecks. | Current bill is 3 per 3 seconds. | Elapsed-time budget: 120 seconds uses 20 Oxygen (one-charge floating tolerance). Generated frame partitions must not alter the budget. No assertion derives its expected spend from production constants. |
| FR-2 | R-off prevents the physical red-dot special site from opening. High: finding content requires unrelated random combat. | Both World and Maze special dispatch explicitly read the random preference. | Actual Q discovery then Q-off/R-off W swim into the real World site; visible chooser/solo battle. Maze site with R-off/Q-off physical approach and modal/height/wall negatives. |
| FR-3 | Removing the toggle gate causes cancel/retry prompt loops or consumed rewards to return. High: modal trap/duplicate loot. | Site latches were cleared whenever R was off. | Existing physical exit/re-entry and JSON consumed-state/reward matrices, with fixtures using legitimate inactive/modal ownership. |
| FR-4 | Sonar bills during a paused owner, loses its saved partial interval, or goes negative. Medium: hidden resource loss. | Timers are serialized separately from Oxygen. | Engine callback off/paused/zero boundaries, public CampaignSession handoff of a partial interval; no recharge or immediate duplicate bill. |
| FR-5 | Help/HUD still teach that R gates destinations or quote the old drain. Medium: operational contradiction despite green code tests. | Onboarding has hardcoded 3/3 fields and prose; HUD says only Encounters. | Open the real onboarding page and compare its declared billing data to independently verified runtime budget; inspect rendered Q/R-off site/chooser HUD. |

Tests assert resource quantities, site access and exclusive input owners, not helper calls, node counts or styling snapshots. Supplied completed-prologue/near-site placement is disclosed; no claim of earned campaign progress or a minigame victory. Frame partition generator covers more than five bounded time shapes. The traversal test never teleports after approach begins.

## Skipped

- Global combat balance, ordinary encounter frequency, maze strong-room forced encounters and random roster: preserve existing design.
- Full earned campaign and special-minigame balance: this change is access/billing, not their rules.
- Music/audio and asset placement: unrelated.
- Sonar toggle-on grace interval: retain the existing deliberate grace policy; changing it is not needed for this fix.

## Evaluation

Pending red witnesses, repairs, existing ownership/persistence regressions and exported browser route.
