# Bug Catalog: Glassgoat PR #88 Review

**Scope:** the player-visible defects reported from the published core-route
review build.  This catalog deliberately excludes Marc's maze geometry and the
larger encounter/puzzle pacing decision; neither belongs in this no-maze slice.

| # | Reported defect | Test / evidence | Status |
| --- | --- | --- | --- |
| 1 | Swap says arrows/Enter and does not support the expected `A`/`D` and Space controls. | Captured live World input contract. | Fixed |
| 2 | Tutorial continuation is too easy to mistake for an Enter-only stall. | Existing live Continue-button test plus Space alias contract. | Fixed |
| 3 | The active-diver marker is a tall green forward-looking cone, indistinguishable from route guidance. | Marker mesh/placement contract plus review screenshot. | Open |
| 4 | Frilled Shark can stop animating after its idle/attack transition. | Real actor idle loop and post-action recovery observation. | Open |
| 5 | Enemy EVA is hidden until hover, so target risk cannot be compared before selection. | Combat menu card state contract. | Open |
| 6 | Unlabelled yellow raw-power values obscure what a move actually does. | Move-card text contract and browser screenshot. | Open |
| 7 | Normal Angler/Frilled actors silently scale from party stats instead of using their agreed tables. | Actor stat-table differential. | Open |
| 8 | `Electric Touch 0` / `Evasion 0` needs exact-state reproduction before formula changes. | Characterization against the reported build/state. | Open |
| 9 | Isolated balance trials hide persistent-route difficulty. | Route-state simulation and normal-entry manual playtest. | Open |

## First red/green slice: Swap controls

`verify/glassgoat_review.gd` sends the same live input events that a player
uses after starting Swap: `D` advances, `A` returns, and Space confirms. It
also checks the visible HUD wording. This catches both a control regression and
a documentation regression without inspecting a private implementation detail.
