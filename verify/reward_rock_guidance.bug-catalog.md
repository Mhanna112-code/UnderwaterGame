# Reward-rock discovery catalog, October 5

## Responsibility and boundaries

World builds physical CrackedWalls keyed by stable rock IDs. Ground-level
rocks spawn random consumable ItemOrbs; two airborne rocks grant fixed keys
and two others start ambushes. CrackedWall's group broadcast listener only
breaks a nearby visible shape; Diver owns the real three-metre Shockwave and
cooldown. World owns consumed IDs, pending drops, inventory and save/load.
The public experience is approach -> visible guidance -> Tab/F -> broken
rock and reward -> normal exploration guidance. No HTTP boundary is involved
in gameplay; browser delivery is a separate generated-pack boundary.

Load-bearing rules: do not promise loot from scenery, route barriers or ambush
rocks; only guide the selected diver and within actual ability reach; consumed
rocks cannot guide or spawn rewards twice. Prologue completion gates abilities.
Deep guidance, solved puzzle and blockade hint retain priority; tutorial is
optional, so its completion must not gate discovery. Physics/position, random
drop identity and saved consumed/drop state are the IO seams. Relevant contracts
are CrackedWall.broken, ability_id=shockwave, rock_N stable IDs and Items' kinds.
Existing local_world_guidance/shallows_guidance cover region/puzzle transitions
but do not cover reward rocks, item benefit or real rock pickup.

| Bug | Blast radius / plausibility | Check and critique |
| --- | --- | --- |
| ROCK-1 nearby reward rocks lack switch/ability/reward guidance | High discoverability; current Shallows fallback ignores rocks entirely | Real World frames and W approach at first rock; label must name Bucky/TAB/F/Shockwave and items. Wrong-but-stable generic text fails; no helper assertion. |
| ROCK-2 stale/misleading guidance points at inactive diver, distant/high rock, ambush/scenery or consumed target | Medium; conditional spatial priorities and rock IDs differ | Generated 3D positions around first three rocks and explicit negative fixtures. Observes visible label and ability eligibility, not a copied conditional. |
| ROCK-3 suggested real controls fail to break/reward or hint persists afterward | High; Tab changes positions and pending reward is separate from consumption | Real Tab/F at the physical target, actual overlap collects an ItemOrb, inventory count rises, consumed target no longer guides. New World cold Title Load uses reserved disposable slot 918501, refuses overwrite and cleans it. |
| ROCK-4 hint wraps/clips or covers minimap | Medium; long key text and fixed panel layout | Native rendered 1280x720/720x480/360x640 frames plus label/panel minimum-height and viewport/minimap bounds. Visual inspection remains required. |

Generated positions are fixtures, not proof of continuous navigation. Actual
W/Tab/F and reward overlap are checked separately. The test must not lock exact
punctuation, item random identity or private helper names. It reads the visible
HUD and concrete gameplay rewards. Save fixtures do not simulate durable browser
storage or prove a complete fresh opening.

## Skipped

No new reward balancing, loot art, ambush reveal/maze tutorial redesign or full
campaign acceptance. Optional onboarding already describes Shockwave but not
specific reward-rock discovery; it is retained. No per-save hint counter is
needed: proximity and actual unconsumed target own this contextual prompt.

## Evaluation

ROCK-1 reproduced on the pre-fix World: actual W reached the first rock but
the visible text remained generic Shallows guidance. The first approach wait
was too short and was repaired before counting this valid red. ROCK-4 reproduced
under native rendering at 360x640: the minimap covered the new hint. Compact
controls now use the left map gutter and the hint sits below both surfaces.

The extended check passes with 36 generated near-rock positions around the
first three rocks, distant/high/ambush negatives, actual Tab/W/F, real collectible
or immediate physics-overlap pickup, consumed target cleanup and cold Title Load.
Native 1280x720, 720x480 and 360x640 captures pass geometry checks; desktop and
narrow frames were visually inspected. Existing Shallows, local puzzle/Deep
guidance and blockade waypoint checks pass; full gate suite was not rerun.

Observer repairs: a nonexistent public save-lesson field was removed (not a
product error); directly flipping prologue state does not execute the genuine
Load handoff, so an interrupted plain World checkpoint is now loaded instead.
An older local-guidance test also mixed an unfinished route with a completed
campaign envelope, correctly rejected by production; its fixture now uses the
proper plain World contract. Auto-overlap can collect the spawned item before
the test queries nodes, so the public inventory increment is accepted alongside
an actual ItemOrb overlap, rather than falsely requiring an orb to remain.

The hosted browser observer uses a disclosed, disposable recovered checkpoint
fixture, then real Title Load/W/Tab/F and rendered reward feedback. Browser
receipt is recorded separately after publishing a checked preview. This does
not certify a complete fresh opening or browser-save durability.
