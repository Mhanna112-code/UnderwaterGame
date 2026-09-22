# Guardian/item source map

This document resolves the one remaining player-facing conflict in raw PR
#72 rather than silently choosing whichever implementation happened to be
newer.

## Raw #72 behavior

Raw #72 removed `ItemGuardian` as a placed `Area3D`. Sonar could reveal a
key-item circle; a normal encounter roll inside that revealed circle then
had a 35% chance to open the special-encounter chooser for its site item.
The chosen diver faced the site-mapped enemy in a one-diver special battle;
loss/cancel restored that diver and left the item available, and a win
granted the item.

## Release behavior and decision

`release/today-build` retains the later, explicitly approved physical
contract:

| Player-facing outcome | Release implementation | Disposition |
| --- | --- | --- |
| Sonar discovers an unknown progression site. | `Diver.update_sonar()` persists `revealed_key_items`; the site, guardian, and visible enemy appear only once revealed. | Integrated equivalent |
| The player deliberately chooses to take the artifact encounter. | Touching the revealed physical `ItemGuardian` opens the same special chooser. | Integrated equivalent |
| The selected diver faces the right guardian and can safely lose/cancel. | The chooser starts a one-diver special battle with the site enemy; loss restores HP/O2 and leaves the guardian for a retry. | Integrated equivalent |
| A won encounter grants its key item only once. | `_grant_reward_item()` writes the party key item and removes its revealed-but-unclaimed state. | Integrated equivalent |
| A random fight does not obscure an artifact encounter. | `_on_encounter_triggered()` suppresses normal rolls inside every unclaimed guardian site; the physical guardian is the only entry point. | **Explicit superseding design decision** |
| A loaded save does not recreate a claimed site. | `_retire_claimed_item_guardians()` removes guardian/decoy and hides its site after save load and after live victory; the trigger also checks `key_items`. | Slice 6 repair |

The raw random-circle acquisition mechanic is intentionally not revived.
It conflicts with the later team decision to put a real Angler at the
shallows artifact and a real Swordfish at the trench artifact, and it
reintroduces the recorded playtest ambiguity: near an artifact the player
cannot tell whether a battle was caused by the treasure or the normal random
encounter system. The replacement preserves raw #72's discovery, chooser,
one-diver, loss-safe, and reward behavior while making the encounter
location legible in the world.

## Verification contract

`verify/guardian_item_integration.gd` drives both sites through normal
signals: random-roll suppression, sonar-revealed guardian entry, chooser,
one-diver mapped battle, loss/retry, win, save, and load. Its first red run
reproduced a stale `current_pearl` guardian after reload; the final green
run proves that a claimed guardian cannot display or reopen an encounter.

The reviewer routes remain:

- `?guardian=shallows` for the Angler guardian;
- `?guardian=trench` for the Swordfish guardian;
- `?special=1` for the chooser/minigame dispatch without modifying a save.
