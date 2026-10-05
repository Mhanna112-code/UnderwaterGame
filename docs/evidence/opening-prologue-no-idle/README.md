# No idle Angler: captured failure and verification

Runtime `296b1a562ef68727fb8b5d40f73d07aadc0b91a0`.
Review: https://underwatergame-opening-prologue-review.vercel.app/
PCK: 93,300,480 bytes; SHA-256
`845a691e700582c9abf1e60e15ac94f68e2bacc54ac6e9cbc52b624a6dae4d2a`.

## What changed

The old seven-second idle fallback started combat without input and allowed
idle time to consume the four-second exploration window. Native and exported
browser red logs reproduce it; the old hosted Angler began 7.804 seconds after
spawn while stationary. Earlier tests approved that behavior. It is superseded.

The trigger now requires four seconds of requested, actual horizontal swimming
and meaningful displacement. No-input, camera-only, passive/blocked movement
cannot bank the window. Exactly one authored Angler follows eligible swimming.

## Real evidence

- `native-captured-red.log`, `browser-captured-red.*`: failure before repair.
- `native-idle-look-swim-green.log`: 15 seconds idle, camera-only, real W input;
  4.059 seconds and 19.333 metres before combat.
- `trigger-matrix-green.log`: 384 heading/frame-time/prior-idle cases plus
  blocked, passive, vertical-only, displacement, reset and one-shot assertions.
- `browser-idle-look-swim-green.*`: full normal movie; 15.007 seconds idle,
  looking around, then real W. Angler only after 4.001 seconds of swimming.
- `idle-world.png`, `after-swimming-angler.png`: inspected actual hosted UI.
- `idle-then-real-swimming.mp4`: nine seconds cut at recording offset 73 seconds
  from the real continuous browser recording identified in the JSON. Includes
  late idle/look, visible swimming and Angler start. No synthetic game state.
- `browser-full-death-green.*`: full opening with idle/look, persisted save,
  cold Load, two actual enemy-caused deaths, Restart and title Load; no replay
  or runtime errors. Low-HP/position attrition fixture changes only this owned
  profile's real saved party after completion, never completion/damage/results.
  105.643 seconds total, 16.753 deliberate idle/look, 88.890 engaged seconds.
- `browser-storage-retry-green.*`: intentionally aborted completed-checkpoint
  transaction; visible Retry Save, accepted durable write and cold Load pass.
  Only the precisely injected storage error is excluded from error acceptance.
- Native logs pin normal death, voluntary training Skip/death, failed recovery
  save and world ownership. Rendered narrow framing also remains green.
- `rejected-headless-framing.log`: invalid visual fixture used a 64×64 dummy
  viewport despite its resolution flag. Retained as rejected, not a product
  pass. `rendered-framing-green.log` uses the actual 720×480 window and 720×205
  stage. No boss/camera change was made to satisfy the invalid fixture.

## Boundaries

No user storage was changed. Ordinary post-opening encounters and vertical-only
trigger policy are unchanged. This is not campaign balance, human comprehension,
or the overall final audio/visual zero-defect audit. Older incomplete saves are
not rewritten by guessing history. Main remains unchanged. Verification media
are excluded from the game package by `.gdignore`.
