# Marc main follow-up bug catalog, October 5

Scope: Goblin's public stats factory and World's post-opening waypoint lifecycle.
Goblin selects ordinary versus explicitly requested legacy scaling, constructs
fresh stats and sets XP. CombatantStats owns integer stats and live resources;
Swordfish/Frilled Shark preserve their own authored blocks. World owns campaign
completion, active diver, menus/combat and physical cracked-wall state.

Public surfaces: `Goblin.make_stats(reference, level)`; normal World physics,
Tab input and the visible world-space arrow. IO boundaries: seeded random rolls,
physics frames, persisted completed-opening/broken-wall state. Only a reserved
disposable slot is written, refusing an existing file and cleaning up afterward.
Arrow must disappear at close range, in another
area/battle, and after its actual target is broken or loaded as consumed.

| ID | Failure | Test / critique |
|---|---|---|
| FOLLOW-1 | Ordinary random boosts still reach 25%, changing hit/damage outcomes instead of Marc's 10% ceiling. | Generated seeds through public Angler factory; Accuracy 3 must stay 3, and other outputs must stay within independently calculated rounded 5-10% bounds. A stable wrong factory fails; private random helpers/constants are not the oracle. |
| FOLLOW-2 | Legacy scaling also boosts Evasion, changing who can hit. | Separate actual `--legacy-enemy-scaling` launch, generated reference Evasion 0-30; returned EVA must equal the greater of the authored floor and reference. Tests the public factory, not its private helper. |
| FOLLOW-3 | No blockade arrow appears after completed recovery, or the arrow targets the tutorial and becomes stale after movement/Tab. | Real World physics, generated separated positions, projected visible mesh direction against the physical target, actual Tab. Uses a named visible scene element, not a helper invocation. Wrong but stable target/rotation fails. |
| FOLLOW-4 | Arrow leaks over combat/maze or survives a broken/loaded-consumed blockade. | Live battle/ownership negatives, actual Shockwave break and a disposable serialized consumed-wall cold Title Load. No reconstruction of expected private conditionals. |

Skipped: whole combat rebalance, Tethys opening pivot, full campaign/maze
acceptance and browser persistence. Those are not fixed by this narrow patch.
Swordfish/Shark tables must not be changed merely to make the Angler factory
test pass. Existing learned-spell, status, opening, save/load and ramp checks
remain preservation checks, not proof of a full game playthrough.

## Evaluation

The pre-fix public factory failed 39 ordinary samples and 89 legacy samples.
The pre-fix World check observed no blockade waypoint after completed recovery.
Both 96-seed stat runs now pass. Real World physics/Tab/F, battle and maze
ownership, target consumption and cold Title Load checks pass headless and
with native Metal rendering. The 1280x720 frame was visually inspected:
the light-blue directional arrow renders above the diver; this is not a
redesign of the existing guidance or a full visual-polish acceptance.

Observer repairs: an initial test type-inference error was corrected before
counting product failures. Approaching the blockade also enters a real save
point lesson and pauses gameplay; normal Escape dismissal was added before
checking resumed exploration. These were test defects, not extra game fixes.
Battle return is driven through the production `finished("fled")` signal;
it tests waypoint ownership, not the outcome/probability of pressing Run.
Position fixtures test direction across twelve points, not continuous human
swimming. Reserved slot 918499 is refused if present and removed after the
test. Existing learned-spell scaling, Glassgoat combat and checkpoint-load
failure checks also pass. The complete gate suite was not rerun.

Receipts are stored under `docs/evidence/marc-main-followup/`.
