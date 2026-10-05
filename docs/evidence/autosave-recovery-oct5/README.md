# Autosave recovery receipts, 2026-10-05

Runtime source: e74fcc55d1dd75339dd8ad3a8d05680ac8cbc61c. Includes latest main f457098, without reverting Marc's concurrent changes.
Pack SHA256: 16af7928a5180284e63fa2a2659d04e2c4802640c6fe292bea3bed1bb9fee2a4. Size: 94,973,920 bytes. Godot 4.7.1.

Native logs: newest valid selected Load and both recovery owners, generated successful-write ordering, legacy/absent/invalid snapshots, exact-byte rollback and failed-write ordering, explicit manual alternative, three-size menu bounds. Existing autosave writer, malformed Load, manual writer, actual maze enemy defeat and manual restart remain green.

Clean original baseline (after importing newly pulled main assets) exited 1 with: `SAVE-1 default Load restored older manual inventory instead of newer autosave`. The oldest file's potion count was 1; newer autosave was 7. Current native tests verify actual loaded resources, not mocked writer calls.

Local and hosted browser receipts have zero findings. They use NEW disposable browser profiles with disclosed older manual/newer autosave snapshots; actual swimming -> random encounter -> real enemy damage -> visible defeat menu -> mouse Continue -> restored auto; cold explicit manual Load; newer invalid-auto fallback; narrow Load layout. They do not prove earning the supplied saves or the entire campaign. Browser snapshots remain in those disposable profiles, not player saves.

Rejected observer receipts are retained rather than mislabeled as successes: contact-healing fixture, guarded-site fixture with mismatched reveal expectation, and target-selection observer clicking a non-interactive selected-move readout. Final fixture avoids contact ownership and the observer selects actual targets first.

Deferred: full gates/campaign balance, earned 180-second interval, audio polish, and matching Windows/Linux packages. Unchanged autosave timing/safe-write paths have focused existing regression coverage; this repair concerns recovering their output.
