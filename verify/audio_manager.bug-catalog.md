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
| AUDIO-004 | Replacing a cue leaves the old stream active or lets its finished handoff start the old loop. | Replace one sequence with another, then advance and require only the replacement loop. | Covered by `verify/audio_manager.gd`. |
| AUDIO-005 | Music and SFX volume/mute settings disappear on restart or mutate the wrong bus. | Config round trip plus real bus assertions. | Covered by `verify/audio_manager.gd`. |
| AUDIO-006 | Browser autoplay prevents music from ever starting, or scene transitions stack tracks after the first user gesture. | Fresh web export, browser console/audio-state probe, and human listening pass. | Planned integration verification. |
| AUDIO-007 | A canonical Phoenix source is missing, corrupted, silently substituted, or imports with the wrong duration. | Pin every selected runtime digest and decoded duration. | Covered by `verify/audio_assets.gd`. |
| AUDIO-008 | An ambiguous filename is treated as a proven Intro/Loop contract and an unreviewed join ships. | Manifest disposition plus named-cue integration test; only the explicit Battle pair is accepted without listening approval. | Characterized in `docs/audio-manifest.md`; browser listening pending. |
| AUDIO-009 | A scene chooses file paths itself, wires Tethys to the unapproved `verb tail`, or treats game-over as a loop. | Named product-cue contract on the autoload owner. | Covered by `verify/audio_manager.gd`. |
| AUDIO-010 | Cold title violates browser autoplay, or World/Battle transitions leave exploration, Battle, boss, victory, or defeat music stale/stacked. | Drive real World start, ordinary battle win, Tethys loss, game-over, and title return while asserting the public audio state. | Covered by `verify/audio_lifecycle.gd`. |
| AUDIO-011 | Menu SFX are absent, doubled, or mapped to the wrong semantics; Start Game fires on navigation or Click replaces a real start. | Drive fresh New Game, returning-player slot navigation, run selection, and Back through real buttons while asserting the SFX event trace. | Covered by `verify/title_audio.gd`. |

## Self-critique

- A deterministic state-machine test proves ownership and ordering, not that a
  WAV is pleasant, audible, or seamlessly edited. Each selected track still
  needs waveform inspection and a human listening pass in the exported build.
- Headless Godot cannot establish real browser autoplay behavior. That remains
  a mandatory web verification boundary.
- Runtime Ogg digests prove the reviewed transcodes are unchanged, not that
  lossy compression preserved a musically seamless boundary. Listening is
  still the deciding evidence.
- Scene lifecycle ownership is deliberately outside the first test. World,
  battle, victory, and defeat will each receive focused behavioral coverage
  before they can call the manager.
