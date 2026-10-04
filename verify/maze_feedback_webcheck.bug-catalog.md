# Exact feedback export, not a complete maze review

Read current source/exports and existing browser gates: old maze_webcheck still
uses M/H, so it cannot accept Marc's L/E/R controls. Browser boundary is the actual
HTML→WASM/PCK→visible title/maze/map, not an API. The engine owns drawing/input;
Node serves an isolated export. Public keyboard L and rendered OCR are the UI
oracles, not JavaScript writes into game state. Pack network bytes/digest must
match the same source export's metadata, preventing stale proof/link confusion.

Catalog: stale/wrong downloaded pack (SHA/size invariant); absent runtime resources
or boot errors (captured page/script errors and real title); retained M/H harness
passes wrong controls (actual L and visible map text). Exact route fixture skips
the opening and does not prove campaign entrance/resources/navigation/combat.

Skipped: injected boss wins/state, full traversal, IndexedDB save, subjective audio
and polish acceptance. Full opening browser gate and actual native game checks
remain separate. Stable wrong screenshot cannot pass the semantic OCR and digest
checks. The first smoke run may characterize working export boundaries rather
than reproduce a new production bug; stale M/H is already a known harness defect.

First run: real title and L map rendered, but Chromium evicted the 92MB PCK
from its default inspector cache. Enlarging the cache did not solve retention and
also produced a screenshot timeout; neither run is accepted. The corrected
artifact oracle streams the actual served pack endpoint outside that cache,
then separately requires completed browser requests to that same endpoint and
rendered title/map in isolated contexts. This verifies served bytes, not a
digest extracted from Chromium memory; its receipt explicitly names that scope.
Evaluation: corrected local run passed on runtime 08d8d97: served endpoint
92,415,496 bytes, SHA256 1ca695124a1b9760c7a189cdbae4e76821e718021e6445b6d2ccf3630872aa41;
two completed browser requests, real title and L-map controls, no captured errors.
Title/map PNGs were inspected. No traversal/audio/persistence claim follows.

Live 1ccf92f also passed its served digest/size and title/L-map checks. The first
alias refresh mixed earlier metadata with new pack bytes and correctly failed;
do not accept a mismatch as a deploy pass. EXPECTED_SOURCE_SHA now optionally
rejects stale-but-self-consistent deployments before rendering. The accepting
runner replaces the historical M/H pixel-change check (ambient animation could
make it green) with this explicit L-map/export test, or logs a missing-manifest
skip. Physical navigation and full browser checkpoint paths remain separate.

Explicit wrong EXPECTED_SOURCE_SHA was rejected before downloading/rendering
as intended. That negative harness result is not a production game failure.
