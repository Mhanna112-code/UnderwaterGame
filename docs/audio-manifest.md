# Phoenix audio runtime manifest

Source of truth: `/Users/tomriddle1/Dropbox/Underwater Music and SFX.zip`
(SHA-256 `a89a04c0c7931731e3bb4e243f80106aca322d06b6377afd45af12cadd7a3d43`).
The ZIP's PCM WAVs are canonical. Long music is encoded to Ogg Vorbis for the
web runtime; the three delivered menu sources remain byte-identical WAVs.
Menu hover now uses a separately named soft derivative rather than the raw
four-second source; click and start-game originals are unchanged.
Dropbox-root copies and `__MACOSX` metadata are not runtime inputs.

Decoded runtime edge measurements and their explicit human-listening boundary
are recorded in [audio-edge-audit.md](audio-edge-audit.md).

| Runtime path | Canonical ZIP member | Source SHA-256 | Runtime SHA-256 | Status |
| --- | --- | --- | --- | --- |
| `audio/music/exploration_loop.ogg` | `Underwater Exploration Ambience (LOOP).wav` | `7d535afb8929b12cfc8148479b6ebc2b900c57dbd8e87960777764ef26ba8543` | `5af14408aa0bb8c8dfc9290c87afef214b4d07fe4e765ae6641cdaf5859a42f8` | Production exploration loop. |
| `audio/music/battle_intro.ogg` | `Underwater Battle Theme 1 (INTRO).wav` | `e08f5bdfce52fdf75006fc403ce449b72b7677c815d83fe26c563d03710eae08` | `9e7dfbd99c85214233cbc47c499076f4622e8deec5a009e697461dd1e99857e4` | Production Battle intro. |
| `audio/music/battle_loop.ogg` | `Underwater Battle Theme 2 (LOOP).wav` | `8acd24916c39782b02e804ef042f174dad175a71e38edc6e4a9ac12f5b308066` | `545242b724a36055b5631df2fd89aad7a66ae66f71ca46060f954dea0245dadd` | Production Battle loop; immediate handoff, no crossfade. |
| `audio/music/tethys_candidate_intro.ogg` | `Underwater Mermaid Boss (verb tail).wav` | `93829813932d8a888b1aaa6ccc2374d340b5e93636a8ac4707e976c666c226d7` | `4ca570fdbe1a19112877d8b35e9aab2ae1e6bf4899e5174f5e93fc3b0bacc224` | Candidate only: filename is not an authored `INTRO`; do not claim the join until listening review. |
| `audio/music/tethys_loop.ogg` | `Underwater Mermaid Boss (LOOP).wav` | `4aaa7c1506650467d99335ee4880d23b65632ad931d4c2f47f67c9e730373ae7` | `62972b88f9bb00984abaf492d7e426ce2348537b1262dc7b59efd2e1bdf17bbd` | Production Tethys loop. |
| `audio/music/title_candidate_intro.ogg` | `Underwater Main Title 1.wav` | `9119743c687e4de4cbdc40183550b672ed8f4702fece9571182569d83e8fd8f0` | `d7da5835dad5eb69867f14e8ebc3cf35ee0b3a2311111d32ba424e4a9fe2461e` | Candidate title first segment; requires browser listening approval. |
| `audio/music/title_loop.ogg` | `Underwater Main Title 2 (LOOP).wav` | `d4017e08bc3969cd164043924df5d0f582a34e004ef79c056a165c05f83f4a0a` | `9c10bf21e47386de428fc3b41755e48cef948faa7c0e0529d3458d4eee0496a2` | Candidate title loop; requires user-gesture lifecycle review. |
| `audio/music/victory_candidate_intro.ogg` | `Underwater Victory Fanfare and Victory Theme 1.wav` | `600c0e8ed037092a2c82a1f156a94199964c29047e329933a6b79fc78e6261bd` | `af53ff067c466697c9d3d7a197521bdc7711986bddbfaca81f3267ab874e04ca` | Production victory first segment; browser listening must approve its loop join. |
| `audio/music/victory_loop.ogg` | `UnderwaterVictory Theme 2 (LOOP).wav` | `25ea80a4790447a36e2c95789348d47b127283930d77b52bb50b9f1b0875d8` | `d36bc5995d1d6b1937117cfa3cf1c7334689f5c45df6fcaa2e5e2c26a3197fdb` | Production victory loop. |
| `audio/music/game_over.ogg` | `Underwater Game Over.wav` | `c0784b24b177f5a7b1f59faa15d28a08e2697f160780a16c69b3490807a8a5f1` | `fde8c2f09fa239a48c93e860979af6d46b94bf216ad05fd629c9a498e6e8872f` | Production game-over one-shot. |
| `audio/music/final_boss_intro.ogg` | `Underwater Final Boss 1 (INTRO).wav` | `122544c04a6874ecc9d24468160950e02a70b2e7e5d933273e354efcc6d4dd91` | `e00bd3d8601cffad0fd9d2232853ceefcaa974aa06b0d924a4208cdf8f9c675f` | Production Cordys prologue intro; 22.589 s, authored local gain -1 dB. |
| `audio/music/final_boss_loop.ogg` | `Underwater Final Boss 2 (LOOP).wav` | `20020af1293e4fe1736078446b8b84447b127283930d77b52bb50b9f1b0875d8` | `dfa5e61d103c53b9420dc58085079684a5dd2d25e2fde835ef37bba45f14eda4` | Production Cordys fallback/future loop; 90.353 s, authored local gain -4.5 dB. |
| `audio/sfx/ui/hover.wav` | `SFX/UIHOVER.wav` | `0a33872ad6512eac29043f86292019f28e00418702978f817c3495d02bca6778` | same | Preserved original; not played by the title menu. |
| `audio/sfx/ui/hover_soft.wav` | Derived from `SFX/UIHOVER.wav` | Original above | `fa711f542b102bd57ae2399fa017863ff393dfaa407ba4d15ad2346c1def89f3` | Production hover: 180ms, 1.8kHz two-pole low-pass, 12ms attack/90ms release, -15dB asset trim; 250ms repeat/confirmation guard. SFX bus still controls volume/mute. |
| `audio/sfx/ui/click.wav` | `SFX/UI CLICK.wav` | `fa4ba4bd62e94c085dc790c100d16cad6ce3dd72b5bf8ed530aedfc281bd4922` | same | Main-menu confirm/click only. |
| `audio/sfx/ui/start_game.wav` | `SFX/UI START GAME.wav` | `e3bd6c7e8e5b8587b8be2ad318bed5518ce4bb84fbc6477253af13e626e5a5ab` | same | Successful run start only. |

