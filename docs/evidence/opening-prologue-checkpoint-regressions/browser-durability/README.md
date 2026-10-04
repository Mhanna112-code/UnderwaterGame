# Checkpoint continuity evidence, 2026-10-04

Runtime source: `85e15cf845c4ffccb51d85607e0375f99e32a039`.
Review: https://underwatergame-opening-prologue-review.vercel.app/
PCK: 93,082,756 bytes; SHA-256
`3742539758b4ed13382700ce8a06eec4da89474eb47275b89803bfb7b0d6dfb2`.
Unauthenticated alias download independently matches the exact clean export.
`build-info.json` records the served source and digest. `review-alias.log`
records alias assignment. Both main/default alias lookups still identify the
pre-existing `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5` deployment.

## Reproduction and repair

- `captured-red.*`: real exported opening with completed-checkpoint IndexedDB
  transactions aborted in an owned disposable test context. Old recovery still
  offered Continue while the durable slot remained initial. This is a confirmed
  replay mechanism, not proof of the user's historical session's exact cause.
- `storage-retry-green.*`: same rejection in the repaired exact local export;
  visible Retry Save retains the recovered session, then accepted persistence
  permits Continue and cold Load without replay. Only the specifically injected
  storage error is excluded; arbitrary runtime errors are not accepted.
- `retry-save.png`, `continue-after-retry.png`: inspected exported error/recovery
  actions, not mocked UI.
- `hosted-real-death-green.*`: full normal New Game/movies/real mouse combat,
  completion saved durably in 86.032 seconds, cold Load, two actual enemy-caused
  losses, visible Restart and Return to Title / Load. No opening replay or runtime
  errors. The test alters only saved party position/stats after obtaining the
  real completed checkpoint in its own profile. It does not inject completion,
  HP-zero, damage or a loss result. Restart HP 1 is the explicit attrition fixture;
  healthy checkpoint restoration is pinned separately by native recovery tests.
- `actual-ordinary-death.png`, `restarted-world.png`, `title-loaded-world.png`:
  actual hosted Game Over and restored world, inspected at 1280×720.
- Native logs: real loss/restart/load, write-denial retry, invalid load, successful-
  only slot switching, training restoration and migration regression checks.

## Rejected verification attempts

The retained `rejected-*` logs do not count as passes: unsupported JS-object
return via eval, a premature click on the disabled Saving action, movement away
from the site, and a combat click above the actual move button. The corrected
runner uses the supported bridge and observed public input paths.

The browser gate process timeout is 420 seconds for the full multiple-boot,
two-death journey; its opening acceptance limit is still 120 seconds.

## Limits

No player save was modified. Existing slots that never recorded completion
cannot safely be rewritten by inferring history. The new browser acknowledgement
guards prologue recovery; other later save-point/autosave acknowledgements and
browser cross-slot commit-denial testing remain follow-ups. This is not campaign
balance, a human comprehension test, or the final zero-defect audio/visual audit.
