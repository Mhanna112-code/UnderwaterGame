# Angler victory and Octopus suspense

Gameplay source: `d7b999bfaf25746a9b2d7fafa4ce1fed10d4cd2a`.

The old real-kill handoff went straight to the Octopus movie phase, waiting only
0.65 seconds. The replacement acknowledges the win before reversing its mood:

1. **Victory** / **The Angler is defeated.** (2.3 seconds).
2. **Your victory has not gone unnoticed.** (about 1.93 seconds).
3. **Something stirs in the deep.** (about 2.1 seconds), then fade to black and
   the existing split Octopus introduction.

The actual defeated battlefield stays visible without stale combat controls,
using a read-only stage texture with preserved aspect. No em dashes or rolling
text. Existing Phoenix victory music is locally quiet (-9 dB), fades to silence
on the notice beat, and stops before the movie. Player volume/mute are unchanged.
No XP, healing, save, tutorial completion or early return to world is added.
Normal combat math, existing full movie lengths and the same Battle persist.

## Verification

- `red.log`: actual attacks kill the Angler; original code has no visible win.
- `green.log`, `wide.log`, `narrow.log`: actual W swimming and real move/target
  buttons, ordered public phases, readable alpha/viewport bounds, 5.5–7.5s bridge,
  Escape/R/W exclusion, unchanged HP/position/preferences, no premature rewards,
  music-owner retirement and preserved audio settings. Exit 0.
- Native wide/narrow screenshots inspected; stale turn queue was identified and
  removed from this interstitial. `transition.gif` is a native viewport recording,
  not a composited mockup. Captured frames sampled about every 0.15 seconds;
  gate logs, rather than GIF playback, establish actual timing.
- `state.log`: generated durable milestone x every allowed transient phase
  restoration passes, including all three new phases.
- `journey.log`: full native movie/boss/recovery, checkpoint Restart and title
  Load remain complete. Its fast ordinary-loss characterization emits the loss
  boundary; it is not claimed as proof of a naturally played enemy defeat.
- Native runs use an isolated custom user directory and owned test slot. The
  running player Godot process and player saves were left untouched.

Commands:

```sh
godot --headless --path <isolated-stage> --script res://verify/angler_victory_transition.gd
godot --path <isolated-stage> --rendering-method gl_compatibility --resolution 1280x720 --script res://verify/angler_victory_transition.gd -- --capture
godot --path <isolated-stage> --rendering-method gl_compatibility --resolution 720x480 --script res://verify/angler_victory_transition.gd -- --capture
OPENING_SAVE_RECHECK=1 node verify/opening_webcheck.mjs <immutable-deployment> <evidence-directory>
```

## Release provenance

Candidate: `dpl_9fk52M37PqP8nu6gPgmaaPRuunZ3` (READY).
Immutable URL: https://underwatergame-cbce76m4b-immortaldemongods-projects.vercel.app/

PCK: 103,845,028 bytes. SHA-256:
`289e100ab8341312ea4c233239df38cdd14716dc598ddb6c59557ef40fd1baf9`.
Unauthenticated hosted download matches the clean export. No verification
user-directory override is shipped. Candidate created with `--skip-domain`;
only the existing opening-review alias may be updated after browser verification.

Hosted Chromium/Metal normal New Game passed in **115.825 seconds**, without
query-string shortcuts, injected defeat or shortened movies. Actual move clicks
produce the win and all three OCR-readable beats; the browser phase trace
measures a 6.43-second bridge. The complete normal boss/recovery handoff remains
under two minutes. `browser/result.json` records zero errors and no failure.
Cold reload followed by the visible title Load restores `complete`, without
replaying the opening; the actual checkpoint retains optional training as
incomplete, and Sonar/encounters On. No browser checkpoint was edited.

Published only to the same stable review URL:
https://underwatergame-opening-prologue-review.vercel.app/
It resolves to `dpl_9fk52M37PqP8nu6gPgmaaPRuunZ3`; its PCK matches the export hash.
Both main and secondary game aliases remain on
`dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`, unchanged.

## Limits

This implements a brief confidence/suspense bridge, not new combat balance,
campaign rewards, animations, lore, navigation or tutorial redesign. Audio gain
and ownership are verified; subjective perceived loudness still depends on the
player's settings and device.
