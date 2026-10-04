# Cordys opening prologue — asset manifest

**Status:** implementation manifest, 2026-10-03; hosted/listening acceptance pending.

Every runtime asset in the child PR must have one canonical source, one
semantic owner, and one web verification path. Dropbox duplicates and archive
metadata are never runtime inputs.

| Role | Canonical source | SHA-256 | Runtime path/status | Owner and disposition |
| --- | --- | --- | --- | --- |
| Temporary opening master | `/Users/tomriddle1/Dropbox/Mermaid_Freak.mp4` | `e8233e3571f1a3ecbea7749155254ed6183935f3667a11c281d35215924a5ffb` | Existing `res://media/cutscenes/mermaid_freak.ogv`, SHA `964d941a17ce417d38b8eaa80a419d9210a7b3b2c314bf7154f1627e9887aeb2`, 10,005,448 bytes | `OpeningVideo` now owns first-run non-skippable playback at -6 dB through Music; `LabVideoCutscene` retains its independent skippable policy. One runtime file only. Browser visual/listening proof remains. |
| Cordys model | `/Users/tomriddle1/Dropbox/Octopus_Boss_V2.fbx` | `e51ac165292525291714505341661067dc56022b20dc52d7aa29ccdf2d491792` | Existing `res://art/deep_zone/Octopus_Boss.fbx`, same SHA, 12,985,388 bytes | Prologue presentation owner only. Campaign Cordys remains deferred. Suppress/repair the bright-line primitive after visual proof. |
| Exploration ambience | Phoenix canonical ZIP member `Underwater Exploration Ambience (LOOP).wav` | `7d535afb8929b12cfc8148479b6ebc2b900c57dbd8e87960777764ef26ba8543` | Existing `res://audio/music/exploration_loop.ogg`, SHA `5af14408aa0bb8c8dfc9290c87afef214b4d07fe4e765ae6641cdaf5859a42f8` | Preserve ordinary PR #96 owner. Prologue applies authored gain only. |
| Angler Battle intro | Phoenix canonical ZIP member `Underwater Battle Theme 1 (INTRO).wav` | `e08f5bdfce52fdf75006fc403ce449b72b7677c815d83fe26c563d03710eae08` | Existing `res://audio/music/battle_intro.ogg`, SHA `9e7dfbd99c85214233cbc47c499076f4622e8deec5a009e697461dd1e99857e4` | Existing normal Battle owner; prologue uses the same intro. |
| Angler Battle loop | Phoenix canonical ZIP member `Underwater Battle Theme 2 (LOOP).wav` | `8acd24916c39782b02e804ef042f174dad175a71e38edc6e4a9ac12f5b308066` | Existing `res://audio/music/battle_loop.ogg`, SHA `545242b724a36055b5631df2fd89aad7a66ae66f71ca46060f954dea0245dadd` | Existing normal Battle owner; prologue applies a safe fallback trim if reached. |
| Cordys music intro | Phoenix canonical ZIP member `Underwater Final Boss 1 (INTRO).wav` | `122544c04a6874ecc9d24468160950e02a70b2e7e5d933273e354efcc6d4dd91` | `res://audio/music/final_boss_intro.ogg`, SHA `e00bd3d8601cffad0fd9d2232853ceefcaa974aa06b0d924a4208cdf8f9c675f`, 317,965 bytes | Cordys leitmotif in prologue; future campaign fight reuses the canonical cue. Old DEMO MP3 is reference-only. |
| Cordys music loop | Phoenix canonical ZIP member `Underwater Final Boss 2 (LOOP).wav` | `20020af1293e4fe1736078446b8b84447b127283930d77b52bb50b9f1b0875d8` | `res://audio/music/final_boss_loop.ogg`, SHA `dfa5e61d103c53b9420dc58085079684a5dd2d25e2fde835ef37bba45f14eda4`, 2,022,093 bytes | Safe delayed-player fallback and future campaign fight. |
| Finishing impact candidate | Glassgoat/Sonniss `Heavy Sci-Fi Hit_HW 09.wav` recorded in PR #96 manifest | `b93255074207c4990dd103d176f67d93967530e09e2f8ab53164941c437b1477` | Existing `res://audio/sfx/combat/heavy_hit.ogg`, SHA `f1d9f767c7191694875075142fc78684cb0138d59c8f25c6c44a654612241721`, 53,904 bytes | Candidate only until browser audition proves timing and mix. Do not add a duplicate. |

