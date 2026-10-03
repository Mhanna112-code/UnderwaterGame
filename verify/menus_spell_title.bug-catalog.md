# Menus, tutorial replay, spells, and title bug catalog

Current contract: PR #96 integrates the retained tutorial/help work while the
deep-zone slice is built from current `main`. This catalog describes player
behavior that exists now; it does not preserve retired PR #72 debug APIs.

## Public interfaces

- `InventoryMenu` is the Esc surface for Items, Party Spells, Combat Help, and
  Audio. It intentionally remains inside the HUD CanvasLayer and leaves the
  compact world-control header visible above its content.
- `World._replay_tutorial_battle()` launches the real first combat lesson from
  Combat Help. Practice starts and ends with a restored party, grants no XP or
  rewards, and must not corrupt growth, spell, inventory, or key-item state.
- `World._on_title_spell_playtest()` is a save-free review route. It enters
  free roam with all current key-item prerequisites and every legal spell
  learned/equipped through `SpellTree`, then directs the reviewer to Esc >
  Party Spells.
- `TitleScreen` composes the current opt-in Boss, Special Encounter, Spell,
  and Skip Tutorial shortcuts. Removed Guardian and onboarding flags are not
  product contracts.

## Bug map

| ID | Failure mode | Player impact | Cheapest reliable test | Status |
| --- | --- | --- | --- | --- |
| MENU-REPLAY-1 | Practice grants XP/items, changes spell progression, or returns a damaged party. | A help action becomes a progression exploit or leaves the player worse off. | World/Battle lifecycle state differential | **Green** |
| MENU-HELP-2 | Help cannot scroll or omits replay/guide actions and glossary sections. | Required combat concepts become unreachable. | Public UI structure and labels | **Green** |
| MENU-SPELL-3 | Spell Test is empty, bypasses real learning rules, writes a save, or Party Spells cannot show learned support spells. | Review evidence is misleading and the real menu is untestable. | Title action -> free roam -> Esc Party Spells journey | **Green** |
| MENU-TITLE-4 | Enabling one review route removes another or leaks debug actions into the ordinary title. | Review paths regress or ship to ordinary players. | Feature-route composition table | **Green** |
| MENU-ITEM-7 | Potion is hidden/disabled, applies the wrong amount, consumes twice, or closes Inventory. | A visible recovery reward is unusable or wasted. | Click public item button and inspect party/count | **Green** |
| MENU-OVERLAY-8 | Runtime Inventory root remains zero-sized or its forced scroll minimum overflows short screens. | Backdrop/hit-testing is inconsistent and lower help content is clipped. | Runtime viewport geometry plus narrow browser review | **Green in focused gate; browser evidence pending** |

## Decisions retained by the audit

- The item button is labeled `Potion`; its count is a separate badge. Tests do
  not look for the retired `Use Potion` label.
- Spell Test does not open the save-point spell tree. Current progression
  auto-learns affordable spells after victories, so the review route supplies
  a fully learned roster and exposes it through the real Party Spells menu.
- Guard Break's current approved accuracy modifier is `+4`, not the obsolete
  `0` asserted by the old extraction gate.
- Tutorial replay deliberately restores HP/Oxygen before and after practice.
  It preserves growth/rewards rather than restoring the player's pre-practice
  damage.
- Inventory stays in the HUD layer so the compact control header remains
  visible. Full-screen opaque save-tree assumptions from the retired gate do
  not apply.

## Red/green record

The inherited gate initially reported 15 failures because it still called a
removed Guardian Test API, expected Spell Test to open SavePointMenu, required
an obsolete Guard Break value, looked for `Use Potion`, and treated the current
HUD-layer menu as invalid. Rebaselining against public player flows exposed one
real defect: `InventoryMenu` still used anchor-only sizing and forced a 460px
scroll minimum. The root/backdrop now reset anchors and offsets together, and
the scroll surface uses a responsive 240px floor. The focused gate is green.

## Test self-critique

- The gate intentionally asserts public labels/state transitions, not private
  container order or implementation snapshots.
- It calls World's completion boundary rather than faking XP inside Battle;
  the dedicated combat/tutorial gates cover Battle's no-XP branch.
- Headless geometry cannot establish that the menu looks good. PR browser
  review at 1280x720 and narrow width remains mandatory.
