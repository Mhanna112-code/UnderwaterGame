# Three-second escape cue

Gameplay source: `7f9cb4ad268346b485927cb56f3e347dae60ca51`.
Browser harness: `8f27c7b` plus separate paused/Off component test additions.

The real successful Run handoff shows the actual R setting and a brief save-point
hint. Its background/border gently pulse at 1 Hz, without hiding the text, sound,
or a full-screen flash. It disappears after **three seconds whether or not R is
pressed**. Off stops pulsing immediately; changing the setting does not extend
the original deadline. The component expires during paused menus too.

No setting changes, healing, saving, pausing, Run-probability changes, or encounter
balance changes. Save-point contact and new battle/title/load/defeat dismiss old
feedback. Every cue Control ignores pointer input; it cannot block minigames.

## Reproduction and verification

- First red: actual World encounter signal -> enabled real Run button -> real
  successful probability roll -> world returned without any visible cue.
  `ESC-001 successful escape has no visible encounter-toggle cue`, exit 1.
- Green integration: actual Run, visible setting, readable pulse, three-second
  expiry with On untouched, actual failed Run with no cue, subsequent successful
  escape, real R input -> Off -> subsequent ordinary encounter ignored, no heal,
  no Oxygen changes, next encounter retires cue, public Load clears it.
- Separate component cases: already-Off is steady; paused menu still expires.
  These are not claimed as manufactured World escape results.
- Rendered native gate passes at 1280x720 and 720x480. Screenshots inspected:
  the cue is below both the objective and minimap, and does not cover controls,
  bottom recovery banner or HP/Oxygen bars. At narrow sizes it temporarily covers
  part of the world view, intentionally, for its short teaching beat.
- Existing exploration/checkpoint preference round-trip and local guidance/puzzle
  gates pass. No player saves or running player game process were touched.
- Hosted Chromium/Metal gate passes through ordinary New Game in 105.222 seconds,
  natural swimming to a random encounter, three real Run clicks before observed
  escape, real R -> Off, visible confirmation and cue expiry. No test query,
  browser RNG seed, injected battle result or edited checkpoint. Cold Load then
  restores the real completed checkpoint without replaying the opening. Zero
  browser errors. `browser/result.json` and screenshots record the result.

Commands use an isolated Godot user directory, owned slot 918321, and real inputs:

```sh
godot --headless --path <isolated-stage> --script res://verify/escape_encounter_hint.gd
godot --path <isolated-stage> --rendering-method gl_compatibility --resolution 1280x720 --script res://verify/escape_encounter_hint.gd -- --capture
godot --path <isolated-stage> --rendering-method gl_compatibility --resolution 720x480 --script res://verify/escape_encounter_hint.gd -- --capture
OPENING_ESCAPE_RECHECK=1 OPENING_SAVE_RECHECK=1 node verify/opening_webcheck.mjs <immutable-deployment> <evidence-directory>
```

## Release provenance

Candidate deployment: `dpl_2YjkkqPDkprbbbakwFjuvykBnuQw` (READY).
Immutable URL: https://underwatergame-65zibh73j-immortaldemongods-projects.vercel.app/

Export PCK: 100,460,384 bytes.
SHA-256: `585e357751776d2ffef8cb24d526c90b234233461ad7fd74ffbd6e92798533f3`.
Unauthenticated hosted download matches the local export. Clean export excludes
the isolated test user-directory override. Publication targets only the existing
opening-prologue review alias, never the main or secondary game alias.

Stable review URL updated and verified READY:
https://underwatergame-opening-prologue-review.vercel.app/
It resolves to the candidate deployment above; its unauthenticated PCK download
matches the same SHA-256. Both `underwatergame.vercel.app` and the secondary
project alias remain on `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`, unchanged.

## Limits

This does not make authored bosses or environmental/Oxygen hazards safe. It
teaches the existing toggle; it does not redesign navigation to save points,
retune base combat, or claim to repair all outstanding game defects.
