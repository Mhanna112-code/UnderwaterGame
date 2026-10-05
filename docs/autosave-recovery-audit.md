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

## System contract

- Inputs: selected slot, manual/autosave JSON files, title choice or death recovery choice.
- Outputs: restored inventory/party/route/maze, or a paused actionable title error. Loading never writes or heals a snapshot; normal save-point contact may heal afterwards.
- Dependencies: atomic SaveManager writer, BrowserCheckpoint durable-sync acknowledgement and exact-byte rollback, World preflight validation, CampaignCheckpoint maze decoding.
- Rules: preserve selected-slot ownership; newest successful snapshot wins; reject bad shape before actor mutation; completed opening does not replay; explicit manual restart remains independent.
- Existing edge cases: same-second writes, failed writes/sync, newer manual after autosave, missing/corrupt/legacy files, embedded-maze geometry/keys, starting a new run clears only the previous run's autosave after confirmation.
- Boundaries: plain legacy World JSON and version-1 campaign envelopes remain accepted. Optional top-level `save_sequence` metadata does not change either save schema.

## Test critique and evaluation

`latest_save_recovery.gd` caught SAVE-1 red on the original default Load: potion inventory was 1 instead of the newer autosaved 7. The production fix then passed. Its generated alternating-write oracle is the last successfully supplied inventory count, not a copy of the comparator. It checks restored resources, exact retained bytes and World/maze ownership, not merely that a helper was called. Writer rollback and recovery routing cover SAVE-2 through SAVE-6. The native test uses isolated chosen-slot signals and recovery UI buttons; it does not claim earned autosave timing or browser mouse behavior.

The browser check supplies declared snapshots in a fresh profile, then uses actual rendered Load/recovery controls and real combat damage. Rejected observer attempts are retained: a fixture on the newly auto-healing save point; a fixture inside a guarded item site that started ordinary combat rather than the observer's expected random reveal; and an observer choosing the selected-move readout instead of the actual target button. These are not evidence of recovery defects. The corrected fixture is away from save/guard sites, and the observer prioritizes target buttons during target selection.

Skipped: full campaign balance, intentional menu-art redesign, native Windows/Linux launches, and a wall-clock 180-second earned autosave journey. Existing safe-ticker/durability tests cover the unchanged writer; focused new tests address recovery selection. Internal UI fixture seams may need adaptation during a presentation refactor; the assertions remain actual loaded state/visible behavior and exact bytes.

## Accepted verification

The final local export and hosted candidate browser runs both finished with zero findings. Hosted input earned an ordinary random encounter, real enemy damage caused Game Over, and the visible Continue action restored the newer autosave. Cold Load, explicit manual recovery and parsed-invalid newer autosave fallback restored the expected saved HP. Desktop defeat and narrow Load layouts were visually inspected. Native latest recovery, existing autosave writer, actual maze defeat/manual restart, malformed loads, manual writer and three-size title checks finished clean, without captured script/engine errors.

Export source: `e74fcc55d1dd75339dd8ad3a8d05680ac8cbc61c`, preserving Marc's `f457098` main changes. Pack SHA256: `16af7928a5180284e63fa2a2659d04e2c4802640c6fe292bea3bed1bb9fee2a4` (94,973,920 bytes). Verification-only changes after export are excluded from the pack. Receipts and rejected observer attempts: `docs/evidence/autosave-recovery-oct5/`. This is focused recovery acceptance, not a full-campaign or earned-autosave-timing claim.
