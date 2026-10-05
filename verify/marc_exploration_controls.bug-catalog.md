# F abilities / E interactions integration

## Public interface and reading

The observable contract is Godot key/mouse dispatch into World and MazeLevel,
their public TargetSelector, Diver ability effects, and displayed instructions.
Read both exploration input dispatches, their complete ability/selection paths,
modal guards, map interaction dispatch and HUD construction. Read TargetSelector,
Slot, TutorialContent and AbilityOnboarding end to end; retain the existing
checkpoint/input tests rather than replacing their physical interactions.

Load-bearing rules: one modal owner; Escape cancels rather than also opening
inventory; map E/Ctrl+E belong to wall/current/door controls; environmental
abilities remain usable at zero Oxygen. Ability IDs are the Diver BASE_STATS
`swap`, `grapple`, `shockwave` contract, not arbitrary display names.
IO: real Input dispatch, physics overlaps, GUI pause, cooldown/tween time.
Branches: World opening/battle/transition; Maze battle/modal/map/selector;
pressed/released/echo keys; active diver ability; selection/confirmation/cancel;
E context interaction versus F environmental ability; optional help rendering.

## Bug catalog

| ID | Player failure | Plausibility / blast radius | Test | Status |
|---|---|---|---|---|
| CTL-1 | F does nothing while E still fires an exploration ability | Both live dispatches retain KEY_E, contradicting latest approved controls | Real input and observed selector/ability | Captured World and Maze reds; repaired |
| CTL-2 | Maze E interaction unexpectedly spends an ability cooldown | `_handle_e` falls back to ability use | Empty-context E then successful F | Captured real empty-context Swap red; repaired |
| CTL-3 | F leaks through map, pause or selection ownership | A new branch can bypass earlier owner guards | Owner/key decision table | Caught World Inventory leakage; repaired. Maze map/save/chest/selection remain exclusive |
| CTL-4 | Help/HUD says E after gameplay has moved to F | Multiple independent prose/keycap tables | Public page/keycap content for all three cast abilities | Nine help-surface reds captured; body/badges/reference/HUD reconciled |
| CTL-5 | A blanket replacement breaks map/minigame E | E still has valid meanings outside exploration abilities | Existing live map/input gates and explicit minigame help contract | Real map E/Ctrl+E and chest E pass; minigame instructions retain E |

## Self-critique and generators

Tests dispatch input through Input.parse_input_event, not a renamed private
handler. Expected effects come from the approved human control mapping, not
the production key constant. Selector state, actual movement/Swap, cooldown,
resource conservation and public help content reject wrong-but-stable output. A
refactor retaining input/effect behavior should pass. The owner × key matrix
generates more than five combinations; each asserts its actual exclusive owner.
Fixtures skip opening, disable encounters and place the party in disclosed clear
space. They are not claims of normal campaign progression.

## Skipped

- Minigame E intentionally stays E; no redesign of those controls.
- First-person maze grapple/camera ownership and embedded-region routing still
  require their own admission. This control port must not declare them complete.
- Save writes: input tests never emit New Game or write player slots.
- Pixel aesthetics of key badges: final native/browser visual inspection remains
  required; no screenshot-count or exact-paragraph snapshot oracle.
- Battle ownership is covered by the existing Battle/input regressions, not by
  a fake `battling=true` fixture presented as an actual-fight acceptance result.
- Delivered tutorial video recordings are historical media; final playback
  inspection must identify stale on-video controls rather than infer correctness
  from updated prose alone.

## Evaluation

Captured reds: actual F did not select World Swap; empty maze E selected Swap
while F did nothing; all three Slot keycaps, reference blurbs and optional lesson
body/badge pairs taught the old key. The expanded test then caught genuine World
Inventory input leakage: F started selection beneath the menu and Escape canceled
that selection instead of closing the menu. World now gives an already-visible
Inventory/Save menu exclusive input before aiming/selection/exploration handling.

Rejected runs: an untyped `:=` on a duck-typed Node selector produced a parse
error (Godot exited 0); it is not a product red or passing receipt. The menu test
initially required SceneTree.paused, but both scenes intentionally freeze movement
through owner guards. That assertion was removed; a rerun still reproduced the
real World F/E/Tab leak before the production guard was added.

Final focused receipt: `/tmp/pr100-oct5-controls-clean.log`, 86 checks, real key
press/release/echo across World/Maze × all three divers. Zero-Oxygen Swap trades
actual positions, Grapple hits and traverses a real anchor, Shockwave dispatches
once and respects cooldown; clock-based readiness returns. Inventory input stays
exclusive, and Escape cancels aim/selection without opening another menu.

Independent integration receipts rerun on the reconciled earned-map source:
six real chest/capsule/pause cases including F, actual chest acquisition/return,
72 map-region samples, isolated-slot Save/cold Load/legacy Load, all-three-diver
map/save/selection with real E/Ctrl+E/R geometry, and 59 light-orb checks.
Pause layout, World aiming, local guidance through actual F Shockwave, and live
stun/Angler consumers also pass. No captured Godot script errors in accepted logs.
This is neither a full-suite nor normal-campaign/browser acceptance claim.
