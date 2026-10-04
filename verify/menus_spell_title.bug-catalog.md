# Slice 3 — menus, spells, and title bug catalog

Baseline: `90c1853` (`release/today-build`) after tutorial/onboarding and
Quick Read slices merged. This catalog extracts the real UI behavior from raw
PR #72 without carrying its stale route removals, generated files, or combat
formula edits.

## Interfaces and risk map

- `InventoryMenu.open()/close()/refresh()` is the public Escape-menu surface.
  Its Items and Party Spells actions call `World`; Combat Help is reference
  content and must not block interaction.
- `World._replay_tutorial_battle()` is the proposed public campaign action
  behind Combat Help. It must run the actual tutorial encounter without
  changing the campaign party.
- `SpellTree.can_learn()/learn()` is the legality boundary. `World` may
  provide a review route with temporary test resources, but it must not alter
  spell definitions, oxygen costs, or normal save state.
- `TitleScreen` owns paused cold-launch/New/Load UI and query-only reviewer
  actions. Existing boss, guardian, special, and onboarding routes are
  established review contracts and must remain present when the spell route is
  added.

## Bugs

| ID | Failure mode | Player impact | Why plausible | Test type | Status |
| --- | --- | --- | --- | --- | --- |
| MENU-REPLAY-1 | Replaying the tutorial heals, levels, strips statuses, or otherwise mutates the real campaign party. | Critical — a help button becomes an unlimited progress/healing exploit and makes save balance meaningless. | The raw #72 implementation explicitly refills the party and its tutorial battle awards XP/recovery. | Lifecycle contract pin | **Green** — snapshot/restore covers mutable combat, growth, spell and health/oxygen state; an initial omission of current HP was caught and fixed before this record. |
| MENU-HELP-2 | Combat Help content extends below the 720px HUD with no scrollable reading surface. | High — the help promised by the tutorial cannot be read. | Raw #72 added a `ScrollContainer`; baseline adds the list directly to a full-height VBox. | UI structure plus 1280×720 manual review | **Green in focused gate** — Help now has a bounded vertical `ContentScroll`, a safe replay action, and distinct Stats/Effects/Status Conditions sections. Manual browser review remains required before merge. |
| MENU-SPELL-3 | A visible spell is learnable despite missing points/prerequisites/key items, the review route changes normal spell data/costs, or the browser route stops before the player reaches the real Learn Spells tree. | High — spell progression or combat balance silently changes, or a reviewer cannot inspect the promised presentation. | The raw branch mixes a spell-test route with an unrelated `acc_mod` change; the public route intentionally has Save, Update, then Learn actions. | Decision-table/invariant plus browser journey | **Green** — the actual title action grants temporary review prerequisites, traverses Save → Update → Learn into the existing spell tree, learns every tree legally, and pins Guard Break's current formula for Slice 5. |
| MENU-TITLE-4 | Adding spell review removes existing guardian/onboarding/boss/special review routes or makes the normal first-run title show developer actions. | High — prior review links regress, or first-time UX regresses. | Raw #72 replaced several title signals instead of composing them. | Title-route decision table | **Green** — no-flag title excludes Spell Test; feature-flag composition renders all five review routes. The focused test exposed and fixed a real live-title guardian-refresh fault. |
| MENU-SAVE-5 | Opening/closing help or replaying practice writes/mutates the active save slot. | High — a UI review path corrupts a player’s progression. | World owns persistence and the new UI calls World directly. | Save-state differential | **Green in focused gate** — replay state is restored after a simulated victory; spell review sets `_current_slot = -1` before opening the actual Save/Update Spells UI, so its Save action cannot write a campaign slot. |
| MENU-BROWSER-6 | A browser verification route fails solely because another local process occupies a hard-coded server port. | High for release confidence — the full browser gate can report a false failure without exercising the exported game. | The pre-existing boss check bound its private static server to port 8766, which was occupied by a developer preview during the first full-suite run. | Captured browser-harness regression | **Green** — the boss check now requests an OS-assigned unused port; the full suite passed while the developer server remained on 8766. |
| MENU-ITEM-7 | A usable inventory item is hidden/disabled, applies the wrong amount, consumes twice, or closes the player into a dead UI state. | High — a visible reward becomes unusable or silently wastes progression. | Slice 3 makes the pause-menu reading surface scrollable and reruns its contents after actions; the raw #72 intent includes usable inventory, while World remains the mutation owner. | Public-UI contract pin | **Green in focused gate** — a real Potion button is selected, adds exactly 10 HP, consumes exactly one copy, refreshes, and leaves Inventory usable. |
| MENU-OVERLAY-8 | Persistent world HUD labels render through full-screen Inventory or Save/Update/Learn screens. | Medium/high — readable menu titles and controls visibly overlap, making a functioning progression UI appear broken. | Those menus initially lived in the same low `HUD` CanvasLayer as the control labels; the initial browser capture showed the overlap. The first fixes exposed a second root cause: `set_anchors_preset()` preserved zero offsets for runtime Controls under a CanvasLayer, so their full-screen backdrops never filled the viewport. | Captured visual regression plus modal geometry/lifecycle contract | **Green** — the exported browser traverses Title → Save → Update → Learn. The recorded title and tree captures show full, opaque modal surfaces with no world HUD or world geometry visible beneath them; close still restores the HUD in the focused lifecycle test. |

