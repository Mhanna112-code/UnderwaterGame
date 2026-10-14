## Purpose

Respond to the playtester who declined to play because the tutorial was too long. Integrate a short starter with optional full interactive practice and stat explanations accessible in battle and inventory, preserving the latest opening/main changes.

## Current draft

- Starter: one actual Electric Touch choice and one live timing dodge, with three short confirmations. A missed dodge still completes the lesson. No extra real-fight grind or mandatory ability carousel.
- Full Combat Lesson remains an actual five-move interactive lesson, not a prose guide. Quick practice and World Abilities are explicit Inventory > Combat Help choices.
- Battle > Combat Help opens the shared stat/effect/status reference. Escape returns to the same actor/menu without spending a turn or changing resources; prior pause/focus is retained.
- Optional Quick/Full combat practice borrows temporary resources/inventory rather than healing the earned party or saving a practice state. Separate special-minigame replay is not covered by this new isolation claim.
- Preserve current main's video/Cordys opening, actual combat formulas, maze/lab progression, rewards, audio settings and other Marc changes.
- Includes PR 101's compact exploration HUD and complete-card maze-caption reservation in this combined review branch. Neither PR has been merged into main by this work.

## Evidence so far

`docs/evidence/quick-tutorial-oct14/`: real failures retained for the missing battle reference, long starter caption, clipped reference Close, and replay healing earned resources. Focused fixes pass the corresponding checks. Starter pass and natural-dodge-timeout pass; retained five-move lesson reaches a real victory; reference tested headless and rendered at three viewport sizes and both prior pause states; optional practice entry/Skip preserves party/inventory.

After combining PR 101, 4,646 rendered HUD checks and the quick/reference/isolation tests pass. The normal beacon route also passes actual W swimming into training, real attack/QTE input, movable World return and stored opening/tutorial milestones.

Expanded checks: 235 actual World skip cases/checks and 249 maze-return checks; 34 Quick/Full completion/item checks; 36 real damage-driven adversarial practice-defeat/Retry/Exit checks; separate native-process cold Load after earned quick completion, Skip and legacy downed-party startup. The legacy downed Maxilani softlock and initial Retry/Exit milestone defects were caught and repaired. Result-handler tests explicitly distinguish injected-result plumbing from actual combat defeat.

Visual checks caught a zero-height narrow battle stage and offscreen Retry/Exit buttons despite functional passes. Final native starter, reference and responsive recovery screenshots have been inspected; wide/narrow starter and reference checks, 64 result-popup checks and Full QTE success/miss layout pass. The fresh combined focused runner and browser acceptance remain pending.

**No updated tutorial Web preview has been published yet.** Any automatic deployment of the repository's existing `docs/` export does not prove these source changes are playable. A fresh exact-source preview remains an acceptance gate.

## Before ready for review

- Expanded skip/callback, practice win/loss/item isolation, normal beam handoff, cold-save/reload and embedded-maze tests.
- Reconcile applicable old tests with explicit quick/full profiles without weakening their behavioral oracles.
- Complete regression checks after the PR 101 HUD integration.
- Exact-source Web preview, real browser interaction/storage, readable narrow/wide screenshots and a fresh full scoped visual-audit round with no observed defects.
- Re-fetch relevant Marc changes before final delivery.

No merge, canonical deployment or full campaign acceptance is requested. This is a draft until the remaining gates pass. The saved implementation/defect ledger is `docs/quick-tutorial-overnight-plan.md`; hourly follow-ups end at October 14, 2026 11 a.m. Chicago. Stop work below 3 GB disk space.