## Measured media boundary

### Approved additional prologue cinematic owner, 2026-10-03

Use the existing `res://media/cutscenes/octopus_demon_v3.ogv`, SHA-256
`8cad2b4924837aedd38eac035ff9733231d550f3754b487f220fd97f2588033c`,
from Glass's `Octopus_demonV3.mp4`, SHA-256
`138c4d3d4b720febae992e6cd8e8c30260513caaeb8e359a0240a8b69665226b`.
Duration: 60.714667 seconds. `PrologueCinematic` owns one decoder, pausing at
25 seconds for the fight and resuming the remainder before motivation. It
uses Music at -6 dB local trim; GameAudio is silent during both portions.
No new video derivative or duplicate full-file packaging is admitted.
Miguel will discuss shortening with Glass; until then the delivered V3 and
25-second boundary are authoritative. Native/web timing and listening remain
required; text legibility findings must not be concealed by successful import.

| Asset | Duration | Video/format | Audio measurement |
| --- | ---: | --- | --- |
| Mermaid runtime OGV | 33.877 s | 1280×720, 30 fps, Theora/Vorbis | -13.3 LUFS, +1.5 dBFS measured peak; begin with -6 dB local trim. |
| Exploration runtime OGG | 105.974 s | Ogg Vorbis loop | -13.9 LUFS, +0.1 dBFS peak; prologue trim near -7 dB. |
| Battle intro runtime OGG | 15.000 s | Ogg Vorbis intro | -26.9 LUFS, -9.6 dBFS peak. |
| Battle loop runtime OGG | 88.645 s | Ogg Vorbis loop | -13.7 LUFS, -0.3 dBFS peak; prologue trim near -7 dB. |
| Final Boss source intro | 22.588 s | PCM WAV | -19.0 LUFS, -3.6 dBFS peak. |
| Final Boss source loop | 90.353 s | PCM WAV | -14.6 LUFS, -1.0 dBFS peak; runtime playback trim near -4.5 dB. |
| Heavy-hit runtime OGG | 4.900 s | Ogg Vorbis one-shot | -26.3 LUFS, -10.0 dBFS peak. |

## 2026-10-03 Glassgoat character deliveries

The Dropbox files below are useful authored-animation sources, but are not
safe whole-file replacements for the current runtime rigs. Their geometry and
bounds match the corresponding existing character, while their clip sets are
purposefully trimmed and would remove locomotion/reaction/win clips required
by `Cast` if copied over unchanged.

| Delivery | SHA-256 / size | Imported contents | Decision for this PR |
| --- | --- | --- | --- |
| `/Users/tomriddle1/Dropbox/Max.fbx` | `cee7fc9b79ad35531e9a78b0d2372b2dba9c53d0e09fe2e83f6839a974a5a977`, 10,790,044 bytes | Same 7-mesh/7-material Maxilani geometry; 13 clips, including new `Riptide Slash` and `Swift Slash`. Current runtime file has 60 clips. | Preserve as an animation-intake candidate. Do not replace `Scuba_Rigged.fbx` during the opening work. |
| `/Users/tomriddle1/Dropbox/Musashi.fbx` | `f78fb38418032c421b4a826f874f9573e8d05c1d4f010f21bed695f21de887b7`, 17,245,964 bytes | Same 1-mesh/1-material Musashi geometry; 24 clips, including new `Precise Jab`, `Silt`, and `Exploit Opening`. Current runtime file has 59 clips. | Preserve as an animation-intake candidate. Do not replace `Prototype1_Rigged.fbx` during the opening work. |
| `/Users/tomriddle1/Dropbox/Buxky.fbx` | `deadfbc96217f1fd5ae03cde371f9a39145d28cbb5fbda7ae84fb53623ce1afb`, 28,820,204 bytes | Same 1-mesh/1-material Bucky geometry; 42 clips, including new `Guard Break`, `Heavy Slam`, `Mending Current`, and `Tidal Revival`. Current runtime file has 55 clips. | Preserve as an animation-intake candidate. Do not replace `PrototypeV_Rigged.fbx` during the opening work. |

