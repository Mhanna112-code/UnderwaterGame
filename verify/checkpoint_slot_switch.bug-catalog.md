# Cross-slot save and message ownership — October 5

## Module and public contract

Read checkpoint_slot_switch.gd completely, plus World serialization/validated
Title Load, forced tutorial beam and manual-save admission/result consumers.
This is an IO fixture test, not an earned journey: two absent owned slots model
an incomplete target and a completed, post-training source. Title Load restores
the source; the public Save menu request attempts a cross-slot replacement.
No ordinary player slots are touched. File permissions deny the real pending
writer; removing denial allows a real retry. Cleanup only owned files.

IO: native files/permissions/rename and message queue/physics time. Branches:
absent/preexisting fixture; completed versus tutorial-owned source; denied
staging versus successful retry; selected source/target; unread failure before
queued success. Current World intentionally rejects saving while the forced
beam/intro owns onboarding. Browser durability is a separate acceptance path.

| ID | Failure | Test and current status |
|---|---|---|
| OPEN-030 | Failed replacement selects or damages an older target; retry loses completed progress. | Native real denied write, exact both-slot bytes, selected slot, and positive retry with completed milestones. |
| MSG-6 | Retry erases the unread failure or never delivers its committed-save notice. | Actual queued banner failure retained before later success, bounded wait. |
| SLOT-FIXTURE | A supposedly stable source still owns compulsory training, so admission rejection is falsely diagnosed as a persistence failure. | Diagnose actual loaded state; source fixture must include completed tutorial. |

Captured current full-suite failure and separate diagnostic both show
`loaded_complete=true`, `tutorial_complete=false`, `intro=true`. Both requests
correctly announce “Wait for the movement or encounter to finish, then save.”
The old fixture completed the opening but not the restored forced tutorial;
it never reached denied IO. Repair the fixture to a completed **post-training**
source rather than weakening the production save guard or clearing intro.
Keep the incomplete target and independent byte/selection/notice assertions.

Self-critique: an always-denied writer cannot pass the successful retry; a
silently selected old target fails selected-slot and bytes oracles. No private
stability-helper assertion, no mocked write result and no punctuation oracle.
Skipped: earned route/tutorial completion, browser IndexedDB, target OS launch;
they require separate tests. These fixtures do not establish campaign balance.

Corrected native run exits0: loaded source is completed/post-training with no
intro owner; actual denied IO preserves both slots and selected source, retry
selects the target while keeping the failure visible, then success appears.
No engine/script errors. The production save guard was not edited. Original
five-finding diagnostic is retained next to the green receipt in
`docs/evidence/sonar-pickup-lifetime-oct5/post-publication-tests`.
