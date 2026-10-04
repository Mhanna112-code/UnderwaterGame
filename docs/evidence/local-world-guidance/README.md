# Location-scoped puzzle and lab guidance

Runtime source: `cb13f072357a2aa1fdf26664df0b25087b33eefe`.

- Near the intact puzzle entrance: "Use Bucky's Shockwave to break the wall."
  Leave the room or destroy the entrance with real Bucky E: prompt clears.
  Returning before destruction restores it; consumed Save/Load does not.
- Lab guidance appears only while the active diver is physically in Deep.
  Shallows clears it without erasing the pending lab goal. Same-objective
  re-entry restores it. Sonar discovery/controls are unchanged.

Evidence: captured actual-crossing `zone-red.log`; final native rendered
  wide/narrow logs and screenshots; existing Deep guidance, legacy puzzle,
  open-water collision and exploration-defaults gates. All final green logs
  checked for engine/script/infinite-loop errors, not only exit status.
  Earlier verifier-only failures are retained in `rendered-harness-red.log`
  and `puzzle-first.log` and explained in the bug catalog.

Browser: `browser-green.log`, eight screenshots and `browser/result.json`.
  Uses a disposable profile seeded from the previously captured real opening
  recovery checkpoint. Positions and disabled random encounters explicitly
  isolate spatial branches. Ordinary title Load and actual keyboard movement,
  Tab and E drive behavior; rendered OCR observes prompt text, not callbacks.
  Zero browser/runtime errors. Screenshots inspected: Deep loaded/returned,
  Shallows, room contact and wall broken. Sonar remains On in Shallows.

Exact clean archive/export: 93,326,920 bytes, PCK SHA-256
`772fca491dae831f32d597198c0726dd42a5855ad5373168239a3406b8cb908c`.
Served immutable PCK matches exactly, unauthenticated.
Deployment `dpl_FP6DgA1SZzFBvW7hRVz4F5yr8nua`:
https://underwatergame-daq5wkuqg-immortaldemongods-projects.vercel.app/.
Same review alias refreshed:
https://underwatergame-opening-prologue-review.vercel.app/.
Public main and its secondary alias remain `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`.

This is focused guidance verification, not a full traversal from spawn or
campaign/overall polish acceptance. Existing large save-crystal geometry can
occlude the actor at this close puzzle approach; the new prompt itself stays
readable. Recorded for the broader visual audit, not silently declared fixed.
