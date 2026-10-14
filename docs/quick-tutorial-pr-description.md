## Purpose

Respond to the playtester who declined to play because the tutorial was too long. Integrate a short starter with optional full interactive practice and stat explanations accessible in battle and inventory, preserving the latest opening/main changes.

## Ready for review

- Starter: one actual Electric Touch choice and one live timing dodge, with three short confirmations. A missed dodge still completes the lesson. No extra real-fight grind or mandatory ability carousel.
- Full Combat Lesson remains an actual five-move interactive lesson, not a prose guide. Quick practice and World Abilities are explicit Inventory > Combat Help choices.
- Battle > Combat Help opens the shared stat/effect/status reference. Escape returns to the same actor/menu without spending a turn or changing resources; prior pause/focus is retained.
- Optional Quick/Full combat practice borrows temporary resources/inventory rather than healing the earned party or saving a practice state. Separate special-minigame replay is not covered by this new isolation claim.
- Preserve current main's video/Cordys opening, actual combat formulas, maze/lab progression, rewards, audio settings and other Marc changes.
- Includes PR 101's compact exploration HUD and complete-card maze-caption reservation in this combined review branch. Neither PR has been merged into main by this work.

## Evidence and retained failures

`docs/evidence/quick-tutorial-oct14/`: real failures retained for the missing battle reference, long starter caption, clipped reference Close, and replay healing earned resources. Focused fixes pass the corresponding checks. Starter pass and natural-dodge-timeout pass; retained five-move lesson reaches a real victory; reference tested headless and rendered at three viewport sizes and both prior pause states; optional practice entry/Skip preserves party/inventory.

After combining PR 101, 4,646 rendered HUD checks and the quick/reference/isolation tests pass. The normal beacon route also passes actual W swimming into training, real attack/QTE input, movable World return and stored opening/tutorial milestones.

Expanded checks with original-effect markers: **274 World skip / 288 maze / 40 Quick+Full completion+item / 42 real damage-driven loss+Retry+Exit checks**; four separate native-process prepare/cold pairs after earned quick completion, Skip, legacy downed-party startup and existing-resource fidelity. The legacy downed Maxilani softlock and initial Retry/Exit milestone defects were caught and repaired. Result-handler tests explicitly distinguish injected-result plumbing from actual combat defeat. Counts are checks, not independent player playthroughs.

Visual checks caught a zero-height narrow battle stage and offscreen Retry/Exit buttons despite functional passes. Final native starter/reference/Full/recovery screenshots were inspected; four combined focused rounds, six reference cases, 64 result-popup checks, unchanged 48 embedded-checkpoint cases and checkpoint IO pass. Full QTE success/miss and live Help preserve the lesson. A suspected Precise Tap preview-color mismatch was retracted after a real rendered five-stage run; a new assertion pins the intended green ACC value.

[Playtest](https://underwatergame-pr103-quick-tutorial.vercel.app/) · [Review steps](https://underwatergame-pr103-quick-tutorial.vercel.app/review.html) · [Exact-source metadata](https://underwatergame-pr103-quick-tutorial.vercel.app/build-info.json). Exported gameplay source is **`bda7ff68634d1a4557e7849538d9e599f61530f4`**, Godot 4.7.1. Subsequent commits are test/documentation-only. Anonymous access succeeds and served PCK SHA256 `606dd91965fb5b02d8a42530aedcd6cf870211fb44fe49f2337ae46d1509c99b` matches the local export. This is not the repository's stale `docs/` bundle.

## Real-browser and final scoped audit

Final-source headed Chromium actually played fresh New Game through the preserved videos, three party actions/Cordys strikes, recovery, beam, real quick attack and missed dodge to movable World. Owned IndexedDB manual slot sequence 4 has completed milestones, no Bleed and reset EVA. Browser reload + actual **Slot 1 Save Point** returned directly to movable World without replaying opening/training. Optional Quick/Full entry+Skip, World Abilities entry+close, shared Help, narrow Inventory and Full scrolling were exercised. No seeded save or test flag replaced normal reachability.

The final scoped native/browser round finished with **no further observed tutorial/help defect**. The first rapid popup-close attempt produced five Chromium background-document pointer-lock rejections while native rendering owned focus; logs are retained. The focused-browser retry produced no new rejection and confirmed real canvas-click pointer lock and camera/menu return. No Godot script exception was captured. The actual browser manual-checkpoint leak from the prior preview was reproduced and repaired before this final-source round; original replay effects and valid older checkpoint fidelity remain intact, not blanket-wiped.

## Limits and review decisions

- **Subsequent human review found inherited guidance gaps:** the nearby Bucky/blockade and reward-rock prompts, post-Run R reminder, Shallows purpose and maze destination cues were removed in earlier main changes and remain absent here. Existing guidance tests partly assert that absence. The source/history audit, including weaker save-point and hallway cues, is retained in `docs/quick-tutorial-overnight-plan.md`. These have not been fixed; Miguel requested analysis first. The earlier clean tutorial/reference round is not acceptance of wider World/maze guidance.
- Full five-stage victory/items/loss and embedded-maze practice are verified natively, not a complete real-browser Full playthrough or normal campaign traversal.
- Safari, mobile hardware, Windows/Linux builds and full campaign/boss/balance acceptance remain unverified.
- Human readability, engagement and preserved opening pacing still need Miguel's review. This PR does not rebalance combat or redesign the story.
- Special-encounter replay is outside the new Quick/Full resource-isolation claim.

Latest upstream fetch found no new main/Marc HUD commits. Implementation is stopped; hourly disk/upstream checks continue until October 14, 11 a.m. Chicago. Main and canonical production are unchanged. Ledger: `docs/quick-tutorial-overnight-plan.md`. Stop immediately below 3 GiB disk space.
