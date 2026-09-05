# PR 54 merge-readiness bug catalog

Scope: the player-visible transition between the world, defeat overlay, and
combat identity labels. Public surfaces are `World`'s HUD/overlay lifecycle,
`GameOverScreen`, `Cast` identity metadata, the world HUD, and Battle's
overhead/turn labels.

## Catalog

| ID | Bug hypothesis | User impact | Likelihood | Catching test | Status |
|---|---|---:|---:|---|---|
| UI-1 | Defeat opens `GameOverScreen` without hiding the live world HUD. | High: the first loss is visibly corrupt and controls appear usable while paused. | Observed | Start a world, expose the HUD, call the production defeat transition, assert the defeat overlay is visible while HUD/title are hidden. | Fixed; RED reproduced `HUD LEAK`, GREEN pending full gate. |
| UI-2 | Hiding HUD to fix UI-1 also hides defeat because the defeat screen is parented under HUD. | High: a superficially simple fix leaves a blank screen. | High | The same lifecycle test asserts both HUD hidden and defeat visible/full viewport. | Fixed by overlay-layer ownership; GREEN pending. |
| UI-3 | The defeat surface inherits a constrained HUD rect instead of owning the viewport. | High: title/buttons bunch in a corner at non-editor resolutions. | Observed | Compare defeat-screen size with the root viewport after the transition. | Fixed; RED reproduced `(0,0)` rect, GREEN pending. |
| NAME-1 | World and Battle duplicate placeholder display-name maps, so identities drift. | Medium: the same person can be labeled differently by exploration and combat. | Certain | Assert both surfaces resolve through `Cast` and show the same three labels. | Fixed; RED showed all six placeholder labels, GREEN pending. |
| NAME-2 | Glassgoat-confirmed `Maxilani` and `Musashi` never reach player UI. | Medium: authored character identity is absent from playtest feedback. | Observed | Cycle active divers in a real World HUD; instantiate Battle and inspect party labels. | Fixed through Cast identity metadata; GREEN pending. |
| NAME-3 | The third pilot has no approved proper name; inventing one presents conjecture as Glassgoat canon. | Medium: creates rework and misleading review evidence. | High | Assert a clearly provisional role label (`Mech Pilot`) and document that it remains naming feedback, not canon. | Fixed with explicit provisional role label; GREEN pending. |

## Interfaces and edge conditions

- Input/state: cold launch is paused with title open; play has HUD open; defeat
  pauses again and exposes only its overlay.
- Output: exactly one full-viewport menu surface is visible during defeat.
- Recovery: Restart and Return to Title rebuild the scene, so HUD restoration is
  validated by the existing title/new/load lifecycle gate after reload.
- Identity source: internal model IDs remain stable for saves, moves, rigs, and
  stats. Only display text changes.

## Skipped / intentionally not tested here

- Pixel-perfect typography and color: covered by committed visual evidence and
  browser inspection; brittle in a headless semantic test.
- An invented proper name for `Prototype_V(1922)`: deliberately excluded until
  Glassgoat approves one.
- Input-device focus after defeat: the two button signals already have direct
  coverage through their production connections; this change does not alter
  focus navigation.

## Post-write evaluation

RED evidence: the original lifecycle produced `HUD LEAK` and a `(0,0)` defeat
rect; the identity pass produced all six old placeholders (`Mermaid`, `Diver
Boy`, `Marine Man`) across World and Battle. GREEN evidence: the combined real
World/Battle gate reports `defeat and identities clean`. Full-suite and both
local/deployed browser evidence are clean; committed captures show the corrected
defeat and combat-name surfaces.
