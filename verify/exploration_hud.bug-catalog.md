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

Each invariant checks visible output rather than helper calls or exact node layout.
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

Native HUD acceptance: 20 viewports x three selections, 4,448 checks, clean.
Native rendered 1280x720/960x540/720x480/360x640: clean; inspected 1280 and 360.
Existing pause-menu suite: clean. Campaign goals: 40 generated cases, zero
findings; shared maze resources and modal/map ownership retained. Browser and
canonical artifact acceptance remain pending at this runtime commit.
