# Ordinary enemy reveal before random combat

Gameplay source: `4c6ca744e528c3cd11f98815e97ce2afe341043c` (local branch;
this packet does not claim a GitHub push or main merge).

After the prologue, a normal successful distance roll selects the pack once.
The actual Angler/Swordfish/Frilled Shark actors appear in the exploration
World3D for 1.5 engine seconds, then that exact roster enters ordinary combat.
World movement/input/stat timers freeze briefly. No new enemy colliders, rings,
prompt, stat overrides, checkpoint writes, healing or encounter-rate changes.
Exploration music continues until the ordinary battle cue. Authored/site,
special, tutorial and prologue entry paths remain separate.

## Checks and real defects

- Initial direct-to-Battle contract failed before implementation (recorded in
  the bug catalog). `contract.log` passes real public-signal dispatch, displayed
  actors, frozen position/HP/O2/preference, duplicate-event exclusion, identical
  Battle roster, title cancellation, actual Load and in-flight teardown.
- `roster.log`: 32 real Battles across four levels retain the selected count/
  species and existing formation bands.
- `framing-solid-camera-red.log` exposed previews hidden/intersecting the
  entrance blockade when the chase camera sat on its solid face. The reveal
  temporarily finds a clear camera origin, checks silhouette sight-lines and
  occupied volume, then restores the original view. Proportional close-range
  travel avoids moving tiny foreground rigs through scenery/near plane.
- A straight-on Shark looked like a small floating head. A three-quarter
  orientation shows its body. `framing.log`: 90 formations / three live
  animation samples each; wide/narrow, five rosters, three pitches/yaws,
  open/low-floor/wall-side camera origins. Final `formation-captures/` renders
  were inspected. Their explicitly resized fixture has stale unrelated HUD
  layout; `native-narrow-final/` separately shows normal compact World entry.
- Guardian exclusion, all mapped site dispatches, normal-stat prologue combat,
  three real player turns between individual Cordys defeats, tutorial victory
  handoff and invalid-checkpoint handling remain green (individual logs).

## Browser: affected contract versus whole-opening result

All browser runs start with ordinary New Game and full movies; no URL test flag,
save fixture, injected encounter signal or fabricated combat result. Actual D
swimming rolls an encounter. Real Run returns to exploration.

`browser-recording-overrun/`: Frilled Shark reveal, **1646ms** browser-source
duration, same species in the real battle HUD, successful Run and R/expired
cue, zero runtime errors. `random-encounter.gif` is seconds 158–164 of its actual
recording, showing swimming → world Shark → combat. This recording's opening
measured **120.991s engaged**, over the existing 120s acceptance band.

`browser/`: independently rolls Swordfish; **1839ms** reveal, actual Swordfish
battle HUD and usable controls, zero runtime errors. Its separate whole-flow
test stopped because the temporary escape cue expired while diagnostic OCR
was running: the retained Off screenshot shows the persistent HUD correctly
Off and the normal “Random encounters off.” announcement. The oracle now checks
the persistent setting, not a demand to prolong the three-second hint. This
run measured **134.803s engaged**; absence of recording did not eliminate the
broader opening timing overrun. We do not claim the whole opening gate is green.

`browser-ocr-clock-red/`: earlier timing oracle received the omen event late
while synchronous Node OCR blocked log delivery; it falsely shortened that
beat. Browser-source console timestamps now observe the actual event without
changing game state or widening timing bands. The failed run is retained.

`browser-reveal-contract.json` and `browser-recorded-reveal-contract.json` are
separate, scoped semantic evaluations of those real traces, matching the
rendered enemy HUD and usable Run control as well as logs. Both PASS and both
explicitly retain the separate whole-flow failure. This is not greenwashing
the broader acceptance test.

## Deployment

- Existing review alias: `https://underwatergame-opening-prologue-review.vercel.app/`.
- READY candidate: `dpl_NfETWbn74s1o1oSodnAbhwUnh938`.
- Immutable URL: `https://underwatergame-cmop2s7of-immortaldemongods-projects.vercel.app/`.
- Export: **111,641,396 bytes**, SHA-256
  `027740c15745e1acac7d5938b5dddafb9df9840d369c8d1480feecf103e6b5a8`.
- Served candidate PCK matches the local export. Public main and its secondary
  alias were `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5` before deployment; post-alias
  verification is retained separately. No production main promotion intended.

The final bounded reveal round has no observed new preview defect. Existing
opening timing, OPEN-032 optional-training label occlusion, OPEN-046 save-point
occlusion and wider whole-game acceptance remain open; this task does not fix
or claim completion of them.
