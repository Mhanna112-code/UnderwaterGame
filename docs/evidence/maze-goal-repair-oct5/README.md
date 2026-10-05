# Maze destination and reading ownership repair — October 5

This is a bounded repair of fresh main 3604bc3 (runtime includes Marc f457098
and latest-save recovery e74fcc5). It is not full-campaign acceptance.

The current-main GOAL-1 receipt in `../main-intake-f457098/campaign-goals.log`
has 40 failures: all milestone-aware maze goals are hidden. The repair restores
only the destination, not the removed generic Controls label or E/F suffix.
The goal yields to notices, Inventory, map/lesson and grapple aim. No opening,
combat formulas, acquired items, geometry or save-state rules change.

## Evidence and scope

- 40 generated lab/map/relic/stale-objective fixtures, physical enter/return and
  real R/Escape/L/Tab/F transitions pass in the corrected native observer.
  Fixtures are explicitly not earned campaign travel or acquisition.
- 72 earned-map region boundary cases pass without expanding the allowed area.
- Existing real aim/cancel/fire/occlusion/teardown and map whirlpool ownership
  checks pass. No save files are written by these caption/aim/map probes.
- Native Metal rendered matrix/owners pass at 1280×720 and 360×640 before the
  layout follow-up. Inspection found the existing long aim title expanded
  past the narrow viewport, clipping fire/cancel instructions. A new GOAL-5
  bounds assertion reproduces exactly one failure. Its raw red and image
  are retained. The final local follow-up wraps long titles and puts aim's
  fire/cancel actions on their own lines. The actual 360px rendered matrix
  and owner sequence then pass with the complete action text visible.
- The initial new ownership observer used a generic maze boundary point
  outside the map region and ignored Tab's legitimate four-second notice.
  Its three findings are retained under `rejected-observers/`, not counted
  as production defects. Corrected fixture uses the actual authored entry
  and waits for the real notice to drain.

Exported browser acceptance and publication are pending. The extended browser
check starts at the diagnostic maze entrance,
then physically swims and presses E to earn the map. It does not inject map
ownership, but is not a normal New Game/full campaign or browser-save test.
Native captures with a fixture-only empty discovery map do not demonstrate
earned/discovered map geometry; the actual browser acquisition checks do.

Initial Angler removal remains a separately recorded current-main conflict.
The Tethys opening/Cordys movie relocation stays LAST and requires Miguel's
explicit review/approval before main or canonical publication.

The first exact browser export (0bba64f, d1ff9ea5 pack) caught a separate
GOAL-6 presentation gap in the real diagnostic entrance: its prologue flag
correctly remains false, but that suppressed active maze guidance too.
The actual native --maze-playtest startup reproduces the missing destination.
The repair allows maze guidance independently of that flag without mutating
it, laboratory progress or acquired map state; unfinished World opening
guidance still stays hidden. Final native review-route checks pass. The
opening sequence/actors are not changed. Browser proof requires a new export.

The complete runner was stopped at orange_messages before older save tests
could temporarily remove ordinary human slots. The isolated rerun uses the
same linked game/test sources and exact exported browser pack, but a copied
project.godot with only config/name changed to UnderwaterGame-gates-qL8P9b.
The observed OS user-data directory confirms the separate namespace. This is
verification filesystem isolation, not a changed public game build. Existing
human save filenames remain present. The complete rerun is still in progress;
its result is not implied by the focused greens above.
