# OPEN-039: optional tutorial victory lockup

Runtime repair: `97782962fdb224aa6e76c1c9a7b1821a422b8829`.
Stop the infinite guided-button highlight tween before freeing its targets.
No tutorial curriculum, stats, assets, or opening-story changes.

## Evidence boundaries

- `menu-replacement-red.log`: native engine reports an infinite loop even
  though the old test printed clean. A zero exit code is not sufficient.
- `menu-replacement-green.log`, `narrow-win-green.log`: actual killing
  button attack and visible, enabled, in-bounds Continue at rendered sizes.
- `full-lesson-final-green.log`: all five lessons, actual attacks/targets,
  real Angler victory and `won` result. No direct `_win` call.
- `world-lesson-final-green.log`: real World Load and swimming into the
  optional beacon, full tutorial victory, World handoff, saved independent
  milestones, party restoration and actual swimming afterward. Fixture uses
  an explicitly owned temporary save slot, removed after testing.
- `optional-training-green.log`: existing ignore/loss/Retry/Return/Skip gate.
- `qte-layout-green.log`, `status-layout-green.log`: affected layout gates.
- `headless-layout-harness-red.log`: dummy headless viewport cannot prove
  button bounds. Only this headless bounds check was excluded; rendered
  bounds checks and actual victory/result assertions remain.
- `headless-win-green.log`: actual win action/result without rendering.

The exported-browser check uses a disposable profile seeded from a previously
captured real completed-opening checkpoint, then normal Load and real W input
to the beacon. It does not use a query shortcut, synthetic `finished`, forced
damage, or `_win`. Screenshots are read using macOS Vision; mouse/keyboard
inputs act on the rendered game. This is completion-branch proof, not a new
cold-start proof of the entire opening.

Browser harness corrections are recorded separately from the game defect:
the Angler preview heading is not the target button; select the bottom-most
rendered label. The final onboarding page uses Close, not Next. Neither
correction changes gameplay or weakens victory/save checks.

Release candidate: `dpl_7BbTfkDs93dYzZb3R3cVJdM53n67`,
https://underwatergame-q8zo06qc7-immortaldemongods-projects.vercel.app/.
The existing review alias now points to that deployment:
https://underwatergame-opening-prologue-review.vercel.app/.
Unauthenticated served metadata identifies runtime commit `9778296`.
Served PCK SHA-256 is
`47a95ad07a9ba7ed63d3cbb63e415d94270aa2fc14209b2522099a2818fb261c`
(93,314,720 bytes), matching the clean export.
Public main still resolves to `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`.

Final browser round (`browser-result.json`, `browser-win-green.log`): all five
guided moves, actual Angler kill, visible Continue, actual click, all five
onboarding Next pages plus Close, unobstructed world and real W input,
persisted independent milestones, zero console errors. Visually inspected
`browser-victory-continue.png` and `browser-returned-world.png`.
Seeing controls behind a modal alone was explicitly rejected as sufficient
proof; the runner now requires the modal actions to disappear.
Overall opening goal remains unfinished; this packet covers the reported
tutorial completion failure, not the entire final visual/audio audit matrix.
