# Ability popup video bug catalog

| Bug | Observable failure | Cheapest protection | Evidence boundary |
| --- | --- | --- | --- |
| A Grapple media refresh leaves a prior player attached | Two video layers draw in the same tutorial modal, producing a doubled or ghosted clip | `ability_popup_video.gd` opens Grapple, counts the nested `VideoStreamPlayer`, refreshes it, then asserts exactly one player remains | The check proves scene ownership and replacement. Browser playback remains the proof that the encoded clip itself looks clean. |
| A video player escapes `MediaFrame` | A 1920x1080 source expands or covers the tutorial modal | The same verifier asserts the player and its frame stay within `TutorialContent.VIDEO_FRAME_SIZE` | Browser review verifies final layout at normal viewport size. |
| The popup pauses the tree and prevents tutorial footage from advancing | A blank or frozen ability clip appears while the modal is open | The verifier waits while paused and asserts a positive stream position | Headless verifies stream progression; browser review verifies visible decode. |

The Grapple asset is deliberately a short, clean 16:9 excerpt. Its prior long source included obstructed late frames that made the clip look corrupted. The runtime test cannot judge video pixels; the hosted review build must be checked visually before merge.
