# Bomb Bot browser progress: Marc's October 4 report

Public surface: the exported title's Bomb Bot diagnostic action, rendered
Battle menus, real mouse clicks, enemy damage/attack feedback and World return.
This is not proof of normal travel to the lab. Disposable browser profiles only.

| ID | Failure mode | Accepting evidence |
| --- | --- | --- |
| BB-WEB-01 | A frozen fight passes because its canvas still draws. | Actual move/target menu transitions, multiple diver turns, changed HP or attack feedback, final victory and World controls. No-input negative control must fail. |
| BB-WEB-02 | A Chrome attack, death or return crashes, while construction tests pass. | Completed real fight with renderer/process/error monitoring and retained last action/screenshots. Test hardware Chrome separately from bundled Chromium/software rendering. |
| BB-WEB-03 | Automated clicks miss buttons after the bottom panel resizes. | Find rendered menu labels and click their actual OCR positions rather than assuming y=550. Reject failure to open the move menu. |

IO: hosted PCK/wasm, browser GPU, OCR process, randomness, real timers. Record
target URL, build metadata if available, browser version/backend and observations.
No immortal party, injected wins, production debug-state mutation or user saves.

Skipped: full grapple/Swap traversal and earned-kit maze route require their own
gates. A lab-only pass does not accept the second-wave Bomb Bot. Asset/Chrome
failure remains open until reproduced or independently retested by Marc.

Evaluation: BB-WEB-01 negative no-input control fails (exit 1). Real rendered
menus/mouse clicks on hosted PR96 and PR100 dcb7650 each complete 19 actions,
enemy attack feedback, actual victory and restored World controls without
captured errors. Bundled Chromium/ANGLE Metal on Apple M1 only; actual Chrome
on Marc's machine remains unverified and the reported crash is not closed.
Early heading-click and OCR failures were rejected harness runs, not game
freezes. Local-export directory support allows the same accepting oracle in
gates.sh; missing native OCR is a recorded skip, never a pass.
