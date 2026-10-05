# Autosave recovery repair

Scope: default death recovery and selected-slot Load must resume the newest usable snapshot. Keep explicit manual save-point recovery. Do not change the 180-second safe-play autosave interval, heal autosaved actors, overwrite snapshots on load, or modify player saves for verification.

## Bug catalog and verification

| ID | Observable failure | Verification |
| --- | --- | --- |
| SAVE-1 | Default Load chooses an older manual save while a newer autosave exists. | Selected-slot title load restores newer inventory and party state. |
| SAVE-2 | Death recovery ignores autosaves in both world and maze. | Recovery button reloads newest snapshot, preserving maze keys and geometry. |
| SAVE-3 | Blindly preferring autosave would discard a more recent manual save. | Alternating real writes restore the last successful write; same-second writes remain ordered. |
| SAVE-4 | Missing, corrupt, or incompatible latest snapshot could prevent recovery despite a valid older checkpoint. | Validated fallback; both invalid retains actionable title error without replaying opening. |
| SAVE-5 | Latest recovery could remove the safe, healed manual checkpoint option. | Explicit manual restart still restores manual snapshot without changing either file. |
| SAVE-6 | Failed save or sync rollback could reorder or destroy the last good snapshot. | Exact-byte rollback preserves ordering and existing atomic-write tests remain green. |

Fresh native/browser fixtures only. Existing opening/save/maze tests provide regression coverage. A browser pass must check the actual menu and persistent storage; test-green is not sufficient for a live-deployment claim.

Not in scope: changing progression, balancing enemies, shortening autosave interval, or migrating unrelated save formats. Legacy saves have no sequence metadata; use their existing file modification times, preferring manual on a tie. New writes receive per-slot monotonic sequence metadata.
