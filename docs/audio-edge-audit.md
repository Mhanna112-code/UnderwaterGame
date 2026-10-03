# Audio edge audit

Candidate: PR #96 source head `735fdad`.

This is a decoded-signal check of the exact runtime Ogg files. It catches
missing audio, silence at a handoff, a gross level discontinuity, and an
obvious non-looping export. It does **not** replace the required subjective
browser listening pass: musical phrasing and whether a transition feels good
cannot be accepted from a waveform statistic.

The files were decoded to stereo 48 kHz float PCM with FFmpeg. Edge RMS uses
the final/first 100 ms. `sample jump` is the largest absolute left/right
sample discontinuity at the join.

## Intro to loop

| Cue | Edge RMS | Difference | Sample jump | Disposition |
| --- | ---: | ---: | ---: | --- |
| Battle | -36.21 to -14.56 dB | +21.65 dB | 0.0406 | No digital silence or missing segment, but the deliberate quiet intro tail to full loop entrance needs listening approval. |
| Victory | -18.42 to -12.75 dB | +5.67 dB | 0.0085 | Technically continuous; listening approval remains. |
| Title candidate | -21.93 to -22.42 dB | -0.48 dB | 0.0118 | Technically even; still not wired as production title music. |

## Loop self-edge

| Cue | Edge RMS | Difference | Sample jump | Decoded peak |
| --- | ---: | ---: | ---: | ---: |
| Exploration | -16.24 to -12.33 dB | +3.92 dB | 0.0734 | +0.11 dBFS |
| Battle | -18.47 to -14.56 dB | +3.91 dB | 0.0409 | -0.41 dBFS |
| Tethys | -24.15 to -14.69 dB | +9.46 dB | 0.0194 | -0.57 dBFS |
| Victory | -19.47 to -12.75 dB | +6.72 dB | 0.0077 | -0.44 dBFS |
| Title candidate | -21.93 to -22.42 dB | -0.48 dB | 0.0118 | -4.50 dBFS |

The files labelled `LOOP` by Phoenix contain audible signal at both edges and
the runtime manager enables forward looping on one music player. The Battle
intro/loop and Tethys loop are the highest-priority listening checks because
their 100 ms edge loudness changes are the largest. Do not classify these as
defects or as approved joins until a person listens through the exact browser
deployment at normal volume.

## Deferred final-boss pair

Phoenix's canonical ZIP also contains the files below. They are deliberately
not imported because Octopus gameplay is outside this slice; the older
`Underwater Final Boss (DEMO).mp3` remains reference-only.

| File | Duration | SHA-256 |
| --- | ---: | --- |
| `Underwater Final Boss 1 (INTRO).wav` | 22.588 s | `122544c04a6874ecc9d24468160950e02a70b2e7e5d933273e354efcc6d4dd91` |
| `Underwater Final Boss 2 (LOOP).wav` | 90.353 s | `20020af1293e4fe1736078446b8b84447b127283930d77b52bb50b9f1b0875d8` |
