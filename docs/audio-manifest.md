# Phoenix audio runtime manifest

Source of truth: `/Users/tomriddle1/Dropbox/Underwater Music and SFX.zip`
(SHA-256 `a89a04c0c7931731e3bb4e243f80106aca322d06b6377afd45af12cadd7a3d43`).
The ZIP's PCM WAVs are canonical. Long music is encoded to Ogg Vorbis for the
web runtime; the three delivered menu sounds remain byte-identical WAVs.
Dropbox-root copies and `__MACOSX` metadata are not runtime inputs.

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
| `audio/sfx/ui/hover.wav` | `SFX/UIHOVER.wav` | `0a33872ad6512eac29043f86292019f28e00418702978f817c3495d02bca6778` | same | Main-menu hover only. |
| `audio/sfx/ui/click.wav` | `SFX/UI CLICK.wav` | `fa4ba4bd62e94c085dc790c100d16cad6ce3dd72b5bf8ed530aedfc281bd4922` | same | Main-menu confirm/click only. |
| `audio/sfx/ui/start_game.wav` | `SFX/UI START GAME.wav` | `e3bd6c7e8e5b8587b8be2ad318bed5518ce4bb84fbc6477253af13e626e5a5ab` | same | Successful run start only. |

The Final Boss pair is deliberately absent from the runtime slice because the
Octopus route remains blocked on a renderable model. No delivered menu sound
is repurposed as combat feedback.
