# Audio Manager Bug Catalog

## Scope

Phoenix's authored music uses both single looping tracks and exact
`INTRO` then `LOOP` pairs. The game currently has no central audio owner, no
Music/SFX buses, and no lifecycle wiring. These checks establish the music
state machine before any scene is allowed to trigger it.

## Bug catalog

| ID | Observable failure | Cheapest catching test | Status |
| --- | --- | --- | --- |
| AUDIO-001 | Starting an intro/loop cue plays the loop at the same time, crossfades it, or leaves more than one music player active. | Start a two-part cue through the public manager API and require exactly one music player in the intro phase. | Covered by `verify/audio_manager.gd`. |
| AUDIO-002 | Finishing an intro stops the cue, restarts the intro, or starts the loop more than once. | Advance the production finished-handler once and require one transition to the looping phase; advance again and require no restart. | Covered by `verify/audio_manager.gd`. |
| AUDIO-003 | Re-requesting the active cue stacks playback or resets a playing intro/loop. | Request the same cue twice and require an idempotent state/transition trace. | Covered by `verify/audio_manager.gd`. |
| AUDIO-004 | Replacing a cue leaves the old stream active or lets its late finished signal start the old loop. | Replace one sequence with another, then advance and require only the replacement loop. | Planned after the first contract is green. |
| AUDIO-005 | Music and SFX volume/mute settings disappear on restart or mutate the wrong bus. | Config round trip plus real bus assertions. | Planned as a separate TDD increment. |
| AUDIO-006 | Browser autoplay prevents music from ever starting, or scene transitions stack tracks after the first user gesture. | Fresh web export, browser console/audio-state probe, and human listening pass. | Planned integration verification. |

## Self-critique

- A deterministic state-machine test proves ownership and ordering, not that a
  WAV is pleasant, audible, or seamlessly edited. Each selected track still
  needs waveform inspection and a human listening pass in the exported build.
- Headless Godot cannot establish real browser autoplay behavior. That remains
  a mandatory web verification boundary.
- Scene lifecycle ownership is deliberately outside the first test. World,
  battle, victory, and defeat will each receive focused behavioral coverage
  before they can call the manager.