## Skipped for this slice

- Pixel-level styling of title art, slot borders, and tooltip colors: existing
  title and Quick Read tests cover their functional layout; visual evidence
  will cover this slice’s changed screens.
- Raw #72 `Guard Break` accuracy change: this changes combat data and belongs
  to Slice 5’s approved move-table reconciliation, not presentation.
- Raw `Slot` nodes as empty HUD boxes: their only raw use was an invisible
  anchor for a popup whose player-facing onboarding is already ported and
  tested in Slice 1. Adding empty boxes would be a regression, not retained
  behavior.

## Test self-critique

- MENU-REPLAY-1 observes the actual World/Battle lifecycle and compares
  campaign state, so it fails for a real free-heal/XP regression and survives
  an internal replay refactor.
- MENU-HELP-2 will assert a scrollable public surface rather than a particular
  container hierarchy beyond the behavior that permits reading long content.
- MENU-SPELL-3 tests public learning legality across every tree and pins data
  rather than merely snapshotting labels.
- MENU-TITLE-4 exercises visible title actions by feature flag; it will fail
  if a route disappears or leaks into the ordinary first-run title.
- MENU-ITEM-7 exercises the visible Inventory button and observable party
  state/count, so it catches a real spend/effect/refresh regression without
  coupling to `World.use_inventory_item()` internals.
- MENU-OVERLAY-8 checks the public canvas ordering contract and actual
  viewport-sized modal rects, then requires exported screenshot review because
  structure still is not enough to establish readable composition.

## Red/green record

- Initial highest-risk test: MENU-REPLAY-1. Expected red on baseline because
  `World._replay_tutorial_battle()` does not exist yet. The extraction must
  implement a non-mutating practice lifecycle before further menu work.
- The first replay implementation missed `stats.hp` in its restore snapshot.
  The lifecycle test changed HP as part of a simulated tutorial win and failed;
  the snapshot now captures and restores it alongside oxygen, growth, XP,
  status, modifiers, known/equipped spells, and spell points.
- MENU-TITLE-4 was deliberately taken red after the spell route was added:
  enabling Guardian Test while a title was already visible did not rebuild the
  button list. Later flags could accidentally hide that problem by rebuilding
  for another reason. `enable_guardian_playtest()` now refreshes just like the
  other opt-in routes, and the direct live-title assertion is green.
- MENU-HELP-2's first test searched only direct children and falsely reported
  a missing scroll view; it was corrected to find the public named view
  recursively. This is recorded so the green result means the actual rendered
  hierarchy, not an implementation accident.
- MENU-BROWSER-6 was caught during the first full exported-browser run: the
  generic web check passed, but the boss route threw `EADDRINUSE` before it
  could begin. The change to an ephemeral port will be accepted only after the
  full suite reruns with the occupied developer port still present. That rerun
  is green: the Tethys fight rendered 662 red samples with the same process
  still listening on 8766.
- The first browser spelling route stopped at the Save menu. That was not a
  game failure, but it was insufficient evidence for spell-tree presentation:
  the public path deliberately has Save → Update → Learn levels. The browser
  contract now follows all three, captures the actual tree, and is green.
- The initial `TitleLayer` reparenting made `SavePointMenu.learn_ui` null at
  World setup because that child is built only in `SavePointMenu._ready()`.
  The focused gate failed before any UI was usable. `World` now assigns the
  shared key-item list immediately after adding the menu to its live modal
  layer; the focused gate is green again. The final browser rerun must still
  prove the visual composition.
- Reparenting alone was not sufficient visual isolation: the browser capture
  still showed the world controls and health bars. The modal open/close path
  now hides/restores `World.HUD`; the focused gate asserts that spell review
  hides it and close restores it. Exported browser evidence remains required.
- The next capture still showed world geometry because the runtime roots used
  `set_anchors_preset()`, which preserves their zero CanvasLayer offsets.
  All full-screen Save/Inventory/Spell controls now use
  `set_anchors_and_offsets_preset()`, and the focused gate checks their real
  rects against the viewport before the browser rerun.
- That exported rerun exposed one more public-input failure: the opaque
  `ColorRect` backdrops had Godot's default `STOP` mouse filter, which ate
  clicks intended for Save/Update/Learn. The browser route could open Save
  but not proceed. Backdrops and structural containers now ignore pointer
  input, while real buttons retain it; the exported route reaches the actual
  tree and the committed title/tree captures prove the repaired composition.