## Glassgoat gameplay-SFX candidate pool

Glassgoat's five delivered WAVs are exact matches for Mechanical Wave's
“Hits Whoosh” collection in the official 2015 Sonniss GDC bundle. The sources
are stereo 24-bit/96 kHz Broadcast WAVs. Runtime derivatives are trimmed,
level-reduced, resampled to 48 kHz, and encoded as Ogg Vorbis so one gameplay
event cannot accidentally play an entire multi-take reel. The bundle license
allows use in games; provenance and license links are recorded in the intake
bug catalog.

| Runtime asset(s) | Canonical source | Source SHA-256 | Runtime SHA-256 | Candidate ownership |
| --- | --- | --- | --- | --- |
| `audio/sfx/combat/attack_swirl.ogg` | `Action Swirl Whoosh_HW 04.wav` | `4f164b427b5a5b692f2f5b57c9475125ff00735ae22caf03c7c7a0a670399c11` | `7d802259a99e41367af60d86c76c0ff18e85037781d0529360189eb7bb76f582` | Shared attack-motion candidate; 0.960 s. |
| `audio/sfx/combat/swish_01.ogg` … `swish_06.ogg` | `Action Swish_HW 02.wav` | `1eb3e50adffabcc46ca3ed30f520eb19b234f9808acf4e760ec9ea8391e9b609` | Pinned individually by `verify/combat_sfx_assets.gd` | Six separated shared swish variants; 0.232–0.270 s. |
| `audio/sfx/combat/fast_swish_01.ogg` … `fast_swish_05.ogg` | `Fast Action Swish_HW 05.wav` | `2ef515c463c04c2d518afb74d44336f51ed0912c46c9e00431a3ed13f927f87d` | Pinned individually by `verify/combat_sfx_assets.gd` | Five separated fast-attack variants; 0.221–0.316 s. |
| `audio/sfx/combat/heavy_hit.ogg` | `Heavy Sci-Fi Hit_HW 09.wav` | `b93255074207c4990dd103d176f67d93967530e09e2f8ab53164941c437b1477` | `f1d9f767c7191694875075142fc78684cb0138d59c8f25c6c44a654612241721` | Heavy impact or knockout candidate; 4.900 s. |
| `audio/sfx/combat/shockwave_swirl.ogg` | `Swirl Whoosh_HW 42.wav` | `d81452bb2d2368f86d6875a54f75fba6aade3993bdfabf1a2ccaf836d92a0620` | `c21c07ae0fac261c4c5a60fc6be645c7ced2cb73c26323ab967f3c9690906dfc` | Sustained Shockwave candidate; 10.000 s. |

The runtime now uses these prepared derivatives for shared attack motion,
ordinary/heavy impact, miss, dodge, and Shockwave feedback through one
four-player overlap pool. Their final mix balance must still be approved
against Phoenix's music in a browser listening pass. No delivered menu sound
is repurposed as combat feedback. Phoenix's labelled Octopus Final Boss
`INTRO`/`LOOP` pair is now admitted for the opening Cordys reveal.
`UnderwaterAudioManager` owns the no-crossfade handoff and applies local
authored trims without changing the user's Music volume. The old Final Boss
DEMO MP3 remains reference-only.
