# Current-main audit receipts

Production revision: 73c2d725c5cfc693bd47451ba9e7994fb481e87c.
No production game file is changed in this isolated audit checkout.
The only pre-existing tracked file changed is the public-input Whirlpool
verifier, copied through apply_patch from the pending local repair. Its SHA256:
d9b5d671c4c129d7592617f007b77fc19dfeff40e911fc6b64bb10f862379140.

Godot4.7.1, headless, bounded gtimeout80/90/120 seconds. These receipts exited0:
autosave, rest-hall, scaling, authored-turns, ramp and load-failures.
None contains engine/script ERROR, FINDING or infinite-loop text. Expected
CHECKPOINT_LOAD_FAILED diagnostic lines are invalid-load cases, not renderer
or script failures.

The five whirlpool receipts (menu, battle, maze-menu, map-pause, save-menu)
exited1 for the concrete ownership defects described in the audit document.
No engine/script ERROR appears. They are original-current-main negative
comparisons, never passing gates. The Save reading check makes no save request.

Canonical build-info at https://underwatergame.vercel.app/build-info.json
identifies runtime97bd48fb4f4c28f45fb2e55e9095b41a2b8691ba.
Actual canonical index.pck streamed/downloaded and hashed independently:
189095a31249e420b3db142e9aa2c0b9be41e7a7392eeb92970e5b31396eec5a,
matching local committed pack. Production READY deployment:
dpl_4vRT6zsVn9Dff4sAvnk9F3Hx5jCn; project link:null, not Git-autodeploy proof.

No full campaign, browser interaction/storage, native visual/audio listening
or target-platform launch was run by this audit. The ported pending verifier
and receipts can be retained with the subsequent main repair; do not push
this intentionally failing verifier into gates before fixing the defect.
