# World manual checkpoint safety

October 5, design-tests. Read SavePointMenu, SaveManager and BrowserCheckpoint
end-to-end, World manual/automatic/new-run/recovery serialization and restore
consumers, Maze stable-capture/manual-save ownership and existing IO verifiers.

## Public interface and boundaries

The Save Point menu emits `save_requested(diver, slot)` after a slot choice.
World serializes the shared party, World and embedded Maze into that checkpoint;
the selected slot also supplies Restart. Success must mean stable poses and
confirmed persistent bytes, not only a RAM filesystem write. SavePoint contact
heals the party independently of whether saving succeeds.

IO: actual user:// slot and .pending rename/readback; IndexedDB confirmation;
physics/Tweens and shared area/input ownership. Branches: negative slot,
prologue/battle/reveal/aim/selector/hazard, active or moving Maze, duplicate or
concurrent writer, existing/missing prior bytes, native write failure, web sync
rejection, confirmed success. Autosaves and manual saves use distinct files;
New Game and recovery already confirm their writes. Do not blanket-disable
their intentionally paused recovery snapshots.

| ID | Failure | Risk and plausible cause | Test / status |
|---|---|---|---|
| SAVE-1 | A menu save commits a caught/hidden/in-transit actor and replaces the last usable checkpoint. | High: World has no stable-capture admission, unlike Maze and autosaves. | Reproduced on unmodified 1dc675c; repaired live rejection and stable/denied retries pass. |
| SAVE-2 | World announces success and selects a target before browser storage accepts it. | High: World manual path omits BrowserCheckpoint while other writers await it. | Disposable browser IndexedDB rejection/retry plus cold Load, pending. Native denied-write and retry preserve existing gate. |
| SAVE-3 | Held swimming or repeated inputs mutate the party while Save reading/confirmation owns the screen. | High: World physics only skips Inventory; reading is not a SceneTree pause. | Actual P/W and Sonar red at 1dc675c; repaired pose/Oxygen retention and resumed swimming pass. |

## Test design / self-critique

SAVE-1 first: refuse any preexisting disposable slots, create exact prior
checkpoints, cause a real hazard catch before the public Save menu signal.
Require no new destination bytes, no slot change and an actionable wait notice.
An always-disabled hazard fails the catch precondition; an always-disabled
writer must subsequently fail a stable save/reload/retry positive leg. This
does not call a private stability helper or assert on its implementation.

SAVE-2 browser will use a fresh browser context and fault the actual IndexedDB
transaction only there. No player database is edited. Inspect RAM and durable
bytes plus rendered notices and selected-slot behavior; restore permission and
use the actual UI retry/cold Load. Native IO checks cannot prove web durability.

SAVE-3 checks real input at an authored contact, not synthetic modal booleans.
These observable pose/IO contracts survive helper/enum/UI reflow refactors;
wrong-but-stable missing writes or frozen gameplay fail the positive legs.

## Skipped / outstanding

- No edits to normal player slots; disposable fixture IDs must be absent first.
- Whole-route/save migration/browser autosave are final campaign acceptance,
  not established by this bounded manual writer check.
- New Game/recovery IO already has independent tests; preserve those paths.
- Snapshots/font/punctuation are not checkpoint correctness oracles.

## Evaluation

- Caught on unmodified main 1dc675c: unstable save selected the target and
  replaced its bytes; actual P/W reading moved the diver and billed Sonar.
- Native repaired request retains exact source/target bytes and selected slot;
  stable retry saves current inventory; actual staging-directory failure retains
  both slots, and removing the denial permits a real successful retry.
- Reading runs real held W for240 physics frames, with Sonar on, then checks
  unchanged pose/Oxygen and actual swimming after another P closes the menu.
- Observer corrections: an early fixture was itself inside World's authored
  whirlpool, so freeing only the added hazard did not make it stable. The
  fixture now uses validated deep-zone water; it still requires a real catch.
  A regional notice is allowed to finish before the rejection reaches the
  foreground. The verifier waits for that existing queue instead of erasing it.
- Browser rejection reached the actual IndexedDB transaction and kept durable
  baseline bytes. The first retry observer waited5.2s after the click and missed
  the four-second success notice; Save's contact prompt had legitimately
  returned. That failed observer receipt is retained. The replacement observes
  the notice while live, with no weakened durability/cold-Load assertion.
- Repaired export browser rerun passed: actual slot-choice/overwrite clicks,
  real rejected IndexedDB writes, visible failure, unchanged durable source
  and target bytes, successful retry, live success notice, then cold Title
  Load of Slot2 and reopened Save Point at the saved pose. Fresh disposable
  context only. Exact hosted candidate/canonical repeat remains pending.
