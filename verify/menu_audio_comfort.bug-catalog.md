# Menu hover comfort (2026-10-04)

## Responsibility / interfaces / IO / branches

Read full AudioManager, TitleScreen and existing title/audio asset/manager
tests. TitleScreen wires enabled buttons' mouse_entered to play_ui_hover;
disabled slots remain silent. Initial keyboard focus is intentionally silent.
Manager owns one UI SFX player (stop-and-replace, not overlapping), four
separate combat players, authored music gains and persisted Music/SFX settings.
Public play_ui_hover/click/start_game are the semantic boundary. Original
hover WAV lasts 4.039 seconds, peak -10.1 dBFS and long tail; every entry can
restart its transient. Existing tests only check requested event IDs, not
duration, acoustic level or rapid pointer behavior. Headless intentionally
does not start hardware playback. Real audio needs rendered/native capture
and hosted browser output, not an event trace alone.

Time: monotonic wall clock for rate limiting, independent of paused title.
Files: preserve Phoenix source WAV/hash; create explicit reproducible runtime
derivative, no global volume preference rewrite. SFX bus remains the mute/
volume authority. Branches: first hover, rapid re-entry, later hover, hover
following confirm, disabled button, muted/zero volume, shutdown/recreation.

## Bugs / tests / critique

| ID | Failure | Risk / reason | Test |
| --- | --- | --- | --- |
| OPEN-047 | Hover sounds harsh/long at default volume. | User reported; raw 4s clip at zero authored trim. | Capture title button hover through actual audio bus; short stream <=250ms, output peak <=-24dBFS, audible but bounded energy and faded edges. Raw source must fail duration/peak bounds. |
| OPEN-048 | Rapid pointer re-entry repeatedly restarts the attack or interrupts confirmation. | One player replaces on every mouse_entered without rate limit. | 32-event bounded hover burst: first accepted, rapid remainder suppressed; later hover works while tree paused; immediate confirm still plays and subsequent hover cannot truncate its initial acknowledgement. |
| OPEN-049 | Softer hover bypasses SFX mute/slider or changes music/combat/confirmation mix. | New local mix/cooldown can leak into shared bus/player settings. | Native actual output capture at full/half/muted/zero; differential amplitude and silence, unchanged Music preference; title click/start event contract and existing combat gates. |

Assert audible output/timing/duration, not calls to a private helper. Event
trace is supplementary to native/browser audio capture. Concrete level and
duration thresholds reject wrong-but-stable output. Properties cover a
bounded input burst and independent preference cases. Refactoring may change
player internals but must preserve the public audible contract.

## Skipped

- Music, movie audio, combat, victory/defeat tuning: not this menu-hover report.
- Replacing Phoenix's canonical originals or inventing new audio: derive a
  clearly documented quiet hover from his existing asset instead.
- Absolute loudness at the user's speakers/headphones: OS/hardware dependent;
  digital measurements cannot certify subjective comfort. Invite user review.
- Full opening visual/audio acceptance: remains a separate open audit.

## Evaluation

- OPEN-047 captured red from real title hover/native Master output: 4.039s,
  -10.06dBFS peak. Short/filtered/faded derivative passes: 180ms,
  -26.16dBFS peak (about 16dB lower). Phoenix original hash retained.
- OPEN-048 burst/confirmation test failed before the clock guard; fixed by
  250ms monotonic rate limit and initial confirm protection. Later paused
  hovers still work; click/start events are not rate-limited.
- OPEN-049 actual Master output at half SFX volume is half amplitude; mute
  is zero and zero slider is effectively silent. Music preference unchanged.
  Initial pre-fader SFX-bus capture could not observe downstream settings;
  this verifier defect is preserved in `pre-fader-harness.log`, not claimed
  as a gameplay mute bug. Capture now measures downstream Master.
- Existing asset/combat/prologue gain checks and isolated title/audio
  sequencing pass. Title's save-slot fixtures run with a temporary isolated
  application data directory, not the player's actual saves.
- Hosted ordinary-title real mouse input passes: actual audible GainNode
  output peak -27.44dBFS, longest detected pulse about 149ms, 20 rapid pointer
  passes rate-limited to five cues, zero runtime errors. Initial capture
  concatenated the audible GainNode and separate silent AudioWorkletNode and
  stretched measured time; `browser-capture-first.*` preserves that verifier
  defect. Per-node capture now separates them and rejects ambiguous outputs.
- Final native test observes actual Master-output duration instead of a
  private named player. Half/mute/zero behavior remains green. Asset duration
  is 180ms; its faded audible span above the measurement threshold is 148ms.
- Exact served export matches runtime source `ceb049c`; same review alias
  refreshed, public main unchanged. User comfort at their own output volume
  remains a subjective review, not proven by digital measurements.
