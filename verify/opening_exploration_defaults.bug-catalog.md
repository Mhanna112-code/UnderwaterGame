# Opening exploration defaults (2026-10-04)

Scope: World recovery, checkpoint serialization/load, Diver Sonar activation,
and minimap/HUD state. At the completed opening handoff, enable Sonar on its
actual owner (Maxilani) and random encounters. Do not require optional training.

## Interfaces and boundaries

- New Game, recovery Continue, title Load and Game Over restart are the player
  entry points. Q/R remain manual controls after recovery.
- Recovery saves before enabling Continue; settings must be applied before
  that durable checkpoint, not just after dismissing its overlay.
- Sonar uses the existing oxygen-aware toggle and three-second drain clock;
  direct boolean assignment would bypass that initialization. Minimap reads
  the Sonar owner's flag even when another diver is active.
- Save IO is real JSON through SaveManager. Validate new boolean fields before
  mutating actors; preserve explicit false values. RouteState migrates saves
  with no opening milestones to completed legacy runs.
- Branches: new unfinished run; first recovery; save denial/retry; current
  saved On/Off preferences; completed legacy save missing fields; empty oxygen.
- Existing journey proves actual combat → aftermath → recovery → Continue →
  ordinary combat → death/restart/title Load. Existing invalid-load and optional
  training gates cover rejection and training side effects.

## Bugs and test plan

| ID | Failure | Risk / plausibility | Test |
| --- | --- | --- | --- |
| OPEN-040 | Recovery leaves Sonar off or previously disabled random encounters off. | High: ordinary discovery/encounters fail to begin; recovery never initializes Sonar. | Real opening journey with pre-opening random Off, inspect HUD/minimap and durable checkpoint before/after Continue. |
| OPEN-041 | Load loses enabled settings, or forcibly undoes the player's later Off choice. | Medium: fields are currently absent from checkpoint serialization. | Round-trip both booleans, missing-field migration, and existing death/restart journey. |
| OPEN-042 | Invalid boolean fields partly restore gameplay or a zero-O2 save shows inert Sonar as On. | Medium: IO coercion and resource activation can disagree with UI. | Malformed-field rejection; oxygen-exhausted load; existing load-failure gate. |

Self-critique: assert observable On/Off HUD, active minimap, actual persisted
values and restored controls, not helper call counts. Incorrect stable output
fails. Fixtures set checkpoint inputs only; first-handoff test runs actual
production combat and Continue. Round-trip matrix spans both toggles, active
diver and missing fields; it does not mirror the loader implementation.

## Skipped

- Sonar cost/range and random encounter rates: preserve current balance.
- Making Sonar required or redesigning discovery/tutorial: not requested.
- Saving on every Q/R keypress: existing checkpoint semantics remain; choices
  persist when a checkpoint is actually saved, not immediately on toggle.
- Changing audio/assets, main deployment or merging PRs: outside this change.

## Evaluation

- Caught OPEN-040/041: the existing recovery kept Sonar Off, retained disabled
  encounters and omitted both settings from its checkpoint (`recovery-red.log`).
- Green actual combat/recovery/Continue/death/restart/title Load journey;
  rendered 1280×720 HUD explicitly shows Sonar (On) and Encounters (On).
- Green eight round-trips of both manual booleans and active diver; completed
  legacy migration, unfinished opener, eight malformed-field rejections and
  oxygen-exhausted load. Invalid-load and optional-training gates also green.
- During writing, found that restoring a saved true flag onto an already-On
  live Sonar owner with zero saved O2 could bypass activation refusal. The
  loader now computes resource-valid state before deciding whether to toggle.
- Test harness required an explicit String annotation for temporary file
  cleanup; parse errors were corrected, never accepted as green exit codes.
- Evidence: `docs/evidence/opening-exploration-defaults/`.
- Hosted full ordinary opening and cold Load passed; both settings persisted
  in actual IndexedDB, HUD screenshots inspected, zero errors. Existing review
  alias updated to exact tested runtime `42d8bf2`; main unchanged.
- No campaign balance change. Existing optional-label occlusion OPEN-032 is
  still visible in browser screenshots and belongs to the larger final audit.