If these moves are admitted later, extract or merge only the approved actions,
then rerun the complete `Cast` clip, animation-motion, world-swim, and battle
presentation gates. File replacement without that reconciliation is rejected.

## Required intake evidence before runtime ownership

Prepared Cordys frame: `res://art/deep_zone/octopus_prologue_frame.tres`,
67,693 bytes, SHA-256 `736f8126c9ad1199318e049296589b98e918d843ac38b2bfca2cc65ba305cb1a`.
This is a mechanical derivative of canonical FBX `e51ac165…`, normalized to
4 m. It records the exact idle/Angry Pose/Damaged 1/Poison Breath clip names,
19 samples per clip and 1,976 actual surface-extreme points. Regenerate with
`godot --headless --path . --script tools/derive_cordys_framing.gd` if the model,
normalization or clip selection changes. It removes a measured 3,062 ms runtime
scan (cached actor ready: 52 ms). The actor/manifest gate checks source and clip
identity; real moving-skin projection and browser first-reveal review remain
independent rejection gates. No source mesh, material or animation bytes changed.

- Final Boss derivatives: canonical source digest, command/settings, duration,
  runtime digest, package size, and signal-edge analysis are recorded. Browser
  listening approval remains required.
- Octopus: the canonical intake gate remains green; the prologue adapter
  normalizes the animated actor to 4.00 m high with observed pose bounds near
  5.88 × 4.00 × 8.54 m, exposes semantic reveal/idle/hurt/finish clips, uses
  the authored +Z front, and tints the pale Swordfish bill to prevent the old
  screen-spanning white-rod presentation. The four production-adapter gallery
  captures are in `docs/evidence/opening-prologue-cordys/`.
- Final opening replacement: source authority, digest, dimensions, duration,
  audio measurements, approval, browser transcode, and replacement proof.

## Excluded assets

- `Underwater Final Boss (DEMO).mp3`: reference only.
- `Octopus_Boss_updatedvs.fbx`: byte-identical duplicate of V2.
- Original animation-only Octopus FBX: superseded reference.
- Dropbox-root music duplicates when the canonical ZIP contains the same file.
- Any second Mermaid OGV copied only to give the opening a different filename.
- The 2026-10-03 Max/Musashi/Buxky FBXs as whole-file runtime replacements;
  they are narrower action deliveries, not complete superseding rigs.

## Final Boss derivative record

The two canonical WAV members were extracted directly from Phoenix's ZIP and
encoded with FFmpeg's native Vorbis encoder at 44.1 kHz stereo, quality 5:

`ffmpeg -i <canonical-wav> -ar 44100 -ac 2 -c:a vorbis -strict -2 -q:a 5 <runtime-ogg>`

No normalization, fade, crossfade, or source edit was applied. Decoded edge
measurements are kept in `docs/audio-edge-audit.md`; authored playback gain is
owned by `UnderwaterAudioManager`, independently of the player's Music slider.

The two Ogg derivatives add 2,340,058 bytes before Godot package compression.
The opening reuses the existing Mermaid and Octopus runtime assets, so this
phase adds no duplicate video or FBX bytes.

## Credits and permission boundary

- Glassgoat delivered/approved the Mermaid and Octopus media for the project.
- Phoenix delivered the canonical music ZIP for the project and documented the
  INTRO/LOOP playback contract.
- The heavy-hit derivative inherits the provenance/license record already kept
  by PR #96.
- Final credit wording remains inherited release metadata; lack of polished
  credit prose does not permit replacing canonical source records.
