# Opening title verifier save ownership

The existing real-video/title/W gate writes a fixed high-numbered slot 918312
without an ownership check or cleanup, despite its header requiring isolation.
It never targets normal user slots 0..2, but repeated runs can overwrite a
previous reserved artifact and leave it behind. Complete verifier and
SaveManager read. No product-save change is authorized by this harness repair.

Fix the harness boundary: choose a fresh high-numbered process-specific slot,
refuse to overwrite if it exists, and delete only that newly owned test slot's
saved/pending files after the real title/swimming gate. Leave pre-existing 918312
untouched because this run did not establish ownership of its prior contents.

Cheapest checks: read the actual existence guard/cleanup plus real World title
run; initial fixed-slot run is not evidence of save-isolated verification.
This scope does not test completed-opening cold Load/Restart, which has its own
checkpoint gates. No injected EOF/handoff or damage replaces actual video/input.

Evaluation: source-inspected IO ownership defect. Fresh owned-slot real title
and held-W run passes in `/tmp/underwater-marc-door-opening-title-owned-final.log`:
4.184 seconds of real swimming, 19.333m displacement, one prologue Angler, no
movement beneath the actual video/title. Cleanup checks pass; no normal user slot
is targeted. First new cleanup expression lacked an explicit String type and
failed parsing; corrected, rejected rather than counted as a production bug/pass.
The old 918312 artifact is left untouched. This is not a cold Load/Restart test.
