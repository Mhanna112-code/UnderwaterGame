# Softer opening-menu hover

Runtime source: `ceb049ccef66d4fe1a4062ca117b92ebf9370362`.

Phoenix's original hover WAV remains unchanged. Title hover instead uses the
reproducible derivative from `tools/prepare_menu_hover.sh`: 180ms, 1.8kHz
two-pole low-pass, 12ms attack, 90ms release, -15dB asset trim. A monotonic
250ms guard prevents rapid re-entry restarts and protects the beginning of
click/start acknowledgement. Normal click/start, music, combat and persisted
SFX preferences are not rebalanced.

- `hover-red.log`: actual title hover/native audio initially 4.039s with
  -10.06dBFS peak; rejected by comfort bounds.
- `hover-green.log`, `full-native-green.log`, `native-hover.wav`: actual
  output at -26.16dBFS (about 16dB below the original); audible span about
  148ms above the measurement threshold. Half SFX gives half amplitude;
  mute is zero; zero slider is effectively silent. No preference saved.
- `interaction-red.log`, `interaction-green.log`: bounded rapid-entry
  burst, later hover while SceneTree paused, immediate click/start priority.
- Existing assets/combat/prologue-mix/title/manager green logs. Save-modifying
  title checks ran in a temporary isolated application directory; the
  override was removed before the normal production export.
- Headless gate only proves event/timing policy; it deliberately does not
  claim real audible playback. Native and browser capture fill that boundary.
- `browser/rapid-hover.wav`, `browser/result.json`, `browser-green.log`:
  ordinary cold title, trusted cover click outside menu, 20 real pointer
  entries. Passive WebAudio capture retains the production graph/output.
  Peak -27.44dBFS; longest pulse about 149ms; five accepted cues rather than
  20 rapid attacks; zero runtime errors. No query flags or injected sounds.
- `pre-fader-harness.log` and `browser-capture-first.*` are verification
  defects, not gameplay mute/duration regressions. Their corrected recording
  boundaries and why the first results were rejected are in the bug catalog.

Exact clean archive/export: 93,339,592 bytes. Served PCK SHA-256 matches:
`01fb064cdee83cce3b6193e601e7ec40e62a679436d5a18a736746d19c64fbc1`.
Deployment `dpl_EF8cE4rEotSS8KdAvceHT57uJ84k`:
https://underwatergame-hugtgp72s-immortaldemongods-projects.vercel.app/.
Same review alias refreshed and served metadata verified:
https://underwatergame-opening-prologue-review.vercel.app/.
Both main aliases remain `dpl_HEhyJ5cpLkbptB19ZioSAZFpu4H5`.

This packet proves digital level/duration/rate and preference behavior, not
subjective comfort on a particular speaker/headphone/OS volume. No claim that
the larger opening visual/audio listening audit is complete.
