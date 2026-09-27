# Bug Catalog: Glassgoat PR #88 Review

**Scope:** the player-visible defects reported from the published core-route
review build.  This catalog deliberately excludes Marc's maze geometry and the
larger encounter/puzzle pacing decision; neither belongs in this no-maze slice.

| # | Reported defect | Test / evidence | Status |
| --- | --- | --- | --- |
| 1 | Swap says arrows/Enter and does not support the expected `A`/`D` and Space controls. | Captured live World input contract. | Fixed |
| 2 | Tutorial continuation is too easy to mistake for an Enter-only stall. | Existing live Continue-button test plus Space alias contract. | Fixed |
| 3 | The active-diver marker is a tall green forward-looking cone, indistinguishable from route guidance. | Marker mesh/placement contract plus review screenshot. | Fixed |
| 4 | Frilled Shark can stop animating after its idle/attack transition. | Real actor idle loop and post-action recovery observation. | Fixed |
| 5 | Enemy EVA is hidden until hover, so target risk cannot be compared before selection. | Combat menu card state contract. | Fixed |
| 6 | Unlabelled yellow raw-power values obscure what a move actually does. | Move-card text contract and browser screenshot. | Fixed |
| 7 | Normal Angler/Frilled actors silently scale from party stats instead of using their agreed tables. | Actor stat-table differential. | Fixed |
| 8 | `Electric Touch 0` / `Evasion 0` needs exact-state reproduction before formula changes. | Current V2 runtime is non-reproducible; a base-stat result contract guards `1 Damage; EVA -3`. | Characterized |
| 9 | Isolated balance trials hide persistent-route difficulty. | Seeded campaign simulation now carries tutorial XP, post-win recovery, O2 availability, capstone restores, and the exact ordered roster. The current 60-seed run: quick-read 91.7%, skilled 91.7%, damage-only 0.0%; capstone named variants are required. Normal-entry browser playthrough remains required as final visual evidence. | Fixed in code; manual evidence pending |

## First red/green slice: Swap controls

`verify/glassgoat_review.gd` sends the same live input events that a player
uses after starting Swap: `D` advances, `A` returns, and Space confirms. It
also checks the visible HUD wording. This catches both a control regression and
a documentation regression without inspecting a private implementation detail.
