# Lab and Tethys route verification bug catalog

This catalog covers the normal-play handoff from the two defeated laboratory
blockers through the Mermaid cutscene, Tethys battle, recovery, and maze
objective. It deliberately does not use `?boss=1`; a debug shortcut cannot
prove that a player can reach or leave the encounter in the campaign.

## Active bugs the gate must catch

| ID | Player-observable failure | Cheapest proof |
| --- | --- | --- |
| LAB-TETHYS-001 | Reaching the unlocked laboratory door does nothing. | Instantiate the production World, put the route in its public unlocked state, physically enter the lab trigger, and observe `lab_state == "cutscene"` plus one visible cutscene owner. |
| LAB-TETHYS-002 | Finishing or skipping the cutscene starts no fight, or starts Tethys more than once. | Drive the public cutscene completion signal and assert exactly one production Battle with `boss_encounter` and `encounter_source == "lab_boss"`. |
| LAB-TETHYS-003 | Cutscene input leaks into swimming/camera control or leaves the HUD, cursor, pause state, or mouse capture stuck afterward. | Observe frozen diver position while the modal is open, then observable world/battle input state after dismissal. |
| LAB-TETHYS-004 | A Tethys loss or checkpoint reload restores an impossible half-cutscene/half-battle state. | Serialize/load `cutscene`, `boss`, and `in_progress`; assert normalization to the safe pre-cutscene lab state and a retryable objective. |
| LAB-TETHYS-005 | Winning Tethys does not persist completion or advance the route. | Complete a production lab-boss battle through World's result handler and assert lab cleared, Tethys defeated, maze objective, and checkpoint data. |
| LAB-TETHYS-006 | The permanent door backing keeps the lab inaccessible after it is unlocked, or the concealed office never becomes the encounter stage. | Assert the environment opens its door collision and reveals the interior only for the cutscene/boss phase. |
| LAB-TETHYS-007 | The Mermaid video is cropped, doubled, absent on web, or has no usable Skip/Continue action. | Structural scene assertions plus browser screenshots at 1280x720 and 720x480. |
| LAB-TETHYS-008 | Tethys starts or attacks with her visible back toward the party. | The existing production Tethys gate measures the model's actual +Z front at spawn and during `_do_boss_turn`. |
| LAB-TETHYS-009 | Exploration, cutscene, boss, victory, or retry music overlaps or resumes in the wrong phase. | Assert the single audio owner's cue transitions along both victory and loss/retry paths. |
| LAB-TETHYS-010 | The trigger repeats while the player remains inside it, creating duplicate modal/battle owners. | Keep the diver inside across several physics frames and count cutscene/Battle owners. |
| LAB-TETHYS-011 | The blue maze landmark is only decoration: reaching it after Tethys never enters the current maze scene. | Complete the public route state, physically enter the maze-transition radius, and assert the scene tree replaces World with MazeLevel. |
| LAB-TETHYS-012 | The Broken Office reads as a small detached prop behind the fight instead of the room containing the combatants. | Start the production three-diver Tethys battle and project the real office and actor bounds through its real camera; require the room to fill the stage and contain the actor tableau. |
| LAB-TETHYS-013 | At 720x480 the content-sized battle HUD leaves such a short stage that Tethys, the party, and the room are too small to read or target. | Run the production battle windowed at 720x480 and require a usable stage height plus a minimum projected actor height. |
| LAB-TETHYS-014 | The generic stage-framing gate reports green while never constructing a boss encounter or inspecting its environment. | Keep a distinct boss-composition gate in `gates.sh` at both supported review resolutions. |
| LAB-TETHYS-015 | The office's remote lantern outlier distorts aggregate bounds, so the wall/floor room is placed to the right while the party stands over empty water. | Identify the authored `Wall_Broken` room shell, align and measure against that shell rather than every detached decoration, and require every actor footprint inside its floor. |
| LAB-TETHYS-016 | Tethys is technically in frame but Bucky/furniture obscures most of her body, hiding the boss and her authored attacks. | Project each actor's production screen rect and reject substantial boss/party overlap; confirm the result visually at both target resolutions. |
| LAB-TETHYS-017 | The room passes size/containment checks but still reads as a flat pale test box, with no authored lighting language and party silhouettes merging into the prop pile. | Inspect the production wall/floor material and authored colored lights, reject substantial party/party overlap, then review regenerated 1280x720 and 720x480 captures. |

## Skipped by headless automation

- Cinematography, subjective pacing, Mermaid video readability, music balance,
  and perceived transition quality require the exact web export and a human
  visual/audio pass.
- Final combat balance requires repeated browser playtests with normal-route
  party stats; a boot test cannot decide whether the boss is fun or fair.
- The automated composition gate now proves size, containment, clipping,
  shell luminance, contrasting authored lights, and actor separation. It still
  cannot decide whether the final camera angle and room dressing look
  polished; those remain mandatory screenshots in the visual-audit loop.

## Evaluation

The route is not complete until the focused gate is green, the existing
Tethys gate is green, save/load is retry-safe, and one full browser audit round
at both target resolutions reports no observed defect.
