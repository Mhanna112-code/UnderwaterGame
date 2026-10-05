# Marc October 4 integration intake

## Frozen source batch, not a deployment claim

Refreshed October 4, 2026. PR #100 starts this intake at f25d2bf (runtime
b0bee59). Marc's PR #97 is ebcb22ec24045b14ecedf4e16bd5c9876eab527a;
PR #99 was d5134bf293487cbae8b8f8cdeaf0fb1c2233dfd9. Both were fetched again
and unchanged before the first implementation batch. A subsequent refresh found
#97 659ff6962543206e7651f22a1ee79df4c4007610 and #99
7a27230e01c07358d50c49f2dca36421508dcdf4. The existing preview remains b0bee59
until a new, identified export passes its delivery checks. Main is untouched.

## Authored deltas and ownership

| Commits | Meaning | Integration contract |
| --- | --- | --- |
| #97 026241c | Item-carrier and battle text | Actual reward identity/first playable turn already adapted; retain our responsive log and spell casts. |
| #97 c1d9067 / #99 7e52dfc | Dark, styled pause menu | One shared port; preserve all four tabs including Audio, and test small viewports rather than copying fixed widths. |
| #97 6719ad2 | Special encounters, floors, save pads, map | Preserve Marc's maze content; adapt persistence to the campaign owner, not a second incompatible `maze_save.json` product. |
| #97 c943218 / bbadaaf | First-person grapple, wall collisions, whirlpools, fake rocks, Sonar-following vision, door reach | Reconcile actual input/camera ownership, collision and recovery; preserve authored strong-room encounter forcing. |
| #97 dd83f7a | Merge main into Marc's branch | Deduplicate inherited main changes. Raw file replacement would overwrite reviewed campaign work. |
| #97 37b7590 / 7a61c72 / 226f4f8 | Wall riders, continuous floor, World-style HUD | Verify a real diver rides without sticking, floor coverage, and readable non-overlapping HUD. |
| #97 809eaa1 | Embed maze into World | Reconcile geometry with independent lab and approved completed-puzzle entrance; preserve one party/resource/save/audio owner. Do not blindly copy coordinates over the lab route. |
| #97 2dcadac | Wall-27 draft/secret passage | Superseded by ebcb22e; do not port both secret entrances. |
| #97 647e900 / 9600eb7 / a1c9093 | Hallway alignment required for split rock; remove boss ring; brown breakable rocks | Retain latest puzzle requirements and remove debugging presentation. |
| #97 68d478f | Developer World start/full unlocks | Explicit review-only route, never normal New Game or saved progression. |
| #97 b41955c | Popups/current warnings wait through combat | Adapt singleton/Battle ownership; no modal may pause or cover combat, lose its remaining pages or replay over Game Over. |
| #97 f3018f4 | Fence past poster wall | Verify real traversal bounds without introducing an invisible world-wide wall. |
| #97 c402d83 | Clockwise map selection by geometry | Preserve screen-space clockwise indexing, not alphabetical node order; test actual highlights/controls. |
| #97 ebcb22e | Wall11EndCap underpass, draft prompt, remove two dome levers | Latest source of truth: enter either side near potion rock, accept prompt, swim down/under/up; old wall-27 path and dome-lever tasks must not remain. |
| #99 b986d58 | Objective below measured HUD | Adapt region-owned guidance; avoid persistent Deep text in Shallows and preserve Bucky/TAB hint. |
| #99 b8bf08b / d5134bf | Tutorial/level-up caption before log; hide log during Enter caption; fit enemy buttons | Preserve approved tutorial and real first-turn controls; verify short-height layout and caption lifecycle. |
| #99 542c456 / 2c1be2b / 91757e3 | Status summaries, HP/queue wording | Use final text and status labels; the added status tutorial page is removed by d5134bf and must not be resurrected. |
| #99 de5f079 | Bleed lasts the rest of battle | Port move + rules/help contract together; verify actual hit, four turns, stacking cap and normal campaign combat. |
| Earlier #99 11857ae pending subset | Learned-spell stat bonus and blockade guidance | Separate remaining admission; apply to intended consumers without double-scaling authored bosses or changing prologue/tutorial contracts. |
| #97 64c778a / c65cf93 / 1a9ba39 | Navigation map earned from Control Room chest, including dev start | Persist actual maze_map key item; L requires earned map, inventory explains ownership; do not grant via ordinary/dev initialization. Chest access must remain possible without already owning L. |
| #97 f58b4ce / 2d60a03 / 4f3cc97 | Right-side discovery-only map legend, chest and visited-boss icons | No undiscovered boss spoilers; right-side panel fits small viewports and updates on discovery. |
| #97 2a41c0f / 65c3f70 | Shift+E rotates selected current, E rotates hallway; readable current strokes | R remains encounter toggle even with map open. Update actual input, HUD/help and route tests together, not just displayed text. |
| #97 2c32467 | Solid chests, Press E to open | Verify physical collision and reachable interaction; no player overlaps chest or infinite regrant. |
| #97 f5a8a97 / ef99337 | Encounter owner/toggle synchronization; special/item spots respect R | Latest Marc decision replaces earlier assumptions: inactive embedded maze must not start World fights; maze special sites require encounters on. Do not silently change authored boss gating. Strong-room forcing still needs inspection against the exact new handlers. |
| #97 818e2ab / #99 7c34be2 / 1b43949 | Status cards and applied messages use remaining-turn units | Deduplicate shared changes; preserve responsive labels and persistent Bleed cap. |
| #97 659ff69 / #99 7a27230 | Remove Reopen Tutorial Guide button; retain F1 | One shared removal; two practice buttons and optional world beacon remain. This does not remove the tutorial content. |

