# Exploration HUD approval — 2026-10-05

Scope: the read-only exploration HUD component and World presentation adapter.
No combat mechanics, saves, input bindings, balance, or opening redesign.

## Interface and boundaries

The component reads named CombatantStats resources through `refresh` and viewport
geometry through `layout_for`; it never writes resources, handles input, or saves.
World owns actual TAB/Q/R/F/E/Escape input, contextual aim/swap hints, minimap,
route objectives, battle transitions and modal ownership. Existing HP references
remain usable by damage feedback and the embedded maze's caption placement.
Load-bearing rule: information-only descendants ignore mouse input individually.
The maze keeps its own exploration controls; its shared resources use this HUD.
Branches: selected/inactive diver, health/down/low, oxygen/empty/low, encounter
preference, tutorial switching lock, narrow viewport, maze owner, modal/battle.
IO: frame/resize events and rendering only; no disk/network/randomness in HUD.

## Catalog and test design

| Bug | Impact and plausibility | Cheapest test | Status |
|---|---|---|---|
| HUD-1: six oversized meters survive approval | Captured screenshot clutter; old construction intentionally creates 6 | Native rendered-tree invariant: exactly two visible meters, correctly identified resources | Pending |
| HUD-2: TAB or resource change shows another diver's values | Shared party changes selection and resources independently | Generated values for all three selected divers; visible text and meters vs independent resource fixture | Pending |
| HUD-3: HUD paints through pause/save/battle or steals mouse input | Old owners separately hide resources and controls | Actual Escape/save/battle transition plus all information-node mouse filters | Pending |
| HUD-4: smaller windows overlap panels/map or clip text | Fixed initial placements and runtime container minimums | Generated viewport geometry and public label bounds; native/browser screenshots | Pending |
| HUD-5: redesign removes existing abilities/controls or encounter state | Mockup initially omitted arrow keys; late-game has F/Q/R/Esc | Real input switching/Q/R and context hint inspection; rendered browser OCR | Pending |
| HUD-6: maze captions reserve a meter row and paint over the full resource card; opening the map hides resources | Shared bar aliases now point inside a taller card; old branch treats map as a modal | Rendered maze notice/card intersection at four viewports, including 360x480; actual L map input preserves resources and main's hidden objective | Captured regression, awaiting rerun |

Each invariant checks visible output rather than helper calls or exact node layout.
HUD-6 observes the production announcement and complete visible cards after
entering the embedded maze. It fails for stable overlapping geometry and permits
changes to container nesting. The four sizes cover desktop, landscape, portrait,
and the short portrait case; HUD-4 additionally generates viewport sizes.
Text checks identify actor, resource and controls; cosmetic spacing is not pinned.
Resource fixtures are declared UI-only setups, not claims of earned gameplay.

## Skipped

- Combat redesign and combat balance: explicitly excluded by approval.
- Full campaign and checkpoint durability: no related state/code change here;
  existing opener/menu/embedded-maze checks cover impacted ownership boundaries.
- Low-resource warning ergonomics: explicit text is checked; effectiveness with
  inexperienced players still needs human playtesting.
- Phone gameplay/touch controls: layout checks do not claim touch support.

## Evaluation

Native captured regression failed first: six meters instead of two. Replaced
with two active meters and two numeric teammate rows. Generated sizes also caught
controls/card overlap at 1197/1256px; the stack breakpoint now respects actual
card widths. Resource checks caught ProgressBar's integer rounding of fractional
Oxygen; continuous meters now use a zero step. Narrow rendered inspection caught
the orange message painting over controls; its actual wrapped height is reserved.

October 14 integration against main `2e183cc`: fresh Godot 4.7.1 import clean.
Rendered HUD acceptance: generated viewport/resource cases and real input,
4,646 checks, clean. HUD-6 first failed at 360x480 because the announcement
overlapped PartyStatus; full-card reservation and wrapped caption placement fixed
it. Inspected wide/narrow World and 360x480 maze images. Actual L map leaves
resource cards visible; main's intentionally removed maze objective stays hidden.
Focused maze input, current prologue, pause presentation and actual Run-return
checks clean. No gameplay/balance/full-campaign or target-OS claim.
Browser verification is recorded separately with the exported PCK hash.
