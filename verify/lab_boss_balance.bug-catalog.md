# Lab boss attainable-victory catalog

## Responsibility / public surface

Tethys must challenge the actual party reachable at the lab, not an imagined
stat-growing party. `TethysBoss.make_stats`, `next_move`, normal Battle buttons,
Battle `finished`, XP/automatic spell learning and persistent party stats are
the surfaces. Model/clip checks are separate presentation evidence.

## Boundaries and branches

Normal level-2/3 loadouts, seeded attack variance/target choice/QTE opportunity,
single/all/multi-hit scopes, poison ticks, initiative/debuffs, healing, death,
ordinary win rewards and auto-learning. Actual timers and animations belong to
the integration test; speeding the engine is disclosed, never changing stats.

| ID | Failure | Test / oracle | Status |
| --- | --- | --- | --- |
| LAB-BAL-001 | Boss kills a full normal diver before the party has a meaningful chance to respond; defense-ignoring sweep wipes all 10-HP divers. | Actual level-2/3 Battle, no stat inflation; failed QTEs; first two boss moves leave a viable party. | confirmed baseline |
| LAB-BAL-002 | Earned spells/refills cannot produce an attainable boss victory; cosmetic level increases are mistaken for stat growth. | Actual buttons through real win/loss; seeded accessible and skilled policies; no keys/shards/HP boosts manufactured. | confirmed baseline |
| LAB-BAL-003 | An animation-only immortal fixture or supplied `won` falsely claims campaign balance. | Separate real victory-rate evidence and rendered real-party victory; animation/route gates labeled honestly. | confirmed baseline |
| LAB-BAL-004 | Fresh-party fixtures hide carried attrition, missed spell rewards or broken guard-to-lab dispatch. | Actual World positions dispatch Bomb Bot, Sword Slayer and Tethys; real menus/outcomes and ordinary rewards carry forward without heals or completion injection. | verification in progress |
| LAB-BAL-005 | Earned Heavy Slam can never land: Bucky ACC 1 plus modifier -3 remains below even EVA 0, making the growth reward unusable. | Actual earned spell/menu/target input against an exhausted-Evasion target; require damage and Oxygen expenditure, then verify a high-Evasion target can still evade and spend its pool. | confirmed code defect; reproduction required |

LAB-BAL-005 is a targeted invalid-content repair, not a spell-tree redesign.
Normal party stats and strict ACC > EVA remain unchanged. Removing the negative
modifier permits an exhausted-Evasion payoff while retaining misses against an
unprepared target. A known-spells assertion alone cannot catch this defect.

The same invalid modifier also affects ordinary Crushing Haymaker. Its tutorial
prose/comment still assumes an old Bucky Accuracy of 4; actual base is 1. Add
real exhausted/unprepared-target cases before fixing the ordinary move and
replace the false -3-ACC counter explanation with its actual Oxygen/EVA risk.
The five-move lesson structure is preserved; no new onboarding is introduced.

Harness correction: the first continuous-route attempt waited for automatic
combat after the lab film. Production deliberately waits for its visible
Continue button. That timeout is not a game failure; the test now presses the
real button only after actual film EOF. The hint formerly promised automatic
start, so its wording now matches the real Continue action.

## Self-critique

A boss with plausible static numbers can still fail these tests if production
turns, statuses, initiative, O2 or menus block victory. Tests do not require
specific HP/STR constants, only real outcomes and preserved attack identities.
Policies must spend real resources and the test must terminate on Battle's
own `finished` signal. A passing policy rate does not prove human readability:
real rendered and browser play remain independent rejection layers.

## Skipped

- Global stat growth and spell-tree redesign: established design, not needed
  to repair boss tuning against the current reachable party.
- Eventual campaign Cordys: unavailable route, not promised playable here.
- Claiming every possible inventory strategy was impossible: not established.
- Full six-clip animation witness at normal HP: some victories legitimately
  finish before all six moves; the separate animation gate covers every clip.

## Evaluation, 2026-10-04

LAB-BAL-001/002 caught: baseline real level-2/3 parties lost all 32 fights.
Revised 65-HP fixed boss wins 32/32 seeded attempts without timing dodges,
inflated HP, supplied keys or result injection. Direct policies lose 13–18 HP
across the party; Blindness/Weaken policies lose 3–5 HP. Minimum Oxygen is 68.
First two boss rounds retain a viable party; all six attack identities/mechanics
still pass the separately labeled animation/poison gate.

LAB-BAL-003 corrected evidence boundary: immutable animation tests still use
500-HP fixtures **only to test six clips/poison**, never attainable victory.
LAB-BAL-004 characterized: actual World dispatch and real victories complete
Bomb Bot -> Sword Slayer -> lab film/Continue -> Tethys, carrying normal rewards
and party resources. Level 2/spells arrive after the second guard, level 3 after
Tethys. A disclosed completed-opening fixture sets the starting state only.

Final human difficulty/readability and eventual campaign Cordys remain unproven.

LAB-BAL-005 caught and repaired: actual earned/menu/target attacks initially
dealt zero against EVA 0 and spent no EVA on a miss. With modifier 0, the real
attack deals damage against exhausted EVA, spends 8 Oxygen, and an EVA-2 target
still evades while spending 1 EVA. A third real-battle policy uses Blindness,
Electric Touch and earned Heavy Slam: the expanded matrix wins 48/48 across
three policies/eight seeds/levels 2 and 3 without HP inflation or timing dodges.
This preserves the counter setup rather than granting guaranteed heavy hits.