## Admission receipts

- 21b84d5: shared pause styling, four tabs including Audio, responsive bounds and
  HUD ordering; 12 shapes and inspected native views pass.
- 3d69a5b: Battle/popup ownership, FIFO remaining lessons, live scene owners,
  stopped hidden decoder and safe late text continuation; actual Battle/native
  video/tutorial handoff gates pass.
- Current status/caption batch: persistent authored Bleed, capped initial stacks,
  readable status durations, responsive six-card layout, caption/log ownership,
  latest applied-message wording and redundant guide-button removal. Actual
  puppet/Cordys combat, all 48 bounded Tethys fights, narrow delivered attack and
  heal/revive checks pass. Final shared status, actual F1/practice/menu and tutorial
  caption regressions pass without captured script errors. No hosted acceptance
  is implied by this local admission.
- All other maze rows above remain pending. In particular, a new branch snapshot
  is not evidence that seamless geometry, acquired-map behavior or underpass
  traversal has been integrated or verified.

## Sequence and acceptance

1. Shared pause/popup/caption/status batch, with named regression catalog,
   red-before-fix checks and fresh rendered wide/narrow views. Preserve Audio,
   clean tutorial video, the opening state and nine authored spell clips.
2. Read latest maze modules and reconcile geometry/input/campaign ownership.
   Admit authored deltas incrementally, not by wholesale scene replacement.
3. Verify completed shallow puzzle → maze, independent lab → Tethys,
   secret-puppet waves/key, defeatable campaign Cordys, actual resources and
   checkpoint/reload/full-party recovery. No prologue replay or campaign relic
   consumption. Marc's forced strong-room encounters remain his design.
4. Inspect actual traversal/rendered interactions and run a complete polish
   round; defects reopen the round. Green targeted gates alone are not full
   maze acceptance.
5. Export the exact reviewed source, inspect served PCK metadata/hash and
   browser behavior, update the existing review alias (not public/main), then
   build same-source Windows/Linux packages with target-launch limits explicit.

Each subsequent push requires another bounded remote refresh and a delta entry.
No absent Discord animation is assumed downloaded; the admitted nine clips are
the already-downloaded FBX derivatives documented in the asset manifest.
