# Bug catalog: Marc pause-menu integration

Generated October 4, 2026 using design-tests. Scope: InventoryMenu (513 lines
before port), World menu ownership and actual four-tab consumer surface.

## Responsibility and public interface

InventoryMenu presents consumables, learned party heal/revive spells, existing
Combat Help/replay actions and central Music/SFX preferences. Escape opens and
closes the overlay. Buttons route to the owning World/Maze, not a copied party.
`open`, `close`, `refresh` are public; tab/button/slider input is player-facing.

## Load-bearing comments, types, boundaries and branches

Full anchors **and offsets** are required for a CanvasLayer child's hit/backdrop
rectangle. ScrollContainer, not an unconstrained VBox, bounds tall Help content.
Dead/live target filtering must remain distinct for revive/heal. Tutorial replay
actions are only available on owners supporting them; Audio is always retained.
Modes are items/spells_root/spells_target/help/audio. Missing World, empty items,
zero quantities, unavailable audio, unaffordable spells, living/dead targets and
missing replay capabilities all change rendered controls. Audio's settings and
World's item/spell operations are external state boundaries; this presentation
test opens settings but does not modify them or write saves. Container layout
settles across frames and is affected by the actual viewport, not a source-string
assertion. Existing menus_spell_title covers real consumable/replay/spell access;
audio_manager covers isolated preference round trips.

## Catalog

| ID | Failure | Blast radius / plausibility | Test / status |
| --- | --- | --- | --- |
| M99-P1 | Four tabs, item/spell buttons or Audio rows extend beyond the screen, making reviewed actions inaccessible. | High: fixed 340px rows, 50px inset and unwrapped tabs already exceed a 360px view; Marc adds larger styles/header. | Real menu input/layout invariant across generated viewport sizes; pending. |
| M99-P2 | Copying Marc's three-tab menu removes Music/SFX or existing replay/help actions. | High: upstream has no Audio tab and differs from our reviewed owner. | Select all four real tabs and assert their consumer controls; pending. |
| M99-P3 | Pause backdrop has zero size or input passes into the world. | Medium: previous CanvasLayer anchor-only regression. | Actual Escape + full overlay rect and blocked movement; pending. |
| M99-P4 | Exploration HP/O2 bars paint above the modal and cover Audio/Help. | High: World builds those siblings after the menu; native capture exposed this despite passing bounds. | Actual Escape + HUD paint ordering, inspected native captures; caught during visual review. |
| M99-P5 | Latest removal of the redundant guide button also removes F1 or the two actual practice actions. | Medium: 659ff69/7a27230 intentionally remove only Reopen Tutorial Guide. | Real Help buttons plus keyboard F1 opening the existing book, no forced tutorial; pending latest refresh. |

## Test design and self-critique

marc_pause_presentation exercises the real World and its public Escape event,
then real tab buttons. It checks visible viewport bounds, nonzero scroll area,
Audio sliders and tutorial Help actions, rather than exact colors, source code,
private helper calls or a screenshot snapshot. Bounded generated widths/heights
cover more than five shapes; narrow/short and portrait/wide native captures are
also inspected. Wrong-but-stable overflowing output fails. Refactoring internal
layout without changing accessible actions/bounds should pass. Node names used
for stable existing Audio controls are consumer automation identifiers.

## Skipped

- Exact gradient/color/font values: cosmetic; inspect actual captures instead.
- Re-test spell/item numerical effects here: already exercised through real
  handlers by menus_spell_title/support_spell_delivery, not presentation scope.
- Change actual audio preferences: isolated audio_manager owns that test; avoid
  mutating the player's settings while reviewing layout.
- Popup, caption and persistence semantics: separate intake increments/catalogs.

## Post-write evaluation

Initial baseline failed M99-P1 at 360x640 and generated 397x647: fixed-width
content made Audio rows and the reading surface overflow. Corrected test parse
error before collecting that baseline; a harness error is not a product failure.
Adaptive dimensions/flow tabs passed 12 headless shapes and 16 native tab views.
Visual inspection then caught M99-P4: HP/O2 bars covered otherwise-fitting
controls. Reopened verification and added the paint-order consumer invariant.
Final post-repair native run passed all 12 shapes and recaptured 16 tab views.
Inspected 360x640 Audio and 720x480 Help after paint repair: no foreground HUD
obstruction, tabs wrap, controls fit and Help scrolls. Also inspected wide Party
Spells and portrait Items. Existing menus_spell_title passed real item use,
practice handoff, learned spells and title-route composition. M99-P2/3 were
characterized; M99-P1 and M99-P4 required fixes. No browser/deployment acceptance
is claimed for this local batch.

Later 659ff69/7a27230 intentionally remove Reopen Tutorial Guide. The updated
contract failed against the retained button, then passed after the shared
removal. Actual F1 still opens the existing book; its real Close button exits.
Both practice buttons and Audio remain across all 12 viewport shapes. An initial
test called a nonexistent `close()` on TutorialBook; that harness failure was
rejected and replaced with the real Close-button event before the red baseline.
The updated menus_spell_title item/practice/spell/title regression also passes.
